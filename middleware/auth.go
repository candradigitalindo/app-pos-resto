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
			c.Locals("admin_scope", "all")
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

		// Extract scope from JWT
		scope, _ := claims["scope"].(string)
		if scope == "" {
			scope = "all"
		}
		c.Locals("admin_scope", scope)

		if scope == "specific" {
			if raw, ok := claims["outlet_ids"].([]interface{}); ok {
				ids := make([]string, 0, len(raw))
				for _, v := range raw {
					if s, ok := v.(string); ok {
						ids = append(ids, s)
					}
				}
				c.Locals("admin_outlet_ids", ids)
			}
			if raw, ok := claims["work_unit_ids"].([]interface{}); ok {
				ids := make([]string, 0, len(raw))
				for _, v := range raw {
					if s, ok := v.(string); ok {
						ids = append(ids, s)
					}
				}
				c.Locals("admin_work_unit_ids", ids)
			}
		}

		return c.Next()
	}
}

func RateLimiter(cfg *config.Config) fiber.Handler {
	return func(c *fiber.Ctx) error {
		// TODO: implement rate limiting with Redis or in-memory store
		return c.Next()
	}
}

// RequirePermission checks if the authenticated admin's role has a specific permission.
// superadmin (static token) always passes.
// For ".view" permissions, having ".manage" of the same module also passes (manage implies view).
func RequirePermission(permission string) fiber.Handler {
	return func(c *fiber.Ctx) error {
		role, _ := c.Locals("admin_role").(string)

		// superadmin bypasses all permission checks
		if role == "superadmin" {
			return c.Next()
		}

		perms, err := services.GetRolePermissions(role)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
				Success: false, Error: "Gagal memeriksa permission",
			})
		}

		for _, p := range perms {
			if p == permission {
				return c.Next()
			}
			// Any sub-permission of a module implies .view access
			if strings.HasSuffix(permission, ".view") {
				module := strings.TrimSuffix(permission, ".view")
				if strings.HasPrefix(p, module+".") {
					return c.Next()
				}
			}
		}

		return c.Status(fiber.StatusForbidden).JSON(models.APIResponse{
			Success: false,
			Error:   "Akses ditolak: Anda tidak memiliki izin untuk fitur ini",
		})
	}
}

// RequireAnyPermission passes if the role holds ANY of the given permissions
// (same matching rules as RequirePermission). Used for resources reachable from
// multiple features — e.g. the vendor list is needed both by vendor management
// (vendors.view) and by procurement requesters (procurement.requests.*).
func RequireAnyPermission(permissions ...string) fiber.Handler {
	return func(c *fiber.Ctx) error {
		role, _ := c.Locals("admin_role").(string)
		if role == "superadmin" {
			return c.Next()
		}

		perms, err := services.GetRolePermissions(role)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
				Success: false, Error: "Gagal memeriksa permission",
			})
		}

		for _, required := range permissions {
			for _, p := range perms {
				if p == required {
					return c.Next()
				}
				if strings.HasSuffix(required, ".view") {
					module := strings.TrimSuffix(required, ".view")
					if strings.HasPrefix(p, module+".") {
						return c.Next()
					}
				}
			}
		}

		return c.Status(fiber.StatusForbidden).JSON(models.APIResponse{
			Success: false,
			Error:   "Akses ditolak: Anda tidak memiliki izin untuk fitur ini",
		})
	}
}

// RequireSuperadmin allows only the superadmin role (master account).
func RequireSuperadmin() fiber.Handler {
	return func(c *fiber.Ctx) error {
		role, _ := c.Locals("admin_role").(string)
		if role != "superadmin" {
			return c.Status(fiber.StatusForbidden).JSON(models.APIResponse{
				Success: false, Error: "Akses ditolak: khusus superadmin",
			})
		}
		return c.Next()
	}
}
