-- ============================================
-- SYNC SYSTEM SCHEMA
-- Untuk sinkronisasi data dengan cloud
-- ============================================

-- Tabel konfigurasi outlet
CREATE TABLE IF NOT EXISTS outlet_config (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    outlet_id TEXT NOT NULL UNIQUE,           -- UUID outlet dari cloud
    outlet_name TEXT NOT NULL,
    outlet_code TEXT NOT NULL UNIQUE,         -- Kode outlet (misal: "JKT-001")
    outlet_address TEXT DEFAULT '',
    outlet_phone TEXT DEFAULT '',
    receipt_footer TEXT DEFAULT 'Terima kasih atas kunjungan Anda!',
    social_media TEXT DEFAULT '',
    target_spend_per_pax INTEGER DEFAULT 0,
    cloud_api_url TEXT NOT NULL,              -- URL API cloud
    cloud_api_key TEXT NOT NULL,              -- API key untuk autentikasi
    is_active BOOLEAN DEFAULT TRUE,
    sync_enabled BOOLEAN DEFAULT TRUE,
    sync_interval_minutes INTEGER DEFAULT 5,  -- Interval sync otomatis
    last_sync_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS additional_charges (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    outlet_id TEXT DEFAULT '',
    name TEXT NOT NULL,
    charge_type TEXT NOT NULL CHECK (charge_type IN ('percentage', 'fixed')),
    value REAL NOT NULL,
    is_active INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_additional_charges_active ON additional_charges(is_active);

-- Tabel antrian sinkronisasi
CREATE TABLE IF NOT EXISTS sync_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type TEXT NOT NULL,                -- 'order', 'transaction', 'product', dll
    entity_id TEXT NOT NULL,                  -- ID dari entity
    operation TEXT NOT NULL,                  -- 'create', 'update', 'delete'
    payload TEXT NOT NULL,                    -- JSON data yang akan di-sync
    status TEXT DEFAULT 'pending',            -- 'pending', 'processing', 'success', 'failed'
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP,
    synced_at TIMESTAMP
);

CREATE INDEX idx_sync_queue_status ON sync_queue(status);
CREATE INDEX idx_sync_queue_entity ON sync_queue(entity_type, entity_id);

-- Tabel log sinkronisasi
CREATE TABLE IF NOT EXISTS sync_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sync_type TEXT NOT NULL,                  -- 'push', 'pull'
    entity_type TEXT NOT NULL,
    entity_count INTEGER DEFAULT 0,
    status TEXT NOT NULL,                     -- 'success', 'partial', 'failed'
    error_message TEXT,
    started_at TIMESTAMP NOT NULL,
    completed_at TIMESTAMP,
    duration_ms INTEGER,
    details TEXT                              -- JSON detail log
);

-- Tabel untuk tracking versi data (conflict resolution)
CREATE TABLE IF NOT EXISTS entity_versions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    version INTEGER DEFAULT 1,
    cloud_version INTEGER DEFAULT 0,
    last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_synced_at TIMESTAMP,
    sync_status TEXT DEFAULT 'pending',       -- 'pending', 'synced', 'conflict'
    UNIQUE(entity_type, entity_id)
);

CREATE INDEX idx_entity_versions_sync ON entity_versions(sync_status);

-- ============================================
-- ALTER EXISTING TABLES
-- Tambahkan kolom untuk sync tracking
-- ============================================

-- Products
ALTER TABLE products ADD COLUMN cloud_id TEXT;                    -- ID di cloud
ALTER TABLE products ADD COLUMN version INTEGER DEFAULT 1;
ALTER TABLE products ADD COLUMN sync_status TEXT DEFAULT 'pending';
ALTER TABLE products ADD COLUMN last_synced_at TIMESTAMP;

-- Categories  
ALTER TABLE categories ADD COLUMN cloud_id TEXT;
ALTER TABLE categories ADD COLUMN version INTEGER DEFAULT 1;
ALTER TABLE categories ADD COLUMN sync_status TEXT DEFAULT 'pending';
ALTER TABLE categories ADD COLUMN last_synced_at TIMESTAMP;

