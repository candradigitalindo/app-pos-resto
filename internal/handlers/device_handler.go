package handlers

import (
	"backend/internal/models"
	"backend/internal/repositories"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/labstack/echo/v5"
	"github.com/skip2/go-qrcode"
)

type DeviceHandler struct {
	deviceRepo repositories.DeviceRepository
	jwtSecret  string
	serverPort string
}

func NewDeviceHandler(deviceRepo repositories.DeviceRepository, jwtSecret, serverPort string) *DeviceHandler {
	return &DeviceHandler{
		deviceRepo: deviceRepo,
		jwtSecret:  jwtSecret,
		serverPort: serverPort,
	}
}

// getLocalIP gets the LAN IP address of the server
func (h *DeviceHandler) getLocalIP() (string, error) {
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		return "", err
	}

	for _, addr := range addrs {
		if ipNet, ok := addr.(*net.IPNet); ok && !ipNet.IP.IsLoopback() {
			if ipNet.IP.To4() != nil {
				return ipNet.IP.String(), nil
			}
		}
	}

	return "", fmt.Errorf("no local IP found")
}

// generatePairingToken generates a secure random token
func (h *DeviceHandler) generatePairingToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base64.URLEncoding.EncodeToString(b), nil
}

// GenerateQRCode generates QR code for device pairing
func (h *DeviceHandler) GenerateQRCode(c *echo.Context) error {
	// Get local IP
	serverIP, err := h.getLocalIP()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to get server IP: " + err.Error(),
		})
	}

	// Generate pairing token
	token, err := h.generatePairingToken()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to generate pairing token",
		})
	}

	// Token expires in 5 minutes
	expiresAt := time.Now().Add(5 * time.Minute)

	// Save token to database
	if err := h.deviceRepo.CreatePairingToken((*c).Request().Context(), token, expiresAt); err != nil {
		log.Printf("Failed to save pairing token: %v", err)
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to create pairing token",
		})
	}

	// Get outlet code from query param or use default
	outletCode := c.QueryParam("outlet_code")
	if outletCode == "" {
		outletCode = "OUTLET-01"
	}

	// Create QR payload
	payload := models.QRCodePayload{
		ServerIP:      serverIP,
		ServerPort:    h.serverPort,
		PairingToken:  token,
		OutletCode:    outletCode,
		ExpiresAt:     expiresAt.Unix(),
		ServerVersion: "1.0.0",
	}

	// Convert to JSON
	jsonData, err := json.Marshal(payload)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to create QR payload",
		})
	}

	// Generate QR code image
	qrCode, err := qrcode.Encode(string(jsonData), qrcode.Medium, 256)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to generate QR code",
		})
	}

	// Return QR code as base64 image
	qrBase64 := base64.StdEncoding.EncodeToString(qrCode)

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data": map[string]interface{}{
			"qr_code":      qrBase64,
			"server_ip":    serverIP,
			"server_port":  h.serverPort,
			"pairing_url":  fmt.Sprintf("http://%s:%s/api/v1/devices/register", serverIP, h.serverPort),
			"expires_at":   expiresAt.Format(time.RFC3339),
			"expires_in":   300, // 5 minutes in seconds
			"outlet_code":  outletCode,
			"instructions": "Scan QR code dengan aplikasi kasir/waiter untuk terhubung ke server",
		},
	})
}

func (h *DeviceHandler) GenerateServerURLQRCode(c *echo.Context) error {
	serverIP, err := h.getLocalIP()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to get server IP: " + err.Error(),
		})
	}

	serverURL := fmt.Sprintf("http://%s", serverIP)
	qrCode, err := qrcode.Encode(serverURL, qrcode.Medium, 256)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to generate QR code",
		})
	}

	qrBase64 := base64.StdEncoding.EncodeToString(qrCode)

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data": map[string]interface{}{
			"qr_code":     qrBase64,
			"server_ip":   serverIP,
			"server_port": "80",
			"server_url":  serverURL,
		},
	})
}

