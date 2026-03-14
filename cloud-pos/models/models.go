package models

import "time"

// ── Outlet ──────────────────────────────────────────────────

type Outlet struct {
	ID         string    `json:"id"`
	Code       string    `json:"code"`
	Name       string    `json:"name"`
	Address    string    `json:"address"`
	Phone      string    `json:"phone"`
	APIKey     string    `json:"api_key,omitempty"`
	WebhookURL string    `json:"webhook_url"`
	IsActive   bool      `json:"is_active"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

type CreateOutletRequest struct {
	Code       string `json:"code"`
	Name       string `json:"name"`
	Address    string `json:"address"`
	Phone      string `json:"phone"`
	WebhookURL string `json:"webhook_url"`
}

type UpdateOutletRequest struct {
	Name       string `json:"name"`
	Address    string `json:"address"`
	Phone      string `json:"phone"`
	WebhookURL string `json:"webhook_url"`
}

// ── Order ───────────────────────────────────────────────────

type OrderItem struct {
	ProductName string  `json:"product_name"`
	Category    string  `json:"category"`
	Qty         int     `json:"qty"`
	Price       float64 `json:"price"`
	Subtotal    float64 `json:"subtotal"`
	Destination string  `json:"destination"`
	Status      string  `json:"status"`
}

type PaymentInfo struct {
	Method        string  `json:"method"`
	Amount        float64 `json:"amount"`
	PaidAmount    float64 `json:"paid_amount"`
	PaymentStatus string  `json:"payment_status"`
	PaidAt        string  `json:"paid_at"`
}

type PushOrderRequest struct {
	LocalID      string      `json:"local_id"`
	OutletID     string      `json:"outlet_id"`
	OutletCode   string      `json:"outlet_code"`
	TableNumber  string      `json:"table_number"`
	CustomerName string      `json:"customer_name"`
	Pax          int         `json:"pax"`
	TotalAmount  float64     `json:"total_amount"`
	Status       string      `json:"status"`
	Items        []OrderItem `json:"items"`
	PaymentInfo  PaymentInfo `json:"payment_info"`
	Version      int         `json:"version"`
	CreatedAt    string      `json:"created_at"`
	UpdatedAt    string      `json:"updated_at"`
}

type CloudOrder struct {
	ID           string    `json:"id"`
	LocalID      string    `json:"local_id"`
	OutletID     string    `json:"outlet_id"`
	OutletCode   string    `json:"outlet_code"`
	TableNumber  string    `json:"table_number"`
	CustomerName string    `json:"customer_name"`
	Pax          int       `json:"pax"`
	TotalAmount  float64   `json:"total_amount"`
	Status       string    `json:"status"`
	Items        string    `json:"items"`
	PaymentInfo  string    `json:"payment_info"`
	Version      int       `json:"version"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
	SyncedAt     time.Time `json:"synced_at"`
}

// ── Transaction ─────────────────────────────────────────────

type TransactionItem struct {
	ID          string  `json:"id"`
	ProductID   string  `json:"product_id"`
	ProductName string  `json:"product_name"`
	Quantity    int     `json:"quantity"`
	Price       float64 `json:"price"`
	Subtotal    float64 `json:"subtotal"`
}

type PushTransactionRequest struct {
	LocalID       string            `json:"local_id"`
	OutletID      string            `json:"outlet_id"`
	OutletCode    string            `json:"outlet_code"`
	OrderID       string            `json:"order_id"`
	TotalAmount   float64           `json:"total_amount"`
	PaymentMethod string            `json:"payment_method"`
	CashAmount    float64           `json:"cash_amount"`
	ChangeAmount  float64           `json:"change_amount"`
	CashierName   string            `json:"cashier_name"`
	Items         []TransactionItem `json:"items"`
	Version       int               `json:"version"`
	CreatedAt     string            `json:"created_at"`
}

type CloudTransaction struct {
	ID            string    `json:"id"`
	LocalID       string    `json:"local_id"`
	OutletID      string    `json:"outlet_id"`
	OutletCode    string    `json:"outlet_code"`
	OrderID       string    `json:"order_id"`
	TotalAmount   float64   `json:"total_amount"`
	PaymentMethod string    `json:"payment_method"`
	CashAmount    float64   `json:"cash_amount"`
	ChangeAmount  float64   `json:"change_amount"`
	CashierName   string    `json:"cashier_name"`
	Items         string    `json:"items"`
	Version       int       `json:"version"`
	CreatedAt     time.Time `json:"created_at"`
	SyncedAt      time.Time `json:"synced_at"`
}

