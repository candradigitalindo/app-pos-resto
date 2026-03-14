package handlers

import (
	"cloud-pos/config"
	"cloud-pos/models"
	"cloud-pos/services"
	"log"
	"math"
	"strconv"
	"time"

	"github.com/gofiber/fiber/v2"
)

// ── Health ──────────────────────────────────────────────────

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

// ── Outlet Handlers ─────────────────────────────────────────

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
	outlets, err := services.GetOutlets()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get outlets",
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: outlets,
	})
}

func GetOutlet(c *fiber.Ctx) error {
	id := c.Params("id")
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

	return c.JSON(models.APIResponse{
		Success: true,
		Data: fiber.Map{
			"id":         outlet.ID,
			"code":       outlet.Code,
			"name":       outlet.Name,
			"address":    outlet.Address,
			"is_active":  outlet.IsActive,
			"created_at": outlet.CreatedAt,
			"updated_at": outlet.UpdatedAt,
		},
	})
}

// ── Order Handlers ──────────────────────────────────────────

func PushOrder(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)

	var req models.PushOrderRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Invalid request body",
		})
	}

	if req.LocalID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "local_id is required",
		})
	}

	cloudID, err := services.SaveOrder(outletID, req)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to save order: " + err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(models.APIResponse{
		Success: true,
		Data: fiber.Map{
			"cloud_id":  cloudID,
			"local_id":  req.LocalID,
			"version":   req.Version,
			"synced_at": time.Now().UTC().Format(time.RFC3339),
		},
	})
}

func GetOrders(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)
	page, limit := getPagination(c)

	orders, total, err := services.GetOrders(outletID, page, limit)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get orders",
		})
	}

	return c.JSON(models.PaginatedResponse{
		Success:    true,
		Data:       orders,
		Page:       page,
		Limit:      limit,
		Total:      total,
		TotalPages: int(math.Ceil(float64(total) / float64(limit))),
	})
}

// ── Transaction Handlers ────────────────────────────────────

func PushTransaction(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)

	var req models.PushTransactionRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Invalid request body",
		})
	}

	if req.LocalID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "local_id is required",
		})
	}

	cloudID, err := services.SaveTransaction(outletID, req)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to save transaction: " + err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(models.APIResponse{
		Success: true,
		Data: fiber.Map{
			"cloud_id":  cloudID,
			"local_id":  req.LocalID,
			"version":   req.Version,
			"synced_at": time.Now().UTC().Format(time.RFC3339),
		},
	})
}

func GetTransactions(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)
	page, limit := getPagination(c)

	txns, total, err := services.GetTransactions(outletID, page, limit)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get transactions",
		})
	}

	return c.JSON(models.PaginatedResponse{
		Success:    true,
		Data:       txns,
		Page:       page,
		Limit:      limit,
		Total:      total,
		TotalPages: int(math.Ceil(float64(total) / float64(limit))),
	})
}

// ── Product Handlers ────────────────────────────────────────

func PushProduct(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)

	var req models.PushProductRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Invalid request body",
		})
	}

	if req.LocalID == "" || req.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "local_id and name are required",
		})
	}

	cloudID, err := services.SaveProduct(outletID, req)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to save product: " + err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(models.APIResponse{
		Success: true,
		Data: fiber.Map{
			"cloud_id":  cloudID,
			"local_id":  req.LocalID,
			"version":   req.Version,
			"synced_at": time.Now().UTC().Format(time.RFC3339),
		},
	})
}

func GetProducts(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)
	page, limit := getPagination(c)

	products, total, err := services.GetProducts(outletID, page, limit)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get products",
		})
	}

	return c.JSON(models.PaginatedResponse{
		Success:    true,
		Data:       products,
		Page:       page,
		Limit:      limit,
		Total:      total,
		TotalPages: int(math.Ceil(float64(total) / float64(limit))),
	})
}

// ── Category Handlers ────────────────────────────────────────

func GetOutletCategories(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)

	rows, err := services.GetOutletCategoriesWithPrinter(outletID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get categories",
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: rows,
	})
}

