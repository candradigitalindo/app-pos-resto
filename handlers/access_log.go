package handlers

import (
	"cloud-pos/models"
	"cloud-pos/services"

	"github.com/gofiber/fiber/v2"
)

// GetAccessLogs lists login/access history (superadmin only — gated by middleware).
func GetAccessLogs(c *fiber.Ctx) error {
	page, limit := getPagination(c)
	search := c.Query("search")
	status := c.Query("status")
	dateFrom := c.Query("date_from")
	dateTo := c.Query("date_to")
	logs, total, err := services.ListAccessLogs(search, status, dateFrom, dateTo, page, limit)
	if err != nil {
		return c.Status(500).JSON(models.APIResponse{Success: false, Error: err.Error()})
	}
	totalPages := (total + limit - 1) / limit
	if totalPages < 1 {
		totalPages = 1
	}
	return c.JSON(models.PaginatedResponse{
		Success: true, Data: logs, Page: page, Limit: limit, Total: total, TotalPages: totalPages,
	})
}
