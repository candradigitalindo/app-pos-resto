package services

import (
	"cloud-pos/database"
	"cloud-pos/models"
	"fmt"
	"log"
	"math"
	"sort"
	"strings"

	"github.com/lib/pq"
)

func GetSalesReport(dateFrom, dateTo, outletID string, scopeIDs []string, page, limit int) (*models.SalesReportResponse, error) {
	report := &models.SalesReportResponse{
		Page:  page,
		Limit: limit,
	}

	// Normalize outlet filter
	var filterIDs []string
	if outletID != "" {
		filterIDs = []string{outletID}
	} else if scopeIDs != nil {
		filterIDs = scopeIDs
	}

	summaryQuery := `
		SELECT
			COUNT(*)::int,
			COALESCE(SUM(total_amount), 0),
			COALESCE(AVG(total_amount), 0),
			COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN total_amount ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN payment_method = 'qris' THEN total_amount ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN payment_method = 'card' THEN total_amount ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN payment_method = 'transfer' THEN total_amount ELSE 0 END), 0)
		FROM cloud_transactions
		WHERE tz_date(created_at) >= $1::date AND tz_date(created_at) <= $2::date`

	args := []interface{}{dateFrom, dateTo}
	if filterIDs != nil {
		summaryQuery += ` AND outlet_id = ANY($3::text[])`
		args = append(args, pq.Array(filterIDs))
	}

	err := database.DB.QueryRow(summaryQuery, args...).Scan(
		&report.Summary.TotalTransactions,
		&report.Summary.TotalRevenue,
		&report.Summary.AvgPerTransaction,
		&report.Summary.CashRevenue,
		&report.Summary.QrisRevenue,
		&report.Summary.CardRevenue,
		&report.Summary.TransferRevenue,
	)
	if err != nil {
		return nil, fmt.Errorf("sales report summary query failed: %w", err)
	}

	unpaidQuery := `
		SELECT COUNT(*)::int, COALESCE(SUM(total_amount), 0)
		FROM cloud_orders
		WHERE COALESCE(payment_info->>'payment_status','unpaid') NOT IN ('paid')
		  AND NULLIF(payment_info->>'voided_at','') IS NULL
		  AND tz_date(created_at) >= $1::date AND tz_date(created_at) <= $2::date`
	unpaidArgs := []interface{}{dateFrom, dateTo}
	if filterIDs != nil {
		unpaidQuery += ` AND outlet_id = ANY($3::text[])`
		unpaidArgs = append(unpaidArgs, pq.Array(filterIDs))
	}
	if err := database.DB.QueryRow(unpaidQuery, unpaidArgs...).Scan(
		&report.Summary.UnpaidOrders,
		&report.Summary.UnpaidAmount,
	); err != nil {
		log.Printf("Sales report unpaid query warning: %v", err)
	}

	dailyQuery := `
		SELECT
			TO_CHAR(tz_date(created_at), 'YYYY-MM-DD') AS date,
			COUNT(*)::int,
			COALESCE(SUM(total_amount), 0),
			COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN total_amount ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN payment_method = 'qris' THEN total_amount ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN payment_method = 'card' THEN total_amount ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN payment_method = 'transfer' THEN total_amount ELSE 0 END), 0)
		FROM cloud_transactions
		WHERE tz_date(created_at) >= $1::date AND tz_date(created_at) <= $2::date`

	dailyArgs := []interface{}{dateFrom, dateTo}
	if filterIDs != nil {
		dailyQuery += ` AND outlet_id = ANY($3::text[])`
		dailyArgs = append(dailyArgs, pq.Array(filterIDs))
	}
	dailyQuery += ` GROUP BY tz_date(created_at) ORDER BY tz_date(created_at) DESC`

	dailyRows, err := database.DB.Query(dailyQuery, dailyArgs...)
	if err != nil {
		return nil, fmt.Errorf("sales report daily query failed: %w", err)
	}
	defer dailyRows.Close()

	report.Daily = []models.SalesReportRow{}
	for dailyRows.Next() {
		var row models.SalesReportRow
		if err := dailyRows.Scan(&row.Date, &row.TotalTransactions, &row.TotalRevenue,
			&row.CashRevenue, &row.QrisRevenue, &row.CardRevenue, &row.TransferRevenue); err != nil {
			return nil, fmt.Errorf("sales report daily scan failed: %w", err)
		}
		report.Daily = append(report.Daily, row)
	}

	outletQuery := `
		SELECT
			t.outlet_id,
			COALESCE(o.name, t.outlet_code),
			COUNT(*)::int,
			COALESCE(SUM(t.total_amount), 0),
			COALESCE(uq.cnt, 0)::int,
			COALESCE(uq.amt, 0)
		FROM cloud_transactions t
		LEFT JOIN outlets o ON o.id = t.outlet_id
		LEFT JOIN (
			SELECT outlet_id, COUNT(*) AS cnt, SUM(total_amount) AS amt
			FROM cloud_orders
			WHERE status NOT IN ('paid','cancelled','voided')
			  AND tz_date(created_at) >= $1::date AND tz_date(created_at) <= $2::date
			GROUP BY outlet_id
		) uq ON uq.outlet_id = t.outlet_id
		WHERE tz_date(t.created_at) >= $1::date AND tz_date(t.created_at) <= $2::date`

	outletArgs := []interface{}{dateFrom, dateTo}
	if filterIDs != nil {
		outletQuery += ` AND t.outlet_id = ANY($3::text[])`
		outletArgs = append(outletArgs, pq.Array(filterIDs))
	}
	outletQuery += ` GROUP BY t.outlet_id, o.name, t.outlet_code, uq.cnt, uq.amt ORDER BY SUM(t.total_amount) DESC`

	outletRows, err := database.DB.Query(outletQuery, outletArgs...)
	if err != nil {
		return nil, fmt.Errorf("sales report outlet query failed: %w", err)
	}
	defer outletRows.Close()

	report.ByOutlet = []models.SalesReportOutlet{}
	for outletRows.Next() {
		var row models.SalesReportOutlet
		if err := outletRows.Scan(&row.OutletID, &row.OutletName, &row.TotalTransactions, &row.TotalRevenue, &row.UnpaidOrders, &row.UnpaidAmount); err != nil {
			return nil, fmt.Errorf("sales report outlet scan failed: %w", err)
		}
		report.ByOutlet = append(report.ByOutlet, row)
	}

	countQuery := `SELECT COUNT(*) FROM cloud_transactions
		WHERE tz_date(created_at) >= $1::date AND tz_date(created_at) <= $2::date`
	countArgs := []interface{}{dateFrom, dateTo}
	if filterIDs != nil {
		countQuery += ` AND outlet_id = ANY($3::text[])`
		countArgs = append(countArgs, pq.Array(filterIDs))
	}

	var total int
	if err := database.DB.QueryRow(countQuery, countArgs...).Scan(&total); err != nil {
		return nil, fmt.Errorf("sales report count query failed: %w", err)
	}
	report.Total = total
	report.TotalPages = int(math.Ceil(float64(total) / float64(limit)))

	offset := (page - 1) * limit
	txQuery := `
		SELECT
			t.id,
			COALESCE(o.name, t.outlet_code),
			t.outlet_code,
			t.total_amount,
			t.payment_method,
			t.cashier_name,
			t.items,
			TO_CHAR(t.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
		FROM cloud_transactions t
		LEFT JOIN outlets o ON o.id = t.outlet_id
		WHERE tz_date(t.created_at) >= $1::date AND tz_date(t.created_at) <= $2::date`

	txArgs := []interface{}{dateFrom, dateTo}
	paramIdx := 3
	if filterIDs != nil {
		txQuery += fmt.Sprintf(` AND t.outlet_id = ANY($%d::text[])`, paramIdx)
		txArgs = append(txArgs, pq.Array(filterIDs))
		paramIdx++
	}
	txQuery += fmt.Sprintf(` ORDER BY t.created_at DESC LIMIT $%d OFFSET $%d`, paramIdx, paramIdx+1)
	txArgs = append(txArgs, limit, offset)

	txRows, err := database.DB.Query(txQuery, txArgs...)
	if err != nil {
		return nil, fmt.Errorf("sales report transactions query failed: %w", err)
	}
	defer txRows.Close()

	transactions := []models.SalesReportTransaction{}
	for txRows.Next() {
		var t models.SalesReportTransaction
		if err := txRows.Scan(&t.ID, &t.OutletName, &t.OutletCode, &t.TotalAmount,
			&t.PaymentMethod, &t.CashierName, &t.Items, &t.CreatedAt); err != nil {
			return nil, fmt.Errorf("sales report transaction scan failed: %w", err)
		}
		transactions = append(transactions, t)
	}

	report.Transactions = transactions
	return report, nil
}

