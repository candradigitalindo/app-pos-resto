package handlers

import (
	"crypto/rand"
	"database/sql"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"time"

	"backend/internal/workers"

	"github.com/labstack/echo/v5"
	"github.com/oklog/ulid/v2"
)

// PrintHandler handles print-related operations
type PrintHandler struct {
	db *sql.DB
}

// NewPrintHandler creates a new print handler
func NewPrintHandler(db *sql.DB) *PrintHandler {
	return &PrintHandler{db: db}
}

// PrintOrderRequest represents a manual print request
type PrintOrderRequest struct {
	OrderID   string `json:"order_id"`
	PrinterID string `json:"printer_id"`
	PrintType string `json:"print_type"` // "full" or "kitchen"
}

// HandlePrintOrder manually adds an order to print queue
func (h *PrintHandler) HandlePrintOrder(c *echo.Context) error {
	var req PrintOrderRequest
	if err := (*c).Bind(&req); err != nil {
		return (*c).JSON(http.StatusBadRequest, APIResponse{
			Success: false,
			Message: "Invalid request format",
		})
	}

	// Validate inputs
	if req.OrderID == "" || req.PrinterID == "" {
		return (*c).JSON(http.StatusBadRequest, APIResponse{
			Success: false,
			Message: "order_id and printer_id are required",
		})
	}

	// Get order data from database
	orderData, err := h.fetchOrderData(req.OrderID)
	if err != nil {
		return (*c).JSON(http.StatusNotFound, APIResponse{
			Success: false,
			Message: "Order not found: " + err.Error(),
		})
	}

	// Insert into print queue
	dataJSON, _ := json.Marshal(orderData)

	printJobID := ulid.MustNew(ulid.Timestamp(time.Now()), rand.Reader).String()
	_, err = h.db.Exec(`
		INSERT INTO print_queue (id, printer_id, data, status, retry_count, created_at, updated_at)
		VALUES (?, ?, ?, 'pending', 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
	`, printJobID, req.PrinterID, string(dataJSON))

	if err != nil {
		return (*c).JSON(http.StatusInternalServerError, APIResponse{
			Success: false,
			Message: "Failed to add to print queue: " + err.Error(),
		})
	}

	return (*c).JSON(http.StatusOK, APIResponse{
		Success: true,
		Message: "Order added to print queue successfully",
	})
}

// HandleReprintOrder reprints an existing order
func (h *PrintHandler) HandleReprintOrder(c *echo.Context) error {
	orderID := (*c).Param("id")
	var err error

	// Get printer_id from query params or use default cashier printer
	printerIDStr := (*c).QueryParam("printer_id")
	var printerID string

	if printerIDStr != "" {
		printerID = printerIDStr
	} else {
		// Get active cashier printer
		row := h.db.QueryRow(`
			SELECT id FROM printers 
			WHERE printer_type = 'cashier' AND is_active = 1 
			LIMIT 1
		`)
		err = row.Scan(&printerID)
		if err != nil {
			return (*c).JSON(http.StatusNotFound, APIResponse{
				Success: false,
				Message: "No active cashier printer found",
			})
		}
	}

	// Get order data
	orderData, err := h.fetchOrderData(orderID)
	if err != nil {
		return (*c).JSON(http.StatusNotFound, APIResponse{
			Success: false,
			Message: "Order not found: " + err.Error(),
		})
	}

	// Mark as reprint in receipt number
	orderData.ReceiptNumber = orderData.ReceiptNumber + " (REPRINT)"

	// Insert into print queue
	dataJSON, _ := json.Marshal(orderData)

	printJobID := ulid.MustNew(ulid.Timestamp(time.Now()), rand.Reader).String()
	_, err = h.db.Exec(`
		INSERT INTO print_queue (id, printer_id, data, status, retry_count, created_at, updated_at)
		VALUES (?, ?, ?, 'pending', 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
	`, printJobID, printerID, string(dataJSON))

	if err != nil {
		return (*c).JSON(http.StatusInternalServerError, APIResponse{
			Success: false,
			Message: "Failed to add to print queue: " + err.Error(),
		})
	}

	return (*c).JSON(http.StatusOK, APIResponse{
		Success: true,
		Message: "Reprint order added to queue successfully",
	})
}

