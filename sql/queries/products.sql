-- name: CreateProduct :one
INSERT INTO products (id, name, code, description, price, stock, category_id, created_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
RETURNING *;

-- name: GetProduct :one
SELECT id, name, code, description, price, stock, category_id, created_at, updated_at FROM products
WHERE id = ? LIMIT 1;

-- name: ListProducts :many
SELECT id, name, code, description, price, stock, category_id, created_at, updated_at FROM products
ORDER BY id;

-- name: UpdateProduct :exec
UPDATE products
SET name = ?, code = ?, description = ?, price = ?, stock = ?, category_id = ?, updated_at = CURRENT_TIMESTAMP
WHERE id = ?;

-- name: DeleteProduct :exec
DELETE FROM products
WHERE id = ?;

-- name: ListProductsByCategory :many
SELECT id, name, code, description, price, stock, category_id, created_at, updated_at FROM products
WHERE category_id = ?
ORDER BY id;

-- name: ListProductsPaginated :many
SELECT id, name, code, description, price, stock, category_id, created_at, updated_at FROM products
ORDER BY id
LIMIT ? OFFSET ?;

-- name: CountProducts :one
SELECT COUNT(*) FROM products;

-- name: SearchProductsPaginated :many
SELECT id, name, code, description, price, stock, category_id, created_at, updated_at FROM products
WHERE (COALESCE(?, '') = '' OR name LIKE '%' || ? || '%' OR code LIKE '%' || ? || '%')
  AND (COALESCE(?, '') = '' OR category_id = ?)
ORDER BY id
LIMIT ? OFFSET ?;

-- name: CountSearchProducts :one
SELECT COUNT(*) FROM products
WHERE (COALESCE(?, '') = '' OR name LIKE '%' || ? || '%' OR code LIKE '%' || ? || '%')
  AND (COALESCE(?, '') = '' OR category_id = ?);

-- name: GetProductByCode :one
SELECT * FROM products
WHERE code = ? LIMIT 1;

-- name: CheckCodeExists :one
SELECT COUNT(*) FROM products
WHERE code = ? AND id != ?;