func GetUnpaidOrders(outletID, status string, scopeIDs []string, page, limit int) (*models.UnpaidOrdersResponse, error) {
	report := &models.UnpaidOrdersResponse{
		Page:  page,
		Limit: limit,
	}

	// Normalize outlet filter
	var filterIDs []string
	if outletID != "" {
		filterIDs = []string{outletID}
	} else if scopeIDs != nil {
		filterIDs = scopeIDs
	}

	where := `WHERE COALESCE(o.payment_info->>'payment_status','unpaid') NOT IN ('paid') AND NULLIF(o.payment_info->>'voided_at','') IS NULL`
	args := []interface{}{}
	paramIdx := 1

	if filterIDs != nil {
		where += fmt.Sprintf(` AND o.outlet_id = ANY($%d::text[])`, paramIdx)
		args = append(args, pq.Array(filterIDs))
		paramIdx++
	}
	if status != "" {
		where += fmt.Sprintf(` AND o.status = $%d`, paramIdx)
		args = append(args, status)
		paramIdx++
	}

	sumQ := `SELECT COUNT(*)::int, COALESCE(SUM(o.total_amount), 0) FROM cloud_orders o ` + where
	if err := database.DB.QueryRow(sumQ, args...).Scan(&report.TotalUnpaid, &report.TotalAmount); err != nil {
		return nil, fmt.Errorf("unpaid orders summary failed: %w", err)
	}

	report.Total = report.TotalUnpaid
	report.TotalPages = int(math.Ceil(float64(report.Total) / float64(limit)))

	offset := (page - 1) * limit
	listQ := fmt.Sprintf(`
		SELECT
			o.id,
			COALESCE(ot.name, o.outlet_code),
			o.outlet_code,
			COALESCE(o.table_number, ''),
			COALESCE(o.customer_name, ''),
			o.pax,
			o.total_amount,
			o.status,
			COALESCE(o.items::text, '[]'),
			TO_CHAR(o.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
			TO_CHAR(o.updated_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
		FROM cloud_orders o
		LEFT JOIN outlets ot ON ot.id = o.outlet_id
		%s
		ORDER BY o.created_at DESC
		LIMIT $%d OFFSET $%d`, where, paramIdx, paramIdx+1)

	listArgs := append(args, limit, offset)
	rows, err := database.DB.Query(listQ, listArgs...)
	if err != nil {
		return nil, fmt.Errorf("unpaid orders list failed: %w", err)
	}
	defer rows.Close()

	report.Orders = []models.UnpaidOrderRow{}
	for rows.Next() {
		var r models.UnpaidOrderRow
		if err := rows.Scan(&r.ID, &r.OutletName, &r.OutletCode, &r.TableNumber,
			&r.CustomerName, &r.Pax, &r.TotalAmount, &r.Status, &r.Items,
			&r.CreatedAt, &r.UpdatedAt); err != nil {
			return nil, fmt.Errorf("unpaid orders scan failed: %w", err)
		}
		report.Orders = append(report.Orders, r)
	}

	return report, nil
}

func GetProductSalesReport(dateFrom, dateTo, outletID string, scopeIDs []string) (*models.ProductSalesResponse, error) {
	conds := []string{"tz_date(o.created_at) >= $1::date", "tz_date(o.created_at) <= $2::date"}
	args := []interface{}{dateFrom, dateTo}
	idx := 3

	// Normalize outlet filter
	var filterIDs []string
	if outletID != "" {
		filterIDs = []string{outletID}
	} else if scopeIDs != nil {
		filterIDs = scopeIDs
	}

	if filterIDs != nil {
		conds = append(conds, fmt.Sprintf("o.outlet_id = ANY($%d::text[])", idx))
		args = append(args, pq.Array(filterIDs))
		idx++
	}
	whereSQL := "WHERE " + strings.Join(conds, " AND ")

	query := fmt.Sprintf(`
		SELECT
			COALESCE(NULLIF(item->>'product_name', ''), 'Unknown')       AS product_name,
			COALESCE(NULLIF(item->>'category_name', ''), COALESCE(NULLIF(item->>'category', ''), 'Tidak Berkategori')) AS category_name,
			SUM(COALESCE((item->>'qty')::int, 0))                         AS total_qty,
			SUM(COALESCE((item->>'subtotal')::float8, COALESCE((item->>'price')::float8, 0) * COALESCE((item->>'qty')::int, 0))) AS total_revenue
		FROM cloud_orders o,
			jsonb_array_elements(COALESCE(o.items, '[]'::jsonb)) AS item
		%s
		GROUP BY product_name, category_name
		ORDER BY total_revenue DESC`, whereSQL)

	rows, err := database.DB.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]models.ProductSalesRow, 0)
	for rows.Next() {
		var r models.ProductSalesRow
		if err := rows.Scan(&r.ProductName, &r.CategoryName, &r.TotalQty, &r.TotalRevenue); err != nil {
			return nil, err
		}
		items = append(items, r)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	return &models.ProductSalesResponse{
		DateFrom: dateFrom,
		DateTo:   dateTo,
		Total:    len(items),
		Items:    items,
	}, nil
}

