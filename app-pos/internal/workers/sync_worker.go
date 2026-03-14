package workers

import (
	"backend/internal/services"
	"context"
	"log"
	"sync"
	"time"
)

// SyncWorker handles background synchronization
type SyncWorker struct {
	syncService      services.SyncService
	interval         time.Duration
	stopChan         chan struct{}
	isRunning        bool
	enabled          bool
	syncMu           sync.Mutex // Mencegah concurrent sync (background + manual trigger)
	consecutiveFails int        // Counter untuk exponential backoff saat offline
	maxBackoffMins   int        // Batas atas backoff (default 30 menit)
}

// NewSyncWorker creates a new sync worker
func NewSyncWorker(syncService services.SyncService, intervalMinutes int, enabled bool) *SyncWorker {
	if intervalMinutes < 1 {
		intervalMinutes = 5 // Default to 5 minutes
	}

	return &SyncWorker{
		syncService:      syncService,
		interval:         time.Duration(intervalMinutes) * time.Minute,
		stopChan:         make(chan struct{}),
		isRunning:        false,
		enabled:          enabled,
		consecutiveFails: 0,
		maxBackoffMins:   30,
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

	w.stopChan = make(chan struct{})
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

	for {
		// Dynamic interval: saat offline, gunakan backoff agar tidak spam
		currentInterval := w.getNextInterval()

		select {
		case <-time.After(currentInterval):
			w.performSync()
		case <-w.stopChan:
			return
		}
	}
}

// getNextInterval menghitung interval berikutnya berdasarkan consecutive fails
// Saat online: gunakan interval normal (default 5 menit)
// Saat offline: eksponensial backoff (5 → 10 → 20 → 30 menit max)
func (w *SyncWorker) getNextInterval() time.Duration {
	if w.consecutiveFails <= 0 {
		return w.interval
	}

	// Eksponensial backoff: interval * 2^fails, cap di maxBackoffMins
	backoff := w.interval * time.Duration(1<<uint(w.consecutiveFails))
	maxBackoff := time.Duration(w.maxBackoffMins) * time.Minute
	if backoff > maxBackoff {
		backoff = maxBackoff
	}

	log.Printf("⏳ Next sync in %v (consecutive fails: %d)", backoff, w.consecutiveFails)
	return backoff
}

// performSync executes the sync operations
func (w *SyncWorker) performSync() {
	if !w.enabled {
		log.Println("⏸️  Sync is disabled - Skipping sync operation")
		return
	}

	// Mutex: mencegah concurrent sync (background tick + manual TriggerSync)
	if !w.syncMu.TryLock() {
		log.Println("⏳ Sync already in progress, skipping this cycle")
		return
	}
	defer w.syncMu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	// Reload cloud client config from DB before each sync
	if err := w.syncService.ReloadCloudClient(ctx); err != nil {
		log.Printf("⚠️  Failed to reload cloud config: %v", err)
		w.consecutiveFails++
		return
	}

	log.Println("🔄 === Background Sync Started ===")
	startTime := time.Now()
	hadError := false

	// Push pending data to cloud
	if err := w.syncService.PushPendingData(ctx); err != nil {
		log.Printf("❌ Error pushing data to cloud: %v", err)
		hadError = true
	}

	// Pull updates from cloud (since last sync) — hanya jika push berhasil
	if !hadError {
		since, err := w.syncService.GetLastSyncTime(ctx)
		if err != nil {
			log.Printf("⚠️  Failed to get last sync time, using fallback: %v", err)
			since = time.Now().Add(-w.interval * 2)
		}
		if since.IsZero() {
			since = time.Now().Add(-24 * time.Hour) // First sync: pull last 24h
		}
		if err := w.syncService.PullUpdates(ctx, since); err != nil {
			log.Printf("❌ Error pulling updates from cloud: %v", err)
			hadError = true
		}
	}

	// Update backoff counter
	if hadError {
		w.consecutiveFails++
	} else {
		if w.consecutiveFails > 0 {
			log.Println("✅ Cloud connection restored!")
		}
		w.consecutiveFails = 0
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

// SetInterval updates the sync interval and restarts the worker if running
func (w *SyncWorker) SetInterval(minutes int) {
	if minutes < 1 {
		minutes = 5
	}
	newInterval := time.Duration(minutes) * time.Minute
	if newInterval == w.interval {
		return
	}
	log.Printf("🔄 Sync interval changed: %v → %v", w.interval, newInterval)
	w.interval = newInterval
	if w.isRunning {
		w.Stop()
		w.Start()
	}
}
