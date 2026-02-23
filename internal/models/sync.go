package models

import "time"

// SyncQueue represents a queued sync operation
type SyncQueue struct {
	ID           int64      `json:"id"`
	EntityType   string     `json:"entity_type"` // 'order', 'transaction', 'product', etc
	EntityID     string     `json:"entity_id"`   // ID of the entity
	Operation    string     `json:"operation"`   // 'create', 'update', 'delete'
	Payload      string     `json:"payload"`     // JSON data
	Status       string     `json:"status"`      // 'pending', 'processing', 'success', 'failed'
	RetryCount   int        `json:"retry_count"`
	MaxRetries   int        `json:"max_retries"`
	ErrorMessage string     `json:"error_message,omitempty"`
	CreatedAt    time.Time  `json:"created_at"`
	ProcessedAt  *time.Time `json:"processed_at,omitempty"`
	SyncedAt     *time.Time `json:"synced_at,omitempty"`
}

// OutletConfig represents outlet configuration for cloud sync
type OutletConfig struct {
	ID                int64      `json:"id"`
	OutletID          string     `json:"outlet_id"`
	OutletName        string     `json:"outlet_name"`
	OutletCode        string     `json:"outlet_code"`
	OutletAddress     string     `json:"outlet_address"`
	OutletPhone       string     `json:"outlet_phone"`
	ReceiptFooter     string     `json:"receipt_footer"`
	SocialMedia       string     `json:"social_media"`
	TargetSpendPerPax int64      `json:"target_spend_per_pax"`
	CloudAPIURL       string     `json:"cloud_api_url"`
	CloudAPIKey       string     `json:"cloud_api_key"`
	IsActive          bool       `json:"is_active"`
	SyncEnabled       bool       `json:"sync_enabled"`
	SyncIntervalMin   int        `json:"sync_interval_minutes"`
	LastSyncAt        *time.Time `json:"last_sync_at,omitempty"`
	CreatedAt         time.Time  `json:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at"`
}

