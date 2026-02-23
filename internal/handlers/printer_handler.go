package handlers

import (
	"backend/internal/repositories"
	"backend/internal/services"
	"backend/pkg/printer"
	"database/sql"
	"fmt"
	"strings"
	"time"

	"github.com/labstack/echo/v5"
)

type PrinterHandler struct {
	printerService services.PrinterService
	syncRepo       repositories.SyncRepository
}

func NewPrinterHandler(printerService services.PrinterService, syncRepo repositories.SyncRepository) *PrinterHandler {
	return &PrinterHandler{
		printerService: printerService,
		syncRepo:       syncRepo,
	}
}

type CreatePrinterRequest struct {
	Name        string `json:"name"`
	IPAddress   string `json:"ip_address"`
	Port        int64  `json:"port"`
	PrinterType string `json:"printer_type"`
	PaperSize   string `json:"paper_size"`
	IsActive    int64  `json:"is_active"`
	// Performance settings - accept both value and pointer
	ConnectionTimeout int64 `json:"connection_timeout,omitempty"`
	WriteTimeout      int64 `json:"write_timeout,omitempty"`
	RetryAttempts     int64 `json:"retry_attempts,omitempty"`
	// Print quality settings - accept both value and pointer
	PrintDensity int64  `json:"print_density,omitempty"`
	PrintSpeed   string `json:"print_speed,omitempty"`
	CutMode      string `json:"cut_mode,omitempty"`
	// Advanced settings - accept both value and pointer
	EnableBeep int64  `json:"enable_beep,omitempty"`
	AutoCut    int64  `json:"auto_cut,omitempty"`
	Charset    string `json:"charset,omitempty"`
}

type UpdatePrinterRequest struct {
	Name        string `json:"name"`
	IPAddress   string `json:"ip_address"`
	Port        int64  `json:"port"`
	PrinterType string `json:"printer_type"`
	PaperSize   string `json:"paper_size"`
	IsActive    int64  `json:"is_active"`
	// Performance settings - accept both value and pointer
	ConnectionTimeout int64 `json:"connection_timeout,omitempty"`
	WriteTimeout      int64 `json:"write_timeout,omitempty"`
	RetryAttempts     int64 `json:"retry_attempts,omitempty"`
	// Print quality settings - accept both value and pointer
	PrintDensity int64  `json:"print_density,omitempty"`
	PrintSpeed   string `json:"print_speed,omitempty"`
	CutMode      string `json:"cut_mode,omitempty"`
	// Advanced settings - accept both value and pointer
	EnableBeep int64  `json:"enable_beep,omitempty"`
	AutoCut    int64  `json:"auto_cut,omitempty"`
	Charset    string `json:"charset,omitempty"`
}

type TogglePrinterRequest struct {
	IsActive int64 `json:"is_active"`
}

func (h *PrinterHandler) CreatePrinter(c *echo.Context) error {
	var req CreatePrinterRequest
	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	// Default port 9100 jika tidak diisi
	if req.Port == 0 {
		req.Port = 9100
	}

	// Default paper size 80mm jika tidak diisi
	if req.PaperSize == "" {
		req.PaperSize = "80mm"
	}

	// Default active
	if req.IsActive == 0 {
		req.IsActive = 1
	}

	// Build optional settings - convert values to pointers
	optional := &repositories.PrinterOptionalSettings{
		ConnectionTimeout: &req.ConnectionTimeout,
		WriteTimeout:      &req.WriteTimeout,
		RetryAttempts:     &req.RetryAttempts,
		PrintDensity:      &req.PrintDensity,
		PrintSpeed:        &req.PrintSpeed,
		CutMode:           &req.CutMode,
		EnableBeep:        &req.EnableBeep,
		AutoCut:           &req.AutoCut,
		Charset:           &req.Charset,
	}

	printer, err := h.printerService.CreatePrinter(
		(*c).Request().Context(),
		req.Name,
		req.IPAddress,
		req.Port,
		req.PrinterType,
		req.PaperSize,
		req.IsActive,
		optional,
	)
	if err != nil {
		if strings.Contains(err.Error(), "UNIQUE constraint failed: printers.ip_address") || strings.Contains(err.Error(), "printers.ip_address") {
			return ConflictResponse(c, "IP address printer sudah digunakan")
		}
		return InternalErrorResponse(c, "Gagal membuat printer: "+err.Error())
	}

	return CreatedResponse(c, "Printer berhasil ditambahkan", printer)
}

