package workers

import (
	"backend/internal/repositories"
	"context"
	"database/sql"
	"fmt"
	"log"
	"time"
)

// RetentionWorker periodically deletes old transaction/order data
type RetentionWorker struct {
	db       *sql.DB
	syncRepo repositories.SyncRepository
	stopChan chan struct{}
	interval time.Duration
}

// NewRetentionWorker creates a new retention cleanup worker
func NewRetentionWorker(db *sql.DB, syncRepo repositories.SyncRepository) *RetentionWorker {
	return &RetentionWorker{
		db:       db,
		syncRepo: syncRepo,
		stopChan: make(chan struct{}),
		interval: 1 * time.Hour, // Check every hour
	}
}

// Start begins the retention worker in a goroutine
func (w *RetentionWorker) Start(ctx context.Context) {
	log.Println("🗑️  Retention worker started (checks every 1 hour)")

	// Run initial cleanup after a short delay
	timer := time.NewTimer(30 * time.Second)
	select {
	case <-timer.C:
		w.runCleanup(ctx)
	case <-ctx.Done():
		timer.Stop()
		return
	case <-w.stopChan:
		timer.Stop()
		return
	}

	ticker := time.NewTicker(w.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-w.stopChan:
			return
		case <-ticker.C:
			w.runCleanup(ctx)
		}
	}
}

// Stop signals the worker to stop
func (w *RetentionWorker) Stop() {
	close(w.stopChan)
	log.Println("🗑️  Retention worker stopped")
}

func (w *RetentionWorker) runCleanup(ctx context.Context) {
	config, err := w.syncRepo.GetOutletConfig(ctx)
	if err != nil || config == nil {
		return // No config = no retention policy
	}

	days := config.DataRetentionDays
	if days <= 0 {
		return // 0 = keep forever
	}

	cutoff := time.Now().AddDate(0, 0, -days)
	cutoffStr := cutoff.Format("2006-01-02 15:04:05")

	deleted, err := w.deleteOldData(ctx, cutoffStr)
	if err != nil {
		log.Printf("⚠️  Retention cleanup error: %v", err)
		return
	}

	if deleted > 0 {
		log.Printf("🗑️  Retention cleanup: deleted %d old records (older than %d days)", deleted, days)

		// VACUUM to reclaim disk space
		if _, err := w.db.ExecContext(ctx, "VACUUM"); err != nil {
			log.Printf("⚠️  VACUUM failed: %v", err)
		}
	}
}

func (w *RetentionWorker) deleteOldData(ctx context.Context, cutoff string) (int64, error) {
	tx, err := w.db.BeginTx(ctx, nil)
	if err != nil {
		return 0, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback()

	var totalDeleted int64

	// Delete old transactions (transaction_items cascade via FK)
	res, err := tx.ExecContext(ctx,
		"DELETE FROM transactions WHERE created_at < ? AND status IN ('completed', 'cancelled')", cutoff)
	if err != nil {
		return 0, fmt.Errorf("delete transactions: %w", err)
	}
	n, _ := res.RowsAffected()
	totalDeleted += n

	// Delete old completed/voided orders (order_items, order_additional_charges, payments cascade via FK)
	res, err = tx.ExecContext(ctx,
		"DELETE FROM orders WHERE created_at < ? AND payment_status IN ('paid', 'voided')", cutoff)
	if err != nil {
		return 0, fmt.Errorf("delete orders: %w", err)
	}
	n, _ = res.RowsAffected()
	totalDeleted += n

	// Delete old closed cashier shifts (cash_movements cascade via FK)
	res, err = tx.ExecContext(ctx,
		"DELETE FROM cashier_shifts WHERE created_at < ? AND status = 'closed'", cutoff)
	if err != nil {
		return 0, fmt.Errorf("delete shifts: %w", err)
	}
	n, _ = res.RowsAffected()
	totalDeleted += n

	// Delete old completed print jobs
	res, err = tx.ExecContext(ctx,
		"DELETE FROM print_queue WHERE created_at < ? AND status IN ('completed', 'failed')", cutoff)
	if err != nil {
		return 0, fmt.Errorf("delete print_queue: %w", err)
	}
	n, _ = res.RowsAffected()
	totalDeleted += n

	// Delete old processed sync queue entries
	res, err = tx.ExecContext(ctx,
		"DELETE FROM sync_queue WHERE created_at < ? AND status IN ('success', 'failed')", cutoff)
	if err != nil {
		// sync_queue may not exist yet
		log.Printf("⚠️  Skip sync_queue cleanup: %v", err)
	} else {
		n, _ = res.RowsAffected()
		totalDeleted += n
	}

	if err := tx.Commit(); err != nil {
		return 0, fmt.Errorf("commit tx: %w", err)
	}

	return totalDeleted, nil
}
