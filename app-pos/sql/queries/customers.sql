-- name: CreateCustomer :one
INSERT INTO customers (id, name, phone)
VALUES (?, ?, ?)
RETURNING *;

-- name: GetCustomerByID :one
SELECT * FROM customers
WHERE id = ? LIMIT 1;

-- name: GetCustomerByPhone :one
SELECT * FROM customers
WHERE phone = ? LIMIT 1;

-- name: GetTopCustomers :many
SELECT
    c.id,
    c.name,
    c.phone,
    COUNT(o.id) AS total_orders,
    SUM(o.total_amount) AS total_spent
FROM customers c
JOIN orders o ON o.customer_id = c.id
WHERE o.payment_status = 'paid'
AND o.created_at BETWEEN sqlc.arg(start_date) AND sqlc.arg(end_date)
GROUP BY c.id
ORDER BY total_spent DESC
LIMIT sqlc.arg(limit);
