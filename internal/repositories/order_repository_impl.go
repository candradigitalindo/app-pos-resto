package repositories

import (
	"backend/internal/db"
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/json"
	"fmt"
	"math"
	"strconv"
	"strings"
	"time"

	"github.com/oklog/ulid/v2"
)

// PrintPayload represents the JSON content for print jobs.
type PrintPayload struct {
	OrderID       string      `json:"order_id"`
	ReceiptNumber string      `json:"receipt_number"`
	TableNumber   string      `json:"table_number"`
	CustomerName  string      `json:"customer_name"`
	WaiterName    string      `json:"waiter_name"`
	CashierName   string      `json:"cashier_name"`
	Items         []PrintItem `json:"items"`
	Subtotal      int         `json:"subtotal"`
	Tax           int         `json:"tax"`
	Total         int         `json:"total"`
	PaymentMethod string      `json:"payment_method"`
	PaidAmount    int         `json:"paid_amount"`
	ChangeAmount  int         `json:"change_amount"`
	DateTime      time.Time   `json:"datetime"`
}

// PrintItemWithInfo represents an item in print payload with full details.
type PrintItem struct {
	Name     string `json:"name"`
	Quantity int    `json:"quantity"`
	Price    int    `json:"price"`
	Total    int    `json:"total"`
}

func parseNumeric(value interface{}) (float64, error) {
	switch v := value.(type) {
	case float64:
		return v, nil
	case int64:
		return float64(v), nil
	case int:
		return float64(v), nil
	case []byte:
		parsed, err := strconv.ParseFloat(string(v), 64)
		if err != nil {
			return 0, err
		}
		return parsed, nil
	case string:
		parsed, err := strconv.ParseFloat(v, 64)
		if err != nil {
			return 0, err
		}
		return parsed, nil
	default:
		return 0, fmt.Errorf("tipe angka tidak dikenali")
	}
}

func parseOrderSequence(orderID string) int {
	parts := strings.Split(orderID, "-")
	if len(parts) < 3 {
		return 0
	}
	seq, err := strconv.Atoi(parts[len(parts)-1])
	if err != nil {
		return 0
	}
	return seq
}

func (r *orderRepository) generateOrderID(ctx context.Context, dbtx db.DBTX, tableNumber string) (string, error) {
	datePart := time.Now().Format("020106")
	prefix := fmt.Sprintf("%s-%s-", datePart, tableNumber)

	rows, err := dbtx.QueryContext(ctx, `
		SELECT id
		FROM orders
		WHERE id LIKE ? AND table_number = ?
	`, prefix+"%", tableNumber)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	maxSeq := 0
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return "", err
		}
		seq := parseOrderSequence(id)
		if seq > maxSeq {
			maxSeq = seq
		}
	}
	if err := rows.Err(); err != nil {
		return "", err
	}

	nextSeq := maxSeq + 1
	return fmt.Sprintf("%s%02d", prefix, nextSeq), nil
}

type orderRepository struct {
	db *sql.DB
}

func NewOrderRepository(dbConn *sql.DB) OrderRepository {
	return &orderRepository{db: dbConn}
}

func (r *orderRepository) recalculateOrderTotals(ctx context.Context, q *db.Queries, tx *sql.Tx, orderID string) (float64, float64, error) {
	items, err := q.GetOrderItems(ctx, orderID)
	if err != nil {
		return 0, 0, err
	}

	subtotal := 0.0
	for _, item := range items {
		subtotal += item.Price * float64(item.Qty)
	}

	basketSize := int64(len(items))

	_, err = tx.ExecContext(ctx, `
		DELETE FROM order_additional_charges
		WHERE order_id = ?

		AND charge_id IS NOT NULL
	`, orderID)
	if err != nil {
		return 0, 0, err
	}

	rows, err := tx.QueryContext(ctx, `
		SELECT id, name, charge_type, value
		FROM additional_charges
		WHERE is_active = 1
	`)
	if err != nil {
		return 0, 0, err
	}
	defer rows.Close()

	type activeCharge struct {
		id         int64
		name       string
		chargeType string
		value      float64
	}

	charges := make([]activeCharge, 0)
	for rows.Next() {
		var charge activeCharge
		if err := rows.Scan(&charge.id, &charge.name, &charge.chargeType, &charge.value); err != nil {
			return 0, 0, err
		}
		charges = append(charges, charge)
	}

	if err := rows.Err(); err != nil {
		return 0, 0, err
	}

	chargesTotal := 0.0
	for _, charge := range charges {
		chargeID := charge.id
		name := charge.name
		chargeType := charge.chargeType
		value := charge.value

		applied := 0.0
		if subtotal > 0 {
			if chargeType == "percentage" {
				applied = subtotal * value / 100
			} else {
				applied = value
			}
		}

		if applied == 0 {
			continue
		}

		_, err = tx.ExecContext(ctx, `
			INSERT INTO order_additional_charges (
				order_id,
				charge_id,
				name,
				charge_type,
				value,
				applied_amount,
				created_at,
				updated_at
			) VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
		`, orderID, chargeID, name, chargeType, value, applied)
		if err != nil {
			return 0, 0, err
		}

		chargesTotal += applied
	}

	manualTotal := 0.0
	manualRows, err := tx.QueryContext(ctx, `
		SELECT id, charge_type, value, applied_amount
		FROM order_additional_charges
		WHERE order_id = ?
		  AND charge_id IS NULL
	`, orderID)
	if err != nil {
		return 0, 0, err
	}
	defer manualRows.Close()

	for manualRows.Next() {
		var id int64
		var chargeType string
		var value float64
		var appliedAmount float64
		if err := manualRows.Scan(&id, &chargeType, &value, &appliedAmount); err != nil {
			return 0, 0, err
		}
		sign := 1.0
		if appliedAmount < 0 {
			sign = -1
		}
		computedAbs := 0.0
		if chargeType == "percentage" {
			computedAbs = subtotal * value / 100
		} else {
			computedAbs = value
		}
		if computedAbs == 0 {
			_, err = tx.ExecContext(ctx, `
				DELETE FROM order_additional_charges
				WHERE id = ?
			`, id)
			if err != nil {
				return 0, 0, err
			}
			continue
		}
		applied := sign * computedAbs
		if math.Abs(applied-appliedAmount) > 0.000001 {
			_, err = tx.ExecContext(ctx, `
				UPDATE order_additional_charges
				SET applied_amount = ?, updated_at = CURRENT_TIMESTAMP
				WHERE id = ?
			`, applied, id)
			if err != nil {
				return 0, 0, err
			}
		}
		manualTotal += applied
	}

	if err := manualRows.Err(); err != nil {
		return 0, 0, err
	}

	totalAmount := subtotal + chargesTotal + manualTotal
	if totalAmount < 0 {
		totalAmount = 0
	}
	_, err = tx.ExecContext(ctx, `
		UPDATE orders
		SET total_amount = ?, basket_size = ?, updated_at = CURRENT_TIMESTAMP
		WHERE id = ?
	`, totalAmount, basketSize, orderID)
	if err != nil {
		return 0, 0, err
	}

	return subtotal, chargesTotal, nil
}

