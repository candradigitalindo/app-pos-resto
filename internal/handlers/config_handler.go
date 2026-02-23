package handlers

import (
	"backend/internal/models"
	"backend/internal/repositories"
	"backend/internal/workers"
	"backend/pkg/utils"
	"database/sql"
	"fmt"
	"net/http"
	"strconv"

	"github.com/labstack/echo/v5"
)

type ConfigHandler struct {
	syncRepo   repositories.SyncRepository
	syncWorker *workers.SyncWorker
}

func NewConfigHandler(syncRepo repositories.SyncRepository) *ConfigHandler {
	return &ConfigHandler{
		syncRepo:   syncRepo,
		syncWorker: nil, // Will be set later
	}
}

// SetSyncWorker sets the sync worker instance (called after worker is created)
func (h *ConfigHandler) SetSyncWorker(worker *workers.SyncWorker) {
	h.syncWorker = worker
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
	// These fields can be empty string
	config.OutletAddress = req.OutletAddress
	config.OutletPhone = req.OutletPhone
	config.ReceiptFooter = req.ReceiptFooter
	config.SocialMedia = req.SocialMedia
	config.CloudAPIURL = req.CloudAPIURL
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

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Outlet configuration updated successfully",
		"data": map[string]interface{}{
			"outlet_code":           config.OutletCode,
			"sync_enabled":          config.SyncEnabled,
			"cloud_api_url":         config.CloudAPIURL,
			"sync_interval_minutes": config.SyncIntervalMin,
		},
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

// TestCloudConnection tests connection to cloud API
func (h *ConfigHandler) TestCloudConnection(c *echo.Context) error {
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

	if config.CloudAPIURL == "" || config.CloudAPIKey == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Cloud API URL and API Key must be configured",
		})
	}

	// TODO: Implement actual ping test to cloud
	// For now, just return config status
	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Configuration is valid (actual connection test coming in Phase 2)",
		"data": map[string]interface{}{
			"cloud_api_url": config.CloudAPIURL,
			"outlet_code":   config.OutletCode,
			"configured":    true,
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
