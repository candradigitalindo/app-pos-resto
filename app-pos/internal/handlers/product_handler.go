package handlers

import (
	"backend/internal/db"
	"backend/internal/services"
	"backend/pkg/utils"
	"context"
	"database/sql"
	"net/http"

	"github.com/labstack/echo/v5"
)

type ProductHandler struct {
	productService services.ProductService
	db             *sql.DB
}

func NewProductHandler(productService services.ProductService, db *sql.DB) *ProductHandler {
	return &ProductHandler{
		productService: productService,
		db:             db,
	}
}

type CreateProductRequest struct {
	Name        string  `json:"name"`
	Code        string  `json:"code"`
	Description string  `json:"description"`
	Price       float64 `json:"price"`
	Stock       int64   `json:"stock"`
	CategoryID  string  `json:"category_id"` // Wajib
}

type UpdateProductRequest struct {
	Name        string  `json:"name"`
	Code        string  `json:"code"`
	Description string  `json:"description"`
	Price       float64 `json:"price"`
	Stock       int64   `json:"stock"`
	CategoryID  string  `json:"category_id"` // Wajib
}

// ProductResponse untuk serialisasi JSON yang proper
type ProductResponse struct {
	ID           string  `json:"id"`
	Name         string  `json:"name"`
	Code         string  `json:"code"`
	Description  string  `json:"description"`
	Price        float64 `json:"price"`
	Stock        int64   `json:"stock"`
	CategoryID   string  `json:"category_id"`
	CategoryName string  `json:"category_name"`
	CreatedAt    string  `json:"created_at"`
	UpdatedAt    string  `json:"updated_at"`
}

// Convert db.Product to ProductResponse
func toProductResponse(p db.Product) ProductResponse {
	desc := ""
	if p.Description.Valid {
		desc = p.Description.String
	}
	catID := ""
	if p.CategoryID.Valid {
		catID = p.CategoryID.String
	}
	code := ""
	if p.Code.Valid {
		code = p.Code.String
	}
	return ProductResponse{
		ID:          p.ID,
		Name:        p.Name,
		Code:        code,
		Description: desc,
		Price:       p.Price,
		Stock:       p.Stock,
		CategoryID:  catID,
		CreatedAt:   p.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
		UpdatedAt:   p.UpdatedAt.Format("2006-01-02T15:04:05Z07:00"),
	}
}

// Convert slice of db.Product to slice of ProductResponse with category name map
func toProductResponses(products []db.Product, catMap map[string]string) []ProductResponse {
	responses := make([]ProductResponse, len(products))
	for i, p := range products {
		r := toProductResponse(p)
		if catMap != nil && r.CategoryID != "" {
			r.CategoryName = catMap[r.CategoryID]
		}
		responses[i] = r
	}
	return responses
}

// getCategoryNameMap returns a map of category ID → name (includes soft-deleted)
func (h *ProductHandler) getCategoryNameMap(ctx context.Context) map[string]string {
	rows, err := h.db.QueryContext(ctx, "SELECT id, name FROM categories")
	if err != nil {
		return nil
	}
	defer rows.Close()
	catMap := make(map[string]string)
	for rows.Next() {
		var id, name string
		if err := rows.Scan(&id, &name); err == nil {
			catMap[id] = name
		}
	}
	return catMap
}

// CreateProduct dinonaktifkan — produk dikelola via Cloud POS
func (h *ProductHandler) CreateProduct(c *echo.Context) error {
	return (*c).JSON(http.StatusLocked, APIResponse{
		Success: false,
		Message: "Produk dikelola melalui Cloud POS. Tambah produk di halaman manajemen cloud.",
	})
}

func (h *ProductHandler) GetProduct(c *echo.Context) error {
	id := c.Param("id")

	product, err := h.productService.GetProductByID((*c).Request().Context(), id)
	if err != nil {
		if err == sql.ErrNoRows {
			return NotFoundResponse(c, "Produk tidak ditemukan")
		}
		return InternalErrorResponse(c, "Gagal mengambil produk: "+err.Error())
	}

	return SuccessResponse(c, "Produk berhasil diambil", toProductResponse(*product))
}

func (h *ProductHandler) GetAllProducts(c *echo.Context) error {
	// Get pagination params
	params := GetPaginationParams(c)

	// Get search and filter params
	search := c.QueryParam("search")
	categoryID := c.QueryParam("category_id")

	ctx := (*c).Request().Context()

	var products []db.Product
	var total int64
	var err error

	// Use search if search or category filter provided
	if search != "" || categoryID != "" {
		products, total, err = h.productService.SearchProducts(ctx, search, categoryID, int64(params.PageSize), int64(params.Offset))
	} else {
		products, total, err = h.productService.GetProductsPaginated(ctx, int64(params.PageSize), int64(params.Offset))
	}

	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data produk: "+err.Error())
	}

	// Build category name map (include soft-deleted for proper name display)
	catMap := h.getCategoryNameMap(ctx)

	pagination := CalculatePagination(params.Page, params.PageSize, total)
	return PaginatedSuccessResponse(c, "Data produk berhasil diambil", toProductResponses(products, catMap), pagination)
}

// UpdateProduct dinonaktifkan — produk dikelola via Cloud POS
func (h *ProductHandler) UpdateProduct(c *echo.Context) error {
	return (*c).JSON(http.StatusLocked, APIResponse{
		Success: false,
		Message: "Produk dikelola melalui Cloud POS. Edit produk di halaman manajemen cloud.",
	})
}

// DeleteProduct dinonaktifkan — produk dikelola via Cloud POS
func (h *ProductHandler) DeleteProduct(c *echo.Context) error {
	return (*c).JSON(http.StatusLocked, APIResponse{
		Success: false,
		Message: "Produk dikelola melalui Cloud POS. Hapus produk di halaman manajemen cloud.",
	})
}

