package repositories

import (
	"backend/internal/models"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
)

type SyncRepository interface {
	// Queue operations
	EnqueueSync(ctx context.Context, entityType, entityID, operation string, payload interface{}) error
	GetPendingSync(ctx context.Context, limit int) ([]models.SyncQueue, error)
	MarkSyncProcessing(ctx context.Context, id int64) error
	MarkSyncSuccess(ctx context.Context, id int64, cloudID string) error
	MarkSyncFailed(ctx context.Context, id int64, errMsg string) error
	GetFailedSync(ctx context.Context) ([]models.SyncQueue, error)
	DeleteSyncQueue(ctx context.Context, id int64) error

	// Config operations
	GetOutletConfig(ctx context.Context) (*models.OutletConfig, error)
	CreateOutletConfig(ctx context.Context, config *models.OutletConfig) error
	UpdateOutletConfig(ctx context.Context, config *models.OutletConfig) error
	UpdateLastSync(ctx context.Context) error
	ListAdditionalCharges(ctx context.Context) ([]models.AdditionalCharge, error)
	CreateAdditionalCharge(ctx context.Context, charge *models.AdditionalCharge) error
	UpdateAdditionalCharge(ctx context.Context, charge *models.AdditionalCharge) error
	DeleteAdditionalCharge(ctx context.Context, id int64) error
	RefreshOpenOrderTotalsForAdditionalCharges(ctx context.Context) error

	// Version tracking
	GetEntityVersion(ctx context.Context, entityType, entityID string) (*models.EntityVersion, error)
	UpdateEntityVersion(ctx context.Context, entityType, entityID string, version, cloudVersion int) error
	MarkEntitySynced(ctx context.Context, entityType, entityID string, cloudVersion int) error

	// Logs
	CreateSyncLog(ctx context.Context, log *models.SyncLog) (int64, error)
	UpdateSyncLog(ctx context.Context, id int64, status string, entityCount int, errMsg string, durationMs int64) error
	GetSyncLogs(ctx context.Context, limit int) ([]models.SyncLog, error)

	// Status
	GetSyncStatus(ctx context.Context) (*models.SyncStatus, error)
}

type syncRepositoryImpl struct {
	db *sql.DB
}

func NewSyncRepository(db *sql.DB) SyncRepository {
	return &syncRepositoryImpl{db: db}
}

// EnqueueSync adds a new sync operation to queue
func (r *syncRepositoryImpl) EnqueueSync(ctx context.Context, entityType, entityID, operation string, payload interface{}) error {
	payloadJSON, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal payload: %w", err)
	}

	query := `
		INSERT INTO sync_queue (entity_type, entity_id, operation, payload, status, retry_count, max_retries)
		VALUES (?, ?, ?, ?, 'pending', 0, 3)
	`

	_, err = r.db.ExecContext(ctx, query, entityType, entityID, operation, string(payloadJSON))
	if err != nil {
		return fmt.Errorf("failed to enqueue sync: %w", err)
	}

	return nil
}

// GetPendingSync retrieves pending sync operations
func (r *syncRepositoryImpl) GetPendingSync(ctx context.Context, limit int) ([]models.SyncQueue, error) {
	query := `
		SELECT id, entity_type, entity_id, operation, payload, status, retry_count, 
		       max_retries, error_message, created_at, processed_at, synced_at
		FROM sync_queue
		WHERE status = 'pending' AND retry_count < max_retries
		ORDER BY created_at ASC
		LIMIT ?
	`

	rows, err := r.db.QueryContext(ctx, query, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to query pending sync: %w", err)
	}
	defer rows.Close()

	var items []models.SyncQueue
	for rows.Next() {
		var item models.SyncQueue
		var processedAt, syncedAt sql.NullTime

		err := rows.Scan(
			&item.ID, &item.EntityType, &item.EntityID, &item.Operation, &item.Payload,
			&item.Status, &item.RetryCount, &item.MaxRetries, &item.ErrorMessage,
			&item.CreatedAt, &processedAt, &syncedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan sync queue: %w", err)
		}

		if processedAt.Valid {
			item.ProcessedAt = &processedAt.Time
		}
		if syncedAt.Valid {
			item.SyncedAt = &syncedAt.Time
		}

		items = append(items, item)
	}

	return items, nil
}

