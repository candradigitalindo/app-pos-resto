-- name: CreatePrinter :one
INSERT INTO printers (
    id, name, ip_address, port, printer_type, paper_size, is_active,
    connection_timeout, write_timeout, retry_attempts,
    print_density, print_speed, cut_mode,
    enable_beep, auto_cut, charset,
    created_at, updated_at
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
RETURNING *;

-- name: GetPrinter :one
SELECT * FROM printers
WHERE id = ?;

-- name: ListPrinters :many
SELECT * FROM printers
ORDER BY printer_type, name;

-- name: ListActivePrinters :many
SELECT * FROM printers
WHERE is_active = 1
ORDER BY printer_type, name;

-- name: ListPrintersByType :many
SELECT * FROM printers
WHERE printer_type = ? AND is_active = 1
ORDER BY name;

-- name: UpdatePrinter :exec
UPDATE printers
SET name = ?, ip_address = ?, port = ?, printer_type = ?, paper_size = ?, is_active = ?,
    connection_timeout = ?, write_timeout = ?, retry_attempts = ?,
    print_density = ?, print_speed = ?, cut_mode = ?,
    enable_beep = ?, auto_cut = ?, charset = ?,
    updated_at = CURRENT_TIMESTAMP
WHERE id = ?;

-- name: DeletePrinter :exec
DELETE FROM printers
WHERE id = ?;

-- name: TogglePrinterActive :exec
UPDATE printers
SET is_active = ?, updated_at = CURRENT_TIMESTAMP
WHERE id = ?;

-- name: CountPrinters :one
SELECT COUNT(*) FROM printers;
