package database

import (
	"backend/pkg/utils"
	"database/sql"
	"log"
	"os"
	"path/filepath"
	"strings"

	_ "modernc.org/sqlite"
)

func NewDatabase(dbPath string) (*sql.DB, error) {
	dbDir := filepath.Dir(dbPath)
	if dbDir != "." && dbDir != "" {
		if err := os.MkdirAll(dbDir, 0o755); err != nil {
			return nil, err
		}
	}

	// Create database file if it doesn't exist
	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		file, err := os.Create(dbPath)
		if err != nil {
			return nil, err
		}
		file.Close()
	}

	// Add busy timeout and other pragmas to prevent database locks
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, err
	}

	// Set connection pool settings
	db.SetMaxOpenConns(1) // SQLite works best with single connection
	db.SetMaxIdleConns(1)

	// Test connection
	if err := db.Ping(); err != nil {
		return nil, err
	}

	if _, err := db.Exec("PRAGMA busy_timeout = 10000"); err != nil {
		return nil, err
	}
	if _, err := db.Exec("PRAGMA journal_mode = WAL"); err != nil {
		return nil, err
	}
	if _, err := db.Exec("PRAGMA synchronous = NORMAL"); err != nil {
		return nil, err
	}

	// Run migrations
	if err := runMigrations(db); err != nil {
		return nil, err
	}

	log.Println("Database connected and migrated successfully")
	return db, nil
}