// MarkSyncProcessing marks sync as processing
func (r *syncRepositoryImpl) MarkSyncProcessing(ctx context.Context, id int64) error {
	query := `
		UPDATE sync_queue 
		SET status = 'processing', processed_at = CURRENT_TIMESTAMP
		WHERE id = ?
	`

	_, err := r.db.ExecContext(ctx, query, id)
	if err != nil {
		return fmt.Errorf("failed to mark sync processing: %w", err)
	}

	return nil
}

// MarkSyncSuccess marks sync as successful
func (r *syncRepositoryImpl) MarkSyncSuccess(ctx context.Context, id int64, cloudID string) error {
	query := `
		UPDATE sync_queue 
		SET status = 'success', synced_at = CURRENT_TIMESTAMP, error_message = NULL
		WHERE id = ?
	`

	_, err := r.db.ExecContext(ctx, query, id)
	if err != nil {
		return fmt.Errorf("failed to mark sync success: %w", err)
	}

	return nil
}

// MarkSyncFailed marks sync as failed and increments retry count
func (r *syncRepositoryImpl) MarkSyncFailed(ctx context.Context, id int64, errMsg string) error {
	query := `
		UPDATE sync_queue 
		SET status = CASE 
			WHEN retry_count + 1 >= max_retries THEN 'failed'
			ELSE 'pending'
		END,
		retry_count = retry_count + 1,
		error_message = ?
		WHERE id = ?
	`

	_, err := r.db.ExecContext(ctx, query, errMsg, id)
	if err != nil {
		return fmt.Errorf("failed to mark sync failed: %w", err)
	}

	return nil
}

// GetFailedSync retrieves all failed sync operations
func (r *syncRepositoryImpl) GetFailedSync(ctx context.Context) ([]models.SyncQueue, error) {
	query := `
		SELECT id, entity_type, entity_id, operation, payload, status, retry_count, 
		       max_retries, error_message, created_at, processed_at, synced_at
		FROM sync_queue
		WHERE status = 'failed'
		ORDER BY created_at DESC
	`

	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed to query failed sync: %w", err)
	}
	defer rows.Close()

	var items []models.SyncQueue
	for rows.Next() {
		var item models.SyncQueue
		var processedAt, syncedAt sql.NullTime

		err := rows.Scan(
			&item.ID, &item.EntityType, &item.EntityID, &item.Operation, &item.Payload,
			&item.Status, &item.RetryCount, &item.MaxRetries, &item.ErrorMessage,
			&item.CreatedAt, &processedAt, &syncedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan sync queue: %w", err)
		}

		if processedAt.Valid {
			item.ProcessedAt = &processedAt.Time
		}
		if syncedAt.Valid {
			item.SyncedAt = &syncedAt.Time
		}

		items = append(items, item)
	}

	return items, nil
}

// DeleteSyncQueue deletes a sync queue item
func (r *syncRepositoryImpl) DeleteSyncQueue(ctx context.Context, id int64) error {
	query := `DELETE FROM sync_queue WHERE id = ?`
	_, err := r.db.ExecContext(ctx, query, id)
	return err
}

// GetOutletConfig retrieves outlet configuration
func (r *syncRepositoryImpl) GetOutletConfig(ctx context.Context) (*models.OutletConfig, error) {
	query := `
		SELECT id, outlet_id, outlet_name, outlet_code, 
		       COALESCE(outlet_address, '') as outlet_address,
		       COALESCE(outlet_phone, '') as outlet_phone,
		       COALESCE(receipt_footer, 'Terima kasih atas kunjungan Anda!') as receipt_footer,
		       COALESCE(social_media, '') as social_media,
		       COALESCE(target_spend_per_pax, 0) as target_spend_per_pax,
		       cloud_api_url, cloud_api_key,
		       is_active, sync_enabled, sync_interval_minutes, last_sync_at, created_at, updated_at
		FROM outlet_config
		LIMIT 1
	`

	var config models.OutletConfig
	var lastSyncAt sql.NullTime

	err := r.db.QueryRowContext(ctx, query).Scan(
		&config.ID, &config.OutletID, &config.OutletName, &config.OutletCode,
		&config.OutletAddress, &config.OutletPhone, &config.ReceiptFooter, &config.SocialMedia,
		&config.TargetSpendPerPax, &config.CloudAPIURL, &config.CloudAPIKey, &config.IsActive, &config.SyncEnabled,
		&config.SyncIntervalMin, &lastSyncAt, &config.CreatedAt, &config.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get outlet config: %w", err)
	}

	if lastSyncAt.Valid {
		config.LastSyncAt = &lastSyncAt.Time
	}

	return &config, nil
}

