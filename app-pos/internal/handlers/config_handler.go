package handlers

import (
	"backend/internal/models"
	"backend/internal/repositories"
	"backend/internal/services"
	"backend/internal/workers"
	"backend/pkg/utils"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/labstack/echo/v5"
)

type ConfigHandler struct {
	syncRepo    repositories.SyncRepository
	syncWorker  *workers.SyncWorker
	syncService services.SyncService
}

func NewConfigHandler(syncRepo repositories.SyncRepository) *ConfigHandler {
	return &ConfigHandler{
		syncRepo:   syncRepo,
		syncWorker: nil, // Will be set later
	}
}

// isSyncEnabled checks if cloud sync is active
func (h *ConfigHandler) isSyncEnabled(c *echo.Context) bool {
	config, err := h.syncRepo.GetOutletConfig((*c).Request().Context())
	if err != nil || config == nil {
		return false
	}
	return config.SyncEnabled
}

// SetSyncWorker sets the sync worker instance (called after worker is created)
func (h *ConfigHandler) SetSyncWorker(worker *workers.SyncWorker) {
	h.syncWorker = worker
}

// SetSyncService sets the sync service instance for cloud client refresh
func (h *ConfigHandler) SetSyncService(svc services.SyncService) {
	h.syncService = svc
}

// GetSyncStatus returns whether cloud sync is enabled (lightweight, all authenticated users)
func (h *ConfigHandler) GetSyncEnabledStatus(c *echo.Context) error {
	config, err := h.syncRepo.GetOutletConfig((*c).Request().Context())
	if err != nil || config == nil {
		return SuccessResponse(c, "Sync status", map[string]bool{"sync_enabled": false})
	}
	return SuccessResponse(c, "Sync status", map[string]bool{"sync_enabled": config.SyncEnabled})
}

// GetOutletConfig returns current outlet configuration
func (h *ConfigHandler) GetOutletConfig(c *echo.Context) error {
	config, err := h.syncRepo.GetOutletConfig((*c).Request().Context())
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to get outlet config: " + err.Error(),
		})
	}

	if config == nil {
		return c.JSON(http.StatusNotFound, map[string]string{
			"error": "Outlet configuration not found",
		})
	}

	// Hide API key in response (show only masked version)
	response := map[string]interface{}{
		"id":                    config.ID,
		"outlet_id":             config.OutletID,
		"outlet_name":           config.OutletName,
		"outlet_code":           config.OutletCode,
		"outlet_address":        config.OutletAddress,
		"outlet_phone":          config.OutletPhone,
		"receipt_footer":        config.ReceiptFooter,
		"social_media":          config.SocialMedia,
		"target_spend_per_pax":  config.TargetSpendPerPax,
		"cloud_api_url":         config.CloudAPIURL,
		"cloud_api_key_masked":  maskAPIKey(config.CloudAPIKey),
		"is_active":             config.IsActive,
		"sync_enabled":          config.SyncEnabled,
		"sync_interval_minutes": config.SyncIntervalMin,
		"last_sync_at":          config.LastSyncAt,
		"created_at":            config.CreatedAt,
		"updated_at":            config.UpdatedAt,
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    response,
	})
}