func GetTaxReport(dateFrom, dateTo, outletID string, scopeIDs []string) (*models.TaxReportResponse, error) {
	taxRate := GetTaxRate()
	taxSettings, _ := GetTaxSettings()

	// Normalize outlet filter
	var filterIDs []string
	if outletID != "" {
		filterIDs = []string{outletID}
	} else if scopeIDs != nil {
		filterIDs = scopeIDs
	}

	args := []interface{}{dateFrom, dateTo}
	outletFilter := ""
	if filterIDs != nil {
		outletFilter = " AND outlet_id = ANY($3::text[])"
		args = append(args, pq.Array(filterIDs))
	}

	var totalTx int
	var gross float64
	if err := database.DB.QueryRow(
		`SELECT COUNT(*)::int, COALESCE(SUM(total_amount), 0)
		 FROM cloud_transactions
		 WHERE tz_date(created_at) >= $1::date AND tz_date(created_at) <= $2::date`+outletFilter,
		args...,
	).Scan(&totalTx, &gross); err != nil {
		return nil, err
	}

	round2 := func(v float64) float64 { return math.Round(v*100) / 100 }
	summary := models.TaxReportSummary{
		TotalTransactions: totalTx,
		GrossRevenue:      gross,
		TaxAmount:         round2(gross * taxRate),
		NetRevenue:        round2(gross - gross*taxRate),
		TaxRate:           taxSettings.TaxRate,
	}

	dailyRows, err := database.DB.Query(
		`SELECT TO_CHAR(tz_date(created_at), 'YYYY-MM-DD'), COUNT(*)::int, COALESCE(SUM(total_amount), 0)
		 FROM cloud_transactions
		 WHERE tz_date(created_at) >= $1::date AND tz_date(created_at) <= $2::date`+outletFilter+`
		 GROUP BY tz_date(created_at) ORDER BY tz_date(created_at) DESC`,
		args...,
	)
	if err != nil {
		return nil, err
	}
	defer dailyRows.Close()

	daily := make([]models.TaxReportRow, 0)
	for dailyRows.Next() {
		var r models.TaxReportRow
		var g float64
		if err := dailyRows.Scan(&r.Date, &r.TotalTransactions, &g); err != nil {
			return nil, err
		}
		r.GrossRevenue = g
		r.TaxAmount = round2(g * taxRate)
		r.NetRevenue = round2(g - g*taxRate)
		daily = append(daily, r)
	}
	if err := dailyRows.Err(); err != nil {
		return nil, err
	}

	outletArgs := []interface{}{dateFrom, dateTo}
	outletFilter2 := ""
	if filterIDs != nil {
		outletFilter2 = " AND t.outlet_id = ANY($3::text[])"
		outletArgs = append(outletArgs, pq.Array(filterIDs))
	}
	outletRows, err := database.DB.Query(
		`SELECT t.outlet_id, COALESCE(o.name, t.outlet_code), COALESCE(SUM(t.total_amount), 0)
		 FROM cloud_transactions t
		 LEFT JOIN outlets o ON o.id = t.outlet_id
		 WHERE tz_date(t.created_at) >= $1::date AND tz_date(t.created_at) <= $2::date`+outletFilter2+`
		 GROUP BY t.outlet_id, o.name, t.outlet_code
		 ORDER BY SUM(t.total_amount) DESC`,
		outletArgs...,
	)
	if err != nil {
		return nil, err
	}
	defer outletRows.Close()

	byOutlet := make([]models.TaxOutletRow, 0)
	for outletRows.Next() {
		var r models.TaxOutletRow
		var g float64
		if err := outletRows.Scan(&r.OutletID, &r.OutletName, &g); err != nil {
			return nil, err
		}
		r.GrossRevenue = g
		r.TaxAmount = round2(g * taxRate)
		r.NetRevenue = round2(g - g*taxRate)
		byOutlet = append(byOutlet, r)
	}
	if err := outletRows.Err(); err != nil {
		return nil, err
	}

	return &models.TaxReportResponse{Summary: summary, Daily: daily, ByOutlet: byOutlet}, nil
}

