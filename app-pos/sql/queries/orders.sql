-- name: CreateOrder :one
INSERT INTO orders (id, table_number, customer_name, customer_phone, customer_id, pax, basket_size, total_amount, order_status, created_by, payment_status)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'cooking', ?, 'unpaid')
RETURNING id;

-- name: CreateOrderItem :one
INSERT INTO order_items (id, order_id, product_name, qty, price, destination, item_status)
VALUES (?, ?, ?, ?, ?, ?, 'pending')
RETURNING *;

-- name: GetOrdersByTable :many
SELECT id, table_number, customer_name, customer_phone, customer_id, pax, basket_size, total_amount, paid_amount, order_status, created_by, payment_status, merged_from, is_merged, created_at, updated_at FROM orders
WHERE table_number = ?
AND voided_at IS NULL
ORDER BY created_at DESC;

-- name: GetOrderWithItems :one
SELECT id, table_number, customer_name, customer_phone, customer_id, pax, basket_size, total_amount, paid_amount, order_status, created_by, payment_status, merged_from, is_merged, created_at, updated_at FROM orders
WHERE id = ? LIMIT 1;

-- name: GetOrderItems :many
SELECT * FROM order_items
WHERE order_id = ?
ORDER BY created_at;

-- name: UpdateOrderStatus :exec
UPDATE orders
SET order_status = ?, updated_at = CURRENT_TIMESTAMP
WHERE id = ?;

-- name: UpdatePaymentStatus :exec
UPDATE orders
SET payment_status = 'paid', updated_at = CURRENT_TIMESTAMP
WHERE id = ?;

-- name: UpdateOrderItemStatus :exec
UPDATE order_items
SET item_status = ?, updated_at = CURRENT_TIMESTAMP
WHERE id = ?;

-- name: GetPendingOrders :many
SELECT id, table_number, customer_name, customer_phone, customer_id, pax, basket_size, total_amount, paid_amount, order_status, created_by, payment_status, merged_from, is_merged, created_at, updated_at FROM orders
WHERE order_status IN ('cooking', 'ready')
AND voided_at IS NULL
ORDER BY created_at ASC;

-- name: GetOrderAnalytics :one
SELECT 
    COUNT(*) as total_orders,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_order_value,
    AVG(basket_size) as avg_basket_size,
    AVG(pax) as avg_pax,
    SUM(pax) as total_pax
FROM orders
WHERE created_at BETWEEN ? AND ?
AND payment_status = 'paid';

-- name: ListOrdersByCustomer :many
SELECT id, table_number, customer_name, customer_phone, customer_id, pax, basket_size, total_amount, paid_amount, order_status, created_by, payment_status, merged_from, is_merged, created_at, updated_at
FROM orders
WHERE customer_id = sqlc.arg(customer_id)
AND created_at BETWEEN sqlc.arg(start_date) AND sqlc.arg(end_date)
ORDER BY created_at DESC;

-- name: CreatePrintJob :one
INSERT INTO print_queue (id, printer_id, data, status)
VALUES (?, ?, ?, 'pending')
RETURNING *;

-- name: GetPendingPrintJobs :many
SELECT *
FROM print_queue
WHERE status = 'pending'
ORDER BY created_at ASC, id ASC;

-- name: UpdatePrintJobStatus :exec
UPDATE print_queue
SET status = ?, retry_count = ?
WHERE id = ?;

-- name: CreatePayment :one
INSERT INTO payments (id, order_id, amount, payment_method, payment_note, created_by)
VALUES (?, ?, ?, ?, ?, ?)
RETURNING *;

-- name: GetPaymentsByOrder :many
SELECT * FROM payments
WHERE order_id = ?
ORDER BY created_at;

-- name: GetOrderTotalPaid :one
SELECT COALESCE(SUM(amount), 0) as total_paid
FROM payments
WHERE order_id = ?;

-- name: UpdateOrderPaidAmount :exec
UPDATE orders
SET paid_amount = ?, payment_status = ?, updated_at = CURRENT_TIMESTAMP
WHERE id = ?;

-- name: UpdateOrderTotals :exec
UPDATE orders
SET total_amount = total_amount + ?, basket_size = basket_size + ?, updated_at = CURRENT_TIMESTAMP
WHERE id = ?;

-- name: MergeOrders :exec
UPDATE orders
SET is_merged = 1, merged_from = ?, updated_at = CURRENT_TIMESTAMP
WHERE id = ?;

-- name: GetMergedOrders :many
SELECT * FROM orders
WHERE merged_from = ?;

-- name: TransferOrderItems :exec
UPDATE order_items
SET order_id = ?, updated_at = CURRENT_TIMESTAMP
WHERE order_id = ?;

-- name: GetRevenueByPaymentStatus :one
SELECT 
    COALESCE(SUM(CASE WHEN payment_status = 'paid' THEN total_amount ELSE 0 END), 0) as paid_revenue,
    COALESCE(SUM(CASE WHEN payment_status = 'unpaid' THEN total_amount ELSE 0 END), 0) as unpaid_revenue
FROM orders
WHERE created_at BETWEEN ? AND ?;

-- name: GetProductsSold :one
SELECT 
    COALESCE(SUM(oi.qty), 0) as total_qty
FROM order_items oi
INNER JOIN orders o ON oi.order_id = o.id
WHERE o.created_at BETWEEN ? AND ?;

-- name: GetRevenueByHour :many
SELECT 
    strftime('%H', created_at) as hour,
    COALESCE(SUM(total_amount), 0) as revenue
FROM orders
WHERE DATE(created_at) = ?
GROUP BY strftime('%H', created_at)
ORDER BY hour;

-- name: GetRevenueByDay :many
SELECT 
    DATE(created_at) as day,
    COALESCE(SUM(total_amount), 0) as revenue
FROM orders
WHERE created_at BETWEEN ? AND ?
GROUP BY DATE(created_at)
ORDER BY day;