func (h *PrinterHandler) GetPrinter(c *echo.Context) error {
	id := c.Param("id")

	printer, err := h.printerService.GetPrinterByID((*c).Request().Context(), id)
	if err != nil {
		if err == sql.ErrNoRows {
			return NotFoundResponse(c, "Printer tidak ditemukan")
		}
		return InternalErrorResponse(c, "Gagal mengambil printer: "+err.Error())
	}

	return SuccessResponse(c, "Printer berhasil diambil", printer)
}

func (h *PrinterHandler) GetAllPrinters(c *echo.Context) error {
	// Check query param untuk filter
	if c.QueryParam("active") == "true" {
		printers, err := h.printerService.GetActivePrinters((*c).Request().Context())
		if err != nil {
			return InternalErrorResponse(c, "Gagal mengambil data printer: "+err.Error())
		}
		return SuccessResponse(c, "Data printer aktif berhasil diambil", printers)
	}

	if printerType := c.QueryParam("type"); printerType != "" {
		printers, err := h.printerService.GetPrintersByType((*c).Request().Context(), printerType)
		if err != nil {
			return InternalErrorResponse(c, "Gagal mengambil data printer: "+err.Error())
		}
		return SuccessResponse(c, "Data printer berhasil diambil", printers)
	}

	printers, err := h.printerService.GetAllPrinters((*c).Request().Context())
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data printer: "+err.Error())
	}

	return SuccessResponse(c, "Data printer berhasil diambil", printers)
}

func (h *PrinterHandler) UpdatePrinter(c *echo.Context) error {
	id := c.Param("id")

	var req UpdatePrinterRequest
	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid: "+err.Error())
	}

	if req.Port == 0 {
		req.Port = 9100
	}

	if req.PaperSize == "" {
		req.PaperSize = "80mm"
	}

	// Build optional settings - convert values to pointers
	optional := &repositories.PrinterOptionalSettings{
		ConnectionTimeout: &req.ConnectionTimeout,
		WriteTimeout:      &req.WriteTimeout,
		RetryAttempts:     &req.RetryAttempts,
		PrintDensity:      &req.PrintDensity,
		PrintSpeed:        &req.PrintSpeed,
		CutMode:           &req.CutMode,
		EnableBeep:        &req.EnableBeep,
		AutoCut:           &req.AutoCut,
		Charset:           &req.Charset,
	}

	if err := h.printerService.UpdatePrinter(
		(*c).Request().Context(),
		id,
		req.Name,
		req.IPAddress,
		req.Port,
		req.PrinterType,
		req.PaperSize,
		req.IsActive,
		optional,
	); err != nil {
		if strings.Contains(err.Error(), "UNIQUE constraint failed: printers.ip_address") || strings.Contains(err.Error(), "printers.ip_address") {
			return ConflictResponse(c, "IP address printer sudah digunakan")
		}
		return InternalErrorResponse(c, "Gagal update printer: "+err.Error())
	}

	printer, _ := h.printerService.GetPrinterByID((*c).Request().Context(), id)
	return SuccessResponse(c, "Printer berhasil diupdate", printer)
}

func (h *PrinterHandler) DeletePrinter(c *echo.Context) error {
	id := c.Param("id")

	if err := h.printerService.DeletePrinter((*c).Request().Context(), id); err != nil {
		return InternalErrorResponse(c, "Gagal menghapus printer: "+err.Error())
	}

	return SuccessResponse(c, "Printer berhasil dihapus", nil)
}

