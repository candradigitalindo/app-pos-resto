package services

import (
	"cloud-pos/database"
	"cloud-pos/models"
	"encoding/json"
	"fmt"
	"math"
	"time"

	"github.com/lib/pq"
)

// Valid status transitions:
//   pending → approved → payment_requested → paid → received
//   pending → rejected
//   pending/approved → cancelled
var validTransitions = map[string]map[string]string{
	"approve":         {"pending": "approved"},
	"reject":          {"pending": "rejected"},
	"request_payment": {"approved": "payment_requested"},
	"pay":             {"payment_requested": "paid", "partial": "paid"},
	"receive":         {"paid": "received"},
	"cancel":          {"pending": "cancelled", "approved": "cancelled"},
}

func nilIfEmpty(s string) interface{} {
	if s == "" {
		return nil
	}
	return s
}

// generateRequestNumber creates a sequential number in the format ddmmYYnnn.
// It queries existing records for today and increments.
func generateRequestNumber(t time.Time) (string, error) {
	prefix := t.Format("020106") // ddmmYY
	var maxSeq int
	err := database.DB.QueryRow(
		"SELECT COALESCE(MAX(CAST(SUBSTRING(request_number FROM 7) AS INTEGER)), 0) FROM purchase_requests WHERE request_number LIKE $1",
		prefix+"%",
	).Scan(&maxSeq)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%s%03d", prefix, maxSeq+1), nil
}

