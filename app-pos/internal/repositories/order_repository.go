package repositories

import (
	"backend/internal/db"
	"context"
	"database/sql"
	"errors"
	"time"
)

// OrderItemInput represents an item in the order request.
type OrderItemInput struct {
	ProductID string `json:"product_id"`
	Qty       int64  `json:"qty"`
}

type SplitBillItem struct {
	ItemID string `json:"item_id"`
	Qty    int64  `json:"qty"`
}

// OrderInput represents the complete order request.
type OrderInput struct {
	TableNumber   string           `json:"table_number"`
	CustomerName  string           `json:"customer_name,omitempty"`
	CustomerPhone string           `json:"customer_phone,omitempty"`
	CustomerID    string           `json:"customer_id,omitempty"`
	Pax           int64            `json:"pax"` // Number of guests
	Items         []OrderItemInput `json:"items"`
	PrinterID     string           `json:"printer_id"` // Target printer ULID
	CreatedBy     string           `json:"created_by,omitempty"`
}

// TimeSeriesData represents revenue data for a time point
type TimeSeriesData struct {
	TimeLabel string  `json:"time_label"` // "00", "01", ... untuk hourly; "2026-01-27" untuk daily
	Revenue   float64 `json:"revenue"`
}

type AdditionalChargeBreakdown struct {
	Name        string  `json:"name"`
	ChargeType  string  `json:"charge_type"`
	Value       float64 `json:"value"`
	TotalAmount float64 `json:"total_amount"`
}

type VoidedOrderHistory struct {
	ID            string         `json:"id"`
	TableNumber   string         `json:"table_number"`
	TotalAmount   float64        `json:"total_amount"`
	PaymentStatus string         `json:"payment_status"`
	CreatedAt     time.Time      `json:"created_at"`
	VoidedAt      sql.NullTime   `json:"voided_at"`
	VoidedBy      sql.NullString `json:"voided_by"`
	VoidedByName  sql.NullString `json:"voided_by_name"`
	VoidReason    sql.NullString `json:"void_reason"`
}

var (
	ErrOrderAlreadyPaid   = errors.New("order sudah dibayar")
	ErrOrderItemNotFound  = errors.New("item tidak ditemukan")
	ErrOrderItemProcessed = errors.New("item sudah diproses kitchen")
	ErrInvalidItemQty     = errors.New("qty tidak valid")
	ErrOrderVoided        = errors.New("order sudah di-void")
)

// OrderRepository adalah interface untuk operasi database order
type OrderRepository interface {
	CreateOrderWithItems(ctx context.Context, input OrderInput) (string, error)
	GetPendingJobs(ctx context.Context) ([]db.PrintQueue, error)
	UpdatePrintJobStatus(ctx context.Context, arg db.UpdatePrintJobStatusParams) error
	UpdateOrderStatus(ctx context.Context, orderID string, status string) error
	UpdateOrderItemStatus(ctx context.Context, itemID string, status string) error
	UpdateOrderItemQty(ctx context.Context, itemID string, qty int64) error
	AddItemsToOrder(ctx context.Context, orderID string, items []OrderItemInput) error
	ProcessPayment(ctx context.Context, orderID string) error
	ApplyOrderDiscount(ctx context.Context, orderID string, chargeType string, value float64) error
	ApplyOrderCompliment(ctx context.Context, orderID string) error
	GetOrderWithItems(ctx context.Context, orderID string) (*db.Order, []db.OrderItem, error)
	GetOrderByTableID(ctx context.Context, tableID string) (*db.Order, []db.OrderItem, error)
	GetOrderAnalytics(ctx context.Context, startDate, endDate time.Time) (*db.GetOrderAnalyticsRow, error)
	GetRevenueByPaymentStatus(ctx context.Context, startDate, endDate time.Time) (paidRevenue, unpaidRevenue float64, err error)
	GetVoidedTotalByDateRange(ctx context.Context, startDate, endDate time.Time) (float64, error)
	GetCancelledTotalByDateRange(ctx context.Context, startDate, endDate time.Time) (float64, error)
	GetAdditionalChargesSummary(ctx context.Context, startDate, endDate time.Time) (total float64, breakdowns []AdditionalChargeBreakdown, err error)
	GetProductsSold(ctx context.Context, startDate, endDate time.Time) (int64, error)
	GetRevenueTimeSeries(ctx context.Context, startDate, endDate time.Time, period string) ([]TimeSeriesData, error)
	ListOrders(ctx context.Context, limit, offset int64) ([]db.Order, int64, error)
	ListOrdersByCustomer(ctx context.Context, customerID string, startDate, endDate time.Time) ([]db.Order, error)
	SplitBillPayment(ctx context.Context, orderID string, amount float64, paymentMethod string, note string, createdBy string, items []SplitBillItem) error
	MergeTables(ctx context.Context, sourceOrderIDs []string, targetTableNumber string) (string, error)
	GetOrderPayments(ctx context.Context, orderID string) ([]db.Payment, error)
	VoidOrder(ctx context.Context, orderID string, voidedBy string, voidReason string) error
	ListVoidedOrders(ctx context.Context, limit, offset int64) ([]VoidedOrderHistory, error)
	CountVoidedOrders(ctx context.Context) (int64, error)
	ListVoidedOrdersByDateRange(ctx context.Context, startDate, endDate time.Time, limit, offset int64) ([]VoidedOrderHistory, error)
	CountVoidedOrdersByDateRange(ctx context.Context, startDate, endDate time.Time) (int64, error)
}
