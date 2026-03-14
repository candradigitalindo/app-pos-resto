package middleware

import (
	"cloud-pos/config"
	"cloud-pos/database"
	"cloud-pos/models"
	"cloud-pos/services"
	"strings"

	"github.com/gofiber/fiber/v2"
)

func AuthOutlet() fiber.Handler {
	return func(c *fiber.Ctx) error {
		auth := c.Get("Authorization")
		if auth == "" {
			return c.Status(fiber.StatusUnauthorized).JSON(models.APIResponse{
				Success: false,
				Error:   "Missing Authorization header",
			})
		}

		apiKey := strings.TrimPrefix(auth, "Bearer ")
		if apiKey == auth {
			return c.Status(fiber.StatusUnauthorized).JSON(models.APIResponse{
				Success: false,
				Error:   "Invalid authorization format, use Bearer {api_key}",
			})
		}

		var outletID, outletCode, outletName string
		var isActive bool
		err := database.DB.QueryRow(
			"SELECT id, code, name, is_active FROM outlets WHERE api_key = $1",
			apiKey,
		).Scan(&outletID, &outletCode, &outletName, &isActive)

		if err != nil {
			return c.Status(fiber.StatusUnauthorized).JSON(models.APIResponse{
				Success: false,
				Error:   "Invalid API key",
			})
		}

		// Trim whitespace from CHAR(26) columns
		outletID = strings.TrimSpace(outletID)
		outletCode = strings.TrimSpace(outletCode)
		outletName = strings.TrimSpace(outletName)

		if !isActive {
			return c.Status(fiber.StatusForbidden).JSON(models.APIResponse{
				Success: false,
				Error:   "Outlet is deactivated",
			})
		}

		// Validate URL param :outletId matches authenticated outlet (if present)
		if paramID := c.Params("outletId"); paramID != "" && paramID != outletID {
			return c.Status(fiber.StatusForbidden).JSON(models.APIResponse{
				Success: false,
				Error:   "API key does not match the requested outlet",
			})
		}

		c.Locals("outlet_id", outletID)
		c.Locals("outlet_code", outletCode)
		c.Locals("outlet_name", outletName)

		return c.Next()
	}
}

func AdminAuth(cfg *config.Config) fiber.Handler {
	return func(c *fiber.Ctx) error {
		auth := c.Get("Authorization")
		token := strings.TrimPrefix(auth, "Bearer ")

		if token == "" || token == auth {
			return c.Status(fiber.StatusUnauthorized).JSON(models.APIResponse{
				Success: false,
				Error:   "Unauthorized: missing or invalid Authorization header",
			})
		}

		// 1) Cek static admin token (backward compatibility)
		if token == cfg.AdminToken {
			c.Locals("admin_id", "static")
			c.Locals("admin_username", "admin")
			c.Locals("admin_role", "superadmin")
			return c.Next()
		}

		// 2) Cek JWT token
		claims, err := services.ValidateJWT(token, cfg.JWTSecret)
		if err != nil {
			return c.Status(fiber.StatusUnauthorized).JSON(models.APIResponse{
				Success: false,
				Error:   "Unauthorized: token tidak valid atau sudah expired",
			})
		}

		c.Locals("admin_id", claims["sub"])
		c.Locals("admin_username", claims["username"])
		c.Locals("admin_role", claims["role"])

		return c.Next()
	}
}

func RateLimiter(cfg *config.Config) fiber.Handler {
	return func(c *fiber.Ctx) error {
		// TODO: implement rate limiting with Redis or in-memory store
		return c.Next()
	}
}
