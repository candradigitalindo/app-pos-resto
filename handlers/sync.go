package handlers

import (
	"cloud-pos/models"
	"cloud-pos/services"
	"strconv"
	"time"

	"github.com/gofiber/fiber/v2"
)

func PushAnalytics(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)

	var req models.PushAnalyticsRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Invalid request body",
		})
	}

	if req.Date == "" {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "date is required",
		})
	}

	cloudID, err := services.SaveAnalytics(outletID, req)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to save analytics: " + err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(models.APIResponse{
		Success: true,
		Data: fiber.Map{
			"cloud_id":  cloudID,
			"synced_at": time.Now().UTC().Format(time.RFC3339),
		},
	})
}

func GetAnalytics(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")

	analytics, err := services.GetAnalytics(outletID, startDate, endDate)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get analytics",
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: analytics,
	})
}

func BatchSync(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)

	var req models.BatchSyncRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Invalid request body",
		})
	}

	if len(req.Items) == 0 {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "No items to sync",
		})
	}

	if len(req.Items) > 1000 {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Maximum 1000 items per batch",
		})
	}

	result := services.ProcessBatchSync(outletID, req)

	return c.JSON(models.APIResponse{
		Success: true, Data: result,
	})
}

func GetUpdates(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)
	since := c.Query("since")

	if since == "" {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "since parameter is required (ISO 8601)",
		})
	}

	updates, err := services.GetUpdatesSince(outletID, since)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get updates: " + err.Error(),
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: updates,
	})
}

func GetConflicts(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)

	conflicts, err := services.GetConflicts(outletID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get conflicts",
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: conflicts,
	})
}

func ResolveConflict(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)
	conflictID := c.Params("conflictId")

	var req models.ResolveConflictRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Invalid request body",
		})
	}

	validStrategies := map[string]bool{
		"cloud_wins": true, "local_wins": true, "newest_wins": true,
	}
	if !validStrategies[req.Strategy] {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "strategy must be: cloud_wins, local_wins, or newest_wins",
		})
	}

	if err := services.ResolveConflict(outletID, conflictID, req); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to resolve conflict",
		})
	}

	return c.JSON(models.APIResponse{
		Success: true,
		Message: "Conflict resolved successfully",
		Data: fiber.Map{
			"resolved":    true,
			"resolved_at": time.Now().UTC().Format(time.RFC3339),
		},
	})
}

func GetRestore(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)

	data, err := services.GetRestoreData(outletID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Gagal mengambil data restore: " + err.Error(),
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: data,
	})
}

func GetSyncLogs(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)
	limit, _ := strconv.Atoi(c.Query("limit", "50"))
	if limit < 1 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}

	logs, err := services.GetSyncLogs(outletID, limit)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get sync logs",
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: logs,
	})
}
