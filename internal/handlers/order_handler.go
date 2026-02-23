package handlers

import (
	"backend/internal/db"
	"backend/internal/middleware"
	"backend/internal/repositories"
	"backend/internal/services"
	"backend/internal/workers"
	"backend/pkg/utils"
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"math"
	"time"

	"github.com/labstack/echo/v5"
	"golang.org/x/crypto/bcrypt"
)

type OrderHandler struct {
	service            services.OrderService
	transactionService services.TransactionService
	customerService    services.CustomerService
	queries            *db.Queries
	db                 *sql.DB
	realtime           RealtimeBroadcaster
}

type RealtimeBroadcaster interface {
	Emit(event string, payload map[string]interface{})
}

type splitBillItem struct {
	ItemID string `json:"item_id"`
	Qty    int64  `json:"qty"`
}

func NewOrderHandler(service services.OrderService, transactionService services.TransactionService, customerService services.CustomerService, queries *db.Queries, dbConn *sql.DB, realtime RealtimeBroadcaster) *OrderHandler {
	return &OrderHandler{
		service:            service,
		transactionService: transactionService,
		customerService:    customerService,
		queries:            queries,
		db:                 dbConn,
		realtime:           realtime,
	}
}

func (h *OrderHandler) emitEvent(event string, payload map[string]interface{}) {
	if h.realtime == nil {
		return
	}
	h.realtime.Emit(event, payload)
}

func (h *OrderHandler) ensureOpenCashierShift(ctx context.Context) error {
	row := h.db.QueryRowContext(ctx, `
		SELECT id
		FROM cashier_shifts
		WHERE status = 'open'
		ORDER BY opened_at DESC
		LIMIT 1
	`)
	var shiftID string
	return row.Scan(&shiftID)
}

type CreateOrderRequest struct {
	TableNumber   string                        `json:"table_number"`
	CustomerName  string                        `json:"customer_name,omitempty"`
	CustomerPhone string                        `json:"customer_phone,omitempty"`
	Pax           int64                         `json:"pax"`
	Items         []repositories.OrderItemInput `json:"items"`
	PrinterID     string                        `json:"printer_id,omitempty"`
}

type CreateOrderResponse struct {
	OrderID string `json:"order_id"`
	Message string `json:"message"`
}

type AddOrderItemsRequest struct {
	Items []repositories.OrderItemInput `json:"items"`
}

func toOrderResponse(order *db.Order, waiterName string, mergedFromTableNumber string) map[string]interface{} {
	customerName := ""
	if order.CustomerName.Valid {
		customerName = order.CustomerName.String
	}

	customerPhone := ""
	if order.CustomerPhone.Valid {
		customerPhone = order.CustomerPhone.String
	}

	customerID := ""
	if order.CustomerID.Valid {
		customerID = order.CustomerID.String
	}

	mergedFrom := ""
	if order.MergedFrom.Valid {
		mergedFrom = order.MergedFrom.String
	}

	createdBy := ""
	if order.CreatedBy.Valid {
		createdBy = order.CreatedBy.String
	}

	return map[string]interface{}{
		"id":                       order.ID,
		"table_number":             order.TableNumber,
		"customer_name":            customerName,
		"customer_phone":           customerPhone,
		"customer_id":              customerID,
		"pax":                      order.Pax,
		"basket_size":              order.BasketSize,
		"total_amount":             order.TotalAmount,
		"paid_amount":              order.PaidAmount,
		"order_status":             order.OrderStatus,
		"created_by":               createdBy,
		"waiter_name":              waiterName,
		"payment_status":           order.PaymentStatus,
		"merged_from":              mergedFrom,
		"merged_from_table_number": mergedFromTableNumber,
		"is_merged":                order.IsMerged == 1,
		"created_at":               order.CreatedAt,
		"updated_at":               order.UpdatedAt,
	}
}

func remainingAmount(order *db.Order) float64 {
	remaining := order.TotalAmount - order.PaidAmount
	if remaining < 0 {
		return 0
	}
	return remaining
}

func toOrderResponseForCashier(order *db.Order, waiterName string, mergedFromTableNumber string) map[string]interface{} {
	response := toOrderResponse(order, waiterName, mergedFromTableNumber)
	response["original_total_amount"] = order.TotalAmount
	response["remaining_amount"] = remainingAmount(order)
	response["total_amount"] = response["remaining_amount"]
	return response
}

func (h *OrderHandler) getWaiterName(ctx context.Context, order *db.Order) string {
	if order.CreatedBy.Valid && order.CreatedBy.String != "" {
		user, err := h.queries.GetUserByID(ctx, order.CreatedBy.String)
		if err == nil {
			return user.FullName
		}
	}
	return ""
}

func (h *OrderHandler) getMergedFromTableNumber(ctx context.Context, order *db.Order) string {
	if !order.MergedFrom.Valid || order.MergedFrom.String == "" {
		return ""
	}
	mergedOrder, err := h.queries.GetOrderWithItems(ctx, order.MergedFrom.String)
	if err != nil {
		return ""
	}
	return mergedOrder.TableNumber
}

func (h *OrderHandler) HandleCreateOrder(c *echo.Context) error {
	var req CreateOrderRequest
	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	// Validate request
	if req.TableNumber == "" {
		return BadRequestResponse(c, "table_number wajib diisi")
	}

	if req.Pax <= 0 {
		return BadRequestResponse(c, "pax harus lebih dari 0")
	}

	if len(req.Items) == 0 {
		return BadRequestResponse(c, "items tidak boleh kosong")
	}

	// Validate each item
	for i, item := range req.Items {
		if item.ProductID == "" {
			return BadRequestResponse(c, "product_id wajib diisi untuk semua item")
		}
		if item.Qty <= 0 {
			return BadRequestResponse(c, "qty harus lebih dari 0")
		}
		req.Items[i] = item
	}

	customerID := ""
	if req.CustomerPhone != "" {
		customer, err := h.customerService.GetCustomerByPhone((*c).Request().Context(), req.CustomerPhone)
		if err != nil {
			if err == sql.ErrNoRows {
				if req.CustomerName == "" {
					return BadRequestResponse(c, "Nomor HP belum terdaftar. Isi nama pelanggan untuk mendaftarkan.")
				}
				createdCustomer, err := h.customerService.CreateCustomer((*c).Request().Context(), req.CustomerName, req.CustomerPhone)
				if err != nil {
					return InternalErrorResponse(c, "Gagal menyimpan data pelanggan: "+err.Error())
				}
				req.CustomerName = createdCustomer.Name
				customerID = createdCustomer.ID
			} else {
				return InternalErrorResponse(c, "Gagal mengambil data pelanggan: "+err.Error())
			}
		} else {
			req.CustomerName = customer.Name
			customerID = customer.ID
		}
	}

	createdBy := ""
	claims, err := middleware.GetUserFromContext(c)
	if err == nil {
		createdBy = claims.UserID
	}

	// Create order with items atomically
	orderID, err := h.service.CreateOrder((*c).Request().Context(), repositories.OrderInput{
		TableNumber:   req.TableNumber,
		CustomerName:  req.CustomerName,
		CustomerPhone: req.CustomerPhone,
		CustomerID:    customerID,
		Pax:           req.Pax,
		Items:         req.Items,
		PrinterID:     req.PrinterID,
		CreatedBy:     createdBy,
	})
	if err != nil {
		return InternalErrorResponse(c, "Gagal membuat order: "+err.Error())
	}

	// Return success immediately (print jobs are in queue)
	h.emitEvent("order_created", map[string]interface{}{
		"order_id":     orderID,
		"table_number": req.TableNumber,
	})
	return SuccessResponse(c, "Order berhasil dibuat, print jobs dalam antrian", map[string]string{
		"order_id": orderID,
	})
}

