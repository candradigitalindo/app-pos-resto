package database

import (
	"log"
)

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
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			updated_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC')
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
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			updated_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			synced_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
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
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			synced_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
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
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			updated_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			synced_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			UNIQUE(outlet_id, local_id)
		)`,

		`CREATE TABLE IF NOT EXISTS cloud_categories (
			id CHAR(26) PRIMARY KEY,
			local_id VARCHAR(50),
			outlet_id CHAR(26) NOT NULL REFERENCES outlets(id),
			name VARCHAR(100) NOT NULL,
			is_deleted BOOLEAN DEFAULT false,
			version INTEGER DEFAULT 1,
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			updated_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			synced_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			UNIQUE(outlet_id, local_id),
			UNIQUE(outlet_id, name)
		)`,

		`CREATE TABLE IF NOT EXISTS cloud_analytics (
			id CHAR(26) PRIMARY KEY,
			outlet_id CHAR(26) NOT NULL REFERENCES outlets(id),
			outlet_code VARCHAR(20) NOT NULL,
			date DATE NOT NULL,
			summary JSONB NOT NULL,
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			updated_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
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
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC')
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
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC')
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
		`CREATE INDEX IF NOT EXISTS idx_cloud_orders_created ON cloud_orders(created_at)`,
		`CREATE INDEX IF NOT EXISTS idx_cloud_transactions_created ON cloud_transactions(created_at)`,
		`CREATE INDEX IF NOT EXISTS idx_cloud_orders_payment_status ON cloud_orders((payment_info->>'payment_status'))`,

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
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			updated_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			synced_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
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
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			synced_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
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
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			updated_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC')
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
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			updated_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			synced_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			UNIQUE(outlet_id, local_id)
		)`,

		`CREATE INDEX IF NOT EXISTS idx_cloud_printers_outlet ON cloud_printers(outlet_id)`,
		`CREATE INDEX IF NOT EXISTS idx_cloud_printers_active ON cloud_printers(outlet_id, is_active)`,

		// Add phone column to outlets (idempotent)
		`ALTER TABLE outlets ADD COLUMN IF NOT EXISTS phone VARCHAR(50) DEFAULT ''`,
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
		`ALTER TABLE cloud_products ADD COLUMN IF NOT EXISTS code VARCHAR(50) DEFAULT NULL`,
		`ALTER TABLE cloud_products ADD COLUMN IF NOT EXISTS description TEXT DEFAULT ''`,
		`CREATE UNIQUE INDEX IF NOT EXISTS idx_cloud_products_code ON cloud_products(outlet_id, code) WHERE code IS NOT NULL AND code != ''`,
	}

	for _, m := range additiveMigrations {
		if _, err := DB.Exec(m); err != nil {
			log.Printf("Additive migration skipped: %v", err)
		}
	}

	// Role permissions table
	rolePermMigrations := []string{
		`CREATE TABLE IF NOT EXISTS role_permissions (
			id SERIAL PRIMARY KEY,
			role VARCHAR(50) NOT NULL,
			permission VARCHAR(50) NOT NULL,
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			UNIQUE(role, permission)
		)`,
		// Seed default permissions for admin (full access)
		`INSERT INTO role_permissions (role, permission)
		VALUES
			('admin', 'dashboard'),
			('admin', 'outlets'),
			('admin', 'products'),
			('admin', 'reports'),
			('admin', 'users'),
			('admin', 'settings.view'),
			('admin', 'settings.manage')
		ON CONFLICT (role, permission) DO NOTHING`,
		// Seed default permissions for manager (no user management)
		`INSERT INTO role_permissions (role, permission)
		VALUES
			('manager', 'dashboard'),
			('manager', 'outlets'),
			('manager', 'products'),
			('manager', 'reports')
		ON CONFLICT (role, permission) DO NOTHING`,
		// Seed default permissions for viewer (read-only)
		`INSERT INTO role_permissions (role, permission)
		VALUES
			('viewer', 'dashboard'),
			('viewer', 'reports')
		ON CONFLICT (role, permission) DO NOTHING`,
	}

	for _, m := range rolePermMigrations {
		if _, err := DB.Exec(m); err != nil {
			log.Printf("Role permissions migration skipped: %v", err)
		}
	}

	// Roles table (custom roles registry)
	rolesMigrations := []string{
		`CREATE TABLE IF NOT EXISTS roles (
			name VARCHAR(50) PRIMARY KEY,
			description VARCHAR(255) NOT NULL DEFAULT '',
			is_system BOOLEAN NOT NULL DEFAULT false,
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC')
		)`,
		// Seed default roles (only admin is system role)
		`INSERT INTO roles (name, description, is_system) VALUES
			('admin', 'Full akses ke semua fitur', true),
			('manager', 'Akses tanpa manajemen pengguna', false),
			('viewer', 'Hanya dashboard dan laporan', false)
		ON CONFLICT (name) DO NOTHING`,
		// Ensure only admin is system role
		`UPDATE roles SET is_system = false WHERE name IN ('manager', 'viewer') AND is_system = true`,
		// Widen role_permissions.role column to allow custom role names
		`ALTER TABLE role_permissions ALTER COLUMN role TYPE VARCHAR(50)`,
		// Add redirect_to column for post-login redirect per role
		`ALTER TABLE roles ADD COLUMN IF NOT EXISTS redirect_to VARCHAR(100) NOT NULL DEFAULT '/'`,
		// Set default redirect_to for seeded roles
		`UPDATE roles SET redirect_to = '/' WHERE name = 'admin' AND redirect_to = '/'`,
		`UPDATE roles SET redirect_to = '/manager-dashboard' WHERE name = 'manager' AND redirect_to IN ('/', '/outlets')`,
		`UPDATE roles SET redirect_to = '/sales-report' WHERE name = 'viewer' AND redirect_to = '/'`,
		// Seed dashboard.manager permission for admin and manager roles
		`INSERT INTO role_permissions (role, permission) VALUES ('admin', 'dashboard.manager') ON CONFLICT (role, permission) DO NOTHING`,
		`INSERT INTO role_permissions (role, permission) VALUES ('manager', 'dashboard.manager') ON CONFLICT (role, permission) DO NOTHING`,
		// Migrate old-style permissions (outlets, products) to new format (module.view)
		`UPDATE role_permissions SET permission = 'outlets.view' WHERE permission = 'outlets'`,
		`UPDATE role_permissions SET permission = 'products.view' WHERE permission = 'products'`,
		`UPDATE role_permissions SET permission = 'users.view' WHERE permission = 'users'`,
		// Seed procurement.work_units for admin and manager roles
		`INSERT INTO role_permissions (role, permission) VALUES ('admin', 'procurement.work_units') ON CONFLICT (role, permission) DO NOTHING`,
		`INSERT INTO role_permissions (role, permission) VALUES ('manager', 'procurement.work_units') ON CONFLICT (role, permission) DO NOTHING`,
	}

	for _, m := range rolesMigrations {
		if _, err := DB.Exec(m); err != nil {
			log.Printf("Roles migration skipped: %v", err)
		}
	}

	// Purchase requests table
	purchaseMigrations := []string{
		`CREATE TABLE IF NOT EXISTS purchase_requests (
			id CHAR(26) PRIMARY KEY,
			outlet_id CHAR(26) NOT NULL REFERENCES outlets(id),
			request_type VARCHAR(10) NOT NULL DEFAULT 'barang',
			requested_by VARCHAR(100) NOT NULL,
			vendor_name VARCHAR(200) NOT NULL DEFAULT '',
			status VARCHAR(20) NOT NULL DEFAULT 'pending',
			items JSONB NOT NULL DEFAULT '[]',
			total_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
			total_hps DECIMAL(15,2) NOT NULL DEFAULT 0,
			total_final DECIMAL(15,2) NOT NULL DEFAULT 0,
			notes TEXT NOT NULL DEFAULT '',
			approved_by VARCHAR(100),
			approved_at TIMESTAMP,
			rejected_reason TEXT,
			paid_by VARCHAR(100),
			paid_at TIMESTAMP,
			payment_proof TEXT,
			received_by VARCHAR(100),
			received_at TIMESTAMP,
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			updated_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC')
		)`,
		`CREATE INDEX IF NOT EXISTS idx_purchase_requests_outlet ON purchase_requests(outlet_id)`,
		`CREATE INDEX IF NOT EXISTS idx_purchase_requests_status ON purchase_requests(status)`,
		`CREATE INDEX IF NOT EXISTS idx_purchase_requests_created ON purchase_requests(created_at)`,
		`ALTER TABLE purchase_requests ADD COLUMN IF NOT EXISTS request_type VARCHAR(10) NOT NULL DEFAULT 'barang'`,
		`ALTER TABLE purchase_requests ADD COLUMN IF NOT EXISTS vendor_name VARCHAR(200) NOT NULL DEFAULT ''`,
		`ALTER TABLE purchase_requests ADD COLUMN IF NOT EXISTS total_hps DECIMAL(15,2) NOT NULL DEFAULT 0`,
		`ALTER TABLE purchase_requests ADD COLUMN IF NOT EXISTS total_final DECIMAL(15,2) NOT NULL DEFAULT 0`,
		`CREATE INDEX IF NOT EXISTS idx_purchase_requests_type ON purchase_requests(request_type)`,
		// Allow purchase requests without outlet (standalone work units)
		`ALTER TABLE purchase_requests ALTER COLUMN outlet_id DROP NOT NULL`,
		// Payment detail fields
		`ALTER TABLE purchase_requests ADD COLUMN IF NOT EXISTS payment_account_dest VARCHAR(300) NOT NULL DEFAULT ''`,
		`ALTER TABLE purchase_requests ADD COLUMN IF NOT EXISTS payment_account_source VARCHAR(300) NOT NULL DEFAULT ''`,
		`ALTER TABLE purchase_requests ADD COLUMN IF NOT EXISTS payment_notes TEXT NOT NULL DEFAULT ''`,
		// Split purchase requests support
		`ALTER TABLE purchase_requests ADD COLUMN IF NOT EXISTS parent_id CHAR(26) REFERENCES purchase_requests(id) ON DELETE SET NULL`,
		`ALTER TABLE purchase_requests ADD COLUMN IF NOT EXISTS split_status VARCHAR(20) DEFAULT NULL`, // 'master' or NULL
		`CREATE INDEX IF NOT EXISTS idx_purchase_requests_parent ON purchase_requests(parent_id)`,
		// Request number for sequential numbering (ddmmYYnnn)
		`ALTER TABLE purchase_requests ADD COLUMN IF NOT EXISTS request_number VARCHAR(20) NOT NULL DEFAULT ''`,
		`CREATE INDEX IF NOT EXISTS idx_purchase_requests_number ON purchase_requests(request_number)`,
		// Cascade: sync children status to match their master's status (for existing data)
		// Only cascade to children that are still in an earlier/equal stage — never downgrade paid/partial/received
		`UPDATE purchase_requests c
		 SET status = p.status, updated_at = NOW()
		 FROM purchase_requests p
		 WHERE c.parent_id = p.id
		   AND p.split_status = 'master'
		   AND c.status != p.status
		   AND p.status IN ('approved', 'payment_requested', 'cancelled')
		   AND c.status NOT IN ('partial', 'paid', 'received')`,
	}

	for _, m := range purchaseMigrations {
		if _, err := DB.Exec(m); err != nil {
			log.Printf("Purchase requests migration skipped: %v", err)
		}
	}

	// Work units table — each outlet is auto-registered as a work unit
	workUnitMigrations := []string{
		`CREATE TABLE IF NOT EXISTS work_units (
			id CHAR(26) PRIMARY KEY,
			outlet_id CHAR(26) NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
			name VARCHAR(100) NOT NULL,
			admin_id CHAR(26) REFERENCES cloud_admins(id) ON DELETE SET NULL,
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			updated_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			UNIQUE(outlet_id)
		)`,
		`CREATE INDEX IF NOT EXISTS idx_work_units_outlet ON work_units(outlet_id)`,
		`CREATE INDEX IF NOT EXISTS idx_work_units_admin ON work_units(admin_id)`,
		// Seed work units for existing outlets that don't have one yet
		`INSERT INTO work_units (id, outlet_id, name, created_at, updated_at)
		SELECT
			UPPER(LPAD(TO_HEX((EXTRACT(EPOCH FROM NOW()) * 1000)::BIGINT), 12, '0') ||
			LPAD(TO_HEX((RANDOM() * 2147483647)::INT), 8, '0') ||
			LPAD(TO_HEX((RANDOM() * 65535)::INT), 4, '0') ||
			'00'),
			o.id, o.name, NOW(), NOW()
		FROM outlets o
		WHERE NOT EXISTS (SELECT 1 FROM work_units wu WHERE wu.outlet_id = o.id)`,
		// Add work_unit_id column to purchase_requests
		`ALTER TABLE purchase_requests ADD COLUMN IF NOT EXISTS work_unit_id CHAR(26) REFERENCES work_units(id) ON DELETE SET NULL`,
		`CREATE INDEX IF NOT EXISTS idx_purchase_requests_work_unit ON purchase_requests(work_unit_id)`,
		// Allow standalone work units (not linked to an outlet)
		`ALTER TABLE work_units ALTER COLUMN outlet_id DROP NOT NULL`,
		`ALTER TABLE work_units DROP CONSTRAINT IF EXISTS work_units_outlet_id_key`,
		`DROP INDEX IF EXISTS work_units_outlet_id_key`,
		`CREATE UNIQUE INDEX IF NOT EXISTS idx_work_units_outlet_unique ON work_units(outlet_id) WHERE outlet_id IS NOT NULL`,
	}

	for _, m := range workUnitMigrations {
		if _, err := DB.Exec(m); err != nil {
			log.Printf("Work units migration skipped: %v", err)
		}
	}

	// Migrate old permission keys to granular view/manage format
	permMigrations := map[string][]string{
		"outlets":     {"outlets.view", "outlets.manage"},
		"products":    {"products.view", "products.manage"},
		"procurement": {"procurement.view", "procurement.submit", "procurement.approve", "procurement.purchasing", "procurement.finance"},
		"users":       {"users.view", "users.manage"},
	}
	for old, newPerms := range permMigrations {
		var count int
		DB.QueryRow("SELECT COUNT(*) FROM role_permissions WHERE permission = $1", old).Scan(&count)
		if count > 0 {
			rows, err := DB.Query("SELECT role FROM role_permissions WHERE permission = $1", old)
			if err == nil {
				var roles []string
				for rows.Next() {
					var r string
					rows.Scan(&r)
					roles = append(roles, r)
				}
				rows.Close()
				for _, r := range roles {
					for _, np := range newPerms {
						DB.Exec("INSERT INTO role_permissions (role, permission) VALUES ($1, $2) ON CONFLICT DO NOTHING", r, np)
					}
				}
				DB.Exec("DELETE FROM role_permissions WHERE permission = $1", old)
			}
			log.Printf("Migrated permission '%s' → %v for %d roles", old, newPerms, count)
		}
	}

	// Migrate procurement.manage → 3 granular permissions
	{
		var count int
		DB.QueryRow("SELECT COUNT(*) FROM role_permissions WHERE permission = 'procurement.manage'").Scan(&count)
		if count > 0 {
			rows, err := DB.Query("SELECT role FROM role_permissions WHERE permission = 'procurement.manage'")
			if err == nil {
				var roles []string
				for rows.Next() {
					var r string
					rows.Scan(&r)
					roles = append(roles, r)
				}
				rows.Close()
				for _, r := range roles {
					DB.Exec("INSERT INTO role_permissions (role, permission) VALUES ($1, $2) ON CONFLICT DO NOTHING", r, "procurement.submit")
					DB.Exec("INSERT INTO role_permissions (role, permission) VALUES ($1, $2) ON CONFLICT DO NOTHING", r, "procurement.approve")
					DB.Exec("INSERT INTO role_permissions (role, permission) VALUES ($1, $2) ON CONFLICT DO NOTHING", r, "procurement.purchasing")
					DB.Exec("INSERT INTO role_permissions (role, permission) VALUES ($1, $2) ON CONFLICT DO NOTHING", r, "procurement.finance")
				}
				DB.Exec("DELETE FROM role_permissions WHERE permission = 'procurement.manage'")
			}
			log.Printf("Migrated 'procurement.manage' → submit+approve+purchasing+finance for %d roles", count)
		}
	}

	// Ensure roles that had procurement.finance also get procurement.purchasing (added later)
	{
		rows, err := DB.Query("SELECT DISTINCT role FROM role_permissions WHERE permission = 'procurement.finance'")
		if err == nil {
			var roles []string
			for rows.Next() {
				var r string
				rows.Scan(&r)
				roles = append(roles, r)
			}
			rows.Close()
			for _, r := range roles {
				DB.Exec("INSERT INTO role_permissions (role, permission) VALUES ($1, 'procurement.purchasing') ON CONFLICT DO NOTHING", r)
			}
		}
	}

	// Settings table (key-value store for app-wide settings)
	settingsMigrations := []string{
		`CREATE TABLE IF NOT EXISTS app_settings (
			key VARCHAR(100) PRIMARY KEY,
			value TEXT NOT NULL DEFAULT '',
			updated_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC')
		)`,
		// Seed default settings
		`INSERT INTO app_settings (key, value) VALUES
			('company_name', ''),
			('company_address', ''),
			('company_phone', ''),
			('company_email', ''),
			('company_tax_id', ''),
			('company_logo_url', ''),
			('timezone', 'Asia/Jakarta')
		ON CONFLICT (key) DO NOTHING`,
		// SQL function: convert a TIMESTAMP to DATE in the configured timezone.
		// Treats stored timestamps as UTC, converts to app timezone, then extracts date.
		`CREATE OR REPLACE FUNCTION tz_date(ts TIMESTAMP) RETURNS DATE AS $$
			SELECT ((ts AT TIME ZONE 'UTC') AT TIME ZONE COALESCE(
				(SELECT value FROM app_settings WHERE key = 'timezone'),
				'Asia/Jakarta'
			))::date;
		$$ LANGUAGE sql STABLE`,
		// SQL function: return today's date in the configured timezone.
		`CREATE OR REPLACE FUNCTION tz_today() RETURNS DATE AS $$
			SELECT (NOW() AT TIME ZONE COALESCE(
				(SELECT value FROM app_settings WHERE key = 'timezone'),
				'Asia/Jakarta'
			))::date;
		$$ LANGUAGE sql STABLE`,
		// Tax settings
		`INSERT INTO app_settings (key, value) VALUES
			('tax_enabled', 'false'),
			('tax_rate', '10'),
			('tax_name', 'Pajak Restoran (PB1)')
		ON CONFLICT (key) DO NOTHING`,
		// Add tax_amount column to cloud_transactions
		`ALTER TABLE cloud_transactions ADD COLUMN IF NOT EXISTS tax_amount DECIMAL(15,2) DEFAULT 0`,
		// Pemisahan penjualan vs pajak vs tambahan lainnya (DPP & charges)
		`ALTER TABLE cloud_transactions ADD COLUMN IF NOT EXISTS subtotal DECIMAL(15,2) DEFAULT 0`,
		`ALTER TABLE cloud_transactions ADD COLUMN IF NOT EXISTS other_charges_total DECIMAL(15,2) DEFAULT 0`,
		`ALTER TABLE cloud_transactions ADD COLUMN IF NOT EXISTS charges JSONB`,
		// Laporan shift lengkap: jumlah transaksi per metode + kas masuk/keluar
		`ALTER TABLE cloud_cashier_shifts ADD COLUMN IF NOT EXISTS report JSONB`,
	}

	for _, m := range settingsMigrations {
		if _, err := DB.Exec(m); err != nil {
			log.Printf("Settings migration skipped: %v", err)
		}
	}

	// Grant settings permissions to all roles that have users.manage or users.update (admin-level roles)
	{
		rows, err := DB.Query("SELECT DISTINCT role FROM role_permissions WHERE permission IN ('users.manage', 'users.update')")
		if err == nil {
			var roles []string
			for rows.Next() {
				var r string
				rows.Scan(&r)
				roles = append(roles, r)
			}
			rows.Close()
			for _, r := range roles {
				DB.Exec("INSERT INTO role_permissions (role, permission) VALUES ($1, 'settings.view') ON CONFLICT DO NOTHING", r)
				DB.Exec("INSERT INTO role_permissions (role, permission) VALUES ($1, 'settings.update') ON CONFLICT DO NOTHING", r)
			}
		}
	}

	// Ensure superadmin has all CRUD permissions in DB
	allPerms := []string{
		"dashboard", "dashboard.manager",
		"outlets.view", "outlets.create", "outlets.update", "outlets.delete",
		"products.view", "products.create", "products.update", "products.delete",
		"reports",
		"procurement.view", "procurement.submit", "procurement.approve", "procurement.purchasing", "procurement.finance", "procurement.work_units", "procurement.vendors",
		"warehouse.view", "warehouse.create", "warehouse.update", "warehouse.delete",
		"users.view", "users.create", "users.update", "users.delete",
		"settings.view", "settings.update",
	}
	for _, p := range allPerms {
		DB.Exec("INSERT INTO role_permissions (role, permission) VALUES ('superadmin', $1) ON CONFLICT DO NOTHING", p)
	}

	// Vendors table
	vendorMigrations := []string{
		`CREATE TABLE IF NOT EXISTS vendors (
			id CHAR(26) PRIMARY KEY,
			name VARCHAR(200) NOT NULL,
			phone VARCHAR(50) DEFAULT '',
			email VARCHAR(200) DEFAULT '',
			address TEXT DEFAULT '',
			notes TEXT DEFAULT '',
			is_active BOOLEAN DEFAULT true,
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			updated_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC')
		)`,
		`ALTER TABLE vendors ADD COLUMN IF NOT EXISTS bank_name VARCHAR(100) DEFAULT ''`,
		`ALTER TABLE vendors ADD COLUMN IF NOT EXISTS account_number VARCHAR(50) DEFAULT ''`,
		`ALTER TABLE vendors ADD COLUMN IF NOT EXISTS account_holder VARCHAR(200) DEFAULT ''`,
	}
	for _, m := range vendorMigrations {
		if _, err := DB.Exec(m); err != nil {
			log.Printf("Vendor migration skipped: %v", err)
		}
	}

	// Seed procurement.vendors permission for admin/manager roles
	{
		rows, err := DB.Query("SELECT DISTINCT role FROM role_permissions WHERE permission = 'procurement.work_units'")
		if err == nil {
			for rows.Next() {
				var r string
				rows.Scan(&r)
				DB.Exec("INSERT INTO role_permissions (role, permission) VALUES ($1, 'procurement.vendors') ON CONFLICT DO NOTHING", r)
			}
			rows.Close()
		}
	}

	// Add vendor_id FK to purchase_requests
	vendorPurchaseMigrations := []string{
		`ALTER TABLE purchase_requests ADD COLUMN IF NOT EXISTS vendor_id CHAR(26) REFERENCES vendors(id) ON DELETE SET NULL`,
	}
	for _, m := range vendorPurchaseMigrations {
		if _, err := DB.Exec(m); err != nil {
			log.Printf("Vendor-purchase migration skipped: %v", err)
		}
	}

	// Add invoice_number to purchase_requests
	if _, err := DB.Exec(`ALTER TABLE purchase_requests ADD COLUMN IF NOT EXISTS invoice_number TEXT NOT NULL DEFAULT ''`); err != nil {
		log.Printf("Invoice number migration skipped: %v", err)
	}

	// Bank accounts table
	if _, err := DB.Exec(`CREATE TABLE IF NOT EXISTS bank_accounts (
		id CHAR(26) PRIMARY KEY,
		bank_name VARCHAR(100) NOT NULL,
		account_number VARCHAR(50) NOT NULL,
		account_holder VARCHAR(200) NOT NULL,
		is_active BOOLEAN NOT NULL DEFAULT true,
		created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
		updated_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC')
	)`); err != nil {
		log.Printf("Bank accounts migration skipped: %v", err)
	}

	// Role scope — allow roles to be scoped to specific work units
	roleScopeMigrations := []string{
		`ALTER TABLE roles ADD COLUMN IF NOT EXISTS scope_type VARCHAR(10) NOT NULL DEFAULT 'all'`,
		`CREATE TABLE IF NOT EXISTS role_work_unit_scope (
			role VARCHAR(50) NOT NULL REFERENCES roles(name) ON DELETE CASCADE,
			work_unit_id CHAR(26) NOT NULL REFERENCES work_units(id) ON DELETE CASCADE,
			PRIMARY KEY (role, work_unit_id)
		)`,
		// Add ON UPDATE CASCADE so role renames propagate without FK violations
		`ALTER TABLE role_work_unit_scope DROP CONSTRAINT IF EXISTS role_work_unit_scope_role_fkey`,
		`ALTER TABLE role_work_unit_scope ADD CONSTRAINT role_work_unit_scope_role_fkey
			FOREIGN KEY (role) REFERENCES roles(name) ON DELETE CASCADE ON UPDATE CASCADE`,
	}
	for _, m := range roleScopeMigrations {
		if _, err := DB.Exec(m); err != nil {
			log.Printf("Role scope migration skipped: %v", err)
		}
	}

	log.Printf("Ran %d migrations successfully", len(migrations))

	// Payment histories — partial payment support
	paymentHistMigrations := []string{
		`CREATE TABLE IF NOT EXISTS payment_histories (
			id CHAR(26) PRIMARY KEY,
			purchase_request_id CHAR(26) NOT NULL REFERENCES purchase_requests(id) ON DELETE CASCADE,
			amount DECIMAL(15,2) NOT NULL,
			payment_proof TEXT NOT NULL DEFAULT '',
			payment_account_dest VARCHAR(300) NOT NULL DEFAULT '',
			payment_account_source VARCHAR(300) NOT NULL DEFAULT '',
			payment_notes TEXT NOT NULL DEFAULT '',
			paid_by VARCHAR(100) NOT NULL DEFAULT '',
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC')
		)`,
		`CREATE INDEX IF NOT EXISTS idx_payment_histories_pr ON payment_histories(purchase_request_id)`,
		`ALTER TABLE purchase_requests ADD COLUMN IF NOT EXISTS paid_amount DECIMAL(15,2) NOT NULL DEFAULT 0`,
	}
	for _, m := range paymentHistMigrations {
		if _, err := DB.Exec(m); err != nil {
			log.Printf("Payment histories migration skipped: %v", err)
		}
	}

	// Warehouse / inventory module — referenced by services/warehouse.go but
	// previously created by hand on dev DBs (never had migration code).
	warehouseMigrations := []string{
		`CREATE TABLE IF NOT EXISTS stock_item_categories (
			id CHAR(26) PRIMARY KEY,
			name VARCHAR(100) NOT NULL UNIQUE,
			notes TEXT DEFAULT '',
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC')
		)`,
		`CREATE TABLE IF NOT EXISTS stock_items (
			id CHAR(26) PRIMARY KEY,
			code VARCHAR(50) NOT NULL UNIQUE,
			name VARCHAR(200) NOT NULL,
			category VARCHAR(100) DEFAULT '',
			base_unit VARCHAR(20) NOT NULL DEFAULT 'pcs',
			dist_unit VARCHAR(20) NOT NULL DEFAULT 'pcs',
			dist_ratio DECIMAL(15,4) NOT NULL DEFAULT 1,
			dist_unit_label VARCHAR(50) DEFAULT '',
			avg_cost DECIMAL(15,2) NOT NULL DEFAULT 0,
			min_stock DECIMAL(15,4) NOT NULL DEFAULT 0,
			notes TEXT DEFAULT '',
			is_active BOOLEAN DEFAULT true,
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			updated_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC')
		)`,
		`CREATE TABLE IF NOT EXISTS warehouses (
			id CHAR(26) PRIMARY KEY,
			code VARCHAR(50) NOT NULL UNIQUE,
			name VARCHAR(200) NOT NULL,
			type VARCHAR(10) NOT NULL DEFAULT 'central',
			outlet_id CHAR(26) REFERENCES outlets(id) ON DELETE SET NULL,
			address TEXT DEFAULT '',
			is_active BOOLEAN DEFAULT true,
			notes TEXT DEFAULT '',
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			updated_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC')
		)`,
		`CREATE UNIQUE INDEX IF NOT EXISTS idx_warehouses_unique_outlet_warehouse
			ON warehouses(outlet_id) WHERE type = 'outlet'`,
		`CREATE TABLE IF NOT EXISTS stock_ledger (
			id CHAR(26) PRIMARY KEY,
			item_id CHAR(26) NOT NULL REFERENCES stock_items(id) ON DELETE CASCADE,
			warehouse_id CHAR(26) NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
			qty_base DECIMAL(15,4) NOT NULL DEFAULT 0,
			avg_cost DECIMAL(15,2) NOT NULL DEFAULT 0,
			updated_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			UNIQUE(item_id, warehouse_id)
		)`,
		// Per-warehouse minimum stock (reorder level) — central & each outlet set their own.
		`ALTER TABLE stock_ledger ADD COLUMN IF NOT EXISTS min_stock DECIMAL(15,4) NOT NULL DEFAULT 0`,
		`CREATE TABLE IF NOT EXISTS stock_batches (
			id CHAR(26) PRIMARY KEY,
			item_id CHAR(26) NOT NULL REFERENCES stock_items(id) ON DELETE CASCADE,
			warehouse_id CHAR(26) NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
			qty_base DECIMAL(15,4) NOT NULL,
			cost_per_base DECIMAL(15,2) NOT NULL DEFAULT 0,
			expiry_date DATE,
			ref_id VARCHAR(50) DEFAULT '',
			ref_type VARCHAR(30) DEFAULT '',
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC')
		)`,
		`CREATE INDEX IF NOT EXISTS idx_stock_batches_fifo ON stock_batches(item_id, warehouse_id, created_at)`,
		`CREATE TABLE IF NOT EXISTS stock_movements (
			id CHAR(26) PRIMARY KEY,
			item_id CHAR(26) NOT NULL REFERENCES stock_items(id) ON DELETE CASCADE,
			warehouse_id CHAR(26) NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
			movement_type VARCHAR(30) NOT NULL,
			qty_base DECIMAL(15,4) NOT NULL,
			qty_dist DECIMAL(15,4),
			unit_used VARCHAR(20) DEFAULT '',
			cost_per_base DECIMAL(15,2) NOT NULL DEFAULT 0,
			balance_after DECIMAL(15,4),
			ref_id VARCHAR(50),
			ref_type VARCHAR(30) DEFAULT '',
			ref_number VARCHAR(50) DEFAULT '',
			notes TEXT DEFAULT '',
			created_by VARCHAR(100) DEFAULT '',
			expiry_date DATE,
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC')
		)`,
		`CREATE INDEX IF NOT EXISTS idx_stock_movements_item_wh ON stock_movements(item_id, warehouse_id, created_at)`,
		`CREATE INDEX IF NOT EXISTS idx_stock_movements_ref ON stock_movements(ref_type, ref_number)`,
		`CREATE TABLE IF NOT EXISTS stock_transfers (
			id CHAR(26) PRIMARY KEY,
			transfer_number VARCHAR(30) NOT NULL UNIQUE,
			from_warehouse_id CHAR(26) NOT NULL REFERENCES warehouses(id),
			to_warehouse_id CHAR(26) NOT NULL REFERENCES warehouses(id),
			status VARCHAR(20) NOT NULL DEFAULT 'draft',
			notes TEXT DEFAULT '',
			created_by VARCHAR(100) DEFAULT '',
			approved_by VARCHAR(100),
			approved_at TIMESTAMP,
			sent_by VARCHAR(100),
			sent_at TIMESTAMP,
			received_by VARCHAR(100),
			received_at TIMESTAMP,
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			updated_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC')
		)`,
		`CREATE TABLE IF NOT EXISTS stock_transfer_items (
			id CHAR(26) PRIMARY KEY,
			transfer_id CHAR(26) NOT NULL REFERENCES stock_transfers(id) ON DELETE CASCADE,
			item_id CHAR(26) NOT NULL REFERENCES stock_items(id),
			qty_dist DECIMAL(15,4) NOT NULL,
			qty_base DECIMAL(15,4) NOT NULL,
			unit_used VARCHAR(20) DEFAULT '',
			received_qty_base DECIMAL(15,4),
			notes TEXT DEFAULT ''
		)`,
		`CREATE TABLE IF NOT EXISTS product_recipes (
			id CHAR(26) PRIMARY KEY,
			product_id CHAR(26) NOT NULL,
			item_id CHAR(26) NOT NULL REFERENCES stock_items(id) ON DELETE CASCADE,
			qty_dist DECIMAL(15,4) NOT NULL,
			qty_base DECIMAL(15,4) NOT NULL,
			unit_used VARCHAR(20) DEFAULT '',
			visibility VARCHAR(10) NOT NULL DEFAULT 'public',
			notes TEXT DEFAULT ''
		)`,
		`CREATE INDEX IF NOT EXISTS idx_product_recipes_product ON product_recipes(product_id)`,
		`CREATE TABLE IF NOT EXISTS recipe_masters (
			id CHAR(26) PRIMARY KEY,
			name VARCHAR(200) NOT NULL,
			description TEXT DEFAULT '',
			visibility VARCHAR(10) NOT NULL DEFAULT 'public',
			instructions TEXT DEFAULT '',
			total_time INTEGER DEFAULT 0,
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC'),
			updated_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC')
		)`,
		`CREATE TABLE IF NOT EXISTS recipe_items (
			id CHAR(26) PRIMARY KEY,
			recipe_master_id CHAR(26) NOT NULL REFERENCES recipe_masters(id) ON DELETE CASCADE,
			item_id CHAR(26) NOT NULL REFERENCES stock_items(id) ON DELETE CASCADE,
			qty_base DECIMAL(15,4) NOT NULL,
			notes TEXT DEFAULT ''
		)`,
		`CREATE TABLE IF NOT EXISTS recipe_outlet_access (
			recipe_master_id CHAR(26) NOT NULL REFERENCES recipe_masters(id) ON DELETE CASCADE,
			outlet_id CHAR(26) NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
			PRIMARY KEY (recipe_master_id, outlet_id)
		)`,
		`CREATE TABLE IF NOT EXISTS stock_item_recipes (
			id CHAR(26) PRIMARY KEY,
			parent_item_id CHAR(26) NOT NULL REFERENCES stock_items(id) ON DELETE CASCADE,
			child_item_id CHAR(26) NOT NULL REFERENCES stock_items(id) ON DELETE CASCADE,
			qty_base DECIMAL(15,4) NOT NULL,
			notes TEXT DEFAULT '',
			visibility VARCHAR(10) NOT NULL DEFAULT 'public'
		)`,
		`CREATE INDEX IF NOT EXISTS idx_stock_item_recipes_parent ON stock_item_recipes(parent_item_id)`,
		`CREATE TABLE IF NOT EXISTS stock_wastes (
			id CHAR(26) PRIMARY KEY,
			waste_number VARCHAR(30) NOT NULL UNIQUE,
			warehouse_id CHAR(26) NOT NULL REFERENCES warehouses(id),
			item_id CHAR(26) NOT NULL REFERENCES stock_items(id),
			qty_base DECIMAL(15,4) NOT NULL,
			qty_dist DECIMAL(15,4),
			unit_used VARCHAR(20) DEFAULT '',
			cost_per_base DECIMAL(15,2) NOT NULL DEFAULT 0,
			total_cost DECIMAL(15,2) NOT NULL DEFAULT 0,
			reason VARCHAR(20) DEFAULT '',
			notes TEXT DEFAULT '',
			created_by VARCHAR(100) DEFAULT '',
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC')
		)`,
		// Link cloud_products to the warehouse module (stock type, single-item link, master recipe)
		`ALTER TABLE cloud_products ADD COLUMN IF NOT EXISTS stock_type VARCHAR(10) NOT NULL DEFAULT 'none'`,
		`ALTER TABLE cloud_products ADD COLUMN IF NOT EXISTS linked_stock_item_id CHAR(26) REFERENCES stock_items(id) ON DELETE SET NULL`,
		`ALTER TABLE cloud_products ADD COLUMN IF NOT EXISTS recipe_master_id CHAR(26) REFERENCES recipe_masters(id) ON DELETE SET NULL`,
	}
	for _, m := range warehouseMigrations {
		if _, err := DB.Exec(m); err != nil {
			log.Printf("Warehouse migration skipped: %v", err)
		}
	}

	// Seed missing permissions for existing roles
	{
		// Warehouse CRUD permissions — were previously seeded as warehouse.manage (now converted)
		warehousePerms := []string{"warehouse.view", "warehouse.create", "warehouse.update", "warehouse.delete"}
		warehouseRoles := []string{"superadmin", "admin", "manager"}
		for _, role := range warehouseRoles {
			for _, perm := range warehousePerms {
				DB.Exec("INSERT INTO role_permissions (role, permission) VALUES ($1, $2) ON CONFLICT DO NOTHING", role, perm)
			}
		}

		// Procurement full permissions for admin
		procurementPerms := []string{"procurement.view", "procurement.submit", "procurement.approve", "procurement.purchasing", "procurement.finance"}
		for _, perm := range procurementPerms {
			DB.Exec("INSERT INTO role_permissions (role, permission) VALUES ('admin', $1) ON CONFLICT DO NOTHING", perm)
		}
		// Manager gets procurement.view so the menu shows
		DB.Exec("INSERT INTO role_permissions (role, permission) VALUES ('manager', 'procurement.view') ON CONFLICT DO NOTHING")
	}

	// Migrate .manage → granular CRUD permissions (one-time, idempotent)
	{
		manageToCRUD := map[string][]string{
			"outlets.manage":  {"outlets.create", "outlets.update", "outlets.delete"},
			"products.manage": {"products.create", "products.update", "products.delete"},
			"warehouse.manage": {"warehouse.create", "warehouse.update", "warehouse.delete"},
			"users.manage":    {"users.create", "users.update", "users.delete"},
			"settings.manage": {"settings.update"},
		}
		for oldPerm, newPerms := range manageToCRUD {
			var count int
			DB.QueryRow("SELECT COUNT(*) FROM role_permissions WHERE permission = $1", oldPerm).Scan(&count)
			if count > 0 {
				rows, err := DB.Query("SELECT role FROM role_permissions WHERE permission = $1", oldPerm)
				if err == nil {
					var roles []string
					for rows.Next() {
						var r string
						rows.Scan(&r)
						roles = append(roles, r)
					}
					rows.Close()
					for _, r := range roles {
						for _, np := range newPerms {
							DB.Exec("INSERT INTO role_permissions (role, permission) VALUES ($1, $2) ON CONFLICT DO NOTHING", r, np)
						}
					}
					DB.Exec("DELETE FROM role_permissions WHERE permission = $1", oldPerm)
				}
				log.Printf("Migrated '%s' → %v for %d roles", oldPerm, newPerms, count)
			}
		}
	}

	// Ensure superadmin has all CRUD permissions (runs after conversion)
	{
		allPerms := []string{
			"dashboard", "dashboard.manager",
			"outlets.view", "outlets.create", "outlets.update", "outlets.delete",
			"products.view", "products.create", "products.update", "products.delete",
			"reports",
			"procurement.view", "procurement.submit", "procurement.approve", "procurement.purchasing", "procurement.finance", "procurement.work_units", "procurement.vendors",
			"warehouse.view", "warehouse.create", "warehouse.update", "warehouse.delete",
			"users.view", "users.create", "users.update", "users.delete",
			"settings.view", "settings.update",
		}
		for _, p := range allPerms {
			DB.Exec("INSERT INTO role_permissions (role, permission) VALUES ('superadmin', $1) ON CONFLICT DO NOTHING", p)
		}
	}

	// Access logs (login/access history — superadmin only)
	accessLogMigrations := []string{
		`CREATE TABLE IF NOT EXISTS access_logs (
			id CHAR(26) PRIMARY KEY,
			username VARCHAR(100) NOT NULL DEFAULT '',
			role VARCHAR(50) NOT NULL DEFAULT '',
			status VARCHAR(20) NOT NULL DEFAULT 'success',
			ip VARCHAR(64) NOT NULL DEFAULT '',
			user_agent TEXT NOT NULL DEFAULT '',
			browser VARCHAR(80) NOT NULL DEFAULT '',
			os VARCHAR(80) NOT NULL DEFAULT '',
			device VARCHAR(40) NOT NULL DEFAULT '',
			created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'UTC')
		)`,
		`CREATE INDEX IF NOT EXISTS idx_access_logs_created ON access_logs(created_at DESC)`,
		`CREATE INDEX IF NOT EXISTS idx_access_logs_username ON access_logs(username)`,
	}
	for _, m := range accessLogMigrations {
		if _, err := DB.Exec(m); err != nil {
			log.Printf("Access logs migration skipped: %v", err)
		}
	}

	// ── Granular per-submenu permission migration (v2) ──────────────────────
	// Split coarse keys into per-submenu granular keys so existing roles keep
	// equivalent access. Replace-style: the old key is deleted after expansion.
	granularSplit := map[string][]string{
		"reports": {
			"reports.sales.view", "reports.product_sales.view", "reports.ledger.view",
			"reports.cashflow.view", "reports.pnl.view", "reports.balance.view",
			"reports.tax.view", "reports.void.view",
		},
		"warehouse.view": {
			"warehouse_dashboard.view", "warehouses.view", "stockitems.view",
			"stocktransfers.view", "stockwastes.view", "stockledger.view", "recipes.view",
		},
		"warehouse.create": {
			"warehouses.create", "stockitems.create", "stocktransfers.create",
			"stockwastes.create", "stockledger.adjust", "recipes.create",
		},
		"warehouse.update": {"warehouses.update", "stockitems.update", "stocktransfers.update", "recipes.update"},
		"warehouse.delete": {"warehouses.delete", "stockitems.delete", "recipes.delete"},

		"procurement.view":       {"procurement.dashboard.view", "procurement.requests.view", "vendors.view"},
		"procurement.submit":     {"procurement.requests.submit"},
		"procurement.approve":    {"procurement.requests.approve"},
		"procurement.purchasing": {"procurement.requests.purchasing"},
		"procurement.finance":    {"finance.payments.view", "finance.bank.view", "finance.bank.create", "finance.bank.update", "finance.bank.delete"},
		"procurement.vendors":    {"vendors.create", "vendors.update", "vendors.delete"},
		"procurement.work_units": {"workunits.view", "workunits.create", "workunits.update", "workunits.delete"},

		"settings.view":   {"settings.company.view", "settings.timezone.view", "settings.tax.view"},
		"settings.update": {"settings.company.update", "settings.timezone.update", "settings.tax.update"},
		"settings.manage": {"settings.company.view", "settings.timezone.view", "settings.tax.view", "settings.company.update", "settings.timezone.update", "settings.tax.update"},

		"outlets.manage":  {"outlets.create", "outlets.update", "outlets.delete"},
		"products.manage": {"products.create", "products.update", "products.delete"},
		"users.manage":    {"users.create", "users.update", "users.delete", "roles.create", "roles.update", "roles.delete"},
	}
	for old, news := range granularSplit {
		var count int
		DB.QueryRow("SELECT COUNT(*) FROM role_permissions WHERE permission = $1", old).Scan(&count)
		if count == 0 {
			continue
		}
		rows, err := DB.Query("SELECT role FROM role_permissions WHERE permission = $1", old)
		if err != nil {
			continue
		}
		var rls []string
		for rows.Next() {
			var r string
			rows.Scan(&r)
			rls = append(rls, r)
		}
		rows.Close()
		for _, r := range rls {
			for _, np := range news {
				DB.Exec("INSERT INTO role_permissions (role, permission) VALUES ($1, $2) ON CONFLICT DO NOTHING", r, np)
			}
		}
		DB.Exec("DELETE FROM role_permissions WHERE permission = $1", old)
		log.Printf("Granular migration: '%s' → %d keys for %d roles", old, len(news), count)
	}

	// Additive: split 'users' module into users (admins) + roles. Keep users.* AND mirror to roles.*.
	for u, rl := range map[string]string{
		"users.view": "roles.view", "users.create": "roles.create",
		"users.update": "roles.update", "users.delete": "roles.delete",
	} {
		DB.Exec(`INSERT INTO role_permissions (role, permission)
			SELECT role, $2 FROM role_permissions WHERE permission = $1
			ON CONFLICT DO NOTHING`, u, rl)
	}

	// Ensure system 'admin' role always holds the full granular permission set.
	adminAll := []string{
		"dashboard",
		"outlets.view", "outlets.create", "outlets.update", "outlets.delete",
		"workunits.view", "workunits.create", "workunits.update", "workunits.delete",
		"products.view", "products.create", "products.update", "products.delete",
		"reports.sales.view", "reports.product_sales.view", "reports.ledger.view",
		"reports.cashflow.view", "reports.pnl.view", "reports.balance.view",
		"reports.tax.view", "reports.void.view",
		"finance.payments.view", "finance.bank.view", "finance.bank.create", "finance.bank.update", "finance.bank.delete",
		"procurement.dashboard.view", "procurement.requests.view", "procurement.requests.submit",
		"procurement.requests.approve", "procurement.requests.purchasing",
		"vendors.view", "vendors.create", "vendors.update", "vendors.delete",
		"users.view", "users.create", "users.update", "users.delete",
		"roles.view", "roles.create", "roles.update", "roles.delete",
		"access_logs.view",
		"warehouse_dashboard.view",
		"warehouses.view", "warehouses.create", "warehouses.update", "warehouses.delete",
		"stockitems.view", "stockitems.create", "stockitems.update", "stockitems.delete",
		"stocktransfers.view", "stocktransfers.create", "stocktransfers.update",
		"stockwastes.view", "stockwastes.create",
		"stockledger.view", "stockledger.adjust",
		"recipes.view", "recipes.create", "recipes.update", "recipes.delete",
		"settings.company.view", "settings.company.update",
		"settings.timezone.view", "settings.timezone.update",
		"settings.tax.view", "settings.tax.update",
	}
	for _, p := range adminAll {
		DB.Exec("INSERT INTO role_permissions (role, permission) VALUES ('admin', $1) ON CONFLICT DO NOTHING", p)
	}

	return nil
}
