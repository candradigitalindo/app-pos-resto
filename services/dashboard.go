package services

import (
	"cloud-pos/database"
	"cloud-pos/models"
	"database/sql"
	"fmt"

	"github.com/lib/pq"
)

func GetDashboardStats(dateFrom, dateTo string, scopeIDs []string) (*models.DashboardStats, error) {
	stats := &models.DashboardStats{}

	// Build scope filter: if scopeIDs is nil → no filter, otherwise filter by outlet IDs
	var scopeParam interface{}
	outletFilter := ""    // e.g. " AND outlet_id = ANY($1)" for tables with outlet_id
	outletsIDFilter := "" // e.g. " AND id = ANY($1)" for the outlets table itself
	if scopeIDs != nil {
		scopeParam = pq.Array(scopeIDs)
		outletFilter = " AND outlet_id = ANY($1)"
		outletsIDFilter = " AND id = ANY($1)"
	}

	var mainQuery string
	if scopeIDs != nil {
		mainQuery = fmt.Sprintf(`
		SELECT
			(SELECT COUNT(*) FROM outlets WHERE 1=1%s),
			(SELECT COUNT(*) FROM outlets WHERE is_active = true%s),
			(SELECT COUNT(*) FROM cloud_orders WHERE 1=1%s),
			(SELECT COUNT(*) FROM cloud_transactions WHERE 1=1%s),
			(SELECT COALESCE(SUM(total_amount),0) FROM cloud_transactions WHERE 1=1%s),
			(SELECT COUNT(*) FROM cloud_transactions WHERE created_at >= date_trunc('month', CURRENT_TIMESTAMP)%s),
			(SELECT COUNT(*) FROM cloud_transactions WHERE created_at >= date_trunc('month', CURRENT_TIMESTAMP) - INTERVAL '1 month' AND created_at < date_trunc('month', CURRENT_TIMESTAMP)%s),
			(SELECT COALESCE(SUM(total_amount),0) FROM cloud_transactions WHERE created_at >= date_trunc('month', CURRENT_TIMESTAMP)%s),
			(SELECT COALESCE(SUM(total_amount),0) FROM cloud_transactions WHERE created_at >= date_trunc('month', CURRENT_TIMESTAMP) - INTERVAL '1 month' AND created_at < date_trunc('month', CURRENT_TIMESTAMP)%s),
			(SELECT COUNT(*) FROM cloud_orders WHERE tz_date(created_at) = tz_today()%s),
			(SELECT COUNT(*) FROM cloud_orders WHERE tz_date(created_at) = tz_today() - 1%s),
			(SELECT COALESCE(SUM(total_amount),0) FROM cloud_transactions WHERE tz_date(created_at) = tz_today()%s),
			(SELECT COUNT(*) FROM cloud_products WHERE is_deleted = false%s),
			(SELECT COUNT(*) FROM sync_logs WHERE 1=1%s),
			(SELECT COUNT(*) FROM sync_conflicts WHERE (resolution IS NULL OR resolution = 'pending')%s),
			(SELECT COUNT(*) FROM cloud_orders WHERE COALESCE(payment_info->>'payment_status','unpaid') NOT IN ('paid') AND NULLIF(payment_info->>'voided_at','') IS NULL%s),
			(SELECT COALESCE(SUM(total_amount),0) FROM cloud_orders WHERE COALESCE(payment_info->>'payment_status','unpaid') NOT IN ('paid') AND NULLIF(payment_info->>'voided_at','') IS NULL%s)
		`,
			outletsIDFilter, outletsIDFilter,
			outletFilter, outletFilter, outletFilter,
			outletFilter, outletFilter,
			outletFilter, outletFilter,
			outletFilter, outletFilter,
			outletFilter,
			outletFilter,
			outletFilter,
			outletFilter,
			outletFilter, outletFilter,
		)
	} else {
		mainQuery = `
		SELECT
			(SELECT COUNT(*) FROM outlets),
			(SELECT COUNT(*) FROM outlets WHERE is_active = true),
			(SELECT COUNT(*) FROM cloud_orders),
			(SELECT COUNT(*) FROM cloud_transactions),
			(SELECT COALESCE(SUM(total_amount),0) FROM cloud_transactions),
			(SELECT COUNT(*) FROM cloud_transactions WHERE created_at >= date_trunc('month', CURRENT_TIMESTAMP)),
			(SELECT COUNT(*) FROM cloud_transactions WHERE created_at >= date_trunc('month', CURRENT_TIMESTAMP) - INTERVAL '1 month' AND created_at < date_trunc('month', CURRENT_TIMESTAMP)),
			(SELECT COALESCE(SUM(total_amount),0) FROM cloud_transactions WHERE created_at >= date_trunc('month', CURRENT_TIMESTAMP)),
			(SELECT COALESCE(SUM(total_amount),0) FROM cloud_transactions WHERE created_at >= date_trunc('month', CURRENT_TIMESTAMP) - INTERVAL '1 month' AND created_at < date_trunc('month', CURRENT_TIMESTAMP)),
			(SELECT COUNT(*) FROM cloud_orders WHERE tz_date(created_at) = tz_today()),
			(SELECT COUNT(*) FROM cloud_orders WHERE tz_date(created_at) = tz_today() - 1),
			(SELECT COALESCE(SUM(total_amount),0) FROM cloud_transactions WHERE tz_date(created_at) = tz_today()),
			(SELECT COUNT(*) FROM cloud_products WHERE is_deleted = false),
			(SELECT COUNT(*) FROM sync_logs),
			(SELECT COUNT(*) FROM sync_conflicts WHERE resolution IS NULL OR resolution = 'pending'),
			(SELECT COUNT(*) FROM cloud_orders WHERE COALESCE(payment_info->>'payment_status','unpaid') NOT IN ('paid') AND NULLIF(payment_info->>'voided_at','') IS NULL),
			(SELECT COALESCE(SUM(total_amount),0) FROM cloud_orders WHERE COALESCE(payment_info->>'payment_status','unpaid') NOT IN ('paid') AND NULLIF(payment_info->>'voided_at','') IS NULL)
		`
	}

	var err error
	if scopeParam != nil {
		err = database.DB.QueryRow(mainQuery, scopeParam).Scan(
			&stats.TotalOutlets, &stats.ActiveOutlets,
			&stats.TotalOrders, &stats.TotalTransactions, &stats.TotalRevenue,
			&stats.MonthTransactions, &stats.MonthTransactionsPrev,
			&stats.MonthRevenue, &stats.MonthRevenuePrev,
			&stats.TodayOrders, &stats.TodayOrdersPrev, &stats.TodayRevenue,
			&stats.TotalProducts, &stats.TotalSyncLogs, &stats.PendingConflicts,
			&stats.TotalUnpaidOrders, &stats.TotalUnpaidAmount,
		)
	} else {
		err = database.DB.QueryRow(mainQuery).Scan(
			&stats.TotalOutlets, &stats.ActiveOutlets,
			&stats.TotalOrders, &stats.TotalTransactions, &stats.TotalRevenue,
			&stats.MonthTransactions, &stats.MonthTransactionsPrev,
			&stats.MonthRevenue, &stats.MonthRevenuePrev,
			&stats.TodayOrders, &stats.TodayOrdersPrev, &stats.TodayRevenue,
			&stats.TotalProducts, &stats.TotalSyncLogs, &stats.PendingConflicts,
			&stats.TotalUnpaidOrders, &stats.TotalUnpaidAmount,
		)
	}
	if err != nil {
		return nil, fmt.Errorf("dashboard stats query failed: %w", err)
	}

	const outletBase = `
		SELECT
			o.id,
			o.name,
			COALESCE(SUM(CASE WHEN tz_date(t.created_at) = tz_today()
				THEN t.total_amount ELSE 0 END), 0)                                       AS sales_day,
			COALESCE(SUM(CASE WHEN tz_date(t.created_at) = tz_today() - INTERVAL '1 day'
				THEN t.total_amount ELSE 0 END), 0)                                       AS sales_day_prev,
			COALESCE(SUM(CASE WHEN t.created_at >= date_trunc('week', CURRENT_TIMESTAMP)
				THEN t.total_amount ELSE 0 END), 0)                                       AS sales_week,
			COALESCE(SUM(CASE WHEN t.created_at >= date_trunc('week', CURRENT_TIMESTAMP) - INTERVAL '7 days'
				AND t.created_at < date_trunc('week', CURRENT_TIMESTAMP)
				THEN t.total_amount ELSE 0 END), 0)                                       AS sales_week_prev,
			COALESCE(SUM(CASE WHEN t.created_at >= date_trunc('month', CURRENT_TIMESTAMP)
				THEN t.total_amount ELSE 0 END), 0)                                       AS sales_month,
			COALESCE(SUM(CASE WHEN t.created_at >= date_trunc('month', CURRENT_TIMESTAMP) - INTERVAL '1 month'
				AND t.created_at < date_trunc('month', CURRENT_TIMESTAMP)
				THEN t.total_amount ELSE 0 END), 0)                                       AS sales_month_prev`

	const outletStdTail = `,
			0::float8                                                                     AS sales_custom,
			0::float8                                                                     AS sales_custom_prev,
			COALESCE(u.cnt, 0)::int                                                       AS unpaid_orders,
			COALESCE(u.amt, 0)                                                            AS unpaid_amount,
			(SELECT TO_CHAR(MAX(sl.created_at), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
				FROM sync_logs sl WHERE sl.outlet_id = o.id AND sl.action != 'restore') AS last_sync_at
		FROM outlets o
		LEFT JOIN cloud_transactions t ON t.outlet_id = o.id
		LEFT JOIN (
			SELECT outlet_id, COUNT(*) AS cnt, SUM(total_amount) AS amt
			FROM cloud_orders WHERE COALESCE(payment_info->>'payment_status','unpaid') NOT IN ('paid') AND NULLIF(payment_info->>'voided_at','') IS NULL
			GROUP BY outlet_id
		) u ON u.outlet_id = o.id
		WHERE o.is_active = true
		GROUP BY o.id, o.name, u.cnt, u.amt
		ORDER BY sales_month DESC`

	const outletStdTailScoped = `,
			0::float8                                                                     AS sales_custom,
			0::float8                                                                     AS sales_custom_prev,
			COALESCE(u.cnt, 0)::int                                                       AS unpaid_orders,
			COALESCE(u.amt, 0)                                                            AS unpaid_amount,
			(SELECT TO_CHAR(MAX(sl.created_at), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
				FROM sync_logs sl WHERE sl.outlet_id = o.id AND sl.action != 'restore') AS last_sync_at
		FROM outlets o
		LEFT JOIN cloud_transactions t ON t.outlet_id = o.id
		LEFT JOIN (
			SELECT outlet_id, COUNT(*) AS cnt, SUM(total_amount) AS amt
			FROM cloud_orders WHERE COALESCE(payment_info->>'payment_status','unpaid') NOT IN ('paid') AND NULLIF(payment_info->>'voided_at','') IS NULL
			GROUP BY outlet_id
		) u ON u.outlet_id = o.id
		WHERE o.is_active = true AND o.id = ANY($1)
		GROUP BY o.id, o.name, u.cnt, u.amt
		ORDER BY sales_month DESC`

	const outletRangeTail = `,
			COALESCE(SUM(CASE WHEN tz_date(t.created_at) >= $1::date AND tz_date(t.created_at) <= $2::date
				THEN t.total_amount ELSE 0 END), 0)                                       AS sales_custom,
			COALESCE(SUM(CASE WHEN tz_date(t.created_at) >= $1::date - ($2::date - $1::date + 1)
				AND tz_date(t.created_at) < $1::date
				THEN t.total_amount ELSE 0 END), 0)                                       AS sales_custom_prev,
			COALESCE(u.cnt, 0)::int                                                       AS unpaid_orders,
			COALESCE(u.amt, 0)                                                            AS unpaid_amount,
			(SELECT TO_CHAR(MAX(sl.created_at), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
				FROM sync_logs sl WHERE sl.outlet_id = o.id AND sl.action != 'restore') AS last_sync_at
		FROM outlets o
		LEFT JOIN cloud_transactions t ON t.outlet_id = o.id
		LEFT JOIN (
			SELECT outlet_id, COUNT(*) AS cnt, SUM(total_amount) AS amt
			FROM cloud_orders WHERE COALESCE(payment_info->>'payment_status','unpaid') NOT IN ('paid') AND NULLIF(payment_info->>'voided_at','') IS NULL
			GROUP BY outlet_id
		) u ON u.outlet_id = o.id
		WHERE o.is_active = true
		GROUP BY o.id, o.name, u.cnt, u.amt
		ORDER BY sales_month DESC`

	const outletRangeTailScoped = `,
			COALESCE(SUM(CASE WHEN tz_date(t.created_at) >= $1::date AND tz_date(t.created_at) <= $2::date
				THEN t.total_amount ELSE 0 END), 0)                                       AS sales_custom,
			COALESCE(SUM(CASE WHEN tz_date(t.created_at) >= $1::date - ($2::date - $1::date + 1)
				AND tz_date(t.created_at) < $1::date
				THEN t.total_amount ELSE 0 END), 0)                                       AS sales_custom_prev,
			COALESCE(u.cnt, 0)::int                                                       AS unpaid_orders,
			COALESCE(u.amt, 0)                                                            AS unpaid_amount,
			(SELECT TO_CHAR(MAX(sl.created_at), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
				FROM sync_logs sl WHERE sl.outlet_id = o.id AND sl.action != 'restore') AS last_sync_at
		FROM outlets o
		LEFT JOIN cloud_transactions t ON t.outlet_id = o.id
		LEFT JOIN (
			SELECT outlet_id, COUNT(*) AS cnt, SUM(total_amount) AS amt
			FROM cloud_orders WHERE COALESCE(payment_info->>'payment_status','unpaid') NOT IN ('paid') AND NULLIF(payment_info->>'voided_at','') IS NULL
			GROUP BY outlet_id
		) u ON u.outlet_id = o.id
		WHERE o.is_active = true AND o.id = ANY($3)
		GROUP BY o.id, o.name, u.cnt, u.amt
		ORDER BY sales_month DESC`

	var (
		rows    *sql.Rows
		rowsErr error
	)
	if dateFrom != "" && dateTo != "" {
		if scopeIDs != nil {
			rows, rowsErr = database.DB.Query(outletBase+outletRangeTailScoped, dateFrom, dateTo, pq.Array(scopeIDs))
		} else {
			rows, rowsErr = database.DB.Query(outletBase+outletRangeTail, dateFrom, dateTo)
		}
	} else {
		if scopeIDs != nil {
			rows, rowsErr = database.DB.Query(outletBase+outletStdTailScoped, pq.Array(scopeIDs))
		} else {
			rows, rowsErr = database.DB.Query(outletBase + outletStdTail)
		}
	}
	if rowsErr != nil {
		return nil, fmt.Errorf("dashboard outlet query failed: %w", rowsErr)
	}
	defer rows.Close()

	stats.Outlets = []models.OutletDashboardRow{}
	for rows.Next() {
		var row models.OutletDashboardRow
		if err := rows.Scan(
			&row.ID, &row.Name,
			&row.SalesDay, &row.SalesDayPrev,
			&row.SalesWeek, &row.SalesWeekPrev,
			&row.SalesMonth, &row.SalesMonthPrev,
			&row.SalesCustom, &row.SalesCustomPrev,
			&row.UnpaidOrders, &row.UnpaidAmount,
			&row.LastSyncAt,
		); err != nil {
			return nil, fmt.Errorf("dashboard outlet scan failed: %w", err)
		}
		stats.Outlets = append(stats.Outlets, row)
	}

	return stats, nil
}

