package services

import (
	"cloud-pos/database"
	"cloud-pos/models"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/oklog/ulid/v2"
	"golang.org/x/crypto/bcrypt"
)

// ── Helpers ─────────────────────────────────────────────────

var (
	entropyMu sync.Mutex
	entropy   = ulid.Monotonic(rand.Reader, 0)
)

func NewULID() string {
	entropyMu.Lock()
	defer entropyMu.Unlock()
	t := time.Now().UTC()
	id, err := ulid.New(ulid.Timestamp(t), entropy)
	if err != nil {
		// Reset entropy on overflow
		entropy = ulid.Monotonic(rand.Reader, 0)
		id = ulid.MustNew(ulid.Timestamp(t), entropy)
	}
	return id.String()
}

func GenerateAPIKey() string {
	b := make([]byte, 32)
	rand.Read(b)
	return "pos_" + hex.EncodeToString(b)
}

// normalizeSyncFields mengkonversi field names dari POS trigger ke cloud model
// POS trigger menggunakan nama kolom SQLite, cloud model pakai nama JSON sendiri
func normalizeSyncFields(data map[string]interface{}, entityType string) {
	if data == nil {
		return
	}

	// Universal: id → local_id (semua entity)
	if _, ok := data["local_id"]; !ok {
		if id, ok := data["id"]; ok {
			data["local_id"] = id
		}
	}

	switch entityType {
	case "order":
		// order_status → status
		if _, ok := data["status"]; !ok {
			if v, ok := data["order_status"]; ok {
				data["status"] = v
			}
		}
		// created_by → customer_name (sebagai fallback jika customer_name kosong)
		if _, ok := data["customer_name"]; !ok {
			if v, ok := data["created_by"]; ok {
				data["customer_name"] = v
			}
		}
		// Pastikan created_at ada (dari trigger mungkin tidak ada)
		if _, ok := data["created_at"]; !ok {
			data["created_at"] = time.Now().UTC().Format(time.RFC3339)
		}
		if _, ok := data["updated_at"]; !ok {
			data["updated_at"] = time.Now().UTC().Format(time.RFC3339)
		}

	case "transaction":
		// transaction_date → created_at
		if _, ok := data["created_at"]; !ok {
			if v, ok := data["transaction_date"]; ok {
				data["created_at"] = v
			}
		}
		// created_by → cashier_name
		if _, ok := data["cashier_name"]; !ok {
			if v, ok := data["created_by"]; ok {
				data["cashier_name"] = v
			}
		}
	}
}

// ── Outlet Service ──────────────────────────────────────────

func CreateOutlet(req models.CreateOutletRequest) (*models.Outlet, error) {
	apiKey := GenerateAPIKey()
	outlet := &models.Outlet{}
	id := NewULID()

	err := database.DB.QueryRow(
		`INSERT INTO outlets (id, code, name, address, phone, api_key, webhook_url)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, code, name, address, COALESCE(phone,''), api_key, COALESCE(webhook_url,''), is_active, created_at, updated_at`,
		id, req.Code, req.Name, req.Address, req.Phone, apiKey, req.WebhookURL,
	).Scan(&outlet.ID, &outlet.Code, &outlet.Name, &outlet.Address,
		&outlet.Phone, &outlet.APIKey, &outlet.WebhookURL, &outlet.IsActive,
		&outlet.CreatedAt, &outlet.UpdatedAt)

	if err != nil {
		return nil, err
	}
	return outlet, nil
}

