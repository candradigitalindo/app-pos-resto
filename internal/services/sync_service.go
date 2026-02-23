package services

import (
	"backend/internal/models"
	"backend/internal/repositories"
	"backend/pkg/cloudapi"
	"backend/pkg/utils"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"strconv"
	"time"
)

type SyncService interface {
	// Push operations
	PushPendingData(ctx context.Context) error
	PushEntity(ctx context.Context, entityType, entityID string, data interface{}) error

	// Pull operations
	PullUpdates(ctx context.Context, since time.Time) error
	ProcessCloudUpdate(ctx context.Context, data map[string]interface{}) error
	ProcessCloudDelete(ctx context.Context, data map[string]interface{}) error

	// Status operations
	GetSyncStatus(ctx context.Context) (*models.SyncStatus, error)
	GetSyncLogs(ctx context.Context, limit int) ([]models.SyncLog, error)
	GetFailedSync(ctx context.Context) ([]models.SyncQueue, error)

	// Manual sync
	TriggerSync(ctx context.Context) error
	RetryFailed(ctx context.Context, queueID int64) error

	// Conflict resolution
	ResolveConflict(ctx context.Context, entityType, entityID, strategy string) error
}

type syncService struct {
	syncRepo    repositories.SyncRepository
	cloudClient *cloudapi.Client
	db          *sql.DB
}

func NewSyncService(syncRepo repositories.SyncRepository, cloudClient *cloudapi.Client, db *sql.DB) SyncService {
	return &syncService{
		syncRepo:    syncRepo,
		cloudClient: cloudClient,
		db:          db,
	}
}

// PushPendingData pushes all pending sync items to cloud
func (s *syncService) PushPendingData(ctx context.Context) error {
	startTime := time.Now()

	// Create sync log
	syncLog := &models.SyncLog{
		SyncType:    "push",
		EntityType:  "mixed",
		EntityCount: 0,
		Status:      "success",
		StartedAt:   startTime,
	}

	logID, err := s.syncRepo.CreateSyncLog(ctx, syncLog)
	if err != nil {
		log.Printf("Failed to create sync log: %v", err)
	}

	// Get pending items
	pendingItems, err := s.syncRepo.GetPendingSync(ctx, 100) // Batch of 100
	if err != nil {
		errMsg := fmt.Sprintf("Failed to get pending sync: %v", err)
		if logID > 0 {
			s.syncRepo.UpdateSyncLog(ctx, logID, "failed", 0, errMsg, time.Since(startTime).Milliseconds())
		}
		return fmt.Errorf("%s", errMsg)
	}

	if len(pendingItems) == 0 {
		log.Println("No pending sync items")
		if logID > 0 {
			s.syncRepo.UpdateSyncLog(ctx, logID, "success", 0, "", time.Since(startTime).Milliseconds())
		}
		return nil
	}

	log.Printf("Processing %d pending sync items", len(pendingItems))

	// Convert to cloud sync items
	var cloudItems []models.CloudSyncItem
	itemMap := make(map[int64]models.SyncQueue) // Map queue ID to item for later update

	for _, item := range pendingItems {
		// Mark as processing
		if err := s.syncRepo.MarkSyncProcessing(ctx, item.ID); err != nil {
			log.Printf("Failed to mark item %d as processing: %v", item.ID, err)
			continue
		}

		// Parse payload
		var data map[string]interface{}
		if err := json.Unmarshal([]byte(item.Payload), &data); err != nil {
			log.Printf("Failed to unmarshal payload for item %d: %v", item.ID, err)
			s.syncRepo.MarkSyncFailed(ctx, item.ID, fmt.Sprintf("Invalid payload: %v", err))
			continue
		}

		cloudItems = append(cloudItems, models.CloudSyncItem{
			EntityType: item.EntityType,
			Operation:  item.Operation,
			Data:       data,
		})

		itemMap[item.ID] = item
	}

	if len(cloudItems) == 0 {
		log.Println("No valid items to sync")
		if logID > 0 {
			s.syncRepo.UpdateSyncLog(ctx, logID, "failed", 0, "No valid items", time.Since(startTime).Milliseconds())
		}
		return nil
	}

	// Push to cloud
	log.Printf("Pushing %d items to cloud", len(cloudItems))
	cloudResp, err := s.cloudClient.PushBatch(ctx, cloudItems)
	if err != nil {
		errMsg := fmt.Sprintf("Failed to push to cloud: %v", err)
		log.Println(errMsg)

		// Mark all as failed
		for id := range itemMap {
			s.syncRepo.MarkSyncFailed(ctx, id, errMsg)
		}

		if logID > 0 {
			s.syncRepo.UpdateSyncLog(ctx, logID, "failed", len(cloudItems), errMsg, time.Since(startTime).Milliseconds())
		}

		return fmt.Errorf("%s", errMsg)
	}

	// Process results
	successCount := 0
	failedCount := 0

	for _, result := range cloudResp.Data.Results {
		// Find corresponding queue item
		var queueID int64
		for id, item := range itemMap {
			var data map[string]interface{}
			json.Unmarshal([]byte(item.Payload), &data)
			if localID, ok := data["id"].(string); ok && localID == result.LocalID {
				queueID = id
				break
			}
		}

		if queueID == 0 {
			log.Printf("Could not find queue item for local_id: %s", result.LocalID)
			continue
		}

		if result.Status == "success" {
			// Mark as synced
			if err := s.syncRepo.MarkSyncSuccess(ctx, queueID, result.CloudID); err != nil {
				log.Printf("Failed to mark sync success for queue %d: %v", queueID, err)
			}

			// Update entity version if exists
			item := itemMap[queueID]
			s.syncRepo.MarkEntitySynced(ctx, item.EntityType, item.EntityID, 1)

			successCount++
		} else {
			// Mark as failed
			if err := s.syncRepo.MarkSyncFailed(ctx, queueID, result.Error); err != nil {
				log.Printf("Failed to mark sync failed for queue %d: %v", queueID, err)
			}
			failedCount++
		}
	}

	log.Printf("Sync completed: %d success, %d failed", successCount, failedCount)

	// Update last sync timestamp
	s.syncRepo.UpdateLastSync(ctx)

	// Update sync log
	status := "success"
	if failedCount > 0 {
		if successCount > 0 {
			status = "partial"
		} else {
			status = "failed"
		}
	}

	if logID > 0 {
		s.syncRepo.UpdateSyncLog(ctx, logID, status, successCount, "", time.Since(startTime).Milliseconds())
	}

	return nil
}