func ListPurchaseRequests(outletID, workUnitID, status, requestType, parentID string, excludeMasters bool, search string, scopeIDs []string, wuScopeIDs []string, page, limit int) (*models.PurchaseRequestListResponse, error) {
	// Normalize outlet filter
	var filterIDs []string
	if outletID != "" {
		filterIDs = []string{outletID}
	} else if scopeIDs != nil {
		filterIDs = scopeIDs
	}

	where := "WHERE 1=1"
	args := []interface{}{}
	idx := 1

	if requestType != "" {
		where += fmt.Sprintf(" AND pr.request_type = $%d", idx)
		args = append(args, requestType)
		idx++
	}

	// Scope filtering: use outlet_id OR work_unit_id for scoped roles
	if filterIDs != nil && wuScopeIDs != nil && len(wuScopeIDs) > 0 {
		// Scoped: show purchase requests matching outlet_ids OR work_unit_ids
		if len(filterIDs) > 0 {
			where += fmt.Sprintf(" AND (pr.outlet_id = ANY($%d::text[]) OR pr.work_unit_id = ANY($%d::text[]))", idx, idx+1)
			args = append(args, pq.Array(filterIDs), pq.Array(wuScopeIDs))
			idx += 2
		} else {
			where += fmt.Sprintf(" AND pr.work_unit_id = ANY($%d::text[])", idx)
			args = append(args, pq.Array(wuScopeIDs))
			idx++
		}
	} else if filterIDs != nil && len(filterIDs) > 0 {
		where += fmt.Sprintf(" AND pr.outlet_id = ANY($%d::text[])", idx)
		args = append(args, pq.Array(filterIDs))
		idx++
	} else if filterIDs != nil && len(filterIDs) == 0 {
		// Scoped but no outlets and no work units — return empty
		where += " AND FALSE"
	}
	if workUnitID != "" {
		where += fmt.Sprintf(" AND pr.work_unit_id = $%d", idx)
		args = append(args, workUnitID)
		idx++
	}
	if status != "" {
		where += fmt.Sprintf(" AND pr.status = $%d", idx)
		args = append(args, status)
		idx++
	}

	// Default: only show main requests (not children) unless explicitly filtering for children or parents
	if parentID == "" {
		where += " AND pr.parent_id IS NULL"
	} else if parentID != "all" {
		where += fmt.Sprintf(" AND pr.parent_id = $%d", idx)
		args = append(args, parentID)
		idx++
	}

	if excludeMasters {
		// Exclude all masters — children are shown individually on the payment page
		where += " AND (pr.split_status IS NULL OR pr.split_status != 'master')"
	}

	if search != "" {
		where += fmt.Sprintf(" AND (pr.request_number ILIKE $%d OR pr.vendor_name ILIKE $%d OR EXISTS (SELECT 1 FROM jsonb_array_elements(pr.items) AS item WHERE item->>'name' ILIKE $%d))", idx, idx, idx)
		args = append(args, "%"+search+"%")
		idx++
	}

	// Count
	var total int
	countQ := fmt.Sprintf("SELECT COUNT(*) FROM purchase_requests pr %s", where)
	if err := database.DB.QueryRow(countQ, args...).Scan(&total); err != nil {
		return nil, err
	}

	totalPages := int(math.Ceil(float64(total) / float64(limit)))
	offset := (page - 1) * limit

	// Fetch
	// When excludeMasters is true (payment page), show master's own values because children display separately.
	// Otherwise aggregate child totals for the master row.
	var totalAmountExpr, totalHpsExpr, totalFinalExpr string
	if excludeMasters {
		totalAmountExpr = "pr.total_amount"
		totalHpsExpr = "pr.total_hps"
		totalFinalExpr = "pr.total_final"
	} else {
		totalAmountExpr = "CASE WHEN pr.split_status = 'master' THEN COALESCE((SELECT SUM(c.total_amount) FROM purchase_requests c WHERE c.parent_id = pr.id), pr.total_amount) ELSE pr.total_amount END"
		totalHpsExpr = "CASE WHEN pr.split_status = 'master' THEN COALESCE((SELECT SUM(c.total_hps) FROM purchase_requests c WHERE c.parent_id = pr.id), pr.total_hps) ELSE pr.total_hps END"
		totalFinalExpr = "CASE WHEN pr.split_status = 'master' THEN COALESCE((SELECT SUM(c.total_final) FROM purchase_requests c WHERE c.parent_id = pr.id), pr.total_final) ELSE pr.total_final END"
	}
	query := fmt.Sprintf(`
		SELECT pr.id, pr.request_number, pr.outlet_id, o.name, pr.work_unit_id, COALESCE(wu.name,''),
		       pr.request_type, pr.requested_by, pr.vendor_id, pr.vendor_name, pr.status,
		       pr.items,
		       %s, %s, %s,
		       pr.notes, pr.invoice_number,`, totalAmountExpr, totalHpsExpr, totalFinalExpr)
	query += fmt.Sprintf(`
		       pr.approved_by, pr.approved_at,
		       pr.rejected_reason,
		       pr.paid_by, pr.paid_at, pr.payment_proof,
		       pr.payment_account_dest, pr.payment_account_source, pr.payment_notes,
		       pr.paid_amount,
		       pr.received_by, pr.received_at,
		       pr.parent_id, COALESCE(ppr.request_number,''), pr.split_status,
		       pr.created_at, pr.updated_at
		FROM purchase_requests pr
		LEFT JOIN outlets o ON o.id = pr.outlet_id
		LEFT JOIN work_units wu ON wu.id = pr.work_unit_id
		LEFT JOIN purchase_requests ppr ON ppr.id = pr.parent_id
		%s
		ORDER BY pr.created_at DESC
		LIMIT $%d OFFSET $%d
	`, where, idx, idx+1)
	args = append(args, limit, offset)

	rows, err := database.DB.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	requests := make([]models.PurchaseRequest, 0)
	for rows.Next() {
		var r models.PurchaseRequest
		var itemsJSON []byte
		var approvedAt, paidAt, receivedAt *time.Time
		var createdAt, updatedAt time.Time

		if err := rows.Scan(
			&r.ID, &r.RequestNumber, &r.OutletID, &r.OutletName, &r.WorkUnitID, &r.WorkUnitName,
			&r.RequestType, &r.RequestedBy, &r.VendorID, &r.VendorName, &r.Status,
			&itemsJSON, &r.TotalAmount, &r.TotalHps, &r.TotalFinal, &r.Notes, &r.InvoiceNumber,
			&r.ApprovedBy, &approvedAt,
			&r.RejectedReason,
			&r.PaidBy, &paidAt, &r.PaymentProof,
			&r.PaymentAccountDest, &r.PaymentAccountSource, &r.PaymentNotes,
			&r.PaidAmount,
			&r.ReceivedBy, &receivedAt,
			&r.ParentID, &r.ParentNumber, &r.SplitStatus,
			&createdAt, &updatedAt,
		); err != nil {
			return nil, err
		}

		json.Unmarshal(itemsJSON, &r.Items)
		if r.Items == nil {
			r.Items = []models.PurchaseRequestItem{}
		}

		r.CreatedAt = createdAt.Format(time.RFC3339)
		r.UpdatedAt = updatedAt.Format(time.RFC3339)
		if approvedAt != nil {
			s := approvedAt.Format(time.RFC3339)
			r.ApprovedAt = &s
		}
		if paidAt != nil {
			s := paidAt.Format(time.RFC3339)
			r.PaidAt = &s
		}
		if receivedAt != nil {
			s := receivedAt.Format(time.RFC3339)
			r.ReceivedAt = &s
		}

		requests = append(requests, r)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	return &models.PurchaseRequestListResponse{
		Page:       page,
		Limit:      limit,
		Total:      total,
		TotalPages: totalPages,
		Requests:   requests,
	}, nil
}

func CreatePurchaseRequest(input models.CreatePurchaseRequestInput) (*models.PurchaseRequest, error) {
	id := NewULID()

	// Calculate totals
	var totalHps, totalFinal float64
	for i := range input.Items {
		var itemHps, itemFinal float64
		for j := range input.Items[i].Items {
			input.Items[i].Items[j].HpsSubtotal = float64(input.Items[i].Items[j].Qty) * input.Items[i].Items[j].HpsPrice
			input.Items[i].Items[j].FinalSubtotal = float64(input.Items[i].Items[j].Qty) * input.Items[i].Items[j].FinalPrice
			itemHps += input.Items[i].Items[j].HpsSubtotal
			itemFinal += input.Items[i].Items[j].FinalSubtotal
		}
		input.Items[i].HpsTotal = itemHps
		input.Items[i].FinalTotal = itemFinal
		totalHps += itemHps
		totalFinal += itemFinal
	}
	// total_amount = final if set, otherwise hps
	total := totalFinal
	if total == 0 {
		total = totalHps
	}

	itemsJSON, err := json.Marshal(input.Items)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal items: %w", err)
	}

	now := time.Now().UTC()
	reqNumber, err := generateRequestNumber(now)
	if err != nil {
		return nil, fmt.Errorf("gagal generate nomor pengajuan: %w", err)
	}
	_, err = database.DB.Exec(`
		INSERT INTO purchase_requests (id, request_number, outlet_id, work_unit_id, request_type, requested_by, vendor_id, vendor_name, status, items, total_amount, total_hps, total_final, notes, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'pending', $9, $10, $11, $12, $13, $14, $14)
	`, id, reqNumber, nilIfEmpty(input.OutletID), nilIfEmpty(input.WorkUnitID), input.RequestType, input.RequestedBy, nilIfEmpty(input.VendorID), input.VendorName, itemsJSON, total, totalHps, totalFinal, input.Notes, now)
	if err != nil {
		return nil, err
	}

	return GetPurchaseRequest(id)
}

