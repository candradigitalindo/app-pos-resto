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

type TransactionCharge struct {
	Name       string  `json:"name"`
	ChargeType string  `json:"charge_type"` // percentage | fixed
	Value      float64 `json:"value"`
	Amount     float64 `json:"amount"`
}

type PushTransactionRequest struct {
	LocalID           string              `json:"local_id"`
	OutletID          string              `json:"outlet_id"`
	OutletCode        string              `json:"outlet_code"`
	OrderID           string              `json:"order_id"`
	Subtotal          float64             `json:"subtotal"`            // penjualan bersih (DPP)
	TaxAmount         float64             `json:"tax_amount"`          // pajak (charge persentase)
	OtherChargesTotal float64             `json:"other_charges_total"` // tambahan fixed
	Charges           []TransactionCharge `json:"charges"`             // rincian tiap tambahan
	TotalAmount       float64             `json:"total_amount"`        // grand total
	PaymentMethod     string              `json:"payment_method"`
	CashAmount        float64             `json:"cash_amount"`
	ChangeAmount      float64             `json:"change_amount"`
	CashierName       string              `json:"cashier_name"`
	Items             []TransactionItem   `json:"items"`
	Version           int                 `json:"version"`
	CreatedAt         string              `json:"created_at"`
}

type CloudTransaction struct {
	ID            string    `json:"id"`
	LocalID       string    `json:"local_id"`
	OutletID      string    `json:"outlet_id"`
	OutletCode    string    `json:"outlet_code"`
	OrderID           string    `json:"order_id"`
	Subtotal          float64   `json:"subtotal"`
	TotalAmount       float64   `json:"total_amount"`
	TaxAmount         float64   `json:"tax_amount"`
	OtherChargesTotal float64   `json:"other_charges_total"`
	Charges           string    `json:"charges"`
	PaymentMethod     string    `json:"payment_method"`
	CashAmount        float64   `json:"cash_amount"`
	ChangeAmount      float64   `json:"change_amount"`
	CashierName       string    `json:"cashier_name"`
	Items             string    `json:"items"`
	Version           int       `json:"version"`
	CreatedAt         time.Time `json:"created_at"`
	SyncedAt          time.Time `json:"synced_at"`
}
