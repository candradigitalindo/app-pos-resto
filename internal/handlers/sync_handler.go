package handlers

import (
	"backend/internal/services"
	"net/http"
	"strconv"

	"github.com/labstack/echo/v5"
)

type SyncHandler struct {
	syncService services.SyncService
}

func NewSyncHandler(syncService services.SyncService) *SyncHandler {
	return &SyncHandler{
		syncService: syncService,
	}
}

// GetSyncStatus returns current sync status
func (h *SyncHandler) GetSyncStatus(c *echo.Context) error {
	status, err := h.syncService.GetSyncStatus((*c).Request().Context())
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to get sync status: " + err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    status,
	})
}

// TriggerSync manually triggers synchronization
func (h *SyncHandler) TriggerSync(c *echo.Context) error {
	if err := h.syncService.TriggerSync((*c).Request().Context()); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to trigger sync: " + err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Sync triggered successfully",
	})
}

// GetSyncLogs returns recent sync logs
func (h *SyncHandler) GetSyncLogs(c *echo.Context) error {
	limitStr := c.QueryParam("limit")
	limit := 50 // default
	if limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 {
			limit = l
		}
	}

	logs, err := h.syncService.GetSyncLogs((*c).Request().Context(), limit)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to get sync logs: " + err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    logs,
	})
}

// GetFailedSync returns all failed sync items
func (h *SyncHandler) GetFailedSync(c *echo.Context) error {
	items, err := h.syncService.GetFailedSync((*c).Request().Context())
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to get failed sync: " + err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    items,
		"count":   len(items),
	})
}

// RetrySync retries a specific failed sync item
func (h *SyncHandler) RetrySync(c *echo.Context) error {
	idStr := c.Param("id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid sync queue ID",
		})
	}

	if err := h.syncService.RetryFailed((*c).Request().Context(), id); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to retry sync: " + err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Sync retry triggered",
	})
}
