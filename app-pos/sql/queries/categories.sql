-- name: CreateCategory :one
INSERT INTO categories (id, name, description, printer_id, is_deleted, created_at, updated_at)
VALUES (?, ?, ?, ?, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
RETURNING *;

-- name: GetCategory :one
SELECT 
    c.*,
    p.name as printer_name,
    p.printer_type as printer_type
FROM categories c
LEFT JOIN printers p ON c.printer_id = p.id
WHERE c.id = ? AND c.is_deleted = 0 LIMIT 1;

-- name: ListCategories :many
SELECT 
    c.*,
    p.name as printer_name,
    p.printer_type as printer_type,
    COUNT(DISTINCT pr.id) as product_count
FROM categories c
LEFT JOIN printers p ON c.printer_id = p.id
LEFT JOIN products pr ON c.id = pr.category_id AND pr.is_deleted = 0
WHERE c.is_deleted = 0
GROUP BY c.id, c.name, c.description, c.printer_id, c.is_deleted, c.created_at, c.updated_at, p.name, p.printer_type
ORDER BY c.id;

-- name: UpdateCategory :exec
UPDATE categories
SET name = ?, description = ?, printer_id = ?, updated_at = CURRENT_TIMESTAMP
WHERE id = ?;

-- name: DeleteCategory :exec
DELETE FROM categories
WHERE id = ?;

-- name: SoftDeleteCategory :exec
UPDATE categories SET is_deleted = 1, updated_at = CURRENT_TIMESTAMP WHERE id = ?;

-- name: ListCategoriesPaginated :many
SELECT 
    c.*,
    p.name as printer_name,
    p.printer_type as printer_type
FROM categories c
LEFT JOIN printers p ON c.printer_id = p.id
WHERE c.is_deleted = 0
ORDER BY c.id
LIMIT ? OFFSET ?;

-- name: CountCategories :one
SELECT COUNT(*) FROM categories WHERE is_deleted = 0;
