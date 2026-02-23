package workers

import (
	"backend/internal/services"
	"context"
	"log"
	"time"
)

// SyncWorker handles background synchronization
type SyncWorker struct {
	syncService services.SyncService
	interval    time.Duration
	stopChan    chan struct{}
	isRunning   bool
	enabled     bool
}

// NewSyncWorker creates a new sync worker
func NewSyncWorker(syncService services.SyncService, intervalMinutes int, enabled bool) *SyncWorker {
	if intervalMinutes < 1 {
		intervalMinutes = 5 // Default to 5 minutes
	}

	return &SyncWorker{
		syncService: syncService,
		interval:    time.Duration(intervalMinutes) * time.Minute,
		stopChan:    make(chan struct{}),
		isRunning:   false,
		enabled:     enabled,
	}
}

// Start begins the background sync worker
func (w *SyncWorker) Start() {
	if !w.enabled {
		log.Println("⏸️  Sync worker disabled - Enable in settings to start syncing")
		return
	}

	if w.isRunning {
		log.Println("Sync worker already running")
		return
	}

	w.isRunning = true
	log.Printf("▶️  Starting sync worker (interval: %v)", w.interval)

	go w.run()
}

// Stop stops the background sync worker
func (w *SyncWorker) Stop() {
	if !w.isRunning {
		return
	}

	log.Println("Stopping sync worker...")
	close(w.stopChan)
	w.isRunning = false
	log.Println("Sync worker stopped")
}

// run is the main worker loop
func (w *SyncWorker) run() {
	// Initial sync on startup
	w.performSync()

	ticker := time.NewTicker(w.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			w.performSync()
		case <-w.stopChan:
			return
		}
	}
}

// performSync executes the sync operations
func (w *SyncWorker) performSync() {
	if !w.enabled {
		log.Println("⏸️  Sync is disabled - Skipping sync operation")
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	log.Println("🔄 === Background Sync Started ===")
	startTime := time.Now()

	// Push pending data to cloud
	if err := w.syncService.PushPendingData(ctx); err != nil {
		log.Printf("❌ Error pushing data to cloud: %v", err)
	}

	// Pull updates from cloud (since last sync)
	since := time.Now().Add(-w.interval * 2) // Pull last 2 intervals worth of data
	if err := w.syncService.PullUpdates(ctx, since); err != nil {
		log.Printf("❌ Error pulling updates from cloud: %v", err)
	}

	duration := time.Since(startTime)
	log.Printf("✅ === Background Sync Completed (took %v) ===", duration)
}

// IsRunning returns whether the worker is currently running
func (w *SyncWorker) IsRunning() bool {
	return w.isRunning
}

// IsEnabled returns whether sync is enabled
func (w *SyncWorker) IsEnabled() bool {
	return w.enabled
}

// SetEnabled updates the enabled status
func (w *SyncWorker) SetEnabled(enabled bool) {
	w.enabled = enabled
	if enabled && !w.isRunning {
		log.Println("🔄 Sync enabled - Starting sync worker...")
		w.Start()
	} else if !enabled && w.isRunning {
		log.Println("⏸️  Sync disabled - Stopping sync worker...")
		w.Stop()
	}
}