// execTx runs fn within a database transaction, rolling back on error.
func (r *orderRepository) execTx(ctx context.Context, fn func(*db.Queries, *sql.Tx) error) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}

	q := db.New(tx)
	if err := fn(q, tx); err != nil {
		if rbErr := tx.Rollback(); rbErr != nil {
			return fmt.Errorf("kesalahan transaksi: %v, kesalahan rollback: %v", err, rbErr)
		}
		return err
	}

	return tx.Commit()
}

func (r *orderRepository) CreateOrderWithItems(ctx context.Context, input OrderInput) (string, error) {
	var orderID string

	err := r.execTx(ctx, func(q *db.Queries, tx *sql.Tx) error {
		generatedID, err := r.generateOrderID(ctx, tx, input.TableNumber)
		if err != nil {
			return fmt.Errorf("gagal membuat nomor pesanan: %w", err)
		}
		orderID = generatedID

		// Fetch product details and group by printer
		subtotal := 0.0
		type ItemWithDetails struct {
			ProductName string
			Price       float64
			Qty         int64
			PrinterID   string
			Destination string
		}
		itemsWithDetails := make([]ItemWithDetails, 0, len(input.Items))
		itemsByPrinter := make(map[string][]ItemWithDetails)

		for _, item := range input.Items {
			// Get product from database
			product, err := q.GetProduct(ctx, item.ProductID)
			if err != nil {
				return fmt.Errorf("product %s tidak ditemukan: %w", item.ProductID, err)
			}

			// Get printer from category (if exists)
			var printerID string
			var destination string = "kitchen" // default untuk order_items table

			if product.CategoryID.Valid {
				category, err := q.GetCategory(ctx, product.CategoryID.String)
				if err == nil && category.PrinterID.Valid {
					printerID = category.PrinterID.String

					// Check printer type for destination field in order_items
					printer, err := q.GetPrinter(ctx, printerID)
					if err == nil {
						destination = printer.PrinterType
					}
				}
			}

			// Calculate subtotal
			subtotal += product.Price * float64(item.Qty)
			itemDetail := ItemWithDetails{
				ProductName: product.Name,
				Price:       product.Price,
				Qty:         item.Qty,
				PrinterID:   printerID,
				Destination: destination,
			}
			itemsWithDetails = append(itemsWithDetails, itemDetail)

			// Group by printer for print jobs
			if printerID != "" {
				itemsByPrinter[printerID] = append(itemsByPrinter[printerID], itemDetail)
			}

		}

		// Calculate basket size
		basketSize := int64(len(itemsWithDetails))

		// Create order
		_, err = q.CreateOrder(ctx, db.CreateOrderParams{
			ID:            orderID,
			TableNumber:   input.TableNumber,
			CustomerName:  sql.NullString{String: input.CustomerName, Valid: input.CustomerName != ""},
			CustomerPhone: sql.NullString{String: input.CustomerPhone, Valid: input.CustomerPhone != ""},
			CustomerID:    sql.NullString{String: input.CustomerID, Valid: input.CustomerID != ""},
			Pax:           input.Pax,
			BasketSize:    basketSize,
			TotalAmount:   subtotal,
			CreatedBy:     sql.NullString{String: input.CreatedBy, Valid: input.CreatedBy != ""},
		})
		if err != nil {
			return fmt.Errorf("gagal membuat order: %w", err)
		}

		for _, item := range itemsWithDetails {
			itemID := ulid.MustNew(ulid.Timestamp(time.Now()), rand.Reader).String()
			_, err = q.CreateOrderItem(ctx, db.CreateOrderItemParams{
				ID:          itemID,
				OrderID:     orderID,
				ProductName: item.ProductName,
				Qty:         item.Qty,
				Price:       item.Price,
				Destination: item.Destination,
			})
			if err != nil {
				return fmt.Errorf("gagal membuat item order: %w", err)
			}
		}

		// Create print jobs grouped by printer
		now := time.Now()
		waiterName := ""
		if input.CreatedBy != "" {
			user, err := q.GetUserByID(ctx, input.CreatedBy)
			if err == nil {
				waiterName = user.FullName
			}
		}

		for printerID, items := range itemsByPrinter {
			printItems := make([]PrintItem, len(items))
			var printerTotal int

			for i, item := range items {
				price := int(math.Round(item.Price))
				total := price * int(item.Qty)
				printItems[i] = PrintItem{
					Name:     item.ProductName,
					Quantity: int(item.Qty),
					Price:    price,
					Total:    total,
				}
				printerTotal += total
			}

			// Build JSON payload for this printer
			payload := PrintPayload{
				OrderID:       orderID,
				ReceiptNumber: orderID,
				TableNumber:   input.TableNumber,
				CustomerName:  input.CustomerName,
				WaiterName:    waiterName,
				Items:         printItems,
				Subtotal:      printerTotal,
				Total:         printerTotal,
				DateTime:      now,
			}

			payloadJSON, err := json.Marshal(payload)
			if err != nil {
				return fmt.Errorf("gagal marshal payload print: %w", err)
			}

			// Generate ULID for print job
			printJobID := ulid.MustNew(ulid.Timestamp(now), rand.Reader).String()

			_, err = q.CreatePrintJob(ctx, db.CreatePrintJobParams{
				ID:        printJobID,
				PrinterID: printerID,
				Data:      string(payloadJSON),
			})
			if err != nil {
				return fmt.Errorf("gagal membuat print job: %w", err)
			}
		}

		_, _, err = r.recalculateOrderTotals(ctx, q, tx, orderID)
		if err != nil {
			return err
		}

		return nil
	})

	return orderID, err
}