func (h *OrderHandler) HandleAddItemsToOrder(c *echo.Context) error {
	orderID := c.Param("id")

	var req AddOrderItemsRequest
	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	if len(req.Items) == 0 {
		return BadRequestResponse(c, "items tidak boleh kosong")
	}

	for i, item := range req.Items {
		if item.ProductID == "" {
			return BadRequestResponse(c, "product_id wajib diisi untuk semua item")
		}
		if item.Qty <= 0 {
			return BadRequestResponse(c, "qty harus lebih dari 0")
		}
		req.Items[i] = item
	}

	if err := h.service.AddItemsToOrder((*c).Request().Context(), orderID, req.Items); err != nil {
		if err == sql.ErrNoRows {
			return NotFoundResponse(c, "Order tidak ditemukan")
		}
		return InternalErrorResponse(c, "Gagal menambah item order: "+err.Error())
	}

	h.emitEvent("order_items_updated", map[string]interface{}{
		"order_id": orderID,
	})
	return SuccessResponse(c, "Item berhasil ditambahkan ke order", nil)
}

func (h *OrderHandler) HandleAddItemsToOrderByTable(c *echo.Context) error {
	tableID := c.Param("table_id")

	var req AddOrderItemsRequest
	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	if len(req.Items) == 0 {
		return BadRequestResponse(c, "items tidak boleh kosong")
	}

	for i, item := range req.Items {
		if item.ProductID == "" {
			return BadRequestResponse(c, "product_id wajib diisi untuk semua item")
		}
		if item.Qty <= 0 {
			return BadRequestResponse(c, "qty harus lebih dari 0")
		}
		req.Items[i] = item
	}

	order, _, err := h.service.GetOrderByTableID((*c).Request().Context(), tableID)
	if err != nil {
		if err == sql.ErrNoRows {
			return NotFoundResponse(c, "Order aktif tidak ditemukan")
		}
		return InternalErrorResponse(c, "Gagal mengambil order aktif: "+err.Error())
	}

	if err := h.service.AddItemsToOrder((*c).Request().Context(), order.ID, req.Items); err != nil {
		return InternalErrorResponse(c, "Gagal menambah item order: "+err.Error())
	}

	h.emitEvent("order_items_updated", map[string]interface{}{
		"order_id": order.ID,
	})
	return SuccessResponse(c, "Item berhasil ditambahkan ke order", map[string]string{
		"order_id": order.ID,
	})
}

// HandleUpdateOrderItemStatus - untuk checker update status item (cooking/ready/served)
func (h *OrderHandler) HandleUpdateOrderItemStatus(c *echo.Context) error {
	itemID := c.Param("id")

	var req struct {
		Status string `json:"status"`
	}

	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	// Validate status
	validStatuses := map[string]bool{
		"pending": true,
		"cooking": true,
		"ready":   true,
		"served":  true,
	}

	if !validStatuses[req.Status] {
		return BadRequestResponse(c, "status harus: pending, cooking, ready, atau served")
	}

	if err := h.service.UpdateOrderItemStatus((*c).Request().Context(), itemID, req.Status); err != nil {
		return InternalErrorResponse(c, "Gagal update status item: "+err.Error())
	}

	h.emitEvent("item_status_updated", map[string]interface{}{
		"item_id": itemID,
		"status":  req.Status,
	})
	return SuccessResponse(c, "Status item berhasil diupdate", nil)
}

func (h *OrderHandler) HandleUpdateOrderItemQty(c *echo.Context) error {
	itemID := c.Param("id")

	var req struct {
		Qty int64 `json:"qty"`
	}

	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	if req.Qty < 0 {
		return BadRequestResponse(c, "qty harus 0 atau lebih")
	}

	if err := h.service.UpdateOrderItemQty((*c).Request().Context(), itemID, req.Qty); err != nil {
		if errors.Is(err, repositories.ErrOrderItemNotFound) {
			return NotFoundResponse(c, "Item tidak ditemukan")
		}
		if errors.Is(err, repositories.ErrOrderItemProcessed) {
			return BadRequestResponse(c, "Item sudah diproses oleh kitchen")
		}
		if errors.Is(err, repositories.ErrOrderAlreadyPaid) {
			return BadRequestResponse(c, "Order sudah dibayar")
		}
		if errors.Is(err, repositories.ErrInvalidItemQty) {
			return BadRequestResponse(c, "qty tidak valid")
		}
		return InternalErrorResponse(c, "Gagal update qty item: "+err.Error())
	}

	h.emitEvent("order_items_updated", map[string]interface{}{
		"item_id": itemID,
		"qty":     req.Qty,
	})
	return SuccessResponse(c, "Qty item berhasil diupdate", nil)
}

// HandleProcessPayment - untuk kasir proses pembayaran
func (h *OrderHandler) HandleProcessPayment(c *echo.Context) error {
	orderID := c.Param("id")
	var req struct {
		PaymentMethod string  `json:"payment_method"`
		PaidAmount    float64 `json:"paid_amount"`
	}

	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	validMethods := map[string]bool{
		"cash": true, "card": true, "qris": true, "transfer": true,
	}
	if !validMethods[req.PaymentMethod] {
		return BadRequestResponse(c, "payment_method tidak valid. Valid: cash, card, qris, transfer")
	}

	ctx := (*c).Request().Context()

	if err := h.ensureOpenCashierShift(ctx); err != nil {
		if err == sql.ErrNoRows {
			return BadRequestResponse(c, "Shift kasir belum dibuka")
		}
		return InternalErrorResponse(c, "Gagal memeriksa shift kasir")
	}

	claims, err := middleware.GetUserFromContext(c)
	if err != nil {
		return UnauthorizedResponse(c, "User tidak terautentikasi")
	}

	order, _, err := h.service.GetOrderDetails(ctx, orderID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil detail order: "+err.Error())
	}

	remaining := order.TotalAmount - order.PaidAmount
	if remaining <= 0 {
		return BadRequestResponse(c, "Tagihan sudah lunas")
	}
	paidAmount := req.PaidAmount
	if paidAmount <= 0 {
		paidAmount = remaining
	}
	if paidAmount < remaining {
		return BadRequestResponse(c, "Jumlah bayar kurang dari total tagihan")
	}
	changeAmount := paidAmount - remaining

	// Update payment status
	if err := h.service.ProcessPayment(ctx, orderID); err != nil {
		return InternalErrorResponse(c, "Gagal proses pembayaran: "+err.Error())
	}

	// Update order status to served
	if err := h.service.UpdateOrderStatus(ctx, orderID, "served"); err != nil {
		return InternalErrorResponse(c, "Gagal update status order: "+err.Error())
	}

	updatedTables := map[string]bool{
		order.TableNumber: true,
	}
	if err := h.queries.UpdateTableStatus(ctx, db.UpdateTableStatusParams{
		Status:      "available",
		TableNumber: order.TableNumber,
	}); err != nil {
		return InternalErrorResponse(c, "Gagal update status meja: "+err.Error())
	}

	mergedOrders, err := h.queries.GetMergedOrders(ctx, sql.NullString{
		String: order.ID,
		Valid:  true,
	})
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil order hasil gabungan: "+err.Error())
	}
	for _, mergedOrder := range mergedOrders {
		if mergedOrder.TableNumber == "" {
			continue
		}
		if updatedTables[mergedOrder.TableNumber] {
			continue
		}
		if err := h.queries.UpdateTableStatus(ctx, db.UpdateTableStatusParams{
			Status:      "available",
			TableNumber: mergedOrder.TableNumber,
		}); err != nil {
			return InternalErrorResponse(c, "Gagal update status meja gabungan: "+err.Error())
		}
		updatedTables[mergedOrder.TableNumber] = true
	}

	tableNumbers := make([]string, 0, len(updatedTables))
	for tableNumber := range updatedTables {
		tableNumbers = append(tableNumbers, tableNumber)
	}

	_, err = h.transactionService.CreateTransactionForOrder(
		ctx,
		orderID,
		remaining,
		req.PaymentMethod,
		claims.UserID,
	)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mencatat transaksi: "+err.Error())
	}

	paidOrder, paidItems, err := h.service.GetOrderDetails(ctx, orderID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil detail order setelah pembayaran: "+err.Error())
	}

	payments, err := h.service.GetOrderPayments(ctx, orderID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil riwayat pembayaran: "+err.Error())
	}

	h.enqueueFullPaymentReceipt(ctx, paidOrder, paidItems, req.PaymentMethod, paidAmount, changeAmount)

	h.emitEvent("payment_completed", map[string]interface{}{
		"order_id":      orderID,
		"table_numbers": tableNumbers,
	})
	h.emitEvent("table_status_updated", map[string]interface{}{
		"table_numbers": tableNumbers,
	})
	return SuccessResponse(c, "Pembayaran berhasil diproses", map[string]interface{}{
		"order_id":       orderID,
		"total_amount":   remainingAmount(paidOrder),
		"remaining":      remainingAmount(paidOrder),
		"original_total": paidOrder.TotalAmount,
		"paid_amount":    paidOrder.PaidAmount,
		"payment_status": paidOrder.PaymentStatus,
		"payments":       payments,
	})
}

