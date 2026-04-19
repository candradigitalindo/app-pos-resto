package routes

import (
	"cloud-pos/config"
	"cloud-pos/handlers"
	"cloud-pos/middleware"

	"github.com/gofiber/fiber/v2"
)

func Setup(app *fiber.App, cfg *config.Config) {
	// Serve uploaded files
	app.Static("/uploads", "./uploads")

	api := app.Group("/api/v1")

	// Public
	api.Get("/ping", handlers.Ping)
	api.Get("/timezone", handlers.GetTimezone) // public — used by frontend for time formatting

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

	// Work Units (Move to top to avoid 404/conflicts)
	admin.Get("/work-units/me", middleware.RequirePermission("procurement.view"), handlers.GetMyWorkUnit)
	admin.Get("/my-work-units", middleware.RequirePermission("procurement.view"), handlers.GetMyWorkUnits)
	admin.Get("/work-units", middleware.RequirePermission("procurement.work_units"), handlers.ListWorkUnits)
	admin.Get("/work-units/:id", middleware.RequirePermission("procurement.work_units"), handlers.GetWorkUnit)
	admin.Post("/work-units", middleware.RequirePermission("procurement.work_units"), handlers.CreateWorkUnit)
	admin.Put("/work-units/:id", middleware.RequirePermission("procurement.work_units"), handlers.UpdateWorkUnit)

	// Dashboard
	admin.Get("/dashboard", handlers.GetDashboard)
	admin.Get("/manager-dashboard", handlers.GetManagerDashboard)

	// Me / permissions (all roles)
	admin.Get("/me/permissions", handlers.GetMyPermissions)
	admin.Put("/me/password", handlers.ChangePassword)
	admin.Put("/me/profile", handlers.UpdateProfile)

	// Outlets (view = read-only, manage = create/edit/delete)
	admin.Get("/my-outlets", handlers.GetMyOutlets) // scope-based outlet list, no permission required
	admin.Get("/outlets", middleware.RequirePermission("outlets.view"), handlers.GetOutlets)
	admin.Get("/outlets/:id", middleware.RequirePermission("outlets.view"), handlers.GetOutlet)
	admin.Post("/outlets", middleware.RequirePermission("outlets.manage"), handlers.CreateOutlet)
	admin.Put("/outlets/:id", middleware.RequirePermission("outlets.manage"), handlers.UpdateOutlet)
	admin.Post("/outlets/:id/regenerate-key", middleware.RequirePermission("outlets.manage"), handlers.RegenerateOutletAPIKey)
	admin.Post("/outlets/:id/toggle", middleware.RequirePermission("outlets.manage"), handlers.ToggleOutlet)
	admin.Delete("/outlets/:id", middleware.RequirePermission("outlets.manage"), handlers.DeleteOutlet)

	// Outlet procurement dashboard
	admin.Get("/outlets/:id/procurement-dashboard", middleware.RequirePermission("procurement.view"), handlers.GetProcurementDashboard)

	// Reports (view-only by nature)
	admin.Get("/sales-report", middleware.RequirePermission("reports"), handlers.GetSalesReport)
	admin.Get("/unpaid-orders", middleware.RequirePermission("reports"), handlers.GetUnpaidOrders)
	admin.Get("/product-sales-report", middleware.RequirePermission("reports"), handlers.GetProductSalesReport)
	admin.Get("/tax-report", middleware.RequirePermission("reports"), handlers.GetTaxReport)
	admin.Get("/cash-flow-report", middleware.RequirePermission("reports"), handlers.GetCashFlowReport)
	admin.Get("/balance-report", middleware.RequirePermission("reports"), handlers.GetBalanceReport)
	admin.Get("/profit-loss-report", middleware.RequirePermission("reports"), handlers.GetProfitLossReport)
	admin.Get("/general-ledger", middleware.RequirePermission("reports"), handlers.GetGeneralLedger)

	// Products & Categories (view = read-only, manage = create/edit/delete)
	admin.Get("/products", middleware.RequirePermission("products.view"), handlers.AdminGetProducts)
	admin.Get("/categories", middleware.RequirePermission("products.view"), handlers.AdminGetCategories)
	admin.Post("/products", middleware.RequirePermission("products.manage"), handlers.AdminCreateProduct)
	admin.Put("/products/:id", middleware.RequirePermission("products.manage"), handlers.AdminUpdateProduct)
	admin.Delete("/products/:id", middleware.RequirePermission("products.manage"), handlers.AdminDeleteProduct)
	admin.Post("/categories", middleware.RequirePermission("products.manage"), handlers.AdminCreateCategory)
	admin.Put("/categories/:id", middleware.RequirePermission("products.manage"), handlers.AdminUpdateCategory)
	admin.Delete("/categories/:id", middleware.RequirePermission("products.manage"), handlers.AdminDeleteCategory)

	// User management (view = read list, manage = create/edit/delete)
	admin.Get("/admins", middleware.RequirePermission("users.view"), handlers.GetAdmins)
	admin.Get("/permissions", middleware.RequirePermission("users.view"), handlers.GetAllRolePermissions)
	admin.Get("/roles", middleware.RequirePermission("users.view"), handlers.ListRoles)
	admin.Post("/admins", middleware.RequirePermission("users.manage"), handlers.CreateAdmin)
	admin.Put("/admins/:id/role", middleware.RequirePermission("users.manage"), handlers.UpdateAdminRole)
	admin.Put("/admins/:id/reset-password", middleware.RequirePermission("users.manage"), handlers.ResetAdminPassword)
	admin.Post("/admins/:id/toggle", middleware.RequirePermission("users.manage"), handlers.ToggleAdminActive)
	admin.Put("/admins/:id", middleware.RequirePermission("users.manage"), handlers.UpdateAdmin)
	admin.Delete("/admins/:id", middleware.RequirePermission("users.manage"), handlers.DeleteAdmin)
	admin.Put("/permissions/:role", middleware.RequirePermission("users.manage"), handlers.UpdateRolePermissions)
	admin.Post("/roles", middleware.RequirePermission("users.manage"), handlers.CreateRole)
	admin.Put("/roles/:name", middleware.RequirePermission("users.manage"), handlers.UpdateRole)
	admin.Delete("/roles/:name", middleware.RequirePermission("users.manage"), handlers.DeleteRole)
	admin.Put("/roles/:role/scope", middleware.RequirePermission("users.manage"), handlers.UpdateRoleScope)

	// Purchase requests — granular: submit, approve, purchasing (isi harga), finance (bayar)
	admin.Get("/procurement-dashboard", middleware.RequirePermission("procurement.view"), handlers.GetProcurementDashboardGlobal)
	admin.Get("/payment-stats", middleware.RequirePermission("procurement.finance"), handlers.GetPaymentStats)
	admin.Get("/purchase-requests", middleware.RequirePermission("procurement.view"), handlers.ListPurchaseRequests)
	admin.Get("/purchase-requests/:id", middleware.RequirePermission("procurement.view"), handlers.GetPurchaseRequest)
	admin.Get("/purchase-requests/:id/payment-histories", middleware.RequirePermission("procurement.finance"), handlers.GetPaymentHistories)
	admin.Post("/purchase-requests/:id/split", middleware.RequirePermission("procurement.purchasing"), handlers.SplitPurchaseRequest)
	admin.Post("/purchase-requests", middleware.RequirePermission("procurement.submit"), handlers.CreatePurchaseRequest)
	admin.Put("/purchase-requests/:id/status", middleware.RequirePermission("procurement.view"), handlers.UpdatePurchaseStatus)
	admin.Put("/purchase-requests/:id/items", middleware.RequirePermission("procurement.view"), handlers.UpdatePurchaseItems)
	admin.Delete("/purchase-requests/:id", middleware.RequirePermission("procurement.submit"), handlers.DeletePurchaseRequest)

	// File upload
	admin.Post("/upload", handlers.UploadFile)

	// Bank Accounts
	admin.Get("/bank-accounts", middleware.RequirePermission("procurement.finance"), handlers.ListBankAccounts)
	admin.Post("/bank-accounts", middleware.RequirePermission("procurement.finance"), handlers.CreateBankAccount)
	admin.Put("/bank-accounts/:id", middleware.RequirePermission("procurement.finance"), handlers.UpdateBankAccount)
	admin.Delete("/bank-accounts/:id", middleware.RequirePermission("procurement.finance"), handlers.DeleteBankAccount)

	// Vendors
	admin.Get("/vendors", middleware.RequirePermission("procurement.view"), handlers.ListVendors)
	admin.Get("/vendors/:id", middleware.RequirePermission("procurement.view"), handlers.GetVendor)
	admin.Get("/vendors/:id/detail", middleware.RequirePermission("procurement.view"), handlers.GetVendorDetail)
	admin.Get("/vendors/:id/purchases", middleware.RequirePermission("procurement.view"), handlers.ListVendorPurchases)
	admin.Post("/vendors", middleware.RequirePermission("procurement.vendors"), handlers.CreateVendor)
	admin.Put("/vendors/:id", middleware.RequirePermission("procurement.vendors"), handlers.UpdateVendor)
	admin.Post("/vendors/:id/toggle", middleware.RequirePermission("procurement.vendors"), handlers.ToggleVendorActive)
	admin.Delete("/vendors/:id", middleware.RequirePermission("procurement.vendors"), handlers.DeleteVendor)

	// Settings (view = read, manage = update)
	admin.Get("/settings", middleware.RequirePermission("settings.view"), handlers.GetAllSettings)
	admin.Get("/settings/company", middleware.RequirePermission("settings.view"), handlers.GetCompanyIdentity)
	admin.Put("/settings/company", middleware.RequirePermission("settings.manage"), handlers.UpdateCompanyIdentity)
	admin.Get("/settings/timezone", middleware.RequirePermission("settings.view"), handlers.GetTimezone)
	admin.Put("/settings/timezone", middleware.RequirePermission("settings.manage"), handlers.UpdateTimezone)
	admin.Get("/settings/tax", middleware.RequirePermission("settings.view"), handlers.GetTaxSettings)
	admin.Put("/settings/tax", middleware.RequirePermission("settings.manage"), handlers.UpdateTaxSettings)
}