// CreateOutletConfig creates initial outlet configuration
func (r *syncRepositoryImpl) CreateOutletConfig(ctx context.Context, config *models.OutletConfig) error {
	query := `
		INSERT INTO outlet_config (
			outlet_id, outlet_name, outlet_code, outlet_address, outlet_phone,
			receipt_footer, social_media, target_spend_per_pax, cloud_api_url, cloud_api_key,
			is_active, sync_enabled, sync_interval_minutes
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`

	result, err := r.db.ExecContext(ctx, query,
		config.OutletID, config.OutletName, config.OutletCode,
		config.OutletAddress, config.OutletPhone, config.ReceiptFooter, config.SocialMedia,
		config.TargetSpendPerPax, config.CloudAPIURL, config.CloudAPIKey,
		config.IsActive, config.SyncEnabled, config.SyncIntervalMin,
	)
	if err != nil {
		return fmt.Errorf("failed to create outlet config: %w", err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return fmt.Errorf("failed to get config id: %w", err)
	}

	config.ID = id
	return nil
}

// UpdateOutletConfig updates outlet configuration
func (r *syncRepositoryImpl) UpdateOutletConfig(ctx context.Context, config *models.OutletConfig) error {
	query := `
		UPDATE outlet_config
		SET outlet_name = ?, outlet_code = ?, outlet_address = ?, outlet_phone = ?,
		    receipt_footer = ?, social_media = ?, target_spend_per_pax = ?, cloud_api_url = ?, cloud_api_key = ?,
		    sync_enabled = ?, sync_interval_minutes = ?, updated_at = CURRENT_TIMESTAMP
		WHERE id = ?
	`

	_, err := r.db.ExecContext(ctx, query,
		config.OutletName, config.OutletCode, config.OutletAddress, config.OutletPhone,
		config.ReceiptFooter, config.SocialMedia, config.TargetSpendPerPax, config.CloudAPIURL, config.CloudAPIKey,
		config.SyncEnabled, config.SyncIntervalMin, config.ID,
	)
	if err != nil {
		return fmt.Errorf("failed to update outlet config: %w", err)
	}

	return nil
}

func (r *syncRepositoryImpl) ListAdditionalCharges(ctx context.Context) ([]models.AdditionalCharge, error) {
	query := `
		SELECT id, outlet_id, name, charge_type, value, is_active, created_at, updated_at
		FROM additional_charges
		ORDER BY id DESC
	`

	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed to get additional charges: %w", err)
	}
	defer rows.Close()

	var charges []models.AdditionalCharge
	for rows.Next() {
		var charge models.AdditionalCharge
		var isActive int64
		if err := rows.Scan(
			&charge.ID,
			&charge.OutletID,
			&charge.Name,
			&charge.ChargeType,
			&charge.Value,
			&isActive,
			&charge.CreatedAt,
			&charge.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan additional charge: %w", err)
		}
		charge.IsActive = isActive == 1
		charges = append(charges, charge)
	}

	return charges, nil
}