func GetOutlets() ([]models.Outlet, error) {
	rows, err := database.DB.Query(
		`SELECT id, code, name, COALESCE(address,''), COALESCE(phone,''), COALESCE(webhook_url,''), is_active, created_at, updated_at
		FROM outlets ORDER BY created_at DESC`,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	outlets := make([]models.Outlet, 0)
	for rows.Next() {
		var o models.Outlet
		if err := rows.Scan(&o.ID, &o.Code, &o.Name, &o.Address,
			&o.Phone, &o.WebhookURL, &o.IsActive, &o.CreatedAt, &o.UpdatedAt); err != nil {
			return nil, err
		}
		outlets = append(outlets, o)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return outlets, nil
}

func GetOutlet(id string) (*models.Outlet, error) {
	o := &models.Outlet{}
	err := database.DB.QueryRow(
		`SELECT TRIM(id), code, name, COALESCE(address,''), COALESCE(phone,''), COALESCE(api_key,''), COALESCE(webhook_url,''), is_active, created_at, updated_at
		FROM outlets WHERE TRIM(id) = $1`, strings.TrimSpace(id),
	).Scan(&o.ID, &o.Code, &o.Name, &o.Address,
		&o.Phone, &o.APIKey, &o.WebhookURL, &o.IsActive, &o.CreatedAt, &o.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return o, nil
}

func UpdateOutlet(id string, req models.UpdateOutletRequest) (*models.Outlet, error) {
	o := &models.Outlet{}
	err := database.DB.QueryRow(
		`UPDATE outlets SET name = $1, address = $2, phone = $3, webhook_url = $4, updated_at = NOW()
		WHERE TRIM(id) = $5
		RETURNING id, code, name, COALESCE(address,''), COALESCE(phone,''), COALESCE(api_key,''), COALESCE(webhook_url,''), is_active, created_at, updated_at`,
		req.Name, req.Address, req.Phone, req.WebhookURL, strings.TrimSpace(id),
	).Scan(&o.ID, &o.Code, &o.Name, &o.Address,
		&o.Phone, &o.APIKey, &o.WebhookURL, &o.IsActive, &o.CreatedAt, &o.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return o, nil
}

func RegenerateAPIKey(id string) (string, error) {
	newKey := GenerateAPIKey()
	result, err := database.DB.Exec(
		`UPDATE outlets SET api_key = $1, updated_at = NOW() WHERE id = $2`,
		newKey, id,
	)
	if err != nil {
		return "", err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return "", fmt.Errorf("outlet not found")
	}
	return newKey, nil
}

func ToggleOutlet(id string) (*models.Outlet, error) {
	o := &models.Outlet{}
	err := database.DB.QueryRow(
		`UPDATE outlets SET is_active = NOT is_active, updated_at = NOW()
		WHERE id = $1
		RETURNING id, code, name, COALESCE(address,''), COALESCE(phone,''), COALESCE(webhook_url,''), is_active, created_at, updated_at`,
		id,
	).Scan(&o.ID, &o.Code, &o.Name, &o.Address,
		&o.Phone, &o.WebhookURL, &o.IsActive, &o.CreatedAt, &o.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return o, nil
}

func DeleteOutlet(id string) error {
	tx, err := database.DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// Delete related data in order
	relatedTables := []string{
		"cloud_cash_movements",
		"cloud_cashier_shifts",
		"sync_conflicts",
		"sync_logs",
		"cloud_analytics",
		"cloud_printers",
		"cloud_orders",
		"cloud_transactions",
		"cloud_products",
		"cloud_categories",
	}
	for _, table := range relatedTables {
		_, err := tx.Exec(fmt.Sprintf("DELETE FROM %s WHERE outlet_id = $1", table), strings.TrimSpace(id))
		if err != nil {
			return fmt.Errorf("failed to delete from %s: %w", table, err)
		}
	}

	result, err := tx.Exec("DELETE FROM outlets WHERE TRIM(id) = $1", strings.TrimSpace(id))
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("outlet not found")
	}
	return tx.Commit()
}

// ── Order Service ───────────────────────────────────────────

func SaveOrder(outletID string, req models.PushOrderRequest) (string, error) {
	itemsJSON, _ := json.Marshal(req.Items)
	paymentJSON, _ := json.Marshal(req.PaymentInfo)

	// id = local_id (ID sama di POS dan Cloud)
	cloudID := req.LocalID
	if cloudID == "" {
		cloudID = NewULID()
	}
	err := database.DB.QueryRow(
		`INSERT INTO cloud_orders (id, local_id, outlet_id, outlet_code, table_number,
			customer_name, pax, total_amount, status, items, payment_info, version,
			created_at, updated_at, synced_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, NOW())
		ON CONFLICT (outlet_id, local_id) DO UPDATE SET
			id = EXCLUDED.id,
			table_number = EXCLUDED.table_number,
			customer_name = EXCLUDED.customer_name,
			pax = EXCLUDED.pax,
			total_amount = EXCLUDED.total_amount,
			status = EXCLUDED.status,
			items = EXCLUDED.items,
			payment_info = EXCLUDED.payment_info,
			version = EXCLUDED.version,
			updated_at = EXCLUDED.updated_at,
			synced_at = NOW()
		RETURNING id`,
		cloudID, cloudID, outletID, req.OutletCode, req.TableNumber,
		req.CustomerName, req.Pax, req.TotalAmount, req.Status,
		string(itemsJSON), string(paymentJSON), req.Version,
		parseTime(req.CreatedAt), parseTime(req.UpdatedAt),
	).Scan(&cloudID)

	if err != nil {
		return "", err
	}

	go logSync(outletID, "push_order", "order", 1, "success", "")
	return cloudID, nil
}

func GetOrders(outletID string, page, limit int) ([]models.CloudOrder, int, error) {
	offset := (page - 1) * limit
	var total int
	database.DB.QueryRow("SELECT COUNT(*) FROM cloud_orders WHERE outlet_id = $1", outletID).Scan(&total)

	rows, err := database.DB.Query(
		`SELECT id, local_id, outlet_id, outlet_code, COALESCE(table_number,''),
			COALESCE(customer_name,''), pax, total_amount, status,
			COALESCE(items::text,'[]'), COALESCE(payment_info::text,'{}'),
			version, created_at, updated_at, synced_at
		FROM cloud_orders WHERE outlet_id = $1
		ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
		outletID, limit, offset,
	)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	orders := make([]models.CloudOrder, 0)
	for rows.Next() {
		var o models.CloudOrder
		if err := rows.Scan(&o.ID, &o.LocalID, &o.OutletID, &o.OutletCode,
			&o.TableNumber, &o.CustomerName, &o.Pax, &o.TotalAmount, &o.Status,
			&o.Items, &o.PaymentInfo, &o.Version, &o.CreatedAt, &o.UpdatedAt, &o.SyncedAt); err != nil {
			return nil, 0, err
		}
		orders = append(orders, o)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, err
	}
	return orders, total, nil
}

// ── Transaction Service ─────────────────────────────────────

func SaveTransaction(outletID string, req models.PushTransactionRequest) (string, error) {
	// id = local_id (ID sama di POS dan Cloud)
	cloudID := req.LocalID
	if cloudID == "" {
		cloudID = NewULID()
	}

	// Serialize items ke JSON
	itemsJSON := "[]"
	if len(req.Items) > 0 {
		b, _ := json.Marshal(req.Items)
		itemsJSON = string(b)
	}

	err := database.DB.QueryRow(
		`INSERT INTO cloud_transactions (id, local_id, outlet_id, outlet_code, order_id,
			total_amount, payment_method, cash_amount, change_amount, cashier_name,
			items, version, created_at, synced_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, NOW())
		ON CONFLICT (outlet_id, local_id) DO UPDATE SET
			id = EXCLUDED.id,
			total_amount = EXCLUDED.total_amount,
			payment_method = EXCLUDED.payment_method,
			cash_amount = EXCLUDED.cash_amount,
			change_amount = EXCLUDED.change_amount,
			cashier_name = EXCLUDED.cashier_name,
			items = EXCLUDED.items,
			version = EXCLUDED.version,
			synced_at = NOW()
		RETURNING id`,
		cloudID, cloudID, outletID, req.OutletCode, req.OrderID,
		req.TotalAmount, req.PaymentMethod, req.CashAmount,
		req.ChangeAmount, req.CashierName, itemsJSON, req.Version,
		parseTime(req.CreatedAt),
	).Scan(&cloudID)

	if err != nil {
		return "", err
	}

	go logSync(outletID, "push_transaction", "transaction", 1, "success", "")
	return cloudID, nil
}

func GetTransactions(outletID string, page, limit int) ([]models.CloudTransaction, int, error) {
	offset := (page - 1) * limit
	var total int
	database.DB.QueryRow("SELECT COUNT(*) FROM cloud_transactions WHERE outlet_id = $1", outletID).Scan(&total)

	rows, err := database.DB.Query(
		`SELECT id, local_id, outlet_id, outlet_code, COALESCE(order_id,''),
			total_amount, COALESCE(payment_method,''), cash_amount, change_amount,
			COALESCE(cashier_name,''), COALESCE(items::text,'[]'), version, created_at, synced_at
		FROM cloud_transactions WHERE outlet_id = $1
		ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
		outletID, limit, offset,
	)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	txns := make([]models.CloudTransaction, 0)
	for rows.Next() {
		var t models.CloudTransaction
		if err := rows.Scan(&t.ID, &t.LocalID, &t.OutletID, &t.OutletCode,
			&t.OrderID, &t.TotalAmount, &t.PaymentMethod, &t.CashAmount,
			&t.ChangeAmount, &t.CashierName, &t.Items, &t.Version, &t.CreatedAt, &t.SyncedAt); err != nil {
			return nil, 0, err
		}
		txns = append(txns, t)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, err
	}
	return txns, total, nil
}

// ── Product Service ─────────────────────────────────────────

func SaveProduct(outletID string, req models.PushProductRequest) (string, error) {
	// Gunakan POS local_id sebagai cloud id agar ID produk sama di POS dan Cloud
	cloudID := req.LocalID
	err := database.DB.QueryRow(
		`INSERT INTO cloud_products (id, local_id, outlet_id, name, code, description, category_id,
			category_name, price, stock, destination, version, updated_at, synced_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, COALESCE($13, NOW()), NOW())
		ON CONFLICT (outlet_id, local_id) DO UPDATE SET
			id = EXCLUDED.id,
			name = EXCLUDED.name,
			code = EXCLUDED.code,
			description = EXCLUDED.description,
			category_id = EXCLUDED.category_id,
			category_name = EXCLUDED.category_name,
			price = EXCLUDED.price,
			stock = EXCLUDED.stock,
			destination = EXCLUDED.destination,
			version = EXCLUDED.version,
			updated_at = NOW(),
			synced_at = NOW()
		RETURNING id`,
		cloudID, cloudID, outletID, req.Name, nullStr(req.Code), req.Description, req.CategoryID,
		req.CategoryName, req.Price, req.Stock, req.Destination,
		req.Version, parseTime(req.UpdatedAt),
	).Scan(&cloudID)

	if err != nil {
		return "", err
	}

	go logSync(outletID, "push_product", "product", 1, "success", "")
	return cloudID, nil
}

func GetProducts(outletID string, page, limit int) ([]models.CloudProduct, int, error) {
	offset := (page - 1) * limit
	var total int
	database.DB.QueryRow("SELECT COUNT(*) FROM cloud_products WHERE outlet_id = $1 AND is_deleted = false", outletID).Scan(&total)

	rows, err := database.DB.Query(
		`SELECT id, local_id, outlet_id, name, COALESCE(code,''), COALESCE(description,''),
			COALESCE(category_id,''),
			COALESCE(category_name,''), price, stock, COALESCE(destination,''),
			is_deleted, version, created_at, updated_at, synced_at
		FROM cloud_products WHERE outlet_id = $1 AND is_deleted = false
		ORDER BY name ASC LIMIT $2 OFFSET $3`,
		outletID, limit, offset,
	)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	products := make([]models.CloudProduct, 0)
	for rows.Next() {
		var p models.CloudProduct
		if err := rows.Scan(&p.ID, &p.LocalID, &p.OutletID, &p.Name, &p.Code, &p.Description,
			&p.CategoryID, &p.CategoryName, &p.Price, &p.Stock, &p.Destination,
			&p.IsDeleted, &p.Version, &p.CreatedAt, &p.UpdatedAt, &p.SyncedAt); err != nil {
			return nil, 0, err
		}
		products = append(products, p)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, err
	}
	return products, total, nil
}

// GetAllProducts fetches products across all outlets for admin view.
// Pass empty outletID / search to skip those filters.
func GetAllProducts(outletID, search string, page, limit int) ([]models.CloudProduct, int, error) {
	offset := (page - 1) * limit

	// ── dynamic WHERE ────────────────────────────────────────
	conds := []string{"cp.is_deleted = false"}
	args := []any{}
	idx := 1

	if outletID != "" {
		conds = append(conds, fmt.Sprintf("cp.outlet_id = $%d", idx))
		args = append(args, outletID)
		idx++
	}
	if search != "" {
		conds = append(conds, fmt.Sprintf("(cp.name ILIKE $%d OR cp.code ILIKE $%d OR cp.category_name ILIKE $%d)", idx, idx, idx))
		args = append(args, "%"+search+"%")
		idx++
	}
	whereSQL := "WHERE " + strings.Join(conds, " AND ")

	// COUNT
	var total int
	database.DB.QueryRow(
		fmt.Sprintf("SELECT COUNT(*) FROM cloud_products cp %s", whereSQL),
		args...,
	).Scan(&total)

	// DATA
	dataArgs := append(append([]any{}, args...), limit, offset)
	dataQuery := fmt.Sprintf(
		`SELECT cp.id, cp.local_id, cp.outlet_id, COALESCE(o.name,''),
			cp.name, COALESCE(cp.code,''), COALESCE(cp.description,''),
			COALESCE(cp.category_id,''), COALESCE(cp.category_name,''),
			cp.price, cp.stock, COALESCE(cp.destination,''),
			cp.is_deleted, cp.version, cp.created_at, cp.updated_at, cp.synced_at
		FROM cloud_products cp
		LEFT JOIN outlets o ON o.id = cp.outlet_id
		%s ORDER BY o.name ASC, cp.name ASC LIMIT $%d OFFSET $%d`,
		whereSQL, idx, idx+1,
	)
	rows, err := database.DB.Query(dataQuery, dataArgs...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	products := make([]models.CloudProduct, 0)
	for rows.Next() {
		var p models.CloudProduct
		if err := rows.Scan(&p.ID, &p.LocalID, &p.OutletID, &p.OutletName,
			&p.Name, &p.Code, &p.Description, &p.CategoryID, &p.CategoryName, &p.Price, &p.Stock, &p.Destination,
			&p.IsDeleted, &p.Version, &p.CreatedAt, &p.UpdatedAt, &p.SyncedAt); err != nil {
			return nil, 0, err
		}
		products = append(products, p)
	}
	return products, total, rows.Err()
}

// GetAllCategories fetches categories across all outlets for admin view.
// Pass empty outletID / search to skip those filters.
func GetAllCategories(outletID, search string, page, limit int) ([]models.CloudCategory, int, error) {
	offset := (page - 1) * limit

	// ── dynamic WHERE ────────────────────────────────────────
	conds := []string{"cc.is_deleted = false"}
	args := []any{}
	idx := 1

	if outletID != "" {
		conds = append(conds, fmt.Sprintf("cc.outlet_id = $%d", idx))
		args = append(args, outletID)
		idx++
	}
	if search != "" {
		conds = append(conds, fmt.Sprintf("(cc.name ILIKE $%d OR cc.code_prefix ILIKE $%d)", idx, idx))
		args = append(args, "%"+search+"%")
		idx++
	}
	whereSQL := "WHERE " + strings.Join(conds, " AND ")

	// COUNT
	var total int
	database.DB.QueryRow(
		fmt.Sprintf("SELECT COUNT(*) FROM cloud_categories cc %s", whereSQL),
		args...,
	).Scan(&total)

	// DATA
	dataArgs := append(append([]any{}, args...), limit, offset)
	dataQuery := fmt.Sprintf(
		`SELECT cc.id, COALESCE(cc.local_id,''), cc.outlet_id, COALESCE(o.name,''),
			cc.name, COALESCE(cc.code_prefix,''), COALESCE(cc.printer_id,''),
			cc.is_deleted, cc.version, cc.created_at, cc.updated_at, cc.synced_at
		FROM cloud_categories cc
		LEFT JOIN outlets o ON o.id = cc.outlet_id
		%s ORDER BY o.name ASC, cc.name ASC LIMIT $%d OFFSET $%d`,
		whereSQL, idx, idx+1,
	)
	rows, err := database.DB.Query(dataQuery, dataArgs...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	cats := make([]models.CloudCategory, 0)
	for rows.Next() {
		var cat models.CloudCategory
		if err := rows.Scan(&cat.ID, &cat.LocalID, &cat.OutletID, &cat.OutletName,
			&cat.Name, &cat.CodePrefix, &cat.PrinterID,
			&cat.IsDeleted, &cat.Version, &cat.CreatedAt, &cat.UpdatedAt, &cat.SyncedAt); err != nil {
			return nil, 0, err
		}
		cats = append(cats, cat)
	}
	return cats, total, rows.Err()
}

// ── Admin CRUD ──────────────────────────────────────────────

func AdminCreateProduct(req models.AdminCreateProductRequest) (models.CloudProduct, error) {
	if req.OutletID == "" || req.Name == "" {
		return models.CloudProduct{}, fmt.Errorf("outlet_id and name are required")
	}
	id := ulid.Make().String()
	now := time.Now()

	// Resolve category_name dari category_id
	if req.CategoryID != "" {
		var catName string
		err := database.DB.QueryRow(
			"SELECT name FROM cloud_categories WHERE id = $1 AND is_deleted = false",
			req.CategoryID,
		).Scan(&catName)
		if err == nil {
			if req.CategoryName == "" {
				req.CategoryName = catName
			}
		}
	}

	// Auto-generate product code dari huruf pertama nama produk
	if req.Code == "" {
		req.Code = generateProductCode(req.OutletID, req.Name)
	}

	_, err := database.DB.Exec(
		`INSERT INTO cloud_products
			(id, local_id, outlet_id, name, code, description, category_id, category_name,
			 price, stock, destination, version, created_at, updated_at, synced_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,1,$12,$13,$14)`,
		id, id, req.OutletID, req.Name, nullStr(req.Code), req.Description, req.CategoryID, req.CategoryName,
		req.Price, req.Stock, req.Destination, now, now, now,
	)
	if err != nil {
		return models.CloudProduct{}, err
	}
	return models.CloudProduct{
		ID: id, LocalID: id, OutletID: req.OutletID,
		Name: req.Name, Code: req.Code, Description: req.Description,
		CategoryID: req.CategoryID, CategoryName: req.CategoryName,
		Price: req.Price, Stock: req.Stock, Destination: req.Destination,
		Version: 1, CreatedAt: now, UpdatedAt: now, SyncedAt: now,
	}, nil
}

func AdminUpdateProduct(id string, req models.AdminUpdateProductRequest) error {
	// Resolve category_name dari category_id
	if req.CategoryID != "" {
		var catName string
		err := database.DB.QueryRow(
			"SELECT name FROM cloud_categories WHERE id = $1 AND is_deleted = false",
			req.CategoryID,
		).Scan(&catName)
		if err == nil {
			if req.CategoryName == "" {
				req.CategoryName = catName
			}
		}
	}

	// Auto-generate product code dari huruf pertama nama produk
	if req.Code == "" && req.Name != "" {
		var outletID string
		database.DB.QueryRow("SELECT outlet_id FROM cloud_products WHERE id = $1", id).Scan(&outletID)
		if outletID != "" {
			req.Code = generateProductCode(outletID, req.Name)
		}
	}

	result, err := database.DB.Exec(
		`UPDATE cloud_products
		SET name=$1, code=$2, description=$3, category_id=$4, category_name=$5,
		    price=$6, stock=$7, destination=$8,
		    updated_at=NOW(), version=version+1
		WHERE id=$9 AND is_deleted=false`,
		req.Name, nullStr(req.Code), req.Description, req.CategoryID, req.CategoryName,
		req.Price, req.Stock, req.Destination, id,
	)
	if err != nil {
		return err
	}
	n, _ := result.RowsAffected()
	if n == 0 {
		return fmt.Errorf("product not found")
	}
	return nil
}

func AdminDeleteProduct(id string) error {
	result, err := database.DB.Exec(
		`UPDATE cloud_products SET is_deleted=true, updated_at=NOW() WHERE id=$1 AND is_deleted=false`, id,
	)
	if err != nil {
		return err
	}
	n, _ := result.RowsAffected()
	if n == 0 {
		return fmt.Errorf("product not found")
	}
	return nil
}

func AdminCreateCategory(req models.AdminCreateCategoryRequest) (models.CloudCategory, error) {
	if req.OutletID == "" || req.Name == "" {
		return models.CloudCategory{}, fmt.Errorf("outlet_id and name are required")
	}
	id := ulid.Make().String()
	now := time.Now()
	cp := req.CodePrefix
	if cp == "" {
		cp = generateCategoryCodePrefix(req.Name)
	}
	_, err := database.DB.Exec(
		`INSERT INTO cloud_categories
			(id, local_id, outlet_id, name, code_prefix, version, created_at, updated_at, synced_at)
		VALUES ($1,$2,$3,$4,$5,1,$6,$7,$8)`,
		id, id, req.OutletID, req.Name, cp, now, now, now,
	)
	if err != nil {
		return models.CloudCategory{}, err
	}
	return models.CloudCategory{
		ID: id, LocalID: id, OutletID: req.OutletID,
		Name: req.Name, CodePrefix: cp,
		Version: 1, CreatedAt: now, UpdatedAt: now, SyncedAt: now,
	}, nil
}

func AdminUpdateCategory(id string, req models.AdminUpdateCategoryRequest) error {
	cp := req.CodePrefix
	if cp == "" && req.Name != "" {
		cp = generateCategoryCodePrefix(req.Name)
	}
	result, err := database.DB.Exec(
		`UPDATE cloud_categories
		SET name=$1, code_prefix=$2, updated_at=NOW(), version=version+1
		WHERE id=$3 AND is_deleted=false`,
		req.Name, cp, id,
	)
	if err != nil {
		return err
	}
	n, _ := result.RowsAffected()
	if n == 0 {
		return fmt.Errorf("category not found")
	}
	return nil
}

func AdminDeleteCategory(id string) error {
	result, err := database.DB.Exec(
		`UPDATE cloud_categories SET is_deleted=true, updated_at=NOW() WHERE id=$1 AND is_deleted=false`, id,
	)
	if err != nil {
		return err
	}
	n, _ := result.RowsAffected()
	if n == 0 {
		return fmt.Errorf("category not found")
	}
	return nil
}

func DeleteProduct(outletID, localID string) error {
	_, err := database.DB.Exec(
		`UPDATE cloud_products SET is_deleted = true, updated_at = NOW()
		WHERE outlet_id = $1 AND local_id = $2`,
		outletID, localID,
	)
	return err
}

// ── Category Service ────────────────────────────────────────

// generateProductCode membuat kode produk dari huruf pertama nama produk.
// Jika kode sudah ada, tambahkan nomor urut: N, N1, N2, dst.
func generateProductCode(outletID, productName string) string {
	name := strings.TrimSpace(productName)
	if name == "" {
		name = "P"
	}
	// Ambil huruf pertama (uppercase)
	firstLetter := strings.ToUpper(string([]rune(name)[0]))

	// Cek apakah kode "X" sudah ada
	var count int
	database.DB.QueryRow(
		`SELECT COUNT(*) FROM cloud_products
		WHERE outlet_id = $1 AND code = $2 AND is_deleted = false`,
		outletID, firstLetter,
	).Scan(&count)

	if count == 0 {
		return firstLetter
	}

	// Cari nomor urut tertinggi: X1, X2, X3, ...
	var maxNum int
	database.DB.QueryRow(
		`SELECT COALESCE(MAX(
			CAST(SUBSTRING(code FROM $1) AS INTEGER)
		), 0) FROM cloud_products
		WHERE outlet_id = $2 AND code ~ $3 AND is_deleted = false`,
		fmt.Sprintf("^%s(\\d+)$", firstLetter),
		outletID,
		fmt.Sprintf("^%s\\d+$", firstLetter),
	).Scan(&maxNum)

	return fmt.Sprintf("%s%d", firstLetter, maxNum+1)
}

// generateCategoryCodePrefix membuat kode prefix dari huruf pertama setiap kata
// (logika sama seperti generateProductCode di local POS)
func generateCategoryCodePrefix(name string) string {
	words := strings.Fields(name)
	var code string
	for _, word := range words {
		if len([]rune(word)) > 0 {
			code += strings.ToUpper(string([]rune(word)[0]))
		}
	}
	if len(code) > 4 {
		code = code[:4]
	}
	if code == "" {
		code = "C"
	}
	return code
}

func SaveCategory(outletID string, req models.PushCategoryRequest) (string, error) {
	// Auto-generate code_prefix jika tidak dikirim oleh local POS
	codePrefix := strings.TrimSpace(req.CodePrefix)
	if codePrefix == "" {
		codePrefix = generateCategoryCodePrefix(req.Name)
	}

	// Gunakan POS local_id sebagai cloud id agar ID kategori sama di POS dan Cloud
	cloudID := req.LocalID
	err := database.DB.QueryRow(
		`INSERT INTO cloud_categories (id, local_id, outlet_id, name, code_prefix, version, synced_at)
		VALUES ($1, $2, $3, $4, $5, $6, NOW())
		ON CONFLICT (outlet_id, local_id) DO UPDATE SET
			id = EXCLUDED.id,
			name = EXCLUDED.name,
			code_prefix = EXCLUDED.code_prefix,
			version = EXCLUDED.version,
			updated_at = NOW(),
			synced_at = NOW()
		RETURNING id`,
		cloudID, cloudID, outletID, req.Name, codePrefix, req.Version,
	).Scan(&cloudID)

	if err != nil {
		return "", err
	}
	return cloudID, nil
}

// UpdateCategoryPrinter mengizinkan cloud admin menugaskan printer ke kategori
func UpdateCategoryPrinter(outletID, categoryID, printerID string) error {
	_, err := database.DB.Exec(
		`UPDATE cloud_categories SET printer_id = $1, updated_at = NOW()
		WHERE outlet_id = $2 AND id = $3`,
		printerID, outletID, categoryID,
	)
	return err
}

func GetOutletCategoriesWithPrinter(outletID string) ([]models.CloudCategory, error) {
	rows, err := database.DB.Query(
		`SELECT cc.id, COALESCE(cc.local_id,''), cc.outlet_id, cc.name,
			COALESCE(cc.code_prefix,''), COALESCE(cc.printer_id,''),
			cc.is_deleted, cc.version, cc.created_at, cc.updated_at, cc.synced_at
		FROM cloud_categories cc
		WHERE cc.outlet_id = $1 AND cc.is_deleted = false
		ORDER BY cc.name`,
		outletID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	cats := make([]models.CloudCategory, 0)
	for rows.Next() {
		var cat models.CloudCategory
		if err := rows.Scan(&cat.ID, &cat.LocalID, &cat.OutletID, &cat.Name,
			&cat.CodePrefix, &cat.PrinterID, &cat.IsDeleted, &cat.Version,
			&cat.CreatedAt, &cat.UpdatedAt, &cat.SyncedAt); err != nil {
			return nil, err
		}
		cats = append(cats, cat)
	}
	return cats, rows.Err()
}

func DeleteCategory(outletID, name string) error {
	_, err := database.DB.Exec(
		`UPDATE cloud_categories SET is_deleted = true, updated_at = NOW()
		WHERE outlet_id = $1 AND name = $2`,
		outletID, name,
	)
	return err
}

// ── Printer Service ─────────────────────────────────────────

func SavePrinter(outletID string, req models.PushPrinterRequest) (string, error) {
	cloudID := req.LocalID
	if cloudID == "" {
		cloudID = NewULID()
	}
	err := database.DB.QueryRow(
		`INSERT INTO cloud_printers (id, local_id, outlet_id, name, ip_address, port,
			printer_type, paper_size, is_active, is_deleted, synced_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, NOW())
		ON CONFLICT (outlet_id, local_id) DO UPDATE SET
			id = EXCLUDED.id,
			name = EXCLUDED.name,
			ip_address = EXCLUDED.ip_address,
			port = EXCLUDED.port,
			printer_type = EXCLUDED.printer_type,
			paper_size = EXCLUDED.paper_size,
			is_active = EXCLUDED.is_active,
			is_deleted = EXCLUDED.is_deleted,
			updated_at = NOW(),
			synced_at = NOW()
		RETURNING id`,
		cloudID, cloudID, outletID, req.Name, req.IPAddress, req.Port,
		req.PrinterType, req.PaperSize, req.IsActive, req.IsDeleted,
	).Scan(&cloudID)
	if err != nil {
		return "", err
	}
	go logSync(outletID, "push_printer", "printer", 1, "success", "")
	return cloudID, nil
}

func GetOutletPrinters(outletID string) ([]models.CloudPrinter, error) {
	rows, err := database.DB.Query(
		`SELECT id, local_id, outlet_id, name, ip_address, port,
			printer_type, paper_size, is_active, is_deleted, created_at, updated_at, synced_at
		FROM cloud_printers
		WHERE outlet_id = $1 AND is_deleted = false
		ORDER BY printer_type, name`,
		outletID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	printers := make([]models.CloudPrinter, 0)
	for rows.Next() {
		var p models.CloudPrinter
		if err := rows.Scan(&p.ID, &p.LocalID, &p.OutletID, &p.Name, &p.IPAddress,
			&p.Port, &p.PrinterType, &p.PaperSize, &p.IsActive, &p.IsDeleted,
			&p.CreatedAt, &p.UpdatedAt, &p.SyncedAt); err != nil {
			return nil, err
		}
		printers = append(printers, p)
	}
	return printers, rows.Err()
}

// ── Cashier Shift Service ────────────────────────────────────

func SaveCashierShift(outletID string, req models.PushCashierShiftRequest) (string, error) {
	// id = local_id (ID sama di POS dan Cloud)
	cloudID := req.LocalID
	if cloudID == "" {
		cloudID = NewULID()
	}

	// Parse nullable closed_at
	var closedAt interface{}
	if req.ClosedAt != "" {
		closedAt = parseTime(req.ClosedAt)
	}

	err := database.DB.QueryRow(
		`INSERT INTO cloud_cashier_shifts (id, local_id, outlet_id, opened_by, opened_at,
			opening_cash, closed_at, closed_by, closing_cash, closing_card, closing_qris,
			closing_transfer, carry_over_cash, previous_shift_id, handover_to, status, notes,
			created_at, updated_at, synced_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, NOW(), NOW(), NOW())
		ON CONFLICT (outlet_id, local_id) DO UPDATE SET
			id = EXCLUDED.id,
			opened_by = EXCLUDED.opened_by,
			opened_at = EXCLUDED.opened_at,
			opening_cash = EXCLUDED.opening_cash,
			closed_at = EXCLUDED.closed_at,
			closed_by = EXCLUDED.closed_by,
			closing_cash = EXCLUDED.closing_cash,
			closing_card = EXCLUDED.closing_card,
			closing_qris = EXCLUDED.closing_qris,
			closing_transfer = EXCLUDED.closing_transfer,
			carry_over_cash = EXCLUDED.carry_over_cash,
			previous_shift_id = EXCLUDED.previous_shift_id,
			handover_to = EXCLUDED.handover_to,
			status = EXCLUDED.status,
			notes = EXCLUDED.notes,
			updated_at = NOW(),
			synced_at = NOW()
		RETURNING id`,
		cloudID, cloudID, outletID, req.OpenedBy, parseTime(req.OpenedAt),
		req.OpeningCash, closedAt, req.ClosedBy, req.ClosingCash, req.ClosingCard,
		req.ClosingQris, req.ClosingTransfer, req.CarryOverCash, req.PreviousShiftID,
		req.HandoverTo, req.Status, req.Notes,
	).Scan(&cloudID)

	if err != nil {
		return "", err
	}

	go logSync(outletID, "push_cashier_shift", "cashier_shift", 1, "success", "")
	return cloudID, nil
}

func SaveCashMovement(outletID string, req models.PushCashMovementRequest) (string, error) {
	// id = local_id (ID sama di POS dan Cloud)
	cloudID := req.LocalID
	if cloudID == "" {
		cloudID = NewULID()
	}

	err := database.DB.QueryRow(
		`INSERT INTO cloud_cash_movements (id, local_id, outlet_id, shift_id,
			movement_type, amount, counterpart_name, note, created_at, synced_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())
		ON CONFLICT (outlet_id, local_id) DO UPDATE SET
			id = EXCLUDED.id,
			shift_id = EXCLUDED.shift_id,
			movement_type = EXCLUDED.movement_type,
			amount = EXCLUDED.amount,
			counterpart_name = EXCLUDED.counterpart_name,
			note = EXCLUDED.note,
			synced_at = NOW()
		RETURNING id`,
		cloudID, cloudID, outletID, req.ShiftID,
		req.MovementType, req.Amount, req.CounterpartName, req.Note,
		parseTime(req.CreatedAt),
	).Scan(&cloudID)

	if err != nil {
		return "", err
	}

	go logSync(outletID, "push_cash_movement", "cash_movement", 1, "success", "")
	return cloudID, nil
}

// ── Analytics Service ───────────────────────────────────────

func SaveAnalytics(outletID string, req models.PushAnalyticsRequest) (string, error) {
	summaryJSON, _ := json.Marshal(req.Summary)
	cloudID := NewULID()
	err := database.DB.QueryRow(
		`INSERT INTO cloud_analytics (id, outlet_id, outlet_code, date, summary)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (outlet_id, date) DO UPDATE SET
			summary = EXCLUDED.summary,
			updated_at = NOW()
		RETURNING id`,
		cloudID, outletID, req.OutletCode, req.Date, string(summaryJSON),
	).Scan(&cloudID)

	if err != nil {
		return "", err
	}

	go logSync(outletID, "push_analytics", "analytics", 1, "success", "")
	return cloudID, nil
}

func GetAnalytics(outletID, startDate, endDate string) ([]models.CloudAnalytics, error) {
	query := `SELECT id, outlet_id, outlet_code, date::text, summary::text,
		created_at, updated_at FROM cloud_analytics WHERE outlet_id = $1`
	args := []interface{}{outletID}

	if startDate != "" && endDate != "" {
		query += " AND date BETWEEN $2 AND $3"
		args = append(args, startDate, endDate)
	}
	query += " ORDER BY date DESC"

	rows, err := database.DB.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	analytics := make([]models.CloudAnalytics, 0)
	for rows.Next() {
		var a models.CloudAnalytics
		if err := rows.Scan(&a.ID, &a.OutletID, &a.OutletCode, &a.Date,
			&a.Summary, &a.CreatedAt, &a.UpdatedAt); err != nil {
			return nil, err
		}
		analytics = append(analytics, a)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return analytics, nil
}

// ── Batch Sync Service ──────────────────────────────────────

func ProcessBatchSync(outletID string, req models.BatchSyncRequest) models.BatchSyncResponse {
	resp := models.BatchSyncResponse{
		Processed: len(req.Items),
		SyncedAt:  time.Now().UTC().Format(time.RFC3339),
	}

	for _, item := range req.Items {
		result := models.BatchSyncResult{
			EntityType: item.EntityType,
			Status:     "success",
		}

		// Normalisasi field names dari POS trigger ke cloud model
		if dataMap, ok := item.Data.(map[string]interface{}); ok {
			normalizeSyncFields(dataMap, item.EntityType)
			item.Data = dataMap
		}

		dataBytes, _ := json.Marshal(item.Data)

		switch item.EntityType {
		case "order":
			var orderReq models.PushOrderRequest
			if err := json.Unmarshal(dataBytes, &orderReq); err != nil {
				result.Status = "failed"
				result.Error = "Invalid order data: " + err.Error()
				resp.Failed++
			} else {
				if orderReq.OutletCode == "" {
					orderReq.OutletCode = req.OutletCode
				}
				result.LocalID = orderReq.LocalID
				if cloudID, err := SaveOrder(outletID, orderReq); err != nil {
					result.Status = "failed"
					result.Error = err.Error()
					resp.Failed++
				} else {
					result.CloudID = cloudID
					resp.Success++
				}
			}

		case "transaction":
			var txReq models.PushTransactionRequest
			if err := json.Unmarshal(dataBytes, &txReq); err != nil {
				result.Status = "failed"
				result.Error = "Invalid transaction data: " + err.Error()
				resp.Failed++
			} else {
				if txReq.OutletCode == "" {
					txReq.OutletCode = req.OutletCode
				}
				result.LocalID = txReq.LocalID
				if cloudID, err := SaveTransaction(outletID, txReq); err != nil {
					result.Status = "failed"
					result.Error = err.Error()
					resp.Failed++
				} else {
					result.CloudID = cloudID
					resp.Success++
				}
			}

		case "product":
			var prodReq models.PushProductRequest
			if err := json.Unmarshal(dataBytes, &prodReq); err != nil {
				result.Status = "failed"
				result.Error = "Invalid product data: " + err.Error()
				resp.Failed++
			} else {
				result.LocalID = prodReq.LocalID
				if item.Operation == "delete" {
					if err := DeleteProduct(outletID, prodReq.LocalID); err != nil {
						result.Status = "failed"
						result.Error = err.Error()
						resp.Failed++
					} else {
						resp.Success++
					}
				} else {
					if cloudID, err := SaveProduct(outletID, prodReq); err != nil {
						result.Status = "failed"
						result.Error = err.Error()
						resp.Failed++
					} else {
						result.CloudID = cloudID
						resp.Success++
					}
				}
			}

		case "category":
			// Extract category fields from the data map
			dataMap := make(map[string]interface{})
			if err := json.Unmarshal(dataBytes, &dataMap); err != nil {
				result.Status = "failed"
				result.Error = "Invalid category data: " + err.Error()
				resp.Failed++
			} else {
				localID := ""
				if v, ok := dataMap["local_id"].(string); ok && v != "" {
					localID = v
				} else if v, ok := dataMap["id"].(string); ok && v != "" {
					localID = v
				}
				name := ""
				if v, ok := dataMap["name"].(string); ok {
					name = v
				}
				codePrefix := ""
				if v, ok := dataMap["code_prefix"].(string); ok {
					codePrefix = v
				}
				version := 1
				if v, ok := dataMap["version"].(float64); ok {
					version = int(v)
				}

				catReq := models.PushCategoryRequest{
					LocalID:    localID,
					Name:       name,
					CodePrefix: codePrefix,
					Version:    version,
				}

				result.LocalID = localID
				if item.Operation == "delete" {
					if err := DeleteCategory(outletID, name); err != nil {
						result.Status = "failed"
						result.Error = err.Error()
						resp.Failed++
					} else {
						resp.Success++
					}
				} else {
					if cloudID, err := SaveCategory(outletID, catReq); err != nil {
						result.Status = "failed"
						result.Error = err.Error()
						resp.Failed++
					} else {
						result.CloudID = cloudID
						resp.Success++
					}
				}
			}

		case "printer":
			var printerReq models.PushPrinterRequest
			if err := json.Unmarshal(dataBytes, &printerReq); err != nil {
				result.Status = "failed"
				result.Error = "Invalid printer data: " + err.Error()
				resp.Failed++
			} else {
				result.LocalID = printerReq.LocalID
				if item.Operation == "delete" {
					// Soft delete
					printerReq.IsDeleted = true
				}
				if cloudID, err := SavePrinter(outletID, printerReq); err != nil {
					result.Status = "failed"
					result.Error = err.Error()
					resp.Failed++
				} else {
					result.CloudID = cloudID
					resp.Success++
				}
			}

		case "cashier_shift":
			var shiftReq models.PushCashierShiftRequest
			if err := json.Unmarshal(dataBytes, &shiftReq); err != nil {
				result.Status = "failed"
				result.Error = "Invalid cashier_shift data: " + err.Error()
				resp.Failed++
			} else {
				result.LocalID = shiftReq.LocalID
				if cloudID, err := SaveCashierShift(outletID, shiftReq); err != nil {
					result.Status = "failed"
					result.Error = err.Error()
					resp.Failed++
				} else {
					result.CloudID = cloudID
					resp.Success++
				}
			}

		case "cashier_cash_movement":
			var movReq models.PushCashMovementRequest
			if err := json.Unmarshal(dataBytes, &movReq); err != nil {
				result.Status = "failed"
				result.Error = "Invalid cashier_cash_movement data: " + err.Error()
				resp.Failed++
			} else {
				result.LocalID = movReq.LocalID
				if cloudID, err := SaveCashMovement(outletID, movReq); err != nil {
					result.Status = "failed"
					result.Error = err.Error()
					resp.Failed++
				} else {
					result.CloudID = cloudID
					resp.Success++
				}
			}

		default:
			// Entity types yang belum di-handle di cloud: user, payment, dll
			// Skip tanpa error agar tidak mengganggu sync batch
			localID := ""
			if dataMap, ok := item.Data.(map[string]interface{}); ok {
				if v, ok := dataMap["local_id"].(string); ok {
					localID = v
				} else if v, ok := dataMap["id"].(string); ok {
					localID = v
				}
			}
			result.LocalID = localID
			result.Status = "success" // Anggap sukses — cloud tidak perlu entity ini
			result.CloudID = localID
			log.Printf("Entity type '%s' not handled by cloud, skipping", item.EntityType)
			resp.Success++
		}

		resp.Results = append(resp.Results, result)
	}

	syncStatus := "success"
	syncErr := ""
	if resp.Failed > 0 {
		if resp.Success == 0 {
			syncStatus = "failed"
		} else {
			syncStatus = "partial"
		}
		syncErr = fmt.Sprintf("%d of %d items failed", resp.Failed, resp.Processed)
	}
	go logSync(outletID, "batch_sync", "batch", resp.Processed, syncStatus, syncErr)
	return resp
}

// ── Updates Service ─────────────────────────────────────────

func GetUpdatesSince(outletID, since string) (*models.UpdatesResponse, error) {
	sinceRaw := parseTime(since)
	// Convert to local time for comparison with timestamp without time zone
	var sinceTime interface{}
	if t, ok := sinceRaw.(time.Time); ok {
		sinceTime = t.Local()
	} else {
		sinceTime = sinceRaw
	}
	resp := &models.UpdatesResponse{
		Products:       make([]models.UpdateEntity, 0),
		Categories:     make([]models.UpdateEntity, 0),
		Deleted:        make([]models.DeletedEntity, 0),
		SyncCheckpoint: time.Now().UTC().Format(time.RFC3339),
	}

	// Updated products
	rows, err := database.DB.Query(
		`SELECT id, local_id, name, COALESCE(code,''), COALESCE(description,''),
			COALESCE(category_id,''), COALESCE(category_name,''),
			price, stock, version, updated_at::text
		FROM cloud_products
		WHERE outlet_id = $1 AND updated_at > $2 AND is_deleted = false
		ORDER BY updated_at ASC`,
		outletID, sinceTime,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var e models.UpdateEntity
		var price float64
		var stock int
		if err := rows.Scan(&e.CloudID, &e.LocalID, &e.Name, &e.Code, &e.Description,
			&e.CategoryID, &e.CategoryName,
			&price, &stock, &e.Version, &e.UpdatedAt); err != nil {
			return nil, err
		}
		e.Price = &price
		e.Stock = &stock
		e.Action = "update"
		resp.Products = append(resp.Products, e)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	// Updated categories
	catRows, err := database.DB.Query(
		`SELECT id, COALESCE(local_id,''), name, version, updated_at::text
		FROM cloud_categories
		WHERE outlet_id = $1 AND updated_at > $2 AND is_deleted = false
		ORDER BY updated_at ASC`,
		outletID, sinceTime,
	)
	if err != nil {
		return nil, err
	}
	defer catRows.Close()
	for catRows.Next() {
		var e models.UpdateEntity
		if err := catRows.Scan(&e.CloudID, &e.LocalID, &e.Name, &e.Version, &e.UpdatedAt); err != nil {
			return nil, err
		}
		e.Action = "update"
		resp.Categories = append(resp.Categories, e)
	}
	if err := catRows.Err(); err != nil {
		return nil, err
	}

	// Deleted entities
	delProdRows, err := database.DB.Query(
		`SELECT id, local_id, updated_at::text
		FROM cloud_products WHERE outlet_id = $1 AND is_deleted = true AND updated_at > $2`,
		outletID, sinceTime,
	)
	if err != nil {
		return nil, err
	}
	defer delProdRows.Close()
	for delProdRows.Next() {
		var d models.DeletedEntity
		d.EntityType = "product"
		if err := delProdRows.Scan(&d.CloudID, &d.LocalID, &d.DeletedAt); err != nil {
			return nil, err
		}
		resp.Deleted = append(resp.Deleted, d)
	}
	if err := delProdRows.Err(); err != nil {
		return nil, err
	}

	delCatRows, err := database.DB.Query(
		`SELECT id, COALESCE(local_id,''), updated_at::text
		FROM cloud_categories WHERE outlet_id = $1 AND is_deleted = true AND updated_at > $2`,
		outletID, sinceTime,
	)
	if err != nil {
		return nil, err
	}
	defer delCatRows.Close()
	for delCatRows.Next() {
		var d models.DeletedEntity
		d.EntityType = "category"
		if err := delCatRows.Scan(&d.CloudID, &d.LocalID, &d.DeletedAt); err != nil {
			return nil, err
		}
		resp.Deleted = append(resp.Deleted, d)
	}
	if err := delCatRows.Err(); err != nil {
		return nil, err
	}

	return resp, nil
}

// ── Conflict Service ────────────────────────────────────────

func GetConflicts(outletID string) ([]models.SyncConflict, error) {
	rows, err := database.DB.Query(
		`SELECT id, outlet_id, entity_type, COALESCE(entity_local_id,''),
			COALESCE(entity_cloud_id::text,''), COALESCE(conflict_field,''),
			COALESCE(cloud_value,''), COALESCE(local_value,''),
			COALESCE(cloud_version,0), COALESCE(local_version,0),
			COALESCE(resolution,'pending'), COALESCE(resolved_by,''),
			resolved_at::text, COALESCE(notes,''), created_at::text
		FROM sync_conflicts WHERE outlet_id = $1
		ORDER BY created_at DESC`,
		outletID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	conflicts := make([]models.SyncConflict, 0)
	for rows.Next() {
		var c models.SyncConflict
		if err := rows.Scan(&c.ID, &c.OutletID, &c.EntityType,
			&c.EntityLocalID, &c.EntityCloudID, &c.ConflictField,
			&c.CloudValue, &c.LocalValue, &c.CloudVersion, &c.LocalVersion,
			&c.Resolution, &c.ResolvedBy, &c.ResolvedAt, &c.Notes, &c.CreatedAt); err != nil {
			return nil, err
		}
		conflicts = append(conflicts, c)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return conflicts, nil
}

func ResolveConflict(outletID, conflictID string, req models.ResolveConflictRequest) error {
	result, err := database.DB.Exec(
		`UPDATE sync_conflicts
		SET resolution = $1, resolved_by = $2, notes = $3, resolved_at = NOW()
		WHERE id = $4 AND outlet_id = $5`,
		req.Strategy, req.ResolvedBy, req.Notes, conflictID, outletID,
	)
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("conflict not found")
	}
	return nil
}

// ── Sync Log Service ────────────────────────────────────────

func logSync(outletID, action, entityType string, count int, status, errMsg string) {
	_, err := database.DB.Exec(
		`INSERT INTO sync_logs (id, outlet_id, action, entity_type, entity_count, status, error_message)
		VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		NewULID(), outletID, action, entityType, count, status, errMsg,
	)
	if err != nil {
		log.Printf("Failed to log sync: %v", err)
	}
}

func GetSyncLogs(outletID string, limit int) ([]models.SyncLog, error) {
	rows, err := database.DB.Query(
		`SELECT id, outlet_id, action, COALESCE(entity_type,''),
			entity_count, status, COALESCE(error_message,''), created_at::text
		FROM sync_logs WHERE outlet_id = $1
		ORDER BY created_at DESC LIMIT $2`,
		outletID, limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	logs := make([]models.SyncLog, 0)
	for rows.Next() {
		var l models.SyncLog
		if err := rows.Scan(&l.ID, &l.OutletID, &l.Action, &l.EntityType,
			&l.EntityCount, &l.Status, &l.ErrorMessage, &l.CreatedAt); err != nil {
			return nil, err
		}
		logs = append(logs, l)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return logs, nil
}

// ── Dashboard Service ───────────────────────────────────────

// GetDashboardStats returns aggregated stats.
// dateFrom / dateTo (YYYY-MM-DD) are optional; when supplied the per-outlet
// custom-range columns are populated.  Empty strings mean "no custom range".
func GetDashboardStats(dateFrom, dateTo string) (*models.DashboardStats, error) {
	stats := &models.DashboardStats{}

	queries := []struct {
		query string
		dest  interface{}
	}{
		{"SELECT COUNT(*) FROM outlets", &stats.TotalOutlets},
		{"SELECT COUNT(*) FROM outlets WHERE is_active = true", &stats.ActiveOutlets},
		{"SELECT COUNT(*) FROM cloud_orders", &stats.TotalOrders},
		{"SELECT COUNT(*) FROM cloud_transactions", &stats.TotalTransactions},
		{"SELECT COALESCE(SUM(total_amount),0) FROM cloud_transactions", &stats.TotalRevenue},
		// monthly
		{`SELECT COUNT(*) FROM cloud_transactions
			 WHERE created_at >= date_trunc('month', CURRENT_TIMESTAMP)`, &stats.MonthTransactions},
		{`SELECT COUNT(*) FROM cloud_transactions
			 WHERE created_at >= date_trunc('month', CURRENT_TIMESTAMP) - INTERVAL '1 month'
			   AND created_at <  date_trunc('month', CURRENT_TIMESTAMP)`, &stats.MonthTransactionsPrev},
		{`SELECT COALESCE(SUM(total_amount),0) FROM cloud_transactions
			 WHERE created_at >= date_trunc('month', CURRENT_TIMESTAMP)`, &stats.MonthRevenue},
		{`SELECT COALESCE(SUM(total_amount),0) FROM cloud_transactions
			 WHERE created_at >= date_trunc('month', CURRENT_TIMESTAMP) - INTERVAL '1 month'
			   AND created_at <  date_trunc('month', CURRENT_TIMESTAMP)`, &stats.MonthRevenuePrev},
		// today
		{"SELECT COUNT(*) FROM cloud_orders WHERE created_at::date = CURRENT_DATE", &stats.TodayOrders},
		{"SELECT COUNT(*) FROM cloud_orders WHERE created_at::date = CURRENT_DATE - 1", &stats.TodayOrdersPrev},
		{"SELECT COALESCE(SUM(total_amount),0) FROM cloud_transactions WHERE created_at::date = CURRENT_DATE", &stats.TodayRevenue},
		{"SELECT COUNT(*) FROM cloud_products WHERE is_deleted = false", &stats.TotalProducts},
		{"SELECT COUNT(*) FROM sync_logs", &stats.TotalSyncLogs},
		{"SELECT COUNT(*) FROM sync_conflicts WHERE resolution IS NULL OR resolution = 'pending'", &stats.PendingConflicts},
		{"SELECT COUNT(*) FROM cloud_orders WHERE COALESCE(payment_info->>'payment_status','unpaid') NOT IN ('paid') AND payment_info->>'voided_at' IS NULL", &stats.TotalUnpaidOrders},
		{"SELECT COALESCE(SUM(total_amount),0) FROM cloud_orders WHERE COALESCE(payment_info->>'payment_status','unpaid') NOT IN ('paid') AND payment_info->>'voided_at' IS NULL", &stats.TotalUnpaidAmount},
	}

	for _, q := range queries {
		if err := database.DB.QueryRow(q.query).Scan(q.dest); err != nil {
			return nil, fmt.Errorf("dashboard query failed: %w", err)
		}
	}

	// ── Per-outlet sales summary ─────────────────────────────
	// Two query variants:
	//   a) standard  – no parameters, custom columns are always 0
	//   b) range     – two date parameters, custom columns populated
	const outletBase = `
		SELECT
			o.id,
			o.name,
			COALESCE(SUM(CASE WHEN t.created_at::date = CURRENT_DATE
				THEN t.total_amount ELSE 0 END), 0)                                       AS sales_day,
			COALESCE(SUM(CASE WHEN t.created_at::date = CURRENT_DATE - INTERVAL '1 day'
				THEN t.total_amount ELSE 0 END), 0)                                       AS sales_day_prev,
			COALESCE(SUM(CASE WHEN t.created_at >= date_trunc('week', CURRENT_TIMESTAMP)
				THEN t.total_amount ELSE 0 END), 0)                                       AS sales_week,
			COALESCE(SUM(CASE WHEN t.created_at >= date_trunc('week', CURRENT_TIMESTAMP) - INTERVAL '7 days'
				AND t.created_at < date_trunc('week', CURRENT_TIMESTAMP)
				THEN t.total_amount ELSE 0 END), 0)                                       AS sales_week_prev,
			COALESCE(SUM(CASE WHEN t.created_at >= date_trunc('month', CURRENT_TIMESTAMP)
				THEN t.total_amount ELSE 0 END), 0)                                       AS sales_month,
			COALESCE(SUM(CASE WHEN t.created_at >= date_trunc('month', CURRENT_TIMESTAMP) - INTERVAL '1 month'
				AND t.created_at < date_trunc('month', CURRENT_TIMESTAMP)
				THEN t.total_amount ELSE 0 END), 0)                                       AS sales_month_prev`

	const outletStdTail = `,
			0::float8                                                                     AS sales_custom,
			0::float8                                                                     AS sales_custom_prev,
			COALESCE(u.cnt, 0)::int                                                       AS unpaid_orders,
			COALESCE(u.amt, 0)                                                            AS unpaid_amount,
			TO_CHAR(MAX(t.synced_at), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')                    AS last_sync_at
		FROM outlets o
		LEFT JOIN cloud_transactions t ON t.outlet_id = o.id
		LEFT JOIN (
			SELECT outlet_id, COUNT(*) AS cnt, SUM(total_amount) AS amt
			FROM cloud_orders WHERE COALESCE(payment_info->>'payment_status','unpaid') NOT IN ('paid') AND payment_info->>'voided_at' IS NULL
			GROUP BY outlet_id
		) u ON u.outlet_id = o.id
		WHERE o.is_active = true
		GROUP BY o.id, o.name, u.cnt, u.amt
		ORDER BY sales_month DESC`

	const outletRangeTail = `,
			COALESCE(SUM(CASE WHEN t.created_at::date >= $1::date AND t.created_at::date <= $2::date
				THEN t.total_amount ELSE 0 END), 0)                                       AS sales_custom,
			COALESCE(SUM(CASE WHEN t.created_at::date >= $1::date - ($2::date - $1::date + 1)
				AND t.created_at::date < $1::date
				THEN t.total_amount ELSE 0 END), 0)                                       AS sales_custom_prev,
			COALESCE(u.cnt, 0)::int                                                       AS unpaid_orders,
			COALESCE(u.amt, 0)                                                            AS unpaid_amount,
			TO_CHAR(MAX(t.synced_at), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')                    AS last_sync_at
		FROM outlets o
		LEFT JOIN cloud_transactions t ON t.outlet_id = o.id
		LEFT JOIN (
			SELECT outlet_id, COUNT(*) AS cnt, SUM(total_amount) AS amt
			FROM cloud_orders WHERE COALESCE(payment_info->>'payment_status','unpaid') NOT IN ('paid') AND payment_info->>'voided_at' IS NULL
			GROUP BY outlet_id
		) u ON u.outlet_id = o.id
		WHERE o.is_active = true
		GROUP BY o.id, o.name, u.cnt, u.amt
		ORDER BY sales_month DESC`

	var (
		rows    *sql.Rows
		rowsErr error
	)
	if dateFrom != "" && dateTo != "" {
		rows, rowsErr = database.DB.Query(outletBase+outletRangeTail, dateFrom, dateTo)
	} else {
		rows, rowsErr = database.DB.Query(outletBase + outletStdTail)
	}
	if rowsErr != nil {
		return nil, fmt.Errorf("dashboard outlet query failed: %w", rowsErr)
	}
	defer rows.Close()

	stats.Outlets = []models.OutletDashboardRow{}
	for rows.Next() {
		var row models.OutletDashboardRow
		if err := rows.Scan(
			&row.ID, &row.Name,
			&row.SalesDay, &row.SalesDayPrev,
			&row.SalesWeek, &row.SalesWeekPrev,
			&row.SalesMonth, &row.SalesMonthPrev,
			&row.SalesCustom, &row.SalesCustomPrev,
			&row.UnpaidOrders, &row.UnpaidAmount,
			&row.LastSyncAt,
		); err != nil {
			return nil, fmt.Errorf("dashboard outlet scan failed: %w", err)
		}
		stats.Outlets = append(stats.Outlets, row)
	}

	return stats, nil
}

// ── Sales Report Service ────────────────────────────────────

func GetSalesReport(dateFrom, dateTo, outletID string, page, limit int) (*models.SalesReportResponse, error) {
	report := &models.SalesReportResponse{
		Page:  page,
		Limit: limit,
	}

	// ── Summary ──
	summaryQuery := `
		SELECT
			COUNT(*)::int,
			COALESCE(SUM(total_amount), 0),
			COALESCE(AVG(total_amount), 0),
			COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN total_amount ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN payment_method = 'qris' THEN total_amount ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN payment_method = 'card' THEN total_amount ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN payment_method = 'transfer' THEN total_amount ELSE 0 END), 0)
		FROM cloud_transactions
		WHERE created_at::date >= $1::date AND created_at::date <= $2::date`

	args := []interface{}{dateFrom, dateTo}
	if outletID != "" {
		summaryQuery += ` AND outlet_id = $3`
		args = append(args, outletID)
	}

	err := database.DB.QueryRow(summaryQuery, args...).Scan(
		&report.Summary.TotalTransactions,
		&report.Summary.TotalRevenue,
		&report.Summary.AvgPerTransaction,
		&report.Summary.CashRevenue,
		&report.Summary.QrisRevenue,
		&report.Summary.CardRevenue,
		&report.Summary.TransferRevenue,
	)
	if err != nil {
		return nil, fmt.Errorf("sales report summary query failed: %w", err)
	}

	// ── Unpaid orders summary ──
	unpaidQuery := `
		SELECT COUNT(*)::int, COALESCE(SUM(total_amount), 0)
		FROM cloud_orders
		WHERE COALESCE(payment_info->>'payment_status','unpaid') NOT IN ('paid')
		  AND payment_info->>'voided_at' IS NULL
		  AND created_at::date >= $1::date AND created_at::date <= $2::date`
	unpaidArgs := []interface{}{dateFrom, dateTo}
	if outletID != "" {
		unpaidQuery += ` AND outlet_id = $3`
		unpaidArgs = append(unpaidArgs, outletID)
	}
	_ = database.DB.QueryRow(unpaidQuery, unpaidArgs...).Scan(
		&report.Summary.UnpaidOrders,
		&report.Summary.UnpaidAmount,
	)

	// ── Daily breakdown ──
	dailyQuery := `
		SELECT
			TO_CHAR(created_at::date, 'YYYY-MM-DD') AS date,
			COUNT(*)::int,
			COALESCE(SUM(total_amount), 0),
			COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN total_amount ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN payment_method = 'qris' THEN total_amount ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN payment_method = 'card' THEN total_amount ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN payment_method = 'transfer' THEN total_amount ELSE 0 END), 0)
		FROM cloud_transactions
		WHERE created_at::date >= $1::date AND created_at::date <= $2::date`

	dailyArgs := []interface{}{dateFrom, dateTo}
	if outletID != "" {
		dailyQuery += ` AND outlet_id = $3`
		dailyArgs = append(dailyArgs, outletID)
	}
	dailyQuery += ` GROUP BY created_at::date ORDER BY created_at::date DESC`

	dailyRows, err := database.DB.Query(dailyQuery, dailyArgs...)
	if err != nil {
		return nil, fmt.Errorf("sales report daily query failed: %w", err)
	}
	defer dailyRows.Close()

	report.Daily = []models.SalesReportRow{}
	for dailyRows.Next() {
		var row models.SalesReportRow
		if err := dailyRows.Scan(&row.Date, &row.TotalTransactions, &row.TotalRevenue,
			&row.CashRevenue, &row.QrisRevenue, &row.CardRevenue, &row.TransferRevenue); err != nil {
			return nil, fmt.Errorf("sales report daily scan failed: %w", err)
		}
		report.Daily = append(report.Daily, row)
	}

	// ── By outlet ──
	outletQuery := `
		SELECT
			t.outlet_id,
			COALESCE(o.name, t.outlet_code),
			COUNT(*)::int,
			COALESCE(SUM(t.total_amount), 0),
			COALESCE(uq.cnt, 0)::int,
			COALESCE(uq.amt, 0)
		FROM cloud_transactions t
		LEFT JOIN outlets o ON o.id = t.outlet_id
		LEFT JOIN (
			SELECT outlet_id, COUNT(*) AS cnt, SUM(total_amount) AS amt
			FROM cloud_orders
			WHERE status NOT IN ('paid','cancelled','voided')
			  AND created_at::date >= $1::date AND created_at::date <= $2::date
			GROUP BY outlet_id
		) uq ON uq.outlet_id = t.outlet_id
		WHERE t.created_at::date >= $1::date AND t.created_at::date <= $2::date`

	outletArgs := []interface{}{dateFrom, dateTo}
	if outletID != "" {
		outletQuery += ` AND t.outlet_id = $3`
		outletArgs = append(outletArgs, outletID)
	}
	outletQuery += ` GROUP BY t.outlet_id, o.name, t.outlet_code, uq.cnt, uq.amt ORDER BY SUM(t.total_amount) DESC`

	outletRows, err := database.DB.Query(outletQuery, outletArgs...)
	if err != nil {
		return nil, fmt.Errorf("sales report outlet query failed: %w", err)
	}
	defer outletRows.Close()

	report.ByOutlet = []models.SalesReportOutlet{}
	for outletRows.Next() {
		var row models.SalesReportOutlet
		if err := outletRows.Scan(&row.OutletID, &row.OutletName, &row.TotalTransactions, &row.TotalRevenue, &row.UnpaidOrders, &row.UnpaidAmount); err != nil {
			return nil, fmt.Errorf("sales report outlet scan failed: %w", err)
		}
		report.ByOutlet = append(report.ByOutlet, row)
	}

	// ── Paginated transactions ──
	countQuery := `SELECT COUNT(*) FROM cloud_transactions
		WHERE created_at::date >= $1::date AND created_at::date <= $2::date`
	countArgs := []interface{}{dateFrom, dateTo}
	if outletID != "" {
		countQuery += ` AND outlet_id = $3`
		countArgs = append(countArgs, outletID)
	}

	var total int
	if err := database.DB.QueryRow(countQuery, countArgs...).Scan(&total); err != nil {
		return nil, fmt.Errorf("sales report count query failed: %w", err)
	}
	report.Total = total
	report.TotalPages = int(math.Ceil(float64(total) / float64(limit)))

	offset := (page - 1) * limit
	txQuery := `
		SELECT
			t.id,
			COALESCE(o.name, t.outlet_code),
			t.outlet_code,
			t.total_amount,
			t.payment_method,
			t.cashier_name,
			t.items,
			TO_CHAR(t.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
		FROM cloud_transactions t
		LEFT JOIN outlets o ON o.id = t.outlet_id
		WHERE t.created_at::date >= $1::date AND t.created_at::date <= $2::date`

	txArgs := []interface{}{dateFrom, dateTo}
	paramIdx := 3
	if outletID != "" {
		txQuery += fmt.Sprintf(` AND t.outlet_id = $%d`, paramIdx)
		txArgs = append(txArgs, outletID)
		paramIdx++
	}
	txQuery += fmt.Sprintf(` ORDER BY t.created_at DESC LIMIT $%d OFFSET $%d`, paramIdx, paramIdx+1)
	txArgs = append(txArgs, limit, offset)

	txRows, err := database.DB.Query(txQuery, txArgs...)
	if err != nil {
		return nil, fmt.Errorf("sales report transactions query failed: %w", err)
	}
	defer txRows.Close()

	transactions := []models.SalesReportTransaction{}
	for txRows.Next() {
		var t models.SalesReportTransaction
		if err := txRows.Scan(&t.ID, &t.OutletName, &t.OutletCode, &t.TotalAmount,
			&t.PaymentMethod, &t.CashierName, &t.Items, &t.CreatedAt); err != nil {
			return nil, fmt.Errorf("sales report transaction scan failed: %w", err)
		}
		transactions = append(transactions, t)
	}

	report.Transactions = transactions
	return report, nil
}

// ── Unpaid Orders Report Service ────────────────────────────

func GetUnpaidOrders(outletID, status string, page, limit int) (*models.UnpaidOrdersResponse, error) {
	report := &models.UnpaidOrdersResponse{
		Page:  page,
		Limit: limit,
	}

	// Build WHERE clause
	where := `WHERE COALESCE(o.payment_info->>'payment_status','unpaid') NOT IN ('paid') AND o.payment_info->>'voided_at' IS NULL`
	args := []interface{}{}
	paramIdx := 1

	if outletID != "" {
		where += fmt.Sprintf(` AND o.outlet_id = $%d`, paramIdx)
		args = append(args, outletID)
		paramIdx++
	}
	if status != "" {
		where += fmt.Sprintf(` AND o.status = $%d`, paramIdx)
		args = append(args, status)
		paramIdx++
	}

	// Summary
	sumQ := `SELECT COUNT(*)::int, COALESCE(SUM(o.total_amount), 0) FROM cloud_orders o ` + where
	if err := database.DB.QueryRow(sumQ, args...).Scan(&report.TotalUnpaid, &report.TotalAmount); err != nil {
		return nil, fmt.Errorf("unpaid orders summary failed: %w", err)
	}

	// Count for pagination
	report.Total = report.TotalUnpaid
	report.TotalPages = int(math.Ceil(float64(report.Total) / float64(limit)))

	// Paginated list
	offset := (page - 1) * limit
	listQ := fmt.Sprintf(`
		SELECT
			o.id,
			COALESCE(ot.name, o.outlet_code),
			o.outlet_code,
			COALESCE(o.table_number, ''),
			COALESCE(o.customer_name, ''),
			o.pax,
			o.total_amount,
			o.status,
			COALESCE(o.items::text, '[]'),
			TO_CHAR(o.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
			TO_CHAR(o.updated_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
		FROM cloud_orders o
		LEFT JOIN outlets ot ON ot.id = o.outlet_id
		%s
		ORDER BY o.created_at DESC
		LIMIT $%d OFFSET $%d`, where, paramIdx, paramIdx+1)

	listArgs := append(args, limit, offset)
	rows, err := database.DB.Query(listQ, listArgs...)
	if err != nil {
		return nil, fmt.Errorf("unpaid orders list failed: %w", err)
	}
	defer rows.Close()

	report.Orders = []models.UnpaidOrderRow{}
	for rows.Next() {
		var r models.UnpaidOrderRow
		if err := rows.Scan(&r.ID, &r.OutletName, &r.OutletCode, &r.TableNumber,
			&r.CustomerName, &r.Pax, &r.TotalAmount, &r.Status, &r.Items,
			&r.CreatedAt, &r.UpdatedAt); err != nil {
			return nil, fmt.Errorf("unpaid orders scan failed: %w", err)
		}
		report.Orders = append(report.Orders, r)
	}

	return report, nil
}

// ── Admin Auth Service ──────────────────────────────────────

func AdminLogin(req models.AdminLoginRequest, jwtSecret string) (*models.AdminLoginResponse, error) {
	var admin models.CloudAdmin
	var passwordHash string
	var lastLogin sql.NullTime

	err := database.DB.QueryRow(
		`SELECT id, username, password_hash, name, role, is_active, last_login_at, created_at, updated_at
		FROM cloud_admins WHERE username = $1`,
		req.Username,
	).Scan(&admin.ID, &admin.Username, &passwordHash, &admin.Name, &admin.Role,
		&admin.IsActive, &lastLogin, &admin.CreatedAt, &admin.UpdatedAt)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("username atau password salah")
	}
	if err != nil {
		return nil, err
	}

	// Trim CHAR(26) whitespace
	admin.ID = strings.TrimSpace(admin.ID)

	if !admin.IsActive {
		return nil, fmt.Errorf("akun admin tidak aktif")
	}

	if err := bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(req.Password)); err != nil {
		return nil, fmt.Errorf("username atau password salah")
	}

	if lastLogin.Valid {
		admin.LastLoginAt = &lastLogin.Time
	}

	// Update last_login_at
	database.DB.Exec("UPDATE cloud_admins SET last_login_at = NOW() WHERE id = $1", admin.ID)

	// Generate JWT token
	token, err := generateJWT(admin, jwtSecret)
	if err != nil {
		return nil, fmt.Errorf("gagal membuat token: %w", err)
	}

	return &models.AdminLoginResponse{
		Token: token,
		Admin: admin,
	}, nil
}

func generateJWT(admin models.CloudAdmin, secret string) (string, error) {
	claims := jwt.MapClaims{
		"sub":      admin.ID,
		"username": admin.Username,
		"name":     admin.Name,
		"role":     admin.Role,
		"iat":      time.Now().Unix(),
		"exp":      time.Now().Add(24 * time.Hour).Unix(),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(secret))
}

func ValidateJWT(tokenString, secret string) (jwt.MapClaims, error) {
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(secret), nil
	})

	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(jwt.MapClaims); ok && token.Valid {
		return claims, nil
	}

	return nil, fmt.Errorf("invalid token")
}

func GetAdmins() ([]models.CloudAdmin, error) {
	rows, err := database.DB.Query(
		`SELECT id, username, name, role, is_active, last_login_at, created_at, updated_at
		FROM cloud_admins ORDER BY created_at ASC`,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	admins := make([]models.CloudAdmin, 0)
	for rows.Next() {
		var a models.CloudAdmin
		var lastLogin sql.NullTime
		if err := rows.Scan(&a.ID, &a.Username, &a.Name, &a.Role,
			&a.IsActive, &lastLogin, &a.CreatedAt, &a.UpdatedAt); err != nil {
			return nil, err
		}
		a.ID = strings.TrimSpace(a.ID)
		if lastLogin.Valid {
			a.LastLoginAt = &lastLogin.Time
		}
		admins = append(admins, a)
	}
	return admins, rows.Err()
}

func CreateAdmin(req models.CreateAdminRequest) (*models.CloudAdmin, error) {
	// Validasi
	if req.Username == "" || req.Password == "" || req.Name == "" {
		return nil, fmt.Errorf("username, password, dan name wajib diisi")
	}
	if len(req.Password) < 6 {
		return nil, fmt.Errorf("password minimal 6 karakter")
	}
	if req.Role == "" {
		req.Role = "admin"
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	id := NewULID()
	admin := &models.CloudAdmin{ID: id, Username: req.Username, Name: req.Name, Role: req.Role, IsActive: true}

	err = database.DB.QueryRow(
		`INSERT INTO cloud_admins (id, username, password_hash, name, role)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING created_at, updated_at`,
		id, req.Username, string(hash), req.Name, req.Role,
	).Scan(&admin.CreatedAt, &admin.UpdatedAt)

	if err != nil {
		if strings.Contains(err.Error(), "duplicate key") || strings.Contains(err.Error(), "unique") {
			return nil, fmt.Errorf("username '%s' sudah digunakan", req.Username)
		}
		return nil, err
	}

	return admin, nil
}

// ── Helpers ─────────────────────────────────────────────────

func parseTime(s string) interface{} {
	if s == "" {
		return sql.NullTime{}
	}

	formats := []string{
		time.RFC3339,
		"2006-01-02T15:04:05Z",
		"2006-01-02 15:04:05",
		"2006-01-02",
	}

	for _, f := range formats {
		if t, err := time.Parse(f, s); err == nil {
			return t
		}
	}

	return time.Now().UTC()
}

// nullStr converts empty string to nil (NULL in SQL), non-empty to *string
func nullStr(s string) interface{} {
	if s == "" {
		return nil
	}
	return s
}
