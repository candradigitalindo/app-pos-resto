package handlers

import (
	"strconv"

	"github.com/labstack/echo/v5"
)

// PaginationParams berisi parameter untuk pagination
type PaginationParams struct {
	Page     int `json:"page"`
	PageSize int `json:"page_size"`
	Offset   int `json:"-"`
}

// PaginatedResponse adalah struktur standar untuk response dengan pagination
type PaginatedResponse struct {
	Success    bool        `json:"success"`
	Message    string      `json:"message,omitempty"`
	Data       interface{} `json:"data"`
	Pagination Pagination  `json:"pagination"`
}

// Pagination berisi metadata pagination
type Pagination struct {
	CurrentPage int   `json:"current_page"`
	PageSize    int   `json:"page_size"`
	TotalItems  int64 `json:"total_items"`
	TotalPages  int   `json:"total_pages"`
}

// GetPaginationParams mengambil parameter pagination dari query string
// Default: page=1, page_size=10
func GetPaginationParams(c *echo.Context) PaginationParams {
	page, _ := strconv.Atoi(c.QueryParam("page"))
	if page < 1 {
		page = 1
	}

	pageSize, _ := strconv.Atoi(c.QueryParam("page_size"))
	if pageSize < 1 {
		pageSize = 10
	}
	if pageSize > 100 {
		pageSize = 100 // Maximum page size
	}

	offset := (page - 1) * pageSize

	return PaginationParams{
		Page:     page,
		PageSize: pageSize,
		Offset:   offset,
	}
}

// CalculatePagination menghitung metadata pagination
func CalculatePagination(page, pageSize int, totalItems int64) Pagination {
	totalPages := int(totalItems) / pageSize
	if int(totalItems)%pageSize > 0 {
		totalPages++
	}

	return Pagination{
		CurrentPage: page,
		PageSize:    pageSize,
		TotalItems:  totalItems,
		TotalPages:  totalPages,
	}
}

// PaginatedSuccessResponse mengembalikan response sukses dengan pagination
func PaginatedSuccessResponse(c *echo.Context, message string, data interface{}, pagination Pagination) error {
	return c.JSON(200, PaginatedResponse{
		Success:    true,
		Message:    message,
		Data:       data,
		Pagination: pagination,
	})
}