// ── Product ─────────────────────────────────────────────────

type PushProductRequest struct {
	LocalID      string  `json:"local_id"`
	OutletID     string  `json:"outlet_id"`
	Name         string  `json:"name"`
	Code         string  `json:"code"`
	Description  string  `json:"description"`
	CategoryID   string  `json:"category_id"`
	CategoryName string  `json:"category_name"`
	Price        float64 `json:"price"`
	Stock        int     `json:"stock"`
	Destination  string  `json:"destination"`
	Version      int     `json:"version"`
	UpdatedAt    string  `json:"updated_at"`
}

type CloudProduct struct {
	ID           string    `json:"id"`
	LocalID      string    `json:"local_id"`
	OutletID     string    `json:"outlet_id"`
	OutletName   string    `json:"outlet_name,omitempty"`
	Name         string    `json:"name"`
	Code         string    `json:"code"`
	Description  string    `json:"description"`
	CategoryID   string    `json:"category_id"`
	CategoryName string    `json:"category_name"`
	Price        float64   `json:"price"`
	Stock        int       `json:"stock"`
	Destination  string    `json:"destination"`
	IsDeleted    bool      `json:"is_deleted"`
	Version      int       `json:"version"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
	SyncedAt     time.Time `json:"synced_at"`
}

// ── Category ────────────────────────────────────────────────

// PushCategoryRequest adalah payload dari local POS saat sync kategori
type PushCategoryRequest struct {
	LocalID     string `json:"local_id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	CodePrefix  string `json:"code_prefix"`
	Version     int    `json:"version"`
}

