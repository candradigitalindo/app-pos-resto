package models

import "time"

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
	TaxAmount     float64           `json:"tax_amount"`
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
	TaxAmount     float64   `json:"tax_amount"`
	PaymentMethod string    `json:"payment_method"`
	CashAmount    float64   `json:"cash_amount"`
	ChangeAmount  float64   `json:"change_amount"`
	CashierName   string    `json:"cashier_name"`
	Items         string    `json:"items"`
	Version       int       `json:"version"`
	CreatedAt     time.Time `json:"created_at"`
	SyncedAt      time.Time `json:"synced_at"`
}