func UpdateCategoryPrinter(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)
	categoryID := c.Params("categoryId")

	var body struct {
		PrinterID string `json:"printer_id"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Invalid request body",
		})
	}

	if err := services.UpdateCategoryPrinter(outletID, categoryID, body.PrinterID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to update category printer: " + err.Error(),
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Message: "Printer kategori berhasil diperbarui",
	})
}

// ── Printer Handlers ─────────────────────────────────────────

func GetOutletPrinters(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)

	printers, err := services.GetOutletPrinters(outletID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get printers",
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: printers,
	})
}

func PushPrinter(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)

	var req models.PushPrinterRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Invalid request body",
		})
	}

	if req.LocalID == "" || req.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "local_id and name are required",
		})
	}

	cloudID, err := services.SavePrinter(outletID, req)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to save printer: " + err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(models.APIResponse{
		Success: true,
		Data: fiber.Map{
			"cloud_id":  cloudID,
			"local_id":  req.LocalID,
			"synced_at": time.Now().UTC().Format(time.RFC3339),
		},
	})
}

// ── Analytics Handlers ──────────────────────────────────────

func PushAnalytics(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)

	var req models.PushAnalyticsRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Invalid request body",
		})
	}

	if req.Date == "" {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "date is required",
		})
	}

	cloudID, err := services.SaveAnalytics(outletID, req)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to save analytics: " + err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(models.APIResponse{
		Success: true,
		Data: fiber.Map{
			"cloud_id":  cloudID,
			"synced_at": time.Now().UTC().Format(time.RFC3339),
		},
	})
}

func GetAnalytics(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")

	analytics, err := services.GetAnalytics(outletID, startDate, endDate)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get analytics",
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: analytics,
	})
}

// ── Batch Sync Handler ──────────────────────────────────────

func BatchSync(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)

	var req models.BatchSyncRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Invalid request body",
		})
	}

	if len(req.Items) == 0 {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "No items to sync",
		})
	}

	if len(req.Items) > 1000 {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Maximum 1000 items per batch",
		})
	}

	result := services.ProcessBatchSync(outletID, req)

	return c.JSON(models.APIResponse{
		Success: true, Data: result,
	})
}

// ── Updates Handler ─────────────────────────────────────────

func GetUpdates(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)
	since := c.Query("since")

	if since == "" {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "since parameter is required (ISO 8601)",
		})
	}

	updates, err := services.GetUpdatesSince(outletID, since)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get updates: " + err.Error(),
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: updates,
	})
}

// ── Conflict Handlers ───────────────────────────────────────

func GetConflicts(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)

	conflicts, err := services.GetConflicts(outletID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get conflicts",
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: conflicts,
	})
}

func ResolveConflict(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)
	conflictID := c.Params("conflictId")

	var req models.ResolveConflictRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Invalid request body",
		})
	}

	validStrategies := map[string]bool{
		"cloud_wins": true, "local_wins": true, "newest_wins": true,
	}
	if !validStrategies[req.Strategy] {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "strategy must be: cloud_wins, local_wins, or newest_wins",
		})
	}

	if err := services.ResolveConflict(outletID, conflictID, req); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to resolve conflict",
		})
	}

	return c.JSON(models.APIResponse{
		Success: true,
		Message: "Conflict resolved successfully",
		Data: fiber.Map{
			"resolved":    true,
			"resolved_at": time.Now().UTC().Format(time.RFC3339),
		},
	})
}

// ── Sync Log Handler ────────────────────────────────────────

func GetSyncLogs(c *fiber.Ctx) error {
	outletID := c.Locals("outlet_id").(string)
	limit, _ := strconv.Atoi(c.Query("limit", "50"))
	if limit > 200 {
		limit = 200
	}

	logs, err := services.GetSyncLogs(outletID, limit)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get sync logs",
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: logs,
	})
}

// ── Dashboard Handler ───────────────────────────────────────

func GetDashboard(c *fiber.Ctx) error {
	dateFrom := c.Query("date_from", "")
	dateTo := c.Query("date_to", "")
	stats, err := services.GetDashboardStats(dateFrom, dateTo)
	if err != nil {
		log.Printf("GetDashboard error: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get dashboard stats: " + err.Error(),
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: stats,
	})
}

// ── Sales Report Handler ────────────────────────────────────

func GetSalesReport(c *fiber.Ctx) error {
	today := time.Now().Format("2006-01-02")
	dateFrom := c.Query("date_from", today)
	dateTo := c.Query("date_to", today)
	outletID := c.Query("outlet_id", "")
	page, limit := getPagination(c)

	report, err := services.GetSalesReport(dateFrom, dateTo, outletID, page, limit)
	if err != nil {
		log.Printf("GetSalesReport error: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get sales report: " + err.Error(),
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: report,
	})
}

// ── Unpaid Orders Report Handler ────────────────────────────

func GetUnpaidOrders(c *fiber.Ctx) error {
	outletID := c.Query("outlet_id", "")
	status := c.Query("status", "")
	page, limit := getPagination(c)

	report, err := services.GetUnpaidOrders(outletID, status, page, limit)
	if err != nil {
		log.Printf("GetUnpaidOrders error: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Failed to get unpaid orders: " + err.Error(),
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: report,
	})
}

// ── Helpers ─────────────────────────────────────────────────

func getPagination(c *fiber.Ctx) (int, int) {
	page, _ := strconv.Atoi(c.Query("page", "1"))
	limit, _ := strconv.Atoi(c.Query("limit", "20"))

	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}

	return page, limit
}

// ── Admin Auth Handlers ─────────────────────────────────────

func AdminLogin(cfg *config.Config) fiber.Handler {
	return func(c *fiber.Ctx) error {
		var req models.AdminLoginRequest
		if err := c.BodyParser(&req); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
				Success: false, Error: "Invalid request body",
			})
		}

		if req.Username == "" || req.Password == "" {
			return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
				Success: false, Error: "Username dan password wajib diisi",
			})
		}

		result, err := services.AdminLogin(req, cfg.JWTSecret)
		if err != nil {
			return c.Status(fiber.StatusUnauthorized).JSON(models.APIResponse{
				Success: false, Error: err.Error(),
			})
		}

		return c.JSON(models.APIResponse{
			Success: true,
			Data:    result,
			Message: "Login berhasil",
		})
	}
}

// ── Admin Product & Category Handlers ──────────────────────

func AdminGetProducts(c *fiber.Ctx) error {
	outletID := c.Query("outlet_id")
	search := c.Query("search")
	page, limit := getPagination(c)

	products, total, err := services.GetAllProducts(outletID, search, page, limit)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Gagal mengambil data produk",
		})
	}
	return c.JSON(models.APIResponse{
		Success: true,
		Data: fiber.Map{
			"items":       products,
			"total":       total,
			"page":        page,
			"limit":       limit,
			"total_pages": int(math.Ceil(float64(total) / float64(limit))),
		},
	})
}

func AdminGetCategories(c *fiber.Ctx) error {
	outletID := c.Query("outlet_id")
	search := c.Query("search")
	page, limit := getPagination(c)

	cats, total, err := services.GetAllCategories(outletID, search, page, limit)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Gagal mengambil data kategori",
		})
	}
	return c.JSON(models.APIResponse{
		Success: true,
		Data: fiber.Map{
			"items":       cats,
			"total":       total,
			"page":        page,
			"limit":       limit,
			"total_pages": int(math.Ceil(float64(total) / float64(limit))),
		},
	})
}

func AdminCreateProduct(c *fiber.Ctx) error {
	var req models.AdminCreateProductRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{Success: false, Error: "Invalid request body"})
	}
	if req.OutletID == "" || req.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{Success: false, Error: "outlet_id dan name wajib diisi"})
	}
	p, err := services.AdminCreateProduct(req)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{Success: false, Error: err.Error()})
	}
	return c.Status(fiber.StatusCreated).JSON(models.APIResponse{Success: true, Data: p})
}

func AdminUpdateProduct(c *fiber.Ctx) error {
	id := c.Params("id")
	var req models.AdminUpdateProductRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{Success: false, Error: "Invalid request body"})
	}
	if req.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{Success: false, Error: "name wajib diisi"})
	}
	if err := services.AdminUpdateProduct(id, req); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{Success: false, Error: err.Error()})
	}
	return c.JSON(models.APIResponse{Success: true, Data: fiber.Map{"id": id}})
}

func AdminDeleteProduct(c *fiber.Ctx) error {
	id := c.Params("id")
	if err := services.AdminDeleteProduct(id); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{Success: false, Error: err.Error()})
	}
	return c.JSON(models.APIResponse{Success: true, Data: fiber.Map{"id": id}})
}

func AdminCreateCategory(c *fiber.Ctx) error {
	var req models.AdminCreateCategoryRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{Success: false, Error: "Invalid request body"})
	}
	if req.OutletID == "" || req.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{Success: false, Error: "outlet_id dan name wajib diisi"})
	}
	cat, err := services.AdminCreateCategory(req)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{Success: false, Error: err.Error()})
	}
	return c.Status(fiber.StatusCreated).JSON(models.APIResponse{Success: true, Data: cat})
}

func AdminUpdateCategory(c *fiber.Ctx) error {
	id := c.Params("id")
	var req models.AdminUpdateCategoryRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{Success: false, Error: "Invalid request body"})
	}
	if req.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{Success: false, Error: "name wajib diisi"})
	}
	if err := services.AdminUpdateCategory(id, req); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{Success: false, Error: err.Error()})
	}
	return c.JSON(models.APIResponse{Success: true, Data: fiber.Map{"id": id}})
}

func AdminDeleteCategory(c *fiber.Ctx) error {
	id := c.Params("id")
	if err := services.AdminDeleteCategory(id); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{Success: false, Error: err.Error()})
	}
	return c.JSON(models.APIResponse{Success: true, Data: fiber.Map{"id": id}})
}

func GetAdmins(c *fiber.Ctx) error {
	admins, err := services.GetAdmins()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Gagal mengambil data admin",
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: admins,
	})
}

func CreateAdmin(c *fiber.Ctx) error {
	var req models.CreateAdminRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{
			Success: false, Error: "Invalid request body",
		})
	}

	admin, err := services.CreateAdmin(req)
	if err != nil {
		status := fiber.StatusInternalServerError
		if err.Error() == "username, password, dan name wajib diisi" ||
			err.Error() == "password minimal 6 karakter" {
			status = fiber.StatusBadRequest
		}
		if len(err.Error()) > 8 && err.Error()[:9] == "username " {
			status = fiber.StatusConflict
		}
		return c.Status(status).JSON(models.APIResponse{
			Success: false, Error: err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(models.APIResponse{
		Success: true,
		Data:    admin,
		Message: "Admin berhasil dibuat",
	})
}