-- Tables
ALTER TABLE tables ADD COLUMN cloud_id TEXT;
ALTER TABLE tables ADD COLUMN version INTEGER DEFAULT 1;
ALTER TABLE tables ADD COLUMN sync_status TEXT DEFAULT 'pending';
ALTER TABLE tables ADD COLUMN last_synced_at TIMESTAMP;

-- Orders
ALTER TABLE orders ADD COLUMN cloud_id TEXT;
ALTER TABLE orders ADD COLUMN version INTEGER DEFAULT 1;
ALTER TABLE orders ADD COLUMN sync_status TEXT DEFAULT 'pending';
ALTER TABLE orders ADD COLUMN last_synced_at TIMESTAMP;

-- Transactions
ALTER TABLE transactions ADD COLUMN cloud_id TEXT;
ALTER TABLE transactions ADD COLUMN version INTEGER DEFAULT 1;
ALTER TABLE transactions ADD COLUMN sync_status TEXT DEFAULT 'pending';
ALTER TABLE transactions ADD COLUMN last_synced_at TIMESTAMP;

-- Users
ALTER TABLE users ADD COLUMN cloud_id TEXT;
ALTER TABLE users ADD COLUMN version INTEGER DEFAULT 1;
ALTER TABLE users ADD COLUMN sync_status TEXT DEFAULT 'pending';
ALTER TABLE users ADD COLUMN last_synced_at TIMESTAMP;

-- ============================================
-- INDEXES untuk performance
-- ============================================

CREATE INDEX idx_products_sync ON products(sync_status, last_synced_at);
CREATE INDEX idx_categories_sync ON categories(sync_status, last_synced_at);
CREATE INDEX idx_tables_sync ON tables(sync_status, last_synced_at);
CREATE INDEX idx_orders_sync ON orders(sync_status, last_synced_at);
CREATE INDEX idx_transactions_sync ON transactions(sync_status, last_synced_at);
CREATE INDEX idx_users_sync ON users(sync_status, last_synced_at);

-- ============================================
-- TRIGGERS untuk auto-update sync_status
-- ============================================

-- Product triggers
CREATE TRIGGER IF NOT EXISTS products_mark_dirty_update
AFTER UPDATE ON products
WHEN NEW.updated_at != OLD.updated_at
BEGIN
    UPDATE products 
    SET 
        sync_status = 'pending',
        version = version + 1
    WHERE id = NEW.id;
    
    -- Tambahkan ke sync queue
    INSERT INTO sync_queue (entity_type, entity_id, operation, payload)
    VALUES (
        'product',
        NEW.id,
        'update',
        json_object(
            'id', NEW.id,
            'name', NEW.name,
            'category_id', NEW.category_id,
            'price', NEW.price,
            'stock', NEW.stock,
            'destination', NEW.destination
        )
    );
END;

CREATE TRIGGER IF NOT EXISTS products_mark_dirty_insert
AFTER INSERT ON products
BEGIN
    UPDATE products 
    SET sync_status = 'pending'
    WHERE id = NEW.id;
    
    INSERT INTO sync_queue (entity_type, entity_id, operation, payload)
    VALUES (
        'product',
        NEW.id,
        'create',
        json_object(
            'id', NEW.id,
            'name', NEW.name,
            'category_id', NEW.category_id,
            'price', NEW.price,
            'stock', NEW.stock,
            'destination', NEW.destination
        )
    );
END;

-- Order triggers
CREATE TRIGGER IF NOT EXISTS orders_mark_dirty_insert
AFTER INSERT ON orders
BEGIN
    UPDATE orders 
    SET sync_status = 'pending'
    WHERE id = NEW.id;

    INSERT INTO sync_queue (entity_type, entity_id, operation, payload)
    VALUES (
        'order',
        NEW.id,
        'create',
        json_object(
            'id', NEW.id,
            'order_id', NEW.id,
            'table_number', NEW.table_number,
            'total_amount', NEW.total_amount,
            'paid_amount', NEW.paid_amount,
            'pax', NEW.pax,
            'basket_size', NEW.basket_size,
            'order_status', NEW.order_status,
            'payment_status', NEW.payment_status,
            'created_by', NEW.created_by
        )
    );
