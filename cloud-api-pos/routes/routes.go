package routes

import (
	"cloud-api-pos/config"
	"cloud-api-pos/handlers"
	"cloud-api-pos/middleware"

	"github.com/gofiber/fiber/v2"
)

func Setup(app *fiber.App, cfg *config.Config) {
	api := app.Group("/api/v1")

	// Public
	api.Get("/ping", handlers.Ping)

	// Outlet self-discovery: GET /api/v1/outlet/me — returns outlet info from API key alone
	api.Get("/outlet/me", middleware.AuthOutlet(), func(c *fiber.Ctx) error {
		return handlers.GetOutletInfo(c)
	})

	// Outlet API (authenticated by API key)
	outlet := api.Group("/outlets/:outletId", middleware.AuthOutlet(), middleware.RateLimiter(cfg))

	// Outlet info (self-service)
	outlet.Get("/info", handlers.GetOutletInfo)

	// Orders
	outlet.Post("/orders", handlers.PushOrder)
	outlet.Get("/orders", handlers.GetOrders)

	// Transactions
	outlet.Post("/transactions", handlers.PushTransaction)
	outlet.Get("/transactions", handlers.GetTransactions)

	// Products
	outlet.Post("/products", handlers.PushProduct)
	outlet.Get("/products", handlers.GetProducts)

	// Categories
	outlet.Get("/categories", handlers.GetOutletCategories)
	outlet.Put("/categories/:categoryId/printer", handlers.UpdateCategoryPrinter)

	// Printers
	outlet.Get("/printers", handlers.GetOutletPrinters)
	outlet.Post("/printers", handlers.PushPrinter)

	// Analytics
	outlet.Post("/analytics/daily", handlers.PushAnalytics)
	outlet.Get("/analytics", handlers.GetAnalytics)

	// Batch sync
	outlet.Post("/sync/batch", handlers.BatchSync)

	// Updates
	outlet.Get("/updates", handlers.GetUpdates)

	// Conflicts
	outlet.Get("/conflicts", handlers.GetConflicts)
	outlet.Post("/conflicts/:conflictId/resolve", handlers.ResolveConflict)

	// Sync logs
	outlet.Get("/sync/logs", handlers.GetSyncLogs)

	// Admin login (public — no auth required)
	api.Post("/admin/login", handlers.AdminLogin(cfg))

	// Admin API (authenticated by admin token or JWT)
	admin := api.Group("/admin", middleware.AdminAuth(cfg))
	admin.Get("/outlets", handlers.GetOutlets)
	admin.Post("/outlets", handlers.CreateOutlet)
	admin.Get("/outlets/:id", handlers.GetOutlet)
	admin.Put("/outlets/:id", handlers.UpdateOutlet)
	admin.Post("/outlets/:id/regenerate-key", handlers.RegenerateOutletAPIKey)
	admin.Post("/outlets/:id/toggle", handlers.ToggleOutlet)
	admin.Delete("/outlets/:id", handlers.DeleteOutlet)
	admin.Get("/dashboard", handlers.GetDashboard)
	admin.Get("/products", handlers.AdminGetProducts)
	admin.Post("/products", handlers.AdminCreateProduct)
	admin.Put("/products/:id", handlers.AdminUpdateProduct)
	admin.Delete("/products/:id", handlers.AdminDeleteProduct)
	admin.Get("/categories", handlers.AdminGetCategories)
	admin.Post("/categories", handlers.AdminCreateCategory)
	admin.Put("/categories/:id", handlers.AdminUpdateCategory)
	admin.Delete("/categories/:id", handlers.AdminDeleteCategory)
	admin.Get("/admins", handlers.GetAdmins)
	admin.Post("/admins", handlers.CreateAdmin)
}