// UpdateOutletConfig updates outlet configuration
func (h *ConfigHandler) UpdateOutletConfig(c *echo.Context) error {
	var req struct {
		OutletID          string `json:"outlet_id"`
		OutletName        string `json:"outlet_name"`
		OutletCode        string `json:"outlet_code"`
		OutletAddress     string `json:"outlet_address"`
		OutletPhone       string `json:"outlet_phone"`
		ReceiptFooter     string `json:"receipt_footer"`
		SocialMedia       string `json:"social_media"`
		TargetSpendPerPax *int64 `json:"target_spend_per_pax,omitempty"`
		CloudAPIURL       string `json:"cloud_api_url"`
		CloudAPIKey       string `json:"cloud_api_key,omitempty"` // Optional - only update if provided
		SyncEnabled       *bool  `json:"sync_enabled,omitempty"`
		SyncIntervalMin   *int   `json:"sync_interval_minutes,omitempty"`
	}

	if err := (*c).Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid request body",
		})
	}

	// Get existing config
	config, err := h.syncRepo.GetOutletConfig((*c).Request().Context())
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to get current config: " + err.Error(),
		})
	}

	if config == nil {
		return c.JSON(http.StatusNotFound, map[string]string{
			"error": "Outlet configuration not found. Please create initial config first.",
		})
	}

	// Simpan API key lama untuk deteksi perubahan
	oldAPIKey := config.CloudAPIKey

	// Update fields (only if provided)
	if req.OutletID != "" {
		config.OutletID = req.OutletID
	}
	if req.OutletName != "" {
		config.OutletName = req.OutletName
	}
	if req.OutletCode != "" {
		config.OutletCode = req.OutletCode
	}
	// These fields only update if non-empty (avoid accidental clear)
	if req.OutletAddress != "" {
		config.OutletAddress = req.OutletAddress
	}
	if req.OutletPhone != "" {
		config.OutletPhone = req.OutletPhone
	}
	if req.ReceiptFooter != "" {
		config.ReceiptFooter = req.ReceiptFooter
	}
	if req.SocialMedia != "" {
		config.SocialMedia = req.SocialMedia
	}
	if req.CloudAPIURL != "" {
		config.CloudAPIURL = req.CloudAPIURL
	}
	if req.TargetSpendPerPax != nil {
		if *req.TargetSpendPerPax < 0 {
			return c.JSON(http.StatusBadRequest, map[string]string{
				"error": "Target spend per pax must be non-negative",
			})
		}
		config.TargetSpendPerPax = *req.TargetSpendPerPax
	}

	if req.CloudAPIKey != "" {
		config.CloudAPIKey = req.CloudAPIKey
	}
	if req.SyncEnabled != nil {
		config.SyncEnabled = *req.SyncEnabled
	}
	if req.SyncIntervalMin != nil {
		if *req.SyncIntervalMin < 1 {
			return c.JSON(http.StatusBadRequest, map[string]string{
				"error": "Sync interval must be at least 1 minute",
			})
		}
		config.SyncIntervalMin = *req.SyncIntervalMin
	}

	// Update in database
	if err := h.syncRepo.UpdateOutletConfig((*c).Request().Context(), config); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to update config: " + err.Error(),
		})
	}

	// Update sync worker if sync_enabled changed
	if req.SyncEnabled != nil && h.syncWorker != nil {
		h.syncWorker.SetEnabled(*req.SyncEnabled)
	}

	// Update sync worker interval if changed
	if req.SyncIntervalMin != nil && h.syncWorker != nil {
		h.syncWorker.SetInterval(*req.SyncIntervalMin)
	}

	// Jika API key berubah DAN cloud URL tersedia, auto-discover outlet info dari cloud
	apiKeyChanged := req.CloudAPIKey != "" && req.CloudAPIKey != oldAPIKey
	cloudURL := strings.TrimSuffix(config.CloudAPIURL, "/")
	outletDiscovered := false

	if apiKeyChanged && cloudURL != "" {
		discoverReq, err2 := http.NewRequest("GET", cloudURL+"/outlet/me", nil)
		if err2 == nil {
			discoverReq.Header.Set("Authorization", "Bearer "+config.CloudAPIKey)
			httpClient := &http.Client{Timeout: 10 * time.Second}
			resp2, err2 := httpClient.Do(discoverReq)
			if err2 == nil {
				defer resp2.Body.Close()
				body2, _ := io.ReadAll(resp2.Body)
				var cloudResp struct {
					Success bool `json:"success"`
					Data    struct {
						ID      string `json:"id"`
						Code    string `json:"code"`
						Name    string `json:"name"`
						Address string `json:"address"`
					} `json:"data"`
				}
				if json.Unmarshal(body2, &cloudResp) == nil && cloudResp.Success && cloudResp.Data.ID != "" {
					config.OutletID = cloudResp.Data.ID
					config.OutletName = cloudResp.Data.Name
					config.OutletCode = cloudResp.Data.Code
					config.OutletAddress = cloudResp.Data.Address
					outletDiscovered = true
					// Simpan ulang config dengan data outlet terbaru
					if err := h.syncRepo.UpdateOutletConfig((*c).Request().Context(), config); err != nil {
						log.Printf("Warning: gagal simpan outlet info dari cloud: %v", err)
					} else {
						log.Printf("Outlet info di-update otomatis dari cloud: id=%s name=%s code=%s", config.OutletID, config.OutletName, config.OutletCode)
					}
				} else {
					log.Printf("Warning: gagal parse respons /outlet/me atau API key tidak valid (status %d)", resp2.StatusCode)
				}
			} else {
				log.Printf("Warning: gagal request /outlet/me: %v", err2)
			}
		}
	}

	// Reload cloud client if cloud config was changed
	if h.syncService != nil && (req.CloudAPIURL != "" || req.CloudAPIKey != "" || req.OutletID != "") {
		if err := h.syncService.ReloadCloudClient((*c).Request().Context()); err != nil {
			log.Printf("Warning: failed to reload cloud client: %v", err)
		}
	}

	// Jika outlet berhasil di-discover (API key berubah), pull semua produk & kategori
	// dari cloud outlet baru ke lokal secara background (tanpa blokir response)
	if outletDiscovered && h.syncService != nil {
		svc := h.syncService
		go func() {
			log.Println("Auto pull produk & kategori dari cloud outlet baru...")
			if err := svc.FullPullFromCloud(context.Background()); err != nil {
				log.Printf("Warning: gagal pull dari cloud setelah outlet discovery: %v", err)
			} else {
				log.Println("Pull produk & kategori dari cloud selesai")
			}
		}()
	}

	responseData := map[string]interface{}{
		"outlet_id":             config.OutletID,
		"outlet_name":           config.OutletName,
		"outlet_code":           config.OutletCode,
		"outlet_address":        config.OutletAddress,
		"sync_enabled":          config.SyncEnabled,
		"cloud_api_url":         config.CloudAPIURL,
		"sync_interval_minutes": config.SyncIntervalMin,
		"outlet_auto_updated":   outletDiscovered,
		"data_pull_started":     outletDiscovered && h.syncService != nil,
	}

	message := "Outlet configuration updated successfully"
	if outletDiscovered {
		message = fmt.Sprintf("Konfigurasi berhasil diperbarui. Data outlet ditemukan: %s (%s). Produk & kategori sedang di-sinkronisasi dari cloud...", config.OutletName, config.OutletCode)
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"message": message,
		"data":    responseData,
	})
}

