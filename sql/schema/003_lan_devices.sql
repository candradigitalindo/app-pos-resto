-- ============================================
-- LAN DEVICE SYNC SCHEMA
-- For local network device registration
-- ============================================

-- Tabel untuk device yang terdaftar via LAN
CREATE TABLE IF NOT EXISTS registered_devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL UNIQUE,           -- UUID device
    device_name TEXT NOT NULL,                -- Nama device (e.g., "Kasir 1")
    device_type TEXT NOT NULL,                -- 'cashier', 'waiter', 'kitchen', 'bar'
    ip_address TEXT NOT NULL,                 -- IP address device
    mac_address TEXT,                         -- MAC address device
    app_version TEXT,                         -- Versi aplikasi client
    platform TEXT,                            -- 'android', 'ios', 'windows', 'web'
    is_active BOOLEAN DEFAULT TRUE,
    last_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    registered_by TEXT,                       -- User yang register device
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_device_id ON registered_devices(device_id);
CREATE INDEX idx_device_type ON registered_devices(device_type);
CREATE INDEX idx_device_active ON registered_devices(is_active);

-- Tabel untuk pairing tokens (QR code)
CREATE TABLE IF NOT EXISTS pairing_tokens (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    token TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMP NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    used_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_pairing_token ON pairing_tokens(token);
CREATE INDEX idx_pairing_expires ON pairing_tokens(expires_at);