func (h *OrderHandler) HandleApplyDiscount(c *echo.Context) error {
	orderID := c.Param("id")

	var req struct {
		ChargeType string  `json:"charge_type"`
		Value      float64 `json:"value"`
	}
	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}
	if req.ChargeType != "percentage" && req.ChargeType != "fixed" {
		return BadRequestResponse(c, "charge_type harus percentage atau fixed")
	}
	if req.Value <= 0 {
		return BadRequestResponse(c, "Nilai diskon harus lebih dari 0")
	}

	ctx := (*c).Request().Context()
	if err := h.ensureOpenCashierShift(ctx); err != nil {
		if err == sql.ErrNoRows {
			return BadRequestResponse(c, "Shift kasir belum dibuka")
		}
		return InternalErrorResponse(c, "Gagal memeriksa shift kasir")
	}

	if err := h.service.ApplyOrderDiscount(ctx, orderID, req.ChargeType, req.Value); err != nil {
		return BadRequestResponse(c, err.Error())
	}

	h.emitEvent("order_items_updated", map[string]interface{}{
		"order_id": orderID,
	})
	return SuccessResponse(c, "Diskon berhasil diterapkan", nil)
}

func (h *OrderHandler) HandleApplyCompliment(c *echo.Context) error {
	orderID := c.Param("id")
	ctx := (*c).Request().Context()
	if err := h.ensureOpenCashierShift(ctx); err != nil {
		if err == sql.ErrNoRows {
			return BadRequestResponse(c, "Shift kasir belum dibuka")
		}
		return InternalErrorResponse(c, "Gagal memeriksa shift kasir")
	}

	claims, err := middleware.GetUserFromContext(c)
	if err != nil {
		return UnauthorizedResponse(c, "User tidak terautentikasi")
	}

	if err := h.service.ApplyOrderCompliment(ctx, orderID); err != nil {
		return BadRequestResponse(c, err.Error())
	}

	if err := h.service.ProcessPayment(ctx, orderID); err != nil {
		return InternalErrorResponse(c, "Gagal memperbarui status pembayaran: "+err.Error())
	}

	if err := h.service.UpdateOrderStatus(ctx, orderID, "served"); err != nil {
		return InternalErrorResponse(c, "Gagal update status order: "+err.Error())
	}

	order, items, err := h.service.GetOrderDetails(ctx, orderID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil detail order: "+err.Error())
	}

	h.enqueueComplimentReceipt(ctx, order, items)

	updatedTables := map[string]bool{
		order.TableNumber: true,
	}
	if err := h.queries.UpdateTableStatus(ctx, db.UpdateTableStatusParams{
		Status:      "available",
		TableNumber: order.TableNumber,
	}); err != nil {
		return InternalErrorResponse(c, "Gagal update status meja: "+err.Error())
	}

	mergedOrders, err := h.queries.GetMergedOrders(ctx, sql.NullString{
		String: order.ID,
		Valid:  true,
	})
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil order hasil gabungan: "+err.Error())
	}
	for _, mergedOrder := range mergedOrders {
		if mergedOrder.TableNumber == "" {
			continue
		}
		if updatedTables[mergedOrder.TableNumber] {
			continue
		}
		if err := h.queries.UpdateTableStatus(ctx, db.UpdateTableStatusParams{
			Status:      "available",
			TableNumber: mergedOrder.TableNumber,
		}); err != nil {
			return InternalErrorResponse(c, "Gagal update status meja gabungan: "+err.Error())
		}
		updatedTables[mergedOrder.TableNumber] = true
	}

	tableNumbers := make([]string, 0, len(updatedTables))
	for tableNumber := range updatedTables {
		tableNumbers = append(tableNumbers, tableNumber)
	}

	_, err = h.transactionService.CreateTransactionForOrder(ctx, orderID, 0, "cash", claims.UserID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mencatat transaksi: "+err.Error())
	}

	h.emitEvent("order_items_updated", map[string]interface{}{
		"order_id": orderID,
	})
	h.emitEvent("payment_completed", map[string]interface{}{
		"order_id":      orderID,
		"table_numbers": tableNumbers,
	})
	h.emitEvent("table_status_updated", map[string]interface{}{
		"table_numbers": tableNumbers,
	})
	return SuccessResponse(c, "Order berhasil dikompliment", nil)
}

func (h *OrderHandler) enqueueFullPaymentReceipt(ctx context.Context, order *db.Order, items []db.OrderItem, paymentMethod string, paidAmount float64, changeAmount float64) {
	printerID, ok := h.getReceiptPrinterID(ctx)
	if !ok {
		return
	}

	receiptItems := make([]workers.ReceiptItem, 0, len(items))
	subtotal := 0
	for _, item := range items {
		price := int(math.Round(item.Price))
		total := price * int(item.Qty)
		receiptItems = append(receiptItems, workers.ReceiptItem{
			Name:     item.ProductName,
			Quantity: int(item.Qty),
			Price:    price,
			Total:    total,
		})
		subtotal += total
	}

	customerName := ""
	if order.CustomerName.Valid {
		customerName = order.CustomerName.String
	}

	payload := workers.PrintJobData{
		OrderID:                order.ID,
		ReceiptNumber:          "TRX-" + order.ID,
		TableNumber:            order.TableNumber,
		CustomerName:           customerName,
		WaiterName:             h.getWaiterName(ctx, order),
		CashierName:            "",
		Items:                  receiptItems,
		Subtotal:               subtotal,
		AdditionalChargesTotal: h.getAdditionalChargesTotal(ctx, order.ID),
		AdditionalCharges:      h.getAdditionalChargesBreakdown(ctx, order.ID),
		Tax:                    0,
		Total:                  int(math.Round(order.TotalAmount)),
		PaymentMethod:          paymentMethod,
		PaidAmount:             int(math.Round(paidAmount)),
		ChangeAmount:           int(math.Round(changeAmount)),
		DateTime:               time.Now(),
	}

	payloadJSON, err := json.Marshal(payload)
	if err != nil {
		return
	}

	_, _ = h.queries.CreatePrintJob(ctx, db.CreatePrintJobParams{
		ID:        utils.GenerateULID(),
		PrinterID: printerID,
		Data:      string(payloadJSON),
	})
}

