package repositories

import (
	"backend/internal/models"
	"context"
	"database/sql"
	"time"
)

type DeviceRepository interface {
	// Device management
	RegisterDevice(ctx context.Context, device *models.RegisteredDevice) error
	GetDeviceByID(ctx context.Context, deviceID string) (*models.RegisteredDevice, error)
	GetAllDevices(ctx context.Context) ([]models.RegisteredDevice, error)
	GetActiveDevices(ctx context.Context) ([]models.RegisteredDevice, error)
	GetDevicesByType(ctx context.Context, deviceType string) ([]models.RegisteredDevice, error)
	UpdateDevice(ctx context.Context, device *models.RegisteredDevice) error
	UpdateDeviceLastSeen(ctx context.Context, deviceID string) error
	DeactivateDevice(ctx context.Context, deviceID string) error
	DeleteDevice(ctx context.Context, deviceID string) error

	// Pairing token management
	CreatePairingToken(ctx context.Context, token string, expiresAt time.Time) error
	ValidatePairingToken(ctx context.Context, token string) (bool, error)
	DeletePairingToken(ctx context.Context, token string) error
	CleanupExpiredTokens(ctx context.Context) error

	// Statistics
	GetDeviceStats(ctx context.Context) (*models.LANSyncStatus, error)
	CountDevicesByType(ctx context.Context) (map[string]int, error)
}

type deviceRepositoryImpl struct {
	db *sql.DB
}

func NewDeviceRepository(db *sql.DB) DeviceRepository {
	return &deviceRepositoryImpl{db: db}
}

// RegisterDevice registers a new device
func (r *deviceRepositoryImpl) RegisterDevice(ctx context.Context, device *models.RegisteredDevice) error {
	query := `
		INSERT INTO registered_devices (
			device_id, device_name, device_type, ip_address, mac_address,
			app_version, platform, is_active, last_seen_at, registered_by
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`

	_, err := r.db.ExecContext(ctx, query,
		device.DeviceID, device.DeviceName, device.DeviceType,
		device.IPAddress, device.MACAddress, device.AppVersion,
		device.Platform, device.IsActive, device.LastSeenAt,
		device.RegisteredBy,
	)

	return err
}

// GetDeviceByID retrieves device by ID
func (r *deviceRepositoryImpl) GetDeviceByID(ctx context.Context, deviceID string) (*models.RegisteredDevice, error) {
	query := `
		SELECT id, device_id, device_name, device_type, ip_address, mac_address,
			   app_version, platform, is_active, last_seen_at, registered_at, 
			   registered_by, updated_at
		FROM registered_devices
		WHERE device_id = ?
	`

	device := &models.RegisteredDevice{}
	err := r.db.QueryRowContext(ctx, query, deviceID).Scan(
		&device.ID, &device.DeviceID, &device.DeviceName, &device.DeviceType,
		&device.IPAddress, &device.MACAddress, &device.AppVersion, &device.Platform,
		&device.IsActive, &device.LastSeenAt, &device.RegisteredAt,
		&device.RegisteredBy, &device.UpdatedAt,
	)

	if err == sql.ErrNoRows {
		return nil, nil
	}

	return device, err
}

