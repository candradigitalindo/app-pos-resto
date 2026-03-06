-- name: GetActiveOrderByTable :one
-- Get the latest active order for a table (not yet paid)
SELECT id, table_number, customer_name, customer_phone, customer_id, pax, basket_size, total_amount, paid_amount, order_status, created_by, payment_status, merged_from, is_merged, created_at, updated_at FROM orders
WHERE table_number = ?
AND payment_status != 'paid'
AND is_merged = 0
AND voided_at IS NULL
ORDER BY created_at DESC
LIMIT 1;