func (h *PrinterHandler) TogglePrinter(c *echo.Context) error {
	id := c.Param("id")

	var req TogglePrinterRequest
	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	if err := h.printerService.TogglePrinterActive((*c).Request().Context(), id, req.IsActive); err != nil {
		return InternalErrorResponse(c, "Gagal toggle printer: "+err.Error())
	}

	printer, _ := h.printerService.GetPrinterByID((*c).Request().Context(), id)
	return SuccessResponse(c, "Status printer berhasil diubah", printer)
}

// TestPrintHandler sends a test receipt to the printer
func (h *PrinterHandler) TestPrintHandler(c *echo.Context) error {
	id := c.Param("id")

	// Get printer info
	printerData, err := h.printerService.GetPrinterByID((*c).Request().Context(), id)
	if err != nil {
		if err == sql.ErrNoRows {
			return NotFoundResponse(c, "Printer tidak ditemukan")
		}
		return InternalErrorResponse(c, "Gagal mengambil data printer: "+err.Error())
	}

	// Check if printer is active
	if printerData.IsActive != 1 {
		return BadRequestResponse(c, "Printer tidak aktif")
	}

	// Create default outlet config for receipt
	outletConfig := printer.OutletConfig{
		Name:        "Outlet",
		Address:     "",
		Phone:       "",
		SocialMedia: "",
		Footer:      "Terima kasih atas kunjungan Anda!",
	}

	// Try to get outlet config from database
	outletCfg, err := h.syncRepo.GetOutletConfig((*c).Request().Context())
	if err == nil && outletCfg != nil {
		// Override with actual config if available
		outletConfig.Name = outletCfg.OutletName
		outletConfig.Address = outletCfg.OutletAddress
		outletConfig.Phone = outletCfg.OutletPhone
		outletConfig.SocialMedia = outletCfg.SocialMedia
		outletConfig.Footer = outletCfg.ReceiptFooter
	}

	formatter := printer.NewPrintFormatter(outletConfig, printerData.PaperSize)

	// Generate test receipt data with printer info
	testData := printer.ReceiptData{
		ReceiptNumber: "TEST-" + time.Now().Format("150405"),
		TableNumber:   "-",
		CustomerName:  "",
		WaiterName:    "",
		CashierName:   "",
		Items: []printer.ReceiptItem{
			{
				Name:     "=== TEST PRINT ===",
				Quantity: 1,
				Price:    0,
				Total:    0,
			},
			{
				Name:     "Printer: " + printerData.Name,
				Quantity: 1,
				Price:    0,
				Total:    0,
			},
			{
				Name:     "IP: " + printerData.IpAddress,
				Quantity: 1,
				Price:    0,
				Total:    0,
			},
			{
				Name:     fmt.Sprintf("Port: %d", printerData.Port),
				Quantity: 1,
				Price:    0,
				Total:    0,
			},
			{
				Name:     "Status: BERHASIL",
				Quantity: 1,
				Price:    0,
				Total:    0,
			},
		},
		Subtotal:      0,
		Tax:           0,
		Total:         0,
		PaymentMethod: "",
		PaidAmount:    0,
		ChangeAmount:  0,
		DateTime:      time.Now(),
	}

	// Format receipt
	receiptBytes := formatter.FormatReceipt(testData)

	// Send to printer
	err = printer.SendToPrinter(printerData.IpAddress, int(printerData.Port), receiptBytes)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengirim test print: "+err.Error())
	}

	return SuccessResponse(c, "Test print berhasil dikirim", map[string]interface{}{
		"printer_name": printerData.Name,
		"ip_address":   printerData.IpAddress,
		"port":         printerData.Port,
		"status":       "Test print berhasil",
	})
}