// PushEntity pushes a single entity to cloud
func (s *syncService) PushEntity(ctx context.Context, entityType, entityID string, data interface{}) error {
	// Queue the sync
	if err := s.syncRepo.EnqueueSync(ctx, entityType, entityID, "create", data); err != nil {
		return fmt.Errorf("failed to enqueue sync: %w", err)
	}

	// Immediately try to push
	return s.PushPendingData(ctx)
}

// PullUpdates pulls updates from cloud
func (s *syncService) PullUpdates(ctx context.Context, since time.Time) error {
	log.Printf("Pulling updates from cloud since %v", since)

	// Get updates from cloud
	updates, err := s.cloudClient.GetUpdates(ctx, since)
	if err != nil {
		log.Printf("Failed to get updates from cloud: %v", err)
		return err
	}

	// Check if there are updates
	if updates == nil || updates["success"] == false {
		log.Println("No updates from cloud")
		return nil
	}

	data, ok := updates["data"].(map[string]interface{})
	if !ok {
		log.Println("Invalid update data format")
		return nil
	}

	processedCount := 0

	if items, ok := data["items"].([]interface{}); ok && len(items) > 0 {
		log.Printf("Processing %d updates from cloud", len(items))
		for _, item := range items {
			itemData, ok := item.(map[string]interface{})
			if !ok {
				continue
			}

			if err := s.ProcessCloudUpdate(ctx, itemData); err != nil {
				log.Printf("Error processing cloud update: %v", err)
				continue
			}
			processedCount++
		}
	}

	if products, ok := data["products"].([]interface{}); ok && len(products) > 0 {
		log.Printf("Processing %d product updates", len(products))
		for _, item := range products {
			itemData, ok := item.(map[string]interface{})
			if !ok {
				continue
			}
			if err := s.upsertProductFromCloud(ctx, itemData); err != nil {
				log.Printf("Error processing product update: %v", err)
				continue
			}
			processedCount++
		}
	}

	if categories, ok := data["categories"].([]interface{}); ok && len(categories) > 0 {
		log.Printf("Processing %d category updates", len(categories))
		for _, item := range categories {
			itemData, ok := item.(map[string]interface{})
			if !ok {
				continue
			}
			if err := s.upsertCategoryFromCloud(ctx, itemData); err != nil {
				log.Printf("Error processing category update: %v", err)
				continue
			}
			processedCount++
		}
	}

	if deleted, ok := data["deleted"].([]interface{}); ok && len(deleted) > 0 {
		log.Printf("Processing %d deletions", len(deleted))
		for _, item := range deleted {
			itemData, ok := item.(map[string]interface{})
			if !ok {
				continue
			}
			if err := s.ProcessCloudDelete(ctx, itemData); err != nil {
				log.Printf("Error processing cloud delete: %v", err)
				continue
			}
			processedCount++
		}
	}

	if processedCount == 0 {
		log.Println("No updates from cloud")
		return nil
	}

	if err := s.syncRepo.UpdateLastSync(ctx); err != nil {
		log.Printf("Failed to update last sync time: %v", err)
	}

	return nil
}

