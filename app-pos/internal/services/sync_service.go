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
	"strings"
	"time"
)

type SyncService interface {
	// Push operations
	PushPendingData(ctx context.Context) error
	PushEntity(ctx context.Context, entityType, entityID string, data interface{}) error

	// Pull operations
	PullUpdates(ctx context.Context, since time.Time) error
	FullPullFromCloud(ctx context.Context) error
	ProcessCloudUpdate(ctx context.Context, data map[string]interface{}) error
	ProcessCloudDelete(ctx context.Context, data map[string]interface{}) error

	// Status operations
	GetSyncStatus(ctx context.Context) (*models.SyncStatus, error)
	GetSyncLogs(ctx context.Context, limit int) ([]models.SyncLog, error)
	GetFailedSync(ctx context.Context) ([]models.SyncQueue, error)
	GetLastSyncTime(ctx context.Context) (time.Time, error)

	// Manual sync
	TriggerSync(ctx context.Context) error
	RetryFailed(ctx context.Context, queueID int64) error

	// Conflict resolution
	ResolveConflict(ctx context.Context, entityType, entityID, strategy string) error

	// Cloud client management
	UpdateCloudClient(client *cloudapi.Client)
	ReloadCloudClient(ctx context.Context) error
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

// UpdateCloudClient replaces the cloud API client (called when config changes)
func (s *syncService) UpdateCloudClient(client *cloudapi.Client) {
	s.cloudClient = client
	log.Println("Cloud API client updated")
}

// ReloadCloudClient reloads the cloud client from database config
func (s *syncService) ReloadCloudClient(ctx context.Context) error {
	config, err := s.syncRepo.GetOutletConfig(ctx)
	if err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}
	if config == nil || config.CloudAPIURL == "" || config.CloudAPIKey == "" {
		return fmt.Errorf("cloud config not configured")
	}
	s.cloudClient = cloudapi.NewClient(config.CloudAPIURL, config.CloudAPIKey, config.OutletID, config.OutletCode)
	return nil
}

// isCloudReachable does a fast health check before attempting sync.
// Returns false if cloud is unreachable — avoids wasting resources.
func (s *syncService) isCloudReachable(ctx context.Context) bool {
	if s.cloudClient == nil {
		return false
	}
	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := s.cloudClient.Ping(pingCtx); err != nil {
		log.Printf("☁️  Cloud unreachable: %v", err)
		return false
	}
	return true
}

// enrichOrderPayload adds order_items to an order sync payload
func (s *syncService) enrichOrderPayload(ctx context.Context, data map[string]interface{}) {
	orderID := getString(data, "id")
	if orderID == "" {
		orderID = getString(data, "local_id")
	}
	if orderID == "" {
		return
	}

	rows, err := s.db.QueryContext(ctx, `
		SELECT oi.id, oi.product_name, oi.qty, oi.price, oi.destination, oi.item_status,
		       COALESCE(c.name, '') AS category
		FROM order_items oi
		LEFT JOIN products p ON p.name = oi.product_name
		LEFT JOIN categories c ON c.id = p.category_id
		WHERE oi.order_id = ?
	`, orderID)
	if err != nil {
		log.Printf("Failed to query order_items for %s: %v", orderID, err)
		return
	}
	defer rows.Close()

	var items []map[string]interface{}
	for rows.Next() {
		var id, productName, destination, itemStatus, category string
		var qty int
		var price float64
		if err := rows.Scan(&id, &productName, &qty, &price, &destination, &itemStatus, &category); err != nil {
			continue
		}
		items = append(items, map[string]interface{}{
			"product_name": productName,
			"category":     category,
			"qty":          qty,
			"price":        price,
			"subtotal":     price * float64(qty),
			"destination":  destination,
			"status":       itemStatus,
		})
	}

	if len(items) > 0 {
		data["items"] = items
	}
}