func (h *OrderHandler) enqueueComplimentReceipt(ctx context.Context, order *db.Order, items []db.OrderItem) {
	printerID, ok := h.getReceiptPrinterID(ctx)
	if !ok {
		return
	}

	receiptItems, subtotal := buildReceiptItems(items)

	customerName := ""
	if order.CustomerName.Valid {
		customerName = order.CustomerName.String
	}

	payload := workers.PrintJobData{
		OrderID:                order.ID,
		ReceiptNumber:          "COMP-" + order.ID,
		TableNumber:            order.TableNumber,
		CustomerName:           customerName,
		WaiterName:             h.getWaiterName(ctx, order),
		CashierName:            "",
		Items:                  receiptItems,
		Subtotal:               subtotal,
		AdditionalChargesTotal: h.getAdditionalChargesTotal(ctx, order.ID),
		AdditionalCharges:      h.getAdditionalChargesBreakdown(ctx, order.ID),
		Tax:                    0,
		Total:                  int(math.Round(order.TotalAmount)),
		PaymentMethod:          "compliment",
		PaidAmount:             0,
		ChangeAmount:           0,
		DateTime:               time.Now(),
	}

	payloadJSON, err := json.Marshal(payload)
	if err != nil {
		return
	}

	_, _ = h.queries.CreatePrintJob(ctx, db.CreatePrintJobParams{
		ID:        utils.GenerateULID(),
		PrinterID: printerID,
		Data:      string(payloadJSON),
	})
}

func (h *OrderHandler) HandleVoidOrder(c *echo.Context) error {
	orderID := c.Param("id")
	var req struct {
		ManagerPIN string `json:"manager_pin"`
		Reason     string `json:"reason"`
	}

	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	if len(req.ManagerPIN) != 4 {
		return BadRequestResponse(c, "PIN harus tepat 4 digit")
	}
	for _, char := range req.ManagerPIN {
		if char < '0' || char > '9' {
			return BadRequestResponse(c, "PIN harus berupa angka")
		}
	}

	managers, err := h.queries.ListActiveManagers((*c).Request().Context())
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data manager")
	}

	var managerID string
	for _, manager := range managers {
		if err := bcrypt.CompareHashAndPassword([]byte(manager.PasswordHash), []byte(req.ManagerPIN)); err == nil {
			managerID = manager.ID
			break
		}
	}
	if managerID == "" {
		return UnauthorizedResponse(c, "PIN manager salah")
	}

	order, _, err := h.service.GetOrderDetails((*c).Request().Context(), orderID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil detail order: "+err.Error())
	}

	if err := h.service.VoidOrder((*c).Request().Context(), orderID, managerID, req.Reason); err != nil {
		if errors.Is(err, repositories.ErrOrderAlreadyPaid) {
			return BadRequestResponse(c, "Order sudah dibayar")
		}
		if errors.Is(err, repositories.ErrOrderVoided) {
			return BadRequestResponse(c, "Order sudah di-void")
		}
		if err == sql.ErrNoRows {
			return NotFoundResponse(c, "Order tidak ditemukan")
		}
		return InternalErrorResponse(c, "Gagal void order: "+err.Error())
	}

	ctx := (*c).Request().Context()
	updatedTables := map[string]bool{
		order.TableNumber: true,
	}
	if err := h.queries.UpdateTableStatus(ctx, db.UpdateTableStatusParams{
		Status:      "available",
		TableNumber: order.TableNumber,
	}); err != nil {
		return InternalErrorResponse(c, "Gagal update status meja: "+err.Error())
	}

	mergedOrders, err := h.queries.GetMergedOrders(ctx, sql.NullString{
		String: order.ID,
		Valid:  true,
	})
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil order hasil gabungan: "+err.Error())
	}
	for _, mergedOrder := range mergedOrders {
		if mergedOrder.TableNumber == "" {
			continue
		}
		if updatedTables[mergedOrder.TableNumber] {
			continue
		}
		if err := h.queries.UpdateTableStatus(ctx, db.UpdateTableStatusParams{
			Status:      "available",
			TableNumber: mergedOrder.TableNumber,
		}); err != nil {
			return InternalErrorResponse(c, "Gagal update status meja gabungan: "+err.Error())
		}
		updatedTables[mergedOrder.TableNumber] = true
	}

	tableNumbers := make([]string, 0, len(updatedTables))
	for tableNumber := range updatedTables {
		tableNumbers = append(tableNumbers, tableNumber)
	}

	h.emitEvent("order_voided", map[string]interface{}{
		"order_id":      orderID,
		"table_numbers": tableNumbers,
	})
	h.emitEvent("table_status_updated", map[string]interface{}{
		"table_numbers": tableNumbers,
	})
	return SuccessResponse(c, "Order berhasil di-void", map[string]interface{}{
		"order_id":      orderID,
		"table_numbers": tableNumbers,
	})
}

func (h *OrderHandler) HandleListOrders(c *echo.Context) error {
	params := GetPaginationParams(c)
	isCashier := false
	if claims, err := middleware.GetUserFromContext(c); err == nil {
		isCashier = claims.Role == "cashier"
	}

	orders, total, err := h.service.ListOrders(
		(*c).Request().Context(),
		int64(params.PageSize),
		int64(params.Offset),
	)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data order: "+err.Error())
	}

	responses := make([]map[string]interface{}, 0, len(orders))
	ctx := (*c).Request().Context()
	for i := range orders {
		order := orders[i]
		waiterName := h.getWaiterName(ctx, &order)
		mergedFromTableNumber := h.getMergedFromTableNumber(ctx, &order)
		if isCashier {
			responses = append(responses, toOrderResponseForCashier(&order, waiterName, mergedFromTableNumber))
			continue
		}
		responses = append(responses, toOrderResponse(&order, waiterName, mergedFromTableNumber))
	}

	pagination := CalculatePagination(params.Page, params.PageSize, total)
	return PaginatedSuccessResponse(c, "Data order berhasil diambil", responses, pagination)
}

// HandleGetOrderDetails - untuk checker lihat detail order
func (h *OrderHandler) HandleGetOrderDetails(c *echo.Context) error {
	orderID := c.Param("id")

	order, items, err := h.service.GetOrderDetails((*c).Request().Context(), orderID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil detail order: "+err.Error())
	}

	payments, err := h.service.GetOrderPayments((*c).Request().Context(), orderID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil riwayat pembayaran: "+err.Error())
	}

	adjustments := h.getManualAdjustments((*c).Request().Context(), orderID)
	additionalChargesTotal := h.getAdditionalChargesTotal((*c).Request().Context(), orderID)
	additionalCharges := h.getAdditionalChargesBreakdown((*c).Request().Context(), orderID)

	waiterName := h.getWaiterName((*c).Request().Context(), order)
	mergedFromTableNumber := h.getMergedFromTableNumber((*c).Request().Context(), order)
	orderResponse := toOrderResponse(order, waiterName, mergedFromTableNumber)
	if claims, err := middleware.GetUserFromContext(c); err == nil && claims.Role == "cashier" {
		orderResponse = toOrderResponseForCashier(order, waiterName, mergedFromTableNumber)
	}
	return SuccessResponse(c, "Detail order berhasil diambil", map[string]interface{}{
		"order":                    orderResponse,
		"items":                    items,
		"payments":                 payments,
		"adjustments":              adjustments,
		"additional_charges_total": additionalChargesTotal,
		"additional_charges":       additionalCharges,
	})
}

