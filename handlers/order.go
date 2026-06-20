package handlers

import (
	"cloud-pos/models"
	"cloud-pos/services"
	"math"
	"time"

	"github.com/gofiber/fiber/v2"
)

func PushOrder(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)

	var req models.PushOrderRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Invalid request body",
		})
	}

	if req.LocalID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "local_id is required",
		})
	}

	cloudID, err := services.SaveOrder(outletID, req)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to save order: " + err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(models.APIResponse{
		Success: true,
		Data: fiber.Map{
			"cloud_id":  cloudID,
			"local_id":  req.LocalID,
			"version":   req.Version,
			"synced_at": time.Now().UTC().Format(time.RFC3339),
		},
	})
}

func GetOrders(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)
	page, limit := getPagination(c)

	orders, total, err := services.GetOrders(outletID, page, limit)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get orders",
		})
	}

	return c.JSON(models.PaginatedResponse{
		Success:    true,
		Data:       orders,
		Page:       page,
		Limit:      limit,
		Total:      total,
		TotalPages: int(math.Ceil(float64(total) / float64(limit))),
	})
}

func PushTransaction(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)

	var req models.PushTransactionRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Invalid request body",
		})
	}

	if req.LocalID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "local_id is required",
		})
	}

	cloudID, err := services.SaveTransaction(outletID, req)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to save transaction: " + err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(models.APIResponse{
		Success: true,
		Data: fiber.Map{
			"cloud_id":  cloudID,
			"local_id":  req.LocalID,
			"version":   req.Version,
			"synced_at": time.Now().UTC().Format(time.RFC3339),
		},
	})
}

func GetTransactions(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)
	page, limit := getPagination(c)

	txns, total, err := services.GetTransactions(outletID, page, limit)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get transactions",
		})
	}

	return c.JSON(models.PaginatedResponse{
		Success:    true,
		Data:       txns,
		Page:       page,
		Limit:      limit,
		Total:      total,
		TotalPages: int(math.Ceil(float64(total) / float64(limit))),
	})
}
