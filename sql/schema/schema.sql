PRAGMA foreign_keys = ON;

-- Users table untuk auth
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY CHECK (length(id) = 26),
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('admin', 'waiter', 'kitchen', 'bar', 'cashier', 'manager')),
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS customers (
    id TEXT PRIMARY KEY CHECK (length(id) = 26),
    name TEXT NOT NULL,
    phone TEXT NOT NULL UNIQUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);

-- Tables management
CREATE TABLE IF NOT EXISTS tables (
    id TEXT PRIMARY KEY CHECK (length(id) = 26),
    table_number TEXT NOT NULL UNIQUE,
    capacity INTEGER NOT NULL DEFAULT 4 CHECK (capacity > 0),
    status TEXT NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'occupied', 'reserved')),
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_tables_status ON tables(status);
CREATE INDEX IF NOT EXISTS idx_tables_number ON tables(table_number);

-- ULID primary keys keep inserts fast on SQLite while remaining sortable
CREATE TABLE IF NOT EXISTS orders (
    id TEXT PRIMARY KEY,
    table_number TEXT NOT NULL,
    customer_name TEXT,
    customer_phone TEXT,
    customer_id TEXT,
    pax INTEGER NOT NULL DEFAULT 1 CHECK (pax > 0),
    basket_size INTEGER NOT NULL DEFAULT 0 CHECK (basket_size >= 0),
    total_amount REAL NOT NULL,
    paid_amount REAL NOT NULL DEFAULT 0,
    order_status TEXT NOT NULL DEFAULT 'cooking' CHECK (order_status IN ('cooking', 'ready', 'served')),
    created_by TEXT,
    payment_status TEXT NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'partial', 'paid')),
    merged_from TEXT,
    is_merged INTEGER NOT NULL DEFAULT 0,
    voided_at DATETIME,
    voided_by TEXT,
    void_reason TEXT,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS order_items (
    id TEXT PRIMARY KEY CHECK (length(id) = 26),
    order_id TEXT NOT NULL,
    product_name TEXT NOT NULL,
    qty INTEGER NOT NULL CHECK (qty > 0),
    price REAL NOT NULL CHECK (price >= 0),
    destination TEXT NOT NULL CHECK (destination IN ('kitchen', 'bar')),
    item_status TEXT NOT NULL DEFAULT 'pending' CHECK (item_status IN ('pending', 'cooking', 'ready', 'served')),
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);

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

-- Outbox for eventual printing
-- Print queue for background processing
CREATE TABLE IF NOT EXISTS print_queue (
    id TEXT PRIMARY KEY CHECK (length(id) = 26),
    printer_id TEXT NOT NULL,
    data TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'done', 'failed')),
    retry_count INTEGER NOT NULL DEFAULT 0,
    error_message TEXT,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    locked_at DATETIME,
    locked_by TEXT,
    FOREIGN KEY (printer_id) REFERENCES printers(id)
);

-- Printers configuration table
CREATE TABLE IF NOT EXISTS printers (
    id TEXT PRIMARY KEY CHECK (length(id) = 26),
    name TEXT NOT NULL,
    ip_address TEXT NOT NULL,
    port INTEGER NOT NULL DEFAULT 9100,
    printer_type TEXT NOT NULL CHECK (printer_type IN ('kitchen', 'bar', 'cashier', 'checker', 'struk')),
    paper_size TEXT NOT NULL DEFAULT '80mm' CHECK (paper_size IN ('58mm', '80mm')),
    
    -- Optional Performance Settings
    connection_timeout INTEGER DEFAULT 3,
    write_timeout INTEGER DEFAULT 5,
    retry_attempts INTEGER DEFAULT 2,
    
    -- Optional Print Quality Settings
    print_density INTEGER DEFAULT 50 CHECK (print_density >= 0 AND print_density <= 100),
    print_speed TEXT DEFAULT 'normal' CHECK (print_speed IN ('slow', 'normal', 'fast')),
    cut_mode TEXT DEFAULT 'partial' CHECK (cut_mode IN ('full', 'partial', 'none')),
    
    -- Optional Advanced Settings
    enable_beep INTEGER DEFAULT 1,
    auto_cut INTEGER DEFAULT 1,
    charset TEXT DEFAULT 'latin',
    
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at);
CREATE INDEX IF NOT EXISTS idx_orders_table_number ON orders(table_number);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(order_status, payment_status);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_additional_charges_order_id ON order_additional_charges(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_status ON order_items(item_status);
CREATE INDEX IF NOT EXISTS idx_print_queue_status_created ON print_queue(status, created_at);
CREATE INDEX IF NOT EXISTS idx_printers_type_active ON printers(printer_type, is_active);
CREATE UNIQUE INDEX IF NOT EXISTS idx_printers_ip_type_unique ON printers(ip_address, printer_type);

-- Payments table untuk split bill
CREATE TABLE IF NOT EXISTS payments (
    id TEXT PRIMARY KEY CHECK (length(id) = 26),
    order_id TEXT NOT NULL,
    amount REAL NOT NULL CHECK (amount > 0),
    payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'card', 'qris', 'transfer')),
    payment_note TEXT,
    created_by TEXT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_payments_order_id ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON payments(created_at);

