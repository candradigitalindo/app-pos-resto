package handlers

import (
	"backend/internal/services"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"log"
	"net/http"

	"github.com/labstack/echo/v5"
)

type WebhookHandler struct {
	syncService   services.SyncService
	webhookSecret string // Shared secret for signature verification
}

func NewWebhookHandler(syncService services.SyncService, webhookSecret string) *WebhookHandler {
	return &WebhookHandler{
		syncService:   syncService,
		webhookSecret: webhookSecret,
	}
}

// verifySignature verifies the webhook signature
func (h *WebhookHandler) verifySignature(body []byte, signature string) bool {
	if h.webhookSecret == "" {
		log.Println("Warning: Webhook secret not configured, skipping signature verification")
		return true // Allow if no secret configured (dev mode)
	}

	mac := hmac.New(sha256.New, []byte(h.webhookSecret))
	mac.Write(body)
	expectedSignature := hex.EncodeToString(mac.Sum(nil))

	return hmac.Equal([]byte(signature), []byte(expectedSignature))
}

// HandleCloudUpdate handles update notifications from cloud
func (h *WebhookHandler) HandleCloudUpdate(c *echo.Context) error {
	// Read request body
	body, err := io.ReadAll((*c).Request().Body)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Failed to read request body",
		})
	}

	// Verify signature
	signature := (*c).Request().Header.Get("X-Cloud-Signature")
	if !h.verifySignature(body, signature) {
		log.Printf("Invalid webhook signature from %s", (*c).Request().RemoteAddr)
		return c.JSON(http.StatusUnauthorized, map[string]string{
			"error": "Invalid signature",
		})
	}

	// Parse payload
	var payload map[string]interface{}
	if err := json.Unmarshal(body, &payload); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid JSON payload",
		})
	}

	log.Printf("Received cloud update webhook: %v", payload)

	// Process the update
	if err := h.syncService.ProcessCloudUpdate((*c).Request().Context(), payload); err != nil {
		log.Printf("Error processing cloud update: %v", err)
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to process update",
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Update processed successfully",
	})
}

// HandleCloudDelete handles delete notifications from cloud
func (h *WebhookHandler) HandleCloudDelete(c *echo.Context) error {
	// Read request body
	body, err := io.ReadAll((*c).Request().Body)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Failed to read request body",
		})
	}

	// Verify signature
	signature := (*c).Request().Header.Get("X-Cloud-Signature")
	if !h.verifySignature(body, signature) {
		log.Printf("Invalid webhook signature from %s", (*c).Request().RemoteAddr)
		return c.JSON(http.StatusUnauthorized, map[string]string{
			"error": "Invalid signature",
		})
	}

	// Parse payload
	var payload map[string]interface{}
	if err := json.Unmarshal(body, &payload); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid JSON payload",
		})
	}

	log.Printf("Received cloud delete webhook: %v", payload)

	// Process the delete
	if err := h.syncService.ProcessCloudDelete((*c).Request().Context(), payload); err != nil {
		log.Printf("Error processing cloud delete: %v", err)
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to process delete",
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Delete processed successfully",
	})
}

// HandleCloudConflict handles conflict notifications from cloud
func (h *WebhookHandler) HandleCloudConflict(c *echo.Context) error {
	// Read request body
	body, err := io.ReadAll((*c).Request().Body)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Failed to read request body",
		})
	}

	// Verify signature
	signature := (*c).Request().Header.Get("X-Cloud-Signature")
	if !h.verifySignature(body, signature) {
		log.Printf("Invalid webhook signature from %s", (*c).Request().RemoteAddr)
		return c.JSON(http.StatusUnauthorized, map[string]string{
			"error": "Invalid signature",
		})
	}

	// Parse payload
	var payload map[string]interface{}
	if err := json.Unmarshal(body, &payload); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid JSON payload",
		})
	}

	log.Printf("Received cloud conflict webhook: %v", payload)

	// Log the conflict for manual resolution
	// In production, you might want to store this in a conflicts table
	log.Printf("CONFLICT DETECTED: %+v", payload)

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Conflict notification received",
	})
}

// HandleCloudBulkUpdate handles bulk update notifications from cloud
func (h *WebhookHandler) HandleCloudBulkUpdate(c *echo.Context) error {
	// Read request body
	body, err := io.ReadAll((*c).Request().Body)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Failed to read request body",
		})
	}

	// Verify signature
	signature := (*c).Request().Header.Get("X-Cloud-Signature")
	if !h.verifySignature(body, signature) {
		log.Printf("Invalid webhook signature from %s", (*c).Request().RemoteAddr)
		return c.JSON(http.StatusUnauthorized, map[string]string{
			"error": "Invalid signature",
		})
	}

	// Parse payload
	var payload struct {
		Updates []map[string]interface{} `json:"updates"`
	}
	if err := json.Unmarshal(body, &payload); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid JSON payload",
		})
	}

	log.Printf("Received cloud bulk update webhook: %d items", len(payload.Updates))

	// Process each update
	successCount := 0
	failedCount := 0
	for _, update := range payload.Updates {
		if err := h.syncService.ProcessCloudUpdate((*c).Request().Context(), update); err != nil {
			log.Printf("Error processing bulk update item: %v", err)
			failedCount++
		} else {
			successCount++
		}
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success":       true,
		"message":       "Bulk update processed",
		"success_count": successCount,
		"failed_count":  failedCount,
	})
}
