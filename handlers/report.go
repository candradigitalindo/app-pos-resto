package handlers

import (
	"cloud-pos/models"
	"cloud-pos/services"
	"log"

	"github.com/gofiber/fiber/v2"
)

func GetSalesReport(c *fiber.Ctx) error {
	dateFrom, dateTo, err := getDateRange(c)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{Success: false, Error: err.Error()})
	}
	outletID := c.Query("outlet_id", "")
	if outletID != "" && !validateOutletAccess(c, outletID) {
		return c.Status(fiber.StatusForbidden).JSON(models.APIResponse{Success: false, Error: "Akses outlet tidak diizinkan"})
	}
	page, limit := getPagination(c)
	scopeIDs := getOutletScope(c)

	report, err := services.GetSalesReport(dateFrom, dateTo, outletID, scopeIDs, page, limit)
	if err != nil {
		log.Printf("GetSalesReport error: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Gagal memuat laporan penjualan.",
		})
	}

	return c.JSON(models.APIResponse{
		Success: true, Data: report,
	})
}

func GetUnpaidOrders(c *fiber.Ctx) error {
	outletID := c.Query("outlet_id", "")
	if outletID != "" && !validateOutletAccess(c, outletID) {
		return c.Status(fiber.StatusForbidden).JSON(models.APIResponse{Success: false, Error: "Akses outlet tidak diizinkan"})
	}
	status := c.Query("status", "")
	page, limit := getPagination(c)
	scopeIDs := getOutletScope(c)

	report, err := services.GetUnpaidOrders(outletID, status, scopeIDs, page, limit)
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

func GetProductSalesReport(c *fiber.Ctx) error {
	dateFrom, dateTo, err := getDateRange(c)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{Success: false, Error: err.Error()})
	}
	outletID := c.Query("outlet_id", "")
	if outletID != "" && !validateOutletAccess(c, outletID) {
		return c.Status(fiber.StatusForbidden).JSON(models.APIResponse{Success: false, Error: "Akses outlet tidak diizinkan"})
	}

	scopeIDs := getOutletScope(c)

	report, err := services.GetProductSalesReport(dateFrom, dateTo, outletID, scopeIDs)
	if err != nil {
		log.Printf("GetProductSalesReport error: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Gagal memuat laporan penjualan produk.",
		})
	}
	return c.JSON(models.APIResponse{Success: true, Data: report})
}

func GetTaxReport(c *fiber.Ctx) error {
	dateFrom, dateTo, err := getDateRange(c)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{Success: false, Error: err.Error()})
	}
	outletID := c.Query("outlet_id", "")
	if outletID != "" && !validateOutletAccess(c, outletID) {
		return c.Status(fiber.StatusForbidden).JSON(models.APIResponse{Success: false, Error: "Akses outlet tidak diizinkan"})
	}

	scopeIDs := getOutletScope(c)

	report, err := services.GetTaxReport(dateFrom, dateTo, outletID, scopeIDs)
	if err != nil {
		log.Printf("GetTaxReport error: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Gagal memuat laporan pajak.",
		})
	}
	return c.JSON(models.APIResponse{Success: true, Data: report})
}

func GetCashFlowReport(c *fiber.Ctx) error {
	dateFrom, dateTo, err := getDateRange(c)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{Success: false, Error: err.Error()})
	}
	outletID := c.Query("outlet_id", "")
	if outletID != "" && !validateOutletAccess(c, outletID) {
		return c.Status(fiber.StatusForbidden).JSON(models.APIResponse{Success: false, Error: "Akses outlet tidak diizinkan"})
	}

	scopeIDs := getOutletScope(c)

	report, err := services.GetCashFlowReport(dateFrom, dateTo, outletID, scopeIDs)
	if err != nil {
		log.Printf("GetCashFlowReport error: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Gagal memuat laporan arus kas.",
		})
	}
	return c.JSON(models.APIResponse{Success: true, Data: report})
}

func GetBalanceReport(c *fiber.Ctx) error {
	dateFrom, dateTo, err := getDateRange(c)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{Success: false, Error: err.Error()})
	}
	outletID := c.Query("outlet_id", "")
	if outletID != "" && !validateOutletAccess(c, outletID) {
		return c.Status(fiber.StatusForbidden).JSON(models.APIResponse{Success: false, Error: "Akses outlet tidak diizinkan"})
	}

	scopeIDs := getOutletScope(c)

	report, err := services.GetBalanceReport(dateFrom, dateTo, outletID, scopeIDs)
	if err != nil {
		log.Printf("GetBalanceReport error: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Gagal memuat laporan neraca.",
		})
	}
	return c.JSON(models.APIResponse{Success: true, Data: report})
}

func GetProfitLossReport(c *fiber.Ctx) error {
	dateFrom, dateTo, err := getDateRange(c)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{Success: false, Error: err.Error()})
	}
	outletID := c.Query("outlet_id", "")
	if outletID != "" && !validateOutletAccess(c, outletID) {
		return c.Status(fiber.StatusForbidden).JSON(models.APIResponse{Success: false, Error: "Akses outlet tidak diizinkan"})
	}

	scopeIDs := getOutletScope(c)

	report, err := services.GetProfitLossReport(dateFrom, dateTo, outletID, scopeIDs)
	if err != nil {
		log.Printf("GetProfitLossReport error: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Gagal memuat laporan profit & loss.",
		})
	}
	return c.JSON(models.APIResponse{Success: true, Data: report})
}

func GetGeneralLedger(c *fiber.Ctx) error {
	dateFrom, dateTo, err := getDateRange(c)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{Success: false, Error: err.Error()})
	}
	outletID := c.Query("outlet_id", "")
	if outletID != "" && !validateOutletAccess(c, outletID) {
		return c.Status(fiber.StatusForbidden).JSON(models.APIResponse{Success: false, Error: "Akses outlet tidak diizinkan"})
	}
	scopeIDs := getOutletScope(c)
	accountFilter := c.Query("account", "")

	report, err := services.GetGeneralLedger(dateFrom, dateTo, outletID, accountFilter, scopeIDs)
	if err != nil {
		log.Printf("GetGeneralLedger error: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Gagal memuat buku besar.",
		})
	}
	return c.JSON(models.APIResponse{Success: true, Data: report})
}

func GetVoidReport(c *fiber.Ctx) error {
	dateFrom, dateTo, err := getDateRange(c)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.APIResponse{Success: false, Error: err.Error()})
	}
	outletID := c.Query("outlet_id", "")
	if outletID != "" && !validateOutletAccess(c, outletID) {
		return c.Status(fiber.StatusForbidden).JSON(models.APIResponse{Success: false, Error: "Akses outlet tidak diizinkan"})
	}
	page, limit := getPagination(c)
	scopeIDs := getOutletScope(c)

	report, err := services.GetVoidReport(dateFrom, dateTo, outletID, scopeIDs, page, limit)
	if err != nil {
		log.Printf("GetVoidReport error: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(models.APIResponse{
			Success: false, Error: "Gagal memuat laporan void.",
		})
	}
	return c.JSON(models.APIResponse{Success: true, Data: report})
}