// GetManagerDashboard returns a rich data set for the manager dashboard.
func GetManagerDashboard(scopeIDs []string) (*models.ManagerDashboardStats, error) {
	stats := &models.ManagerDashboardStats{}

	// Build scope filter helpers
	var scopeParam interface{}
	outletFilter := ""
	outletsIDFilter := ""
	if scopeIDs != nil {
		scopeParam = pq.Array(scopeIDs)
		outletFilter = " AND outlet_id = ANY($1)"
		outletsIDFilter = " AND id = ANY($1)"
	}

	// ── 1. KPI aggregates ──────────────────────────────────
	kpiQuery := fmt.Sprintf(`
		SELECT
			COALESCE(SUM(CASE WHEN tz_date(t.created_at) = tz_today() THEN t.total_amount ELSE 0 END), 0),
			COALESCE(COUNT(CASE WHEN tz_date(t.created_at) = tz_today() THEN 1 END), 0),
			COALESCE(SUM(CASE WHEN tz_date(t.created_at) = tz_today() - 1 THEN t.total_amount ELSE 0 END), 0),
			COALESCE(COUNT(CASE WHEN tz_date(t.created_at) = tz_today() - 1 THEN 1 END), 0),
			COALESCE(SUM(CASE WHEN t.created_at >= date_trunc('month', CURRENT_TIMESTAMP) THEN t.total_amount ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN t.created_at >= date_trunc('month', CURRENT_TIMESTAMP) - INTERVAL '1 month' AND t.created_at < date_trunc('month', CURRENT_TIMESTAMP) THEN t.total_amount ELSE 0 END), 0),
			COALESCE(COUNT(CASE WHEN t.created_at >= date_trunc('month', CURRENT_TIMESTAMP) THEN 1 END), 0),
			COALESCE(COUNT(CASE WHEN t.created_at >= date_trunc('month', CURRENT_TIMESTAMP) - INTERVAL '1 month' AND t.created_at < date_trunc('month', CURRENT_TIMESTAMP) THEN 1 END), 0),
			COALESCE(SUM(CASE WHEN t.created_at >= date_trunc('week', CURRENT_TIMESTAMP) THEN t.total_amount ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN t.created_at >= date_trunc('week', CURRENT_TIMESTAMP) - INTERVAL '7 days' AND t.created_at < date_trunc('week', CURRENT_TIMESTAMP) THEN t.total_amount ELSE 0 END), 0)
		FROM cloud_transactions t
		WHERE 1=1%s
	`, outletFilter)

	if scopeParam != nil {
		err := database.DB.QueryRow(kpiQuery, scopeParam).Scan(
			&stats.TodayRevenue, &stats.TodayOrders,
			&stats.YesterdayRevenue, &stats.YesterdayOrders,
			&stats.MonthRevenue, &stats.MonthRevenuePrev,
			&stats.MonthOrders, &stats.MonthOrdersPrev,
			&stats.WeekRevenue, &stats.WeekRevenuePrev,
		)
		if err != nil {
			return nil, fmt.Errorf("manager dashboard KPI query failed: %w", err)
		}
	} else {
		err := database.DB.QueryRow(kpiQuery).Scan(
			&stats.TodayRevenue, &stats.TodayOrders,
			&stats.YesterdayRevenue, &stats.YesterdayOrders,
			&stats.MonthRevenue, &stats.MonthRevenuePrev,
			&stats.MonthOrders, &stats.MonthOrdersPrev,
			&stats.WeekRevenue, &stats.WeekRevenuePrev,
		)
		if err != nil {
			return nil, fmt.Errorf("manager dashboard KPI query failed: %w", err)
		}
	}

	if stats.TodayOrders > 0 {
		stats.TodayAvgOrder = stats.TodayRevenue / float64(stats.TodayOrders)
	}

	// Active outlets, products, unpaid
	countQuery := fmt.Sprintf(`
		SELECT
			(SELECT COUNT(*) FROM outlets WHERE is_active = true%s),
			(SELECT COUNT(*) FROM cloud_products WHERE is_deleted = false%s),
			(SELECT COUNT(*) FROM cloud_orders WHERE COALESCE(payment_info->>'payment_status','unpaid') NOT IN ('paid') AND NULLIF(payment_info->>'voided_at','') IS NULL%s),
			(SELECT COALESCE(SUM(total_amount),0) FROM cloud_orders WHERE COALESCE(payment_info->>'payment_status','unpaid') NOT IN ('paid') AND NULLIF(payment_info->>'voided_at','') IS NULL%s)
	`, outletsIDFilter, outletFilter, outletFilter, outletFilter)

	if scopeParam != nil {
		_ = database.DB.QueryRow(countQuery, scopeParam).Scan(&stats.ActiveOutlets, &stats.TotalProducts, &stats.UnpaidOrders, &stats.UnpaidAmount)
	} else {
		_ = database.DB.QueryRow(countQuery).Scan(&stats.ActiveOutlets, &stats.TotalProducts, &stats.UnpaidOrders, &stats.UnpaidAmount)
	}

	// ── 2. Revenue trend (last 30 days) ────────────────────
	trendQuery := fmt.Sprintf(`
		SELECT TO_CHAR(d.dt, 'YYYY-MM-DD'), COALESCE(SUM(t.total_amount), 0)
		FROM generate_series(tz_today() - 29, tz_today(), '1 day'::interval) d(dt)
		LEFT JOIN cloud_transactions t ON tz_date(t.created_at) = d.dt%s
		GROUP BY d.dt ORDER BY d.dt
	`, outletFilter)

	stats.RevenueTrend = []models.DailyPoint{}
	var trendRows *sql.Rows
	var trendErr error
	if scopeParam != nil {
		trendRows, trendErr = database.DB.Query(trendQuery, scopeParam)
	} else {
		trendRows, trendErr = database.DB.Query(trendQuery)
	}
	if trendErr == nil {
		defer trendRows.Close()
		for trendRows.Next() {
			var p models.DailyPoint
			if err := trendRows.Scan(&p.Date, &p.Value); err == nil {
				stats.RevenueTrend = append(stats.RevenueTrend, p)
			}
		}
	}

	// ── 3. Order trend (last 30 days) ──────────────────────
	orderTrendQuery := fmt.Sprintf(`
		SELECT TO_CHAR(d.dt, 'YYYY-MM-DD'), COALESCE(COUNT(t.id), 0)
		FROM generate_series(tz_today() - 29, tz_today(), '1 day'::interval) d(dt)
		LEFT JOIN cloud_transactions t ON tz_date(t.created_at) = d.dt%s
		GROUP BY d.dt ORDER BY d.dt
	`, outletFilter)

	stats.OrderTrend = []models.DailyPoint{}
	var otRows *sql.Rows
	var otErr error
	if scopeParam != nil {
		otRows, otErr = database.DB.Query(orderTrendQuery, scopeParam)
	} else {
		otRows, otErr = database.DB.Query(orderTrendQuery)
	}
	if otErr == nil {
		defer otRows.Close()
		for otRows.Next() {
			var p models.DailyPoint
			if err := otRows.Scan(&p.Date, &p.Value); err == nil {
				stats.OrderTrend = append(stats.OrderTrend, p)
			}
		}
	}

	// ── 4. Hourly sales pattern (today) ────────────────────
	hourlyQuery := fmt.Sprintf(`
		SELECT h.hour, COALESCE(SUM(t.total_amount), 0), COALESCE(COUNT(t.id), 0)
		FROM generate_series(0, 23) h(hour)
		LEFT JOIN cloud_transactions t ON EXTRACT(HOUR FROM t.created_at AT TIME ZONE COALESCE(current_setting('timezone', true), 'Asia/Jakarta')) = h.hour
		  AND tz_date(t.created_at) = tz_today()%s
		GROUP BY h.hour ORDER BY h.hour
	`, outletFilter)

	stats.HourlySales = []models.HourlyPoint{}
	var hRows *sql.Rows
	var hErr error
	if scopeParam != nil {
		hRows, hErr = database.DB.Query(hourlyQuery, scopeParam)
	} else {
		hRows, hErr = database.DB.Query(hourlyQuery)
	}
	if hErr == nil {
		defer hRows.Close()
		for hRows.Next() {
			var p models.HourlyPoint
			if err := hRows.Scan(&p.Hour, &p.Value, &p.Count); err == nil {
				stats.HourlySales = append(stats.HourlySales, p)
			}
		}
	}

	// ── 5. Payment methods (this month) ────────────────────
	pmQuery := fmt.Sprintf(`
		SELECT COALESCE(payment_method, 'other'), COALESCE(SUM(total_amount), 0), COUNT(*)
		FROM cloud_transactions
		WHERE created_at >= date_trunc('month', CURRENT_TIMESTAMP)%s
		GROUP BY payment_method ORDER BY SUM(total_amount) DESC
	`, outletFilter)

	stats.PaymentMethods = []models.PaymentMethodShare{}
	var pmRows *sql.Rows
	var pmErr error
	if scopeParam != nil {
		pmRows, pmErr = database.DB.Query(pmQuery, scopeParam)
	} else {
		pmRows, pmErr = database.DB.Query(pmQuery)
	}
	if pmErr == nil {
		defer pmRows.Close()
		for pmRows.Next() {
			var p models.PaymentMethodShare
			if err := pmRows.Scan(&p.Method, &p.Amount, &p.Count); err == nil {
				stats.PaymentMethods = append(stats.PaymentMethods, p)
			}
		}
	}

	// ── 6. Top 10 products (this month by qty) ─────────────
	// Item penjualan disimpan sebagai JSONB di kolom cloud_transactions.items
	// (bukan tabel terpisah). Setiap elemen: { product_name, quantity, subtotal }.
	topQuery := fmt.Sprintf(`
		SELECT item->>'product_name' AS name,
			COALESCE(SUM((item->>'quantity')::numeric), 0)::int AS qty,
			COALESCE(SUM((item->>'subtotal')::numeric), 0) AS revenue
		FROM cloud_transactions t,
			jsonb_array_elements(t.items) AS item
		WHERE t.created_at >= date_trunc('month', CURRENT_TIMESTAMP)
		  AND COALESCE(item->>'product_name','') <> ''%s
		GROUP BY item->>'product_name'
		ORDER BY qty DESC LIMIT 10
	`, func() string {
		if scopeIDs != nil {
			return " AND t.outlet_id = ANY($1)"
		}
		return ""
	}())

	stats.TopProducts = []models.TopProductRow{}
	var tpRows *sql.Rows
	var tpErr error
	if scopeParam != nil {
		tpRows, tpErr = database.DB.Query(topQuery, scopeParam)
	} else {
		tpRows, tpErr = database.DB.Query(topQuery)
	}
	if tpErr == nil {
		defer tpRows.Close()
		for tpRows.Next() {
			var p models.TopProductRow
			if err := tpRows.Scan(&p.Name, &p.Quantity, &p.Revenue); err == nil {
				stats.TopProducts = append(stats.TopProducts, p)
			}
		}
	}

	// ── 7. Outlet ranking ──────────────────────────────────
	outletQuery := fmt.Sprintf(`
		SELECT o.id, o.name,
			COALESCE(SUM(CASE WHEN tz_date(t.created_at) = tz_today() THEN t.total_amount ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN t.created_at >= date_trunc('month', CURRENT_TIMESTAMP) THEN t.total_amount ELSE 0 END), 0),
			COALESCE(COUNT(CASE WHEN tz_date(t.created_at) = tz_today() THEN 1 END), 0)::int,
			COALESCE(COUNT(CASE WHEN t.created_at >= date_trunc('month', CURRENT_TIMESTAMP) THEN 1 END), 0)::int,
			(SELECT COALESCE(SUM(total_amount),0) FROM cloud_orders co
				WHERE co.outlet_id = o.id
				AND COALESCE(co.payment_info->>'payment_status','unpaid') NOT IN ('paid')
				AND NULLIF(co.payment_info->>'voided_at','') IS NULL),
			(SELECT TO_CHAR(MAX(sl.created_at), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
				FROM sync_logs sl WHERE sl.outlet_id = o.id AND sl.action != 'restore')
		FROM outlets o
		LEFT JOIN cloud_transactions t ON t.outlet_id = o.id
		WHERE o.is_active = true%s
		GROUP BY o.id, o.name
		ORDER BY SUM(CASE WHEN t.created_at >= date_trunc('month', CURRENT_TIMESTAMP) THEN t.total_amount ELSE 0 END) DESC
	`, func() string {
		// Query ini JOIN outlets + cloud_transactions yang dua-duanya punya
		// kolom `id`, jadi filter scope harus pakai `o.id` (bukan `id` polos)
		// agar tidak error "ambiguous column" yang membuat Performa Outlet kosong.
		if scopeIDs != nil {
			return " AND o.id = ANY($1)"
		}
		return ""
	}())

	stats.OutletRanking = []models.OutletRankRow{}
	var orRows *sql.Rows
	var orErr error
	if scopeParam != nil {
		orRows, orErr = database.DB.Query(outletQuery, scopeParam)
	} else {
		orRows, orErr = database.DB.Query(outletQuery)
	}
	if orErr == nil {
		defer orRows.Close()
		for orRows.Next() {
			var r models.OutletRankRow
			if err := orRows.Scan(&r.ID, &r.Name, &r.TodayRevenue, &r.MonthRevenue, &r.TodayOrders, &r.MonthOrders, &r.UnpaidAmount, &r.LastSyncAt); err == nil {
				stats.OutletRanking = append(stats.OutletRanking, r)
			}
		}
	}

	return stats, nil
}