// GetAllDevices retrieves all registered devices
func (r *deviceRepositoryImpl) GetAllDevices(ctx context.Context) ([]models.RegisteredDevice, error) {
	query := `
		SELECT id, device_id, device_name, device_type, ip_address, mac_address,
			   app_version, platform, is_active, last_seen_at, registered_at,
			   registered_by, updated_at
		FROM registered_devices
		ORDER BY registered_at DESC
	`

	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var devices []models.RegisteredDevice
	for rows.Next() {
		var device models.RegisteredDevice
		err := rows.Scan(
			&device.ID, &device.DeviceID, &device.DeviceName, &device.DeviceType,
			&device.IPAddress, &device.MACAddress, &device.AppVersion, &device.Platform,
			&device.IsActive, &device.LastSeenAt, &device.RegisteredAt,
			&device.RegisteredBy, &device.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		devices = append(devices, device)
	}

	return devices, nil
}

// GetActiveDevices retrieves only active devices
func (r *deviceRepositoryImpl) GetActiveDevices(ctx context.Context) ([]models.RegisteredDevice, error) {
	query := `
		SELECT id, device_id, device_name, device_type, ip_address, mac_address,
			   app_version, platform, is_active, last_seen_at, registered_at,
			   registered_by, updated_at
		FROM registered_devices
		WHERE is_active = 1
		ORDER BY last_seen_at DESC
	`

	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var devices []models.RegisteredDevice
	for rows.Next() {
		var device models.RegisteredDevice
		err := rows.Scan(
			&device.ID, &device.DeviceID, &device.DeviceName, &device.DeviceType,
			&device.IPAddress, &device.MACAddress, &device.AppVersion, &device.Platform,
			&device.IsActive, &device.LastSeenAt, &device.RegisteredAt,
			&device.RegisteredBy, &device.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		devices = append(devices, device)
	}

	return devices, nil
}

// GetDevicesByType retrieves devices by type
func (r *deviceRepositoryImpl) GetDevicesByType(ctx context.Context, deviceType string) ([]models.RegisteredDevice, error) {
	query := `
		SELECT id, device_id, device_name, device_type, ip_address, mac_address,
			   app_version, platform, is_active, last_seen_at, registered_at,
			   registered_by, updated_at
		FROM registered_devices
		WHERE device_type = ?
		ORDER BY registered_at DESC
	`

	rows, err := r.db.QueryContext(ctx, query, deviceType)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var devices []models.RegisteredDevice
	for rows.Next() {
		var device models.RegisteredDevice
		err := rows.Scan(
			&device.ID, &device.DeviceID, &device.DeviceName, &device.DeviceType,
			&device.IPAddress, &device.MACAddress, &device.AppVersion, &device.Platform,
			&device.IsActive, &device.LastSeenAt, &device.RegisteredAt,
			&device.RegisteredBy, &device.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		devices = append(devices, device)
	}

	return devices, nil
}

// UpdateDevice updates device information
func (r *deviceRepositoryImpl) UpdateDevice(ctx context.Context, device *models.RegisteredDevice) error {
	query := `
		UPDATE registered_devices
		SET device_name = ?, device_type = ?, ip_address = ?, mac_address = ?,
		    app_version = ?, platform = ?, is_active = ?, updated_at = CURRENT_TIMESTAMP
		WHERE device_id = ?
	`

	_, err := r.db.ExecContext(ctx, query,
		device.DeviceName, device.DeviceType, device.IPAddress,
		device.MACAddress, device.AppVersion, device.Platform,
		device.IsActive, device.DeviceID,
	)

	return err
}

// UpdateDeviceLastSeen updates device last seen timestamp (heartbeat)
func (r *deviceRepositoryImpl) UpdateDeviceLastSeen(ctx context.Context, deviceID string) error {
	query := `
		UPDATE registered_devices
		SET last_seen_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
		WHERE device_id = ?
	`

	_, err := r.db.ExecContext(ctx, query, deviceID)
	return err
}

// DeactivateDevice deactivates a device
func (r *deviceRepositoryImpl) DeactivateDevice(ctx context.Context, deviceID string) error {
	query := `
		UPDATE registered_devices
		SET is_active = 0, updated_at = CURRENT_TIMESTAMP
		WHERE device_id = ?
	`

	_, err := r.db.ExecContext(ctx, query, deviceID)
	return err
}

// DeleteDevice removes a device
func (r *deviceRepositoryImpl) DeleteDevice(ctx context.Context, deviceID string) error {
	query := `DELETE FROM registered_devices WHERE device_id = ?`
	_, err := r.db.ExecContext(ctx, query, deviceID)
	return err
}

// CreatePairingToken creates a one-time pairing token
func (r *deviceRepositoryImpl) CreatePairingToken(ctx context.Context, token string, expiresAt time.Time) error {
	query := `
		INSERT INTO pairing_tokens (token, expires_at)
		VALUES (?, ?)
	`

	_, err := r.db.ExecContext(ctx, query, token, expiresAt)
	return err
}

// ValidatePairingToken checks if token is valid and not expired
func (r *deviceRepositoryImpl) ValidatePairingToken(ctx context.Context, token string) (bool, error) {
	query := `
		SELECT COUNT(*) FROM pairing_tokens
		WHERE token = ? AND expires_at > CURRENT_TIMESTAMP AND used = 0
	`

	var count int
	err := r.db.QueryRowContext(ctx, query, token).Scan(&count)
	if err != nil {
		return false, err
	}

	return count > 0, nil
}

// DeletePairingToken marks token as used
func (r *deviceRepositoryImpl) DeletePairingToken(ctx context.Context, token string) error {
	query := `
		UPDATE pairing_tokens
		SET used = 1, used_at = CURRENT_TIMESTAMP
		WHERE token = ?
	`

	_, err := r.db.ExecContext(ctx, query, token)
	return err
}

// CleanupExpiredTokens removes expired pairing tokens
func (r *deviceRepositoryImpl) CleanupExpiredTokens(ctx context.Context) error {
	query := `
		DELETE FROM pairing_tokens
		WHERE expires_at < datetime('now', '-1 day')
	`

	_, err := r.db.ExecContext(ctx, query)
	return err
}

// GetDeviceStats retrieves device statistics
func (r *deviceRepositoryImpl) GetDeviceStats(ctx context.Context) (*models.LANSyncStatus, error) {
	stats := &models.LANSyncStatus{
		DevicesByType: make(map[string]int),
	}

	// Total devices
	err := r.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM registered_devices").Scan(&stats.TotalDevices)
	if err != nil {
		return nil, err
	}

	// Active devices
	err = r.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM registered_devices WHERE is_active = 1").Scan(&stats.ActiveDevices)
	if err != nil {
		return nil, err
	}

	// Registered today
	err = r.db.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM registered_devices 
		WHERE DATE(registered_at) = DATE('now')
	`).Scan(&stats.RegisteredToday)
	if err != nil {
		return nil, err
	}

	// Last activity
	var lastActivity sql.NullTime
	err = r.db.QueryRowContext(ctx, "SELECT MAX(last_seen_at) FROM registered_devices").Scan(&lastActivity)
	if err == nil && lastActivity.Valid {
		stats.LastActivity = &lastActivity.Time
	}

	// Devices by type
	rows, err := r.db.QueryContext(ctx, `
		SELECT device_type, COUNT(*) 
		FROM registered_devices 
		GROUP BY device_type
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var deviceType string
		var count int
		if err := rows.Scan(&deviceType, &count); err != nil {
			return nil, err
		}
		stats.DevicesByType[deviceType] = count
	}

	return stats, nil
}

// CountDevicesByType counts devices grouped by type
func (r *deviceRepositoryImpl) CountDevicesByType(ctx context.Context) (map[string]int, error) {
	counts := make(map[string]int)

	rows, err := r.db.QueryContext(ctx, `
		SELECT device_type, COUNT(*) 
		FROM registered_devices 
		WHERE is_active = 1
		GROUP BY device_type
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var deviceType string
		var count int
		if err := rows.Scan(&deviceType, &count); err != nil {
			return nil, err
		}
		counts[deviceType] = count
	}

	return counts, nil
}