-- Categories table
CREATE TABLE IF NOT EXISTS categories (
    id TEXT PRIMARY KEY CHECK (length(id) = 26),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    printer_id TEXT,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (printer_id) REFERENCES printers(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_categories_printer_id ON categories(printer_id);

-- Products table
CREATE TABLE IF NOT EXISTS products (
    id TEXT PRIMARY KEY CHECK (length(id) = 26),
    name TEXT NOT NULL,
    code TEXT UNIQUE,
    description TEXT,
    price REAL NOT NULL,
    stock INTEGER NOT NULL,
    category_id TEXT,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);
CREATE UNIQUE INDEX IF NOT EXISTS idx_products_code ON products(code);

-- Transactions table
CREATE TABLE IF NOT EXISTS transactions (
    id TEXT PRIMARY KEY CHECK (length(id) = 26),
    order_id TEXT NOT NULL DEFAULT '',
    total_amount REAL NOT NULL,
    payment_method TEXT NOT NULL,
    status TEXT NOT NULL,
    transaction_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT,
    cancelled_at DATETIME,
    cancelled_by TEXT,
    cancel_reason TEXT,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(transaction_date);
CREATE INDEX IF NOT EXISTS idx_transactions_created_by ON transactions(created_by);

-- Transaction items table
CREATE TABLE IF NOT EXISTS transaction_items (
    id TEXT PRIMARY KEY CHECK (length(id) = 26),
    transaction_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    price REAL NOT NULL,
    FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_transaction_items_transaction_id ON transaction_items(transaction_id);
CREATE INDEX IF NOT EXISTS idx_transaction_items_product_id ON transaction_items(product_id);

-- Cashier shifts table
CREATE TABLE IF NOT EXISTS cashier_shifts (
    id TEXT PRIMARY KEY CHECK (length(id) = 26),
    opened_by TEXT NOT NULL,
    opened_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    opening_cash REAL NOT NULL DEFAULT 0,
    closed_at DATETIME,
    closed_by TEXT,
    closing_cash REAL,
    closing_card REAL,
    closing_qris REAL,
    closing_transfer REAL,
    carry_over_cash REAL,
    previous_shift_id TEXT,
    handover_to TEXT,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
    notes TEXT,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (opened_by) REFERENCES users(id),
    FOREIGN KEY (closed_by) REFERENCES users(id),
    FOREIGN KEY (previous_shift_id) REFERENCES cashier_shifts(id),
    FOREIGN KEY (handover_to) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_cashier_shifts_status ON cashier_shifts(status);
CREATE INDEX IF NOT EXISTS idx_cashier_shifts_opened_at ON cashier_shifts(opened_at);

CREATE TABLE IF NOT EXISTS cashier_cash_movements (
    id TEXT PRIMARY KEY CHECK (length(id) = 26),
    shift_id TEXT NOT NULL,
    movement_type TEXT NOT NULL CHECK (movement_type IN ('in', 'out')),
    amount REAL NOT NULL,
    counterpart_name TEXT NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (shift_id) REFERENCES cashier_shifts(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_cashier_cash_movements_shift_id ON cashier_cash_movements(shift_id);
CREATE INDEX IF NOT EXISTS idx_cashier_cash_movements_type ON cashier_cash_movements(movement_type);