type CloudCategory struct {
	ID         string    `json:"id"`
	LocalID    string    `json:"local_id"`
	OutletID   string    `json:"outlet_id"`
	OutletName string    `json:"outlet_name,omitempty"`
	Name       string    `json:"name"`
	CodePrefix string    `json:"code_prefix"`
	PrinterID  string    `json:"printer_id"`
	IsDeleted  bool      `json:"is_deleted"`
	Version    int       `json:"version"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
	SyncedAt   time.Time `json:"synced_at"`
}

// ── Admin CRUD Requests ─────────────────────────────────────

type AdminCreateProductRequest struct {
	OutletID     string  `json:"outlet_id"`
	Name         string  `json:"name"`
	Code         string  `json:"code"`
	Description  string  `json:"description"`
	CategoryID   string  `json:"category_id"`
	CategoryName string  `json:"category_name"`
	Price        float64 `json:"price"`
	Stock        int     `json:"stock"`
	Destination  string  `json:"destination"`
}

type AdminUpdateProductRequest struct {
	Name         string  `json:"name"`
	Code         string  `json:"code"`
	Description  string  `json:"description"`
	CategoryID   string  `json:"category_id"`
	CategoryName string  `json:"category_name"`
	Price        float64 `json:"price"`
	Stock        int     `json:"stock"`
	Destination  string  `json:"destination"`
}

type AdminCreateCategoryRequest struct {
	OutletID   string `json:"outlet_id"`
	Name       string `json:"name"`
	CodePrefix string `json:"code_prefix"`
}

type AdminUpdateCategoryRequest struct {
	Name       string `json:"name"`
	CodePrefix string `json:"code_prefix"`
}

// ── Analytics ───────────────────────────────────────────────

type PushAnalyticsRequest struct {
	OutletID   string      `json:"outlet_id"`
	OutletCode string      `json:"outlet_code"`
	Date       string      `json:"date"`
	Summary    interface{} `json:"summary"`
}

type CloudAnalytics struct {
	ID         string    `json:"id"`
	OutletID   string    `json:"outlet_id"`
	OutletCode string    `json:"outlet_code"`
	Date       string    `json:"date"`
	Summary    string    `json:"summary"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

// ── Cashier Shift ───────────────────────────────────────────

type PushCashierShiftRequest struct {
	LocalID         string  `json:"local_id"`
	OpenedBy        string  `json:"opened_by"`
	OpenedAt        string  `json:"opened_at"`
	OpeningCash     float64 `json:"opening_cash"`
	ClosedAt        string  `json:"closed_at"`
	ClosedBy        string  `json:"closed_by"`
	ClosingCash     float64 `json:"closing_cash"`
	ClosingCard     float64 `json:"closing_card"`
	ClosingQris     float64 `json:"closing_qris"`
	ClosingTransfer float64 `json:"closing_transfer"`
	CarryOverCash   float64 `json:"carry_over_cash"`
	PreviousShiftID string  `json:"previous_shift_id"`
	HandoverTo      string  `json:"handover_to"`
	Status          string  `json:"status"`
	Notes           string  `json:"notes"`
}

type CloudCashierShift struct {
	ID              string     `json:"id"`
	LocalID         string     `json:"local_id"`
	OutletID        string     `json:"outlet_id"`
	OpenedBy        string     `json:"opened_by"`
	OpenedAt        time.Time  `json:"opened_at"`
	OpeningCash     float64    `json:"opening_cash"`
	ClosedAt        *time.Time `json:"closed_at"`
	ClosedBy        string     `json:"closed_by"`
	ClosingCash     float64    `json:"closing_cash"`
	ClosingCard     float64    `json:"closing_card"`
	ClosingQris     float64    `json:"closing_qris"`
	ClosingTransfer float64    `json:"closing_transfer"`
	CarryOverCash   float64    `json:"carry_over_cash"`
	PreviousShiftID string     `json:"previous_shift_id"`
	HandoverTo      string     `json:"handover_to"`
	Status          string     `json:"status"`
	Notes           string     `json:"notes"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
	SyncedAt        time.Time  `json:"synced_at"`
}

// ── Printer ─────────────────────────────────────────────────

type PushPrinterRequest struct {
	LocalID     string `json:"local_id"`
	Name        string `json:"name"`
	IPAddress   string `json:"ip_address"`
	Port        int    `json:"port"`
	PrinterType string `json:"printer_type"`
	PaperSize   string `json:"paper_size"`
	IsActive    bool   `json:"is_active"`
	IsDeleted   bool   `json:"is_deleted"`
}

type CloudPrinter struct {
	ID          string    `json:"id"`
	LocalID     string    `json:"local_id"`
	OutletID    string    `json:"outlet_id"`
	Name        string    `json:"name"`
	IPAddress   string    `json:"ip_address"`
	Port        int       `json:"port"`
	PrinterType string    `json:"printer_type"`
	PaperSize   string    `json:"paper_size"`
	IsActive    bool      `json:"is_active"`
	IsDeleted   bool      `json:"is_deleted"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
	SyncedAt    time.Time `json:"synced_at"`
}

// ── Cash Movement ───────────────────────────────────────────

type PushCashMovementRequest struct {
	LocalID         string  `json:"local_id"`
	ShiftID         string  `json:"shift_id"`
	MovementType    string  `json:"movement_type"`
	Amount          float64 `json:"amount"`
	CounterpartName string  `json:"counterpart_name"`
	Note            string  `json:"note"`
	CreatedAt       string  `json:"created_at"`
}

type CloudCashMovement struct {
	ID              string    `json:"id"`
	LocalID         string    `json:"local_id"`
	OutletID        string    `json:"outlet_id"`
	ShiftID         string    `json:"shift_id"`
	MovementType    string    `json:"movement_type"`
	Amount          float64   `json:"amount"`
	CounterpartName string    `json:"counterpart_name"`
	Note            string    `json:"note"`
	CreatedAt       time.Time `json:"created_at"`
	SyncedAt        time.Time `json:"synced_at"`
}

// ── Batch Sync ──────────────────────────────────────────────

type BatchSyncItem struct {
	EntityType string      `json:"entity_type"`
	Operation  string      `json:"operation"`
	Data       interface{} `json:"data"`
}

type BatchSyncRequest struct {
	OutletID      string          `json:"outlet_id"`
	OutletCode    string          `json:"outlet_code"`
	SyncTimestamp string          `json:"sync_timestamp"`
	Items         []BatchSyncItem `json:"items"`
}

type BatchSyncResult struct {
	EntityType string `json:"entity_type"`
	LocalID    string `json:"local_id"`
	CloudID    string `json:"cloud_id,omitempty"`
	Status     string `json:"status"`
	Error      string `json:"error,omitempty"`
}

type BatchSyncResponse struct {
	Processed int               `json:"processed"`
	Success   int               `json:"success"`
	Failed    int               `json:"failed"`
	Results   []BatchSyncResult `json:"results"`
	SyncedAt  string            `json:"synced_at"`
}

// ── Updates ─────────────────────────────────────────────────

type UpdateEntity struct {
	CloudID      string   `json:"cloud_id"`
	LocalID      string   `json:"local_id"`
	Name         string   `json:"name,omitempty"`
	Code         string   `json:"code,omitempty"`
	Description  string   `json:"description,omitempty"`
	CategoryID   string   `json:"category_id,omitempty"`
	CategoryName string   `json:"category_name,omitempty"`
	Price        *float64 `json:"price,omitempty"`
	Stock        *int     `json:"stock,omitempty"`
	Version      int      `json:"version"`
	UpdatedAt    string   `json:"updated_at"`
	Action       string   `json:"action"`
}

type DeletedEntity struct {
	EntityType string `json:"entity_type"`
	LocalID    string `json:"local_id"`
	CloudID    string `json:"cloud_id"`
	DeletedAt  string `json:"deleted_at"`
}

type UpdatesResponse struct {
	Products       []UpdateEntity  `json:"products"`
	Categories     []UpdateEntity  `json:"categories"`
	Deleted        []DeletedEntity `json:"deleted"`
	SyncCheckpoint string          `json:"sync_checkpoint"`
}

// ── Conflict ────────────────────────────────────────────────

type SyncConflict struct {
	ID            string  `json:"id"`
	OutletID      string  `json:"outlet_id"`
	EntityType    string  `json:"entity_type"`
	EntityLocalID string  `json:"entity_local_id"`
	EntityCloudID string  `json:"entity_cloud_id"`
	ConflictField string  `json:"conflict_field"`
	CloudValue    string  `json:"cloud_value"`
	LocalValue    string  `json:"local_value"`
	CloudVersion  int     `json:"cloud_version"`
	LocalVersion  int     `json:"local_version"`
	Resolution    string  `json:"resolution"`
	ResolvedBy    string  `json:"resolved_by"`
	ResolvedAt    *string `json:"resolved_at"`
	Notes         string  `json:"notes"`
	CreatedAt     string  `json:"created_at"`
}

type ResolveConflictRequest struct {
	Strategy   string `json:"strategy"`
	ResolvedBy string `json:"resolved_by"`
	Notes      string `json:"notes"`
}

// ── API Response ────────────────────────────────────────────

type APIResponse struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
	Message string      `json:"message,omitempty"`
}