func (h *OrderHandler) HandleGetVoidedOrders(c *echo.Context) error {
	params := GetPaginationParams(c)
	startDateStr := c.QueryParam("start_date")
	endDateStr := c.QueryParam("end_date")

	var (
		orders []repositories.VoidedOrderHistory
		total  int64
		err    error
	)

	if startDateStr != "" || endDateStr != "" {
		startDate, endDate, parseErr := parseDateRangeWithLimit(startDateStr, endDateStr, 3)
		if parseErr != nil {
			return BadRequestResponse(c, parseErr.Error())
		}
		orders, total, err = h.service.ListVoidedOrdersByDateRange(
			(*c).Request().Context(),
			startDate,
			endDate,
			int64(params.PageSize),
			int64(params.Offset),
		)
	} else {
		orders, total, err = h.service.ListVoidedOrders(
			(*c).Request().Context(),
			int64(params.PageSize),
			int64(params.Offset),
		)
	}
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil histori void: "+err.Error())
	}

	type voidedOrderResponse struct {
		ID            string     `json:"id"`
		TableNumber   string     `json:"table_number"`
		TotalAmount   float64    `json:"total_amount"`
		PaymentStatus string     `json:"payment_status"`
		CreatedAt     time.Time  `json:"created_at"`
		VoidedAt      *time.Time `json:"voided_at"`
		VoidedBy      string     `json:"voided_by"`
		VoidedByName  string     `json:"voided_by_name"`
		VoidReason    string     `json:"void_reason"`
	}

	responses := make([]voidedOrderResponse, 0, len(orders))
	for _, order := range orders {
		var voidedAt *time.Time
		if order.VoidedAt.Valid {
			voidedAt = &order.VoidedAt.Time
		}
		voidedBy := ""
		if order.VoidedBy.Valid {
			voidedBy = order.VoidedBy.String
		}
		voidedByName := ""
		if order.VoidedByName.Valid {
			voidedByName = order.VoidedByName.String
		}
		voidReason := ""
		if order.VoidReason.Valid {
			voidReason = order.VoidReason.String
		}
		responses = append(responses, voidedOrderResponse{
			ID:            order.ID,
			TableNumber:   order.TableNumber,
			TotalAmount:   order.TotalAmount,
			PaymentStatus: order.PaymentStatus,
			CreatedAt:     order.CreatedAt,
			VoidedAt:      voidedAt,
			VoidedBy:      voidedBy,
			VoidedByName:  voidedByName,
			VoidReason:    voidReason,
		})
	}

	pagination := CalculatePagination(params.Page, params.PageSize, total)
	return PaginatedSuccessResponse(c, "Histori void berhasil diambil", responses, pagination)
}

func (h *OrderHandler) HandleGetDisplayOrders(c *echo.Context) error {
	claims, err := middleware.GetUserFromContext(c)
	if err != nil {
		return UnauthorizedResponse(c, "User tidak terautentikasi")
	}

	ctx := (*c).Request().Context()
	orders, err := h.queries.GetPendingOrders(ctx)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data order display: "+err.Error())
	}

	destination := ""
	if claims.Role == "kitchen" || claims.Role == "bar" {
		destination = claims.Role
	}

	displayOrders := make([]map[string]interface{}, 0, len(orders))
	for _, order := range orders {
		items, err := h.queries.GetOrderItems(ctx, order.ID)
		if err != nil {
			return InternalErrorResponse(c, "Gagal mengambil item order: "+err.Error())
		}

		filteredItems := items
		if destination != "" {
			selectedItems := make([]db.OrderItem, 0, len(items))
			for _, item := range items {
				if item.Destination == destination {
					selectedItems = append(selectedItems, item)
				}
			}
			filteredItems = selectedItems
		}

		if len(filteredItems) == 0 {
			continue
		}

		currentOrder := order
		waiterName := h.getWaiterName(ctx, &currentOrder)
		mergedFromTableNumber := h.getMergedFromTableNumber(ctx, &currentOrder)
		displayOrders = append(displayOrders, map[string]interface{}{
			"order": toOrderResponse(&currentOrder, waiterName, mergedFromTableNumber),
			"items": filteredItems,
		})
	}

	return SuccessResponse(c, "Data display berhasil diambil", map[string]interface{}{
		"orders": displayOrders,
	})
}