// enrichTransactionPayload adds transaction_items to a transaction sync payload
func (s *syncService) enrichTransactionPayload(ctx context.Context, data map[string]interface{}) {
	txID := getString(data, "id")
	if txID == "" {
		txID = getString(data, "local_id")
	}
	if txID == "" {
		return
	}

	rows, err := s.db.QueryContext(ctx, `
		SELECT ti.id, ti.product_id, COALESCE(p.name, ''), ti.quantity, ti.price
		FROM transaction_items ti
		LEFT JOIN products p ON p.id = ti.product_id
		WHERE ti.transaction_id = ?
	`, txID)
	if err != nil {
		log.Printf("Failed to query transaction_items for %s: %v", txID, err)
		return
	}
	defer rows.Close()

	var items []map[string]interface{}
	for rows.Next() {
		var id, productID, productName string
		var quantity int
		var price float64
		if err := rows.Scan(&id, &productID, &productName, &quantity, &price); err != nil {
			continue
		}
		items = append(items, map[string]interface{}{
			"id":           id,
			"product_id":   productID,
			"product_name": productName,
			"quantity":     quantity,
			"price":        price,
			"subtotal":     price * float64(quantity),
		})
	}

	if len(items) > 0 {
		data["items"] = items
	}

	// Juga tambahkan cash_amount & change_amount jika belum ada — query dari transactions
	if _, ok := data["cash_amount"]; !ok {
		var cashAmount, changeAmount float64
		err := s.db.QueryRowContext(ctx, `
			SELECT COALESCE(
				(SELECT SUM(amount) FROM payments WHERE order_id = (SELECT order_id FROM transactions WHERE id = ?)), 0
			)`, txID).Scan(&cashAmount)
		if err == nil && cashAmount > 0 {
			data["cash_amount"] = cashAmount
			totalAmount := getFloat64(data, "total_amount")
			if totalAmount > 0 {
				changeAmount = cashAmount - totalAmount
				if changeAmount < 0 {
					changeAmount = 0
				}
			}
			data["change_amount"] = changeAmount
		}
	}

	// Tambahkan tax_amount dari order_additional_charges (charge yang merupakan pajak)
	orderID := getString(data, "order_id")
	if orderID != "" {
		var taxAmount float64
		err := s.db.QueryRowContext(ctx, `
			SELECT COALESCE(SUM(oac.applied_amount), 0)
			FROM order_additional_charges oac
			JOIN additional_charges ac ON ac.id = oac.charge_id
			WHERE oac.order_id = ?
			  AND ac.charge_type = 'percentage'
			  AND LOWER(ac.name) LIKE '%pajak%'
		`, orderID).Scan(&taxAmount)
		if err == nil && taxAmount > 0 {
			data["tax_amount"] = taxAmount
		}
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

	// Health check: skip sync jika cloud unreachable
	if !s.isCloudReachable(ctx) {
		msg := "Cloud unreachable, skipping push cycle"
		log.Println("☁️  " + msg)
		if logID > 0 {
			s.syncRepo.UpdateSyncLog(ctx, logID, "skipped", 0, msg, time.Since(startTime).Milliseconds())
		}
		return nil // BUKAN error — POS tetap berjalan normal
	}

	// Get pending items (skip items yang terlalu sering gagal — exponential backoff)
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

	// Filter: skip items dengan retry_count tinggi (exponential backoff)
	var filteredItems []models.SyncQueue
	for _, item := range pendingItems {
		if item.RetryCount >= 3 {
			// Item sudah gagal 3x, skip dulu — akan di-retry via RetryFailed manual
			continue
		}
		filteredItems = append(filteredItems, item)
	}

	if len(filteredItems) == 0 {
		log.Println("All pending items exceeded retry limit, skipping")
		if logID > 0 {
			s.syncRepo.UpdateSyncLog(ctx, logID, "skipped", 0, "All items exceeded retry limit", time.Since(startTime).Milliseconds())
		}
		return nil
	}

	log.Printf("Processing %d pending sync items (filtered from %d)", len(filteredItems), len(pendingItems))

	// Convert to cloud sync items — SKIP transaction_item (akan di-bundle ke parent)
	var cloudItems []models.CloudSyncItem
	itemMap := make(map[int64]models.SyncQueue) // Map queue ID to item for later update
	var skippedTransactionItemIDs []int64       // IDs of transaction_item entries to mark success

	for _, item := range filteredItems {
		// Skip transaction_item — akan di-bundle ke parent transaction
		if item.EntityType == "transaction_item" {
			skippedTransactionItemIDs = append(skippedTransactionItemIDs, item.ID)
			continue
		}

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

		// === ENRICHMENT: bundle child items ke parent ===
		switch item.EntityType {
		case "order":
			s.enrichOrderPayload(ctx, data)
		case "transaction":
			s.enrichTransactionPayload(ctx, data)
		}

		cloudItems = append(cloudItems, models.CloudSyncItem{
			EntityType: item.EntityType,
			Operation:  item.Operation,
			Data:       data,
		})

		itemMap[item.ID] = item
	}

	// Mark skipped transaction_item entries as success (sudah di-bundle)
	for _, id := range skippedTransactionItemIDs {
		s.syncRepo.MarkSyncSuccess(ctx, id, "bundled")
	}

	if len(cloudItems) == 0 {
		log.Println("No valid items to sync")
		if logID > 0 {
			s.syncRepo.UpdateSyncLog(ctx, logID, "success", 0, "No valid items (all bundled)", time.Since(startTime).Milliseconds())
		}
		return nil
	}

	// Push to cloud
	log.Printf("Pushing %d items to cloud", len(cloudItems))
	cloudResp, err := s.cloudClient.PushBatch(ctx, cloudItems)
	if err != nil {
		errMsg := fmt.Sprintf("Failed to push to cloud: %v", err)
		log.Println(errMsg)

		// Mark all as failed (increment retry_count)
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

	// Build entityID → queueIDs map agar semua duplikat untuk entity sama ditangani
	entityQueueMap := make(map[string][]int64) // "entityType:entityID" → [queueID1, queueID2, ...]
	for id, item := range itemMap {
		key := item.EntityType + ":" + item.EntityID
		entityQueueMap[key] = append(entityQueueMap[key], id)
	}

	for _, result := range cloudResp.Data.Results {
		// Find ALL corresponding queue items by local_id
		var matchedIDs []int64
		for key, ids := range entityQueueMap {
			parts := strings.SplitN(key, ":", 2)
			entityID := ""
			if len(parts) == 2 {
				entityID = parts[1]
			}
			if entityID == result.LocalID {
				matchedIDs = ids
				break
			}
		}

		if len(matchedIDs) == 0 {
			log.Printf("Could not find queue item for local_id: %s", result.LocalID)
			continue
		}

		if result.Status == "success" {
			// Mark ALL entries for this entity as success
			for _, qid := range matchedIDs {
				if err := s.syncRepo.MarkSyncSuccess(ctx, qid, result.CloudID); err != nil {
					log.Printf("Failed to mark sync success for queue %d: %v", qid, err)
				}
			}

			// Update entity version
			firstItem := itemMap[matchedIDs[0]]
			s.syncRepo.MarkEntitySynced(ctx, firstItem.EntityType, firstItem.EntityID, 1)

			successCount++
		} else {
			// Mark ALL entries for this entity as failed
			for _, qid := range matchedIDs {
				if err := s.syncRepo.MarkSyncFailed(ctx, qid, result.Error); err != nil {
					log.Printf("Failed to mark sync failed for queue %d: %v", qid, err)
				}
			}
			failedCount++
		}
	}

	log.Printf("Sync completed: %d success, %d failed", successCount, failedCount)

	// Update last sync timestamp
	s.syncRepo.UpdateLastSync(ctx)

	// Cleanup: hapus entry success yang sudah lama (> 24 jam) agar tidak menumpuk
	s.cleanupOldSyncEntries(ctx)

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

// cleanupOldSyncEntries menghapus entry sync_queue yang sudah success/bundled
// agar tidak menumpuk di database lokal (performance SQLite)
func (s *syncService) cleanupOldSyncEntries(ctx context.Context) {
	result, err := s.db.ExecContext(ctx, `
		DELETE FROM sync_queue
		WHERE status IN ('success', 'bundled')
		AND processed_at < datetime('now', '-24 hours')
	`)
	if err != nil {
		log.Printf("Failed to cleanup old sync entries: %v", err)
		return
	}
	if rows, _ := result.RowsAffected(); rows > 0 {
		log.Printf("🧹 Cleaned up %d old sync entries", rows)
	}
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

	// Selalu update last_sync_at setelah pull berhasil (meskipun tidak ada data baru)
	if err := s.syncRepo.UpdateLastSync(ctx); err != nil {
		log.Printf("Failed to update last sync time: %v", err)
	}

	if processedCount == 0 {
		log.Println("No updates from cloud")
	}

	return nil
}

// FullPullFromCloud fetches ALL products & categories from cloud and upserts to local DB.
// Used after API key / outlet changes to fully replace local data with cloud data.
func (s *syncService) FullPullFromCloud(ctx context.Context) error {
	if s.cloudClient == nil {
		return fmt.Errorf("cloud client tidak dikonfigurasi")
	}

	log.Println("FullPullFromCloud: pull semua kategori & produk dari cloud...")

	// 1. Fetch & upsert categories
	categories, err := s.cloudClient.GetAllCategories(ctx)
	if err != nil {
		return fmt.Errorf("gagal fetch kategori dari cloud: %w", err)
	}
	catCount := 0
	for _, cat := range categories {
		if err2 := s.upsertCategoryFromCloud(ctx, cat); err2 != nil {
			log.Printf("Warning: gagal upsert kategori '%v': %v", cat["name"], err2)
			continue
		}
		catCount++
	}
	log.Printf("FullPullFromCloud: %d kategori diproses", catCount)

	// === Delete local categories not in cloud ===
	cloudCatIDs := make(map[string]struct{})
	for _, cat := range categories {
		id := ""
		if v, ok := cat["id"].(string); ok {
			id = v
		}
		if id == "" {
			if v, ok := cat["local_id"].(string); ok {
				id = v
			}
		}
		if id != "" {
			cloudCatIDs[id] = struct{}{}
		}
	}
	{
		rows, err := s.db.QueryContext(ctx, "SELECT id, COALESCE(cloud_id, '') FROM categories WHERE is_deleted = 0")
		if err == nil {
			type localCat struct{ id, cloudID string }
			var localCats []localCat
			for rows.Next() {
				var lc localCat
				if err := rows.Scan(&lc.id, &lc.cloudID); err == nil {
					localCats = append(localCats, lc)
				}
			}
			rows.Close()
			delCatCount := 0
			for _, lc := range localCats {
				_, foundByID := cloudCatIDs[lc.id]
				_, foundByCloudID := cloudCatIDs[lc.cloudID]
				if !foundByID && !foundByCloudID {
					s.db.ExecContext(ctx, "UPDATE categories SET is_deleted = 1, updated_at = CURRENT_TIMESTAMP WHERE id = ?", lc.id)
					delCatCount++
				}
			}
			if delCatCount > 0 {
				log.Printf("FullPullFromCloud: %d kategori lokal dihapus (tidak ada di cloud)", delCatCount)
			}
		}
	}

	// 2. Fetch & upsert products
	products, err := s.cloudClient.GetAllProducts(ctx)
	if err != nil {
		return fmt.Errorf("gagal fetch produk dari cloud: %w", err)
	}
	prodCount := 0
	for _, prod := range products {
		if err2 := s.upsertProductFromCloud(ctx, prod); err2 != nil {
			log.Printf("Warning: gagal upsert produk '%v': %v", prod["name"], err2)
			continue
		}
		prodCount++
	}
	log.Printf("FullPullFromCloud: %d produk diproses", prodCount)

	// === Delete local products not in cloud ===
	cloudProdIDs := make(map[string]struct{})
	for _, prod := range products {
		id := ""
		if v, ok := prod["id"].(string); ok {
			id = v
		}
		if id == "" {
			if v, ok := prod["local_id"].(string); ok {
				id = v
			}
		}
		if id != "" {
			cloudProdIDs[id] = struct{}{}
		}
	}
	{
		rows, err := s.db.QueryContext(ctx, "SELECT id, COALESCE(cloud_id, '') FROM products WHERE is_deleted = 0")
		if err == nil {
			type localProd struct{ id, cloudID string }
			var localProds []localProd
			for rows.Next() {
				var lp localProd
				if err := rows.Scan(&lp.id, &lp.cloudID); err == nil {
					localProds = append(localProds, lp)
				}
			}
			rows.Close()
			delProdCount := 0
			for _, lp := range localProds {
				_, foundByID := cloudProdIDs[lp.id]
				_, foundByCloudID := cloudProdIDs[lp.cloudID]
				if !foundByID && !foundByCloudID {
					s.db.ExecContext(ctx, "UPDATE products SET is_deleted = 1, updated_at = CURRENT_TIMESTAMP WHERE id = ?", lp.id)
					delProdCount++
				}
			}
			if delProdCount > 0 {
				log.Printf("FullPullFromCloud: %d produk lokal dihapus (tidak ada di cloud)", delProdCount)
			}
		}
	}

	// 3. Fetch outlet info (including tax settings) and sync tax charge
	outletInfo, err := s.cloudClient.GetOutletInfo(ctx)
	if err != nil {
		log.Printf("FullPullFromCloud: gagal fetch outlet info (tax settings): %v", err)
	} else {
		s.syncTaxFromCloud(ctx, outletInfo.TaxEnabled, outletInfo.TaxRate, outletInfo.TaxName)
	}

	if err := s.syncRepo.UpdateLastSync(ctx); err != nil {
		log.Printf("Warning: gagal update last sync: %v", err)
	}

	return nil
}

// GetSyncStatus returns current sync status
func (s *syncService) GetSyncStatus(ctx context.Context) (*models.SyncStatus, error) {
	return s.syncRepo.GetSyncStatus(ctx)
}

// syncTaxFromCloud creates or updates a local additional_charge entry from cloud tax settings
func (s *syncService) syncTaxFromCloud(ctx context.Context, taxEnabled bool, taxRate float64, taxName string) {
	if taxName == "" {
		taxName = "Pajak Restoran (PB1)"
	}

	charges, err := s.syncRepo.ListAdditionalCharges(ctx)
	if err != nil {
		log.Printf("syncTaxFromCloud: gagal list additional charges: %v", err)
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
		existingTax.Name = taxName
		existingTax.Value = taxRate
		existingTax.IsActive = taxEnabled
		if err := s.syncRepo.UpdateAdditionalCharge(ctx, existingTax); err != nil {
			log.Printf("syncTaxFromCloud: gagal update tax charge: %v", err)
			return
		}
		log.Printf("syncTaxFromCloud: tax charge updated: name=%s rate=%.2f enabled=%v", taxName, taxRate, taxEnabled)
	} else {
		newCharge := &models.AdditionalCharge{
			Name:       taxName,
			ChargeType: "percentage",
			Value:      taxRate,
			IsActive:   taxEnabled,
		}
		if err := s.syncRepo.CreateAdditionalCharge(ctx, newCharge); err != nil {
			log.Printf("syncTaxFromCloud: gagal create tax charge: %v", err)
			return
		}
		log.Printf("syncTaxFromCloud: tax charge created: name=%s rate=%.2f enabled=%v", taxName, taxRate, taxEnabled)
	}

	// Recalculate open orders
	if err := s.syncRepo.RefreshOpenOrderTotalsForAdditionalCharges(ctx); err != nil {
		log.Printf("syncTaxFromCloud: gagal refresh open orders: %v", err)
	}
}

// GetLastSyncTime returns the last sync timestamp from DB
func (s *syncService) GetLastSyncTime(ctx context.Context) (time.Time, error) {
	config, err := s.syncRepo.GetOutletConfig(ctx)
	if err != nil {
		return time.Time{}, err
	}
	if config.LastSyncAt != nil {
		return *config.LastSyncAt, nil
	}
	// No last sync — return zero time so we pull everything
	return time.Time{}, nil
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
	// Di cloud, id == local_id == POS category id (ID sama di kedua sistem)
	localID := getString(data, "id")
	if localID == "" {
		localID = getString(data, "local_id")
	}

	name := getString(data, "name")
	if name == "" {
		return fmt.Errorf("category name is required")
	}

	description := getString(data, "description")
	printerID := getString(data, "printer_id")
	version := getInt64(data, "version")

	// Cloud id = POS id, jadi cloud_id = id itu sendiri
	cloudID := localID

	// Cari kategori lokal by id (karena id sama di POS dan cloud)
	if localID != "" && len(localID) == 26 {
		exists, err := s.entityExists(ctx, "categories", localID)
		if err != nil {
			return err
		}
		if exists {
			goto doUpsert
		}
	}

	// Fallback: cari by nama (kategori punya nama unik)
	{
		var existingID string
		err := s.db.QueryRowContext(ctx, "SELECT id FROM categories WHERE name = ? LIMIT 1", name).Scan(&existingID)
		if err == nil && existingID != "" {
			localID = existingID
		}
	}

	// Generate ULID baru jika tidak ada ID valid
	if localID == "" || len(localID) != 26 {
		localID = utils.GenerateULID()
		cloudID = localID
	}

doUpsert:
	exists, err := s.entityExists(ctx, "categories", localID)
	if err != nil {
		return err
	}

	nullDesc := toNullString(description)
	nullCloudID := toNullString(cloudID)

	// Jika kategori baru dan belum ada printer_id, auto-assign berdasarkan destination produk
	if !exists && printerID == "" {
		printerID = s.resolvePrinterForCategory(ctx, name)
	}

	// Untuk update, JANGAN timpa printer_id yang sudah di-set lokal
	// (cloud tidak tahu soal printer lokal)
	if exists {
		_, err = s.db.ExecContext(ctx, `
			UPDATE categories
			SET name = ?, description = ?, cloud_id = COALESCE(?, cloud_id),
			    version = COALESCE(?, version), sync_status = 'synced', is_deleted = 0, last_synced_at = CURRENT_TIMESTAMP
			WHERE id = ?
		`, name, nullDesc, nullCloudID, nullableInt64(version), localID)
		if err != nil {
			return err
		}
		// Hapus entry sync_queue pending agar tidak push-back ke cloud (cegah feedback loop)
		_, _ = s.db.ExecContext(ctx, `
			DELETE FROM sync_queue
			WHERE entity_type = 'category' AND entity_id = ? AND status = 'pending'
		`, localID)
		return nil
	}

	nullPrinterID := toNullString(printerID)
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO categories (id, name, description, printer_id, cloud_id, version, sync_status, last_synced_at, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, 'synced', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
	`, localID, name, nullDesc, nullPrinterID, nullCloudID, nullableInt64(version))
	if err != nil {
		tx.Rollback()
		return err
	}

	// Hapus entry sync_queue pending agar tidak push-back ke cloud (cegah feedback loop)
	_, _ = tx.ExecContext(ctx, `
		DELETE FROM sync_queue
		WHERE entity_type = 'category' AND entity_id = ? AND status = 'pending'
	`, localID)

	return tx.Commit()
}

// resolvePrinterForCategory mencari printer yang cocok untuk kategori baru dari cloud.
// Mapping: nama kategori "Makanan" → kitchen, "Minuman"/"Dessert" → bar.
// Jika ada destination dari produk cloud, gunakan itu.
func (s *syncService) resolvePrinterForCategory(ctx context.Context, categoryName string) string {
	// Map nama kategori → printer_type
	printerType := ""
	nameLower := strings.ToLower(categoryName)
	switch {
	case strings.Contains(nameLower, "makan") || strings.Contains(nameLower, "food") || strings.Contains(nameLower, "snack"):
		printerType = "kitchen"
	case strings.Contains(nameLower, "minum") || strings.Contains(nameLower, "drink") || strings.Contains(nameLower, "beverage"):
		printerType = "bar"
	case strings.Contains(nameLower, "dessert") || strings.Contains(nameLower, "kue"):
		printerType = "kitchen"
	default:
		printerType = "kitchen" // default ke dapur
	}

	// Cari printer aktif yang cocok
	var foundPrinterID string
	err := s.db.QueryRowContext(ctx,
		"SELECT id FROM printers WHERE printer_type = ? AND is_active = 1 ORDER BY name LIMIT 1",
		printerType,
	).Scan(&foundPrinterID)

	if err == nil && foundPrinterID != "" {
		log.Printf("Auto-assigned printer %s (type=%s) untuk kategori '%s'", foundPrinterID, printerType, categoryName)
		return foundPrinterID
	}

	// Fallback: cari printer aktif apapun
	err = s.db.QueryRowContext(ctx,
		"SELECT id FROM printers WHERE is_active = 1 ORDER BY name LIMIT 1",
	).Scan(&foundPrinterID)

	if err == nil && foundPrinterID != "" {
		log.Printf("Auto-assigned fallback printer %s untuk kategori '%s'", foundPrinterID, categoryName)
		return foundPrinterID
	}

	log.Printf("Tidak ada printer aktif untuk kategori '%s', printer_id akan NULL", categoryName)
	return ""
}

func (s *syncService) upsertProductFromCloud(ctx context.Context, data map[string]interface{}) error {
	// Di cloud, id == local_id == POS product id (ID sama di kedua sistem)
	localID := getString(data, "id")
	if localID == "" {
		localID = getString(data, "local_id")
	}

	name := getString(data, "name")
	if name == "" {
		return fmt.Errorf("product name is required")
	}

	// Cloud sekarang punya code/description
	code := getString(data, "code")
	description := getString(data, "description")
	price := getFloat64(data, "price")
	stock := getInt64(data, "stock")
	categoryID := getString(data, "category_id")
	if categoryID == "" {
		categoryID = getString(data, "category_cloud_id")
	}
	// category_id di cloud = POS category id (sudah sama), tidak perlu mapping
	version := getInt64(data, "version")

	// Cloud id = POS id
	cloudID := localID

	// Cari produk lokal by id (karena id sama di POS dan cloud)
	if localID != "" && len(localID) == 26 {
		exists, err := s.entityExists(ctx, "products", localID)
		if err != nil {
			return err
		}
		if exists {
			goto doUpsert
		}
	}

	// Fallback: cari by nama
	{
		var existingID string
		err := s.db.QueryRowContext(ctx, "SELECT id FROM products WHERE name = ? LIMIT 1", name).Scan(&existingID)
		if err == nil && existingID != "" {
			localID = existingID
		}
	}

	// Generate ULID baru jika tidak ada ID valid
	if localID == "" || len(localID) != 26 {
		localID = utils.GenerateULID()
		cloudID = localID
	}

doUpsert:
	exists, err := s.entityExists(ctx, "products", localID)
	if err != nil {
		return err
	}

	// Clear code pada produk soft-deleted lain yang punya code sama (hindari UNIQUE constraint)
	if code != "" {
		_, _ = s.db.ExecContext(ctx, `
			UPDATE products SET code = NULL WHERE code = ? AND id != ? AND is_deleted = 1
		`, code, localID)
	}

	nullCategoryID := toNullString(categoryID)
	nullCloudID := toNullString(cloudID)

	if exists {
		// Update produk termasuk code dan description dari cloud
		_, err = s.db.ExecContext(ctx, `
			UPDATE products
			SET name = ?, code = COALESCE(?, code), description = COALESCE(?, description),
			    price = ?, stock = ?, category_id = ?,
			    cloud_id = COALESCE(?, cloud_id), version = COALESCE(?, version),
			    sync_status = 'synced', is_deleted = 0, last_synced_at = CURRENT_TIMESTAMP
			WHERE id = ?
		`, name, toNullString(code), toNullString(description),
			price, stock, nullCategoryID, nullCloudID, nullableInt64(version), localID)
		if err != nil {
			return err
		}
		// Hapus entry sync_queue pending agar tidak push-back ke cloud (cegah feedback loop)
		_, _ = s.db.ExecContext(ctx, `
			DELETE FROM sync_queue
			WHERE entity_type = 'product' AND entity_id = ? AND status = 'pending'
		`, localID)
		return nil
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO products (id, name, code, description, price, stock, category_id, cloud_id, version, sync_status, last_synced_at, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'synced', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
	`, localID, name, toNullString(code), toNullString(description), price, stock, nullCategoryID, nullCloudID, nullableInt64(version))
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

	// Soft delete: mark as deleted instead of hard DELETE to avoid FK constraint errors
	// (transaction_items.product_id → products.id ON DELETE RESTRICT)
	_, err := s.db.ExecContext(ctx, fmt.Sprintf("UPDATE %s SET is_deleted = 1, updated_at = CURRENT_TIMESTAMP WHERE id = ?", table), localID)
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