func (h *ProductHandler) GetProductsByCategory(c *echo.Context) error {
	categoryID := c.Param("categoryId")

	products, err := h.productService.GetProductsByCategory((*c).Request().Context(), categoryID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil produk: "+err.Error())
	}

	return SuccessResponse(c, "Produk berhasil diambil", toProductResponses(products, nil))
}

func (h *ProductHandler) GetProductNotes(c *echo.Context) error {
	productID := c.Param("id")
	if productID == "" {
		return BadRequestResponse(c, "product id wajib diisi")
	}

	rows, err := h.db.QueryContext((*c).Request().Context(),
		`SELECT id, note_text, usage_count FROM product_notes WHERE product_id = ? ORDER BY usage_count DESC, updated_at DESC LIMIT 5`,
		productID,
	)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil catatan produk: "+err.Error())
	}
	defer rows.Close()

	type NoteResponse struct {
		ID         string `json:"id"`
		NoteText   string `json:"note_text"`
		UsageCount int64  `json:"usage_count"`
	}
	notes := make([]NoteResponse, 0)
	for rows.Next() {
		var n NoteResponse
		if err := rows.Scan(&n.ID, &n.NoteText, &n.UsageCount); err != nil {
			return InternalErrorResponse(c, "Gagal membaca catatan: "+err.Error())
		}
		notes = append(notes, n)
	}

	return SuccessResponse(c, "Catatan produk berhasil diambil", notes)
}

// === Product Addons (Additional items with prices) ===

type AddonResponse struct {
	ID        string  `json:"id"`
	ProductID string  `json:"product_id"`
	Name      string  `json:"name"`
	Price     float64 `json:"price"`
	IsActive  bool    `json:"is_active"`
}

type CreateAddonRequest struct {
	Name  string  `json:"name"`
	Price float64 `json:"price"`
}

func (h *ProductHandler) GetProductAddons(c *echo.Context) error {
	productID := c.Param("id")
	if productID == "" {
		return BadRequestResponse(c, "product id wajib diisi")
	}

	rows, err := h.db.QueryContext((*c).Request().Context(),
		`SELECT id, product_id, name, price, is_active FROM product_addons WHERE product_id = ? AND is_active = 1 ORDER BY name`,
		productID,
	)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil addon: "+err.Error())
	}
	defer rows.Close()

	addons := make([]AddonResponse, 0)
	for rows.Next() {
		var a AddonResponse
		var isActive int
		if err := rows.Scan(&a.ID, &a.ProductID, &a.Name, &a.Price, &isActive); err != nil {
			return InternalErrorResponse(c, "Gagal membaca addon: "+err.Error())
		}
		a.IsActive = isActive == 1
		addons = append(addons, a)
	}

	return SuccessResponse(c, "Addon produk berhasil diambil", addons)
}

func (h *ProductHandler) CreateProductAddon(c *echo.Context) error {
	productID := c.Param("id")
	if productID == "" {
		return BadRequestResponse(c, "product id wajib diisi")
	}

	var req CreateAddonRequest
	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Format request tidak valid")
	}
	if req.Name == "" {
		return BadRequestResponse(c, "Nama addon wajib diisi")
	}
	if req.Price < 0 {
		return BadRequestResponse(c, "Harga addon tidak boleh negatif")
	}

	id := utils.GenerateULID()
	_, err := h.db.ExecContext((*c).Request().Context(),
		`INSERT INTO product_addons (id, product_id, name, price) VALUES (?, ?, ?, ?)`,
		id, productID, req.Name, req.Price,
	)
	if err != nil {
		return InternalErrorResponse(c, "Gagal membuat addon: "+err.Error())
	}

	return SuccessResponse(c, "Addon berhasil ditambahkan", AddonResponse{
		ID:        id,
		ProductID: productID,
		Name:      req.Name,
		Price:     req.Price,
		IsActive:  true,
	})
}

func (h *ProductHandler) UpdateProductAddon(c *echo.Context) error {
	addonID := c.Param("addonId")
	if addonID == "" {
		return BadRequestResponse(c, "addon id wajib diisi")
	}

	var req CreateAddonRequest
	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Format request tidak valid")
	}
	if req.Name == "" {
		return BadRequestResponse(c, "Nama addon wajib diisi")
	}
	if req.Price < 0 {
		return BadRequestResponse(c, "Harga addon tidak boleh negatif")
	}

	result, err := h.db.ExecContext((*c).Request().Context(),
		`UPDATE product_addons SET name = ?, price = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?`,
		req.Name, req.Price, addonID,
	)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengupdate addon: "+err.Error())
	}
	affected, _ := result.RowsAffected()
	if affected == 0 {
		return NotFoundResponse(c, "Addon tidak ditemukan")
	}

	return SuccessResponse(c, "Addon berhasil diupdate", nil)
}

func (h *ProductHandler) DeleteProductAddon(c *echo.Context) error {
	addonID := c.Param("addonId")
	if addonID == "" {
		return BadRequestResponse(c, "addon id wajib diisi")
	}

	result, err := h.db.ExecContext((*c).Request().Context(),
		`UPDATE product_addons SET is_active = 0, updated_at = CURRENT_TIMESTAMP WHERE id = ?`,
		addonID,
	)
	if err != nil {
		return InternalErrorResponse(c, "Gagal menghapus addon: "+err.Error())
	}
	affected, _ := result.RowsAffected()
	if affected == 0 {
		return NotFoundResponse(c, "Addon tidak ditemukan")
	}

	return SuccessResponse(c, "Addon berhasil dihapus", nil)
}