func (r *syncRepositoryImpl) CreateAdditionalCharge(ctx context.Context, charge *models.AdditionalCharge) error {
	query := `
		INSERT INTO additional_charges (outlet_id, name, charge_type, value, is_active)
		VALUES (?, ?, ?, ?, ?)
	`

	isActive := 0
	if charge.IsActive {
		isActive = 1
	}

	result, err := r.db.ExecContext(ctx, query, charge.OutletID, charge.Name, charge.ChargeType, charge.Value, isActive)
	if err != nil {
		return fmt.Errorf("failed to create additional charge: %w", err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return fmt.Errorf("failed to get additional charge id: %w", err)
	}

	charge.ID = id
	return nil
}

func (r *syncRepositoryImpl) UpdateAdditionalCharge(ctx context.Context, charge *models.AdditionalCharge) error {
	query := `
		UPDATE additional_charges
		SET name = ?, charge_type = ?, value = ?, is_active = ?, updated_at = CURRENT_TIMESTAMP
		WHERE id = ?
	`

	isActive := 0
	if charge.IsActive {
		isActive = 1
	}

	result, err := r.db.ExecContext(ctx, query, charge.Name, charge.ChargeType, charge.Value, isActive, charge.ID)
	if err != nil {
		return fmt.Errorf("failed to update additional charge: %w", err)
	}

	affected, err := result.RowsAffected()
	if err == nil && affected == 0 {
		return sql.ErrNoRows
	}

	return nil
}

func (r *syncRepositoryImpl) DeleteAdditionalCharge(ctx context.Context, id int64) error {
	result, err := r.db.ExecContext(ctx, "DELETE FROM additional_charges WHERE id = ?", id)
	if err != nil {
		return fmt.Errorf("failed to delete additional charge: %w", err)
	}

	affected, err := result.RowsAffected()
	if err == nil && affected == 0 {
		return sql.ErrNoRows
	}

	return nil
}

func (r *syncRepositoryImpl) RefreshOpenOrderTotalsForAdditionalCharges(ctx context.Context) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}

	rows, err := tx.QueryContext(ctx, `
		SELECT id
		FROM orders
		WHERE payment_status IN ('unpaid', 'partial')
		  AND voided_at IS NULL
		  AND is_merged = 0
	`)
	if err != nil {
		_ = tx.Rollback()
		return fmt.Errorf("failed to list open orders: %w", err)
	}

	orderIDs := make([]string, 0)
	for rows.Next() {
		var orderID string
		if err := rows.Scan(&orderID); err != nil {
			rows.Close()
			_ = tx.Rollback()
			return fmt.Errorf("failed to scan open order id: %w", err)
		}
		orderIDs = append(orderIDs, orderID)
	}
	if err := rows.Err(); err != nil {
		rows.Close()
		_ = tx.Rollback()
		return fmt.Errorf("failed to iterate open orders: %w", err)
	}
	rows.Close()

	chargeRows, err := tx.QueryContext(ctx, `
		SELECT id, name, charge_type, value
		FROM additional_charges
		WHERE is_active = 1
		ORDER BY id ASC
	`)
	if err != nil {
		_ = tx.Rollback()
		return fmt.Errorf("failed to list active additional charges: %w", err)
	}

	type activeCharge struct {
		id         int64
		name       string
		chargeType string
		value      float64
	}

	charges := make([]activeCharge, 0)
	for chargeRows.Next() {
		var charge activeCharge
		if err := chargeRows.Scan(&charge.id, &charge.name, &charge.chargeType, &charge.value); err != nil {
			chargeRows.Close()
			_ = tx.Rollback()
			return fmt.Errorf("failed to scan active additional charge: %w", err)
		}
		charges = append(charges, charge)
	}
	if err := chargeRows.Err(); err != nil {
		chargeRows.Close()
		_ = tx.Rollback()
		return fmt.Errorf("failed to iterate active additional charges: %w", err)
	}
	chargeRows.Close()

	for _, orderID := range orderIDs {
		var subtotal float64
		if err := tx.QueryRowContext(ctx, `
			SELECT COALESCE(SUM(price * qty), 0)
			FROM order_items
			WHERE order_id = ?
		`, orderID).Scan(&subtotal); err != nil {
			_ = tx.Rollback()
			return fmt.Errorf("failed to calculate subtotal for order %s: %w", orderID, err)
		}

		var basketSize int64
		if err := tx.QueryRowContext(ctx, `
			SELECT COUNT(*)
			FROM order_items
			WHERE order_id = ?
		`, orderID).Scan(&basketSize); err != nil {
			_ = tx.Rollback()
			return fmt.Errorf("failed to calculate basket size for order %s: %w", orderID, err)
		}

		if _, err := tx.ExecContext(ctx, `
			DELETE FROM order_additional_charges
			WHERE order_id = ?
			  AND charge_id IS NOT NULL
		`, orderID); err != nil {
			_ = tx.Rollback()
			return fmt.Errorf("failed to reset additional charges for order %s: %w", orderID, err)
		}

		chargesTotal := 0.0
		for _, charge := range charges {
			applied := 0.0
			if subtotal > 0 {
				if charge.chargeType == "percentage" {
					applied = subtotal * charge.value / 100
				} else {
					applied = charge.value
				}
			}

			if applied == 0 {
				continue
			}

			if _, err := tx.ExecContext(ctx, `
				INSERT INTO order_additional_charges (
					order_id,
					charge_id,
					name,
					charge_type,
					value,
					applied_amount,
					created_at,
					updated_at
				) VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
			`, orderID, charge.id, charge.name, charge.chargeType, charge.value, applied); err != nil {
				_ = tx.Rollback()
				return fmt.Errorf("failed to insert additional charge for order %s: %w", orderID, err)
			}

			chargesTotal += applied
		}

		var manualTotal float64
		if err := tx.QueryRowContext(ctx, `
			SELECT COALESCE(SUM(applied_amount), 0)
			FROM order_additional_charges
			WHERE order_id = ?
			  AND charge_id IS NULL
		`, orderID).Scan(&manualTotal); err != nil {
			_ = tx.Rollback()
			return fmt.Errorf("failed to calculate manual adjustments for order %s: %w", orderID, err)
		}

		totalAmount := subtotal + chargesTotal + manualTotal
		if totalAmount < 0 {
			totalAmount = 0
		}
		if _, err := tx.ExecContext(ctx, `
			UPDATE orders
			SET total_amount = ?, basket_size = ?, updated_at = CURRENT_TIMESTAMP
			WHERE id = ?
		`, totalAmount, basketSize, orderID); err != nil {
			_ = tx.Rollback()
			return fmt.Errorf("failed to update order total for order %s: %w", orderID, err)
		}
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit total refresh: %w", err)
	}

	return nil
}