END;

CREATE TRIGGER IF NOT EXISTS orders_mark_dirty_update
AFTER UPDATE ON orders
WHEN NEW.updated_at != OLD.updated_at
BEGIN
    UPDATE orders 
    SET 
        sync_status = 'pending',
        version = version + 1
    WHERE id = NEW.id;

    INSERT INTO sync_queue (entity_type, entity_id, operation, payload)
    VALUES (
        'order',
        NEW.id,
        'update',
        json_object(
            'id', NEW.id,
            'order_id', NEW.id,
            'table_number', NEW.table_number,
            'total_amount', NEW.total_amount,
            'paid_amount', NEW.paid_amount,
            'pax', NEW.pax,
            'basket_size', NEW.basket_size,
            'order_status', NEW.order_status,
            'payment_status', NEW.payment_status,
            'created_by', NEW.created_by,
            'voided_at', NEW.voided_at,
            'voided_by', NEW.voided_by,
            'void_reason', NEW.void_reason
        )
    );
END;

-- Transaction triggers
CREATE TRIGGER IF NOT EXISTS transactions_mark_dirty_insert
AFTER INSERT ON transactions
BEGIN
    UPDATE transactions 
    SET sync_status = 'pending'
    WHERE id = NEW.id;

    INSERT INTO sync_queue (entity_type, entity_id, operation, payload)
    VALUES (
        'transaction',
        NEW.id,
        'create',
        json_object(
            'id', NEW.id,
            'order_id', NEW.order_id,
            'total_amount', NEW.total_amount,
            'payment_method', NEW.payment_method,
            'transaction_date', NEW.transaction_date,
            'created_by', NEW.created_by,
            'cancelled_at', NEW.cancelled_at,
            'cancelled_by', NEW.cancelled_by,
            'cancel_reason', NEW.cancel_reason
        )
    );
END;

CREATE TRIGGER IF NOT EXISTS transactions_mark_dirty_update
AFTER UPDATE ON transactions
WHEN NEW.updated_at != OLD.updated_at
BEGIN
    UPDATE transactions 
    SET 
        sync_status = 'pending',
        version = version + 1
    WHERE id = NEW.id;

    INSERT INTO sync_queue (entity_type, entity_id, operation, payload)
    VALUES (
        'transaction',
        NEW.id,
        'update',
        json_object(
            'id', NEW.id,
            'order_id', NEW.order_id,
            'total_amount', NEW.total_amount,
            'payment_method', NEW.payment_method,
            'transaction_date', NEW.transaction_date,
            'created_by', NEW.created_by,
            'cancelled_at', NEW.cancelled_at,
            'cancelled_by', NEW.cancelled_by,
            'cancel_reason', NEW.cancel_reason
        )
    );
END;

-- Transaction item triggers
CREATE TRIGGER IF NOT EXISTS transaction_items_mark_dirty_insert
AFTER INSERT ON transaction_items
BEGIN
    INSERT INTO sync_queue (entity_type, entity_id, operation, payload)
    VALUES (
        'transaction_item',
        NEW.id,
        'create',
        json_object(
            'id', NEW.id,
            'transaction_id', NEW.transaction_id,
            'product_id', NEW.product_id,
            'quantity', NEW.quantity,
            'price', NEW.price
        )
    );
END;

-- User triggers
CREATE TRIGGER IF NOT EXISTS users_mark_dirty_insert
AFTER INSERT ON users
BEGIN
    UPDATE users 
    SET sync_status = 'pending'
    WHERE id = NEW.id;

    INSERT INTO sync_queue (entity_type, entity_id, operation, payload)
    VALUES (
        'user',
        NEW.id,
        'create',
        json_object(
            'id', NEW.id,
            'username', NEW.username,
            'full_name', NEW.full_name,
            'role', NEW.role,
            'is_active', NEW.is_active
        )
    );