type PaginatedResponse struct {
	Success    bool        `json:"success"`
	Data       interface{} `json:"data"`
	Page       int         `json:"page"`
	Limit      int         `json:"limit"`
	Total      int         `json:"total"`
	TotalPages int         `json:"total_pages"`
}

// ── Sync Log ────────────────────────────────────────────────

type SyncLog struct {
	ID           string `json:"id"`
	OutletID     string `json:"outlet_id"`
	Action       string `json:"action"`
	EntityType   string `json:"entity_type"`
	EntityCount  int    `json:"entity_count"`
	Status       string `json:"status"`
	ErrorMessage string `json:"error_message"`
	CreatedAt    string `json:"created_at"`
}

// ── Dashboard ───────────────────────────────────────────────

// OutletDashboardRow holds per-outlet sales figures shown in the dashboard table.
type OutletDashboardRow struct {
	ID              string  `json:"id"`
	Name            string  `json:"name"`
	SalesDay        float64 `json:"sales_day"`
	SalesDayPrev    float64 `json:"sales_day_prev"`
	SalesWeek       float64 `json:"sales_week"`
	SalesWeekPrev   float64 `json:"sales_week_prev"`
	SalesMonth      float64 `json:"sales_month"`
	SalesMonthPrev  float64 `json:"sales_month_prev"`
	SalesCustom     float64 `json:"sales_custom"`
	SalesCustomPrev float64 `json:"sales_custom_prev"`
	UnpaidOrders    int     `json:"unpaid_orders"`
	UnpaidAmount    float64 `json:"unpaid_amount"`
	LastSyncAt      *string `json:"last_sync_at"`
}

type DashboardStats struct {
	TotalOutlets          int                  `json:"total_outlets"`
	ActiveOutlets         int                  `json:"active_outlets"`
	TotalOrders           int                  `json:"total_orders"`
	TotalTransactions     int                  `json:"total_transactions"`
	TotalRevenue          float64              `json:"total_revenue"`
	MonthTransactions     int                  `json:"month_transactions"`
	MonthTransactionsPrev int                  `json:"month_transactions_prev"`
	MonthRevenue          float64              `json:"month_revenue"`
	MonthRevenuePrev      float64              `json:"month_revenue_prev"`
	TodayOrders           int                  `json:"today_orders"`
	TodayOrdersPrev       int                  `json:"today_orders_prev"`
	TodayRevenue          float64              `json:"today_revenue"`
	TotalProducts         int                  `json:"total_products"`
	TotalSyncLogs         int                  `json:"total_sync_logs"`
	PendingConflicts      int                  `json:"pending_conflicts"`
	TotalUnpaidOrders     int                  `json:"total_unpaid_orders"`
	TotalUnpaidAmount     float64              `json:"total_unpaid_amount"`
	Outlets               []OutletDashboardRow `json:"outlets"`
}

