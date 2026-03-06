CREATE TABLE IF NOT EXISTS order_additional_charges (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    order_id TEXT NOT NULL,
    charge_id INTEGER,
    name TEXT NOT NULL,
    charge_type TEXT NOT NULL CHECK (charge_type IN ('percentage', 'fixed')),
    value REAL NOT NULL,
    applied_amount REAL NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_order_additional_charges_order_id ON order_additional_charges(order_id);