// CreateOutletConfig creates initial outlet configuration
func (h *ConfigHandler) CreateOutletConfig(c *echo.Context) error {
	var req struct {
		OutletID          string `json:"outlet_id"`
		OutletName        string `json:"outlet_name"`
		OutletCode        string `json:"outlet_code"`
		OutletAddress     string `json:"outlet_address"`
		OutletPhone       string `json:"outlet_phone"`
		ReceiptFooter     string `json:"receipt_footer"`
		SocialMedia       string `json:"social_media"`
		TargetSpendPerPax int64  `json:"target_spend_per_pax"`
		CloudAPIURL       string `json:"cloud_api_url"`
		CloudAPIKey       string `json:"cloud_api_key"`
		SyncEnabled       bool   `json:"sync_enabled"`
		SyncIntervalMin   int    `json:"sync_interval_minutes"`
	}

	if err := (*c).Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid request body",
		})
	}

	// Validate required fields - only outlet_name is truly required now
	if req.OutletName == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "outlet_name is required",
		})
	}

	// Generate outlet_id if not provided
	if req.OutletID == "" {
		req.OutletID = utils.GenerateULID()
	}

	// Generate outlet_code if not provided
	if req.OutletCode == "" {
		req.OutletCode = "OUTLET-001"
	}

	// Cloud sync is now optional - no validation for cloud_api_url and cloud_api_key

	if req.SyncIntervalMin < 1 {
		req.SyncIntervalMin = 5 // default
	}

	// Default receipt footer
	if req.ReceiptFooter == "" {
		req.ReceiptFooter = "Terima kasih atas kunjungan Anda!"
	}

	// Check if config already exists
	existing, err := h.syncRepo.GetOutletConfig((*c).Request().Context())
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to check existing config: " + err.Error(),
		})
	}

	if existing != nil {
		return c.JSON(http.StatusConflict, map[string]string{
			"error": "Outlet configuration already exists. Use PUT to update.",
		})
	}

	// Create config
	config := &models.OutletConfig{
		OutletID:          req.OutletID,
		OutletName:        req.OutletName,
		OutletCode:        req.OutletCode,
		OutletAddress:     req.OutletAddress,
		OutletPhone:       req.OutletPhone,
		ReceiptFooter:     req.ReceiptFooter,
		SocialMedia:       req.SocialMedia,
		TargetSpendPerPax: req.TargetSpendPerPax,
		CloudAPIURL:       req.CloudAPIURL,
		CloudAPIKey:       req.CloudAPIKey,
		IsActive:          true,
		SyncEnabled:       req.SyncEnabled,
		SyncIntervalMin:   req.SyncIntervalMin,
	}

	if err := h.syncRepo.CreateOutletConfig((*c).Request().Context(), config); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to create config: " + err.Error(),
		})
	}

	return c.JSON(http.StatusCreated, map[string]interface{}{
		"success": true,
		"message": "Outlet configuration created successfully",
		"data": map[string]interface{}{
			"outlet_id":             config.OutletID,
			"outlet_name":           config.OutletName,
			"outlet_code":           config.OutletCode,
			"sync_enabled":          config.SyncEnabled,
			"sync_interval_minutes": config.SyncIntervalMin,
		},
	})
}

