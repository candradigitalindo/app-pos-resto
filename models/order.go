package models

import "time"

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
	VoidedAt      string  `json:"voided_at,omitempty"`
	VoidedBy      string  `json:"voided_by,omitempty"`
	VoidReason    string  `json:"void_reason,omitempty"`
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

type VoidOrderRow struct {
	ID           string  `json:"id"`
	OutletName   string  `json:"outlet_name"`
	TableNumber  string  `json:"table_number"`
	CustomerName string  `json:"customer_name"`
	TotalAmount  float64 `json:"total_amount"`
	Items        string  `json:"items"`
	VoidedAt     string  `json:"voided_at"`
	VoidedBy     string  `json:"voided_by"`
	VoidReason   string  `json:"void_reason"`
	CreatedAt    string  `json:"created_at"`
}

type VoidReportSummary struct {
	TotalVoided int     `json:"total_voided"`
	TotalAmount float64 `json:"total_amount"`
}

type VoidReport struct {
	Summary VoidReportSummary `json:"summary"`
	Data    []VoidOrderRow    `json:"data"`
	Total   int               `json:"total"`
	Page    int               `json:"page"`
	Limit   int               `json:"limit"`
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