func (r *orderRepository) AddItemsToOrder(ctx context.Context, orderID string, items []OrderItemInput) error {
	return r.execTx(ctx, func(q *db.Queries, tx *sql.Tx) error {
		order, err := q.GetOrderWithItems(ctx, orderID)
		if err != nil {
			return err
		}

		if order.PaymentStatus == "paid" {
			return fmt.Errorf("order sudah dibayar")
		}

		var totalAmount float64
		type ItemWithDetails struct {
			ProductName string
			Price       float64
			Qty         int64
			PrinterID   string
			Destination string
		}
		itemsWithDetails := make([]ItemWithDetails, 0, len(items))
		itemsByPrinter := make(map[string][]ItemWithDetails)

		for _, item := range items {
			product, err := q.GetProduct(ctx, item.ProductID)
			if err != nil {
				return fmt.Errorf("product %s tidak ditemukan: %w", item.ProductID, err)
			}

			var printerID string
			destination := "kitchen"

			if product.CategoryID.Valid {
				category, err := q.GetCategory(ctx, product.CategoryID.String)
				if err == nil && category.PrinterID.Valid {
					printerID = category.PrinterID.String
					printer, err := q.GetPrinter(ctx, printerID)
					if err == nil {
						destination = printer.PrinterType
					}
				}
			}

			itemTotal := product.Price * float64(item.Qty)
			totalAmount += itemTotal

			itemDetail := ItemWithDetails{
				ProductName: product.Name,
				Price:       product.Price,
				Qty:         item.Qty,
				PrinterID:   printerID,
				Destination: destination,
			}
			itemsWithDetails = append(itemsWithDetails, itemDetail)

			if printerID != "" {
				itemsByPrinter[printerID] = append(itemsByPrinter[printerID], itemDetail)
			}
		}

		for _, item := range itemsWithDetails {
			itemID := ulid.MustNew(ulid.Timestamp(time.Now()), rand.Reader).String()
			_, err = q.CreateOrderItem(ctx, db.CreateOrderItemParams{
				ID:          itemID,
				OrderID:     orderID,
				ProductName: item.ProductName,
				Qty:         item.Qty,
				Price:       item.Price,
				Destination: item.Destination,
			})
			if err != nil {
				return fmt.Errorf("gagal membuat item order: %w", err)
			}
		}

		customerName := ""
		if order.CustomerName.Valid {
			customerName = order.CustomerName.String
		}
		waiterName := ""
		if order.CreatedBy.Valid && order.CreatedBy.String != "" {
			user, err := q.GetUserByID(ctx, order.CreatedBy.String)
			if err == nil {
				waiterName = user.FullName
			}
		}

		now := time.Now()
		for printerID, items := range itemsByPrinter {
			printItems := make([]PrintItem, len(items))
			var printerTotal int

			for i, item := range items {
				price := int(math.Round(item.Price))
				total := price * int(item.Qty)
				printItems[i] = PrintItem{
					Name:     item.ProductName,
					Quantity: int(item.Qty),
					Price:    price,
					Total:    total,
				}
				printerTotal += total
			}

			payload := PrintPayload{
				OrderID:       orderID,
				ReceiptNumber: orderID,
				TableNumber:   order.TableNumber,
				CustomerName:  customerName,
				WaiterName:    waiterName,
				Items:         printItems,
				Subtotal:      printerTotal,
				Total:         printerTotal,
				DateTime:      now,
			}

			payloadJSON, err := json.Marshal(payload)
			if err != nil {
				return fmt.Errorf("gagal marshal payload print: %w", err)
			}

			printJobID := ulid.MustNew(ulid.Timestamp(now), rand.Reader).String()
			_, err = q.CreatePrintJob(ctx, db.CreatePrintJobParams{
				ID:        printJobID,
				PrinterID: printerID,
				Data:      string(payloadJSON),
			})
			if err != nil {
				return fmt.Errorf("gagal membuat print job: %w", err)
			}
		}

		_, _, err = r.recalculateOrderTotals(ctx, q, tx, orderID)
		if err != nil {
			return err
		}

		return nil
	})
}

func (r *orderRepository) GetPendingJobs(ctx context.Context) ([]db.PrintQueue, error) {
	return db.New(r.db).GetPendingPrintJobs(ctx)
}

func (r *orderRepository) UpdatePrintJobStatus(ctx context.Context, arg db.UpdatePrintJobStatusParams) error {
	return db.New(r.db).UpdatePrintJobStatus(ctx, arg)
}

func (r *orderRepository) UpdateOrderStatus(ctx context.Context, orderID string, status string) error {
	return db.New(r.db).UpdateOrderStatus(ctx, db.UpdateOrderStatusParams{
		OrderStatus: status,
		ID:          orderID,
	})
}

func (r *orderRepository) UpdateOrderItemStatus(ctx context.Context, itemID string, status string) error {
	return db.New(r.db).UpdateOrderItemStatus(ctx, db.UpdateOrderItemStatusParams{
		ItemStatus: status,
		ID:         itemID,
	})
}

func (r *orderRepository) UpdateOrderItemQty(ctx context.Context, itemID string, qty int64) error {
	if qty < 0 {
		return ErrInvalidItemQty
	}

	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}

	q := db.New(r.db).WithTx(tx)

	var orderID string
	var currentQty int64
	var itemStatus string

	err = tx.QueryRowContext(ctx, `
		SELECT order_id, qty, item_status
		FROM order_items
		WHERE id = ?
	`, itemID).Scan(&orderID, &currentQty, &itemStatus)
	if err != nil {
		_ = tx.Rollback()
		if err == sql.ErrNoRows {
			return ErrOrderItemNotFound
		}
		return err
	}

	if itemStatus != "pending" {
		_ = tx.Rollback()
		return ErrOrderItemProcessed
	}

	order, err := q.GetOrderWithItems(ctx, orderID)
	if err != nil {
		_ = tx.Rollback()
		return err
	}

	if order.PaymentStatus == "paid" {
		_ = tx.Rollback()
		return ErrOrderAlreadyPaid
	}

	if qty == currentQty {
		return tx.Commit()
	}

	if qty == 0 {
		_, err = tx.ExecContext(ctx, `
			DELETE FROM order_items
			WHERE id = ?
		`, itemID)
		if err != nil {
			_ = tx.Rollback()
			return err
		}
	} else {
		_, err = tx.ExecContext(ctx, `
			UPDATE order_items
			SET qty = ?, updated_at = CURRENT_TIMESTAMP
			WHERE id = ?
		`, qty, itemID)
		if err != nil {
			_ = tx.Rollback()
			return err
		}
	}

	if _, _, err := r.recalculateOrderTotals(ctx, q, tx, orderID); err != nil {
		_ = tx.Rollback()
		return err
	}

	return tx.Commit()
}