func (h *PrintHandler) HandlePrintBill(c *echo.Context) error {
	orderID := (*c).Param("id")
	var err error

	printerIDStr := (*c).QueryParam("printer_id")
	var printerID string

	if printerIDStr != "" {
		printerID = printerIDStr
	} else {
		row := h.db.QueryRow(`
			SELECT id FROM printers 
			WHERE printer_type IN ('struk', 'cashier') AND is_active = 1 
			ORDER BY CASE WHEN printer_type = 'struk' THEN 0 ELSE 1 END
			LIMIT 1
		`)
		err = row.Scan(&printerID)
		if err != nil {
			return (*c).JSON(http.StatusNotFound, APIResponse{
				Success: false,
				Message: "No active cashier printer found",
			})
		}
	}

	orderData, err := h.fetchOrderData(orderID)
	if err != nil {
		return (*c).JSON(http.StatusNotFound, APIResponse{
			Success: false,
			Message: "Order not found: " + err.Error(),
		})
	}

	orderData.PaidAmount = 0
	orderData.ChangeAmount = 0
	orderData.IsBill = true

	dataJSON, _ := json.Marshal(orderData)

	printJobID := ulid.MustNew(ulid.Timestamp(time.Now()), rand.Reader).String()
	_, err = h.db.Exec(`
		INSERT INTO print_queue (id, printer_id, data, status, retry_count, created_at, updated_at)
		VALUES (?, ?, ?, 'pending', 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
	`, printJobID, printerID, string(dataJSON))

	if err != nil {
		return (*c).JSON(http.StatusInternalServerError, APIResponse{
			Success: false,
			Message: "Failed to add to print queue: " + err.Error(),
		})
	}

	return (*c).JSON(http.StatusOK, APIResponse{
		Success: true,
		Message: "Bill added to queue successfully",
	})
}

func (h *PrintHandler) HandleRetryPrintQueue(c *echo.Context) error {
	queueID := (*c).Param("id")
	if queueID == "" {
		return (*c).JSON(http.StatusBadRequest, APIResponse{
			Success: false,
			Message: "queue id is required",
		})
	}

	var printerID string
	var dataJSON string
	var status string
	row := h.db.QueryRow(`
		SELECT printer_id, data, status
		FROM print_queue
		WHERE id = ?
		LIMIT 1
	`, queueID)
	err := row.Scan(&printerID, &dataJSON, &status)
	if err != nil {
		if err == sql.ErrNoRows {
			return (*c).JSON(http.StatusNotFound, APIResponse{
				Success: false,
				Message: "Print queue not found",
			})
		}
		return (*c).JSON(http.StatusInternalServerError, APIResponse{
			Success: false,
			Message: "Failed to fetch print queue: " + err.Error(),
		})
	}

	if status != "failed" {
		return (*c).JSON(http.StatusBadRequest, APIResponse{
			Success: false,
			Message: "Print queue is not failed",
		})
	}

	var jobData workers.PrintJobData
	if err := json.Unmarshal([]byte(dataJSON), &jobData); err == nil {
		if jobData.RetryOf == "" {
			jobData.RetryOf = queueID
		}
		if raw, err := json.Marshal(jobData); err == nil {
			dataJSON = string(raw)
		}
	} else {
		var payload map[string]interface{}
		if err := json.Unmarshal([]byte(dataJSON), &payload); err == nil {
			payload["retry_of"] = queueID
			if raw, err := json.Marshal(payload); err == nil {
				dataJSON = string(raw)
			}
		}
	}

	printJobID := ulid.MustNew(ulid.Timestamp(time.Now()), rand.Reader).String()
	_, err = h.db.Exec(`
		INSERT INTO print_queue (id, printer_id, data, status, retry_count, created_at, updated_at)
		VALUES (?, ?, ?, 'pending', 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
	`, printJobID, printerID, dataJSON)
	if err != nil {
		return (*c).JSON(http.StatusInternalServerError, APIResponse{
			Success: false,
			Message: "Failed to retry print queue: " + err.Error(),
		})
	}

	return (*c).JSON(http.StatusOK, APIResponse{
		Success: true,
		Message: "Print queue retried successfully",
	})
}

