CREATE TABLE IF NOT EXISTS additional_charges (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    outlet_id TEXT DEFAULT '',
    name TEXT NOT NULL,
    charge_type TEXT NOT NULL CHECK (charge_type IN ('percentage', 'fixed')),
    value REAL NOT NULL,
    is_active INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_additional_charges_active ON additional_charges(is_active);
