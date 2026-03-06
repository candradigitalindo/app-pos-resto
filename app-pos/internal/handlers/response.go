package handlers

import (
	"net/http"

	"github.com/labstack/echo/v5"
)

// APIResponse adalah struktur standar untuk semua response API
type APIResponse struct {
	Success bool        `json:"success"`
	Message string      `json:"message,omitempty"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

// SuccessResponse mengembalikan response sukses dengan data
func SuccessResponse(c *echo.Context, message string, data interface{}) error {
	return (*c).JSON(http.StatusOK, APIResponse{
		Success: true,
		Message: message,
		Data:    data,
	})
}

// CreatedResponse mengembalikan response sukses untuk data yang baru dibuat
func CreatedResponse(c *echo.Context, message string, data interface{}) error {
	return (*c).JSON(http.StatusCreated, APIResponse{
		Success: true,
		Message: message,
		Data:    data,
	})
}

// ErrorResponse mengembalikan response error
func ErrorResponse(c *echo.Context, statusCode int, message string) error {
	return (*c).JSON(statusCode, APIResponse{
		Success: false,
		Message: message,
	})
}

// BadRequestResponse mengembalikan response bad request (400)
func BadRequestResponse(c *echo.Context, message string) error {
	return ErrorResponse(c, http.StatusBadRequest, message)
}

// UnauthorizedResponse mengembalikan response unauthorized (401)
func UnauthorizedResponse(c *echo.Context, message string) error {
	return ErrorResponse(c, http.StatusUnauthorized, message)
}

// NotFoundResponse mengembalikan response not found (404)
func NotFoundResponse(c *echo.Context, message string) error {
	return ErrorResponse(c, http.StatusNotFound, message)
}

// ConflictResponse mengembalikan response conflict (409)
func ConflictResponse(c *echo.Context, message string) error {
	return ErrorResponse(c, http.StatusConflict, message)
}

// InternalErrorResponse mengembalikan response internal server error (500)
func InternalErrorResponse(c *echo.Context, message string) error {
	return ErrorResponse(c, http.StatusInternalServerError, message)
}