func (h *ConfigHandler) GetAdditionalCharges(c *echo.Context) error {
	charges, err := h.syncRepo.ListAdditionalCharges((*c).Request().Context())
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to get additional charges: " + err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    charges,
	})
}

func (h *ConfigHandler) CreateAdditionalCharge(c *echo.Context) error {
	if h.isSyncEnabled(c) {
		return (*c).JSON(http.StatusLocked, map[string]interface{}{
			"success": false,
			"message": "Sync aktif. Biaya tambahan harus dikelola melalui cloud.",
		})
	}

	var req struct {
		Name       string  `json:"name"`
		ChargeType string  `json:"charge_type"`
		Value      float64 `json:"value"`
		IsActive   *bool   `json:"is_active,omitempty"`
	}

	if err := (*c).Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid request body",
		})
	}

	if req.Name == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "name is required",
		})
	}

	if req.ChargeType != "percentage" && req.ChargeType != "fixed" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "charge_type must be percentage or fixed",
		})
	}

	if req.Value < 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "value must be non-negative",
		})
	}

	if req.ChargeType == "percentage" && req.Value > 100 {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "percentage value must be between 0 and 100",
		})
	}

	isActive := true
	if req.IsActive != nil {
		isActive = *req.IsActive
	}

	outletID := ""
	config, err := h.syncRepo.GetOutletConfig((*c).Request().Context())
	if err == nil && config != nil {
		outletID = config.OutletID
	}

	charge := &models.AdditionalCharge{
		OutletID:   outletID,
		Name:       req.Name,
		ChargeType: req.ChargeType,
		Value:      req.Value,
		IsActive:   isActive,
	}

	if err := h.syncRepo.CreateAdditionalCharge((*c).Request().Context(), charge); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to create additional charge: " + err.Error(),
		})
	}

	if err := h.syncRepo.RefreshOpenOrderTotalsForAdditionalCharges((*c).Request().Context()); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to refresh open order totals: " + err.Error(),
		})
	}

	return c.JSON(http.StatusCreated, map[string]interface{}{
		"success": true,
		"data":    charge,
	})
}

func (h *ConfigHandler) UpdateAdditionalCharge(c *echo.Context) error {
	if h.isSyncEnabled(c) {
		return (*c).JSON(http.StatusLocked, map[string]interface{}{
			"success": false,
			"message": "Sync aktif. Biaya tambahan harus dikelola melalui cloud.",
		})
	}

	var req struct {
		Name       string  `json:"name"`
		ChargeType string  `json:"charge_type"`
		Value      float64 `json:"value"`
		IsActive   *bool   `json:"is_active,omitempty"`
	}

	if err := (*c).Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid request body",
		})
	}

	id, err := strconv.ParseInt((*c).Param("id"), 10, 64)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid charge id",
		})
	}

	if req.Name == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "name is required",
		})
	}

	if req.ChargeType != "percentage" && req.ChargeType != "fixed" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "charge_type must be percentage or fixed",
		})
	}

	if req.Value < 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "value must be non-negative",
		})
	}

	if req.ChargeType == "percentage" && req.Value > 100 {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "percentage value must be between 0 and 100",
		})
	}

	isActive := true
	if req.IsActive != nil {
		isActive = *req.IsActive
	}

	charge := &models.AdditionalCharge{
		ID:         id,
		Name:       req.Name,
		ChargeType: req.ChargeType,
		Value:      req.Value,
		IsActive:   isActive,
	}

	if err := h.syncRepo.UpdateAdditionalCharge((*c).Request().Context(), charge); err != nil {
		if err == sql.ErrNoRows {
			return c.JSON(http.StatusNotFound, map[string]string{
				"error": "Additional charge not found",
			})
		}
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to update additional charge: " + err.Error(),
		})
	}

	if err := h.syncRepo.RefreshOpenOrderTotalsForAdditionalCharges((*c).Request().Context()); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to refresh open order totals: " + err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    charge,
	})
}

