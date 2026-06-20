package handlers

import (
	"cloud-pos/models"
	"cloud-pos/services"

	"github.com/gofiber/fiber/v2"
)

func ListWorkUnits(c *fiber.Ctx) error {
	wuScopeIDs := getWorkUnitScope(c)
	units, err := services.ListWorkUnits(wuScopeIDs)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Gagal memuat unit kerja: " + err.Error(),
		})
	}
	return c.JSON(models.APIResponse{Success: true, Data: units})
}

// GetMyWorkUnits returns work units accessible to the current user based on scope.
// For dropdown filters in purchase pages — requires only procurement.view.
func GetMyWorkUnits(c *fiber.Ctx) error {
	wuScopeIDs := getWorkUnitScope(c)
	units, err := services.ListWorkUnits(wuScopeIDs)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Gagal memuat unit kerja",
		})
	}
	return c.JSON(models.APIResponse{Success: true, Data: units})
}

func CreateWorkUnit(c *fiber.Ctx) error {
	var req models.CreateWorkUnitRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Invalid request body",
		})
	}

	wu, err := services.CreateWorkUnit(req)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: err.Error(),
		})
	}
	return c.Status(fiber.StatusCreated).JSON(models.APIResponse{Success: true, Data: wu})
}

func GetWorkUnit(c *fiber.Ctx) error {
	id := c.Params("id")
	wu, err := services.GetWorkUnit(id)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(models.APIResponse{
			Success: false, Error: "Unit kerja tidak ditemukan",
		})
	}
	return c.JSON(models.APIResponse{Success: true, Data: wu})
}

func UpdateWorkUnit(c *fiber.Ctx) error {
	id := c.Params("id")
	var req models.UpdateWorkUnitRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Invalid request body",
		})
	}

	wu, err := services.UpdateWorkUnit(id, req)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: err.Error(),
		})
	}
	return c.JSON(models.APIResponse{Success: true, Data: wu})
}

// GetMyWorkUnit returns the work unit assigned to the authenticated admin.
func GetMyWorkUnit(c *fiber.Ctx) error {
	adminID, _ := c.Locals("admin_id").(string)
	if adminID == "" || adminID == "static" {
		return c.JSON(models.APIResponse{Success: true, Data: nil})
	}

	wu, err := services.GetWorkUnitByAdminID(adminID)
	if err != nil || wu == nil {
		return c.JSON(models.APIResponse{Success: true, Data: nil})
	}
	return c.JSON(models.APIResponse{Success: true, Data: wu})
}

// DeleteWorkUnit removes a work unit by id.
func DeleteWorkUnit(c *fiber.Ctx) error {
	id := c.Params("id")
	if err := services.DeleteWorkUnit(id); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: err.Error(),
		})
	}
	return c.JSON(models.APIResponse{Success: true, Data: fiber.Map{"deleted": id}})
}