// RegisterDevice handles device registration after scanning QR code
func (h *DeviceHandler) RegisterDevice(c *echo.Context) error {
	var req models.DeviceRegistrationRequest

	if err := (*c).Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid request body",
		})
	}

	// Validate required fields
	if req.DeviceID == "" || req.DeviceName == "" || req.DeviceType == "" || req.PairingToken == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Missing required fields: device_id, device_name, device_type, pairing_token",
		})
	}

	// Validate device type
	validTypes := map[string]bool{"cashier": true, "waiter": true, "kitchen": true, "bar": true}
	if !validTypes[req.DeviceType] {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid device_type. Must be: cashier, waiter, kitchen, or bar",
		})
	}

	// Validate pairing token
	valid, err := h.deviceRepo.ValidatePairingToken((*c).Request().Context(), req.PairingToken)
	if err != nil {
		log.Printf("Error validating token: %v", err)
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to validate pairing token",
		})
	}

	if !valid {
		return c.JSON(http.StatusUnauthorized, map[string]string{
			"error": "Invalid or expired pairing token",
		})
	}

	// Check if device already registered
	existing, err := h.deviceRepo.GetDeviceByID((*c).Request().Context(), req.DeviceID)
	if err != nil {
		log.Printf("Error checking existing device: %v", err)
	}

	if existing != nil {
		// Update existing device
		existing.DeviceName = req.DeviceName
		existing.DeviceType = req.DeviceType
		existing.IPAddress = req.IPAddress
		existing.MACAddress = req.MACAddress
		existing.AppVersion = req.AppVersion
		existing.Platform = req.Platform
		existing.IsActive = true
		existing.LastSeenAt = time.Now()

		if err := h.deviceRepo.UpdateDevice((*c).Request().Context(), existing); err != nil {
			log.Printf("Error updating device: %v", err)
			return c.JSON(http.StatusInternalServerError, map[string]string{
				"error": "Failed to update device",
			})
		}
	} else {
		// Register new device
		device := &models.RegisteredDevice{
			DeviceID:     req.DeviceID,
			DeviceName:   req.DeviceName,
			DeviceType:   req.DeviceType,
			IPAddress:    req.IPAddress,
			MACAddress:   req.MACAddress,
			AppVersion:   req.AppVersion,
			Platform:     req.Platform,
			IsActive:     true,
			LastSeenAt:   time.Now(),
			RegisteredBy: "qr-scan",
		}

		if err := h.deviceRepo.RegisterDevice((*c).Request().Context(), device); err != nil {
			log.Printf("Error registering device: %v", err)
			return c.JSON(http.StatusInternalServerError, map[string]string{
				"error": "Failed to register device",
			})
		}
	}

	// Mark token as used
	h.deviceRepo.DeletePairingToken((*c).Request().Context(), req.PairingToken)

	// Generate JWT token for device
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"device_id":   req.DeviceID,
		"device_name": req.DeviceName,
		"device_type": req.DeviceType,
		"role":        req.DeviceType,                              // Use device type as role
		"exp":         time.Now().Add(365 * 24 * time.Hour).Unix(), // 1 year validity
		"iat":         time.Now().Unix(),
	})

	tokenString, err := token.SignedString([]byte(h.jwtSecret))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to generate access token",
		})
	}

	// Generate refresh token (longer validity)
	refreshToken := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"device_id": req.DeviceID,
		"type":      "refresh",
		"exp":       time.Now().Add(730 * 24 * time.Hour).Unix(), // 2 years
	})

	refreshTokenString, err := refreshToken.SignedString([]byte(h.jwtSecret))
	if err != nil {
		log.Printf("Failed to generate refresh token: %v", err)
		refreshTokenString = "" // Optional, can work without refresh token
	}

	// Get server IP
	serverIP, _ := h.getLocalIP()

	// Return registration response
	response := models.DeviceRegistrationResponse{
		DeviceID:     req.DeviceID,
		AccessToken:  tokenString,
		RefreshToken: refreshTokenString,
		ServerIP:     serverIP,
		ServerPort:   h.serverPort,
		OutletCode:   "OUTLET-01",      // TODO: Get from config
		OutletName:   "Outlet Jakarta", // TODO: Get from config
		ExpiresIn:    365 * 24 * 3600,  // 1 year in seconds
		RegisteredAt: time.Now(),
	}

	log.Printf("Device registered successfully: %s (%s) - %s", req.DeviceName, req.DeviceType, req.DeviceID)

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Device registered successfully",
		"data":    response,
	})
}

// DeviceHeartbeat handles periodic device check-in
func (h *DeviceHandler) DeviceHeartbeat(c *echo.Context) error {
	var heartbeat models.DeviceHeartbeat

	if err := (*c).Bind(&heartbeat); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid request body",
		})
	}

	// Update last seen timestamp
	if err := h.deviceRepo.UpdateDeviceLastSeen((*c).Request().Context(), heartbeat.DeviceID); err != nil {
		log.Printf("Error updating heartbeat for device %s: %v", heartbeat.DeviceID, err)
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to update heartbeat",
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success":     true,
		"message":     "Heartbeat received",
		"server_time": time.Now().Format(time.RFC3339),
	})
}

// GetDeviceList lists all registered devices
func (h *DeviceHandler) GetDeviceList(c *echo.Context) error {
	// Check filter
	filter := c.QueryParam("filter") // 'all', 'active', or device type

	var devices []models.RegisteredDevice
	var err error

	switch filter {
	case "active":
		devices, err = h.deviceRepo.GetActiveDevices((*c).Request().Context())
	case "cashier", "waiter", "kitchen", "bar":
		devices, err = h.deviceRepo.GetDevicesByType((*c).Request().Context(), filter)
	default:
		devices, err = h.deviceRepo.GetAllDevices((*c).Request().Context())
	}

	if err != nil {
		log.Printf("Error getting devices: %v", err)
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to retrieve devices",
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    devices,
		"count":   len(devices),
	})
}

// GetDeviceStatus gets LAN sync status and statistics
func (h *DeviceHandler) GetDeviceStatus(c *echo.Context) error {
	stats, err := h.deviceRepo.GetDeviceStats((*c).Request().Context())
	if err != nil {
		log.Printf("Error getting device stats: %v", err)
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to get device statistics",
		})
	}

	// Get server IP
	serverIP, _ := h.getLocalIP()
	stats.ServerIP = serverIP

	// Get device list
	devices, _ := h.deviceRepo.GetActiveDevices((*c).Request().Context())
	stats.RegisteredList = devices

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    stats,
	})
}

// DeactivateDevice deactivates a device
func (h *DeviceHandler) DeactivateDevice(c *echo.Context) error {
	deviceID := c.Param("device_id")

	if err := h.deviceRepo.DeactivateDevice((*c).Request().Context(), deviceID); err != nil {
		log.Printf("Error deactivating device %s: %v", deviceID, err)
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to deactivate device",
		})
	}

	log.Printf("Device deactivated: %s", deviceID)

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Device deactivated successfully",
	})
}

// DeleteDevice removes a device
func (h *DeviceHandler) DeleteDevice(c *echo.Context) error {
	deviceID := c.Param("device_id")

	if err := h.deviceRepo.DeleteDevice((*c).Request().Context(), deviceID); err != nil {
		log.Printf("Error deleting device %s: %v", deviceID, err)
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to delete device",
		})
	}

	log.Printf("Device deleted: %s", deviceID)

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Device deleted successfully",
	})
}
