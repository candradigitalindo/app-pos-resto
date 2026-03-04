package services

import (
	"cloud-api-pos/database"
	"cloud-api-pos/models"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/oklog/ulid/v2"
	"golang.org/x/crypto/bcrypt"
)

// ── Helpers ─────────────────────────────────────────────────

var (
	entropyMu sync.Mutex
	entropy   = ulid.Monotonic(rand.Reader, 0)
)

func NewULID() string {
	entropyMu.Lock()
	defer entropyMu.Unlock()
	t := time.Now().UTC()
	id, err := ulid.New(ulid.Timestamp(t), entropy)
	if err != nil {
		// Reset entropy on overflow
		entropy = ulid.Monotonic(rand.Reader, 0)
		id = ulid.MustNew(ulid.Timestamp(t), entropy)
	}
	return id.String()
}

func GenerateAPIKey() string {
	b := make([]byte, 32)
	rand.Read(b)
	return "pos_" + hex.EncodeToString(b)
}

// normalizeSyncFields mengkonversi field names dari POS trigger ke cloud model
// POS trigger menggunakan nama kolom SQLite, cloud model pakai nama JSON sendiri
func normalizeSyncFields(data map[string]interface{}, entityType string) {
	if data == nil {
		return
	}

	// Universal: id → local_id (semua entity)
	if _, ok := data["local_id"]; !ok {
		if id, ok := data["id"]; ok {
			data["local_id"] = id
		}
	}

	switch entityType {
	case "order":
		// order_status → status
		if _, ok := data["status"]; !ok {
			if v, ok := data["order_status"]; ok {
				data["status"] = v
			}
		}
		// created_by → customer_name (sebagai fallback jika customer_name kosong)
		if _, ok := data["customer_name"]; !ok {
			if v, ok := data["created_by"]; ok {
				data["customer_name"] = v
			}
		}
		// Pastikan created_at ada (dari trigger mungkin tidak ada)
		if _, ok := data["created_at"]; !ok {
			data["created_at"] = time.Now().UTC().Format(time.RFC3339)
		}
		if _, ok := data["updated_at"]; !ok {
			data["updated_at"] = time.Now().UTC().Format(time.RFC3339)
		}

	case "transaction":
		// transaction_date → created_at
		if _, ok := data["created_at"]; !ok {
			if v, ok := data["transaction_date"]; ok {
				data["created_at"] = v
			}
		}
		// created_by → cashier_name
		if _, ok := data["cashier_name"]; !ok {
			if v, ok := data["created_by"]; ok {
				data["cashier_name"] = v
			}
		}
	}
}

// ── Outlet Service ──────────────────────────────────────────

func CreateOutlet(req models.CreateOutletRequest) (*models.Outlet, error) {
	apiKey := GenerateAPIKey()
	outlet := &models.Outlet{}
	id := NewULID()

	err := database.DB.QueryRow(
		`INSERT INTO outlets (id, code, name, address, api_key, webhook_url)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, code, name, address, api_key, webhook_url, is_active, created_at, updated_at`,
		id, req.Code, req.Name, req.Address, apiKey, req.WebhookURL,
	).Scan(&outlet.ID, &outlet.Code, &outlet.Name, &outlet.Address,
		&outlet.APIKey, &outlet.WebhookURL, &outlet.IsActive,
		&outlet.CreatedAt, &outlet.UpdatedAt)

	if err != nil {
		return nil, err
	}
	return outlet, nil
}

