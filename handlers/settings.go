package handlers

import (
	"cloud-pos/models"
	"cloud-pos/services"

	"github.com/gofiber/fiber/v2"
)

func GetCompanyIdentity(c *fiber.Ctx) error {
	data, err := services.GetCompanyIdentity()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Gagal mengambil identitas perusahaan",
		})
	}
	return c.JSON(models.APIResponse{Success: true, Data: data})
}

func UpdateCompanyIdentity(c *fiber.Ctx) error {
	var req models.CompanyIdentity
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Format request tidak valid",
		})
	}

	if err := services.UpdateCompanyIdentity(req); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Gagal menyimpan identitas perusahaan",
		})
	}

	return c.JSON(models.APIResponse{Success: true, Message: "Identitas perusahaan berhasil disimpan"})
}

func GetTimezone(c *fiber.Ctx) error {
	tz, err := services.GetTimezone()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Gagal mengambil pengaturan zona waktu",
		})
	}
	return c.JSON(models.APIResponse{
		Success: true,
		Data: fiber.Map{
			"timezone":  tz,
			"timezones": services.GetAvailableTimezones(),
		},
	})
}

func UpdateTimezone(c *fiber.Ctx) error {
	var req models.TimezoneSettings
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Format request tidak valid",
		})
	}

	if req.Timezone == "" {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Zona waktu harus diisi",
		})
	}

	if err := services.UpdateTimezone(req.Timezone); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: err.Error(),
		})
	}

	return c.JSON(models.APIResponse{Success: true, Message: "Zona waktu berhasil disimpan"})
}

func GetAllSettings(c *fiber.Ctx) error {
	settings, err := services.GetAllSettings()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Gagal mengambil pengaturan",
		})
	}

	result := make(map[string]string)
	for _, s := range settings {
		result[s.Key] = s.Value
	}

	return c.JSON(models.APIResponse{Success: true, Data: result})
}

func GetTaxSettings(c *fiber.Ctx) error {
	data, err := services.GetTaxSettings()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Gagal mengambil pengaturan pajak",
		})
	}
	return c.JSON(models.APIResponse{Success: true, Data: data})
}

func UpdateTaxSettings(c *fiber.Ctx) error {
	var req models.TaxSettings
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Format request tidak valid",
		})
	}

	if err := services.UpdateTaxSettings(req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: err.Error(),
		})
	}

	return c.JSON(models.APIResponse{Success: true, Message: "Pengaturan pajak berhasil disimpan"})
}