func (r *orderRepository) ProcessPayment(ctx context.Context, orderID string) error {
	return r.execTx(ctx, func(q *db.Queries, tx *sql.Tx) error {
		_, _, err := r.recalculateOrderTotals(ctx, q, tx, orderID)
		if err != nil {
			return err
		}

		order, err := q.GetOrderWithItems(ctx, orderID)
		if err != nil {
			return err
		}

		return q.UpdateOrderPaidAmount(ctx, db.UpdateOrderPaidAmountParams{
			PaidAmount:    order.TotalAmount,
			PaymentStatus: "paid",
			ID:            orderID,
		})
	})
}

func (r *orderRepository) ApplyOrderDiscount(ctx context.Context, orderID string, chargeType string, value float64) error {
	if chargeType != "percentage" && chargeType != "fixed" {
		return fmt.Errorf("tipe diskon tidak valid")
	}
	if value <= 0 {
		return fmt.Errorf("nilai diskon tidak valid")
	}

	return r.execTx(ctx, func(q *db.Queries, tx *sql.Tx) error {
		order, err := q.GetOrderWithItems(ctx, orderID)
		if err != nil {
			return err
		}
		if order.PaymentStatus == "paid" {
			return ErrOrderAlreadyPaid
		}
		if order.PaidAmount > 0 {
			return fmt.Errorf("diskon tidak bisa diterapkan setelah pembayaran")
		}

		if _, err := tx.ExecContext(ctx, `
			DELETE FROM order_additional_charges
			WHERE order_id = ?
			  AND charge_id IS NULL
			  AND name IN ('Diskon', 'Kompliment')
		`, orderID); err != nil {
			return err
		}

		if _, _, err := r.recalculateOrderTotals(ctx, q, tx, orderID); err != nil {
			return err
		}

		order, err = q.GetOrderWithItems(ctx, orderID)
		if err != nil {
			return err
		}
		currentTotal := order.TotalAmount
		if currentTotal <= 0 {
			return fmt.Errorf("total order sudah nol")
		}

		discountAbs := value
		if chargeType == "percentage" {
			discountAbs = currentTotal * value / 100
		}
		discountAbs = math.Round(discountAbs)
		if discountAbs <= 0 {
			return fmt.Errorf("nilai diskon tidak valid")
		}
		if discountAbs > currentTotal {
			discountAbs = currentTotal
		}

		appliedAmount := -discountAbs
		_, err = tx.ExecContext(ctx, `
			INSERT INTO order_additional_charges (
				order_id,
				charge_id,
				name,
				charge_type,
				value,
				applied_amount,
				created_at,
				updated_at
			) VALUES (?, NULL, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
		`, orderID, "Diskon", chargeType, value, appliedAmount)
		if err != nil {
			return err
		}

		newTotal := currentTotal + appliedAmount
		if newTotal < 0 {
			newTotal = 0
		}
		_, err = tx.ExecContext(ctx, `
			UPDATE orders
			SET total_amount = ?, updated_at = CURRENT_TIMESTAMP
			WHERE id = ?
		`, newTotal, orderID)
		return err
	})
}

func (r *orderRepository) ApplyOrderCompliment(ctx context.Context, orderID string) error {
	return r.execTx(ctx, func(q *db.Queries, tx *sql.Tx) error {
		order, err := q.GetOrderWithItems(ctx, orderID)
		if err != nil {
			return err
		}
		if order.PaymentStatus == "paid" {
			return ErrOrderAlreadyPaid
		}
		if order.PaidAmount > 0 {
			return fmt.Errorf("kompliment tidak bisa diterapkan setelah pembayaran")
		}

		items, err := q.GetOrderItems(ctx, orderID)
		if err != nil {
			return err
		}
		subtotal := 0.0
		for _, item := range items {
			subtotal += item.Price * float64(item.Qty)
		}

		if _, err := tx.ExecContext(ctx, `
			DELETE FROM order_additional_charges
			WHERE order_id = ?
		`, orderID); err != nil {
			return err
		}

		currentTotal := math.Round(subtotal)
		if currentTotal <= 0 {
			return fmt.Errorf("total order sudah nol")
		}

		appliedAmount := -currentTotal
		_, err = tx.ExecContext(ctx, `
			INSERT INTO order_additional_charges (
				order_id,
				charge_id,
				name,
				charge_type,
				value,
				applied_amount,
				created_at,
				updated_at
			) VALUES (?, NULL, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
		`, orderID, "Kompliment", "fixed", currentTotal, appliedAmount)
		if err != nil {
			return err
		}

		_, err = tx.ExecContext(ctx, `
			UPDATE orders
			SET total_amount = 0, basket_size = ?, updated_at = CURRENT_TIMESTAMP
			WHERE id = ?
		`, int64(len(items)), orderID)
		return err
	})
}

func (r *orderRepository) GetOrderWithItems(ctx context.Context, orderID string) (*db.Order, []db.OrderItem, error) {
	q := db.New(r.db)

	order, err := q.GetOrderWithItems(ctx, orderID)
	if err != nil {
		return nil, nil, err
	}

	items, err := q.GetOrderItems(ctx, orderID)
	if err != nil {
		return nil, nil, err
	}

	if order.TotalAmount == 0 && len(items) > 0 && order.PaymentStatus != "paid" {
		totalAmount := 0.0
		for _, item := range items {
			totalAmount += item.Price * float64(item.Qty)
		}
		order.TotalAmount = totalAmount
	}

	return &order, items, nil
}