func (h *ConfigHandler) DeleteAdditionalCharge(c *echo.Context) error {
	if h.isSyncEnabled(c) {
		return (*c).JSON(http.StatusLocked, map[string]interface{}{
			"success": false,
			"message": "Sync aktif. Biaya tambahan harus dikelola melalui cloud.",
		})
	}

	id, err := strconv.ParseInt((*c).Param("id"), 10, 64)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid charge id",
		})
	}

	if err := h.syncRepo.DeleteAdditionalCharge((*c).Request().Context(), id); err != nil {
		if err == sql.ErrNoRows {
			return c.JSON(http.StatusNotFound, map[string]string{
				"error": "Additional charge not found",
			})
		}
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to delete additional charge: " + err.Error(),
		})
	}

	if err := h.syncRepo.RefreshOpenOrderTotalsForAdditionalCharges((*c).Request().Context()); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to refresh open order totals: " + err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
	})
}

// TestCloudConnection tests connection to cloud API and fetches outlet info
func (h *ConfigHandler) TestCloudConnection(c *echo.Context) error {
	config, err := h.syncRepo.GetOutletConfig((*c).Request().Context())
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error":   "Failed to get outlet config: " + err.Error(),
		})
	}

	if config == nil {
		return c.JSON(http.StatusNotFound, map[string]interface{}{
			"success": false,
			"error":   "Outlet configuration not found",
		})
	}

	if config.CloudAPIURL == "" || config.CloudAPIKey == "" {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error":   "Cloud API URL dan API Key harus diisi terlebih dahulu",
		})
	}

	// Step 1: Ping cloud API to check connectivity
	cloudURL := strings.TrimRight(config.CloudAPIURL, "/")
	// Handle URL that already contains /api/v1
	pingURL := cloudURL + "/ping"
	if !strings.Contains(cloudURL, "/api/v1") {
		pingURL = cloudURL + "/api/v1/ping"
	}

	httpClient := &http.Client{Timeout: 10 * time.Second}

	pingResp, err := httpClient.Get(pingURL)
	if err != nil {
		return c.JSON(http.StatusOK, map[string]interface{}{
			"success":   false,
			"connected": false,
			"error":     "Tidak dapat terhubung ke server cloud: " + err.Error(),
		})
	}
	pingResp.Body.Close()

	if pingResp.StatusCode != 200 {
		return c.JSON(http.StatusOK, map[string]interface{}{
			"success":   false,
			"connected": false,
			"error":     fmt.Sprintf("Server cloud merespon dengan status %d", pingResp.StatusCode),
		})
	}

	// Step 2: Find outlet ID by trying to authenticate with the API key
	// We need to discover the outlet ID. Try the stored outlet_id first,
	// or use a known approach.
	outletID := config.OutletID
	if outletID == "" {
		// No outlet ID stored - can't proceed
		return c.JSON(http.StatusOK, map[string]interface{}{
			"success":   true,
			"connected": true,
			"error":     "Terhubung ke cloud, tapi Outlet ID belum diisi. Masukkan Outlet ID yang terdaftar di cloud.",
		})
	}

	// Step 3: Get outlet info from cloud API
	infoURL := cloudURL + "/outlets/" + outletID + "/info"
	if !strings.Contains(cloudURL, "/api/v1") {
		infoURL = cloudURL + "/api/v1/outlets/" + outletID + "/info"
	}
	req2, _ := http.NewRequest("GET", infoURL, nil)
	req2.Header.Set("Authorization", "Bearer "+config.CloudAPIKey)

	infoResp, err := httpClient.Do(req2)
	if err != nil {
		return c.JSON(http.StatusOK, map[string]interface{}{
			"success":   false,
			"connected": true,
			"error":     "Terhubung ke cloud tapi gagal mengambil info outlet: " + err.Error(),
		})
	}
	defer infoResp.Body.Close()

	body, _ := io.ReadAll(infoResp.Body)

	if infoResp.StatusCode == 401 || infoResp.StatusCode == 403 {
		return c.JSON(http.StatusOK, map[string]interface{}{
			"success":   false,
			"connected": true,
			"error":     "API Key tidak valid atau outlet tidak aktif. Periksa kembali API Key Anda.",
		})
	}

	if infoResp.StatusCode != 200 {
		return c.JSON(http.StatusOK, map[string]interface{}{
			"success":   false,
			"connected": true,
			"error":     fmt.Sprintf("Gagal mengambil info outlet (status %d)", infoResp.StatusCode),
		})
	}

	// Parse cloud response
	var cloudResp struct {
		Success bool `json:"success"`
		Data    struct {
			ID         string  `json:"id"`
			Code       string  `json:"code"`
			Name       string  `json:"name"`
			Address    string  `json:"address"`
			IsActive   bool    `json:"is_active"`
			CreatedAt  string  `json:"created_at"`
			UpdatedAt  string  `json:"updated_at"`
			TaxEnabled bool    `json:"tax_enabled"`
			TaxRate    float64 `json:"tax_rate"`
			TaxName    string  `json:"tax_name"`
		} `json:"data"`
		Error string `json:"error"`
	}

	if err := json.Unmarshal(body, &cloudResp); err != nil {
		return c.JSON(http.StatusOK, map[string]interface{}{
			"success":   false,
			"connected": true,
			"error":     "Respon cloud tidak valid: " + err.Error(),
		})
	}

	if !cloudResp.Success {
		return c.JSON(http.StatusOK, map[string]interface{}{
			"success":   false,
			"connected": true,
			"error":     "Cloud error: " + cloudResp.Error,
		})
	}

	// Step 4: Auto-update local outlet info from cloud data
	updated := false
	if cloudResp.Data.Name != "" && cloudResp.Data.Name != config.OutletName {
		config.OutletName = cloudResp.Data.Name
		updated = true
	}
	if cloudResp.Data.Code != "" && cloudResp.Data.Code != config.OutletCode {
		config.OutletCode = cloudResp.Data.Code
		updated = true
	}
	if cloudResp.Data.Address != "" && cloudResp.Data.Address != config.OutletAddress {
		config.OutletAddress = cloudResp.Data.Address
		updated = true
	}
	if cloudResp.Data.ID != "" && cloudResp.Data.ID != config.OutletID {
		config.OutletID = cloudResp.Data.ID
		updated = true
	}

	if updated {
		if err := h.syncRepo.UpdateOutletConfig((*c).Request().Context(), config); err != nil {
			log.Printf("Warning: failed to auto-update outlet info from cloud: %v", err)
		} else {
			log.Printf("Outlet info updated from cloud: name=%s code=%s", config.OutletName, config.OutletCode)
		}
	}

	// Step 5: Sync tax settings from cloud → local additional_charges
	h.syncTaxFromCloud((*c).Request().Context(), cloudResp.Data.TaxEnabled, cloudResp.Data.TaxRate, cloudResp.Data.TaxName)

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success":   true,
		"connected": true,
		"message":   "Berhasil terhubung ke cloud",
		"data": map[string]interface{}{
			"outlet_id":   cloudResp.Data.ID,
			"outlet_code": cloudResp.Data.Code,
			"outlet_name": cloudResp.Data.Name,
			"address":     cloudResp.Data.Address,
			"is_active":   cloudResp.Data.IsActive,
			"updated":     updated,
		},
	})
}

