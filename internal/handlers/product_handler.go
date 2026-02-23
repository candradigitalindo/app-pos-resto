package handlers

import (
	"backend/internal/db"
	"backend/internal/services"
	"database/sql"

	"github.com/labstack/echo/v5"
)

type ProductHandler struct {
	productService services.ProductService
}

func NewProductHandler(productService services.ProductService) *ProductHandler {
	return &ProductHandler{
		productService: productService,
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
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Code        string  `json:"code"`
	Description string  `json:"description"`
	Price       float64 `json:"price"`
	Stock       int64   `json:"stock"`
	CategoryID  string  `json:"category_id"`
	CreatedAt   string  `json:"created_at"`
	UpdatedAt   string  `json:"updated_at"`
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

// Convert slice of db.Product to slice of ProductResponse
func toProductResponses(products []db.Product) []ProductResponse {
	responses := make([]ProductResponse, len(products))
	for i, p := range products {
		responses[i] = toProductResponse(p)
	}
	return responses
}

func (h *ProductHandler) CreateProduct(c *echo.Context) error {
	var req CreateProductRequest
	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	// Validasi kategori wajib
	if req.CategoryID == "" {
		return BadRequestResponse(c, "Kategori wajib dipilih")
	}

	catID := &req.CategoryID
	// Code akan di-generate otomatis oleh service, jadi selalu pass empty string
	product, err := h.productService.CreateProduct((*c).Request().Context(), req.Name, "", req.Description, req.Price, req.Stock, catID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal membuat produk: "+err.Error())
	}

	return CreatedResponse(c, "Produk berhasil dibuat", toProductResponse(*product))
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

	var products []db.Product
	var total int64
	var err error

	// Use search if search or category filter provided
	if search != "" || categoryID != "" {
		products, total, err = h.productService.SearchProducts(
			(*c).Request().Context(),
			search,
			categoryID,
			int64(params.PageSize),
			int64(params.Offset),
		)
	} else {
		products, total, err = h.productService.GetProductsPaginated(
			(*c).Request().Context(),
			int64(params.PageSize),
			int64(params.Offset),
		)
	}

	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data produk: "+err.Error())
	}

	pagination := CalculatePagination(params.Page, params.PageSize, total)
	return PaginatedSuccessResponse(c, "Data produk berhasil diambil", toProductResponses(products), pagination)
}

func (h *ProductHandler) UpdateProduct(c *echo.Context) error {
	id := c.Param("id")

	var req UpdateProductRequest
	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	// Validasi kategori wajib
	if req.CategoryID == "" {
		return BadRequestResponse(c, "Kategori wajib dipilih")
	}

	catID := &req.CategoryID
	// Code akan di-generate otomatis dari nama, jadi selalu pass empty string
	if err := h.productService.UpdateProduct((*c).Request().Context(), id, req.Name, "", req.Description, req.Price, req.Stock, catID); err != nil {
		return InternalErrorResponse(c, "Gagal update produk: "+err.Error())
	}

	product, err := h.productService.GetProductByID((*c).Request().Context(), id)
	if err != nil {
		return InternalErrorResponse(c, "Gagal get product: "+err.Error())
	}

	return SuccessResponse(c, "Produk berhasil diupdate", toProductResponse(*product))
}

func (h *ProductHandler) DeleteProduct(c *echo.Context) error {
	id := c.Param("id")

	if err := h.productService.DeleteProduct((*c).Request().Context(), id); err != nil {
		return InternalErrorResponse(c, "Gagal menghapus produk: "+err.Error())
	}

	return SuccessResponse(c, "Produk berhasil dihapus", nil)
}

func (h *ProductHandler) GetProductsByCategory(c *echo.Context) error {
	categoryID := c.Param("categoryId")

	products, err := h.productService.GetProductsByCategory((*c).Request().Context(), categoryID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil produk: "+err.Error())
	}

	return SuccessResponse(c, "Produk berhasil diambil", toProductResponses(products))
}