// ── Sales Report ────────────────────────────────────────────

type SalesReportRow struct {
	Date              string  `json:"date"`
	TotalTransactions int     `json:"total_transactions"`
	TotalRevenue      float64 `json:"total_revenue"`
	CashRevenue       float64 `json:"cash_revenue"`
	QrisRevenue       float64 `json:"qris_revenue"`
	CardRevenue       float64 `json:"card_revenue"`
	TransferRevenue   float64 `json:"transfer_revenue"`
}

type SalesReportOutlet struct {
	OutletID          string  `json:"outlet_id"`
	OutletName        string  `json:"outlet_name"`
	TotalTransactions int     `json:"total_transactions"`
	TotalRevenue      float64 `json:"total_revenue"`
	UnpaidOrders      int     `json:"unpaid_orders"`
	UnpaidAmount      float64 `json:"unpaid_amount"`
}

type SalesReportSummary struct {
	TotalTransactions int     `json:"total_transactions"`
	TotalRevenue      float64 `json:"total_revenue"`
	AvgPerTransaction float64 `json:"avg_per_transaction"`
	CashRevenue       float64 `json:"cash_revenue"`
	QrisRevenue       float64 `json:"qris_revenue"`
	CardRevenue       float64 `json:"card_revenue"`
	TransferRevenue   float64 `json:"transfer_revenue"`
	UnpaidOrders      int     `json:"unpaid_orders"`
	UnpaidAmount      float64 `json:"unpaid_amount"`
}

type SalesReportResponse struct {
	Summary      SalesReportSummary       `json:"summary"`
	Daily        []SalesReportRow         `json:"daily"`
	ByOutlet     []SalesReportOutlet      `json:"by_outlet"`
	Transactions []SalesReportTransaction `json:"transactions"`
	Page         int                      `json:"page"`
	Limit        int                      `json:"limit"`
	Total        int                      `json:"total"`
	TotalPages   int                      `json:"total_pages"`
}

type SalesReportTransaction struct {
	ID            string  `json:"id"`
	OutletName    string  `json:"outlet_name"`
	OutletCode    string  `json:"outlet_code"`
	TotalAmount   float64 `json:"total_amount"`
	PaymentMethod string  `json:"payment_method"`
	CashierName   string  `json:"cashier_name"`
	Items         string  `json:"items"`
	CreatedAt     string  `json:"created_at"`
}

// ── Unpaid Orders Report ────────────────────────────────────

type UnpaidOrderRow struct {
	ID           string  `json:"id"`
	OutletName   string  `json:"outlet_name"`
	OutletCode   string  `json:"outlet_code"`
	TableNumber  string  `json:"table_number"`
	CustomerName string  `json:"customer_name"`
	Pax          int     `json:"pax"`
	TotalAmount  float64 `json:"total_amount"`
	Status       string  `json:"status"`
	Items        string  `json:"items"`
	CreatedAt    string  `json:"created_at"`
	UpdatedAt    string  `json:"updated_at"`
}

type UnpaidOrdersResponse struct {
	TotalUnpaid int              `json:"total_unpaid"`
	TotalAmount float64          `json:"total_amount"`
	Orders      []UnpaidOrderRow `json:"orders"`
	Page        int              `json:"page"`
	Limit       int              `json:"limit"`
	Total       int              `json:"total"`
	TotalPages  int              `json:"total_pages"`
}

// ── Admin ───────────────────────────────────────────────────

type CloudAdmin struct {
	ID          string     `json:"id"`
	Username    string     `json:"username"`
	Password    string     `json:"-"`
	Name        string     `json:"name"`
	Role        string     `json:"role"`
	IsActive    bool       `json:"is_active"`
	LastLoginAt *time.Time `json:"last_login_at"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
}

type AdminLoginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type AdminLoginResponse struct {
	Token string     `json:"token"`
	Admin CloudAdmin `json:"admin"`
}

type CreateAdminRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
	Name     string `json:"name"`
	Role     string `json:"role"`
}
