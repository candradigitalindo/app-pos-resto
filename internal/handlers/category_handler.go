package handlers

import (
	"backend/internal/db"
	"backend/internal/services"
	"database/sql"
	"time"

	"github.com/labstack/echo/v5"
)

type CategoryHandler struct {
	categoryService services.CategoryService
}

func NewCategoryHandler(categoryService services.CategoryService) *CategoryHandler {
	return &CategoryHandler{
		categoryService: categoryService,
	}
}

type CreateCategoryRequest struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	PrinterID   string `json:"printer_id"`
}

type UpdateCategoryRequest struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	PrinterID   string `json:"printer_id"`
}

// CategoryResponse untuk serialisasi JSON yang proper
type CategoryResponse struct {
	ID           string    `json:"id"`
	Name         string    `json:"name"`
	Description  *string   `json:"description"`
	PrinterID    *string   `json:"printer_id"`
	PrinterName  *string   `json:"printer_name"`
	PrinterType  *string   `json:"printer_type"`
	ProductCount int64     `json:"product_count"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// Convert db.GetCategoryRow to CategoryResponse
func toGetCategoryResponse(cat db.GetCategoryRow) CategoryResponse {
	var desc *string
	if cat.Description.Valid {
		desc = &cat.Description.String
	}
	var printerID *string
	if cat.PrinterID.Valid {
		printerID = &cat.PrinterID.String
	}
	var printerName *string
	if cat.PrinterName.Valid {
		printerName = &cat.PrinterName.String
	}
	var printerType *string
	if cat.PrinterType.Valid {
		printerType = &cat.PrinterType.String
	}
	return CategoryResponse{
		ID:          cat.ID,
		Name:        cat.Name,
		Description: desc,
		PrinterID:   printerID,
		PrinterName: printerName,
		PrinterType: printerType,
		CreatedAt:   cat.CreatedAt,
		UpdatedAt:   cat.UpdatedAt,
	}
}

// Convert db.ListCategoriesRow to CategoryResponse
func toListCategoryResponse(cat db.ListCategoriesRow) CategoryResponse {
	var desc *string
	if cat.Description.Valid {
		desc = &cat.Description.String
	}
	var printerID *string
	if cat.PrinterID.Valid {
		printerID = &cat.PrinterID.String
	}
	var printerName *string
	if cat.PrinterName.Valid {
		printerName = &cat.PrinterName.String
	}
	var printerType *string
	if cat.PrinterType.Valid {
		printerType = &cat.PrinterType.String
	}
	return CategoryResponse{
		ID:           cat.ID,
		Name:         cat.Name,
		Description:  desc,
		PrinterID:    printerID,
		PrinterName:  printerName,
		PrinterType:  printerType,
		ProductCount: cat.ProductCount,
		CreatedAt:    cat.CreatedAt,
		UpdatedAt:    cat.UpdatedAt,
	}
}

// Convert db.Category to CategoryResponse (for create operation)
func toCategoryResponse(cat db.Category) CategoryResponse {
	var desc *string
	if cat.Description.Valid {
		desc = &cat.Description.String
	}
	var printerID *string
	if cat.PrinterID.Valid {
		printerID = &cat.PrinterID.String
	}
	return CategoryResponse{
		ID:          cat.ID,
		Name:        cat.Name,
		Description: desc,
		PrinterID:   printerID,
		PrinterName: nil,
		PrinterType: nil,
		CreatedAt:   cat.CreatedAt,
		UpdatedAt:   cat.UpdatedAt,
	}
}

// Convert slice of db.ListCategoriesRow to slice of CategoryResponse
func toListCategoryResponses(categories []db.ListCategoriesRow) []CategoryResponse {
	responses := make([]CategoryResponse, len(categories))
	for i, cat := range categories {
		responses[i] = toListCategoryResponse(cat)
	}
	return responses
}

// Convert slice of db.ListCategoriesPaginatedRow to slice of CategoryResponse
func toPaginatedCategoryResponses(categories []db.ListCategoriesPaginatedRow) []CategoryResponse {
	responses := make([]CategoryResponse, len(categories))
	for i, cat := range categories {
		var desc *string
		if cat.Description.Valid {
			desc = &cat.Description.String
		}
		var printerID *string
		if cat.PrinterID.Valid {
			printerID = &cat.PrinterID.String
		}
		var printerName *string
		if cat.PrinterName.Valid {
			printerName = &cat.PrinterName.String
		}
		var printerType *string
		if cat.PrinterType.Valid {
			printerType = &cat.PrinterType.String
		}
		responses[i] = CategoryResponse{
			ID:          cat.ID,
			Name:        cat.Name,
			Description: desc,
			PrinterID:   printerID,
			PrinterName: printerName,
			PrinterType: printerType,
			CreatedAt:   cat.CreatedAt,
			UpdatedAt:   cat.UpdatedAt,
		}
	}
	return responses
}

func (h *CategoryHandler) CreateCategory(c *echo.Context) error {
	var req CreateCategoryRequest
	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	category, err := h.categoryService.CreateCategory((*c).Request().Context(), req.Name, req.Description, req.PrinterID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal membuat kategori: "+err.Error())
	}

	return CreatedResponse(c, "Kategori berhasil dibuat", toCategoryResponse(*category))
}

func (h *CategoryHandler) GetCategory(c *echo.Context) error {
	id := c.Param("id")

	category, err := h.categoryService.GetCategoryByID((*c).Request().Context(), id)
	if err != nil {
		if err == sql.ErrNoRows {
			return NotFoundResponse(c, "Kategori tidak ditemukan")
		}
		return InternalErrorResponse(c, "Gagal mengambil kategori: "+err.Error())
	}

	return SuccessResponse(c, "Kategori berhasil diambil", toGetCategoryResponse(*category))
}

func (h *CategoryHandler) GetAllCategories(c *echo.Context) error {
	// Check if pagination params exist
	if c.QueryParam("page") != "" || c.QueryParam("page_size") != "" {
		// Use pagination
		params := GetPaginationParams(c)

		categories, total, err := h.categoryService.GetCategoriesPaginated(
			(*c).Request().Context(),
			int64(params.PageSize),
			int64(params.Offset),
		)
		if err != nil {
			return InternalErrorResponse(c, "Gagal mengambil data kategori: "+err.Error())
		}

		pagination := CalculatePagination(params.Page, params.PageSize, total)
		return PaginatedSuccessResponse(c, "Data kategori berhasil diambil", toPaginatedCategoryResponses(categories), pagination)
	}

	// Return all categories without pagination
	categories, err := h.categoryService.GetAllCategories((*c).Request().Context())
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data kategori: "+err.Error())
	}

	return SuccessResponse(c, "Data kategori berhasil diambil", toListCategoryResponses(categories))
}

func (h *CategoryHandler) UpdateCategory(c *echo.Context) error {
	id := c.Param("id")

	var req UpdateCategoryRequest
	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	if err := h.categoryService.UpdateCategory((*c).Request().Context(), id, req.Name, req.Description, req.PrinterID); err != nil {
		return InternalErrorResponse(c, "Gagal update kategori: "+err.Error())
	}

	category, _ := h.categoryService.GetCategoryByID((*c).Request().Context(), id)
	return SuccessResponse(c, "Kategori berhasil diupdate", toGetCategoryResponse(*category))
}

func (h *CategoryHandler) DeleteCategory(c *echo.Context) error {
	id := c.Param("id")

	if err := h.categoryService.DeleteCategory((*c).Request().Context(), id); err != nil {
		return InternalErrorResponse(c, "Gagal menghapus kategori: "+err.Error())
	}

	return SuccessResponse(c, "Kategori berhasil dihapus", nil)
}