func runMigrations(db *sql.DB) error {
	schema := `
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

		-- Orders table
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
			ip_address TEXT NOT NULL UNIQUE,
			port INTEGER NOT NULL DEFAULT 9100,
			printer_type TEXT NOT NULL CHECK (printer_type IN ('kitchen', 'bar', 'cashier', 'checker', 'struk')),
			paper_size TEXT DEFAULT '80mm' CHECK (paper_size IN ('58mm', '80mm')),
			
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

		CREATE INDEX IF NOT EXISTS idx_printers_type_active ON printers(printer_type, is_active);
		CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at);
		CREATE INDEX IF NOT EXISTS idx_orders_table_number ON orders(table_number);
		CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(order_status, payment_status);
		CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
		CREATE INDEX IF NOT EXISTS idx_order_additional_charges_order_id ON order_additional_charges(order_id);
		CREATE INDEX IF NOT EXISTS idx_order_items_status ON order_items(item_status);
		CREATE INDEX IF NOT EXISTS idx_print_queue_status_created ON print_queue(status, created_at);

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

		-- Indexes for better query performance
		CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id);
		CREATE INDEX IF NOT EXISTS idx_transaction_items_transaction_id ON transaction_items(transaction_id);
		CREATE INDEX IF NOT EXISTS idx_transaction_items_product_id ON transaction_items(product_id);
		CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(transaction_date);
		CREATE INDEX IF NOT EXISTS idx_cashier_shifts_status ON cashier_shifts(status);
		CREATE INDEX IF NOT EXISTS idx_cashier_shifts_opened_at ON cashier_shifts(opened_at);
		CREATE INDEX IF NOT EXISTS idx_cashier_cash_movements_shift_id ON cashier_cash_movements(shift_id);
		CREATE INDEX IF NOT EXISTS idx_cashier_cash_movements_type ON cashier_cash_movements(movement_type);

		-- ============================================
		-- SYNC SYSTEM SCHEMA
		-- ============================================

		-- Tabel konfigurasi outlet
		CREATE TABLE IF NOT EXISTS outlet_config (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			outlet_id TEXT NOT NULL UNIQUE,
			outlet_name TEXT NOT NULL,
			outlet_code TEXT NOT NULL UNIQUE,
			outlet_address TEXT DEFAULT '',
			outlet_phone TEXT DEFAULT '',
			receipt_footer TEXT DEFAULT 'Terima kasih atas kunjungan Anda!',
			social_media TEXT DEFAULT '',
			target_spend_per_pax INTEGER DEFAULT 0,
			cloud_api_url TEXT NOT NULL,
			cloud_api_key TEXT NOT NULL,
			is_active INTEGER DEFAULT 1,
			sync_enabled INTEGER DEFAULT 1,
			sync_interval_minutes INTEGER DEFAULT 5,
			last_sync_at DATETIME,
			created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
			updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
		);

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

		-- Tabel antrian sinkronisasi
		CREATE TABLE IF NOT EXISTS sync_queue (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			entity_type TEXT NOT NULL,
			entity_id TEXT NOT NULL,
			operation TEXT NOT NULL,
			payload TEXT NOT NULL,
			status TEXT DEFAULT 'pending',
			retry_count INTEGER DEFAULT 0,
			max_retries INTEGER DEFAULT 3,
			error_message TEXT,
			created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
			processed_at DATETIME,
			synced_at DATETIME
		);

		CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(status);
		CREATE INDEX IF NOT EXISTS idx_sync_queue_entity ON sync_queue(entity_type, entity_id);

		-- Tabel log sinkronisasi
		CREATE TABLE IF NOT EXISTS sync_logs (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			sync_type TEXT NOT NULL,
			entity_type TEXT NOT NULL,
			entity_count INTEGER DEFAULT 0,
			status TEXT NOT NULL,
			error_message TEXT,
			started_at DATETIME NOT NULL,
			completed_at DATETIME,
			duration_ms INTEGER,
			details TEXT
		);
	`

	_, err := db.Exec(schema)
	if err != nil {
		return err
	}

	var passwordHashExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('users') 
		WHERE name='password_hash'
	`).Scan(&passwordHashExists)
	if err != nil {
		return err
	}
	if passwordHashExists == 0 {
		_, err = db.Exec("ALTER TABLE users ADD COLUMN password_hash TEXT NOT NULL DEFAULT ''")
		if err != nil {
			return err
		}
		log.Println("✅ Added password_hash column to users table")
	}

	var fullNameExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('users') 
		WHERE name='full_name'
	`).Scan(&fullNameExists)
	if err != nil {
		return err
	}
	if fullNameExists == 0 {
		_, err = db.Exec("ALTER TABLE users ADD COLUMN full_name TEXT NOT NULL DEFAULT ''")
		if err != nil {
			return err
		}
		log.Println("✅ Added full_name column to users table")
	}

	var roleExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('users') 
		WHERE name='role'
	`).Scan(&roleExists)
	if err != nil {
		return err
	}
	if roleExists == 0 {
		_, err = db.Exec("ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'admin' CHECK (role IN ('admin', 'waiter', 'kitchen', 'bar', 'cashier', 'manager'))")
		if err != nil {
			return err
		}
		log.Println("✅ Added role column to users table")
	}

	var isActiveExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('users') 
		WHERE name='is_active'
	`).Scan(&isActiveExists)
	if err != nil {
		return err
	}
	if isActiveExists == 0 {
		_, err = db.Exec("ALTER TABLE users ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1")
		if err != nil {
			return err
		}
		log.Println("✅ Added is_active column to users table")
	}

	var customerPhoneExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('orders') 
		WHERE name='customer_phone'
	`).Scan(&customerPhoneExists)
	if err != nil {
		return err
	}
	if customerPhoneExists == 0 {
		_, err = db.Exec("ALTER TABLE orders ADD COLUMN customer_phone TEXT")
		if err != nil {
			return err
		}
		log.Println("✅ Added customer_phone column to orders table")
	}

	var customerIDExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('orders') 
		WHERE name='customer_id'
	`).Scan(&customerIDExists)
	if err != nil {
		return err
	}
	if customerIDExists == 0 {
		_, err = db.Exec("ALTER TABLE orders ADD COLUMN customer_id TEXT")
		if err != nil {
			return err
		}
		log.Println("✅ Added customer_id column to orders table")
	}

	var createdByExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('orders') 
		WHERE name='created_by'
	`).Scan(&createdByExists)
	if err != nil {
		return err
	}
	if createdByExists == 0 {
		_, err = db.Exec("ALTER TABLE orders ADD COLUMN created_by TEXT")
		if err != nil {
			return err
		}
		log.Println("✅ Added created_by column to orders table")
	}

	var voidedAtExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('orders') 
		WHERE name='voided_at'
	`).Scan(&voidedAtExists)
	if err != nil {
		return err
	}
	if voidedAtExists == 0 {
		_, err = db.Exec("ALTER TABLE orders ADD COLUMN voided_at DATETIME")
		if err != nil {
			return err
		}
		log.Println("✅ Added voided_at column to orders table")
	}

	var voidedByExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('orders') 
		WHERE name='voided_by'
	`).Scan(&voidedByExists)
	if err != nil {
		return err
	}
	if voidedByExists == 0 {
		_, err = db.Exec("ALTER TABLE orders ADD COLUMN voided_by TEXT")
		if err != nil {
			return err
		}
		log.Println("✅ Added voided_by column to orders table")
	}

	var voidReasonExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('orders') 
		WHERE name='void_reason'
	`).Scan(&voidReasonExists)
	if err != nil {
		return err
	}
	if voidReasonExists == 0 {
		_, err = db.Exec("ALTER TABLE orders ADD COLUMN void_reason TEXT")
		if err != nil {
			return err
		}
		log.Println("✅ Added void_reason column to orders table")
	}

	var cancelledAtExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('transactions') 
		WHERE name='cancelled_at'
	`).Scan(&cancelledAtExists)
	if err != nil {
		return err
	}
	if cancelledAtExists == 0 {
		_, err = db.Exec("ALTER TABLE transactions ADD COLUMN cancelled_at DATETIME")
		if err != nil {
			return err
		}
		log.Println("✅ Added cancelled_at column to transactions table")
	}

	var cancelledByExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('transactions') 
		WHERE name='cancelled_by'
	`).Scan(&cancelledByExists)
	if err != nil {
		return err
	}
	if cancelledByExists == 0 {
		_, err = db.Exec("ALTER TABLE transactions ADD COLUMN cancelled_by TEXT")
		if err != nil {
			return err
		}
		log.Println("✅ Added cancelled_by column to transactions table")
	}

	var cancelReasonExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('transactions') 
		WHERE name='cancel_reason'
	`).Scan(&cancelReasonExists)
	if err != nil {
		return err
	}
	if cancelReasonExists == 0 {
		_, err = db.Exec("ALTER TABLE transactions ADD COLUMN cancel_reason TEXT")
		if err != nil {
			return err
		}
		log.Println("✅ Added cancel_reason column to transactions table")
	}

	var orderIDExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('transactions') 
		WHERE name='order_id'
	`).Scan(&orderIDExists)
	if err != nil {
		return err
	}
	if orderIDExists == 0 {
		_, err = db.Exec("ALTER TABLE transactions ADD COLUMN order_id TEXT NOT NULL DEFAULT ''")
		if err != nil {
			return err
		}
		_, err = db.Exec("UPDATE transactions SET order_id = id WHERE order_id = '' OR order_id IS NULL")
		if err != nil {
			return err
		}
		log.Println("✅ Added order_id column to transactions table")
	}

	var createdAtExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('users') 
		WHERE name='created_at'
	`).Scan(&createdAtExists)
	if err != nil {
		return err
	}
	if createdAtExists == 0 {
		_, err = db.Exec("ALTER TABLE users ADD COLUMN created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP")
		if err != nil {
			return err
		}
		log.Println("✅ Added created_at column to users table")
	}

	var updatedAtExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('users') 
		WHERE name='updated_at'
	`).Scan(&updatedAtExists)
	if err != nil {
		return err
	}
	if updatedAtExists == 0 {
		_, err = db.Exec("ALTER TABLE users ADD COLUMN updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP")
		if err != nil {
			return err
		}
		log.Println("✅ Added updated_at column to users table")
	}

	var pinExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('users') 
		WHERE name='pin'
	`).Scan(&pinExists)
	if err != nil {
		return err
	}
	if pinExists > 0 {
		_, err = db.Exec("UPDATE users SET password_hash = pin WHERE password_hash IS NULL OR password_hash = ''")
		if err != nil {
			return err
		}
		log.Println("✅ Migrated pin column to password_hash in users table")
	}

	var legacyPasswordExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('users') 
		WHERE name='password'
	`).Scan(&legacyPasswordExists)
	if err != nil {
		return err
	}
	if legacyPasswordExists > 0 {
		_, err = db.Exec("UPDATE users SET password_hash = password WHERE password_hash IS NULL OR password_hash = ''")
		if err != nil {
			return err
		}
		log.Println("✅ Migrated password column to password_hash in users table")
	}

	// Add description column to categories if it doesn't exist
	// SQLite doesn't have "IF NOT EXISTS" for ALTER TABLE, so we check first
	var columnExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('categories') 
		WHERE name='description'
	`).Scan(&columnExists)

	if err != nil {
		return err
	}

	if columnExists == 0 {
		_, err = db.Exec("ALTER TABLE categories ADD COLUMN description TEXT")
		if err != nil {
			return err
		}
		log.Println("✅ Added description column to categories table")
	}

	// Add printer_id column to categories if it doesn't exist
	var printerIDExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('categories') 
		WHERE name='printer_id'
	`).Scan(&printerIDExists)

	if err != nil {
		return err
	}

	if printerIDExists == 0 {
		_, err = db.Exec("ALTER TABLE categories ADD COLUMN printer_id TEXT")
		if err != nil {
			return err
		}
		log.Println("✅ Added printer_id column to categories table")
	}
	_, err = db.Exec("CREATE INDEX IF NOT EXISTS idx_categories_printer_id ON categories(printer_id)")
	if err != nil {
		return err
	}

	var productCodeExists int
	err = db.QueryRow(`
		SELECT COUNT(*)
		FROM pragma_table_info('products')
		WHERE name='code'
	`).Scan(&productCodeExists)
	if err != nil {
		return err
	}
	if productCodeExists == 0 {
		_, err = db.Exec("ALTER TABLE products ADD COLUMN code TEXT")
		if err != nil {
			return err
		}
	}
	_, err = db.Exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_products_code ON products(code)")
	if err != nil {
		return err
	}

	// Check and add paper_size column to printers if it doesn't exist
	var paperSizeExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('printers') 
		WHERE name='paper_size'
	`).Scan(&paperSizeExists)

	if err != nil {
		return err
	}

	if paperSizeExists == 0 {
		_, err = db.Exec("ALTER TABLE printers ADD COLUMN paper_size TEXT DEFAULT '80mm' CHECK (paper_size IN ('58mm', '80mm'))")
		if err != nil {
			return err
		}
		log.Println("✅ Added paper_size column to printers table")
	}

	var connectionTimeoutExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('printers') 
		WHERE name='connection_timeout'
	`).Scan(&connectionTimeoutExists)
	if err != nil {
		return err
	}
	if connectionTimeoutExists == 0 {
		_, err = db.Exec("ALTER TABLE printers ADD COLUMN connection_timeout INTEGER DEFAULT 3")
		if err != nil {
			return err
		}
	}

	var writeTimeoutExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('printers') 
		WHERE name='write_timeout'
	`).Scan(&writeTimeoutExists)
	if err != nil {
		return err
	}
	if writeTimeoutExists == 0 {
		_, err = db.Exec("ALTER TABLE printers ADD COLUMN write_timeout INTEGER DEFAULT 5")
		if err != nil {
			return err
		}
	}

	var retryAttemptsExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('printers') 
		WHERE name='retry_attempts'
	`).Scan(&retryAttemptsExists)
	if err != nil {
		return err
	}
	if retryAttemptsExists == 0 {
		_, err = db.Exec("ALTER TABLE printers ADD COLUMN retry_attempts INTEGER DEFAULT 2")
		if err != nil {
			return err
		}
	}

	var printDensityExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('printers') 
		WHERE name='print_density'
	`).Scan(&printDensityExists)
	if err != nil {
		return err
	}
	if printDensityExists == 0 {
		_, err = db.Exec("ALTER TABLE printers ADD COLUMN print_density INTEGER DEFAULT 50 CHECK (print_density >= 0 AND print_density <= 100)")
		if err != nil {
			return err
		}
	}

	var printSpeedExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('printers') 
		WHERE name='print_speed'
	`).Scan(&printSpeedExists)
	if err != nil {
		return err
	}
	if printSpeedExists == 0 {
		_, err = db.Exec("ALTER TABLE printers ADD COLUMN print_speed TEXT DEFAULT 'normal' CHECK (print_speed IN ('slow', 'normal', 'fast'))")
		if err != nil {
			return err
		}
	}

	var cutModeExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('printers') 
		WHERE name='cut_mode'
	`).Scan(&cutModeExists)
	if err != nil {
		return err
	}
	if cutModeExists == 0 {
		_, err = db.Exec("ALTER TABLE printers ADD COLUMN cut_mode TEXT DEFAULT 'partial' CHECK (cut_mode IN ('full', 'partial', 'none'))")
		if err != nil {
			return err
		}
	}

	var enableBeepExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('printers') 
		WHERE name='enable_beep'
	`).Scan(&enableBeepExists)
	if err != nil {
		return err
	}
	if enableBeepExists == 0 {
		_, err = db.Exec("ALTER TABLE printers ADD COLUMN enable_beep INTEGER DEFAULT 1")
		if err != nil {
			return err
		}
	}

	var autoCutExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('printers') 
		WHERE name='auto_cut'
	`).Scan(&autoCutExists)
	if err != nil {
		return err
	}
	if autoCutExists == 0 {
		_, err = db.Exec("ALTER TABLE printers ADD COLUMN auto_cut INTEGER DEFAULT 1")
		if err != nil {
			return err
		}
	}

	var charsetExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('printers') 
		WHERE name='charset'
	`).Scan(&charsetExists)
	if err != nil {
		return err
	}
	if charsetExists == 0 {
		_, err = db.Exec("ALTER TABLE printers ADD COLUMN charset TEXT DEFAULT 'latin'")
		if err != nil {
			return err
		}
	}

	var printersSchema string
	err = db.QueryRow(`
		SELECT sql
		FROM sqlite_master
		WHERE type='table' AND name='printers'
	`).Scan(&printersSchema)
	if err != nil && err != sql.ErrNoRows {
		return err
	}

	if printersSchema != "" && strings.Contains(printersSchema, "printer_type IN ('kitchen', 'bar', 'cashier')") && !strings.Contains(printersSchema, "checker") {
		_, err = db.Exec("PRAGMA foreign_keys = OFF")
		if err != nil {
			return err
		}

		_, err = db.Exec(`
			CREATE TABLE printers_new (
				id TEXT PRIMARY KEY CHECK (length(id) = 26),
				name TEXT NOT NULL,
				ip_address TEXT NOT NULL,
				port INTEGER NOT NULL DEFAULT 9100,
				printer_type TEXT NOT NULL CHECK (printer_type IN ('kitchen', 'bar', 'cashier', 'checker', 'struk')),
				paper_size TEXT DEFAULT '80mm' CHECK (paper_size IN ('58mm', '80mm')),
				connection_timeout INTEGER DEFAULT 3,
				write_timeout INTEGER DEFAULT 5,
				retry_attempts INTEGER DEFAULT 2,
				print_density INTEGER DEFAULT 50 CHECK (print_density >= 0 AND print_density <= 100),
				print_speed TEXT DEFAULT 'normal' CHECK (print_speed IN ('slow', 'normal', 'fast')),
				cut_mode TEXT DEFAULT 'partial' CHECK (cut_mode IN ('full', 'partial', 'none')),
				enable_beep INTEGER DEFAULT 1,
				auto_cut INTEGER DEFAULT 1,
				charset TEXT DEFAULT 'latin',
				is_active INTEGER NOT NULL DEFAULT 1,
				created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
				updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
			)
		`)
		if err != nil {
			return err
		}

		_, err = db.Exec(`
			INSERT INTO printers_new (
				id, name, ip_address, port, printer_type, paper_size,
				connection_timeout, write_timeout, retry_attempts,
				print_density, print_speed, cut_mode,
				enable_beep, auto_cut, charset,
				is_active, created_at, updated_at
			)
			SELECT
				id, name, ip_address, port, printer_type, paper_size,
				connection_timeout, write_timeout, retry_attempts,
				print_density, print_speed, cut_mode,
				enable_beep, auto_cut, charset,
				is_active, created_at, updated_at
			FROM printers
		`)
		if err != nil {
			return err
		}

		_, err = db.Exec("DROP TABLE printers")
		if err != nil {
			return err
		}

		_, err = db.Exec("ALTER TABLE printers_new RENAME TO printers")
		if err != nil {
			return err
		}

		_, err = db.Exec("CREATE INDEX IF NOT EXISTS idx_printers_type_active ON printers(printer_type, is_active)")
		if err != nil {
			return err
		}
		_, err = db.Exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_printers_ip_type_unique ON printers(ip_address, printer_type)")
		if err != nil {
			return err
		}

		_, err = db.Exec("PRAGMA foreign_keys = ON")
		if err != nil {
			return err
		}
	}

	if printersSchema != "" {
		err = db.QueryRow(`
			SELECT sql
			FROM sqlite_master
			WHERE type='table' AND name='printers'
		`).Scan(&printersSchema)
		if err != nil && err != sql.ErrNoRows {
			return err
		}
	}

	if printersSchema != "" && strings.Contains(printersSchema, "ip_address TEXT NOT NULL UNIQUE") {
		_, err = db.Exec("PRAGMA foreign_keys = OFF")
		if err != nil {
			return err
		}

		_, err = db.Exec(`
			CREATE TABLE printers_new (
				id TEXT PRIMARY KEY CHECK (length(id) = 26),
				name TEXT NOT NULL,
				ip_address TEXT NOT NULL,
				port INTEGER NOT NULL DEFAULT 9100,
				printer_type TEXT NOT NULL CHECK (printer_type IN ('kitchen', 'bar', 'cashier', 'checker', 'struk')),
				paper_size TEXT DEFAULT '80mm' CHECK (paper_size IN ('58mm', '80mm')),
				connection_timeout INTEGER DEFAULT 3,
				write_timeout INTEGER DEFAULT 5,
				retry_attempts INTEGER DEFAULT 2,
				print_density INTEGER DEFAULT 50 CHECK (print_density >= 0 AND print_density <= 100),
				print_speed TEXT DEFAULT 'normal' CHECK (print_speed IN ('slow', 'normal', 'fast')),
				cut_mode TEXT DEFAULT 'partial' CHECK (cut_mode IN ('full', 'partial', 'none')),
				enable_beep INTEGER DEFAULT 1,
				auto_cut INTEGER DEFAULT 1,
				charset TEXT DEFAULT 'latin',
				is_active INTEGER NOT NULL DEFAULT 1,
				created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
				updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
			)
		`)
		if err != nil {
			return err
		}

		_, err = db.Exec(`
			INSERT INTO printers_new (
				id, name, ip_address, port, printer_type, paper_size,
				connection_timeout, write_timeout, retry_attempts,
				print_density, print_speed, cut_mode,
				enable_beep, auto_cut, charset,
				is_active, created_at, updated_at
			)
			SELECT
				id, name, ip_address, port, printer_type, paper_size,
				connection_timeout, write_timeout, retry_attempts,
				print_density, print_speed, cut_mode,
				enable_beep, auto_cut, charset,
				is_active, created_at, updated_at
			FROM printers
		`)
		if err != nil {
			return err
		}

		_, err = db.Exec("DROP TABLE printers")
		if err != nil {
			return err
		}

		_, err = db.Exec("ALTER TABLE printers_new RENAME TO printers")
		if err != nil {
			return err
		}

		_, err = db.Exec("CREATE INDEX IF NOT EXISTS idx_printers_type_active ON printers(printer_type, is_active)")
		if err != nil {
			return err
		}

		_, err = db.Exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_printers_ip_type_unique ON printers(ip_address, printer_type)")
		if err != nil {
			return err
		}

		_, err = db.Exec("PRAGMA foreign_keys = ON")
		if err != nil {
			return err
		}
	}

	var outletAddressExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('outlet_config') 
		WHERE name='outlet_address'
	`).Scan(&outletAddressExists)
	if err != nil {
		return err
	}
	if outletAddressExists == 0 {
		_, err = db.Exec("ALTER TABLE outlet_config ADD COLUMN outlet_address TEXT DEFAULT ''")
		if err != nil {
			return err
		}
	}

	var outletPhoneExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('outlet_config') 
		WHERE name='outlet_phone'
	`).Scan(&outletPhoneExists)
	if err != nil {
		return err
	}
	if outletPhoneExists == 0 {
		_, err = db.Exec("ALTER TABLE outlet_config ADD COLUMN outlet_phone TEXT DEFAULT ''")
		if err != nil {
			return err
		}
	}

	var receiptFooterExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('outlet_config') 
		WHERE name='receipt_footer'
	`).Scan(&receiptFooterExists)
	if err != nil {
		return err
	}
	if receiptFooterExists == 0 {
		_, err = db.Exec("ALTER TABLE outlet_config ADD COLUMN receipt_footer TEXT DEFAULT 'Terima kasih atas kunjungan Anda!'")
		if err != nil {
			return err
		}
	}

	var socialMediaExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('outlet_config') 
		WHERE name='social_media'
	`).Scan(&socialMediaExists)
	if err != nil {
		return err
	}
	if socialMediaExists == 0 {
		_, err = db.Exec("ALTER TABLE outlet_config ADD COLUMN social_media TEXT DEFAULT ''")
		if err != nil {
			return err
		}
	}

	var targetSpendExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('outlet_config') 
		WHERE name='target_spend_per_pax'
	`).Scan(&targetSpendExists)
	if err != nil {
		return err
	}
	if targetSpendExists == 0 {
		_, err = db.Exec("ALTER TABLE outlet_config ADD COLUMN target_spend_per_pax INTEGER DEFAULT 0")
		if err != nil {
			return err
		}
	}

	// Migrate print_queue table to new schema with printer_id
	// Check if print_queue has old schema (printer_ip column)
	var hasPrinterIP int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('print_queue') 
		WHERE name='printer_ip'
	`).Scan(&hasPrinterIP)

	if err != nil {
		return err
	}

	if hasPrinterIP > 0 {
		// Old schema detected, migrate to new schema
		log.Println("🔄 Migrating print_queue table to new schema...")

		// Rename old table
		_, err = db.Exec("ALTER TABLE print_queue RENAME TO print_queue_old")
		if err != nil {
			return err
		}

		// Create new table with correct schema
		_, err = db.Exec(`
			CREATE TABLE print_queue (
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
			)
		`)
		if err != nil {
			return err
		}

		// Drop old table (no data migration needed as it's a new feature)
		_, err = db.Exec("DROP TABLE print_queue_old")
		if err != nil {
			return err
		}

		log.Println("✅ Print queue table migrated to new schema")
	}

	// Ensure printer_id column exists (for fresh installs)
	var hasPrinterID int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('print_queue') 
		WHERE name='printer_id'
	`).Scan(&hasPrinterID)

	if err != nil {
		return err
	}

	if hasPrinterID == 0 {
		// Add printer_id column if it doesn't exist
		_, err = db.Exec("ALTER TABLE print_queue ADD COLUMN printer_id TEXT REFERENCES printers(id)")
		if err != nil {
			return err
		}
		log.Println("✅ Added printer_id column to print_queue table")
	}

	var printQueueUpdatedAtExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('print_queue') 
		WHERE name='updated_at'
	`).Scan(&printQueueUpdatedAtExists)

	if err != nil {
		return err
	}

	if printQueueUpdatedAtExists == 0 {
		_, err = db.Exec("ALTER TABLE print_queue ADD COLUMN updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP")
		if err != nil {
			return err
		}
		log.Println("✅ Added updated_at column to print_queue table")
	}

	var lockedAtExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('print_queue') 
		WHERE name='locked_at'
	`).Scan(&lockedAtExists)

	if err != nil {
		return err
	}

	if lockedAtExists == 0 {
		_, err = db.Exec("ALTER TABLE print_queue ADD COLUMN locked_at DATETIME")
		if err != nil {
			return err
		}
		log.Println("✅ Added locked_at column to print_queue table")
	}

	var lockedByExists int
	err = db.QueryRow(`
		SELECT COUNT(*) 
		FROM pragma_table_info('print_queue') 
		WHERE name='locked_by'
	`).Scan(&lockedByExists)

	if err != nil {
		return err
	}

	if lockedByExists == 0 {
		_, err = db.Exec("ALTER TABLE print_queue ADD COLUMN locked_by TEXT")
		if err != nil {
			return err
		}
		log.Println("✅ Added locked_by column to print_queue table")
	}

	var transactionCreatedByExists int
	err = db.QueryRow(`
		SELECT COUNT(*)
		FROM pragma_table_info('transactions')
		WHERE name='created_by'
	`).Scan(&transactionCreatedByExists)
	if err != nil {
		return err
	}
	if transactionCreatedByExists == 0 {
		_, err = db.Exec("ALTER TABLE transactions ADD COLUMN created_by TEXT")
		if err != nil {
			return err
		}
		log.Println("✅ Added created_by column to transactions table")
	}
	_, err = db.Exec("CREATE INDEX IF NOT EXISTS idx_transactions_created_by ON transactions(created_by)")
	if err != nil {
		return err
	}

	var cashierShiftsExists int
	err = db.QueryRow(`
		SELECT COUNT(*)
		FROM sqlite_master
		WHERE type='table' AND name='cashier_shifts'
	`).Scan(&cashierShiftsExists)
	if err != nil {
		return err
	}

	if cashierShiftsExists == 0 {
		_, err = db.Exec(`
			CREATE TABLE cashier_shifts (
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
			)
		`)
		if err != nil {
			return err
		}

		_, err = db.Exec("CREATE INDEX IF NOT EXISTS idx_cashier_shifts_status ON cashier_shifts(status)")
		if err != nil {
			return err
		}
		_, err = db.Exec("CREATE INDEX IF NOT EXISTS idx_cashier_shifts_opened_at ON cashier_shifts(opened_at)")
		if err != nil {
			return err
		}
		log.Println("✅ Added cashier_shifts table")
	}

	var cashierCashMovementsExists int
	err = db.QueryRow(`
		SELECT COUNT(*)
		FROM sqlite_master
		WHERE type='table' AND name='cashier_cash_movements'
	`).Scan(&cashierCashMovementsExists)
	if err != nil {
		return err
	}

	if cashierCashMovementsExists == 0 {
		_, err = db.Exec(`
			CREATE TABLE cashier_cash_movements (
				id TEXT PRIMARY KEY CHECK (length(id) = 26),
				shift_id TEXT NOT NULL,
				movement_type TEXT NOT NULL CHECK (movement_type IN ('in', 'out')),
				amount REAL NOT NULL,
				counterpart_name TEXT NOT NULL,
				note TEXT NOT NULL DEFAULT '',
				created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
				FOREIGN KEY (shift_id) REFERENCES cashier_shifts(id) ON DELETE CASCADE
			)
		`)
		if err != nil {
			return err
		}
		_, err = db.Exec("CREATE INDEX IF NOT EXISTS idx_cashier_cash_movements_shift_id ON cashier_cash_movements(shift_id)")
		if err != nil {
			return err
		}
		_, err = db.Exec("CREATE INDEX IF NOT EXISTS idx_cashier_cash_movements_type ON cashier_cash_movements(movement_type)")
		if err != nil {
			return err
		}
		log.Println("✅ Added cashier_cash_movements table")
	}

	var cashMovementNoteExists int
	err = db.QueryRow(`
		SELECT COUNT(*)
		FROM pragma_table_info('cashier_cash_movements')
		WHERE name='note'
	`).Scan(&cashMovementNoteExists)
	if err != nil {
		return err
	}
	if cashMovementNoteExists == 0 {
		_, err = db.Exec("ALTER TABLE cashier_cash_movements ADD COLUMN note TEXT NOT NULL DEFAULT ''")
		if err != nil {
			return err
		}
		log.Println("✅ Added note column to cashier_cash_movements table")
	}

	var previousShiftExists int
	err = db.QueryRow(`
		SELECT COUNT(*)
		FROM pragma_table_info('cashier_shifts')
		WHERE name='previous_shift_id'
	`).Scan(&previousShiftExists)
	if err != nil {
		return err
	}
	if previousShiftExists == 0 {
		_, err = db.Exec("ALTER TABLE cashier_shifts ADD COLUMN previous_shift_id TEXT")
		if err != nil {
			return err
		}
		log.Println("✅ Added previous_shift_id column to cashier_shifts table")
	}

	var handoverToExists int
	err = db.QueryRow(`
		SELECT COUNT(*)
		FROM pragma_table_info('cashier_shifts')
		WHERE name='handover_to'
	`).Scan(&handoverToExists)
	if err != nil {
		return err
	}
	if handoverToExists == 0 {
		_, err = db.Exec("ALTER TABLE cashier_shifts ADD COLUMN handover_to TEXT")
		if err != nil {
			return err
		}
		log.Println("✅ Added handover_to column to cashier_shifts table")
	}

	var closingCardExists int
	err = db.QueryRow(`
		SELECT COUNT(*)
		FROM pragma_table_info('cashier_shifts')
		WHERE name='closing_card'
	`).Scan(&closingCardExists)
	if err != nil {
		return err
	}
	if closingCardExists == 0 {
		_, err = db.Exec("ALTER TABLE cashier_shifts ADD COLUMN closing_card REAL")
		if err != nil {
			return err
		}
		log.Println("✅ Added closing_card column to cashier_shifts table")
	}

	var closingQrisExists int
	err = db.QueryRow(`
		SELECT COUNT(*)
		FROM pragma_table_info('cashier_shifts')
		WHERE name='closing_qris'
	`).Scan(&closingQrisExists)
	if err != nil {
		return err
	}
	if closingQrisExists == 0 {
		_, err = db.Exec("ALTER TABLE cashier_shifts ADD COLUMN closing_qris REAL")
		if err != nil {
			return err
		}
		log.Println("✅ Added closing_qris column to cashier_shifts table")
	}

	var closingTransferExists int
	err = db.QueryRow(`
		SELECT COUNT(*)
		FROM pragma_table_info('cashier_shifts')
		WHERE name='closing_transfer'
	`).Scan(&closingTransferExists)
	if err != nil {
		return err
	}
	if closingTransferExists == 0 {
		_, err = db.Exec("ALTER TABLE cashier_shifts ADD COLUMN closing_transfer REAL")
		if err != nil {
			return err
		}
		log.Println("✅ Added closing_transfer column to cashier_shifts table")
	}

	var ordersSchema string
	err = db.QueryRow(`
		SELECT sql
		FROM sqlite_master
		WHERE type='table' AND name='orders'
	`).Scan(&ordersSchema)
	if err != nil && err != sql.ErrNoRows {
		return err
	}

	if strings.Contains(ordersSchema, "length(id) = 26") {
		log.Println("🔄 Migrating orders table to new order_id format...")

		_, err = db.Exec("PRAGMA foreign_keys = OFF")
		if err != nil {
			return err
		}

		_, err = db.Exec(`
			CREATE TABLE orders_new (
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
			)
		`)
		if err != nil {
			return err
		}

		_, err = db.Exec(`
			INSERT INTO orders_new (
				id,
				table_number,
				customer_name,
				customer_phone,
				customer_id,
				pax,
				basket_size,
				total_amount,
				paid_amount,
				order_status,
				created_by,
				payment_status,
				merged_from,
				is_merged,
				voided_at,
				voided_by,
				void_reason,
				created_at,
				updated_at
			)
			SELECT
				id,
				table_number,
				customer_name,
				customer_phone,
				customer_id,
				pax,
				basket_size,
				total_amount,
				paid_amount,
				order_status,
				created_by,
				payment_status,
				merged_from,
				is_merged,
				voided_at,
				voided_by,
				void_reason,
				created_at,
				updated_at
			FROM orders
		`)
		if err != nil {
			return err
		}

		_, err = db.Exec("DROP TABLE orders")
		if err != nil {
			return err
		}

		_, err = db.Exec("ALTER TABLE orders_new RENAME TO orders")
		if err != nil {
			return err
		}

		_, err = db.Exec("CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at)")
		if err != nil {
			return err
		}
		_, err = db.Exec("CREATE INDEX IF NOT EXISTS idx_orders_table_number ON orders(table_number)")
		if err != nil {
			return err
		}
		_, err = db.Exec("CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(order_status)")
		if err != nil {
			return err
		}

		_, err = db.Exec("PRAGMA foreign_keys = ON")
		if err != nil {
			return err
		}

		log.Println("✅ Orders table migrated to new order_id format")
	}

	if err := seedAdminUser(db); err != nil {
		return err
	}
	if err := seedOutletConfig(db); err != nil {
		return err
	}

	return nil
}

func seedAdminUser(db *sql.DB) error {
	var existing int
	if err := db.QueryRow("SELECT COUNT(*) FROM users WHERE username = 'admin'").Scan(&existing); err != nil {
		return err
	}
	if existing > 0 {
		return nil
	}

	adminID := utils.GenerateULID()
	hashedPin := "$2a$10$oXUCAAv0Ogc46O0PxqVWQOi3BEXgEQ1T7h6jzrVoMjp.4fAieHKn."

	_, err := db.Exec(`
		INSERT INTO users (id, username, password_hash, full_name, role, is_active, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
	`, adminID, "admin", hashedPin, "Administrator", "admin")
	return err
}

func seedOutletConfig(db *sql.DB) error {
	var existing int
	if err := db.QueryRow("SELECT COUNT(*) FROM outlet_config").Scan(&existing); err != nil {
		return err
	}
	if existing > 0 {
		return nil
	}

	outletID := utils.GenerateULID()
	_, err := db.Exec(`
		INSERT INTO outlet_config (
			outlet_id, outlet_name, outlet_code, outlet_address, outlet_phone,
			receipt_footer, social_media, target_spend_per_pax, cloud_api_url, cloud_api_key,
			is_active, sync_enabled, sync_interval_minutes, created_at, updated_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, '', '', 1, 0, 5, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
	`, outletID, "Outlet", "OUTLET-001", "", "", "Terima kasih atas kunjungan Anda!", "", 0)
	return err
}
