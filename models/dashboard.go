package models

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

// ── Manager Dashboard ──────────────────────────────────────

type ManagerDashboardStats struct {
	// KPI cards
	TodayRevenue     float64 `json:"today_revenue"`
	TodayOrders      int     `json:"today_orders"`
	TodayAvgOrder    float64 `json:"today_avg_order"`
	YesterdayRevenue float64 `json:"yesterday_revenue"`
	YesterdayOrders  int     `json:"yesterday_orders"`
	MonthRevenue     float64 `json:"month_revenue"`
	MonthRevenuePrev float64 `json:"month_revenue_prev"`
	MonthOrders      int     `json:"month_orders"`
	MonthOrdersPrev  int     `json:"month_orders_prev"`
	WeekRevenue      float64 `json:"week_revenue"`
	WeekRevenuePrev  float64 `json:"week_revenue_prev"`
	ActiveOutlets    int     `json:"active_outlets"`
	TotalProducts    int     `json:"total_products"`
	UnpaidOrders     int     `json:"unpaid_orders"`
	UnpaidAmount     float64 `json:"unpaid_amount"`

	// Chart data
	RevenueTrend   []DailyPoint         `json:"revenue_trend"`
	OrderTrend     []DailyPoint         `json:"order_trend"`
	HourlySales    []HourlyPoint        `json:"hourly_sales"`
	PaymentMethods []PaymentMethodShare `json:"payment_methods"`
	TopProducts    []TopProductRow      `json:"top_products"`
	OutletRanking  []OutletRankRow      `json:"outlet_ranking"`
}

type DailyPoint struct {
	Date  string  `json:"date"`
	Value float64 `json:"value"`
}

type HourlyPoint struct {
	Hour  int     `json:"hour"`
	Value float64 `json:"value"`
	Count int     `json:"count"`
}

type PaymentMethodShare struct {
	Method string  `json:"method"`
	Amount float64 `json:"amount"`
	Count  int     `json:"count"`
}

type TopProductRow struct {
	Name     string  `json:"name"`
	Quantity int     `json:"quantity"`
	Revenue  float64 `json:"revenue"`
}

type OutletRankRow struct {
	ID           string  `json:"id"`
	Name         string  `json:"name"`
	TodayRevenue float64 `json:"today_revenue"`
	MonthRevenue float64 `json:"month_revenue"`
	TodayOrders  int     `json:"today_orders"`
	MonthOrders  int     `json:"month_orders"`
	UnpaidAmount float64 `json:"unpaid_amount"`
	LastSyncAt   *string `json:"last_sync_at"`
}