func GetOutlets() ([]models.Outlet, error) {
	rows, err := database.DB.Query(
		`SELECT id, code, name, address, webhook_url, is_active, created_at, updated_at
		FROM outlets ORDER BY created_at DESC`,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	outlets := make([]models.Outlet, 0)
	for rows.Next() {
		var o models.Outlet
		if err := rows.Scan(&o.ID, &o.Code, &o.Name, &o.Address,
			&o.WebhookURL, &o.IsActive, &o.CreatedAt, &o.UpdatedAt); err != nil {
			return nil, err
		}
		outlets = append(outlets, o)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return outlets, nil
}

func GetOutlet(id string) (*models.Outlet, error) {
	o := &models.Outlet{}
	err := database.DB.QueryRow(
		`SELECT TRIM(id), code, name, COALESCE(address,''), COALESCE(webhook_url,''), is_active, created_at, updated_at
		FROM outlets WHERE TRIM(id) = $1`, strings.TrimSpace(id),
	).Scan(&o.ID, &o.Code, &o.Name, &o.Address,
		&o.WebhookURL, &o.IsActive, &o.CreatedAt, &o.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return o, nil
}

func RegenerateAPIKey(id string) (string, error) {
	newKey := GenerateAPIKey()
	result, err := database.DB.Exec(
		`UPDATE outlets SET api_key = $1, updated_at = NOW() WHERE id = $2`,
		newKey, id,
	)
	if err != nil {
		return "", err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return "", fmt.Errorf("outlet not found")
	}
	return newKey, nil
}

func ToggleOutlet(id string) (*models.Outlet, error) {
	o := &models.Outlet{}
	err := database.DB.QueryRow(
		`UPDATE outlets SET is_active = NOT is_active, updated_at = NOW()
		WHERE id = $1
		RETURNING id, code, name, address, webhook_url, is_active, created_at, updated_at`,
		id,
	).Scan(&o.ID, &o.Code, &o.Name, &o.Address,
		&o.WebhookURL, &o.IsActive, &o.CreatedAt, &o.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return o, nil
}

// ── Order Service ───────────────────────────────────────────

func SaveOrder(outletID string, req models.PushOrderRequest) (string, error) {
	itemsJSON, _ := json.Marshal(req.Items)
	paymentJSON, _ := json.Marshal(req.PaymentInfo)

	// id = local_id (ID sama di POS dan Cloud)
	cloudID := req.LocalID
	if cloudID == "" {
		cloudID = NewULID()
	}
	err := database.DB.QueryRow(
		`INSERT INTO cloud_orders (id, local_id, outlet_id, outlet_code, table_number,
			customer_name, pax, total_amount, status, items, payment_info, version,
			created_at, updated_at, synced_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, NOW())
		ON CONFLICT (outlet_id, local_id) DO UPDATE SET
			id = EXCLUDED.id,
			table_number = EXCLUDED.table_number,
			customer_name = EXCLUDED.customer_name,
			pax = EXCLUDED.pax,
			total_amount = EXCLUDED.total_amount,
			status = EXCLUDED.status,
			items = EXCLUDED.items,
			payment_info = EXCLUDED.payment_info,
			version = EXCLUDED.version,
			updated_at = EXCLUDED.updated_at,
			synced_at = NOW()
		RETURNING id`,
		cloudID, cloudID, outletID, req.OutletCode, req.TableNumber,
		req.CustomerName, req.Pax, req.TotalAmount, req.Status,
		string(itemsJSON), string(paymentJSON), req.Version,
		parseTime(req.CreatedAt), parseTime(req.UpdatedAt),
	).Scan(&cloudID)

	if err != nil {
		return "", err
	}

	go logSync(outletID, "push_order", "order", 1, "success", "")
	return cloudID, nil
}

func GetOrders(outletID string, page, limit int) ([]models.CloudOrder, int, error) {
	offset := (page - 1) * limit
	var total int
	database.DB.QueryRow("SELECT COUNT(*) FROM cloud_orders WHERE outlet_id = $1", outletID).Scan(&total)

	rows, err := database.DB.Query(
		`SELECT id, local_id, outlet_id, outlet_code, COALESCE(table_number,''),
			COALESCE(customer_name,''), pax, total_amount, status,
			COALESCE(items::text,'[]'), COALESCE(payment_info::text,'{}'),
			version, created_at, updated_at, synced_at
		FROM cloud_orders WHERE outlet_id = $1
		ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
		outletID, limit, offset,
	)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	orders := make([]models.CloudOrder, 0)
	for rows.Next() {
		var o models.CloudOrder
		if err := rows.Scan(&o.ID, &o.LocalID, &o.OutletID, &o.OutletCode,
			&o.TableNumber, &o.CustomerName, &o.Pax, &o.TotalAmount, &o.Status,
			&o.Items, &o.PaymentInfo, &o.Version, &o.CreatedAt, &o.UpdatedAt, &o.SyncedAt); err != nil {
			return nil, 0, err
		}
		orders = append(orders, o)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, err
	}
	return orders, total, nil
}

// ── Transaction Service ─────────────────────────────────────

func SaveTransaction(outletID string, req models.PushTransactionRequest) (string, error) {
	// id = local_id (ID sama di POS dan Cloud)
	cloudID := req.LocalID
	if cloudID == "" {
		cloudID = NewULID()
	}

	// Serialize items ke JSON
	itemsJSON := "[]"
	if len(req.Items) > 0 {
		b, _ := json.Marshal(req.Items)
		itemsJSON = string(b)
	}

	err := database.DB.QueryRow(
		`INSERT INTO cloud_transactions (id, local_id, outlet_id, outlet_code, order_id,
			total_amount, payment_method, cash_amount, change_amount, cashier_name,
			items, version, created_at, synced_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, NOW())
		ON CONFLICT (outlet_id, local_id) DO UPDATE SET
			id = EXCLUDED.id,
			total_amount = EXCLUDED.total_amount,
			payment_method = EXCLUDED.payment_method,
			cash_amount = EXCLUDED.cash_amount,
			change_amount = EXCLUDED.change_amount,
			cashier_name = EXCLUDED.cashier_name,
			items = EXCLUDED.items,
			version = EXCLUDED.version,
			synced_at = NOW()
		RETURNING id`,
		cloudID, cloudID, outletID, req.OutletCode, req.OrderID,
		req.TotalAmount, req.PaymentMethod, req.CashAmount,
		req.ChangeAmount, req.CashierName, itemsJSON, req.Version,
		parseTime(req.CreatedAt),
	).Scan(&cloudID)

	if err != nil {
		return "", err
	}

	go logSync(outletID, "push_transaction", "transaction", 1, "success", "")
	return cloudID, nil
}

func GetTransactions(outletID string, page, limit int) ([]models.CloudTransaction, int, error) {
	offset := (page - 1) * limit
	var total int
	database.DB.QueryRow("SELECT COUNT(*) FROM cloud_transactions WHERE outlet_id = $1", outletID).Scan(&total)

	rows, err := database.DB.Query(
		`SELECT id, local_id, outlet_id, outlet_code, COALESCE(order_id,''),
			total_amount, COALESCE(payment_method,''), cash_amount, change_amount,
			COALESCE(cashier_name,''), COALESCE(items::text,'[]'), version, created_at, synced_at
		FROM cloud_transactions WHERE outlet_id = $1
		ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
		outletID, limit, offset,
	)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	txns := make([]models.CloudTransaction, 0)
	for rows.Next() {
		var t models.CloudTransaction
		if err := rows.Scan(&t.ID, &t.LocalID, &t.OutletID, &t.OutletCode,
			&t.OrderID, &t.TotalAmount, &t.PaymentMethod, &t.CashAmount,
			&t.ChangeAmount, &t.CashierName, &t.Items, &t.Version, &t.CreatedAt, &t.SyncedAt); err != nil {
			return nil, 0, err
		}
		txns = append(txns, t)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, err
	}
	return txns, total, nil
}

// ── Product Service ─────────────────────────────────────────

func SaveProduct(outletID string, req models.PushProductRequest) (string, error) {
	// Gunakan POS local_id sebagai cloud id agar ID produk sama di POS dan Cloud
	cloudID := req.LocalID
	err := database.DB.QueryRow(
		`INSERT INTO cloud_products (id, local_id, outlet_id, name, category_id,
			category_name, price, stock, destination, version, updated_at, synced_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NOW())
		ON CONFLICT (outlet_id, local_id) DO UPDATE SET
			id = EXCLUDED.id,
			name = EXCLUDED.name,
			category_id = EXCLUDED.category_id,
			category_name = EXCLUDED.category_name,
			price = EXCLUDED.price,
			stock = EXCLUDED.stock,
			destination = EXCLUDED.destination,
			version = EXCLUDED.version,
			updated_at = EXCLUDED.updated_at,
			synced_at = NOW()
		RETURNING id`,
		cloudID, cloudID, outletID, req.Name, req.CategoryID,
		req.CategoryName, req.Price, req.Stock, req.Destination,
		req.Version, parseTime(req.UpdatedAt),
	).Scan(&cloudID)

	if err != nil {
		return "", err
	}

	go logSync(outletID, "push_product", "product", 1, "success", "")
	return cloudID, nil
}

func GetProducts(outletID string, page, limit int) ([]models.CloudProduct, int, error) {
	offset := (page - 1) * limit
	var total int
	database.DB.QueryRow("SELECT COUNT(*) FROM cloud_products WHERE outlet_id = $1 AND is_deleted = false", outletID).Scan(&total)

	rows, err := database.DB.Query(
		`SELECT id, local_id, outlet_id, name, COALESCE(category_id,''),
			COALESCE(category_name,''), price, stock, COALESCE(destination,''),
			is_deleted, version, created_at, updated_at, synced_at
		FROM cloud_products WHERE outlet_id = $1 AND is_deleted = false
		ORDER BY name ASC LIMIT $2 OFFSET $3`,
		outletID, limit, offset,
	)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	products := make([]models.CloudProduct, 0)
	for rows.Next() {
		var p models.CloudProduct
		if err := rows.Scan(&p.ID, &p.LocalID, &p.OutletID, &p.Name,
			&p.CategoryID, &p.CategoryName, &p.Price, &p.Stock, &p.Destination,
			&p.IsDeleted, &p.Version, &p.CreatedAt, &p.UpdatedAt, &p.SyncedAt); err != nil {
			return nil, 0, err
		}
		products = append(products, p)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, err
	}
	return products, total, nil
}

func DeleteProduct(outletID, localID string) error {
	_, err := database.DB.Exec(
		`UPDATE cloud_products SET is_deleted = true, updated_at = NOW()
		WHERE outlet_id = $1 AND local_id = $2`,
		outletID, localID,
	)
	return err
}

// ── Category Service ────────────────────────────────────────

// generateCategoryCodePrefix membuat kode prefix dari huruf pertama setiap kata
// (logika sama seperti generateProductCode di local POS)
func generateCategoryCodePrefix(name string) string {
	words := strings.Fields(name)
	var code string
	for _, word := range words {
		if len([]rune(word)) > 0 {
			code += strings.ToUpper(string([]rune(word)[0]))
		}
	}
	if len(code) > 4 {
		code = code[:4]
	}
	if code == "" {
		code = "C"
	}
	return code
}

func SaveCategory(outletID string, req models.PushCategoryRequest) (string, error) {
	// Auto-generate code_prefix jika tidak dikirim oleh local POS
	codePrefix := strings.TrimSpace(req.CodePrefix)
	if codePrefix == "" {
		codePrefix = generateCategoryCodePrefix(req.Name)
	}

	// Gunakan POS local_id sebagai cloud id agar ID kategori sama di POS dan Cloud
	cloudID := req.LocalID
	err := database.DB.QueryRow(
		`INSERT INTO cloud_categories (id, local_id, outlet_id, name, code_prefix, version, synced_at)
		VALUES ($1, $2, $3, $4, $5, $6, NOW())
		ON CONFLICT (outlet_id, local_id) DO UPDATE SET
			id = EXCLUDED.id,
			name = EXCLUDED.name,
			code_prefix = EXCLUDED.code_prefix,
			version = EXCLUDED.version,
			updated_at = NOW(),
			synced_at = NOW()
		RETURNING id`,
		cloudID, cloudID, outletID, req.Name, codePrefix, req.Version,
	).Scan(&cloudID)

	if err != nil {
		return "", err
	}
	return cloudID, nil
}

// UpdateCategoryPrinter mengizinkan cloud admin menugaskan printer ke kategori
func UpdateCategoryPrinter(outletID, categoryID, printerID string) error {
	_, err := database.DB.Exec(
		`UPDATE cloud_categories SET printer_id = $1, updated_at = NOW()
		WHERE outlet_id = $2 AND id = $3`,
		printerID, outletID, categoryID,
	)
	return err
}

func GetOutletCategoriesWithPrinter(outletID string) ([]models.CloudCategory, error) {
	rows, err := database.DB.Query(
		`SELECT cc.id, COALESCE(cc.local_id,''), cc.outlet_id, cc.name,
			COALESCE(cc.code_prefix,''), COALESCE(cc.printer_id,''),
			cc.is_deleted, cc.version, cc.created_at, cc.updated_at, cc.synced_at
		FROM cloud_categories cc
		WHERE cc.outlet_id = $1 AND cc.is_deleted = false
		ORDER BY cc.name`,
		outletID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	cats := make([]models.CloudCategory, 0)
	for rows.Next() {
		var cat models.CloudCategory
		if err := rows.Scan(&cat.ID, &cat.LocalID, &cat.OutletID, &cat.Name,
			&cat.CodePrefix, &cat.PrinterID, &cat.IsDeleted, &cat.Version,
			&cat.CreatedAt, &cat.UpdatedAt, &cat.SyncedAt); err != nil {
			return nil, err
		}
		cats = append(cats, cat)
	}
	return cats, rows.Err()
}

func DeleteCategory(outletID, name string) error {
	_, err := database.DB.Exec(
		`UPDATE cloud_categories SET is_deleted = true, updated_at = NOW()
		WHERE outlet_id = $1 AND name = $2`,
		outletID, name,
	)
	return err
}

// ── Printer Service ─────────────────────────────────────────

func SavePrinter(outletID string, req models.PushPrinterRequest) (string, error) {
	cloudID := req.LocalID
	if cloudID == "" {
		cloudID = NewULID()
	}
	err := database.DB.QueryRow(
		`INSERT INTO cloud_printers (id, local_id, outlet_id, name, ip_address, port,
			printer_type, paper_size, is_active, is_deleted, synced_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, NOW())
		ON CONFLICT (outlet_id, local_id) DO UPDATE SET
			id = EXCLUDED.id,
			name = EXCLUDED.name,
			ip_address = EXCLUDED.ip_address,
			port = EXCLUDED.port,
			printer_type = EXCLUDED.printer_type,
			paper_size = EXCLUDED.paper_size,
			is_active = EXCLUDED.is_active,
			is_deleted = EXCLUDED.is_deleted,
			updated_at = NOW(),
			synced_at = NOW()
		RETURNING id`,
		cloudID, cloudID, outletID, req.Name, req.IPAddress, req.Port,
		req.PrinterType, req.PaperSize, req.IsActive, req.IsDeleted,
	).Scan(&cloudID)
	if err != nil {
		return "", err
	}
	go logSync(outletID, "push_printer", "printer", 1, "success", "")
	return cloudID, nil
}

func GetOutletPrinters(outletID string) ([]models.CloudPrinter, error) {
	rows, err := database.DB.Query(
		`SELECT id, local_id, outlet_id, name, ip_address, port,
			printer_type, paper_size, is_active, is_deleted, created_at, updated_at, synced_at
		FROM cloud_printers
		WHERE outlet_id = $1 AND is_deleted = false
		ORDER BY printer_type, name`,
		outletID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	printers := make([]models.CloudPrinter, 0)
	for rows.Next() {
		var p models.CloudPrinter
		if err := rows.Scan(&p.ID, &p.LocalID, &p.OutletID, &p.Name, &p.IPAddress,
			&p.Port, &p.PrinterType, &p.PaperSize, &p.IsActive, &p.IsDeleted,
			&p.CreatedAt, &p.UpdatedAt, &p.SyncedAt); err != nil {
			return nil, err
		}
		printers = append(printers, p)
	}
	return printers, rows.Err()
}

// ── Cashier Shift Service ────────────────────────────────────

func SaveCashierShift(outletID string, req models.PushCashierShiftRequest) (string, error) {
	// id = local_id (ID sama di POS dan Cloud)
	cloudID := req.LocalID
	if cloudID == "" {
		cloudID = NewULID()
	}

	// Parse nullable closed_at
	var closedAt interface{}
	if req.ClosedAt != "" {
		closedAt = parseTime(req.ClosedAt)
	}

	err := database.DB.QueryRow(
		`INSERT INTO cloud_cashier_shifts (id, local_id, outlet_id, opened_by, opened_at,
			opening_cash, closed_at, closed_by, closing_cash, closing_card, closing_qris,
			closing_transfer, carry_over_cash, previous_shift_id, handover_to, status, notes,
			created_at, updated_at, synced_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, NOW(), NOW(), NOW())
		ON CONFLICT (outlet_id, local_id) DO UPDATE SET
			id = EXCLUDED.id,
			opened_by = EXCLUDED.opened_by,
			opened_at = EXCLUDED.opened_at,
			opening_cash = EXCLUDED.opening_cash,
			closed_at = EXCLUDED.closed_at,
			closed_by = EXCLUDED.closed_by,
			closing_cash = EXCLUDED.closing_cash,
			closing_card = EXCLUDED.closing_card,
			closing_qris = EXCLUDED.closing_qris,
			closing_transfer = EXCLUDED.closing_transfer,
			carry_over_cash = EXCLUDED.carry_over_cash,
			previous_shift_id = EXCLUDED.previous_shift_id,
			handover_to = EXCLUDED.handover_to,
			status = EXCLUDED.status,
			notes = EXCLUDED.notes,
			updated_at = NOW(),
			synced_at = NOW()
		RETURNING id`,
		cloudID, cloudID, outletID, req.OpenedBy, parseTime(req.OpenedAt),
		req.OpeningCash, closedAt, req.ClosedBy, req.ClosingCash, req.ClosingCard,
		req.ClosingQris, req.ClosingTransfer, req.CarryOverCash, req.PreviousShiftID,
		req.HandoverTo, req.Status, req.Notes,
	).Scan(&cloudID)

	if err != nil {
		return "", err
	}

	go logSync(outletID, "push_cashier_shift", "cashier_shift", 1, "success", "")
	return cloudID, nil
}

func SaveCashMovement(outletID string, req models.PushCashMovementRequest) (string, error) {
	// id = local_id (ID sama di POS dan Cloud)
	cloudID := req.LocalID
	if cloudID == "" {
		cloudID = NewULID()
	}

	err := database.DB.QueryRow(
		`INSERT INTO cloud_cash_movements (id, local_id, outlet_id, shift_id,
			movement_type, amount, counterpart_name, note, created_at, synced_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())
		ON CONFLICT (outlet_id, local_id) DO UPDATE SET
			id = EXCLUDED.id,
			shift_id = EXCLUDED.shift_id,
			movement_type = EXCLUDED.movement_type,
			amount = EXCLUDED.amount,
			counterpart_name = EXCLUDED.counterpart_name,
			note = EXCLUDED.note,
			synced_at = NOW()
		RETURNING id`,
		cloudID, cloudID, outletID, req.ShiftID,
		req.MovementType, req.Amount, req.CounterpartName, req.Note,
		parseTime(req.CreatedAt),
	).Scan(&cloudID)

	if err != nil {
		return "", err
	}

	go logSync(outletID, "push_cash_movement", "cash_movement", 1, "success", "")
	return cloudID, nil
}

// ── Analytics Service ───────────────────────────────────────

func SaveAnalytics(outletID string, req models.PushAnalyticsRequest) (string, error) {
	summaryJSON, _ := json.Marshal(req.Summary)
	cloudID := NewULID()
	err := database.DB.QueryRow(
		`INSERT INTO cloud_analytics (id, outlet_id, outlet_code, date, summary)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (outlet_id, date) DO UPDATE SET
			summary = EXCLUDED.summary,
			updated_at = NOW()
		RETURNING id`,
		cloudID, outletID, req.OutletCode, req.Date, string(summaryJSON),
	).Scan(&cloudID)

	if err != nil {
		return "", err
	}

	go logSync(outletID, "push_analytics", "analytics", 1, "success", "")
	return cloudID, nil
}

func GetAnalytics(outletID, startDate, endDate string) ([]models.CloudAnalytics, error) {
	query := `SELECT id, outlet_id, outlet_code, date::text, summary::text,
		created_at, updated_at FROM cloud_analytics WHERE outlet_id = $1`
	args := []interface{}{outletID}

	if startDate != "" && endDate != "" {
		query += " AND date BETWEEN $2 AND $3"
		args = append(args, startDate, endDate)
	}
	query += " ORDER BY date DESC"

	rows, err := database.DB.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	analytics := make([]models.CloudAnalytics, 0)
	for rows.Next() {
		var a models.CloudAnalytics
		if err := rows.Scan(&a.ID, &a.OutletID, &a.OutletCode, &a.Date,
			&a.Summary, &a.CreatedAt, &a.UpdatedAt); err != nil {
			return nil, err
		}
		analytics = append(analytics, a)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return analytics, nil
}

// ── Batch Sync Service ──────────────────────────────────────

func ProcessBatchSync(outletID string, req models.BatchSyncRequest) models.BatchSyncResponse {
	resp := models.BatchSyncResponse{
		Processed: len(req.Items),
		SyncedAt:  time.Now().UTC().Format(time.RFC3339),
	}

	for _, item := range req.Items {
		result := models.BatchSyncResult{
			EntityType: item.EntityType,
			Status:     "success",
		}

		// Normalisasi field names dari POS trigger ke cloud model
		if dataMap, ok := item.Data.(map[string]interface{}); ok {
			normalizeSyncFields(dataMap, item.EntityType)
			item.Data = dataMap
		}

		dataBytes, _ := json.Marshal(item.Data)

		switch item.EntityType {
		case "order":
			var orderReq models.PushOrderRequest
			if err := json.Unmarshal(dataBytes, &orderReq); err != nil {
				result.Status = "failed"
				result.Error = "Invalid order data: " + err.Error()
				resp.Failed++
			} else {
				result.LocalID = orderReq.LocalID
				if cloudID, err := SaveOrder(outletID, orderReq); err != nil {
					result.Status = "failed"
					result.Error = err.Error()
					resp.Failed++
				} else {
					result.CloudID = cloudID
					resp.Success++
				}
			}

		case "transaction":
			var txReq models.PushTransactionRequest
			if err := json.Unmarshal(dataBytes, &txReq); err != nil {
				result.Status = "failed"
				result.Error = "Invalid transaction data: " + err.Error()
				resp.Failed++
			} else {
				result.LocalID = txReq.LocalID
				if cloudID, err := SaveTransaction(outletID, txReq); err != nil {
					result.Status = "failed"
					result.Error = err.Error()
					resp.Failed++
				} else {
					result.CloudID = cloudID
					resp.Success++
				}
			}

		case "product":
			var prodReq models.PushProductRequest
			if err := json.Unmarshal(dataBytes, &prodReq); err != nil {
				result.Status = "failed"
				result.Error = "Invalid product data: " + err.Error()
				resp.Failed++
			} else {
				result.LocalID = prodReq.LocalID
				if item.Operation == "delete" {
					if err := DeleteProduct(outletID, prodReq.LocalID); err != nil {
						result.Status = "failed"
						result.Error = err.Error()
						resp.Failed++
					} else {
						resp.Success++
					}
				} else {
					if cloudID, err := SaveProduct(outletID, prodReq); err != nil {
						result.Status = "failed"
						result.Error = err.Error()
						resp.Failed++
					} else {
						result.CloudID = cloudID
						resp.Success++
					}
				}
			}

		case "category":
			// Extract category fields from the data map
			dataMap := make(map[string]interface{})
			if err := json.Unmarshal(dataBytes, &dataMap); err != nil {
				result.Status = "failed"
				result.Error = "Invalid category data: " + err.Error()
				resp.Failed++
			} else {
				localID := ""
				if v, ok := dataMap["local_id"].(string); ok && v != "" {
					localID = v
				} else if v, ok := dataMap["id"].(string); ok && v != "" {
					localID = v
				}
				name := ""
				if v, ok := dataMap["name"].(string); ok {
					name = v
				}
				codePrefix := ""
				if v, ok := dataMap["code_prefix"].(string); ok {
					codePrefix = v
				}
				version := 1
				if v, ok := dataMap["version"].(float64); ok {
					version = int(v)
				}

				catReq := models.PushCategoryRequest{
					LocalID:    localID,
					Name:       name,
					CodePrefix: codePrefix,
					Version:    version,
				}

				result.LocalID = localID
				if item.Operation == "delete" {
					if err := DeleteCategory(outletID, name); err != nil {
						result.Status = "failed"
						result.Error = err.Error()
						resp.Failed++
					} else {
						resp.Success++
					}
				} else {
					if cloudID, err := SaveCategory(outletID, catReq); err != nil {
						result.Status = "failed"
						result.Error = err.Error()
						resp.Failed++
					} else {
						result.CloudID = cloudID
						resp.Success++
					}
				}
			}

		case "printer":
			var printerReq models.PushPrinterRequest
			if err := json.Unmarshal(dataBytes, &printerReq); err != nil {
				result.Status = "failed"
				result.Error = "Invalid printer data: " + err.Error()
				resp.Failed++
			} else {
				result.LocalID = printerReq.LocalID
				if item.Operation == "delete" {
					// Soft delete
					printerReq.IsDeleted = true
				}
				if cloudID, err := SavePrinter(outletID, printerReq); err != nil {
					result.Status = "failed"
					result.Error = err.Error()
					resp.Failed++
				} else {
					result.CloudID = cloudID
					resp.Success++
				}
			}

		case "cashier_shift":
			var shiftReq models.PushCashierShiftRequest
			if err := json.Unmarshal(dataBytes, &shiftReq); err != nil {
				result.Status = "failed"
				result.Error = "Invalid cashier_shift data: " + err.Error()
				resp.Failed++
			} else {
				result.LocalID = shiftReq.LocalID
				if cloudID, err := SaveCashierShift(outletID, shiftReq); err != nil {
					result.Status = "failed"
					result.Error = err.Error()
					resp.Failed++
				} else {
					result.CloudID = cloudID
					resp.Success++
				}
			}

		case "cashier_cash_movement":
			var movReq models.PushCashMovementRequest
			if err := json.Unmarshal(dataBytes, &movReq); err != nil {
				result.Status = "failed"
				result.Error = "Invalid cashier_cash_movement data: " + err.Error()
				resp.Failed++
			} else {
				result.LocalID = movReq.LocalID
				if cloudID, err := SaveCashMovement(outletID, movReq); err != nil {
					result.Status = "failed"
					result.Error = err.Error()
					resp.Failed++
				} else {
					result.CloudID = cloudID
					resp.Success++
				}
			}

		default:
			// Entity types yang belum di-handle di cloud: user, payment, dll
			// Skip tanpa error agar tidak mengganggu sync batch
			localID := ""
			if dataMap, ok := item.Data.(map[string]interface{}); ok {
				if v, ok := dataMap["local_id"].(string); ok {
					localID = v
				} else if v, ok := dataMap["id"].(string); ok {
					localID = v
				}
			}
			result.LocalID = localID
			result.Status = "success" // Anggap sukses — cloud tidak perlu entity ini
			result.CloudID = localID
			log.Printf("Entity type '%s' not handled by cloud, skipping", item.EntityType)
			resp.Success++
		}

		resp.Results = append(resp.Results, result)
	}

	syncStatus := "success"
	syncErr := ""
	if resp.Failed > 0 {
		if resp.Success == 0 {
			syncStatus = "failed"
		} else {
			syncStatus = "partial"
		}
		syncErr = fmt.Sprintf("%d of %d items failed", resp.Failed, resp.Processed)
	}
	go logSync(outletID, "batch_sync", "batch", resp.Processed, syncStatus, syncErr)
	return resp
}

// ── Updates Service ─────────────────────────────────────────

func GetUpdatesSince(outletID, since string) (*models.UpdatesResponse, error) {
	sinceTime := parseTime(since)
	resp := &models.UpdatesResponse{
		Products:       make([]models.UpdateEntity, 0),
		Categories:     make([]models.UpdateEntity, 0),
		Deleted:        make([]models.DeletedEntity, 0),
		SyncCheckpoint: time.Now().UTC().Format(time.RFC3339),
	}

	// Updated products
	rows, err := database.DB.Query(
		`SELECT id, local_id, name, price, stock, version, updated_at::text
		FROM cloud_products
		WHERE outlet_id = $1 AND updated_at > $2 AND is_deleted = false
		ORDER BY updated_at ASC`,
		outletID, sinceTime,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var e models.UpdateEntity
		var price float64
		var stock int
		if err := rows.Scan(&e.CloudID, &e.LocalID, &e.Name, &price, &stock, &e.Version, &e.UpdatedAt); err != nil {
			return nil, err
		}
		e.Price = &price
		e.Stock = &stock
		e.Action = "update"
		resp.Products = append(resp.Products, e)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	// Updated categories
	catRows, err := database.DB.Query(
		`SELECT id, COALESCE(local_id,''), name, version, updated_at::text
		FROM cloud_categories
		WHERE outlet_id = $1 AND updated_at > $2 AND is_deleted = false
		ORDER BY updated_at ASC`,
		outletID, sinceTime,
	)
	if err != nil {
		return nil, err
	}
	defer catRows.Close()
	for catRows.Next() {
		var e models.UpdateEntity
		if err := catRows.Scan(&e.CloudID, &e.LocalID, &e.Name, &e.Version, &e.UpdatedAt); err != nil {
			return nil, err
		}
		e.Action = "update"
		resp.Categories = append(resp.Categories, e)
	}
	if err := catRows.Err(); err != nil {
		return nil, err
	}

	// Deleted entities
	delProdRows, err := database.DB.Query(
		`SELECT id, local_id, updated_at::text
		FROM cloud_products WHERE outlet_id = $1 AND is_deleted = true AND updated_at > $2`,
		outletID, sinceTime,
	)
	if err != nil {
		return nil, err
	}
	defer delProdRows.Close()
	for delProdRows.Next() {
		var d models.DeletedEntity
		d.EntityType = "product"
		if err := delProdRows.Scan(&d.CloudID, &d.LocalID, &d.DeletedAt); err != nil {
			return nil, err
		}
		resp.Deleted = append(resp.Deleted, d)
	}
	if err := delProdRows.Err(); err != nil {
		return nil, err
	}

	delCatRows, err := database.DB.Query(
		`SELECT id, COALESCE(local_id,''), updated_at::text
		FROM cloud_categories WHERE outlet_id = $1 AND is_deleted = true AND updated_at > $2`,
		outletID, sinceTime,
	)
	if err != nil {
		return nil, err
	}
	defer delCatRows.Close()
	for delCatRows.Next() {
		var d models.DeletedEntity
		d.EntityType = "category"
		if err := delCatRows.Scan(&d.CloudID, &d.LocalID, &d.DeletedAt); err != nil {
			return nil, err
		}
		resp.Deleted = append(resp.Deleted, d)
	}
	if err := delCatRows.Err(); err != nil {
		return nil, err
	}

	return resp, nil
}

// ── Conflict Service ────────────────────────────────────────

func GetConflicts(outletID string) ([]models.SyncConflict, error) {
	rows, err := database.DB.Query(
		`SELECT id, outlet_id, entity_type, COALESCE(entity_local_id,''),
			COALESCE(entity_cloud_id::text,''), COALESCE(conflict_field,''),
			COALESCE(cloud_value,''), COALESCE(local_value,''),
			COALESCE(cloud_version,0), COALESCE(local_version,0),
			COALESCE(resolution,'pending'), COALESCE(resolved_by,''),
			resolved_at::text, COALESCE(notes,''), created_at::text
		FROM sync_conflicts WHERE outlet_id = $1
		ORDER BY created_at DESC`,
		outletID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	conflicts := make([]models.SyncConflict, 0)
	for rows.Next() {
		var c models.SyncConflict
		if err := rows.Scan(&c.ID, &c.OutletID, &c.EntityType,
			&c.EntityLocalID, &c.EntityCloudID, &c.ConflictField,
			&c.CloudValue, &c.LocalValue, &c.CloudVersion, &c.LocalVersion,
			&c.Resolution, &c.ResolvedBy, &c.ResolvedAt, &c.Notes, &c.CreatedAt); err != nil {
			return nil, err
		}
		conflicts = append(conflicts, c)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return conflicts, nil
}

func ResolveConflict(outletID, conflictID string, req models.ResolveConflictRequest) error {
	result, err := database.DB.Exec(
		`UPDATE sync_conflicts
		SET resolution = $1, resolved_by = $2, notes = $3, resolved_at = NOW()
		WHERE id = $4 AND outlet_id = $5`,
		req.Strategy, req.ResolvedBy, req.Notes, conflictID, outletID,
	)
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("conflict not found")
	}
	return nil
}

// ── Sync Log Service ────────────────────────────────────────

func logSync(outletID, action, entityType string, count int, status, errMsg string) {
	_, err := database.DB.Exec(
		`INSERT INTO sync_logs (id, outlet_id, action, entity_type, entity_count, status, error_message)
		VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		NewULID(), outletID, action, entityType, count, status, errMsg,
	)
	if err != nil {
		log.Printf("Failed to log sync: %v", err)
	}
}

func GetSyncLogs(outletID string, limit int) ([]models.SyncLog, error) {
	rows, err := database.DB.Query(
		`SELECT id, outlet_id, action, COALESCE(entity_type,''),
			entity_count, status, COALESCE(error_message,''), created_at::text
		FROM sync_logs WHERE outlet_id = $1
		ORDER BY created_at DESC LIMIT $2`,
		outletID, limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	logs := make([]models.SyncLog, 0)
	for rows.Next() {
		var l models.SyncLog
		if err := rows.Scan(&l.ID, &l.OutletID, &l.Action, &l.EntityType,
			&l.EntityCount, &l.Status, &l.ErrorMessage, &l.CreatedAt); err != nil {
			return nil, err
		}
		logs = append(logs, l)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return logs, nil
}

// ── Dashboard Service ───────────────────────────────────────

func GetDashboardStats() (*models.DashboardStats, error) {
	stats := &models.DashboardStats{}

	queries := []struct {
		query string
		dest  interface{}
	}{
		{"SELECT COUNT(*) FROM outlets", &stats.TotalOutlets},
		{"SELECT COUNT(*) FROM outlets WHERE is_active = true", &stats.ActiveOutlets},
		{"SELECT COUNT(*) FROM cloud_orders", &stats.TotalOrders},
		{"SELECT COUNT(*) FROM cloud_transactions", &stats.TotalTransactions},
		{"SELECT COALESCE(SUM(total_amount),0) FROM cloud_transactions", &stats.TotalRevenue},
		{"SELECT COUNT(*) FROM cloud_orders WHERE created_at::date = CURRENT_DATE", &stats.TodayOrders},
		{"SELECT COALESCE(SUM(total_amount),0) FROM cloud_transactions WHERE created_at::date = CURRENT_DATE", &stats.TodayRevenue},
		{"SELECT COUNT(*) FROM cloud_products WHERE is_deleted = false", &stats.TotalProducts},
		{"SELECT COUNT(*) FROM sync_logs", &stats.TotalSyncLogs},
		{"SELECT COUNT(*) FROM sync_conflicts WHERE resolution IS NULL OR resolution = 'pending'", &stats.PendingConflicts},
	}

	for _, q := range queries {
		if err := database.DB.QueryRow(q.query).Scan(q.dest); err != nil {
			return nil, fmt.Errorf("dashboard query failed: %w", err)
		}
	}

	return stats, nil
}

// ── Admin Auth Service ──────────────────────────────────────

func AdminLogin(req models.AdminLoginRequest, jwtSecret string) (*models.AdminLoginResponse, error) {
	var admin models.CloudAdmin
	var passwordHash string
	var lastLogin sql.NullTime

	err := database.DB.QueryRow(
		`SELECT id, username, password_hash, name, role, is_active, last_login_at, created_at, updated_at
		FROM cloud_admins WHERE username = $1`,
		req.Username,
	).Scan(&admin.ID, &admin.Username, &passwordHash, &admin.Name, &admin.Role,
		&admin.IsActive, &lastLogin, &admin.CreatedAt, &admin.UpdatedAt)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("username atau password salah")
	}
	if err != nil {
		return nil, err
	}

	// Trim CHAR(26) whitespace
	admin.ID = strings.TrimSpace(admin.ID)

	if !admin.IsActive {
		return nil, fmt.Errorf("akun admin tidak aktif")
	}

	if err := bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(req.Password)); err != nil {
		return nil, fmt.Errorf("username atau password salah")
	}

	if lastLogin.Valid {
		admin.LastLoginAt = &lastLogin.Time
	}

	// Update last_login_at
	database.DB.Exec("UPDATE cloud_admins SET last_login_at = NOW() WHERE id = $1", admin.ID)

	// Generate JWT token
	token, err := generateJWT(admin, jwtSecret)
	if err != nil {
		return nil, fmt.Errorf("gagal membuat token: %w", err)
	}

	return &models.AdminLoginResponse{
		Token: token,
		Admin: admin,
	}, nil
}

func generateJWT(admin models.CloudAdmin, secret string) (string, error) {
	claims := jwt.MapClaims{
		"sub":      admin.ID,
		"username": admin.Username,
		"name":     admin.Name,
		"role":     admin.Role,
		"iat":      time.Now().Unix(),
		"exp":      time.Now().Add(24 * time.Hour).Unix(),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(secret))
}

func ValidateJWT(tokenString, secret string) (jwt.MapClaims, error) {
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(secret), nil
	})

	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(jwt.MapClaims); ok && token.Valid {
		return claims, nil
	}

	return nil, fmt.Errorf("invalid token")
}

func GetAdmins() ([]models.CloudAdmin, error) {
	rows, err := database.DB.Query(
		`SELECT id, username, name, role, is_active, last_login_at, created_at, updated_at
		FROM cloud_admins ORDER BY created_at ASC`,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	admins := make([]models.CloudAdmin, 0)
	for rows.Next() {
		var a models.CloudAdmin
		var lastLogin sql.NullTime
		if err := rows.Scan(&a.ID, &a.Username, &a.Name, &a.Role,
			&a.IsActive, &lastLogin, &a.CreatedAt, &a.UpdatedAt); err != nil {
			return nil, err
		}
		a.ID = strings.TrimSpace(a.ID)
		if lastLogin.Valid {
			a.LastLoginAt = &lastLogin.Time
		}
		admins = append(admins, a)
	}
	return admins, rows.Err()
}

func CreateAdmin(req models.CreateAdminRequest) (*models.CloudAdmin, error) {
	// Validasi
	if req.Username == "" || req.Password == "" || req.Name == "" {
		return nil, fmt.Errorf("username, password, dan name wajib diisi")
	}
	if len(req.Password) < 6 {
		return nil, fmt.Errorf("password minimal 6 karakter")
	}
	if req.Role == "" {
		req.Role = "admin"
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	id := NewULID()
	admin := &models.CloudAdmin{ID: id, Username: req.Username, Name: req.Name, Role: req.Role, IsActive: true}

	err = database.DB.QueryRow(
		`INSERT INTO cloud_admins (id, username, password_hash, name, role)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING created_at, updated_at`,
		id, req.Username, string(hash), req.Name, req.Role,
	).Scan(&admin.CreatedAt, &admin.UpdatedAt)

	if err != nil {
		if strings.Contains(err.Error(), "duplicate key") || strings.Contains(err.Error(), "unique") {
			return nil, fmt.Errorf("username '%s' sudah digunakan", req.Username)
		}
		return nil, err
	}

	return admin, nil
}

// ── Helpers ─────────────────────────────────────────────────

func parseTime(s string) interface{} {
	if s == "" {
		return sql.NullTime{}
	}

	formats := []string{
		time.RFC3339,
		"2006-01-02T15:04:05Z",
		"2006-01-02 15:04:05",
		"2006-01-02",
	}

	for _, f := range formats {
		if t, err := time.Parse(f, s); err == nil {
			return t
		}
	}

	return time.Now().UTC()
}