// HandleGetOrderAnalytics - untuk manager/owner lihat analytics
func (h *OrderHandler) HandleGetOrderAnalytics(c *echo.Context) error {
	startDateStr := c.QueryParam("start_date")
	endDateStr := c.QueryParam("end_date")

	var startDate, endDate time.Time
	var err error

	// Default to today if not provided
	if startDateStr == "" {
		startDate = time.Now().Truncate(24 * time.Hour)
	} else {
		startDate, err = time.Parse("2006-01-02", startDateStr)
		if err != nil {
			return BadRequestResponse(c, "Format start_date tidak valid, gunakan YYYY-MM-DD")
		}
	}

	if endDateStr == "" {
		endDate = time.Now()
	} else {
		endDate, err = time.Parse("2006-01-02", endDateStr)
		if err != nil {
			return BadRequestResponse(c, "Format end_date tidak valid, gunakan YYYY-MM-DD")
		}
		// Set to end of day
		endDate = endDate.Add(23*time.Hour + 59*time.Minute + 59*time.Second)
	}

	analytics, err := h.service.GetAnalytics((*c).Request().Context(), startDate, endDate)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil analytics: "+err.Error())
	}

	// Calculate previous period for comparison
	duration := endDate.Sub(startDate)
	prevStartDate := startDate.Add(-duration)
	prevEndDate := startDate.Add(-time.Second) // 1 second before current period starts

	prevAnalytics, _ := h.service.GetAnalytics((*c).Request().Context(), prevStartDate, prevEndDate)

	// Helper function to calculate percentage change
	calculateChange := func(current, previous float64) float64 {
		if previous == 0 {
			if current > 0 {
				return 100.0
			}
			return 0.0
		}
		return ((current - previous) / previous) * 100
	}

	// Convert sql.NullFloat64 to float64 for cleaner JSON
	totalRevenue := 0.0
	if analytics.TotalRevenue.Valid {
		totalRevenue = analytics.TotalRevenue.Float64
	}
	avgOrderValue := 0.0
	if analytics.AvgOrderValue.Valid {
		avgOrderValue = analytics.AvgOrderValue.Float64
	}
	avgBasketSize := 0.0
	if analytics.AvgBasketSize.Valid {
		avgBasketSize = analytics.AvgBasketSize.Float64
	}
	avgPax := 0.0
	if analytics.AvgPax.Valid {
		avgPax = analytics.AvgPax.Float64
	}
	totalPax := 0.0
	if analytics.TotalPax.Valid {
		totalPax = analytics.TotalPax.Float64
	}

	// Get previous period values
	prevTotalRevenue := 0.0
	if prevAnalytics.TotalRevenue.Valid {
		prevTotalRevenue = prevAnalytics.TotalRevenue.Float64
	}
	prevAvgOrderValue := 0.0
	if prevAnalytics.AvgOrderValue.Valid {
		prevAvgOrderValue = prevAnalytics.AvgOrderValue.Float64
	}
	prevAvgBasketSize := 0.0
	if prevAnalytics.AvgBasketSize.Valid {
		prevAvgBasketSize = prevAnalytics.AvgBasketSize.Float64
	}

	// Calculate percentage changes
	revenueChange := calculateChange(totalRevenue, prevTotalRevenue)
	ordersChange := calculateChange(float64(analytics.TotalOrders), float64(prevAnalytics.TotalOrders))
	avgOrderChange := calculateChange(avgOrderValue, prevAvgOrderValue)
	basketSizeChange := calculateChange(avgBasketSize, prevAvgBasketSize)

	// Get actual paid and unpaid revenue from database
	paidRevenue, unpaidRevenue, err := h.service.GetRevenueByPaymentStatus((*c).Request().Context(), startDate, endDate)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data paid/unpaid revenue: "+err.Error())
	}

	prevPaidRevenue, prevUnpaidRevenue, err := h.service.GetRevenueByPaymentStatus((*c).Request().Context(), prevStartDate, prevEndDate)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data paid/unpaid revenue periode sebelumnya: "+err.Error())
	}

	paidRevenueChange := calculateChange(paidRevenue, prevPaidRevenue)
	unpaidRevenueChange := calculateChange(unpaidRevenue, prevUnpaidRevenue)

	additionalChargesTotal, additionalChargesBreakdown, err := h.service.GetAdditionalChargesSummary((*c).Request().Context(), startDate, endDate)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil ringkasan biaya tambahan: "+err.Error())
	}

	voidTotal, err := h.service.GetVoidedTotalByDateRange((*c).Request().Context(), startDate, endDate)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil total void: "+err.Error())
	}

	cancelledTotal, err := h.service.GetCancelledTotalByDateRange((*c).Request().Context(), startDate, endDate)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil total batal transaksi: "+err.Error())
	}

	// Get actual products sold from database (sum of all order_items qty)
	productsSold, err := h.service.GetProductsSold((*c).Request().Context(), startDate, endDate)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data produk terjual: "+err.Error())
	}

	prevProductsSold, err := h.service.GetProductsSold((*c).Request().Context(), prevStartDate, prevEndDate)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data produk terjual periode sebelumnya: "+err.Error())
	}

	productsSoldChange := calculateChange(float64(productsSold), float64(prevProductsSold))

	now := time.Now()
	loc := now.Location()
	dailyStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, loc)
	dailyEnd := dailyStart.Add(23*time.Hour + 59*time.Minute + 59*time.Second)
	weeklyStart := dailyStart.AddDate(0, 0, -int(now.Weekday()))
	weeklyEnd := weeklyStart.AddDate(0, 0, 6).Add(23*time.Hour + 59*time.Minute + 59*time.Second)
	monthlyStart := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, loc)
	monthlyEnd := monthlyStart.AddDate(0, 1, 0).Add(-time.Second)
	mtdStart := monthlyStart
	mtdEnd := now

	dailyAgg, _ := h.service.GetAnalytics((*c).Request().Context(), dailyStart, dailyEnd)
	weeklyAgg, _ := h.service.GetAnalytics((*c).Request().Context(), weeklyStart, weeklyEnd)
	monthlyAgg, _ := h.service.GetAnalytics((*c).Request().Context(), monthlyStart, monthlyEnd)
	mtdAgg, _ := h.service.GetAnalytics((*c).Request().Context(), mtdStart, mtdEnd)

	conv := func(a *db.GetOrderAnalyticsRow) map[string]interface{} {
		tr := 0.0
		if a.TotalRevenue.Valid {
			tr = a.TotalRevenue.Float64
		}
		aov := 0.0
		if a.AvgOrderValue.Valid {
			aov = a.AvgOrderValue.Float64
		}
		abs := 0.0
		if a.AvgBasketSize.Valid {
			abs = a.AvgBasketSize.Float64
		}
		tp := 0.0
		if a.TotalPax.Valid {
			tp = a.TotalPax.Float64
		}
		return map[string]interface{}{
			"total_orders":    a.TotalOrders,
			"total_revenue":   tr,
			"avg_order_value": aov,
			"avg_basket_size": abs,
			"total_pax":       tp,
		}
	}

	return SuccessResponse(c, "Analytics berhasil diambil", map[string]interface{}{
		"period": map[string]string{
			"start": startDate.Format("2006-01-02 15:04:05"),
			"end":   endDate.Format("2006-01-02 15:04:05"),
		},
		"analytics": map[string]interface{}{
			"total_orders":              analytics.TotalOrders,
			"total_revenue":             totalRevenue,
			"avg_order_value":           avgOrderValue,
			"avg_basket_size":           avgBasketSize,
			"avg_pax":                   avgPax,
			"total_pax":                 totalPax,
			"revenue_change_pct":        revenueChange,
			"orders_change_pct":         ordersChange,
			"avg_order_change_pct":      avgOrderChange,
			"basket_change_pct":         basketSizeChange,
			"paid_revenue":              paidRevenue,
			"unpaid_revenue":            unpaidRevenue,
			"paid_revenue_change_pct":   paidRevenueChange,
			"unpaid_revenue_change_pct": unpaidRevenueChange,
			"additional_charges_total":  additionalChargesTotal,
			"additional_charges_items":  additionalChargesBreakdown,
			"void_total":                voidTotal,
			"cancelled_total":           cancelledTotal,
			"products_sold":             productsSold,
			"products_sold_change_pct":  productsSoldChange,
			"summaries": map[string]interface{}{
				"daily":   conv(dailyAgg),
				"weekly":  conv(weeklyAgg),
				"monthly": conv(monthlyAgg),
			},
		},
		"mtd": conv(mtdAgg),
	})
}

// HandleGetRevenueChart - Get revenue time series untuk chart
func (h *OrderHandler) HandleGetRevenueChart(c *echo.Context) error {
	startDateStr := c.QueryParam("start_date")
	endDateStr := c.QueryParam("end_date")
	period := c.QueryParam("period") // "daily", "weekly", "monthly"

	if startDateStr == "" || endDateStr == "" || period == "" {
		return BadRequestResponse(c, "Parameter start_date, end_date, dan period wajib diisi")
	}

	// Validate period
	if period != "daily" && period != "weekly" && period != "monthly" {
		return BadRequestResponse(c, "period harus salah satu dari: daily, weekly, monthly")
	}

	startDate, err := time.Parse("2006-01-02", startDateStr)
	if err != nil {
		return BadRequestResponse(c, "Format start_date tidak valid, gunakan YYYY-MM-DD")
	}

	endDate, err := time.Parse("2006-01-02", endDateStr)
	if err != nil {
		return BadRequestResponse(c, "Format end_date tidak valid, gunakan YYYY-MM-DD")
	}

	// Get time series data
	timeSeries, err := h.service.GetRevenueTimeSeries((*c).Request().Context(), startDate, endDate, period)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data chart: "+err.Error())
	}

	return SuccessResponse(c, "Data chart berhasil diambil", map[string]interface{}{
		"period": period,
		"data":   timeSeries,
	})
}

