package handlers

import (
	"cloud-pos/models"
	"cloud-pos/services"

	"github.com/gofiber/fiber/v2"
)

func CreateOutlet(c *fiber.Ctx) error {
	var req models.CreateOutletRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Invalid request body",
		})
	}

	if req.Code == "" || req.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Code and name are required",
		})
	}

	outlet, err := services.CreateOutlet(req)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to create outlet: " + err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(models.APIResponse{
		Success: true, Data: outlet,
	})
}

func GetOutlets(c *fiber.Ctx) error {
	scopeIDs := getOutletScope(c)
	outlets, err := services.GetOutletsScoped(scopeIDs)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get outlets",
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: outlets,
	})
}

// GetMyOutlets returns outlets accessible to the current user based on scope.
// No specific permission required — any authenticated admin can see their scoped outlets.
func GetMyOutlets(c *fiber.Ctx) error {
	scopeIDs := getOutletScope(c)
	wuScopeIDs := getWorkUnitScope(c)
	outlets, err := services.GetMyScopeOutlets(scopeIDs, wuScopeIDs)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Gagal memuat outlet",
		})
	}
	return c.JSON(models.APIResponse{Success: true, Data: outlets})
}

func GetOutlet(c *fiber.Ctx) error {
	id := c.Params("id")
	if !validateOutletAccess(c, id) {
		return c.Status(fiber.StatusForbidden).JSON(models.APIResponse{
			Success: false, Error: "Akses outlet tidak diizinkan",
		})
	}
	outlet, err := services.GetOutlet(id)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(models.APIResponse{
			Success: false, Error: "Outlet not found",
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: outlet,
	})
}

func RegenerateOutletAPIKey(c *fiber.Ctx) error {
	id := c.Params("id")
	newKey, err := services.RegenerateAPIKey(id)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to regenerate API key",
		})
	}

	return c.JSON(models.APIResponse{
		Success: true,
		Data:    fiber.Map{"api_key": newKey},
		Message: "API key regenerated successfully",
	})
}

func UpdateOutlet(c *fiber.Ctx) error {
	id := c.Params("id")
	var req models.UpdateOutletRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Invalid request body",
		})
	}
	outlet, err := services.UpdateOutlet(id, req)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to update outlet: " + err.Error(),
		})
	}
	return c.JSON(models.APIResponse{Success: true, Data: outlet, Message: "Outlet berhasil diperbarui"})
}

func ToggleOutlet(c *fiber.Ctx) error {
	id := c.Params("id")
	outlet, err := services.ToggleOutlet(id)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to toggle outlet",
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: outlet,
	})
}

func DeleteOutlet(c *fiber.Ctx) error {
	id := c.Params("id")
	err := services.DeleteOutlet(id)
	if err != nil {
		if err.Error() == "outlet not found" {
			return c.Status(fiber.StatusNotFound).JSON(models.APIResponse{
				Success: false, Error: "Outlet tidak ditemukan",
			})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Gagal menghapus outlet: " + err.Error(),
		})
	}
	return c.JSON(models.APIResponse{Success: true, Message: "Outlet berhasil dihapus"})
}

// GetOutletInfo returns outlet info to the authenticated outlet itself
func GetOutletInfo(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)
	outlet, err := services.GetOutlet(outletID)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(models.APIResponse{
			Success: false, Error: "Outlet not found",
		})
	}

	taxSettings, _ := services.GetTaxSettings()

	return c.JSON(models.APIResponse{
		Success: true,
		Data: fiber.Map{
			"id":          outlet.ID,
			"code":        outlet.Code,
			"name":        outlet.Name,
			"address":     outlet.Address,
			"is_active":   outlet.IsActive,
			"created_at":  outlet.CreatedAt,
			"updated_at":  outlet.UpdatedAt,
			"tax_enabled": taxSettings.TaxEnabled,
			"tax_rate":    taxSettings.TaxRate,
			"tax_name":    taxSettings.TaxName,
		},
	})
}