// GetSyncStatus returns current sync status
func (s *syncService) GetSyncStatus(ctx context.Context) (*models.SyncStatus, error) {
	return s.syncRepo.GetSyncStatus(ctx)
}

// GetSyncLogs returns recent sync logs
func (s *syncService) GetSyncLogs(ctx context.Context, limit int) ([]models.SyncLog, error) {
	return s.syncRepo.GetSyncLogs(ctx, limit)
}

// GetFailedSync returns all failed sync items
func (s *syncService) GetFailedSync(ctx context.Context) ([]models.SyncQueue, error) {
	return s.syncRepo.GetFailedSync(ctx)
}

// TriggerSync manually triggers a sync
func (s *syncService) TriggerSync(ctx context.Context) error {
	log.Println("Manual sync triggered")
	return s.PushPendingData(ctx)
}

// RetryFailed retries a specific failed sync item
func (s *syncService) RetryFailed(ctx context.Context, queueID int64) error {
	// Get pending items to find the specific one
	items, err := s.syncRepo.GetFailedSync(ctx)
	if err != nil {
		return fmt.Errorf("failed to get failed sync: %w", err)
	}

	var targetItem *models.SyncQueue
	for _, item := range items {
		if item.ID == queueID {
			targetItem = &item
			break
		}
	}

	if targetItem == nil {
		return fmt.Errorf("sync queue item %d not found", queueID)
	}

	log.Printf("Retrying sync for queue item %d (entity: %s/%s)", queueID, targetItem.EntityType, targetItem.EntityID)

	// Trigger immediate sync (item will be picked up as it's in failed state)
	return s.PushPendingData(ctx)
}

// ProcessCloudUpdate processes an update from cloud
func (s *syncService) ProcessCloudUpdate(ctx context.Context, data map[string]interface{}) error {
	entityType, _ := data["entity_type"].(string)
	cloudID, _ := data["cloud_id"].(string)
	localID, _ := data["local_id"].(string)
	operation, _ := data["operation"].(string)

	log.Printf("Processing cloud update: type=%s, cloud_id=%s, local_id=%s, op=%s",
		entityType, cloudID, localID, operation)

	merged := s.mergeCloudPayload(data)
	if _, ok := merged["cloud_id"]; !ok && cloudID != "" {
		merged["cloud_id"] = cloudID
	}
	if _, ok := merged["local_id"]; !ok && localID != "" {
		merged["local_id"] = localID
	}

	switch entityType {
	case "product":
		return s.upsertProductFromCloud(ctx, merged)
	case "category":
		return s.upsertCategoryFromCloud(ctx, merged)
	default:
		log.Printf("Cloud update ignored: type=%s op=%s", entityType, operation)
	}

	return nil
}

// ProcessCloudDelete processes a delete from cloud
func (s *syncService) ProcessCloudDelete(ctx context.Context, data map[string]interface{}) error {
	entityType, _ := data["entity_type"].(string)
	cloudID, _ := data["cloud_id"].(string)
	localID, _ := data["local_id"].(string)

	log.Printf("Processing cloud delete: type=%s, cloud_id=%s, local_id=%s",
		entityType, cloudID, localID)

	switch entityType {
	case "product":
		return s.deleteByCloudRef(ctx, "products", localID, cloudID)
	case "category":
		return s.deleteByCloudRef(ctx, "categories", localID, cloudID)
	default:
		log.Printf("Cloud delete ignored: type=%s", entityType)
	}

	return nil
}