// HandleSplitBillPayment - Cashier untuk split bill (pembayaran parsial)
func (h *OrderHandler) HandleSplitBillPayment(c *echo.Context) error {
	orderID := c.Param("id")

	var req struct {
		Amount        float64         `json:"amount"`
		PaidAmount    float64         `json:"paid_amount"`
		PaymentMethod string          `json:"payment_method"`
		Note          string          `json:"note,omitempty"`
		Items         []splitBillItem `json:"items,omitempty"`
	}

	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	// Validate payment method
	validMethods := map[string]bool{
		"cash": true, "card": true, "qris": true, "transfer": true,
	}
	if !validMethods[req.PaymentMethod] {
		return BadRequestResponse(c, "payment_method tidak valid. Valid: cash, card, qris, transfer")
	}

	ctx := (*c).Request().Context()

	if err := h.ensureOpenCashierShift(ctx); err != nil {
		if err == sql.ErrNoRows {
			return BadRequestResponse(c, "Shift kasir belum dibuka")
		}
		return InternalErrorResponse(c, "Gagal memeriksa shift kasir")
	}

	// Get user from context
	claims, err := middleware.GetUserFromContext(c)
	if err != nil {
		return UnauthorizedResponse(c, err.Error())
	}

	orderSnapshot, itemsSnapshot, err := h.service.GetOrderDetails(ctx, orderID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil detail order: "+err.Error())
	}

	orderSubtotal := 0.0
	for _, item := range itemsSnapshot {
		orderSubtotal += item.Price * float64(item.Qty)
	}
	manualAdjustmentsTotal := h.getManualAdjustmentsTotal(ctx, orderID)

	remaining := orderSnapshot.TotalAmount - orderSnapshot.PaidAmount
	if remaining <= 0 {
		return BadRequestResponse(c, "Tagihan sudah lunas")
	}

	orderPaymentAmount := req.Amount
	var splitReceiptItems []workers.ReceiptItem
	var splitSubtotal int
	if len(req.Items) > 0 {
		splitReceiptItems, splitSubtotal, err = buildSplitReceiptItems(itemsSnapshot, req.Items)
		if err != nil {
			return BadRequestResponse(c, err.Error())
		}
		splitAdditionalCharges, err := h.calculateActiveAdditionalChargesAmount(ctx, float64(splitSubtotal))
		if err != nil {
			return InternalErrorResponse(c, "Gagal menghitung biaya tambahan split bill: "+err.Error())
		}
		manualShare := 0.0
		if manualAdjustmentsTotal != 0 && orderSubtotal > 0 {
			manualShare = manualAdjustmentsTotal * (float64(splitSubtotal) / orderSubtotal)
		}
		orderPaymentAmount = float64(splitSubtotal) + splitAdditionalCharges + manualShare
	}

	if orderPaymentAmount <= 0 {
		return BadRequestResponse(c, "Jumlah pembayaran harus lebih dari 0")
	}
	orderPaymentAmount = math.Round(orderPaymentAmount)
	remaining = math.Round(remaining)
	if orderPaymentAmount > remaining {
		return BadRequestResponse(c, "Jumlah pembayaran melebihi sisa tagihan")
	}
	receiptPaidAmount := req.PaidAmount
	if req.PaymentMethod != "cash" {
		receiptPaidAmount = orderPaymentAmount
	} else {
		if len(req.Items) > 0 && receiptPaidAmount > 0 && math.Abs(receiptPaidAmount-req.Amount) < 0.000001 {
			receiptPaidAmount = orderPaymentAmount
		}
		if receiptPaidAmount <= 0 {
			receiptPaidAmount = orderPaymentAmount
		}
		receiptPaidAmount = math.Round(receiptPaidAmount)
		if receiptPaidAmount < orderPaymentAmount {
			return BadRequestResponse(c, "Jumlah bayar kurang dari total split")
		}
	}
	changeAmount := receiptPaidAmount - orderPaymentAmount

	repoItems := make([]repositories.SplitBillItem, 0, len(req.Items))
	for _, item := range req.Items {
		repoItems = append(repoItems, repositories.SplitBillItem{
			ItemID: item.ItemID,
			Qty:    item.Qty,
		})
	}

	// Process split payment
	err = h.service.SplitBillPayment(ctx, orderID, orderPaymentAmount, req.PaymentMethod, req.Note, claims.UserID, repoItems)
	if err != nil {
		return InternalErrorResponse(c, "Gagal proses pembayaran: "+err.Error())
	}

	_, err = h.transactionService.CreateTransaction(
		ctx,
		orderID,
		orderPaymentAmount,
		req.PaymentMethod,
		nil,
		claims.UserID,
	)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mencatat transaksi: "+err.Error())
	}

	// Get updated order and payments
	order, items, err := h.service.GetOrderDetails(ctx, orderID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil detail order: "+err.Error())
	}

	payments, _ := h.service.GetOrderPayments(ctx, orderID)
	latestPaymentAmount := orderPaymentAmount
	if len(payments) > 0 {
		latestPaymentAmount = payments[len(payments)-1].Amount
	}

	tableNumbers := []string{}
	if order.PaymentStatus == "paid" {
		if err := h.service.UpdateOrderStatus(ctx, orderID, "served"); err != nil {
			return InternalErrorResponse(c, "Gagal update status order: "+err.Error())
		}

		updatedTables := map[string]bool{
			order.TableNumber: true,
		}
		if err := h.queries.UpdateTableStatus(ctx, db.UpdateTableStatusParams{
			Status:      "available",
			TableNumber: order.TableNumber,
		}); err != nil {
			return InternalErrorResponse(c, "Gagal update status meja: "+err.Error())
		}

		mergedOrders, err := h.queries.GetMergedOrders(ctx, sql.NullString{
			String: order.ID,
			Valid:  true,
		})
		if err != nil {
			return InternalErrorResponse(c, "Gagal mengambil order hasil gabungan: "+err.Error())
		}
		for _, mergedOrder := range mergedOrders {
			if mergedOrder.TableNumber == "" {
				continue
			}
			if updatedTables[mergedOrder.TableNumber] {
				continue
			}
			if err := h.queries.UpdateTableStatus(ctx, db.UpdateTableStatusParams{
				Status:      "available",
				TableNumber: mergedOrder.TableNumber,
			}); err != nil {
				return InternalErrorResponse(c, "Gagal update status meja gabungan: "+err.Error())
			}
			updatedTables[mergedOrder.TableNumber] = true
		}

		tableNumbers = make([]string, 0, len(updatedTables))
		for tableNumber := range updatedTables {
			tableNumbers = append(tableNumbers, tableNumber)
		}

		h.emitEvent("table_status_updated", map[string]interface{}{
			"table_numbers": tableNumbers,
		})
	}

	receiptItems := splitReceiptItems
	receiptSubtotal := splitSubtotal
	receiptTotal := int(math.Round(latestPaymentAmount))
	if len(receiptItems) == 0 {
		receiptItems, receiptSubtotal = buildReceiptItems(items)
	}

	h.enqueueSplitPaymentReceipt(ctx, order, receiptItems, receiptSubtotal, receiptTotal, req.PaymentMethod, receiptPaidAmount, changeAmount)

	h.emitEvent("payment_completed", map[string]interface{}{
		"order_id":       orderID,
		"payment_status": order.PaymentStatus,
		"table_numbers":  tableNumbers,
	})
	return SuccessResponse(c, "Pembayaran berhasil dicatat", map[string]interface{}{
		"order_id":       orderID,
		"total_amount":   remainingAmount(order),
		"remaining":      remainingAmount(order),
		"original_total": order.TotalAmount,
		"paid_amount":    order.PaidAmount,
		"payment_status": order.PaymentStatus,
		"payments":       payments,
	})
}

func buildReceiptItems(items []db.OrderItem) ([]workers.ReceiptItem, int) {
	receiptItems := make([]workers.ReceiptItem, 0, len(items))
	subtotal := 0
	for _, item := range items {
		price := int(math.Round(item.Price))
		total := price * int(item.Qty)
		receiptItems = append(receiptItems, workers.ReceiptItem{
			Name:     item.ProductName,
			Quantity: int(item.Qty),
			Price:    price,
			Total:    total,
		})
		subtotal += total
	}
	return receiptItems, subtotal
}

