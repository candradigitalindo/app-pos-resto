package handlers

import (
	"cloud-pos/models"
	"cloud-pos/services"
	"log"

	"github.com/gofiber/fiber/v2"
)

func GetDashboard(c *fiber.Ctx) error {
	dateFrom := c.Query("date_from", "")
	dateTo := c.Query("date_to", "")
	scopeIDs := getOutletScope(c)
	stats, err := services.GetDashboardStats(dateFrom, dateTo, scopeIDs)
	if err != nil {
		log.Printf("GetDashboard error: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get dashboard stats: " + err.Error(),
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: stats,
	})
}

func GetManagerDashboard(c *fiber.Ctx) error {
	scopeIDs := getOutletScope(c)
	stats, err := services.GetManagerDashboard(scopeIDs)
	if err != nil {
		log.Printf("GetManagerDashboard error: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get manager dashboard: " + err.Error(),
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: stats,
	})
}
