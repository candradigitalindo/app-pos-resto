package handlers

import (
	"cloud-pos/models"
	"cloud-pos/services"
	"math"
	"time"

	"github.com/gofiber/fiber/v2"
)

func PushProduct(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)

	var req models.PushProductRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Invalid request body",
		})
	}

	if req.LocalID == "" || req.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "local_id and name are required",
		})
	}

	cloudID, err := services.SaveProduct(outletID, req)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to save product: " + err.Error(),
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

func GetProducts(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)
	page, limit := getPagination(c)

	products, total, err := services.GetProducts(outletID, page, limit)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get products",
		})
	}

	return c.JSON(models.PaginatedResponse{
		Success:    true,
		Data:       products,
		Page:       page,
		Limit:      limit,
		Total:      total,
		TotalPages: int(math.Ceil(float64(total) / float64(limit))),
	})
}

func GetOutletCategories(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)

	rows, err := services.GetOutletCategoriesWithPrinter(outletID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get categories",
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: rows,
	})
}

func UpdateCategoryPrinter(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)
	categoryID := c.Params("categoryId")

	var body struct {
		PrinterID string `json:"printer_id"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Invalid request body",
		})
	}

	if err := services.UpdateCategoryPrinter(outletID, categoryID, body.PrinterID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to update category printer: " + err.Error(),
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Message: "Printer kategori berhasil diperbarui",
	})
}

func GetOutletPrinters(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)

	printers, err := services.GetOutletPrinters(outletID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get printers",
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: printers,
	})
}

func PushPrinter(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)

	var req models.PushPrinterRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Invalid request body",
		})
	}

	if req.LocalID == "" || req.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "local_id and name are required",
		})
	}

	cloudID, err := services.SavePrinter(outletID, req)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to save printer: " + err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(models.APIResponse{
		Success: true,
		Data: fiber.Map{
			"cloud_id":  cloudID,
			"local_id":  req.LocalID,
			"synced_at": time.Now().UTC().Format(time.RFC3339),
		},
	})
}