// Helper function to mask API key
func maskAPIKey(key string) string {
	if len(key) <= 8 {
		return "****"
	}
	return key[:4] + "****" + key[len(key)-4:]
}

// syncTaxFromCloud syncs tax settings from cloud into local additional_charges.
// It creates or updates a single "tax" additional_charge entry.
func (h *ConfigHandler) syncTaxFromCloud(ctx context.Context, taxEnabled bool, taxRate float64, taxName string) {
	if taxName == "" {
		taxName = "Pajak Restoran (PB1)"
	}

	// Find existing tax charge by name pattern
	charges, err := h.syncRepo.ListAdditionalCharges(ctx)
	if err != nil {
		log.Printf("Warning: failed to list additional charges for tax sync: %v", err)
		return
	}

	var existingTax *models.AdditionalCharge
	for i, ch := range charges {
		if ch.ChargeType == "percentage" && (ch.Name == taxName || strings.HasPrefix(strings.ToLower(ch.Name), "pajak")) {
			existingTax = &charges[i]
			break
		}
	}

	if existingTax != nil {
		// Update existing
		existingTax.Name = taxName
		existingTax.Value = taxRate
		existingTax.IsActive = taxEnabled
		if err := h.syncRepo.UpdateAdditionalCharge(ctx, existingTax); err != nil {
			log.Printf("Warning: failed to update tax charge: %v", err)
			return
		}
		log.Printf("Tax charge updated: name=%s rate=%.2f enabled=%v", taxName, taxRate, taxEnabled)
	} else {
		// Create new
		newCharge := &models.AdditionalCharge{
			Name:       taxName,
			ChargeType: "percentage",
			Value:      taxRate,
			IsActive:   taxEnabled,
		}
		if err := h.syncRepo.CreateAdditionalCharge(ctx, newCharge); err != nil {
			log.Printf("Warning: failed to create tax charge: %v", err)
			return
		}
		log.Printf("Tax charge created: name=%s rate=%.2f enabled=%v", taxName, taxRate, taxEnabled)
	}

	// Recalculate open orders with new tax settings
	if err := h.syncRepo.RefreshOpenOrderTotalsForAdditionalCharges(ctx); err != nil {
		log.Printf("Warning: failed to refresh open orders after tax sync: %v", err)
	}
}