func GetPurchaseRequest(id string) (*models.PurchaseRequest, error) {
	var r models.PurchaseRequest
	var itemsJSON []byte
	var approvedAt, paidAt, receivedAt *time.Time
	var createdAt, updatedAt time.Time

	err := database.DB.QueryRow(`
		SELECT pr.id, pr.request_number, pr.outlet_id, o.name, pr.work_unit_id, COALESCE(wu.name,''),
		       pr.request_type, pr.requested_by, pr.vendor_id, pr.vendor_name, pr.status,
		       pr.items, pr.total_amount, pr.total_hps, pr.total_final, pr.notes, pr.invoice_number,
		       pr.approved_by, pr.approved_at,
		       pr.rejected_reason,
		       pr.paid_by, pr.paid_at, pr.payment_proof,
		       pr.payment_account_dest, pr.payment_account_source, pr.payment_notes,
		       pr.paid_amount,
		       pr.received_by, pr.received_at,
		       pr.parent_id, COALESCE(ppr.request_number,''), pr.split_status,
		       pr.created_at, pr.updated_at
		FROM purchase_requests pr
		LEFT JOIN outlets o ON o.id = pr.outlet_id
		LEFT JOIN work_units wu ON wu.id = pr.work_unit_id
		LEFT JOIN purchase_requests ppr ON ppr.id = pr.parent_id
		WHERE pr.id = $1
	`, id).Scan(
		&r.ID, &r.RequestNumber, &r.OutletID, &r.OutletName, &r.WorkUnitID, &r.WorkUnitName,
		&r.RequestType, &r.RequestedBy, &r.VendorID, &r.VendorName, &r.Status,
		&itemsJSON, &r.TotalAmount, &r.TotalHps, &r.TotalFinal, &r.Notes, &r.InvoiceNumber,
		&r.ApprovedBy, &approvedAt,
		&r.RejectedReason,
		&r.PaidBy, &paidAt, &r.PaymentProof,
		&r.PaymentAccountDest, &r.PaymentAccountSource, &r.PaymentNotes,
		&r.PaidAmount,
		&r.ReceivedBy, &receivedAt,
		&r.ParentID, &r.ParentNumber, &r.SplitStatus,
		&createdAt, &updatedAt,
	)
	if err != nil {
		return nil, err
	}

	json.Unmarshal(itemsJSON, &r.Items)
	if r.Items == nil {
		r.Items = []models.PurchaseRequestItem{}
	}

	// If this is a master, fetch children and recalc totals from children
	if r.SplitStatus != nil && *r.SplitStatus == "master" {
		children, err := getPurchaseChildren(id)
		if err == nil {
			r.Children = children
			if len(children) > 0 {
				// Totals = sum of all children (master items are the original document)
				var sumAmount, sumHps, sumFinal float64
				for _, ch := range children {
					sumAmount += ch.TotalAmount
					sumHps += ch.TotalHps
					sumFinal += ch.TotalFinal
				}
				r.TotalAmount = sumAmount
				r.TotalHps = sumHps
				r.TotalFinal = sumFinal
			}
		}
	}

	r.CreatedAt = createdAt.Format(time.RFC3339)
	r.UpdatedAt = updatedAt.Format(time.RFC3339)
	if approvedAt != nil {
		s := approvedAt.Format(time.RFC3339)
		r.ApprovedAt = &s
	}
	if paidAt != nil {
		s := paidAt.Format(time.RFC3339)
		r.PaidAt = &s
	}
	if receivedAt != nil {
		s := receivedAt.Format(time.RFC3339)
		r.ReceivedAt = &s
	}

	return &r, nil
}

