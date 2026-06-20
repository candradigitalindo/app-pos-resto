package services

import (
	"cloud-pos/database"
	"cloud-pos/models"
	"fmt"
	"strings"
	"time"

	"github.com/lib/pq"
	"github.com/oklog/ulid/v2"
)

func SaveProduct(outletID string, req models.PushProductRequest) (string, error) {
	cloudID := req.LocalID
	err := database.DB.QueryRow(
		`INSERT INTO cloud_products (id, local_id, outlet_id, name, code, description, category_id,
			category_name, price, destination, version, updated_at, synced_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, COALESCE($12, NOW()), NOW())
		ON CONFLICT (outlet_id, local_id) DO UPDATE SET
			id = EXCLUDED.id,
			name = EXCLUDED.name,
			code = EXCLUDED.code,
			description = EXCLUDED.description,
			category_id = EXCLUDED.category_id,
			category_name = EXCLUDED.category_name,
			price = EXCLUDED.price,
			destination = EXCLUDED.destination,
			version = EXCLUDED.version,
			updated_at = NOW(),
			synced_at = NOW()
		RETURNING id`,
		cloudID, cloudID, outletID, req.Name, nullStr(req.Code), req.Description, req.CategoryID,
		req.CategoryName, req.Price, req.Destination,
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
			COALESCE(category_name,''), price, COALESCE(destination,''),
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
			&p.CategoryID, &p.CategoryName, &p.Price, &p.Destination,
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

func GetAllProducts(outletID, search string, scopeIDs []string, page, limit int) ([]models.CloudProduct, int, error) {
	offset := (page - 1) * limit

	// Normalize outlet filter
	var filterIDs []string
	if outletID != "" {
		filterIDs = []string{outletID}
	} else if scopeIDs != nil {
		filterIDs = scopeIDs
	}

	conds := []string{"cp.is_deleted = false"}
	args := []any{}
	idx := 1

	if filterIDs != nil {
		conds = append(conds, fmt.Sprintf("cp.outlet_id = ANY($%d::text[])", idx))
		args = append(args, pq.Array(filterIDs))
		idx++
	}
	if search != "" {
		conds = append(conds, fmt.Sprintf("(cp.name ILIKE $%d OR cp.code ILIKE $%d OR cp.category_name ILIKE $%d)", idx, idx, idx))
		args = append(args, "%"+search+"%")
		idx++
	}
	whereSQL := "WHERE " + strings.Join(conds, " AND ")

	var total int
	database.DB.QueryRow(
		fmt.Sprintf("SELECT COUNT(*) FROM cloud_products cp %s", whereSQL),
		args...,
	).Scan(&total)

	dataArgs := append(append([]any{}, args...), limit, offset)
	dataQuery := fmt.Sprintf(
		`SELECT cp.id, cp.local_id, cp.outlet_id, COALESCE(o.name,''),
			cp.name, COALESCE(cp.code,''), COALESCE(cp.description,''),
			COALESCE(cp.category_id,''), COALESCE(cp.category_name,''),
			cp.price, COALESCE(cp.destination,''),
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
			&p.Name, &p.Code, &p.Description, &p.CategoryID, &p.CategoryName, &p.Price, &p.Destination,
			&p.IsDeleted, &p.Version, &p.CreatedAt, &p.UpdatedAt, &p.SyncedAt); err != nil {
			return nil, 0, err
		}
		products = append(products, p)
	}
	return products, total, rows.Err()
}

func GetAllCategories(outletID, search string, scopeIDs []string, page, limit int) ([]models.CloudCategory, int, error) {
	offset := (page - 1) * limit

	// Normalize outlet filter
	var filterIDs []string
	if outletID != "" {
		filterIDs = []string{outletID}
	} else if scopeIDs != nil {
		filterIDs = scopeIDs
	}

	conds := []string{"cc.is_deleted = false"}
	args := []any{}
	idx := 1

	if filterIDs != nil {
		conds = append(conds, fmt.Sprintf("cc.outlet_id = ANY($%d::text[])", idx))
		args = append(args, pq.Array(filterIDs))
		idx++
	}
	if search != "" {
		conds = append(conds, fmt.Sprintf("(cc.name ILIKE $%d OR cc.code_prefix ILIKE $%d)", idx, idx))
		args = append(args, "%"+search+"%")
		idx++
	}
	whereSQL := "WHERE " + strings.Join(conds, " AND ")

	var total int
	database.DB.QueryRow(
		fmt.Sprintf("SELECT COUNT(*) FROM cloud_categories cc %s", whereSQL),
		args...,
	).Scan(&total)

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

func AdminCreateProduct(req models.AdminCreateProductRequest) (models.CloudProduct, error) {
	if req.OutletID == "" || req.Name == "" {
		return models.CloudProduct{}, fmt.Errorf("outlet_id and name are required")
	}
	id := ulid.Make().String()
	now := time.Now().UTC()

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

	if req.Code == "" {
		req.Code = generateProductCode(req.OutletID, req.Name)
	}

	_, err := database.DB.Exec(
		`INSERT INTO cloud_products
			(id, local_id, outlet_id, name, code, description, category_id, category_name,
			 price, destination, version, created_at, updated_at, synced_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,1,$11,$12,$13)`,
		id, id, req.OutletID, req.Name, nullStr(req.Code), req.Description, req.CategoryID, req.CategoryName,
		req.Price, req.Destination, now, now, now,
	)
	if err != nil {
		return models.CloudProduct{}, err
	}
	return models.CloudProduct{
		ID: id, LocalID: id, OutletID: req.OutletID,
		Name: req.Name, Code: req.Code, Description: req.Description,
		CategoryID: req.CategoryID, CategoryName: req.CategoryName,
		Price: req.Price, Destination: req.Destination,
		Version: 1, CreatedAt: now, UpdatedAt: now, SyncedAt: now,
	}, nil
}

func AdminUpdateProduct(id string, req models.AdminUpdateProductRequest) error {
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
		    price=$6, destination=$7,
		    updated_at=NOW(), version=version+1
		WHERE id=$8 AND is_deleted=false`,
		req.Name, nullStr(req.Code), req.Description, req.CategoryID, req.CategoryName,
		req.Price, req.Destination, id,
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
	now := time.Now().UTC()
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

func generateProductCode(outletID, productName string) string {
	name := strings.TrimSpace(productName)
	if name == "" {
		name = "P"
	}
	firstLetter := strings.ToUpper(string([]rune(name)[0]))

	var count int
	database.DB.QueryRow(
		`SELECT COUNT(*) FROM cloud_products
		WHERE outlet_id = $1 AND code = $2 AND is_deleted = false`,
		outletID, firstLetter,
	).Scan(&count)

	if count == 0 {
		return firstLetter
	}

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
	codePrefix := strings.TrimSpace(req.CodePrefix)
	if codePrefix == "" {
		codePrefix = generateCategoryCodePrefix(req.Name)
	}

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