END;

CREATE TRIGGER IF NOT EXISTS users_mark_dirty_update
AFTER UPDATE ON users
WHEN NEW.updated_at != OLD.updated_at
BEGIN
    UPDATE users 
    SET 
        sync_status = 'pending',
        version = version + 1
    WHERE id = NEW.id;

    INSERT INTO sync_queue (entity_type, entity_id, operation, payload)
    VALUES (
        'user',
        NEW.id,
        'update',
        json_object(
            'id', NEW.id,
            'username', NEW.username,
            'full_name', NEW.full_name,
            'role', NEW.role,
            'is_active', NEW.is_active
        )
    );
END;

-- Cashier shift triggers
CREATE TRIGGER IF NOT EXISTS cashier_shifts_mark_dirty_insert
AFTER INSERT ON cashier_shifts
BEGIN
    INSERT INTO sync_queue (entity_type, entity_id, operation, payload)
    VALUES (
        'cashier_shift',
        NEW.id,
        'create',
        json_object(
            'id', NEW.id,
            'opened_by', NEW.opened_by,
            'opened_at', NEW.opened_at,
            'opening_cash', NEW.opening_cash,
            'closed_at', NEW.closed_at,
            'closed_by', NEW.closed_by,
            'closing_cash', NEW.closing_cash,
            'closing_card', NEW.closing_card,
            'closing_qris', NEW.closing_qris,
            'carry_over_cash', NEW.carry_over_cash,
            'previous_shift_id', NEW.previous_shift_id,
            'handover_to', NEW.handover_to,
            'status', NEW.status,
            'notes', NEW.notes
        )
    );
END;

CREATE TRIGGER IF NOT EXISTS cashier_shifts_mark_dirty_update
AFTER UPDATE ON cashier_shifts
WHEN NEW.updated_at != OLD.updated_at
BEGIN
    INSERT INTO sync_queue (entity_type, entity_id, operation, payload)
    VALUES (
        'cashier_shift',
        NEW.id,
        'update',
        json_object(
            'id', NEW.id,
            'opened_by', NEW.opened_by,
            'opened_at', NEW.opened_at,
            'opening_cash', NEW.opening_cash,
            'closed_at', NEW.closed_at,
            'closed_by', NEW.closed_by,
            'closing_cash', NEW.closing_cash,
            'closing_card', NEW.closing_card,
            'closing_qris', NEW.closing_qris,
            'carry_over_cash', NEW.carry_over_cash,
            'previous_shift_id', NEW.previous_shift_id,
            'handover_to', NEW.handover_to,
            'status', NEW.status,
            'notes', NEW.notes
        )
    );
END;

-- Cash movement triggers
CREATE TRIGGER IF NOT EXISTS cashier_cash_movements_mark_dirty_insert
AFTER INSERT ON cashier_cash_movements
BEGIN
    INSERT INTO sync_queue (entity_type, entity_id, operation, payload)
    VALUES (
        'cashier_cash_movement',
        NEW.id,
        'create',
        json_object(
            'id', NEW.id,
            'shift_id', NEW.shift_id,
            'movement_type', NEW.movement_type,
            'amount', NEW.amount,
            'counterpart_name', NEW.counterpart_name,
            'note', NEW.note,
            'created_at', NEW.created_at
        )
    );
END;

-- Payment triggers
CREATE TRIGGER IF NOT EXISTS payments_mark_dirty_insert
AFTER INSERT ON payments
BEGIN
    INSERT INTO sync_queue (entity_type, entity_id, operation, payload)
    VALUES (
        'payment',
        NEW.id,
        'create',
        json_object(
            'id', NEW.id,
            'order_id', NEW.order_id,
            'amount', NEW.amount,
            'payment_method', NEW.payment_method,
            'payment_note', NEW.payment_note,
            'created_by', NEW.created_by,
            'created_at', NEW.created_at
        )
    );
END;

-- ============================================
-- INITIAL DATA
-- ============================================

-- No default data - Configuration should be created via API
-- Use: POST /api/v1/config/outlet to create initial configuration