func (s *syncService) upsertCategoryFromCloud(ctx context.Context, data map[string]interface{}) error {
	cloudID := getString(data, "cloud_id")
	localID := getString(data, "local_id")
	if localID == "" {
		localID = getString(data, "id")
	}

	name := getString(data, "name")
	if name == "" {
		return fmt.Errorf("category name is required")
	}

	description := getString(data, "description")
	printerID := getString(data, "printer_id")
	version := getInt64(data, "version")

	if cloudID != "" {
		existingID, err := s.findLocalIDByCloudID(ctx, "categories", cloudID)
		if err != nil {
			return err
		}
		if existingID != "" {
			localID = existingID
		}
	}

	if localID == "" {
		localID = utils.GenerateULID()
	}

	exists, err := s.entityExists(ctx, "categories", localID)
	if err != nil {
		return err
	}

	nullDesc := toNullString(description)
	nullPrinterID := toNullString(printerID)
	nullCloudID := toNullString(cloudID)

	if exists {
		_, err = s.db.ExecContext(ctx, `
			UPDATE categories
			SET name = ?, description = ?, printer_id = ?, cloud_id = COALESCE(?, cloud_id),
			    version = COALESCE(?, version), sync_status = 'synced', last_synced_at = CURRENT_TIMESTAMP
			WHERE id = ?
		`, name, nullDesc, nullPrinterID, nullCloudID, nullableInt64(version), localID)
		return err
	}

	_, err = s.db.ExecContext(ctx, `
		INSERT INTO categories (id, name, description, printer_id, cloud_id, version, sync_status, last_synced_at, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, 'synced', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
	`, localID, name, nullDesc, nullPrinterID, nullCloudID, nullableInt64(version))
	return err
}