// ToggleSync toggles sync on/off
func (h *ConfigHandler) ToggleSync(c *echo.Context) error {
	var req struct {
		Enabled bool `json:"enabled"`
	}

	if err := (*c).Bind(&req); err != nil {
		return (*c).JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"message": "Invalid request body",
		})
	}

	// Get current config
	config, err := h.syncRepo.GetOutletConfig((*c).Request().Context())
	if err != nil {
		return (*c).JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"message": "Failed to get config: " + err.Error(),
		})
	}

	if config == nil {
		return (*c).JSON(http.StatusNotFound, map[string]interface{}{
			"success": false,
			"message": "Outlet configuration not found. Please create config first.",
		})
	}

	// Update sync enabled status
	config.SyncEnabled = req.Enabled

	if err := h.syncRepo.UpdateOutletConfig((*c).Request().Context(), config); err != nil {
		return (*c).JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"message": "Failed to update sync status: " + err.Error(),
		})
	}

	// Update sync worker real-time
	if h.syncWorker != nil {
		h.syncWorker.SetEnabled(req.Enabled)
	}

	status := "disabled"
	if req.Enabled {
		status = "enabled"
	}

	return (*c).JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"message": fmt.Sprintf("Sync %s successfully", status),
		"data": map[string]interface{}{
			"sync_enabled":   config.SyncEnabled,
			"worker_running": h.syncWorker != nil && h.syncWorker.IsRunning(),
		},
	})
}

// GetSyncSettings returns sync-specific settings
func (h *ConfigHandler) GetSyncSettings(c *echo.Context) error {
	config, err := h.syncRepo.GetOutletConfig((*c).Request().Context())
	if err != nil {
		return (*c).JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"message": "Failed to get config: " + err.Error(),
		})
	}

	workerStatus := map[string]interface{}{
		"initialized": h.syncWorker != nil,
		"running":     false,
		"enabled":     false,
	}

	if h.syncWorker != nil {
		workerStatus["running"] = h.syncWorker.IsRunning()
		workerStatus["enabled"] = h.syncWorker.IsEnabled()
	}

	response := map[string]interface{}{
		"sync_enabled":          false,
		"sync_interval_minutes": 5,
		"cloud_configured":      false,
		"worker_status":         workerStatus,
	}

	if config != nil {
		response["sync_enabled"] = config.SyncEnabled
		response["sync_interval_minutes"] = config.SyncIntervalMin
		response["cloud_configured"] = config.CloudAPIURL != "" && config.CloudAPIKey != ""
		response["cloud_api_url"] = config.CloudAPIURL
		response["outlet_code"] = config.OutletCode
		response["last_sync_at"] = config.LastSyncAt
	}

	return (*c).JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    response,
	})
}
