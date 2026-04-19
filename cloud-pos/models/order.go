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
