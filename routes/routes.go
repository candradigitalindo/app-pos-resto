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

	// Restore — ambil state tertinggal setelah device reset database
	outlet.Get("/restore", handlers.GetRestore)

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
	admin.Get("/work-units/me", middleware.RequirePermission("procurement.requests.view"), handlers.GetMyWorkUnit)
	admin.Get("/my-work-units", middleware.RequirePermission("procurement.requests.view"), handlers.GetMyWorkUnits)
	admin.Get("/work-units", middleware.RequirePermission("workunits.view"), handlers.ListWorkUnits)
	admin.Get("/work-units/:id", middleware.RequirePermission("workunits.view"), handlers.GetWorkUnit)
	admin.Post("/work-units", middleware.RequirePermission("workunits.create"), handlers.CreateWorkUnit)
	admin.Put("/work-units/:id", middleware.RequirePermission("workunits.update"), handlers.UpdateWorkUnit)
	admin.Delete("/work-units/:id", middleware.RequirePermission("workunits.delete"), handlers.DeleteWorkUnit)

	// Dashboard
	admin.Get("/dashboard", handlers.GetDashboard)
	admin.Get("/manager-dashboard", handlers.GetManagerDashboard)

	// Me / permissions (all roles)
	admin.Get("/me/permissions", handlers.GetMyPermissions)
	admin.Put("/me/password", handlers.ChangePassword)
	admin.Put("/me/profile", handlers.UpdateProfile)

	// Access logs — login/access history (role permission; superadmin always passes)
	admin.Get("/access-logs", middleware.RequirePermission("access_logs.view"), handlers.GetAccessLogs)

	// Outlets — CRUD granular
	admin.Get("/my-outlets", handlers.GetMyOutlets)
	admin.Get("/outlets", middleware.RequirePermission("outlets.view"), handlers.GetOutlets)
	admin.Get("/outlets/:id", middleware.RequirePermission("outlets.view"), handlers.GetOutlet)
	admin.Post("/outlets", middleware.RequirePermission("outlets.create"), handlers.CreateOutlet)
	admin.Put("/outlets/:id", middleware.RequirePermission("outlets.update"), handlers.UpdateOutlet)
	admin.Post("/outlets/:id/regenerate-key", middleware.RequirePermission("outlets.update"), handlers.RegenerateOutletAPIKey)
	admin.Post("/outlets/:id/toggle", middleware.RequirePermission("outlets.update"), handlers.ToggleOutlet)
	admin.Delete("/outlets/:id", middleware.RequirePermission("outlets.delete"), handlers.DeleteOutlet)

	// Outlet procurement dashboard
	admin.Get("/outlets/:id/procurement-dashboard", middleware.RequirePermission("procurement.dashboard.view"), handlers.GetProcurementDashboard)

	// Reports (view-only by nature)
	admin.Get("/sales-report", middleware.RequirePermission("reports.sales.view"), handlers.GetSalesReport)
	admin.Get("/unpaid-orders", middleware.RequirePermission("reports.sales.view"), handlers.GetUnpaidOrders)
	admin.Get("/product-sales-report", middleware.RequirePermission("reports.product_sales.view"), handlers.GetProductSalesReport)
	admin.Get("/tax-report", middleware.RequirePermission("reports.tax.view"), handlers.GetTaxReport)
	admin.Get("/cash-flow-report", middleware.RequirePermission("reports.cashflow.view"), handlers.GetCashFlowReport)
	admin.Get("/balance-report", middleware.RequirePermission("reports.balance.view"), handlers.GetBalanceReport)
	admin.Get("/profit-loss-report", middleware.RequirePermission("reports.pnl.view"), handlers.GetProfitLossReport)
	admin.Get("/general-ledger", middleware.RequirePermission("reports.ledger.view"), handlers.GetGeneralLedger)
	admin.Get("/void-report", middleware.RequirePermission("reports.void.view"), handlers.GetVoidReport)
	admin.Get("/discount-report", middleware.RequirePermission("reports.discount.view"), handlers.GetDiscountReport)

	// Products & Categories — CRUD granular
	admin.Get("/products", middleware.RequirePermission("products.view"), handlers.AdminGetProducts)
	admin.Get("/categories", middleware.RequirePermission("products.view"), handlers.AdminGetCategories)
	admin.Post("/products", middleware.RequirePermission("products.create"), handlers.AdminCreateProduct)
	admin.Put("/products/:id", middleware.RequirePermission("products.update"), handlers.AdminUpdateProduct)
	admin.Delete("/products/:id", middleware.RequirePermission("products.delete"), handlers.AdminDeleteProduct)
	admin.Post("/categories", middleware.RequirePermission("products.create"), handlers.AdminCreateCategory)
	admin.Put("/categories/:id", middleware.RequirePermission("products.update"), handlers.AdminUpdateCategory)
	admin.Delete("/categories/:id", middleware.RequirePermission("products.delete"), handlers.AdminDeleteCategory)

	// User management — CRUD granular
	admin.Get("/admins", middleware.RequirePermission("users.view"), handlers.GetAdmins)
	admin.Get("/permissions", middleware.RequirePermission("roles.view"), handlers.GetAllRolePermissions)
	admin.Get("/roles", middleware.RequirePermission("roles.view"), handlers.ListRoles)
	admin.Post("/admins", middleware.RequirePermission("users.create"), handlers.CreateAdmin)
	admin.Put("/admins/:id/role", middleware.RequirePermission("users.update"), handlers.UpdateAdminRole)
	admin.Put("/admins/:id/reset-password", middleware.RequirePermission("users.update"), handlers.ResetAdminPassword)
	admin.Post("/admins/:id/toggle", middleware.RequirePermission("users.update"), handlers.ToggleAdminActive)
	admin.Put("/admins/:id", middleware.RequirePermission("users.update"), handlers.UpdateAdmin)
	admin.Delete("/admins/:id", middleware.RequirePermission("users.delete"), handlers.DeleteAdmin)
	admin.Put("/permissions/:role", middleware.RequirePermission("roles.update"), handlers.UpdateRolePermissions)
	admin.Post("/roles", middleware.RequirePermission("roles.create"), handlers.CreateRole)
	admin.Put("/roles/:name", middleware.RequirePermission("roles.update"), handlers.UpdateRole)
	admin.Delete("/roles/:name", middleware.RequirePermission("roles.delete"), handlers.DeleteRole)
	admin.Put("/roles/:role/scope", middleware.RequirePermission("roles.update"), handlers.UpdateRoleScope)

	// Purchase requests — granular: submit, approve, purchasing (isi harga), finance (bayar)
	admin.Get("/procurement-dashboard", middleware.RequirePermission("procurement.dashboard.view"), handlers.GetProcurementDashboardGlobal)
	admin.Get("/payment-stats", middleware.RequirePermission("finance.payments.view"), handlers.GetPaymentStats)
	admin.Get("/purchase-requests", middleware.RequirePermission("procurement.requests.view"), handlers.ListPurchaseRequests)
	admin.Get("/purchase-requests/:id", middleware.RequirePermission("procurement.requests.view"), handlers.GetPurchaseRequest)
	admin.Get("/purchase-requests/:id/payment-histories", middleware.RequirePermission("finance.payments.view"), handlers.GetPaymentHistories)
	admin.Post("/purchase-requests/:id/split", middleware.RequirePermission("procurement.requests.purchasing"), handlers.SplitPurchaseRequest)
	admin.Post("/purchase-requests", middleware.RequirePermission("procurement.requests.submit"), handlers.CreatePurchaseRequest)
	admin.Put("/purchase-requests/:id/status", middleware.RequirePermission("procurement.requests.view"), handlers.UpdatePurchaseStatus)
	admin.Put("/purchase-requests/:id/items", middleware.RequirePermission("procurement.requests.view"), handlers.UpdatePurchaseItems)
	admin.Delete("/purchase-requests/:id", middleware.RequirePermission("procurement.requests.submit"), handlers.DeletePurchaseRequest)

	// File upload
	admin.Post("/upload", handlers.UploadFile)

	// Bank Accounts
	admin.Get("/bank-accounts", middleware.RequirePermission("finance.bank.view"), handlers.ListBankAccounts)
	admin.Post("/bank-accounts", middleware.RequirePermission("finance.bank.create"), handlers.CreateBankAccount)
	admin.Put("/bank-accounts/:id", middleware.RequirePermission("finance.bank.update"), handlers.UpdateBankAccount)
	admin.Delete("/bank-accounts/:id", middleware.RequirePermission("finance.bank.delete"), handlers.DeleteBankAccount)

	// Vendors
	// Vendor list/lookup is also needed by procurement requesters (to pick a vendor).
	admin.Get("/vendors", middleware.RequireAnyPermission("vendors.view", "procurement.requests.view", "procurement.requests.submit", "procurement.requests.purchasing"), handlers.ListVendors)
	admin.Get("/vendors/:id", middleware.RequireAnyPermission("vendors.view", "procurement.requests.view", "procurement.requests.submit", "procurement.requests.purchasing"), handlers.GetVendor)
	admin.Get("/vendors/:id/detail", middleware.RequirePermission("vendors.view"), handlers.GetVendorDetail)
	admin.Get("/vendors/:id/purchases", middleware.RequirePermission("vendors.view"), handlers.ListVendorPurchases)
	admin.Post("/vendors", middleware.RequirePermission("vendors.create"), handlers.CreateVendor)
	admin.Put("/vendors/:id", middleware.RequirePermission("vendors.update"), handlers.UpdateVendor)
	admin.Post("/vendors/:id/toggle", middleware.RequirePermission("vendors.update"), handlers.ToggleVendorActive)
	admin.Delete("/vendors/:id", middleware.RequirePermission("vendors.delete"), handlers.DeleteVendor)

	// Warehouse / Inventory — CRUD granular
	// Shared Gudang read lookups (warehouse selector, item picker, ledger) are
	// cross-loaded by every Gudang page, so any warehouse-module viewer may read them.
	whView := []string{"warehouse_dashboard.view", "warehouses.view", "stockitems.view", "stocktransfers.view", "stockwastes.view", "stockledger.view", "recipes.view"}
	admin.Get("/warehouse-dashboard", middleware.RequirePermission("warehouse_dashboard.view"), handlers.GetWarehouseDashboard)
	admin.Get("/warehouses", middleware.RequireAnyPermission(whView...), handlers.ListWarehouses)
	admin.Get("/warehouses/:id", middleware.RequireAnyPermission(whView...), handlers.GetWarehouse)
	admin.Post("/warehouses", middleware.RequirePermission("warehouses.create"), handlers.CreateWarehouse)
	admin.Put("/warehouses/:id", middleware.RequirePermission("warehouses.update"), handlers.UpdateWarehouse)
	admin.Delete("/warehouses/:id", middleware.RequirePermission("warehouses.delete"), handlers.DeleteWarehouse)

	// Stock Items
	admin.Get("/stock-items", middleware.RequireAnyPermission(whView...), handlers.ListStockItems)
	admin.Get("/stock-items/:id", middleware.RequireAnyPermission(whView...), handlers.GetStockItem)
	admin.Post("/stock-items", middleware.RequirePermission("stockitems.create"), handlers.CreateStockItem)
	admin.Put("/stock-items/:id", middleware.RequirePermission("stockitems.update"), handlers.UpdateStockItem)
	admin.Post("/stock-items/:id/toggle", middleware.RequirePermission("stockitems.update"), handlers.ToggleStockItemActive)
	admin.Delete("/stock-items/:id", middleware.RequirePermission("stockitems.delete"), handlers.DeleteStockItem)
	admin.Get("/stock-item-categories", middleware.RequireAnyPermission(whView...), handlers.ListStockItemCategories)
	admin.Post("/stock-item-categories", middleware.RequirePermission("stockitems.create"), handlers.CreateStockItemCategory)
	admin.Put("/stock-item-categories/:id", middleware.RequirePermission("stockitems.update"), handlers.UpdateStockItemCategory)
	admin.Delete("/stock-item-categories/:id", middleware.RequirePermission("stockitems.delete"), handlers.DeleteStockItemCategory)

	// Stock Ledger & Movements
	admin.Get("/stock-ledger", middleware.RequireAnyPermission(whView...), handlers.GetStockLedger)
	admin.Get("/stock-movements", middleware.RequireAnyPermission(whView...), handlers.GetStockMovements)
	admin.Post("/stock-adjustments", middleware.RequirePermission("stockledger.adjust"), handlers.CreateAdjustment)

	// Stock Transfers
	admin.Get("/stock-transfers", middleware.RequirePermission("stocktransfers.view"), handlers.ListStockTransfers)
	admin.Get("/stock-transfers/:id", middleware.RequirePermission("stocktransfers.view"), handlers.GetStockTransfer)
	admin.Post("/stock-transfers", middleware.RequirePermission("stocktransfers.create"), handlers.CreateStockTransfer)
	admin.Put("/stock-transfers/:id/status", middleware.RequirePermission("stocktransfers.update"), handlers.UpdateTransferStatus)
	admin.Put("/stock-transfers/:id/received", middleware.RequirePermission("stocktransfers.update"), handlers.UpdateReceivedQty)

	// Recipes
	admin.Get("/products/:id/recipes", middleware.RequirePermission("recipes.view"), handlers.GetProductRecipes)
	admin.Put("/products/:id/recipes", middleware.RequirePermission("recipes.update"), handlers.SaveProductRecipes)
	admin.Get("/stock-items/:id/recipes", middleware.RequirePermission("recipes.view"), handlers.GetStockItemRecipes)
	admin.Put("/stock-items/:id/recipes", middleware.RequirePermission("recipes.update"), handlers.SaveStockItemRecipes)
	admin.Post("/stock-items/:id/produce", middleware.RequirePermission("recipes.create"), handlers.ProduceStockItem)
	admin.Get("/recipe-masters", middleware.RequirePermission("recipes.view"), handlers.ListRecipeMasters)
	admin.Get("/recipe-masters/:id", middleware.RequirePermission("recipes.view"), handlers.GetRecipeMaster)
	admin.Post("/recipe-masters", middleware.RequirePermission("recipes.create"), handlers.CreateRecipeMaster)
	admin.Put("/recipe-masters/:id", middleware.RequirePermission("recipes.update"), handlers.UpdateRecipeMaster)
	admin.Delete("/recipe-masters/:id", middleware.RequirePermission("recipes.delete"), handlers.DeleteRecipeMaster)

	// Stock Wastes
	admin.Get("/stock-wastes", middleware.RequirePermission("stockwastes.view"), handlers.ListStockWastes)
	admin.Post("/stock-wastes", middleware.RequirePermission("stockwastes.create"), handlers.CreateStockWaste)

	// Settings — view + update only (no create/delete for settings)
	admin.Get("/settings", middleware.RequirePermission("settings.company.view"), handlers.GetAllSettings)
	admin.Get("/settings/company", middleware.RequirePermission("settings.company.view"), handlers.GetCompanyIdentity)
	admin.Put("/settings/company", middleware.RequirePermission("settings.company.update"), handlers.UpdateCompanyIdentity)
	admin.Get("/settings/timezone", middleware.RequirePermission("settings.timezone.view"), handlers.GetTimezone)
	admin.Put("/settings/timezone", middleware.RequirePermission("settings.timezone.update"), handlers.UpdateTimezone)
	admin.Get("/settings/tax", middleware.RequirePermission("settings.tax.view"), handlers.GetTaxSettings)
	admin.Put("/settings/tax", middleware.RequirePermission("settings.tax.update"), handlers.UpdateTaxSettings)
}
