package handlers

import (
	"cloud-pos/models"
	"cloud-pos/services"

	"github.com/gofiber/fiber/v2"
)

func ListBankAccounts(c *fiber.Ctx) error {
	accounts, err := services.ListBankAccounts()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Gagal memuat data rekening: " + err.Error(),
		})
	}
	return c.JSON(models.APIResponse{Success: true, Data: accounts})
}

func CreateBankAccount(c *fiber.Ctx) error {
	var req models.CreateBankAccountRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Invalid request body",
		})
	}
	a, err := services.CreateBankAccount(req)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: err.Error(),
		})
	}
	return c.Status(fiber.StatusCreated).JSON(models.APIResponse{Success: true, Data: a})
}

func UpdateBankAccount(c *fiber.Ctx) error {
	id := c.Params("id")
	var req models.UpdateBankAccountRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Invalid request body",
		})
	}
	a, err := services.UpdateBankAccount(id, req)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: err.Error(),
		})
	}
	return c.JSON(models.APIResponse{Success: true, Data: a})
}

func DeleteBankAccount(c *fiber.Ctx) error {
	id := c.Params("id")
	if err := services.DeleteBankAccount(id); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: err.Error(),
		})
	}
	return c.JSON(models.APIResponse{Success: true, Data: fiber.Map{"id": id}})
}