func (r *orderRepository) GetOrderByTableID(ctx context.Context, tableID string) (*db.Order, []db.OrderItem, error) {
	q := db.New(r.db)

	// First, get the table to find active order
	query := `
		SELECT
			o.id,
			o.table_number,
			o.customer_name,
			o.customer_phone,
			o.customer_id,
			o.pax,
			o.basket_size,
			o.total_amount,
			o.paid_amount,
			o.order_status,
			o.created_by,
			o.payment_status,
			o.merged_from,
			o.is_merged,
			o.created_at,
			o.updated_at
		FROM orders o
		INNER JOIN tables t ON o.table_number = t.table_number
		WHERE t.id = ?
		AND o.order_status != 'served'
		AND o.payment_status != 'paid'
		AND o.is_merged = 0
		AND o.voided_at IS NULL
		ORDER BY o.created_at DESC
		LIMIT 1
	`

	var order db.Order
	err := r.db.QueryRowContext(ctx, query, tableID).Scan(
		&order.ID,
		&order.TableNumber,
		&order.CustomerName,
		&order.CustomerPhone,
		&order.CustomerID,
		&order.Pax,
		&order.BasketSize,
		&order.TotalAmount,
		&order.PaidAmount,
		&order.OrderStatus,
		&order.CreatedBy,
		&order.PaymentStatus,
		&order.MergedFrom,
		&order.IsMerged,
		&order.CreatedAt,
		&order.UpdatedAt,
	)
	if err != nil {
		return nil, nil, err
	}

	items, err := q.GetOrderItems(ctx, order.ID)
	if err != nil {
		return nil, nil, err
	}

	if order.TotalAmount == 0 && len(items) > 0 {
		totalAmount := 0.0
		for _, item := range items {
			totalAmount += item.Price * float64(item.Qty)
		}
		order.TotalAmount = totalAmount
	}

	return &order, items, nil
}

func (r *orderRepository) GetOrderAnalytics(ctx context.Context, startDate, endDate time.Time) (*db.GetOrderAnalyticsRow, error) {
	query := `
		SELECT
			COUNT(*) as total_orders,
			SUM(total_amount) as total_revenue,
			AVG(total_amount) as avg_order_value,
			AVG(basket_size) as avg_basket_size,
			AVG(pax) as avg_pax,
			SUM(pax) as total_pax
		FROM orders o
		WHERE o.created_at BETWEEN ? AND ?
		AND o.payment_status = 'paid'
		AND o.voided_at IS NULL
		AND NOT EXISTS (
			SELECT 1
			FROM transactions t
			WHERE t.order_id = o.id
			AND t.status = 'cancelled'
		)
	`

	var analytics db.GetOrderAnalyticsRow
	err := r.db.QueryRowContext(ctx, query, startDate, endDate).Scan(
		&analytics.TotalOrders,
		&analytics.TotalRevenue,
		&analytics.AvgOrderValue,
		&analytics.AvgBasketSize,
		&analytics.AvgPax,
		&analytics.TotalPax,
	)
	if err != nil {
		return nil, err
	}

	return &analytics, nil
}

