package services

import (
	"cloud-pos/database"
	"cloud-pos/models"
	"encoding/json"
	"fmt"
	"log"
)

func SaveOrder(outletID string, req models.PushOrderRequest) (string, error) {
	itemsJSON, _ := json.Marshal(req.Items)
	paymentJSON, _ := json.Marshal(req.PaymentInfo)

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
	if err := database.DB.QueryRow("SELECT COUNT(*) FROM cloud_orders WHERE outlet_id = $1", outletID).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count orders: %w", err)
	}

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

func SaveTransaction(outletID string, req models.PushTransactionRequest) (string, error) {
	cloudID := req.LocalID
	if cloudID == "" {
		cloudID = NewULID()
	}

	itemsJSON := "[]"
	if len(req.Items) > 0 {
		b, _ := json.Marshal(req.Items)
		itemsJSON = string(b)
	}

	chargesJSON := "[]"
	if len(req.Charges) > 0 {
		b, _ := json.Marshal(req.Charges)
		chargesJSON = string(b)
	}

	err := database.DB.QueryRow(
		`INSERT INTO cloud_transactions (id, local_id, outlet_id, outlet_code, order_id,
			subtotal, total_amount, tax_amount, other_charges_total, charges,
			payment_method, cash_amount, change_amount, cashier_name,
			items, version, created_at, synced_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, NOW())
		ON CONFLICT (outlet_id, local_id) DO UPDATE SET
			id = EXCLUDED.id,
			subtotal = EXCLUDED.subtotal,
			total_amount = EXCLUDED.total_amount,
			tax_amount = EXCLUDED.tax_amount,
			other_charges_total = EXCLUDED.other_charges_total,
			charges = EXCLUDED.charges,
			payment_method = EXCLUDED.payment_method,
			cash_amount = EXCLUDED.cash_amount,
			change_amount = EXCLUDED.change_amount,
			cashier_name = EXCLUDED.cashier_name,
			items = EXCLUDED.items,
			version = EXCLUDED.version,
			synced_at = NOW()
		RETURNING id`,
		cloudID, cloudID, outletID, req.OutletCode, req.OrderID,
		req.Subtotal, req.TotalAmount, req.TaxAmount, req.OtherChargesTotal, chargesJSON,
		req.PaymentMethod, req.CashAmount, req.ChangeAmount, req.CashierName,
		itemsJSON, req.Version, parseTime(req.CreatedAt),
	).Scan(&cloudID)

	if err != nil {
		return "", err
	}

	go logSync(outletID, "push_transaction", "transaction", 1, "success", "")

	// Auto-deduct stok bahan baku via resep produk (lenient: gagal dicatat,
	// transaksi tetap commit — selisih stok lebih baik daripada transaksi gagal sync).
	// Catatan: saat ini akan no-op untuk item tanpa product_id (app outlet belum
	// mengirim local_id produk di payload transaksi — lihat memory project_cloud_pos_overview).
	for _, item := range req.Items {
		if item.ProductID == "" || item.Quantity <= 0 {
			continue
		}
		if derr := DeductStockByRecipe(outletID, item.ProductID, float64(item.Quantity), cloudID, req.LocalID); derr != nil {
			log.Printf("DeductStockByRecipe gagal (outlet=%s produk=%s transaksi=%s): %v", outletID, item.ProductID, cloudID, derr)
			go logSync(outletID, "deduct_stock", "stock_movement", 1, "failed", derr.Error())
		}
	}

	return cloudID, nil
}

func GetTransactions(outletID string, page, limit int) ([]models.CloudTransaction, int, error) {
	offset := (page - 1) * limit
	var total int
	if err := database.DB.QueryRow("SELECT COUNT(*) FROM cloud_transactions WHERE outlet_id = $1", outletID).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count transactions: %w", err)
	}

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
