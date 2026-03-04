package database

import "log"

func RunMigrations() error {
	migrations := []string{
		`CREATE TABLE IF NOT EXISTS outlets (
			id CHAR(26) PRIMARY KEY,
			code VARCHAR(20) UNIQUE NOT NULL,
			name VARCHAR(100) NOT NULL,
			address TEXT,
			api_key VARCHAR(100) UNIQUE NOT NULL,
			webhook_url TEXT,
			is_active BOOLEAN DEFAULT true,
			created_at TIMESTAMP DEFAULT NOW(),
			updated_at TIMESTAMP DEFAULT NOW()
		)`,

		`CREATE TABLE IF NOT EXISTS cloud_orders (
			id CHAR(26) PRIMARY KEY,
			local_id VARCHAR(50) NOT NULL,
			outlet_id CHAR(26) NOT NULL REFERENCES outlets(id),
			outlet_code VARCHAR(20) NOT NULL,
			table_number VARCHAR(20),
			customer_name VARCHAR(100),
			pax INTEGER DEFAULT 1,
			total_amount DECIMAL(15,2) NOT NULL,
			status VARCHAR(20) DEFAULT 'pending',
			items JSONB,
			payment_info JSONB,
			version INTEGER DEFAULT 1,
			created_at TIMESTAMP DEFAULT NOW(),
			updated_at TIMESTAMP DEFAULT NOW(),
			synced_at TIMESTAMP DEFAULT NOW(),
			UNIQUE(outlet_id, local_id)
		)`,

		`CREATE TABLE IF NOT EXISTS cloud_transactions (
			id CHAR(26) PRIMARY KEY,
			local_id VARCHAR(50) NOT NULL,
			outlet_id CHAR(26) NOT NULL REFERENCES outlets(id),
			outlet_code VARCHAR(20) NOT NULL,
			order_id VARCHAR(50),
			total_amount DECIMAL(15,2) NOT NULL,
			payment_method VARCHAR(30),
			cash_amount DECIMAL(15,2) DEFAULT 0,
			change_amount DECIMAL(15,2) DEFAULT 0,
			cashier_name VARCHAR(100),
			items JSONB,
			version INTEGER DEFAULT 1,
			created_at TIMESTAMP DEFAULT NOW(),
			synced_at TIMESTAMP DEFAULT NOW(),
			UNIQUE(outlet_id, local_id)
		)`,

		`CREATE TABLE IF NOT EXISTS cloud_products (
			id CHAR(26) PRIMARY KEY,
			local_id VARCHAR(50) NOT NULL,
			outlet_id CHAR(26) NOT NULL REFERENCES outlets(id),
			name VARCHAR(200) NOT NULL,
			category_id VARCHAR(50),
			category_name VARCHAR(100),
			price DECIMAL(15,2) NOT NULL,
			stock INTEGER DEFAULT 0,
			destination VARCHAR(50),
			is_deleted BOOLEAN DEFAULT false,
			version INTEGER DEFAULT 1,
			created_at TIMESTAMP DEFAULT NOW(),
			updated_at TIMESTAMP DEFAULT NOW(),
			synced_at TIMESTAMP DEFAULT NOW(),
			UNIQUE(outlet_id, local_id)
		)`,

		`CREATE TABLE IF NOT EXISTS cloud_categories (
			id CHAR(26) PRIMARY KEY,
			local_id VARCHAR(50),
			outlet_id CHAR(26) NOT NULL REFERENCES outlets(id),
			name VARCHAR(100) NOT NULL,
			is_deleted BOOLEAN DEFAULT false,
			version INTEGER DEFAULT 1,
			created_at TIMESTAMP DEFAULT NOW(),
			updated_at TIMESTAMP DEFAULT NOW(),
			synced_at TIMESTAMP DEFAULT NOW(),
			UNIQUE(outlet_id, local_id),
			UNIQUE(outlet_id, name)
		)`,

		`CREATE TABLE IF NOT EXISTS cloud_analytics (
			id CHAR(26) PRIMARY KEY,
			outlet_id CHAR(26) NOT NULL REFERENCES outlets(id),
			outlet_code VARCHAR(20) NOT NULL,
			date DATE NOT NULL,
			summary JSONB NOT NULL,
			created_at TIMESTAMP DEFAULT NOW(),
			updated_at TIMESTAMP DEFAULT NOW(),
			UNIQUE(outlet_id, date)
		)`,

		`CREATE TABLE IF NOT EXISTS sync_logs (
			id CHAR(26) PRIMARY KEY,
			outlet_id CHAR(26) NOT NULL REFERENCES outlets(id),
			action VARCHAR(50) NOT NULL,
			entity_type VARCHAR(30),
			entity_count INTEGER DEFAULT 0,
			status VARCHAR(20) DEFAULT 'success',
			error_message TEXT,
			created_at TIMESTAMP DEFAULT NOW()
		)`,

		`CREATE TABLE IF NOT EXISTS sync_conflicts (
			id CHAR(26) PRIMARY KEY,
			outlet_id CHAR(26) NOT NULL REFERENCES outlets(id),
			entity_type VARCHAR(30) NOT NULL,
			entity_local_id VARCHAR(50),
			entity_cloud_id CHAR(26),
			conflict_field VARCHAR(50),
			cloud_value TEXT,
			local_value TEXT,
			cloud_version INTEGER,
			local_version INTEGER,
			resolution VARCHAR(20),
			resolved_by VARCHAR(100),
			resolved_at TIMESTAMP,
			notes TEXT,
			created_at TIMESTAMP DEFAULT NOW()
		)`,

		`CREATE INDEX IF NOT EXISTS idx_cloud_orders_outlet ON cloud_orders(outlet_id)`,
		`CREATE INDEX IF NOT EXISTS idx_cloud_orders_local ON cloud_orders(outlet_id, local_id)`,
		`CREATE INDEX IF NOT EXISTS idx_cloud_orders_updated ON cloud_orders(updated_at)`,
		`CREATE INDEX IF NOT EXISTS idx_cloud_transactions_outlet ON cloud_transactions(outlet_id)`,
		`CREATE INDEX IF NOT EXISTS idx_cloud_transactions_local ON cloud_transactions(outlet_id, local_id)`,
		`CREATE INDEX IF NOT EXISTS idx_cloud_products_outlet ON cloud_products(outlet_id)`,
		`CREATE INDEX IF NOT EXISTS idx_cloud_products_local ON cloud_products(outlet_id, local_id)`,
		`CREATE INDEX IF NOT EXISTS idx_cloud_products_updated ON cloud_products(updated_at)`,
		`CREATE INDEX IF NOT EXISTS idx_cloud_categories_outlet ON cloud_categories(outlet_id)`,
		`CREATE INDEX IF NOT EXISTS idx_cloud_analytics_outlet ON cloud_analytics(outlet_id, date)`,
		`CREATE INDEX IF NOT EXISTS idx_sync_logs_outlet ON sync_logs(outlet_id, created_at)`,

		// Cashier shifts table
		`CREATE TABLE IF NOT EXISTS cloud_cashier_shifts (
			id CHAR(26) PRIMARY KEY,
			local_id VARCHAR(50) NOT NULL,
			outlet_id CHAR(26) NOT NULL REFERENCES outlets(id),
			opened_by VARCHAR(100) NOT NULL,
			opened_at TIMESTAMP NOT NULL,
			opening_cash DECIMAL(15,2) NOT NULL DEFAULT 0,
			closed_at TIMESTAMP,
			closed_by VARCHAR(100),
			closing_cash DECIMAL(15,2),
			closing_card DECIMAL(15,2),
			closing_qris DECIMAL(15,2),
			closing_transfer DECIMAL(15,2),
			carry_over_cash DECIMAL(15,2),
			previous_shift_id VARCHAR(50),
			handover_to VARCHAR(100),
			status VARCHAR(20) NOT NULL DEFAULT 'open',
			notes TEXT,
			created_at TIMESTAMP DEFAULT NOW(),
			updated_at TIMESTAMP DEFAULT NOW(),
			synced_at TIMESTAMP DEFAULT NOW(),
			UNIQUE(outlet_id, local_id)
		)`,

		// Cash movements table
		`CREATE TABLE IF NOT EXISTS cloud_cash_movements (
			id CHAR(26) PRIMARY KEY,
			local_id VARCHAR(50) NOT NULL,
			outlet_id CHAR(26) NOT NULL REFERENCES outlets(id),
			shift_id VARCHAR(50) NOT NULL,
			movement_type VARCHAR(10) NOT NULL,
			amount DECIMAL(15,2) NOT NULL,
			counterpart_name VARCHAR(200) NOT NULL DEFAULT '',
			note TEXT NOT NULL DEFAULT '',
			created_at TIMESTAMP DEFAULT NOW(),
			synced_at TIMESTAMP DEFAULT NOW(),
			UNIQUE(outlet_id, local_id)
		)`,

		`CREATE INDEX IF NOT EXISTS idx_cloud_cashier_shifts_outlet ON cloud_cashier_shifts(outlet_id)`,
		`CREATE INDEX IF NOT EXISTS idx_cloud_cashier_shifts_status ON cloud_cashier_shifts(outlet_id, status)`,
		`CREATE INDEX IF NOT EXISTS idx_cloud_cashier_shifts_opened ON cloud_cashier_shifts(opened_at)`,
		`CREATE INDEX IF NOT EXISTS idx_cloud_cash_movements_outlet ON cloud_cash_movements(outlet_id)`,
		`CREATE INDEX IF NOT EXISTS idx_cloud_cash_movements_shift ON cloud_cash_movements(shift_id)`,

		// Admin users table
		`CREATE TABLE IF NOT EXISTS cloud_admins (
			id CHAR(26) PRIMARY KEY,
			username VARCHAR(50) UNIQUE NOT NULL,
			password_hash VARCHAR(255) NOT NULL,
			name VARCHAR(100) NOT NULL,
			role VARCHAR(20) NOT NULL DEFAULT 'admin',
			is_active BOOLEAN DEFAULT true,
			last_login_at TIMESTAMP,
			created_at TIMESTAMP DEFAULT NOW(),
			updated_at TIMESTAMP DEFAULT NOW()
		)`,

		// Printers per outlet
		`CREATE TABLE IF NOT EXISTS cloud_printers (
			id CHAR(26) PRIMARY KEY,
			local_id VARCHAR(50) NOT NULL,
			outlet_id CHAR(26) NOT NULL REFERENCES outlets(id),
			name VARCHAR(100) NOT NULL,
			ip_address VARCHAR(50) NOT NULL,
			port INTEGER NOT NULL DEFAULT 9100,
			printer_type VARCHAR(20) NOT NULL,
			paper_size VARCHAR(10) NOT NULL DEFAULT '80mm',
			is_active BOOLEAN NOT NULL DEFAULT true,
			is_deleted BOOLEAN NOT NULL DEFAULT false,
			created_at TIMESTAMP DEFAULT NOW(),
			updated_at TIMESTAMP DEFAULT NOW(),
			synced_at TIMESTAMP DEFAULT NOW(),
			UNIQUE(outlet_id, local_id)
		)`,

		`CREATE INDEX IF NOT EXISTS idx_cloud_printers_outlet ON cloud_printers(outlet_id)`,
		`CREATE INDEX IF NOT EXISTS idx_cloud_printers_active ON cloud_printers(outlet_id, is_active)`,
	}

	for i, m := range migrations {
		if _, err := DB.Exec(m); err != nil {
			log.Printf("Migration %d failed: %v", i+1, err)
			return err
		}
	}

	// Additive migrations — safe for existing databases
	additiveMigrations := []string{
		`ALTER TABLE cloud_transactions ADD COLUMN IF NOT EXISTS items JSONB`,
		`ALTER TABLE cloud_categories ADD COLUMN IF NOT EXISTS code_prefix VARCHAR(10) DEFAULT ''`,
		`ALTER TABLE cloud_categories ADD COLUMN IF NOT EXISTS printer_id VARCHAR(50) DEFAULT NULL`,
	}

	for _, m := range additiveMigrations {
		if _, err := DB.Exec(m); err != nil {
			log.Printf("Additive migration skipped: %v", err)
		}
	}

	log.Printf("Ran %d migrations successfully", len(migrations))
	return nil
}