func (r *orderRepository) ListOrders(ctx context.Context, limit, offset int64) ([]db.Order, int64, error) {
	query := `
		SELECT
			id,
			table_number,
			customer_name,
			customer_phone,
			customer_id,
			pax,
			basket_size,
			total_amount,
			paid_amount,
			order_status,
			created_by,
			payment_status,
			merged_from,
			is_merged,
			created_at,
			updated_at
		FROM orders
		WHERE voided_at IS NULL
		ORDER BY created_at DESC
		LIMIT ? OFFSET ?
	`

	rows, err := r.db.QueryContext(ctx, query, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	orders := []db.Order{}
	for rows.Next() {
		var order db.Order
		if err := rows.Scan(
			&order.ID,
			&order.TableNumber,
			&order.CustomerName,
			&order.CustomerPhone,
			&order.CustomerID,
			&order.Pax,
			&order.BasketSize,
			&order.TotalAmount,
			&order.PaidAmount,
			&order.OrderStatus,
			&order.CreatedBy,
			&order.PaymentStatus,
			&order.MergedFrom,
			&order.IsMerged,
			&order.CreatedAt,
			&order.UpdatedAt,
		); err != nil {
			return nil, 0, err
		}
		orders = append(orders, order)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, err
	}

	var total int64
	if err := r.db.QueryRowContext(ctx, `
		SELECT COUNT(*)
		FROM orders
		WHERE voided_at IS NULL
	`).Scan(&total); err != nil {
		return nil, 0, err
	}

	return orders, total, nil
}

func (r *orderRepository) ListOrdersByCustomer(ctx context.Context, customerID string, startDate, endDate time.Time) ([]db.Order, error) {
	query := `
		SELECT id, table_number, customer_name, customer_phone, customer_id, pax, basket_size, total_amount, paid_amount, order_status, payment_status, merged_from, is_merged, created_at, updated_at
		FROM orders
		WHERE customer_id = ?
		AND created_at BETWEEN ? AND ?
		ORDER BY created_at DESC
	`

	rows, err := r.db.QueryContext(ctx, query, customerID, startDate, endDate)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	orders := []db.Order{}
	for rows.Next() {
		var order db.Order
		if err := rows.Scan(
			&order.ID,
			&order.TableNumber,
			&order.CustomerName,
			&order.CustomerPhone,
			&order.CustomerID,
			&order.Pax,
			&order.BasketSize,
			&order.TotalAmount,
			&order.PaidAmount,
			&order.OrderStatus,
			&order.PaymentStatus,
			&order.MergedFrom,
			&order.IsMerged,
			&order.CreatedAt,
			&order.UpdatedAt,
		); err != nil {
			return nil, err
		}
		orders = append(orders, order)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	return orders, nil
}

// GetRevenueByPaymentStatus mendapatkan revenue berdasarkan status pembayaran
func (r *orderRepository) GetRevenueByPaymentStatus(ctx context.Context, startDate, endDate time.Time) (paidRevenue, unpaidRevenue float64, err error) {
	query := `
		SELECT 
			COALESCE(SUM(CASE WHEN payment_status = 'paid' THEN total_amount ELSE 0 END), 0) as paid_revenue,
			COALESCE(SUM(CASE WHEN payment_status = 'unpaid' THEN total_amount ELSE 0 END), 0) as unpaid_revenue
		FROM orders o
		WHERE o.created_at BETWEEN ? AND ?
		AND o.is_merged = 0
		AND o.voided_at IS NULL
		AND NOT EXISTS (
			SELECT 1
			FROM transactions t
			WHERE t.order_id = o.id
			AND t.status = 'cancelled'
		)
	`

	err = r.db.QueryRowContext(ctx, query, startDate, endDate).Scan(&paidRevenue, &unpaidRevenue)
	if err != nil {
		return 0, 0, fmt.Errorf("gagal mengambil revenue by payment status: %w", err)
	}

	return paidRevenue, unpaidRevenue, nil
}

func (r *orderRepository) GetVoidedTotalByDateRange(ctx context.Context, startDate, endDate time.Time) (float64, error) {
	query := `
		SELECT COALESCE(SUM(total_amount), 0)
		FROM orders
		WHERE voided_at IS NOT NULL
		AND voided_at BETWEEN ? AND ?
	`
	var total float64
	if err := r.db.QueryRowContext(ctx, query, startDate, endDate).Scan(&total); err != nil {
		return 0, fmt.Errorf("gagal mengambil total void: %w", err)
	}
	return total, nil
}

func (r *orderRepository) GetCancelledTotalByDateRange(ctx context.Context, startDate, endDate time.Time) (float64, error) {
	query := `
		SELECT COALESCE(SUM(total_amount), 0)
		FROM transactions
		WHERE cancelled_at IS NOT NULL
		AND cancelled_at BETWEEN ? AND ?
	`
	var total float64
	if err := r.db.QueryRowContext(ctx, query, startDate, endDate).Scan(&total); err != nil {
		return 0, fmt.Errorf("gagal mengambil total batal transaksi: %w", err)
	}
	return total, nil
}

func (r *orderRepository) GetAdditionalChargesSummary(ctx context.Context, startDate, endDate time.Time) (float64, []AdditionalChargeBreakdown, error) {
	query := `
		SELECT
			oac.name,
			MIN(oac.charge_type) as charge_type,
			MIN(oac.value) as value,
			COALESCE(SUM(oac.applied_amount), 0) as total_amount
		FROM order_additional_charges oac
		INNER JOIN orders o ON oac.order_id = o.id
		WHERE o.created_at BETWEEN ? AND ?
		AND o.payment_status = 'paid'
		AND o.is_merged = 0
		AND o.voided_at IS NULL
		AND NOT EXISTS (
			SELECT 1
			FROM transactions t
			WHERE t.order_id = o.id
			AND t.status = 'cancelled'
		)
		GROUP BY
			oac.name,
			CASE
				WHEN lower(oac.name) IN ('kompliment', 'diskon') THEN lower(oac.name)
				ELSE oac.charge_type
			END,
			CASE
				WHEN lower(oac.name) IN ('kompliment', 'diskon') THEN 0
				ELSE oac.value
			END
		ORDER BY total_amount DESC
	`

	rows, err := r.db.QueryContext(ctx, query, startDate, endDate)
	if err != nil {
		return 0, nil, fmt.Errorf("gagal mengambil ringkasan biaya tambahan: %w", err)
	}
	defer rows.Close()

	total := 0.0
	breakdowns := []AdditionalChargeBreakdown{}
	for rows.Next() {
		var breakdown AdditionalChargeBreakdown
		if err := rows.Scan(&breakdown.Name, &breakdown.ChargeType, &breakdown.Value, &breakdown.TotalAmount); err != nil {
			return 0, nil, fmt.Errorf("gagal scan ringkasan biaya tambahan: %w", err)
		}
		total += breakdown.TotalAmount
		breakdowns = append(breakdowns, breakdown)
	}

	if err := rows.Err(); err != nil {
		return 0, nil, fmt.Errorf("gagal membaca ringkasan biaya tambahan: %w", err)
	}

	return total, breakdowns, nil
}

// GetProductsSold menghitung total produk yang terjual
func (r *orderRepository) GetProductsSold(ctx context.Context, startDate, endDate time.Time) (int64, error) {
	query := `
		SELECT 
			COALESCE(SUM(oi.qty), 0) as total_qty
		FROM order_items oi
		INNER JOIN orders o ON oi.order_id = o.id
		WHERE o.created_at BETWEEN ? AND ?
		AND o.voided_at IS NULL
		AND NOT EXISTS (
			SELECT 1
			FROM transactions t
			WHERE t.order_id = o.id
			AND t.status = 'cancelled'
		)
	`

	var totalQty int64
	err := r.db.QueryRowContext(ctx, query, startDate, endDate).Scan(&totalQty)
	if err != nil {
		return 0, fmt.Errorf("gagal mengambil total produk terjual: %w", err)
	}

	return totalQty, nil
}

// GetRevenueTimeSeries mendapatkan data revenue berdasarkan time series
func (r *orderRepository) GetRevenueTimeSeries(ctx context.Context, startDate, endDate time.Time, period string) ([]TimeSeriesData, error) {
	var result []TimeSeriesData

	if period == "daily" {
		// Untuk harian, tampilkan per jam (0-23)
		query := `
			SELECT 
				strftime('%H', created_at) as hour,
				COALESCE(SUM(total_amount), 0) as revenue
			FROM orders o
			WHERE DATE(o.created_at) = ?
			AND o.voided_at IS NULL
			AND NOT EXISTS (
				SELECT 1
				FROM transactions t
				WHERE t.order_id = o.id
				AND t.status = 'cancelled'
			)
			GROUP BY strftime('%H', created_at)
			ORDER BY hour
		`

		rows, err := r.db.QueryContext(ctx, query, startDate.Format("2006-01-02"))
		if err != nil {
			return nil, fmt.Errorf("gagal mengambil revenue per jam: %w", err)
		}
		defer rows.Close()

		// Buat map untuk data yang ada
		revenueMap := make(map[string]float64)
		for rows.Next() {
			var hour string
			var revenue float64
			if err := rows.Scan(&hour, &revenue); err != nil {
				return nil, err
			}
			revenueMap[hour] = revenue
		}

		// Fill semua jam 00-23, gunakan 0 jika tidak ada data
		for i := 0; i < 24; i++ {
			hourStr := fmt.Sprintf("%02d", i)
			revenue := revenueMap[hourStr]
			result = append(result, TimeSeriesData{
				TimeLabel: hourStr,
				Revenue:   revenue,
			})
		}

	} else {
		// Untuk mingguan dan bulanan, tampilkan per hari
		query := `
			SELECT 
				DATE(created_at) as day,
				COALESCE(SUM(total_amount), 0) as revenue
			FROM orders o
			WHERE o.created_at BETWEEN ? AND ?
			AND o.voided_at IS NULL
			AND NOT EXISTS (
				SELECT 1
				FROM transactions t
				WHERE t.order_id = o.id
				AND t.status = 'cancelled'
			)
			GROUP BY DATE(created_at)
			ORDER BY day
		`

		rows, err := r.db.QueryContext(ctx, query, startDate, endDate)
		if err != nil {
			return nil, fmt.Errorf("gagal mengambil revenue per hari: %w", err)
		}
		defer rows.Close()

		// Buat map untuk data yang ada
		revenueMap := make(map[string]float64)
		for rows.Next() {
			var day string
			var revenue float64
			if err := rows.Scan(&day, &revenue); err != nil {
				return nil, err
			}
			revenueMap[day] = revenue
		}

		// Fill semua hari dalam range, gunakan 0 jika tidak ada data
		currentDate := startDate
		for !currentDate.After(endDate) {
			dayStr := currentDate.Format("2006-01-02")
			revenue := revenueMap[dayStr]
			result = append(result, TimeSeriesData{
				TimeLabel: dayStr,
				Revenue:   revenue,
			})
			currentDate = currentDate.AddDate(0, 0, 1)
		}
	}

	return result, nil
}

// SplitBillPayment menambahkan pembayaran parsial (split bill)
func (r *orderRepository) SplitBillPayment(ctx context.Context, orderID string, amount float64, paymentMethod string, note string, createdBy string, items []SplitBillItem) error {
	return r.execTx(ctx, func(q *db.Queries, tx *sql.Tx) error {
		if len(items) > 0 {
			qtyByID := make(map[string]int64, len(items))
			for _, item := range items {
				if item.ItemID == "" || item.Qty <= 0 {
					return fmt.Errorf("item_id dan qty wajib diisi")
				}
				qtyByID[item.ItemID] += item.Qty
			}

			if len(qtyByID) == 0 {
				return fmt.Errorf("items tidak boleh kosong")
			}

			orderItems, err := q.GetOrderItems(ctx, orderID)
			if err != nil {
				return fmt.Errorf("gagal mendapatkan item order: %w", err)
			}

			matched := 0
			for _, orderItem := range orderItems {
				qty, ok := qtyByID[orderItem.ID]
				if !ok {
					continue
				}
				if qty > orderItem.Qty {
					return fmt.Errorf("qty melebihi jumlah item")
				}

				newQty := orderItem.Qty - qty
				var err error
				if newQty == 0 {
					_, err = tx.ExecContext(ctx, `
						DELETE FROM order_items
						WHERE id = ?
					`, orderItem.ID)
				} else {
					_, err = tx.ExecContext(ctx, `
						UPDATE order_items
						SET qty = ?, updated_at = CURRENT_TIMESTAMP
						WHERE id = ?
					`, newQty, orderItem.ID)
				}
				if err != nil {
					return err
				}
				matched++
			}

			if matched != len(qtyByID) {
				return fmt.Errorf("item_id tidak ditemukan")
			}
		}

		// Create payment record
		paymentID := ulid.MustNew(ulid.Now(), rand.Reader).String()
		_, err := q.CreatePayment(ctx, db.CreatePaymentParams{
			ID:            paymentID,
			OrderID:       orderID,
			Amount:        amount,
			PaymentMethod: paymentMethod,
			PaymentNote:   sql.NullString{String: note, Valid: note != ""},
			CreatedBy:     createdBy,
		})
		if err != nil {
			return fmt.Errorf("gagal membuat pembayaran: %w", err)
		}

		// Get total paid amount
		totalPaidRow, err := q.GetOrderTotalPaid(ctx, orderID)
		if err != nil {
			return fmt.Errorf("gagal mendapatkan total pembayaran: %w", err)
		}

		// Get order to check total amount
		order, err := q.GetOrderWithItems(ctx, orderID)
		if err != nil {
			return fmt.Errorf("gagal mendapatkan order: %w", err)
		}

		// Extract total paid as float64
		totalPaid, err := parseNumeric(totalPaidRow)
		if err != nil {
			return fmt.Errorf("gagal konversi total_paid: %w", err)
		}

		// Update order paid amount and status
		paymentStatus := "partial"
		if totalPaid >= order.TotalAmount {
			paymentStatus = "paid"
		}

		err = q.UpdateOrderPaidAmount(ctx, db.UpdateOrderPaidAmountParams{
			PaidAmount:    totalPaid,
			PaymentStatus: paymentStatus,
			ID:            orderID,
		})
		if err != nil {
			return fmt.Errorf("gagal update order: %w", err)
		}

		return nil
	})
}

// MergeTables menggabungkan beberapa order/meja menjadi satu
func (r *orderRepository) MergeTables(ctx context.Context, sourceOrderIDs []string, targetTableNumber string) (string, error) {
	var newOrderID string

	err := r.execTx(ctx, func(q *db.Queries, tx *sql.Tx) error {
		// Collect all items and calculate totals
		var allItems []db.OrderItem
		var totalAmount float64
		var totalPax int64
		var customerNames []string
		var createdBy string

		for _, sourceID := range sourceOrderIDs {
			order, err := q.GetOrderWithItems(ctx, sourceID)
			if err != nil {
				return fmt.Errorf("gagal mendapatkan order sumber %s: %w", sourceID, err)
			}
			if order.PaymentStatus == "paid" {
				return fmt.Errorf("order %s sudah dibayar", sourceID)
			}
			if order.IsMerged == 1 {
				return fmt.Errorf("order %s sudah digabung", sourceID)
			}

			items, err := q.GetOrderItems(ctx, sourceID)
			if err != nil {
				return fmt.Errorf("gagal mendapatkan item untuk order %s: %w", sourceID, err)
			}

			allItems = append(allItems, items...)
			totalAmount += order.TotalAmount
			totalPax += order.Pax
			if order.CustomerName.Valid && order.CustomerName.String != "" {
				customerNames = append(customerNames, order.CustomerName.String)
			}
			if createdBy == "" && order.CreatedBy.Valid && order.CreatedBy.String != "" {
				createdBy = order.CreatedBy.String
			}
		}

		// Create new merged order
		generatedID, genErr := r.generateOrderID(ctx, tx, targetTableNumber)
		if genErr != nil {
			return fmt.Errorf("gagal membuat nomor pesanan: %w", genErr)
		}
		newOrderID = generatedID
		var customerName string
		if len(customerNames) > 0 {
			customerName = customerNames[0] // Use first customer name
		}

		_, err := q.CreateOrder(ctx, db.CreateOrderParams{
			ID:           newOrderID,
			TableNumber:  targetTableNumber,
			CustomerName: sql.NullString{String: customerName, Valid: customerName != ""},
			Pax:          totalPax,
			BasketSize:   int64(len(allItems)),
			TotalAmount:  totalAmount,
			CreatedBy:    sql.NullString{String: createdBy, Valid: createdBy != ""},
		})
		if err != nil {
			return fmt.Errorf("gagal membuat order gabungan: %w", err)
		}

		// Transfer all items to new order
		for _, sourceID := range sourceOrderIDs {
			err = q.TransferOrderItems(ctx, db.TransferOrderItemsParams{
				OrderID:   newOrderID,
				OrderID_2: sourceID,
			})
			if err != nil {
				return fmt.Errorf("gagal transfer item dari %s: %w", sourceID, err)
			}

			// Mark source order as merged
			err = q.MergeOrders(ctx, db.MergeOrdersParams{
				MergedFrom: sql.NullString{String: newOrderID, Valid: true},
				ID:         sourceID,
			})
			if err != nil {
				return fmt.Errorf("gagal menandai order sebagai merged: %w", err)
			}
		}

		_, _, err = r.recalculateOrderTotals(ctx, q, tx, newOrderID)
		if err != nil {
			return err
		}

		return nil
	})

	return newOrderID, err
}

// GetOrderPayments mendapatkan semua pembayaran untuk order (untuk tracking split bill)
func (r *orderRepository) GetOrderPayments(ctx context.Context, orderID string) ([]db.Payment, error) {
	return db.New(r.db).GetPaymentsByOrder(ctx, orderID)
}

func (r *orderRepository) VoidOrder(ctx context.Context, orderID string, voidedBy string, voidReason string) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}

	var paymentStatus string
	var voidedAt sql.NullTime
	err = tx.QueryRowContext(ctx, `
		SELECT payment_status, voided_at
		FROM orders
		WHERE id = ?
	`, orderID).Scan(&paymentStatus, &voidedAt)
	if err != nil {
		_ = tx.Rollback()
		return err
	}

	if voidedAt.Valid {
		_ = tx.Rollback()
		return ErrOrderVoided
	}

	if paymentStatus == "paid" {
		_ = tx.Rollback()
		return ErrOrderAlreadyPaid
	}

	_, err = tx.ExecContext(ctx, `
		UPDATE orders
		SET voided_at = CURRENT_TIMESTAMP, voided_by = ?, void_reason = ?, updated_at = CURRENT_TIMESTAMP
		WHERE id = ?
	`, voidedBy, voidReason, orderID)
	if err != nil {
		_ = tx.Rollback()
		return err
	}

	return tx.Commit()
}