func GetCashFlowReport(dateFrom, dateTo, outletID string, scopeIDs []string) (*models.CashFlowResponse, error) {
	// Normalize outlet filter
	var filterIDs []string
	if outletID != "" {
		filterIDs = []string{outletID}
	} else if scopeIDs != nil {
		filterIDs = scopeIDs
	}

	args := []interface{}{dateFrom, dateTo}
	outletFilter := ""
	if filterIDs != nil {
		outletFilter = " AND outlet_id = ANY($3::text[])"
		args = append(args, pq.Array(filterIDs))
	}

	query := `
		SELECT TO_CHAR(date, 'YYYY-MM-DD') AS date,
			SUM(sales_receipts) AS sales_receipts,
			SUM(other_receipts) AS other_receipts,
			SUM(cogs_payments)  AS cogs_payments,
			SUM(svc_payments)   AS svc_payments,
			SUM(opex_payments)  AS opex_payments
		FROM (
			-- Penerimaan Penjualan
			SELECT tz_date(created_at) AS date,
				total_amount AS sales_receipts,
				0::float8 AS other_receipts,
				0::float8 AS cogs_payments,
				0::float8 AS svc_payments,
				0::float8 AS opex_payments
			FROM cloud_transactions
			WHERE tz_date(created_at) >= $1::date AND tz_date(created_at) <= $2::date` + outletFilter + `

			UNION ALL

			-- Kas Masuk = Penerimaan Lainnya, Kas Keluar = Beban Operasional
			SELECT tz_date(created_at) AS date,
				0::float8,
				CASE WHEN LOWER(movement_type) IN ('masuk','in','income','pemasukan') THEN amount ELSE 0 END,
				0::float8,
				0::float8,
				CASE WHEN LOWER(movement_type) NOT IN ('masuk','in','income','pemasukan') THEN amount ELSE 0 END
			FROM cloud_cash_movements
			WHERE tz_date(created_at) >= $1::date AND tz_date(created_at) <= $2::date` + outletFilter + `

			UNION ALL

			-- Pengadaan Barang = HPP, Jasa = Beban Jasa
			SELECT tz_date(paid_at) AS date,
				0::float8, 0::float8,
				CASE WHEN request_type = 'barang' THEN paid_amount ELSE 0 END,
				CASE WHEN request_type = 'jasa'   THEN paid_amount ELSE 0 END,
				0::float8
			FROM purchase_requests
			WHERE status IN ('partial','paid','received')
			  AND paid_at IS NOT NULL
			  AND split_status IS NULL
			  AND tz_date(paid_at) >= $1::date AND tz_date(paid_at) <= $2::date` + outletFilter + `
		) sub
		GROUP BY date
		ORDER BY date DESC`

	rows, err := database.DB.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	daily := make([]models.CashFlowRow, 0)
	var sumSales, sumOther, sumCOGS, sumSvc, sumOpex float64
	for rows.Next() {
		var r models.CashFlowRow
		if err := rows.Scan(&r.Date, &r.SalesReceipts, &r.OtherReceipts,
			&r.COGSPayments, &r.ServicePayments, &r.OpexPayments); err != nil {
			return nil, err
		}
		r.NetCashFlow = (r.SalesReceipts + r.OtherReceipts) - (r.COGSPayments + r.ServicePayments + r.OpexPayments)
		daily = append(daily, r)
		sumSales += r.SalesReceipts
		sumOther += r.OtherReceipts
		sumCOGS += r.COGSPayments
		sumSvc += r.ServicePayments
		sumOpex += r.OpexPayments
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	totalReceipts := sumSales + sumOther
	totalPayments := sumCOGS + sumSvc + sumOpex

	return &models.CashFlowResponse{
		Summary: models.CashFlowSummary{
			SalesReceipts:   sumSales,
			OtherReceipts:   sumOther,
			TotalReceipts:   totalReceipts,
			COGSPayments:    sumCOGS,
			ServicePayments: sumSvc,
			OpexPayments:    sumOpex,
			TotalPayments:   totalPayments,
			NetCashFlow:     totalReceipts - totalPayments,
		},
		Daily: daily,
	}, nil
}

func GetBalanceReport(dateFrom, dateTo, outletID string, scopeIDs []string) (*models.BalanceResponse, error) {
	taxRate := GetTaxRate()
	round2 := func(v float64) float64 { return math.Round(v*100) / 100 }

	// Normalize outlet filter
	var filterIDs []string
	if outletID != "" {
		filterIDs = []string{outletID}
	} else if scopeIDs != nil {
		filterIDs = scopeIDs
	}

	args := []interface{}{dateFrom, dateTo}
	outletWhere := ""
	if filterIDs != nil {
		outletWhere = " AND o.id = ANY($3::text[])"
		args = append(args, pq.Array(filterIDs))
	}

	outletRows, err := database.DB.Query(`
		SELECT
			o.id,
			o.name,
			COALESCE(t.total_revenue, 0),
			COALESCE(mv.total_cash_in, 0),
			COALESCE(mv.total_expense, 0),
			COALESCE(uq.unpaid_amount, 0),
			COALESCE(pr.total_procurement, 0),
			COALESCE(ap.accounts_payable, 0)
		FROM outlets o
		LEFT JOIN (
			SELECT outlet_id, SUM(total_amount) AS total_revenue
			FROM cloud_transactions
			WHERE tz_date(created_at) >= $1::date AND tz_date(created_at) <= $2::date
			GROUP BY outlet_id
		) t ON t.outlet_id = o.id
		LEFT JOIN (
			SELECT outlet_id,
				SUM(CASE WHEN LOWER(movement_type) IN ('masuk','in','income','pemasukan') THEN amount ELSE 0 END) AS total_cash_in,
				SUM(CASE WHEN LOWER(movement_type) NOT IN ('masuk','in','income','pemasukan') THEN amount ELSE 0 END) AS total_expense
			FROM cloud_cash_movements
			WHERE tz_date(created_at) >= $1::date AND tz_date(created_at) <= $2::date
			GROUP BY outlet_id
		) mv ON mv.outlet_id = o.id
		LEFT JOIN (
			SELECT outlet_id, SUM(total_amount) AS unpaid_amount
			FROM cloud_orders
			WHERE COALESCE(payment_info->>'payment_status','unpaid') NOT IN ('paid')
			  AND NULLIF(payment_info->>'voided_at','') IS NULL
			GROUP BY outlet_id
		) uq ON uq.outlet_id = o.id
		LEFT JOIN (
			SELECT outlet_id, SUM(paid_amount) AS total_procurement
			FROM purchase_requests
			WHERE status IN ('partial','paid','received')
			  AND paid_at IS NOT NULL
			  AND split_status IS NULL
			  AND tz_date(paid_at) >= $1::date AND tz_date(paid_at) <= $2::date
			GROUP BY outlet_id
		) pr ON pr.outlet_id = o.id
		LEFT JOIN (
			SELECT outlet_id, SUM(CASE WHEN status = 'partial' THEN total_final - paid_amount ELSE COALESCE(total_final, total_amount) END) AS accounts_payable
			FROM purchase_requests
			WHERE status IN ('approved','priced','partial')
			  AND split_status IS NULL
			GROUP BY outlet_id
		) ap ON ap.outlet_id = o.id
		WHERE o.is_active = true
		  AND (t.outlet_id IS NOT NULL OR mv.outlet_id IS NOT NULL OR uq.outlet_id IS NOT NULL OR pr.outlet_id IS NOT NULL OR ap.outlet_id IS NOT NULL)`+outletWhere+`
		ORDER BY COALESCE(t.total_revenue, 0) DESC`,
		args...,
	)
	if err != nil {
		return nil, err
	}
	defer outletRows.Close()

	outlets := make([]models.BalanceOutletRow, 0)
	var sumRev, sumCashIn, sumExp, sumUnpaid, sumAP float64
	for outletRows.Next() {
		var r models.BalanceOutletRow
		var procurement float64
		if err := outletRows.Scan(&r.OutletID, &r.OutletName, &r.TotalRevenue, &r.TotalCashIn, &r.TotalExpense, &r.UnpaidAmount, &procurement, &r.AccountsPayable); err != nil {
			return nil, err
		}
		r.TotalExpense += procurement
		// Aset
		r.CashAndEquivalents = round2(r.TotalRevenue + r.TotalCashIn - r.TotalExpense)
		r.Receivables = r.UnpaidAmount
		r.TotalAssets = round2(r.CashAndEquivalents + r.Receivables)
		// Kewajiban
		r.TaxPayable = round2(r.TotalRevenue * taxRate)
		r.TotalLiabilities = round2(r.TaxPayable + r.AccountsPayable)
		// Ekuitas = Aset - Kewajiban
		r.TotalEquity = round2(r.TotalAssets - r.TotalLiabilities)

		outlets = append(outlets, r)
		sumRev += r.TotalRevenue
		sumCashIn += r.TotalCashIn
		sumExp += r.TotalExpense
		sumUnpaid += r.UnpaidAmount
		sumAP += r.AccountsPayable
	}
	if err := outletRows.Err(); err != nil {
		return nil, err
	}

	// Add procurement with no outlet (outlet_id IS NULL) to global expense
	var nullOutletProcurement float64
	nullPrArgs := []interface{}{dateFrom, dateTo}
	nullPrQuery := `SELECT COALESCE(SUM(paid_amount), 0) FROM purchase_requests
		WHERE status IN ('partial','paid','received') AND paid_at IS NOT NULL
		  AND outlet_id IS NULL
		  AND split_status IS NULL
		  AND tz_date(paid_at) >= $1::date AND tz_date(paid_at) <= $2::date`
	if filterIDs == nil {
		if err := database.DB.QueryRow(nullPrQuery, nullPrArgs...).Scan(&nullOutletProcurement); err != nil {
			return nil, err
		}
		sumExp += nullOutletProcurement
	}

	// Accounts payable with no outlet
	var nullOutletAP float64
	if filterIDs == nil {
		database.DB.QueryRow(`SELECT COALESCE(SUM(CASE WHEN status = 'partial' THEN total_final - paid_amount ELSE COALESCE(total_final, total_amount) END), 0)
			FROM purchase_requests WHERE status IN ('approved','priced','partial') AND outlet_id IS NULL AND split_status IS NULL`).Scan(&nullOutletAP)
		sumAP += nullOutletAP
	}

	// Total accounting
	cash := round2(sumRev + sumCashIn - sumExp)
	receivables := sumUnpaid
	totalAssets := round2(cash + receivables)
	taxPayable := round2(sumRev * taxRate)
	accountsPayable := round2(sumAP)
	totalLiabilities := round2(taxPayable + accountsPayable)
	totalEquity := round2(totalAssets - totalLiabilities)

	return &models.BalanceResponse{
		DateFrom:           dateFrom,
		DateTo:             dateTo,
		CashAndEquivalents: cash,
		Receivables:        receivables,
		TotalAssets:        totalAssets,
		AccountsPayable:    accountsPayable,
		TaxPayable:         taxPayable,
		TotalLiabilities:   totalLiabilities,
		TotalEquity:        totalEquity,
		TotalRevenue:       sumRev,
		TotalCashIn:        sumCashIn,
		TotalExpense:       sumExp,
		UnpaidAmount:       sumUnpaid,
		Outlets:            outlets,
	}, nil
}

func GetProfitLossReport(dateFrom, dateTo, outletID string, scopeIDs []string) (*models.ProfitLossResponse, error) {
	taxRate := GetTaxRate()
	round2 := func(v float64) float64 { return math.Round(v*100) / 100 }

	// Normalize outlet filter
	var filterIDs []string
	if outletID != "" {
		filterIDs = []string{outletID}
	} else if scopeIDs != nil {
		filterIDs = scopeIDs
	}

	args := []interface{}{dateFrom, dateTo}
	outletFilter := ""
	if filterIDs != nil {
		outletFilter = " AND outlet_id = ANY($3::text[])"
		args = append(args, pq.Array(filterIDs))
	}

	// ── Daily breakdown ──
	dailyRows, err := database.DB.Query(`
		SELECT TO_CHAR(date, 'YYYY-MM-DD') AS date,
			SUM(revenue) AS revenue,
			SUM(cogs)    AS cogs,
			SUM(opex)    AS opex
		FROM (
			SELECT tz_date(created_at) AS date, total_amount AS revenue, 0::float8 AS cogs, 0::float8 AS opex
			FROM cloud_transactions
			WHERE tz_date(created_at) >= $1::date AND tz_date(created_at) <= $2::date`+outletFilter+`

			UNION ALL

			SELECT tz_date(created_at) AS date, 0::float8, 0::float8, amount
			FROM cloud_cash_movements
			WHERE LOWER(movement_type) NOT IN ('masuk','in','income','pemasukan')
			  AND tz_date(created_at) >= $1::date AND tz_date(created_at) <= $2::date`+outletFilter+`

			UNION ALL

			SELECT tz_date(paid_at) AS date, 0::float8,
				CASE WHEN request_type = 'barang' THEN paid_amount ELSE 0 END,
				CASE WHEN request_type = 'jasa'   THEN paid_amount ELSE 0 END
			FROM purchase_requests
			WHERE status IN ('partial','paid','received')
			  AND paid_at IS NOT NULL
			  AND split_status IS NULL
			  AND tz_date(paid_at) >= $1::date AND tz_date(paid_at) <= $2::date`+outletFilter+`
		) sub
		GROUP BY date
		ORDER BY date DESC`,
		args...,
	)
	if err != nil {
		return nil, err
	}
	defer dailyRows.Close()

	daily := make([]models.ProfitLossRow, 0)
	for dailyRows.Next() {
		var r models.ProfitLossRow
		var opex float64
		if err := dailyRows.Scan(&r.Date, &r.Revenue, &r.COGS, &opex); err != nil {
			return nil, err
		}
		r.GrossProfit = r.Revenue - r.COGS
		r.OperatingExpense = opex
		r.NetProfit = r.GrossProfit - opex
		daily = append(daily, r)
	}
	if err := dailyRows.Err(); err != nil {
		return nil, err
	}

	// ── Summary totals ──
	var salesRevenue, otherIncome, totalCOGS, serviceExpense, operatingExpense float64

	// Sales revenue
	revArgs := []interface{}{dateFrom, dateTo}
	revQ := `SELECT COALESCE(SUM(total_amount), 0) FROM cloud_transactions
		WHERE tz_date(created_at) >= $1::date AND tz_date(created_at) <= $2::date`
	if filterIDs != nil {
		revQ += ` AND outlet_id = ANY($3::text[])`
		revArgs = append(revArgs, pq.Array(filterIDs))
	}
	database.DB.QueryRow(revQ, revArgs...).Scan(&salesRevenue)

	// Other income (kas masuk)
	oiArgs := []interface{}{dateFrom, dateTo}
	oiQ := `SELECT COALESCE(SUM(amount), 0) FROM cloud_cash_movements
		WHERE LOWER(movement_type) IN ('masuk','in','income','pemasukan')
		  AND tz_date(created_at) >= $1::date AND tz_date(created_at) <= $2::date`
	if filterIDs != nil {
		oiQ += ` AND outlet_id = ANY($3::text[])`
		oiArgs = append(oiArgs, pq.Array(filterIDs))
	}
	database.DB.QueryRow(oiQ, oiArgs...).Scan(&otherIncome)

	// COGS (purchase barang) and Service expense (purchase jasa)
	prArgs := []interface{}{dateFrom, dateTo}
	prQ := `SELECT
		COALESCE(SUM(CASE WHEN request_type = 'barang' THEN paid_amount ELSE 0 END), 0),
		COALESCE(SUM(CASE WHEN request_type = 'jasa'   THEN paid_amount ELSE 0 END), 0)
	FROM purchase_requests
	WHERE status IN ('partial','paid','received') AND paid_at IS NOT NULL
	  AND split_status IS NULL
	  AND tz_date(paid_at) >= $1::date AND tz_date(paid_at) <= $2::date`
	if filterIDs != nil {
		prQ += ` AND outlet_id = ANY($3::text[])`
		prArgs = append(prArgs, pq.Array(filterIDs))
	}
	database.DB.QueryRow(prQ, prArgs...).Scan(&totalCOGS, &serviceExpense)

	// Operating expense (kas keluar)
	opArgs := []interface{}{dateFrom, dateTo}
	opQ := `SELECT COALESCE(SUM(amount), 0) FROM cloud_cash_movements
		WHERE LOWER(movement_type) NOT IN ('masuk','in','income','pemasukan')
		  AND tz_date(created_at) >= $1::date AND tz_date(created_at) <= $2::date`
	if filterIDs != nil {
		opQ += ` AND outlet_id = ANY($3::text[])`
		opArgs = append(opArgs, pq.Array(filterIDs))
	}
	database.DB.QueryRow(opQ, opArgs...).Scan(&operatingExpense)

	totalRevenue := salesRevenue + otherIncome
	grossProfit := salesRevenue - totalCOGS
	totalOpex := serviceExpense + operatingExpense
	operatingProfit := grossProfit + otherIncome - totalOpex
	taxExpense := round2(salesRevenue * taxRate)
	netProfit := operatingProfit - taxExpense

	grossMargin := 0.0
	if salesRevenue > 0 {
		grossMargin = math.Round(grossProfit/salesRevenue*10000) / 100
	}
	netMargin := 0.0
	if totalRevenue > 0 {
		netMargin = math.Round(netProfit/totalRevenue*10000) / 100
	}

	// ── Per-outlet breakdown ──
	outletArgs := []interface{}{dateFrom, dateTo}
	outletFilter2 := ""
	if filterIDs != nil {
		outletFilter2 = " AND o.id = ANY($3::text[])"
		outletArgs = append(outletArgs, pq.Array(filterIDs))
	}
	outletQRows, err := database.DB.Query(`
		SELECT
			o.id,
			o.name,
			COALESCE(t.revenue, 0),
			COALESCE(pr_b.cogs, 0),
			COALESCE(mv.expense, 0) + COALESCE(pr_j.svc, 0)
		FROM outlets o
		LEFT JOIN (
			SELECT outlet_id, SUM(total_amount) AS revenue
			FROM cloud_transactions
			WHERE tz_date(created_at) >= $1::date AND tz_date(created_at) <= $2::date
			GROUP BY outlet_id
		) t ON t.outlet_id = o.id
		LEFT JOIN (
			SELECT outlet_id, SUM(paid_amount) AS cogs
			FROM purchase_requests
			WHERE status IN ('partial','paid','received') AND paid_at IS NOT NULL AND request_type = 'barang'
			  AND split_status IS NULL
			  AND tz_date(paid_at) >= $1::date AND tz_date(paid_at) <= $2::date
			GROUP BY outlet_id
		) pr_b ON pr_b.outlet_id = o.id
		LEFT JOIN (
			SELECT outlet_id, SUM(paid_amount) AS svc
			FROM purchase_requests
			WHERE status IN ('partial','paid','received') AND paid_at IS NOT NULL AND request_type = 'jasa'
			  AND split_status IS NULL
			  AND tz_date(paid_at) >= $1::date AND tz_date(paid_at) <= $2::date
			GROUP BY outlet_id
		) pr_j ON pr_j.outlet_id = o.id
		LEFT JOIN (
			SELECT outlet_id, SUM(amount) AS expense
			FROM cloud_cash_movements
			WHERE LOWER(movement_type) NOT IN ('masuk','in','income','pemasukan')
			  AND tz_date(created_at) >= $1::date AND tz_date(created_at) <= $2::date
			GROUP BY outlet_id
		) mv ON mv.outlet_id = o.id
		WHERE o.is_active = true
		  AND (t.outlet_id IS NOT NULL OR mv.outlet_id IS NOT NULL OR pr_b.outlet_id IS NOT NULL OR pr_j.outlet_id IS NOT NULL)`+outletFilter2+`
		ORDER BY COALESCE(t.revenue, 0) DESC`,
		outletArgs...,
	)
	if err != nil {
		return nil, err
	}
	defer outletQRows.Close()

	byOutlet := make([]models.ProfitLossOutletRow, 0)
	for outletQRows.Next() {
		var r models.ProfitLossOutletRow
		if err := outletQRows.Scan(&r.OutletID, &r.OutletName, &r.Revenue, &r.COGS, &r.OperatingExpense); err != nil {
			return nil, err
		}
		r.NetProfit = r.Revenue - r.COGS - r.OperatingExpense
		byOutlet = append(byOutlet, r)
	}
	if err := outletQRows.Err(); err != nil {
		return nil, err
	}

	return &models.ProfitLossResponse{
		Summary: models.ProfitLossSummary{
			SalesRevenue:     round2(salesRevenue),
			OtherIncome:      round2(otherIncome),
			TotalRevenue:     round2(totalRevenue),
			COGS:             round2(totalCOGS),
			GrossProfit:      round2(grossProfit),
			GrossMargin:      grossMargin,
			ServiceExpense:   round2(serviceExpense),
			OperatingExpense: round2(operatingExpense),
			TotalOpex:        round2(totalOpex),
			OperatingProfit:  round2(operatingProfit),
			TaxExpense:       taxExpense,
			NetProfit:        round2(netProfit),
			NetMargin:        netMargin,
		},
		Daily:    daily,
		ByOutlet: byOutlet,
	}, nil
}

// ── Buku Besar (General Ledger) ─────────────────────────────

func GetGeneralLedger(dateFrom, dateTo, outletID, accountFilter string, scopeIDs []string) (*models.GeneralLedgerResponse, error) {
	round2 := func(v float64) float64 { return math.Round(v*100) / 100 }
	taxRate := GetTaxRate()

	// Account codes — COA F&B
	const (
		accCash        = "1-100"
		accReceivable  = "1-200"
		accPayable     = "2-100"
		accTaxPayable  = "2-200"
		accRevenue     = "4-100"
		accOtherIncome = "4-200"
		accCOGS        = "5-100"
		accServiceExp  = "5-200"
		accOpex        = "5-300"
		accTaxExpense  = "6-100"
	)

	// Normalize outlet filter
	var filterIDs []string
	if outletID != "" {
		filterIDs = []string{outletID}
	} else if scopeIDs != nil {
		filterIDs = scopeIDs
	}

	type rawEntry struct {
		AccountCode string
		Date        string
		Description string
		Debit       float64
		Credit      float64
	}

	var entries []rawEntry

	args := []interface{}{dateFrom, dateTo}
	outletFilter := ""
	if filterIDs != nil {
		outletFilter = " AND outlet_id = ANY($3::text[])"
		args = append(args, pq.Array(filterIDs))
	}

	// Skip queries not relevant to the filtered account
	needQ := func(accounts ...string) bool {
		if accountFilter == "" {
			return true
		}
		for _, a := range accounts {
			if accountFilter == a {
				return true
			}
		}
		return false
	}

	// 1) Pendapatan Penjualan — from cloud_transactions
	if needQ(accCash, accRevenue) {
	txQuery := `
		SELECT
			TO_CHAR(tz_date(created_at), 'YYYY-MM-DD') AS date,
			COALESCE(cashier_name, 'Kasir') || ' - ' || COALESCE(payment_method, '') AS description,
			total_amount
		FROM cloud_transactions
		WHERE tz_date(created_at) >= $1::date AND tz_date(created_at) <= $2::date` + outletFilter + `
		ORDER BY created_at`

	txRows, err := database.DB.Query(txQuery, args...)
	if err != nil {
		return nil, fmt.Errorf("general ledger: revenue query failed: %w", err)
	}
	defer txRows.Close()

	for txRows.Next() {
		var date, desc string
		var amount float64
		if err := txRows.Scan(&date, &desc, &amount); err != nil {
			return nil, fmt.Errorf("general ledger: revenue scan failed: %w", err)
		}
		entries = append(entries, rawEntry{AccountCode: accCash, Date: date, Description: "Penjualan: " + desc, Debit: amount})
		entries = append(entries, rawEntry{AccountCode: accRevenue, Date: date, Description: "Penjualan: " + desc, Credit: amount})
	}
	if err := txRows.Err(); err != nil {
		return nil, err
	}
	}

	// 2) Kas Masuk & Pengeluaran Operasional — from cloud_cash_movements
	if needQ(accCash, accOtherIncome, accOpex) {
	mvQuery := `
		SELECT
			TO_CHAR(tz_date(created_at), 'YYYY-MM-DD') AS date,
			COALESCE(NULLIF(note, ''), movement_type) AS description,
			movement_type,
			amount
		FROM cloud_cash_movements
		WHERE tz_date(created_at) >= $1::date AND tz_date(created_at) <= $2::date` + outletFilter + `
		ORDER BY created_at`

	mvRows, err := database.DB.Query(mvQuery, args...)
	if err != nil {
		return nil, fmt.Errorf("general ledger: cash movement query failed: %w", err)
	}
	defer mvRows.Close()

	for mvRows.Next() {
		var date, desc, mvType string
		var amount float64
		if err := mvRows.Scan(&date, &desc, &mvType, &amount); err != nil {
			return nil, fmt.Errorf("general ledger: cash movement scan failed: %w", err)
		}
		isIncome := strings.EqualFold(mvType, "masuk") || strings.EqualFold(mvType, "in") ||
			strings.EqualFold(mvType, "income") || strings.EqualFold(mvType, "pemasukan")

		if isIncome {
			entries = append(entries, rawEntry{AccountCode: accCash, Date: date, Description: "Kas Masuk: " + desc, Debit: amount})
			entries = append(entries, rawEntry{AccountCode: accOtherIncome, Date: date, Description: "Kas Masuk: " + desc, Credit: amount})
		} else {
			entries = append(entries, rawEntry{AccountCode: accOpex, Date: date, Description: "Pengeluaran: " + desc, Debit: amount})
			entries = append(entries, rawEntry{AccountCode: accCash, Date: date, Description: "Pengeluaran: " + desc, Credit: amount})
		}
	}
	if err := mvRows.Err(); err != nil {
		return nil, err
	}
	}

	// 3) Pengadaan Dibayar — split by type (barang→HPP, jasa→Beban Jasa)
	if needQ(accCash, accCOGS, accServiceExp) {
	prArgs := []interface{}{dateFrom, dateTo}
	prFilter := ""
	if filterIDs != nil {
		prFilter = " AND pr.outlet_id = ANY($3::text[])"
		prArgs = append(prArgs, pq.Array(filterIDs))
	}
	prQuery := `
		SELECT
			TO_CHAR(tz_date(pr.paid_at), 'YYYY-MM-DD') AS date,
			pr.request_type,
			pr.request_type || ': ' || COALESCE(wu.name, '-') || ' — ' || pr.requested_by AS description,
			pr.paid_amount
		FROM purchase_requests pr
		LEFT JOIN work_units wu ON wu.id = pr.work_unit_id
		WHERE pr.status IN ('partial', 'paid', 'received')
		  AND pr.paid_at IS NOT NULL
		  AND (pr.split_status IS NULL OR pr.split_status != 'master')
		  AND tz_date(pr.paid_at) >= $1::date AND tz_date(pr.paid_at) <= $2::date` + prFilter + `
		ORDER BY pr.paid_at`

	prRows, err := database.DB.Query(prQuery, prArgs...)
	if err != nil {
		return nil, fmt.Errorf("general ledger: procurement query failed: %w", err)
	}
	defer prRows.Close()

	for prRows.Next() {
		var date, reqType, desc string
		var amount float64
		if err := prRows.Scan(&date, &reqType, &desc, &amount); err != nil {
			return nil, fmt.Errorf("general ledger: procurement scan failed: %w", err)
		}
		expAccount := accCOGS
		prefix := "HPP: "
		if reqType == "jasa" {
			expAccount = accServiceExp
			prefix = "Beban Jasa: "
		}
		entries = append(entries, rawEntry{AccountCode: expAccount, Date: date, Description: prefix + desc, Debit: amount})
		entries = append(entries, rawEntry{AccountCode: accCash, Date: date, Description: prefix + desc, Credit: amount})
	}
	if err := prRows.Err(); err != nil {
		return nil, err
	}
	}

	// 4) Hutang Usaha — approved but unpaid purchase_requests
	if needQ(accPayable, accCOGS, accServiceExp) {
	apArgs := []interface{}{dateFrom, dateTo}
	apFilter := ""
	if filterIDs != nil {
		apFilter = " AND pr.outlet_id = ANY($3::text[])"
		apArgs = append(apArgs, pq.Array(filterIDs))
	}
	apQuery := `
		SELECT
			TO_CHAR(tz_date(pr.created_at), 'YYYY-MM-DD') AS date,
			pr.request_type,
			pr.request_type || ': ' || COALESCE(wu.name, '-') || ' — ' || pr.requested_by AS description,
			CASE WHEN pr.status = 'partial' THEN pr.total_final - pr.paid_amount ELSE COALESCE(pr.total_final, pr.total_amount) END
		FROM purchase_requests pr
		LEFT JOIN work_units wu ON wu.id = pr.work_unit_id
		WHERE pr.status IN ('approved', 'payment_requested', 'partial')
		  AND (pr.split_status IS NULL OR pr.split_status != 'master')
		  AND tz_date(pr.created_at) >= $1::date AND tz_date(pr.created_at) <= $2::date` + apFilter + `
		ORDER BY pr.created_at`

	apRows, err := database.DB.Query(apQuery, apArgs...)
	if err != nil {
		return nil, fmt.Errorf("general ledger: payable query failed: %w", err)
	}
	defer apRows.Close()

	for apRows.Next() {
		var date, reqType, desc string
		var amount float64
		if err := apRows.Scan(&date, &reqType, &desc, &amount); err != nil {
			return nil, fmt.Errorf("general ledger: payable scan failed: %w", err)
		}
		expAccount := accCOGS
		prefix := "HPP (Hutang): "
		if reqType == "jasa" {
			expAccount = accServiceExp
			prefix = "Beban Jasa (Hutang): "
		}
		entries = append(entries, rawEntry{AccountCode: expAccount, Date: date, Description: prefix + desc, Debit: amount})
		entries = append(entries, rawEntry{AccountCode: accPayable, Date: date, Description: prefix + desc, Credit: amount})
	}
	if err := apRows.Err(); err != nil {
		return nil, err
	}
	}

	// 5) Piutang Usaha — from cloud_orders (unpaid)
	if needQ(accReceivable, accRevenue) {
	unpArgs := []interface{}{dateFrom, dateTo}
	unpFilter := ""
	if filterIDs != nil {
		unpFilter = " AND o.outlet_id = ANY($3::text[])"
		unpArgs = append(unpArgs, pq.Array(filterIDs))
	}
	unpQuery := `
		SELECT
			TO_CHAR(tz_date(o.created_at), 'YYYY-MM-DD') AS date,
			COALESCE(ot.name, o.outlet_code) || ' - ' || COALESCE(o.customer_name, 'Pelanggan') AS description,
			o.total_amount
		FROM cloud_orders o
		LEFT JOIN outlets ot ON ot.id = o.outlet_id
		WHERE COALESCE(o.payment_info->>'payment_status','unpaid') NOT IN ('paid')
		  AND NULLIF(o.payment_info->>'voided_at','') IS NULL
		  AND tz_date(o.created_at) >= $1::date AND tz_date(o.created_at) <= $2::date` + unpFilter + `
		ORDER BY o.created_at`

	unpRows, err := database.DB.Query(unpQuery, unpArgs...)
	if err != nil {
		return nil, fmt.Errorf("general ledger: receivables query failed: %w", err)
	}
	defer unpRows.Close()

	for unpRows.Next() {
		var date, desc string
		var amount float64
		if err := unpRows.Scan(&date, &desc, &amount); err != nil {
			return nil, fmt.Errorf("general ledger: receivables scan failed: %w", err)
		}
		entries = append(entries, rawEntry{AccountCode: accReceivable, Date: date, Description: "Piutang: " + desc, Debit: amount})
		entries = append(entries, rawEntry{AccountCode: accRevenue, Date: date, Description: "Piutang: " + desc, Credit: amount})
	}
	if err := unpRows.Err(); err != nil {
		return nil, err
	}
	}

	// 6) Pajak Restoran (PB1) — jurnal estimasi dari total penjualan harian
	if needQ(accTaxExpense, accTaxPayable) {
	taxQuery := `
		SELECT TO_CHAR(tz_date(created_at), 'YYYY-MM-DD') AS date, SUM(total_amount)
		FROM cloud_transactions
		WHERE tz_date(created_at) >= $1::date AND tz_date(created_at) <= $2::date` + outletFilter + `
		GROUP BY tz_date(created_at)
		ORDER BY tz_date(created_at)`

	taxRows, err := database.DB.Query(taxQuery, args...)
	if err != nil {
		return nil, fmt.Errorf("general ledger: tax query failed: %w", err)
	}
	defer taxRows.Close()

	for taxRows.Next() {
		var date string
		var dayRevenue float64
		if err := taxRows.Scan(&date, &dayRevenue); err != nil {
			return nil, fmt.Errorf("general ledger: tax scan failed: %w", err)
		}
		taxAmt := round2(dayRevenue * taxRate)
		if taxAmt > 0 {
			entries = append(entries, rawEntry{AccountCode: accTaxExpense, Date: date, Description: "Estimasi PB1 10%", Debit: taxAmt})
			entries = append(entries, rawEntry{AccountCode: accTaxPayable, Date: date, Description: "Estimasi PB1 10%", Credit: taxAmt})
		}
	}
	if err := taxRows.Err(); err != nil {
		return nil, err
	}
	}

	// ── Build accounts from entries ──
	type accountMeta struct {
		Code  string
		Name  string
		Group string
	}
	accountList := []accountMeta{
		{accCash, "Kas & Setara Kas", "aset"},
		{accReceivable, "Piutang Usaha", "aset"},
		{accPayable, "Hutang Usaha", "kewajiban"},
		{accTaxPayable, "Hutang Pajak Restoran", "kewajiban"},
		{accRevenue, "Pendapatan Penjualan", "pendapatan"},
		{accOtherIncome, "Pendapatan Lainnya", "pendapatan"},
		{accCOGS, "HPP - Bahan Baku", "beban"},
		{accServiceExp, "Beban Jasa & Layanan", "beban"},
		{accOpex, "Beban Operasional", "beban"},
		{accTaxExpense, "Beban Pajak Restoran", "beban"},
	}

	// Collect entries per account
	accountEntries := make(map[string][]rawEntry)
	for _, e := range entries {
		accountEntries[e.AccountCode] = append(accountEntries[e.AccountCode], e)
	}

	accounts := make([]models.GeneralLedgerAccount, 0)
	balanceOf := make(map[string]float64)

	for _, meta := range accountList {
		if accountFilter != "" && accountFilter != meta.Code {
			continue
		}
		raw := accountEntries[meta.Code]

		var acctDebit, acctCredit float64
		var balance float64
		ledgerEntries := make([]models.GeneralLedgerEntry, 0, len(raw))

		// Sort entries by date for running balance
		sort.Slice(raw, func(i, j int) bool {
			return raw[i].Date < raw[j].Date
		})

		for _, e := range raw {
			acctDebit += e.Debit
			acctCredit += e.Credit
			if meta.Group == "aset" || meta.Group == "beban" {
				balance += e.Debit - e.Credit
			} else {
				balance += e.Credit - e.Debit
			}
			ledgerEntries = append(ledgerEntries, models.GeneralLedgerEntry{
				Date:        e.Date,
				Description: e.Description,
				Debit:       round2(e.Debit),
				Credit:      round2(e.Credit),
				Balance:     round2(balance),
			})
		}

		accounts = append(accounts, models.GeneralLedgerAccount{
			Code:        meta.Code,
			Name:        meta.Name,
			Group:       meta.Group,
			TotalDebit:  round2(acctDebit),
			TotalCredit: round2(acctCredit),
			Balance:     round2(balance),
			Entries:     ledgerEntries,
		})

		balanceOf[meta.Code] = round2(balance)
	}

	return &models.GeneralLedgerResponse{
		DateFrom: dateFrom,
		DateTo:   dateTo,
		Summary: models.GeneralLedgerSummary{
			CashBalance:  balanceOf[accCash],
			TotalRevenue: round2(balanceOf[accRevenue] + balanceOf[accOtherIncome]),
			TotalExpense: round2(balanceOf[accCOGS] + balanceOf[accServiceExp] + balanceOf[accOpex] + balanceOf[accTaxExpense]),
		},
		Accounts: accounts,
	}, nil
}

func GetVoidReport(dateFrom, dateTo, outletID string, scopeIDs []string, page, limit int) (*models.VoidReport, error) {
	offset := (page - 1) * limit

	// Order dianggap void hanya jika voided_at ada DAN bukan empty string.
	// NULLIF mencegah error cast "" → timestamptz.
	conds := []string{"NULLIF(o.payment_info->>'voided_at','') IS NOT NULL"}
	args := []interface{}{}
	idx := 1

	if outletID != "" {
		conds = append(conds, fmt.Sprintf("o.outlet_id = $%d", idx))
		args = append(args, outletID)
		idx++
	} else if scopeIDs != nil {
		conds = append(conds, fmt.Sprintf("o.outlet_id = ANY($%d::text[])", idx))
		args = append(args, pq.Array(scopeIDs))
		idx++
	}

	if dateFrom != "" {
		conds = append(conds, fmt.Sprintf("NULLIF(o.payment_info->>'voided_at','')::timestamptz >= $%d::timestamptz", idx))
		args = append(args, dateFrom+" 00:00:00")
		idx++
	}
	if dateTo != "" {
		conds = append(conds, fmt.Sprintf("NULLIF(o.payment_info->>'voided_at','')::timestamptz <= $%d::timestamptz", idx))
		args = append(args, dateTo+" 23:59:59")
		idx++
	}

	where := "WHERE " + strings.Join(conds, " AND ")

	var total int
	var totalAmount float64
	err := database.DB.QueryRow(fmt.Sprintf(
		`SELECT COUNT(*), COALESCE(SUM(o.total_amount),0)
		FROM cloud_orders o %s`, where,
	), args...).Scan(&total, &totalAmount)
	if err != nil {
		return nil, err
	}

	dataArgs := append(append([]interface{}{}, args...), limit, offset)
	rows, err := database.DB.Query(fmt.Sprintf(
		`SELECT o.id,
			COALESCE(out.name,''),
			COALESCE(o.table_number,''),
			COALESCE(o.customer_name,''),
			o.total_amount,
			COALESCE(o.items::text,'[]'),
			COALESCE(o.payment_info->>'voided_at',''),
			COALESCE(o.payment_info->>'voided_by',''),
			COALESCE(o.payment_info->>'void_reason',''),
			o.created_at::text
		FROM cloud_orders o
		LEFT JOIN outlets out ON out.id = o.outlet_id
		%s
		ORDER BY (o.payment_info->>'voided_at') DESC
		LIMIT $%d OFFSET $%d`, where, idx, idx+1,
	), dataArgs...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	data := make([]models.VoidOrderRow, 0)
	for rows.Next() {
		var r models.VoidOrderRow
		if err := rows.Scan(&r.ID, &r.OutletName, &r.TableNumber, &r.CustomerName,
			&r.TotalAmount, &r.Items, &r.VoidedAt, &r.VoidedBy, &r.VoidReason, &r.CreatedAt); err != nil {
			return nil, err
		}
		data = append(data, r)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	return &models.VoidReport{
		Summary: models.VoidReportSummary{TotalVoided: total, TotalAmount: totalAmount},
		Data:    data,
		Total:   total,
		Page:    page,
		Limit:   limit,
	}, nil
}
