package models

// ProcurementWorkUnitStat holds procurement stats for a single work unit.
type ProcurementWorkUnitStat struct {
	WorkUnitID       string  `json:"work_unit_id"`
	WorkUnitName     string  `json:"work_unit_name"`
	Total            int     `json:"total"`
	TotalAmount      float64 `json:"total_amount"`
	Pending          int     `json:"pending"`
	Approved         int     `json:"approved"`
	PaymentRequested int     `json:"payment_requested"`
	Paid             int     `json:"paid"`
	Received         int     `json:"received"`
	Rejected         int     `json:"rejected"`
	Cancelled        int     `json:"cancelled"`
}

// ProcurementMonthlyTrend holds monthly procurement totals.
type ProcurementMonthlyTrend struct {
	Month       string  `json:"month"` // "2026-01"
	Count       int     `json:"count"`
	TotalAmount float64 `json:"total_amount"`
}

// ProcurementStatusBreakdown holds counts by status.
type ProcurementStatusBreakdown struct {
	Pending          int `json:"pending"`
	Approved         int `json:"approved"`
	PaymentRequested int `json:"payment_requested"`
	Paid             int `json:"paid"`
	Received         int `json:"received"`
	Rejected         int `json:"rejected"`
	Cancelled        int `json:"cancelled"`
}

// ProcurementTypeSplit holds counts by request type.
type ProcurementTypeSplit struct {
	Barang      int     `json:"barang"`
	BarangTotal float64 `json:"barang_total"`
	Jasa        int     `json:"jasa"`
	JasaTotal   float64 `json:"jasa_total"`
}

// ProcurementDashboardResponse is the response for the outlet procurement dashboard.
type ProcurementDashboardResponse struct {
	TotalRequests   int                        `json:"total_requests"`
	TotalAmount     float64                    `json:"total_amount"`
	StatusBreakdown ProcurementStatusBreakdown `json:"status_breakdown"`
	TypeSplit       ProcurementTypeSplit       `json:"type_split"`
	WorkUnits       []ProcurementWorkUnitStat  `json:"work_units"`
	MonthlyTrend    []ProcurementMonthlyTrend  `json:"monthly_trend"`
	AccountsPayable AccountsPayable            `json:"accounts_payable"`
}

// AccountsPayable holds hutang usaha summary.
type AccountsPayable struct {
	Count       int     `json:"count"`
	TotalAmount float64 `json:"total_amount"`
}

// PaymentStatsResponse holds stats for the payments page.
type PaymentStatsResponse struct {
	Waiting         int             `json:"waiting"`
	TotalWaiting    float64         `json:"total_waiting"`
	Paid            int             `json:"paid"`
	TotalPaid       float64         `json:"total_paid"`
	Received        int             `json:"received"`
	AccountsPayable AccountsPayable `json:"accounts_payable"`
}