// HandleGetPrintQueue gets current print queue status
func (h *PrintHandler) HandleGetPrintQueue(c *echo.Context) error {
	status := (*c).QueryParam("status") // Filter by status

	query := `
		SELECT pq.id, pq.printer_id, pq.status, pq.retry_count, 
		       pq.error_message, pq.created_at, pq.data,
		       p.name as printer_name, p.printer_type, p.ip_address, p.port
		FROM print_queue pq
		LEFT JOIN printers p ON pq.printer_id = p.id
	`

	args := []interface{}{}
	if status != "" {
		query += " WHERE pq.status = ?"
		args = append(args, status)
	}

	query += " ORDER BY pq.created_at DESC LIMIT 100"

	rows, err := h.db.Query(query, args...)
	if err != nil {
		return (*c).JSON(http.StatusInternalServerError, APIResponse{
			Success: false,
			Message: "Failed to fetch print queue: " + err.Error(),
		})
	}
	defer rows.Close()

	type QueueItem struct {
		ID             string    `json:"id"`
		PrinterID      string    `json:"printer_id"`
		PrinterName    string    `json:"printer_name"`
		PrinterType    string    `json:"printer_type"`
		PrinterIP      string    `json:"printer_ip"`
		PrinterPort    int       `json:"printer_port"`
		Status         string    `json:"status"`
		RetryCount     int       `json:"retry_count"`
		ErrorMessage   *string   `json:"error_message"`
		CreatedAt      time.Time `json:"created_at"`
		ContentType    string    `json:"content_type"`
		ContentSummary string    `json:"content_summary"`
		ReceiptNumber  string    `json:"receipt_number"`
		TableNumber    string    `json:"table_number"`
		OrderID        string    `json:"order_id"`
	}

	queue := []QueueItem{}
	for rows.Next() {
		var item QueueItem
		var dataJSON string
		var printerName sql.NullString
		var printerType sql.NullString
		var printerIP sql.NullString
		var printerPort sql.NullInt64
		err := rows.Scan(
			&item.ID, &item.PrinterID, &item.Status, &item.RetryCount,
			&item.ErrorMessage, &item.CreatedAt, &dataJSON,
			&printerName, &printerType, &printerIP, &printerPort,
		)
		if err != nil {
			continue
		}
		if printerName.Valid {
			item.PrinterName = printerName.String
		}
		if printerType.Valid {
			item.PrinterType = printerType.String
		}
		if printerIP.Valid {
			item.PrinterIP = printerIP.String
		}
		if printerPort.Valid {
			item.PrinterPort = int(printerPort.Int64)
		}
		if dataJSON != "" {
			var jobData workers.PrintJobData
			if err := json.Unmarshal([]byte(dataJSON), &jobData); err == nil {
				item.ContentType = getPrintContentType(jobData, item.PrinterType)
				item.ContentSummary = getPrintContentSummary(jobData, item.PrinterType)
				item.ReceiptNumber = jobData.ReceiptNumber
				item.TableNumber = jobData.TableNumber
				item.OrderID = jobData.OrderID
			}
		}
		queue = append(queue, item)
	}

	return (*c).JSON(http.StatusOK, APIResponse{
		Success: true,
		Message: "Print queue fetched successfully",
		Data:    queue,
	})
}

func getPrintContentType(data workers.PrintJobData, printerType string) string {
	if data.IsHandover {
		return "Serah Terima"
	}
	if data.IsCloseShift {
		return "Tutup Shift"
	}
	if data.IsCashInReceipt {
		return "Kas Masuk"
	}
	if data.IsCashOutReceipt {
		return "Kas Keluar"
	}
	if data.IsBill {
		return "Bill"
	}
	if data.IsSplitPayment {
		return "Split Bill"
	}
	if printerType == "kitchen" || printerType == "bar" {
		if printerType == "bar" {
			return "Bar"
		}
		return "Kitchen"
	}
	return "Struk"
}

func getPrintContentSummary(data workers.PrintJobData, printerType string) string {
	contentType := getPrintContentType(data, printerType)
	parts := []string{}
	if contentType != "" {
		parts = append(parts, contentType)
	}
	if data.ReceiptNumber != "" {
		parts = append(parts, data.ReceiptNumber)
	}
	if data.TableNumber != "" && data.TableNumber != "-" {
		parts = append(parts, "Meja "+data.TableNumber)
	}
	if data.IsHandover {
		if data.HandoverFrom != "" || data.HandoverTo != "" {
			parts = append(parts, data.HandoverFrom+" → "+data.HandoverTo)
		}
	}
	if data.IsCloseShift {
		if data.CashierName != "" {
			parts = append(parts, data.CashierName)
		}
	}
	if data.IsCashInReceipt || data.IsCashOutReceipt {
		if data.MovementName != "" {
			parts = append(parts, data.MovementName)
		}
		if data.MovementAmount > 0 {
			parts = append(parts, "Rp "+formatAmount(data.MovementAmount))
		}
	}
	if !data.IsHandover && !data.IsCloseShift && !data.IsCashInReceipt && !data.IsCashOutReceipt {
		if data.Total > 0 && (contentType == "Struk" || contentType == "Bill" || contentType == "Split Bill") {
			parts = append(parts, "Total Rp "+formatAmount(data.Total))
		}
		if (printerType == "kitchen" || printerType == "bar") && len(data.Items) > 0 {
			parts = append(parts, fmt.Sprintf("%d item", len(data.Items)))
		}
	}
	if len(parts) == 0 {
		return "-"
	}
	return joinParts(parts)
}

func joinParts(parts []string) string {
	if len(parts) == 0 {
		return ""
	}
	result := parts[0]
	for i := 1; i < len(parts); i++ {
		if parts[i] == "" {
			continue
		}
		if result == "" {
			result = parts[i]
			continue
		}
		result += " • " + parts[i]
	}
	return result
}