// UpdateLastSync updates last sync timestamp
func (r *syncRepositoryImpl) UpdateLastSync(ctx context.Context) error {
	query := `UPDATE outlet_config SET last_sync_at = CURRENT_TIMESTAMP WHERE id = 1`
	_, err := r.db.ExecContext(ctx, query)
	return err
}

// GetEntityVersion retrieves entity version info
func (r *syncRepositoryImpl) GetEntityVersion(ctx context.Context, entityType, entityID string) (*models.EntityVersion, error) {
	query := `
		SELECT id, entity_type, entity_id, version, cloud_version, 
		       last_modified_at, last_synced_at, sync_status
		FROM entity_versions
		WHERE entity_type = ? AND entity_id = ?
	`

	var ev models.EntityVersion
	var lastSyncedAt sql.NullTime

	err := r.db.QueryRowContext(ctx, query, entityType, entityID).Scan(
		&ev.ID, &ev.EntityType, &ev.EntityID, &ev.Version, &ev.CloudVersion,
		&ev.LastModifiedAt, &lastSyncedAt, &ev.SyncStatus,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get entity version: %w", err)
	}

	if lastSyncedAt.Valid {
		ev.LastSyncedAt = &lastSyncedAt.Time
	}

	return &ev, nil
}

// UpdateEntityVersion updates entity version
func (r *syncRepositoryImpl) UpdateEntityVersion(ctx context.Context, entityType, entityID string, version, cloudVersion int) error {
	query := `
		INSERT INTO entity_versions (entity_type, entity_id, version, cloud_version, last_modified_at, sync_status)
		VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP, 'pending')
		ON CONFLICT(entity_type, entity_id) DO UPDATE SET
			version = excluded.version,
			cloud_version = excluded.cloud_version,
			last_modified_at = CURRENT_TIMESTAMP,
			sync_status = 'pending'
	`

	_, err := r.db.ExecContext(ctx, query, entityType, entityID, version, cloudVersion)
	if err != nil {
		return fmt.Errorf("failed to update entity version: %w", err)
	}

	return nil
}

// MarkEntitySynced marks entity as synced
func (r *syncRepositoryImpl) MarkEntitySynced(ctx context.Context, entityType, entityID string, cloudVersion int) error {
	query := `
		UPDATE entity_versions
		SET sync_status = 'synced',
		    cloud_version = ?,
		    last_synced_at = CURRENT_TIMESTAMP
		WHERE entity_type = ? AND entity_id = ?
	`

	_, err := r.db.ExecContext(ctx, query, cloudVersion, entityType, entityID)
	if err != nil {
		return fmt.Errorf("failed to mark entity synced: %w", err)
	}

	return nil
}