func (r *orderRepository) ListVoidedOrders(ctx context.Context, limit, offset int64) ([]VoidedOrderHistory, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT
			o.id,
			o.table_number,
			o.total_amount,
			o.payment_status,
			o.created_at,
			o.voided_at,
			o.voided_by,
			o.void_reason,
			u.full_name
		FROM orders o
		LEFT JOIN users u ON o.voided_by = u.id
		WHERE o.voided_at IS NOT NULL
		ORDER BY o.voided_at DESC
		LIMIT ? OFFSET ?
	`, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := []VoidedOrderHistory{}
	for rows.Next() {
		var item VoidedOrderHistory
		if err := rows.Scan(
			&item.ID,
			&item.TableNumber,
			&item.TotalAmount,
			&item.PaymentStatus,
			&item.CreatedAt,
			&item.VoidedAt,
			&item.VoidedBy,
			&item.VoidReason,
			&item.VoidedByName,
		); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	if err := rows.Close(); err != nil {
		return nil, err
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

func (r *orderRepository) CountVoidedOrders(ctx context.Context) (int64, error) {
	var total int64
	if err := r.db.QueryRowContext(ctx, `
		SELECT COUNT(*)
		FROM orders
		WHERE voided_at IS NOT NULL
	`).Scan(&total); err != nil {
		return 0, err
	}
	return total, nil
}

func (r *orderRepository) ListVoidedOrdersByDateRange(ctx context.Context, startDate, endDate time.Time, limit, offset int64) ([]VoidedOrderHistory, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT
			o.id,
			o.table_number,
			o.total_amount,
			o.payment_status,
			o.created_at,
			o.voided_at,
			o.voided_by,
			o.void_reason,
			u.full_name
		FROM orders o
		LEFT JOIN users u ON o.voided_by = u.id
		WHERE o.voided_at IS NOT NULL
		AND o.voided_at BETWEEN ? AND ?
		ORDER BY o.voided_at DESC
		LIMIT ? OFFSET ?
	`, startDate, endDate, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := []VoidedOrderHistory{}
	for rows.Next() {
		var item VoidedOrderHistory
		if err := rows.Scan(
			&item.ID,
			&item.TableNumber,
			&item.TotalAmount,
			&item.PaymentStatus,
			&item.CreatedAt,
			&item.VoidedAt,
			&item.VoidedBy,
			&item.VoidReason,
			&item.VoidedByName,
		); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	if err := rows.Close(); err != nil {
		return nil, err
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

func (r *orderRepository) CountVoidedOrdersByDateRange(ctx context.Context, startDate, endDate time.Time) (int64, error) {
	var total int64
	if err := r.db.QueryRowContext(ctx, `
		SELECT COUNT(*)
		FROM orders
		WHERE voided_at IS NOT NULL
		AND voided_at BETWEEN ? AND ?
	`, startDate, endDate).Scan(&total); err != nil {
		return 0, err
	}
	return total, nil
}