type AdditionalCharge struct {
	ID         int64     `json:"id"`
	OutletID   string    `json:"outlet_id"`
	Name       string    `json:"name"`
	ChargeType string    `json:"charge_type"`
	Value      float64   `json:"value"`
	IsActive   bool      `json:"is_active"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

// SyncLog represents a sync operation log
type SyncLog struct {
	ID           int64      `json:"id"`
	SyncType     string     `json:"sync_type"` // 'push', 'pull'
	EntityType   string     `json:"entity_type"`
	EntityCount  int        `json:"entity_count"`
	Status       string     `json:"status"` // 'success', 'partial', 'failed'
	ErrorMessage string     `json:"error_message,omitempty"`
	StartedAt    time.Time  `json:"started_at"`
	CompletedAt  *time.Time `json:"completed_at,omitempty"`
	DurationMs   int64      `json:"duration_ms"`
	Details      string     `json:"details,omitempty"` // JSON details
}

// EntityVersion tracks entity versions for conflict detection
type EntityVersion struct {
	ID             int64      `json:"id"`
	EntityType     string     `json:"entity_type"`
	EntityID       string     `json:"entity_id"`
	Version        int        `json:"version"`
	CloudVersion   int        `json:"cloud_version"`
	LastModifiedAt time.Time  `json:"last_modified_at"`
	LastSyncedAt   *time.Time `json:"last_synced_at,omitempty"`
	SyncStatus     string     `json:"sync_status"` // 'pending', 'synced', 'conflict'
}

// SyncStatus represents current sync status
type SyncStatus struct {
	OutletID      string     `json:"outlet_id"`
	OutletCode    string     `json:"outlet_code"`
	SyncEnabled   bool       `json:"sync_enabled"`
	LastSyncAt    *time.Time `json:"last_sync_at,omitempty"`
	PendingCount  int64      `json:"pending_count"`
	FailedCount   int64      `json:"failed_count"`
	ConflictCount int64      `json:"conflict_count"`
	TotalSynced   int64      `json:"total_synced"`
	LastError     string     `json:"last_error,omitempty"`
}

// CloudSyncRequest represents data sent to cloud
type CloudSyncRequest struct {
	OutletID      string          `json:"outlet_id"`
	OutletCode    string          `json:"outlet_code"`
	SyncTimestamp time.Time       `json:"sync_timestamp"`
	Items         []CloudSyncItem `json:"items"`
}

// CloudSyncItem represents a single sync item
type CloudSyncItem struct {
	EntityType string                 `json:"entity_type"`
	Operation  string                 `json:"operation"`
	Data       map[string]interface{} `json:"data"`
}

// CloudSyncResponse represents response from cloud
type CloudSyncResponse struct {
	Success bool                  `json:"success"`
	Data    CloudSyncResponseData `json:"data"`
}

// CloudSyncResponseData contains sync results
type CloudSyncResponseData struct {
	Processed int64             `json:"processed"`
	Success   int64             `json:"success"`
	Failed    int64             `json:"failed"`
	Results   []CloudSyncResult `json:"results"`
	SyncedAt  time.Time         `json:"synced_at"`
}

// CloudSyncResult represents individual sync result
type CloudSyncResult struct {
	EntityType string `json:"entity_type"`
	LocalID    string `json:"local_id"`
	CloudID    string `json:"cloud_id,omitempty"`
	Status     string `json:"status"` // 'success', 'failed'
	Error      string `json:"error,omitempty"`
}

// CloudUpdatePayload represents update from cloud via webhook
type CloudUpdatePayload struct {
	Event      string                 `json:"event"`
	Timestamp  time.Time              `json:"timestamp"`
	EntityType string                 `json:"entity_type"`
	CloudID    string                 `json:"cloud_id"`
	LocalID    string                 `json:"local_id,omitempty"`
	Data       map[string]interface{} `json:"data"`
	Version    int                    `json:"version"`
	UpdatedBy  string                 `json:"updated_by"`
	Reason     string                 `json:"reason,omitempty"`
}

// ConflictInfo represents a sync conflict
type ConflictInfo struct {
	EntityType     string      `json:"entity_type"`
	CloudID        string      `json:"cloud_id"`
	LocalID        string      `json:"local_id"`
	Field          string      `json:"field"`
	CloudValue     interface{} `json:"cloud_value"`
	CloudVersion   int         `json:"cloud_version"`
	CloudUpdatedAt time.Time   `json:"cloud_updated_at"`
	LocalValue     interface{} `json:"local_value"`
	LocalVersion   int         `json:"local_version"`
	LocalUpdatedAt time.Time   `json:"local_updated_at"`
}

// ============================================
// LAN SYNC MODELS
// For local network synchronization
// ============================================

// RegisteredDevice represents a device connected via LAN
type RegisteredDevice struct {
	ID           int64     `json:"id"`
	DeviceID     string    `json:"device_id"`    // Unique device identifier
	DeviceName   string    `json:"device_name"`  // e.g., "Kasir 1", "Waiter iPad 2"
	DeviceType   string    `json:"device_type"`  // 'cashier', 'waiter', 'kitchen', 'bar'
	IPAddress    string    `json:"ip_address"`   // Device IP
	MACAddress   string    `json:"mac_address"`  // Device MAC address
	AppVersion   string    `json:"app_version"`  // Client app version
	Platform     string    `json:"platform"`     // 'android', 'ios', 'windows', 'web'
	IsActive     bool      `json:"is_active"`    // Device status
	LastSeenAt   time.Time `json:"last_seen_at"` // Last heartbeat
	RegisteredAt time.Time `json:"registered_at"`
	RegisteredBy string    `json:"registered_by"` // User who registered
	UpdatedAt    time.Time `json:"updated_at"`
}

// QRCodePayload represents data encoded in QR code for device pairing
type QRCodePayload struct {
	ServerIP      string `json:"server_ip"`      // LAN IP server
	ServerPort    string `json:"server_port"`    // Server port
	PairingToken  string `json:"pairing_token"`  // One-time pairing token
	OutletCode    string `json:"outlet_code"`    // Outlet identifier
	ExpiresAt     int64  `json:"expires_at"`     // Unix timestamp
	ServerVersion string `json:"server_version"` // Server app version
}

// DeviceRegistrationRequest represents device registration payload
type DeviceRegistrationRequest struct {
	DeviceID     string `json:"device_id"`     // Unique device ID (UUID)
	DeviceName   string `json:"device_name"`   // User-friendly name
	DeviceType   string `json:"device_type"`   // cashier/waiter/kitchen/bar
	IPAddress    string `json:"ip_address"`    // Device IP
	MACAddress   string `json:"mac_address"`   // Device MAC
	PairingToken string `json:"pairing_token"` // From QR code
	AppVersion   string `json:"app_version"`   // Client version
	Platform     string `json:"platform"`      // android/ios/windows/web
}

// DeviceRegistrationResponse represents successful registration response
type DeviceRegistrationResponse struct {
	DeviceID     string    `json:"device_id"`
	AccessToken  string    `json:"access_token"`  // JWT token for API access
	RefreshToken string    `json:"refresh_token"` // For token refresh
	ServerIP     string    `json:"server_ip"`
	ServerPort   string    `json:"server_port"`
	OutletCode   string    `json:"outlet_code"`
	OutletName   string    `json:"outlet_name"`
	ExpiresIn    int64     `json:"expires_in"` // Token validity in seconds
	RegisteredAt time.Time `json:"registered_at"`
}

// DeviceHeartbeat represents periodic device check-in
type DeviceHeartbeat struct {
	DeviceID   string `json:"device_id"`
	IPAddress  string `json:"ip_address"`
	AppVersion string `json:"app_version"`
	Status     string `json:"status"` // 'active', 'idle', 'busy'
}

// LANSyncStatus represents LAN sync status
type LANSyncStatus struct {
	ServerIP        string             `json:"server_ip"`
	TotalDevices    int                `json:"total_devices"`
	ActiveDevices   int                `json:"active_devices"`
	DevicesByType   map[string]int     `json:"devices_by_type"`
	RegisteredToday int                `json:"registered_today"`
	LastActivity    *time.Time         `json:"last_activity,omitempty"`
	RegisteredList  []RegisteredDevice `json:"registered_devices,omitempty"`
}