func (h *OrderHandler) getAdditionalChargesTotal(ctx context.Context, orderID string) int {
	row := h.db.QueryRowContext(ctx, `
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

func (h *OrderHandler) getAdditionalChargesBreakdown(ctx context.Context, orderID string) []workers.ReceiptCharge {
	rows, err := h.db.QueryContext(ctx, `
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

type ManualAdjustment struct {
	Name          string  `json:"name"`
	ChargeType    string  `json:"charge_type"`
	Value         float64 `json:"value"`
	AppliedAmount float64 `json:"applied_amount"`
}

func (h *OrderHandler) getManualAdjustments(ctx context.Context, orderID string) []ManualAdjustment {
	rows, err := h.db.QueryContext(ctx, `
		SELECT name, charge_type, value, applied_amount
		FROM order_additional_charges
		WHERE order_id = ?
		  AND charge_id IS NULL
		ORDER BY created_at
	`, orderID)
	if err != nil {
		return nil
	}
	defer rows.Close()

	adjustments := []ManualAdjustment{}
	for rows.Next() {
		var item ManualAdjustment
		if err := rows.Scan(&item.Name, &item.ChargeType, &item.Value, &item.AppliedAmount); err != nil {
			return adjustments
		}
		adjustments = append(adjustments, item)
	}
	return adjustments
}

func (h *OrderHandler) getManualAdjustmentsTotal(ctx context.Context, orderID string) float64 {
	row := h.db.QueryRowContext(ctx, `
		SELECT COALESCE(SUM(applied_amount), 0)
		FROM order_additional_charges
		WHERE order_id = ?
		  AND charge_id IS NULL
	`, orderID)
	var total float64
	if err := row.Scan(&total); err != nil {
		return 0
	}
	return total
}

func (h *OrderHandler) calculateActiveAdditionalChargesAmount(ctx context.Context, subtotal float64) (float64, error) {
	if subtotal <= 0 {
		return 0, nil
	}

	var total float64
	err := h.db.QueryRowContext(ctx, `
		SELECT COALESCE(SUM(
			CASE
				WHEN charge_type = 'percentage' THEN (? * value / 100.0)
				ELSE value
			END
		), 0)
		FROM additional_charges
		WHERE is_active = 1
	`, subtotal).Scan(&total)
	if err != nil {
		return 0, err
	}

	return total, nil
}

func buildSplitReceiptItems(orderItems []db.OrderItem, selected []splitBillItem) ([]workers.ReceiptItem, int, error) {
	qtyByID := make(map[string]int64, len(selected))
	for _, item := range selected {
		if item.ItemID == "" || item.Qty <= 0 {
			return nil, 0, errors.New("item_id dan qty wajib diisi")
		}
		qtyByID[item.ItemID] += item.Qty
	}
	if len(qtyByID) == 0 {
		return nil, 0, errors.New("items tidak boleh kosong")
	}

	receiptItems := make([]workers.ReceiptItem, 0, len(qtyByID))
	subtotal := 0
	matched := 0
	for _, orderItem := range orderItems {
		qty, ok := qtyByID[orderItem.ID]
		if !ok {
			continue
		}
		if qty > orderItem.Qty {
			return nil, 0, errors.New("qty melebihi jumlah item")
		}
		price := int(math.Round(orderItem.Price))
		total := price * int(qty)
		receiptItems = append(receiptItems, workers.ReceiptItem{
			Name:     orderItem.ProductName,
			Quantity: int(qty),
			Price:    price,
			Total:    total,
		})
		subtotal += total
		matched++
	}
	if matched != len(qtyByID) {
		return nil, 0, errors.New("item_id tidak ditemukan")
	}
	return receiptItems, subtotal, nil
}

func (h *OrderHandler) enqueueSplitPaymentReceipt(ctx context.Context, order *db.Order, receiptItems []workers.ReceiptItem, subtotal int, total int, paymentMethod string, paidAmount float64, changeAmount float64) {
	printerID, ok := h.getReceiptPrinterID(ctx)
	if !ok {
		return
	}

	customerName := ""
	if order.CustomerName.Valid {
		customerName = order.CustomerName.String
	}

	payload := workers.PrintJobData{
		OrderID:                order.ID,
		ReceiptNumber:          "TRX-" + order.ID,
		TableNumber:            order.TableNumber,
		CustomerName:           customerName,
		WaiterName:             h.getWaiterName(ctx, order),
		CashierName:            "",
		Items:                  receiptItems,
		Subtotal:               subtotal,
		AdditionalChargesTotal: h.getAdditionalChargesTotal(ctx, order.ID),
		AdditionalCharges:      h.getAdditionalChargesBreakdown(ctx, order.ID),
		Tax:                    0,
		Total:                  total,
		PaymentMethod:          paymentMethod,
		PaidAmount:             int(math.Round(paidAmount)),
		ChangeAmount:           int(math.Round(changeAmount)),
		DateTime:               time.Now(),
		IsSplitPayment:         true,
	}

	payloadJSON, err := json.Marshal(payload)
	if err != nil {
		return
	}

	_, _ = h.queries.CreatePrintJob(ctx, db.CreatePrintJobParams{
		ID:        utils.GenerateULID(),
		PrinterID: printerID,
		Data:      string(payloadJSON),
	})
}

func (h *OrderHandler) getReceiptPrinterID(ctx context.Context) (string, bool) {
	strukPrinters, err := h.queries.ListPrintersByType(ctx, "struk")
	if err == nil && len(strukPrinters) > 0 {
		return strukPrinters[0].ID, true
	}

	cashierPrinters, err := h.queries.ListPrintersByType(ctx, "cashier")
	if err == nil && len(cashierPrinters) > 0 {
		return cashierPrinters[0].ID, true
	}

	return "", false
}

// HandleMergeTables - Waiter/Admin untuk gabung meja
func (h *OrderHandler) HandleMergeTables(c *echo.Context) error {
	var req struct {
		SourceOrderIDs    []string `json:"source_order_ids"`
		TargetTableNumber string   `json:"target_table_number"`
	}

	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	if len(req.SourceOrderIDs) < 2 {
		return BadRequestResponse(c, "Minimal 2 order untuk digabung")
	}

	if req.TargetTableNumber == "" {
		return BadRequestResponse(c, "target_table_number wajib diisi")
	}

	// Merge tables
	newOrderID, err := h.service.MergeTables((*c).Request().Context(), req.SourceOrderIDs, req.TargetTableNumber)
	if err != nil {
		return InternalErrorResponse(c, "Gagal menggabung meja: "+err.Error())
	}

	// Get merged order details
	order, items, err := h.service.GetOrderDetails((*c).Request().Context(), newOrderID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil order gabungan: "+err.Error())
	}

	h.emitEvent("orders_merged", map[string]interface{}{
		"new_order_id":        newOrderID,
		"target_table_number": order.TableNumber,
		"merged_from_orders":  req.SourceOrderIDs,
	})
	return SuccessResponse(c, "Meja berhasil digabung", map[string]interface{}{
		"new_order_id":       newOrderID,
		"table_number":       order.TableNumber,
		"total_amount":       order.TotalAmount,
		"total_pax":          order.Pax,
		"total_items":        len(items),
		"merged_from_orders": req.SourceOrderIDs,
	})
}

// HandleGetOrderByTable - Get active order for a specific table
func (h *OrderHandler) HandleGetOrderByTable(c *echo.Context) error {
	tableID := c.Param("table_id")

	if tableID == "" {
		return BadRequestResponse(c, "table_id wajib diisi")
	}

	// Get order by table
	order, items, err := h.service.GetOrderByTableID((*c).Request().Context(), tableID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil order: "+err.Error())
	}

	waiterName := h.getWaiterName((*c).Request().Context(), order)
	mergedFromTableNumber := h.getMergedFromTableNumber((*c).Request().Context(), order)
	orderResponse := toOrderResponse(order, waiterName, mergedFromTableNumber)
	if claims, err := middleware.GetUserFromContext(c); err == nil && claims.Role == "cashier" {
		orderResponse = toOrderResponseForCashier(order, waiterName, mergedFromTableNumber)
	}
	return SuccessResponse(c, "Detail order berhasil diambil", map[string]interface{}{
		"order": orderResponse,
		"items": items,
	})
}