func formatAmount(value int) string {
	if value == 0 {
		return "0"
	}
	negative := value < 0
	if negative {
		value = -value
	}
	digits := []byte{}
	for value > 0 {
		digits = append(digits, byte('0'+(value%10)))
		value /= 10
	}
	formatted := []byte{}
	for i := 0; i < len(digits); i++ {
		if i != 0 && i%3 == 0 {
			formatted = append(formatted, '.')
		}
		formatted = append(formatted, digits[i])
	}
	for i, j := 0, len(formatted)-1; i < j; i, j = i+1, j-1 {
		formatted[i], formatted[j] = formatted[j], formatted[i]
	}
	if negative {
		return "-" + string(formatted)
	}
	return string(formatted)
}

// fetchOrderData retrieves order data from database for printing
func (h *PrintHandler) fetchOrderData(orderID string) (*workers.PrintJobData, error) {
	// This is a simplified version - adjust based on your actual schema
	var data workers.PrintJobData

	// Get order info
	row := h.db.QueryRow(`
		SELECT 
			id, table_number, customer_name, total_amount, paid_amount, created_at, created_by
		FROM orders
		WHERE id = ?
	`, orderID)

	var totalAmount float64
	var paidAmount float64
	var customerName sql.NullString
	var createdBy sql.NullString
	err := row.Scan(
		&data.OrderID, &data.TableNumber, &customerName,
		&totalAmount, &paidAmount, &data.DateTime, &createdBy,
	)
	if err != nil {
		return nil, err
	}
	if customerName.Valid {
		data.CustomerName = customerName.String
	}
	if createdBy.Valid && createdBy.String != "" {
		userRow := h.db.QueryRow(`SELECT full_name FROM users WHERE id = ? LIMIT 1`, createdBy.String)
		var fullName string
		if err := userRow.Scan(&fullName); err == nil {
			data.WaiterName = fullName
		}
	}

	// Generate receipt number
	data.ReceiptNumber = "TRX-" + orderID

	// Get order items
	rows, err := h.db.Query(`
		SELECT oi.product_name, oi.qty, oi.price
		FROM order_items oi
		WHERE oi.order_id = ?
	`, orderID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	data.Items = []workers.ReceiptItem{}
	subtotal := 0
	for rows.Next() {
		var item workers.ReceiptItem
		var price float64
		err := rows.Scan(&item.Name, &item.Quantity, &price)
		if err != nil {
			continue
		}
		item.Price = int(math.Round(price))
		item.Total = item.Price * item.Quantity
		subtotal += item.Total
		data.Items = append(data.Items, item)
	}

	data.Subtotal = subtotal
	data.AdditionalChargesTotal = h.getAdditionalChargesTotal(orderID)
	data.AdditionalCharges = h.getAdditionalChargesBreakdown(orderID)
	data.Tax = 0
	data.Total = int(math.Round(totalAmount))
	data.PaidAmount = int(math.Round(paidAmount))
	data.ChangeAmount = data.PaidAmount - data.Total

	return &data, nil
}

func (h *PrintHandler) getAdditionalChargesTotal(orderID string) int {
	row := h.db.QueryRow(`
		SELECT COALESCE(SUM(oac.applied_amount), 0)
		FROM order_additional_charges oac
		LEFT JOIN additional_charges ac ON ac.id = oac.charge_id
		WHERE oac.order_id = ?
		  AND (oac.charge_id IS NULL OR ac.is_active = 1)
	`, orderID)
	var total float64
	if err := row.Scan(&total); err != nil {
		return 0
	}
	return int(math.Round(total))
}

func (h *PrintHandler) getAdditionalChargesBreakdown(orderID string) []workers.ReceiptCharge {
	rows, err := h.db.Query(`
		SELECT oac.name, COALESCE(SUM(oac.applied_amount), 0)
		FROM order_additional_charges oac
		LEFT JOIN additional_charges ac ON ac.id = oac.charge_id
		WHERE oac.order_id = ?
		  AND (oac.charge_id IS NULL OR ac.is_active = 1)
		GROUP BY oac.charge_id, oac.name
		ORDER BY MIN(oac.created_at), oac.charge_id
	`, orderID)
	if err != nil {
		return nil
	}
	defer rows.Close()

	breakdowns := []workers.ReceiptCharge{}
	for rows.Next() {
		var name string
		var total float64
		if err := rows.Scan(&name, &total); err != nil {
			return breakdowns
		}
		breakdowns = append(breakdowns, workers.ReceiptCharge{
			Name:   name,
			Amount: int(math.Round(total)),
		})
	}
	return breakdowns
}