// getPurchaseChildren fetches all split children for a master request.
func getPurchaseChildren(parentID string) ([]models.PurchaseRequest, error) {
	rows, err := database.DB.Query(`
		SELECT pr.id, pr.request_number, pr.outlet_id, o.name, pr.work_unit_id, COALESCE(wu.name,''),
		       pr.request_type, pr.requested_by, pr.vendor_id, pr.vendor_name, pr.status,
		pr.items, pr.total_amount, pr.total_hps, pr.total_final, pr.notes, pr.invoice_number,
		       pr.approved_by, pr.approved_at,
		       pr.rejected_reason,
		       pr.paid_by, pr.paid_at, pr.payment_proof,
		       pr.payment_account_dest, pr.payment_account_source, pr.payment_notes,
		       pr.paid_amount,
		       pr.received_by, pr.received_at,
		       pr.parent_id, COALESCE(ppr.request_number,''), pr.split_status,
		       pr.created_at, pr.updated_at
		FROM purchase_requests pr
		LEFT JOIN outlets o ON o.id = pr.outlet_id
		LEFT JOIN work_units wu ON wu.id = pr.work_unit_id
		LEFT JOIN purchase_requests ppr ON ppr.id = pr.parent_id
		WHERE pr.parent_id = $1
		ORDER BY pr.created_at ASC
	`, parentID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	children := make([]models.PurchaseRequest, 0)
	for rows.Next() {
		var r models.PurchaseRequest
		var itemsJSON []byte
		var approvedAt, paidAt, receivedAt *time.Time
		var createdAt, updatedAt time.Time

		if err := rows.Scan(
			&r.ID, &r.RequestNumber, &r.OutletID, &r.OutletName, &r.WorkUnitID, &r.WorkUnitName,
			&r.RequestType, &r.RequestedBy, &r.VendorID, &r.VendorName, &r.Status,
			&itemsJSON, &r.TotalAmount, &r.TotalHps, &r.TotalFinal, &r.Notes, &r.InvoiceNumber,
			&r.ApprovedBy, &approvedAt,
			&r.RejectedReason,
			&r.PaidBy, &paidAt, &r.PaymentProof,
			&r.PaymentAccountDest, &r.PaymentAccountSource, &r.PaymentNotes,
			&r.PaidAmount,
			&r.ReceivedBy, &receivedAt,
			&r.ParentID, &r.ParentNumber, &r.SplitStatus,
			&createdAt, &updatedAt,
		); err != nil {
			return nil, err
		}

		json.Unmarshal(itemsJSON, &r.Items)
		if r.Items == nil {
			r.Items = []models.PurchaseRequestItem{}
		}

		r.CreatedAt = createdAt.Format(time.RFC3339)
		r.UpdatedAt = updatedAt.Format(time.RFC3339)
		if approvedAt != nil {
			s := approvedAt.Format(time.RFC3339)
			r.ApprovedAt = &s
		}
		if paidAt != nil {
			s := paidAt.Format(time.RFC3339)
			r.PaidAt = &s
		}
		if receivedAt != nil {
			s := receivedAt.Format(time.RFC3339)
			r.ReceivedAt = &s
		}

		children = append(children, r)
	}
	return children, nil
}

func SplitPurchaseRequest(parentID string, input models.SplitPurchaseRequestInput) (*models.PurchaseRequest, error) {
	tx, err := database.DB.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	now := time.Now().UTC()

	// 1. Get parent PR details
	var p models.PurchaseRequest
	var itemsJSON []byte
	err = tx.QueryRow(`
		SELECT outlet_id, work_unit_id, request_type, requested_by, items, total_hps, total_final, status, request_number
		FROM purchase_requests WHERE id = $1
	`, parentID).Scan(&p.OutletID, &p.WorkUnitID, &p.RequestType, &p.RequestedBy, &itemsJSON, &p.TotalHps, &p.TotalFinal, &p.Status, &p.RequestNumber)
	if err != nil {
		return nil, fmt.Errorf("pengajuan induk tidak ditemukan")
	}

	if p.Status != "approved" && p.Status != "pending" {
		return nil, fmt.Errorf("hanya pengajuan yang sudah disetujui atau pending yang bisa di-split vendor")
	}

	var parentItems []models.PurchaseRequestItem
	json.Unmarshal(itemsJSON, &parentItems)

	// 2. Identify items to move and remaining items (Sub-item level)
	var groupsToMove []models.PurchaseRequestItem
	var groupsRemaining []models.PurchaseRequestItem

	for _, pGroup := range parentItems {
		var subItemsToMove []models.PurchaseSubItem
		var subItemsRemaining []models.PurchaseSubItem

		for _, pSub := range pGroup.Items {
			foundInInput := false
			// Check if this specific sub-item is in the input to be moved
			for _, inputGroup := range input.Items {
				if inputGroup.Name == pGroup.Name {
					for _, inputSub := range inputGroup.Items {
						if inputSub.Name == pSub.Name {
							subItemsToMove = append(subItemsToMove, pSub)
							foundInInput = true
							break
						}
					}
				}
				if foundInInput {
					break
				}
			}

			if !foundInInput {
				subItemsRemaining = append(subItemsRemaining, pSub)
			}
		}

		// If we found sub-items to move in this group, create a group for child PR
		if len(subItemsToMove) > 0 {
			newGroup := pGroup
			newGroup.Items = subItemsToMove
			// Recalculate group totals for the moved group
			var hps, final float64
			for _, s := range subItemsToMove {
				hps += float64(s.Qty) * s.HpsPrice
				final += float64(s.Qty) * s.FinalPrice
			}
			newGroup.HpsTotal = hps
			newGroup.FinalTotal = final
			groupsToMove = append(groupsToMove, newGroup)
		}

		// If there are sub-items left in this group, keep them in parent PR
		if len(subItemsRemaining) > 0 {
			remGroup := pGroup
			remGroup.Items = subItemsRemaining
			// Recalculate group totals for the remaining group
			var hps, final float64
			for _, s := range subItemsRemaining {
				hps += float64(s.Qty) * s.HpsPrice
				final += float64(s.Qty) * s.FinalPrice
			}
			remGroup.HpsTotal = hps
			remGroup.FinalTotal = final
			groupsRemaining = append(groupsRemaining, remGroup)
		}
	}

	if len(groupsToMove) == 0 {
		return nil, fmt.Errorf("tidak ada item valid yang dipilih untuk di-split")
	}

	// 3. Create Child PR
	childID := NewULID()
	var childHps, childFinal float64
	for _, g := range groupsToMove {
		childHps += g.HpsTotal
		childFinal += g.FinalTotal
	}
	childTotal := childFinal
	if childTotal == 0 {
		childTotal = childHps
	}

	childItemsJSON, _ := json.Marshal(groupsToMove)
	childNumber, err := generateRequestNumber(now)
	if err != nil {
		return nil, fmt.Errorf("gagal generate nomor pengajuan: %w", err)
	}
	_, err = tx.Exec(`
		INSERT INTO purchase_requests (id, request_number, parent_id, outlet_id, work_unit_id, request_type, requested_by, vendor_id, vendor_name, status, items, total_amount, total_hps, total_final, notes, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $16)
	`, childID, childNumber, parentID, p.OutletID, p.WorkUnitID, p.RequestType, p.RequestedBy, nilIfEmpty(input.VendorID), input.VendorName, p.Status, childItemsJSON, childTotal, childHps, childFinal, "", now)
	if err != nil {
		return nil, fmt.Errorf("gagal membuat pengajuan pecahan: %w", err)
	}

	// 4. Update Parent PR: keep all original items, just set master status
	// Items stay in master as the "original document". Children have copies.
	masterStatus := "master"
	_, err = tx.Exec(`
		UPDATE purchase_requests SET split_status=$1, updated_at=$2 WHERE id=$3
	`, masterStatus, now, parentID)
	if err != nil {
		return nil, fmt.Errorf("gagal memperbarui pengajuan induk: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return nil, err
	}

	return GetPurchaseRequest(parentID)
}

func UpdatePurchaseStatus(id string, input models.UpdatePurchaseStatusInput) (*models.PurchaseRequest, error) {
	// Get current status and split_status
	var currentStatus string
	var splitStatus *string
	err := database.DB.QueryRow("SELECT status, split_status FROM purchase_requests WHERE id = $1", id).Scan(&currentStatus, &splitStatus)
	if err != nil {
		return nil, fmt.Errorf("pengajuan tidak ditemukan")
	}

	transitions, ok := validTransitions[input.Action]
	if !ok {
		return nil, fmt.Errorf("aksi '%s' tidak valid", input.Action)
	}

	// If this is a master with children, cascade certain actions to children
	isMaster := splitStatus != nil && *splitStatus == "master"
	if isMaster {
		switch input.Action {
		case "pay":
			// Allow pay on master only if it still has its own items (not fully split)
			var totalFinal float64
			database.DB.QueryRow("SELECT COALESCE(total_final, 0) FROM purchase_requests WHERE id = $1", id).Scan(&totalFinal)
			if totalFinal <= 0 {
				return nil, fmt.Errorf("pembayaran master tidak diizinkan, bayar per vendor melalui halaman Pembayaran")
			}
			// Fall through to normal pay flow for this master's own items
		case "request_payment", "approve", "cancel":
			return cascadeStatusToChildren(id, currentStatus, input)
		}
	}

	newStatus, ok := transitions[currentStatus]
	if !ok {
		return nil, fmt.Errorf("tidak bisa %s dari status '%s'", input.Action, currentStatus)
	}

	return applyStatusUpdate(id, newStatus, input)
}

// cascadeStatusToChildren applies a status action to all children of a master PR.
func cascadeStatusToChildren(masterID, masterStatus string, input models.UpdatePurchaseStatusInput) (*models.PurchaseRequest, error) {
	transitions, _ := validTransitions[input.Action]
	newStatus, ok := transitions[masterStatus]
	if !ok {
		return nil, fmt.Errorf("tidak bisa %s dari status '%s'", input.Action, masterStatus)
	}

	// Get all children
	rows, err := database.DB.Query("SELECT id, status FROM purchase_requests WHERE parent_id = $1", masterID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	type child struct {
		id, status string
	}
	var children []child
	for rows.Next() {
		var c child
		rows.Scan(&c.id, &c.status)
		children = append(children, c)
	}

	// Apply to each eligible child
	for _, c := range children {
		if _, valid := transitions[c.status]; !valid {
			continue // skip children that can't transition
		}

		// For request_payment on children, validate total_final > 0
		if input.Action == "request_payment" {
			var totalFinal float64
			database.DB.QueryRow("SELECT COALESCE(total_final, 0) FROM purchase_requests WHERE id = $1", c.id).Scan(&totalFinal)
			if totalFinal <= 0 {
				continue // skip children without final price
			}
		}

		if _, err := applyStatusUpdate(c.id, newStatus, input); err != nil {
			return nil, fmt.Errorf("gagal update child %s: %w", c.id, err)
		}
	}

	// Also update master status
	if _, err := applyStatusUpdate(masterID, newStatus, input); err != nil {
		return nil, err
	}

	return GetPurchaseRequest(masterID)
}

// applyStatusUpdate performs the actual DB update for a single purchase request.
func applyStatusUpdate(id, newStatus string, input models.UpdatePurchaseStatusInput) (*models.PurchaseRequest, error) {
	now := time.Now().UTC()
	var err error

	switch input.Action {
	case "approve":
		_, err = database.DB.Exec(
			"UPDATE purchase_requests SET status=$1, approved_by=$2, approved_at=$3, updated_at=$3 WHERE id=$4",
			newStatus, input.ActorName, now, id,
		)
	case "reject":
		_, err = database.DB.Exec(
			"UPDATE purchase_requests SET status=$1, rejected_reason=$2, approved_by=$3, approved_at=$4, updated_at=$4 WHERE id=$5",
			newStatus, input.RejectedReason, input.ActorName, now, id,
		)
	case "request_payment":
		var totalFinal float64
		var splitStatus *string
		if scanErr := database.DB.QueryRow("SELECT COALESCE(total_final, 0), split_status FROM purchase_requests WHERE id = $1", id).Scan(&totalFinal, &splitStatus); scanErr != nil {
			return nil, fmt.Errorf("gagal memeriksa total harga")
		}
		// For masters, check sum of children's total_final
		if splitStatus != nil && *splitStatus == "master" {
			database.DB.QueryRow("SELECT COALESCE(SUM(total_final), 0) FROM purchase_requests WHERE parent_id = $1", id).Scan(&totalFinal)
		}
		if totalFinal <= 0 {
			return nil, fmt.Errorf("harga final belum diisi, tidak bisa mengajukan pembayaran")
		}
		_, err = database.DB.Exec(
			"UPDATE purchase_requests SET status=$1, updated_at=$2 WHERE id=$3",
			newStatus, now, id,
		)
	case "pay":
		// Determine payment amount
		var totalFinal, currentPaid float64
		database.DB.QueryRow("SELECT COALESCE(total_final,0), COALESCE(paid_amount,0) FROM purchase_requests WHERE id=$1", id).Scan(&totalFinal, &currentPaid)
		remaining := totalFinal - currentPaid

		if remaining <= 0 {
			return nil, fmt.Errorf("tagihan sudah lunas")
		}

		payAmount := input.PaymentAmount
		if payAmount <= 0 {
			payAmount = remaining // default: pay full remaining
		}
		if payAmount > remaining {
			return nil, fmt.Errorf("jumlah bayar (%.0f) melebihi sisa tagihan (%.0f)", payAmount, remaining)
		}

		// Round to 2 decimals
		payAmount = math.Round(payAmount*100) / 100
		newPaid := math.Round((currentPaid+payAmount)*100) / 100

		// Insert payment history
		phID := NewULID()
		_, err = database.DB.Exec(
			`INSERT INTO payment_histories (id, purchase_request_id, amount, payment_proof, payment_account_dest, payment_account_source, payment_notes, paid_by, created_at)
			 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
			phID, id, payAmount, input.PaymentProof,
			input.PaymentAccountDest, input.PaymentAccountSource, input.PaymentNotes,
			input.ActorName, now,
		)
		if err != nil {
			return nil, fmt.Errorf("gagal menyimpan histori pembayaran: %w", err)
		}

		// Determine new status
		actualStatus := "partial"
		if newPaid >= totalFinal {
			actualStatus = "paid"
		}

		_, err = database.DB.Exec(
			`UPDATE purchase_requests SET status=$1, paid_by=$2, paid_at=$3, payment_proof=$4,
			 payment_account_dest=$5, payment_account_source=$6, payment_notes=$7,
			 paid_amount=$8, updated_at=$3 WHERE id=$9`,
			actualStatus, input.ActorName, now, input.PaymentProof,
			input.PaymentAccountDest, input.PaymentAccountSource, input.PaymentNotes,
			newPaid, id,
		)
	case "receive":
		_, err = database.DB.Exec(
			"UPDATE purchase_requests SET status=$1, received_by=$2, received_at=$3, updated_at=$3 WHERE id=$4",
			newStatus, input.ActorName, now, id,
		)
	case "cancel":
		_, err = database.DB.Exec(
			"UPDATE purchase_requests SET status=$1, rejected_reason=$2, updated_at=$3 WHERE id=$4",
			newStatus, input.RejectedReason, now, id,
		)
	}

	if err != nil {
		return nil, err
	}

	// After updating a child, sync the master's status based on all children
	syncMasterStatusFromChild(id)

	return GetPurchaseRequest(id)
}

// syncMasterStatusFromChild checks if a purchase request has a parent (master),
// and if all siblings are paid/received, updates the master status accordingly.
func syncMasterStatusFromChild(childID string) {
	var parentID *string
	database.DB.QueryRow("SELECT parent_id FROM purchase_requests WHERE id = $1", childID).Scan(&parentID)
	if parentID == nil || *parentID == "" {
		return
	}

	// Count children by status
	var total, paidOrReceived, partial int
	rows, err := database.DB.Query("SELECT status FROM purchase_requests WHERE parent_id = $1", *parentID)
	if err != nil {
		return
	}
	defer rows.Close()
	for rows.Next() {
		var s string
		rows.Scan(&s)
		total++
		if s == "paid" || s == "received" {
			paidOrReceived++
		} else if s == "partial" {
			partial++
		}
	}
	if total == 0 {
		return
	}

	now := time.Now().UTC()
	if paidOrReceived == total {
		// All children fully paid/received → master = paid
		database.DB.Exec("UPDATE purchase_requests SET status = 'paid', updated_at = $1 WHERE id = $2 AND status NOT IN ('paid','received')", now, *parentID)
	} else if paidOrReceived+partial > 0 && paidOrReceived+partial == total {
		// All children are at least partial → master = partial
		database.DB.Exec("UPDATE purchase_requests SET status = 'partial', updated_at = $1 WHERE id = $2 AND status NOT IN ('paid','received','partial')", now, *parentID)
	}
}

func UpdatePurchaseItems(id string, input models.UpdatePurchaseItemsInput) (*models.PurchaseRequest, error) {
	var currentStatus string
	err := database.DB.QueryRow("SELECT status FROM purchase_requests WHERE id = $1", id).Scan(&currentStatus)
	if err != nil {
		return nil, fmt.Errorf("pengajuan tidak ditemukan")
	}
	if currentStatus != "pending" && currentStatus != "approved" {
		return nil, fmt.Errorf("hanya bisa update item pada status pending/approved")
	}

	var totalHps, totalFinal float64
	for i := range input.Items {
		var itemHps, itemFinal float64
		for j := range input.Items[i].Items {
			input.Items[i].Items[j].HpsSubtotal = float64(input.Items[i].Items[j].Qty) * input.Items[i].Items[j].HpsPrice
			input.Items[i].Items[j].FinalSubtotal = float64(input.Items[i].Items[j].Qty) * input.Items[i].Items[j].FinalPrice
			itemHps += input.Items[i].Items[j].HpsSubtotal
			itemFinal += input.Items[i].Items[j].FinalSubtotal
		}
		input.Items[i].HpsTotal = itemHps
		input.Items[i].FinalTotal = itemFinal
		totalHps += itemHps
		totalFinal += itemFinal
	}
	total := totalFinal
	if total == 0 {
		total = totalHps
	}

	itemsJSON, err := json.Marshal(input.Items)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal items: %w", err)
	}

	_, err = database.DB.Exec(`
		UPDATE purchase_requests SET items=$1, total_amount=$2, total_hps=$3, total_final=$4, vendor_id=$5, vendor_name=$6, invoice_number=$7, updated_at=NOW() WHERE id=$8
	`, itemsJSON, total, totalHps, totalFinal, nilIfEmpty(input.VendorID), input.VendorName, input.InvoiceNumber, id)
	if err != nil {
		return nil, err
	}

	return GetPurchaseRequest(id)
}

func DeletePurchaseRequest(id string, isAdmin bool) error {
	var status string
	var splitStatus *string
	err := database.DB.QueryRow("SELECT status, split_status FROM purchase_requests WHERE id = $1", id).Scan(&status, &splitStatus)
	if err != nil {
		return fmt.Errorf("pengajuan tidak ditemukan")
	}

	if isAdmin {
		// Admin bisa hapus semua kecuali yang sudah dibayar
		if status == "paid" {
			return fmt.Errorf("tidak bisa menghapus pengajuan yang sudah dibayar")
		}
		// Jika master, cek apakah ada anak yang sudah dibayar
		if splitStatus != nil && *splitStatus == "master" {
			var paidCount int
			err = database.DB.QueryRow("SELECT COUNT(*) FROM purchase_requests WHERE parent_id = $1 AND status = 'paid'", id).Scan(&paidCount)
			if err != nil {
				return fmt.Errorf("gagal memeriksa status pecahan")
			}
			if paidCount > 0 {
				return fmt.Errorf("tidak bisa menghapus pengajuan induk karena ada pecahan yang sudah dibayar")
			}
			// Hapus semua anak dulu
			_, err = database.DB.Exec("DELETE FROM purchase_requests WHERE parent_id = $1", id)
			if err != nil {
				return fmt.Errorf("gagal menghapus pecahan: %w", err)
			}
		}
	} else {
		if status != "pending" && status != "rejected" && status != "cancelled" {
			return fmt.Errorf("hanya bisa menghapus pengajuan berstatus pending/rejected/cancelled")
		}
	}

	_, err = database.DB.Exec("DELETE FROM purchase_requests WHERE id = $1", id)
	return err
}

// GetPaymentHistories returns all payment history entries for a purchase request.
func GetPaymentHistories(purchaseRequestID string) ([]models.PaymentHistory, error) {
	rows, err := database.DB.Query(`
		SELECT id, purchase_request_id, amount, payment_proof,
		       payment_account_dest, payment_account_source, payment_notes,
		       paid_by, created_at
		FROM payment_histories
		WHERE purchase_request_id = $1
		ORDER BY created_at ASC
	`, purchaseRequestID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	histories := make([]models.PaymentHistory, 0)
	for rows.Next() {
		var h models.PaymentHistory
		var createdAt time.Time
		if err := rows.Scan(&h.ID, &h.PurchaseRequestID, &h.Amount, &h.PaymentProof,
			&h.PaymentAccountDest, &h.PaymentAccountSource, &h.PaymentNotes,
			&h.PaidBy, &createdAt); err != nil {
			return nil, err
		}
		h.CreatedAt = createdAt.Format(time.RFC3339)
		histories = append(histories, h)
	}
	return histories, nil
}
