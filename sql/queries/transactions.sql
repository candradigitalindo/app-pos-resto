-- name: CreateTransaction :one
INSERT INTO transactions (id, order_id, total_amount, payment_method, status, transaction_date, created_by, created_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
RETURNING *;

-- name: GetTransaction :one
SELECT * FROM transactions
WHERE id = ? LIMIT 1;

-- name: ListTransactions :many
SELECT * FROM transactions
ORDER BY transaction_date DESC;

-- name: ListTransactionsPaginated :many
SELECT * FROM transactions
ORDER BY transaction_date DESC
LIMIT ? OFFSET ?;

-- name: CountTransactions :one
SELECT COUNT(*) FROM transactions;

-- name: ListTransactionsByDateRange :many
SELECT * FROM transactions
WHERE transaction_date BETWEEN ? AND ?
ORDER BY transaction_date DESC;

-- name: CancelTransaction :one
UPDATE transactions
SET status = ?, cancelled_at = ?, cancelled_by = ?, cancel_reason = ?, updated_at = ?
WHERE id = ?
RETURNING *;

-- name: CreateTransactionItem :one
INSERT INTO transaction_items (id, transaction_id, product_id, quantity, price)
VALUES (?, ?, ?, ?, ?)
RETURNING *;

-- name: ListTransactionItems :many
SELECT ti.*, p.name as product_name
FROM transaction_items ti
LEFT JOIN products p ON ti.product_id = p.id
WHERE ti.transaction_id = ?;