func (s *syncService) upsertProductFromCloud(ctx context.Context, data map[string]interface{}) error {
	cloudID := getString(data, "cloud_id")
	localID := getString(data, "local_id")
	if localID == "" {
		localID = getString(data, "id")
	}

	name := getString(data, "name")
	if name == "" {
		return fmt.Errorf("product name is required")
	}

	code := getString(data, "code")
	description := getString(data, "description")
	price := getFloat64(data, "price")
	stock := getInt64(data, "stock")
	categoryID := getString(data, "category_id")
	if categoryID == "" {
		categoryID = getString(data, "category_cloud_id")
	}
	if categoryID != "" {
		if mappedID, err := s.findLocalIDByCloudID(ctx, "categories", categoryID); err == nil && mappedID != "" {
			categoryID = mappedID
		}
	}
	version := getInt64(data, "version")

	if cloudID != "" {
		existingID, err := s.findLocalIDByCloudID(ctx, "products", cloudID)
		if err != nil {
			return err
		}
		if existingID != "" {
			localID = existingID
		}
	}

	if localID == "" {
		localID = utils.GenerateULID()
	}

	exists, err := s.entityExists(ctx, "products", localID)
	if err != nil {
		return err
	}

	nullCode := toNullString(code)
	nullDesc := toNullString(description)
	nullCategoryID := toNullString(categoryID)
	nullCloudID := toNullString(cloudID)

	if exists {
		_, err = s.db.ExecContext(ctx, `
			UPDATE products
			SET name = ?, code = ?, description = ?, price = ?, stock = ?, category_id = ?,
			    cloud_id = COALESCE(?, cloud_id), version = COALESCE(?, version),
			    sync_status = 'synced', last_synced_at = CURRENT_TIMESTAMP
			WHERE id = ?
		`, name, nullCode, nullDesc, price, stock, nullCategoryID, nullCloudID, nullableInt64(version), localID)
		return err
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO products (id, name, code, description, price, stock, category_id, cloud_id, version, sync_status, last_synced_at, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'synced', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
	`, localID, name, nullCode, nullDesc, price, stock, nullCategoryID, nullCloudID, nullableInt64(version))
	if err != nil {
		tx.Rollback()
		return err
	}

	_, err = tx.ExecContext(ctx, `
		DELETE FROM sync_queue
		WHERE entity_type = 'product' AND entity_id = ? AND status = 'pending'
	`, localID)
	if err != nil {
		tx.Rollback()
		return err
	}

	if err := tx.Commit(); err != nil {
		return err
	}

	return nil
}

func (s *syncService) deleteByCloudRef(ctx context.Context, table, localID, cloudID string) error {
	if localID == "" && cloudID != "" {
		foundID, err := s.findLocalIDByCloudID(ctx, table, cloudID)
		if err != nil {
			return err
		}
		localID = foundID
	}

	if localID == "" {
		return nil
	}

	_, err := s.db.ExecContext(ctx, fmt.Sprintf("DELETE FROM %s WHERE id = ?", table), localID)
	return err
}

func (s *syncService) findLocalIDByCloudID(ctx context.Context, table, cloudID string) (string, error) {
	if cloudID == "" {
		return "", nil
	}

	if table != "products" && table != "categories" {
		return "", fmt.Errorf("unsupported table: %s", table)
	}

	var id string
	err := s.db.QueryRowContext(ctx, fmt.Sprintf("SELECT id FROM %s WHERE cloud_id = ? LIMIT 1", table), cloudID).Scan(&id)
	if err == sql.ErrNoRows {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	return id, nil
}

func (s *syncService) entityExists(ctx context.Context, table, id string) (bool, error) {
	if id == "" {
		return false, nil
	}
	if table != "products" && table != "categories" {
		return false, fmt.Errorf("unsupported table: %s", table)
	}

	var exists int
	err := s.db.QueryRowContext(ctx, fmt.Sprintf("SELECT 1 FROM %s WHERE id = ? LIMIT 1", table), id).Scan(&exists)
	if err == sql.ErrNoRows {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, nil
}

func (s *syncService) mergeCloudPayload(data map[string]interface{}) map[string]interface{} {
	if inner, ok := data["data"].(map[string]interface{}); ok {
		merged := map[string]interface{}{}
		for key, value := range inner {
			merged[key] = value
		}
		if _, ok := merged["cloud_id"]; !ok {
			if value, ok := data["cloud_id"]; ok {
				merged["cloud_id"] = value
			}
		}
		if _, ok := merged["local_id"]; !ok {
			if value, ok := data["local_id"]; ok {
				merged["local_id"] = value
			}
		}
		if _, ok := merged["version"]; !ok {
			if value, ok := data["version"]; ok {
				merged["version"] = value
			}
		}
		return merged
	}

	merged := map[string]interface{}{}
	for key, value := range data {
		merged[key] = value
	}
	return merged
}

func getString(data map[string]interface{}, key string) string {
	if value, ok := data[key]; ok {
		switch v := value.(type) {
		case string:
			return v
		case []byte:
			return string(v)
		case float64:
			if v == float64(int64(v)) {
				return strconv.FormatInt(int64(v), 10)
			}
			return strconv.FormatFloat(v, 'f', -1, 64)
		}
	}
	return ""
}

func getFloat64(data map[string]interface{}, key string) float64 {
	if value, ok := data[key]; ok {
		switch v := value.(type) {
		case float64:
			return v
		case int64:
			return float64(v)
		case int:
			return float64(v)
		case string:
			parsed, _ := strconv.ParseFloat(v, 64)
			return parsed
		}
	}
	return 0
}

func getInt64(data map[string]interface{}, key string) int64 {
	if value, ok := data[key]; ok {
		switch v := value.(type) {
		case int64:
			return v
		case int:
			return int64(v)
		case float64:
			return int64(v)
		case string:
			parsed, _ := strconv.ParseInt(v, 10, 64)
			return parsed
		}
	}
	return 0
}

func toNullString(value string) sql.NullString {
	return sql.NullString{String: value, Valid: value != ""}
}

func nullableInt64(value int64) interface{} {
	if value == 0 {
		return nil
	}
	return value
}

// ResolveConflict resolves a sync conflict
func (s *syncService) ResolveConflict(ctx context.Context, entityType, entityID, strategy string) error {
	log.Printf("Resolving conflict: type=%s, id=%s, strategy=%s", entityType, entityID, strategy)

	// Get entity version
	version, err := s.syncRepo.GetEntityVersion(ctx, entityType, entityID)
	if err != nil {
		return fmt.Errorf("failed to get entity version: %w", err)
	}

	if version.SyncStatus != "conflict" {
		return fmt.Errorf("entity is not in conflict state")
	}

	// Apply conflict resolution strategy
	switch strategy {
	case "cloud_wins":
		// Pull latest from cloud and overwrite local
		log.Printf("Applying cloud_wins strategy")
		// TODO: Implement cloud_wins logic

	case "local_wins":
		// Push local data to cloud and overwrite cloud
		log.Printf("Applying local_wins strategy")
		// TODO: Implement local_wins logic

	case "newest_wins":
		// Compare timestamps and keep the newest
		log.Printf("Applying newest_wins strategy")
		// TODO: Implement newest_wins logic

	default:
		return fmt.Errorf("unknown conflict resolution strategy: %s", strategy)
	}

	// Update sync status
	if err := s.syncRepo.MarkEntitySynced(ctx, entityType, entityID, version.CloudVersion); err != nil {
		return fmt.Errorf("failed to update sync status: %w", err)
	}

	log.Printf("Conflict resolved successfully")
	return nil
}
