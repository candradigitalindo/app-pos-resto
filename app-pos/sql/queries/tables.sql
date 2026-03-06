-- name: CreateTable :one
INSERT INTO tables (id, table_number, capacity, status)
VALUES (?, ?, ?, 'available')
RETURNING *;

-- name: GetAllTables :many
SELECT * FROM tables
ORDER BY table_number;

-- name: GetTableByID :one
SELECT * FROM tables
WHERE id = ? LIMIT 1;

-- name: GetTableByNumber :one
SELECT * FROM tables
WHERE table_number = ? LIMIT 1;

-- name: GetTablesByStatus :many
SELECT * FROM tables
WHERE status = ?
ORDER BY table_number;

-- name: UpdateTable :exec
UPDATE tables
SET table_number = ?, capacity = ?, updated_at = CURRENT_TIMESTAMP
WHERE id = ?;

-- name: UpdateTableStatus :exec
UPDATE tables
SET status = ?, updated_at = CURRENT_TIMESTAMP
WHERE table_number = ?;

-- name: DeleteTable :exec
DELETE FROM tables
WHERE id = ?;

-- name: ListTablesPaginated :many
SELECT * FROM tables
ORDER BY id
LIMIT ? OFFSET ?;

-- name: CountTables :one
SELECT COUNT(*) FROM tables;

-- name: GetAvailableTables :many
SELECT * FROM tables
WHERE status = 'available'
ORDER BY table_number;

-- name: GetOccupiedTables :many
SELECT * FROM tables
WHERE status = 'occupied'
ORDER BY table_number;
