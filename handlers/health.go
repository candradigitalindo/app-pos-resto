package handlers

import (
	"cloud-pos/models"
	"time"

	"github.com/gofiber/fiber/v2"
)

func Ping(c *fiber.Ctx) error {
	return c.JSON(models.APIResponse{
		Success: true,
		Data: fiber.Map{
			"service":   "Nusantara POS Cloud API",
			"version":   "1.0.0",
			"timestamp": time.Now().UTC().Format(time.RFC3339),
		},
	})
}
