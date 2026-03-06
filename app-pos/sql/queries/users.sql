-- name: CreateUser :one
INSERT INTO users (id, username, password_hash, full_name, role)
VALUES (?, ?, ?, ?, ?)
RETURNING *;

-- name: GetUserByUsername :one
SELECT * FROM users
WHERE username = ? LIMIT 1;

-- name: GetUserByID :one
SELECT * FROM users
WHERE id = ? LIMIT 1;

-- name: ListUsers :many
SELECT id, username, full_name, role, is_active, created_at, updated_at
FROM users
WHERE is_active = 1
ORDER BY created_at DESC;

-- name: ListUsersPaginated :many
SELECT id, username, full_name, role, is_active, created_at, updated_at
FROM users
WHERE is_active = 1
ORDER BY created_at DESC
LIMIT ? OFFSET ?;

-- name: CountUsers :one
SELECT COUNT(*) FROM users
WHERE is_active = 1;

-- name: UpdateUserPassword :exec
UPDATE users
SET password_hash = ?, updated_at = CURRENT_TIMESTAMP
WHERE id = ?;

-- name: UpdateUserFullName :exec
UPDATE users
SET full_name = ?, updated_at = CURRENT_TIMESTAMP
WHERE id = ?;

-- name: UpdateUserUsername :exec
UPDATE users
SET username = ?, updated_at = CURRENT_TIMESTAMP
WHERE id = ?;

-- name: UpdateUserRole :exec
UPDATE users
SET role = ?, updated_at = CURRENT_TIMESTAMP
WHERE id = ?;

-- name: DeactivateUser :exec
UPDATE users
SET is_active = 0, updated_at = CURRENT_TIMESTAMP
WHERE id = ?;

-- name: ActivateUser :exec
UPDATE users
SET is_active = 1, updated_at = CURRENT_TIMESTAMP
WHERE id = ?;

-- name: ListActiveManagers :many
SELECT id, username, password_hash, full_name, role, is_active, created_at, updated_at
FROM users
WHERE is_active = 1
AND (role = 'manager' OR role = 'admin')
ORDER BY created_at DESC;