// CreateSyncLog creates a new sync log entry
func (r *syncRepositoryImpl) CreateSyncLog(ctx context.Context, log *models.SyncLog) (int64, error) {
	query := `
		INSERT INTO sync_logs (sync_type, entity_type, entity_count, status, error_message, started_at, details)
		VALUES (?, ?, ?, ?, ?, ?, ?)
	`

	result, err := r.db.ExecContext(ctx, query,
		log.SyncType, log.EntityType, log.EntityCount, log.Status,
		log.ErrorMessage, log.StartedAt, log.Details,
	)
	if err != nil {
		return 0, fmt.Errorf("failed to create sync log: %w", err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return 0, fmt.Errorf("failed to get log id: %w", err)
	}

	return id, nil
}

// UpdateSyncLog updates sync log with completion info
func (r *syncRepositoryImpl) UpdateSyncLog(ctx context.Context, id int64, status string, entityCount int, errMsg string, durationMs int64) error {
	query := `
		UPDATE sync_logs
		SET status = ?, entity_count = ?, error_message = ?, completed_at = CURRENT_TIMESTAMP, duration_ms = ?
		WHERE id = ?
	`

	_, err := r.db.ExecContext(ctx, query, status, entityCount, errMsg, durationMs, id)
	if err != nil {
		return fmt.Errorf("failed to update sync log: %w", err)
	}

	return nil
}

// GetSyncLogs retrieves recent sync logs
func (r *syncRepositoryImpl) GetSyncLogs(ctx context.Context, limit int) ([]models.SyncLog, error) {
	query := `
		SELECT id, sync_type, entity_type, entity_count, status, error_message,
		       started_at, completed_at, duration_ms, details
		FROM sync_logs
		ORDER BY started_at DESC
		LIMIT ?
	`

	rows, err := r.db.QueryContext(ctx, query, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to query sync logs: %w", err)
	}
	defer rows.Close()

	var logs []models.SyncLog
	for rows.Next() {
		var log models.SyncLog
		var completedAt sql.NullTime

		err := rows.Scan(
			&log.ID, &log.SyncType, &log.EntityType, &log.EntityCount,
			&log.Status, &log.ErrorMessage, &log.StartedAt, &completedAt,
			&log.DurationMs, &log.Details,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan sync log: %w", err)
		}

		if completedAt.Valid {
			log.CompletedAt = &completedAt.Time
		}

		logs = append(logs, log)
	}

	return logs, nil
}

// GetSyncStatus retrieves current sync status
func (r *syncRepositoryImpl) GetSyncStatus(ctx context.Context) (*models.SyncStatus, error) {
	config, err := r.GetOutletConfig(ctx)
	if err != nil || config == nil {
		return nil, err
	}

	// Count pending
	var pendingCount int64
	err = r.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM sync_queue WHERE status = 'pending'").Scan(&pendingCount)
	if err != nil {
		return nil, err
	}

	// Count failed
	var failedCount int64
	err = r.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM sync_queue WHERE status = 'failed'").Scan(&failedCount)
	if err != nil {
		return nil, err
	}

	// Count conflicts
	var conflictCount int64
	err = r.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM entity_versions WHERE sync_status = 'conflict'").Scan(&conflictCount)
	if err != nil {
		return nil, err
	}

	// Count synced
	var syncedCount int64
	err = r.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM sync_queue WHERE status = 'success'").Scan(&syncedCount)
	if err != nil {
		return nil, err
	}

	// Get last error
	var lastError sql.NullString
	r.db.QueryRowContext(ctx, `
		SELECT error_message FROM sync_queue 
		WHERE status = 'failed' AND error_message IS NOT NULL 
		ORDER BY created_at DESC LIMIT 1
	`).Scan(&lastError)

	status := &models.SyncStatus{
		OutletID:      config.OutletID,
		OutletCode:    config.OutletCode,
		SyncEnabled:   config.SyncEnabled,
		LastSyncAt:    config.LastSyncAt,
		PendingCount:  pendingCount,
		FailedCount:   failedCount,
		ConflictCount: conflictCount,
		TotalSynced:   syncedCount,
	}

	if lastError.Valid {
		status.LastError = lastError.String
	}

	return status, nil
}
