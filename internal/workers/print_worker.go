package workers

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"backend/internal/db"
	"backend/pkg/printer"
)

// PrintWorker handles background print job processing
type PrintWorker struct {
	db           *sql.DB
	queries      *db.Queries
	pollInterval time.Duration
	maxRetries   int
	outletConfig printer.OutletConfig
	workerID     string
	stopChan     chan struct{}
	stoppedChan  chan struct{}
}

// PrintJobData holds the data structure for print_queue.data JSON
type PrintJobData struct {
	OrderID                string             `json:"order_id"`
	RetryOf                string             `json:"retry_of,omitempty"`
	ReceiptNumber          string             `json:"receipt_number"`
	TableNumber            string             `json:"table_number"`
	CustomerName           string             `json:"customer_name"`
	WaiterName             string             `json:"waiter_name"`
	CashierName            string             `json:"cashier_name"`
	Items                  []ReceiptItem      `json:"items"`
	Subtotal               int                `json:"subtotal"`
	AdditionalChargesTotal int                `json:"additional_charges_total"`
	AdditionalCharges      []ReceiptCharge    `json:"additional_charges"`
	Tax                    int                `json:"tax"`
	Total                  int                `json:"total"`
	PaymentMethod          string             `json:"payment_method"`
	PaidAmount             int                `json:"paid_amount"`
	ChangeAmount           int                `json:"change_amount"`
	DateTime               time.Time          `json:"datetime"`
	IsBill                 bool               `json:"is_bill"`
	IsSplitPayment         bool               `json:"is_split_payment"`
	IsHandover             bool               `json:"is_handover"`
	IsCloseShift           bool               `json:"is_close_shift"`
	IsCashInReceipt        bool               `json:"is_cash_in_receipt"`
	IsCashOutReceipt       bool               `json:"is_cash_out_receipt"`
	HandoverFrom           string             `json:"handover_from"`
	HandoverTo             string             `json:"handover_to"`
	MovementName           string             `json:"movement_name"`
	MovementNote           string             `json:"movement_note"`
	MovementAmount         int                `json:"movement_amount"`
	OpeningCash            int                `json:"opening_cash"`
	ClosingCash            int                `json:"closing_cash"`
	ClosingCard            int                `json:"closing_card"`
	ClosingQris            int                `json:"closing_qris"`
	ClosingTransfer        int                `json:"closing_transfer"`
	VoidedCount            int                `json:"voided_count"`
	VoidedTotal            int                `json:"voided_total"`
	CancelledCount         int                `json:"cancelled_count"`
	CancelledTotal         int                `json:"cancelled_total"`
	CashIns                []CashMovementData `json:"cash_ins"`
	CashOuts               []CashMovementData `json:"cash_outs"`
}

type CashMovementData struct {
	Name   string `json:"name"`
	Amount int    `json:"amount"`
}

// ReceiptItem represents a single item on the receipt
type ReceiptItem struct {
	Name     string `json:"name"`
	Quantity int    `json:"quantity"`
	Price    int    `json:"price"`
	Total    int    `json:"total"`
}

type ReceiptCharge struct {
	Name   string `json:"name"`
	Amount int    `json:"amount"`
}

// NewPrintWorker creates a new print worker
func NewPrintWorker(database *sql.DB, outlet printer.OutletConfig) *PrintWorker {
	hostname, err := os.Hostname()
	if err != nil || hostname == "" {
		hostname = "worker"
	}
	return &PrintWorker{
		db:           database,
		queries:      db.New(database),
		pollInterval: 2 * time.Second, // Poll every 2 seconds
		maxRetries:   3,
		outletConfig: outlet,
		workerID:     fmt.Sprintf("%s-%d", hostname, time.Now().UnixNano()),
		stopChan:     make(chan struct{}),
		stoppedChan:  make(chan struct{}),
	}
}

// Start begins the print worker loop
func (w *PrintWorker) Start(ctx context.Context) {
	// log.Println("🖨️  Print Worker started")
	ticker := time.NewTicker(w.pollInterval)
	defer ticker.Stop()
	defer close(w.stoppedChan)

	for {
		select {
		case <-ctx.Done():
			// log.Println("🖨️  Print Worker stopping (context cancelled)")
			return
		case <-w.stopChan:
			// log.Println("🖨️  Print Worker stopping (stop signal received)")
			return
		case <-ticker.C:
			w.processPendingJobs()
		}
	}
}

// Stop signals the worker to stop
func (w *PrintWorker) Stop() {
	close(w.stopChan)
	<-w.stoppedChan
	// log.Println("🖨️  Print Worker stopped")
}

// processPendingJobs processes all pending print jobs
func (w *PrintWorker) processPendingJobs() {
	_, _ = w.db.Exec(`
		UPDATE print_queue
		SET locked_at = NULL, locked_by = NULL, updated_at = CURRENT_TIMESTAMP
		WHERE status = 'pending'
		  AND locked_at IS NOT NULL
		  AND locked_at <= datetime('now', '-5 minutes')
	`)

	// Get pending jobs
	rows, err := w.db.Query(`
		SELECT id, printer_id, data, retry_count 
		FROM print_queue 
		WHERE status = 'pending' AND locked_at IS NULL
		ORDER BY created_at ASC 
		LIMIT 10
	`)
	if err != nil {
		// log.Printf("❌ Error querying print queue: %v", err)
		return
	}
	defer rows.Close()

	type pendingJob struct {
		jobID      string
		printerID  string
		dataJSON   string
		retryCount int
	}

	jobs := make([]pendingJob, 0, 10)

	for rows.Next() {
		var jobID, printerID string
		var dataJSON string
		var retryCount int

		err := rows.Scan(&jobID, &printerID, &dataJSON, &retryCount)
		if err != nil {
			// log.Printf("❌ Error scanning print job: %v", err)
			continue
		}

		jobs = append(jobs, pendingJob{
			jobID:      jobID,
			printerID:  printerID,
			dataJSON:   dataJSON,
			retryCount: retryCount,
		})
	}

	if err := rows.Err(); err != nil {
		return
	}

	for _, job := range jobs {
		claimed, err := w.claimJob(job.jobID)
		if err != nil || !claimed {
			continue
		}
		w.processJob(job.jobID, job.printerID, job.dataJSON, job.retryCount)
	}
}

func (w *PrintWorker) claimJob(jobID string) (bool, error) {
	result, err := w.db.Exec(`
		UPDATE print_queue
		SET locked_at = CURRENT_TIMESTAMP, locked_by = ?, updated_at = CURRENT_TIMESTAMP
		WHERE id = ? AND status = 'pending' AND locked_at IS NULL
	`, w.workerID, jobID)
	if err != nil {
		return false, err
	}
	affected, err := result.RowsAffected()
	if err != nil {
		return false, err
	}
	return affected > 0, nil
}

// processJob processes a single print job
func (w *PrintWorker) processJob(jobID, printerID string, dataJSON string, retryCount int) {
	// log.Printf("🖨️  Processing print job #%s (printer #%s, retry %d)", jobID, printerID, retryCount)

	// Check retry limit
	if retryCount >= w.maxRetries {
		w.markJobFailed(jobID, fmt.Sprintf("Max retries (%d) exceeded", w.maxRetries))
		return
	}

	// Get printer info
	printerRow := w.db.QueryRow(`
		SELECT name, ip_address, port, printer_type, paper_size, is_active 
		FROM printers 
		WHERE id = ?
	`, printerID)

	var printerName, ipAddress, printerType, paperSize string
	var port int
	var isActive int

	err := printerRow.Scan(&printerName, &ipAddress, &port, &printerType, &paperSize, &isActive)
	if err != nil {
		w.markJobFailed(jobID, fmt.Sprintf("Printer not found: %v", err))
		return
	}

	// Check if printer is active
	if isActive != 1 {
		w.markJobFailed(jobID, fmt.Sprintf("Printer '%s' is not active", printerName))
		return
	}

	// Parse print data
	var jobData PrintJobData
	err = json.Unmarshal([]byte(dataJSON), &jobData)
	if err != nil {
		w.markJobFailed(jobID, fmt.Sprintf("Invalid job data: %v", err))
		return
	}
	if jobData.OrderID != "" && !jobData.IsBill && !jobData.IsHandover && !jobData.IsCloseShift && !jobData.IsCashInReceipt && !jobData.IsCashOutReceipt && printerType != "kitchen" && printerType != "bar" {
		var paymentTime sql.NullTime
		var paymentCreatedBy sql.NullString
		_ = w.db.QueryRow(`SELECT created_at, created_by FROM payments WHERE order_id = ? ORDER BY created_at DESC LIMIT 1`, jobData.OrderID).Scan(&paymentTime, &paymentCreatedBy)

		var transactionTime sql.NullTime
		var transactionCreatedBy sql.NullString
		_ = w.db.QueryRow(`SELECT transaction_date, created_by FROM transactions WHERE order_id = ? AND cancelled_at IS NULL ORDER BY transaction_date DESC LIMIT 1`, jobData.OrderID).Scan(&transactionTime, &transactionCreatedBy)

		selectedTime := time.Time{}
		selectedCashierID := ""
		if paymentTime.Valid {
			selectedTime = paymentTime.Time
			if paymentCreatedBy.Valid {
				selectedCashierID = paymentCreatedBy.String
			}
		}
		if transactionTime.Valid && (selectedTime.IsZero() || transactionTime.Time.After(selectedTime)) {
			selectedTime = transactionTime.Time
			if transactionCreatedBy.Valid {
				selectedCashierID = transactionCreatedBy.String
			}
		}
		if !selectedTime.IsZero() {
			jobData.DateTime = selectedTime.In(time.Local)
		}
		if jobData.CashierName == "" && selectedCashierID != "" {
			var fullName string
			if err := w.db.QueryRow(`SELECT full_name FROM users WHERE id = ?`, selectedCashierID).Scan(&fullName); err == nil {
				jobData.CashierName = fullName
			}
		}
	}
	if jobData.DateTime.IsZero() && jobData.OrderID != "" {
		var updatedAt time.Time
		var createdAt time.Time
		if err := w.db.QueryRow(`SELECT updated_at, created_at FROM orders WHERE id = ?`, jobData.OrderID).Scan(&updatedAt, &createdAt); err == nil {
			if !updatedAt.IsZero() {
				jobData.DateTime = updatedAt.In(time.Local)
			} else {
				jobData.DateTime = createdAt.In(time.Local)
			}
		}
	}
	if !jobData.DateTime.IsZero() {
		jobData.DateTime = jobData.DateTime.In(time.Local)
	}
	if jobData.WaiterName == "" && jobData.OrderID != "" {
		var createdBy sql.NullString
		row := w.db.QueryRow(`SELECT created_by FROM orders WHERE id = ?`, jobData.OrderID)
		if err := row.Scan(&createdBy); err == nil && createdBy.Valid && createdBy.String != "" {
			var fullName string
			if err := w.db.QueryRow(`SELECT full_name FROM users WHERE id = ?`, createdBy.String).Scan(&fullName); err == nil {
				jobData.WaiterName = fullName
			}
		}
	}

	// Create formatter
	formatter := printer.NewPrintFormatter(w.outletConfig, paperSize)

	var receiptData []byte

	// Format receipt based on printer type
	toPrinterMovements := func(items []CashMovementData) []printer.CashMovementData {
		printItems := make([]printer.CashMovementData, 0, len(items))
		for _, item := range items {
			printItems = append(printItems, printer.CashMovementData{
				Name:   item.Name,
				Amount: item.Amount,
			})
		}
		return printItems
	}
	toPrinterCharges := func(items []ReceiptCharge) []printer.ReceiptCharge {
		printItems := make([]printer.ReceiptCharge, 0, len(items))
		for _, item := range items {
			printItems = append(printItems, printer.ReceiptCharge{
				Name:   item.Name,
				Amount: item.Amount,
			})
		}
		return printItems
	}

	if jobData.IsHandover {
		handoverPayload := printer.HandoverReceiptData{
			ReceiptNumber:   jobData.ReceiptNumber,
			CashierFrom:     jobData.HandoverFrom,
			CashierTo:       jobData.HandoverTo,
			OpeningCash:     jobData.OpeningCash,
			ClosingCash:     jobData.ClosingCash,
			ClosingCard:     jobData.ClosingCard,
			ClosingQris:     jobData.ClosingQris,
			ClosingTransfer: jobData.ClosingTransfer,
			VoidedCount:     jobData.VoidedCount,
			VoidedTotal:     jobData.VoidedTotal,
			CancelledCount:  jobData.CancelledCount,
			CancelledTotal:  jobData.CancelledTotal,
			CashIns:         toPrinterMovements(jobData.CashIns),
			CashOuts:        toPrinterMovements(jobData.CashOuts),
			DateTime:        jobData.DateTime,
		}
		receiptData = formatter.FormatHandoverReceipt(handoverPayload)
	} else if jobData.IsCloseShift {
		closePayload := printer.CloseShiftReceiptData{
			ReceiptNumber:   jobData.ReceiptNumber,
			CashierName:     jobData.CashierName,
			OpeningCash:     jobData.OpeningCash,
			ClosingCash:     jobData.ClosingCash,
			ClosingCard:     jobData.ClosingCard,
			ClosingQris:     jobData.ClosingQris,
			ClosingTransfer: jobData.ClosingTransfer,
			VoidedCount:     jobData.VoidedCount,
			VoidedTotal:     jobData.VoidedTotal,
			CancelledCount:  jobData.CancelledCount,
			CancelledTotal:  jobData.CancelledTotal,
			CashIns:         toPrinterMovements(jobData.CashIns),
			CashOuts:        toPrinterMovements(jobData.CashOuts),
			DateTime:        jobData.DateTime,
		}
		receiptData = formatter.FormatCloseShiftReceipt(closePayload)
	} else if jobData.IsCashInReceipt {
		cashInPayload := printer.CashInReceiptData{
			ReceiptNumber: jobData.ReceiptNumber,
			CashierName:   jobData.CashierName,
			Counterpart:   jobData.MovementName,
			Amount:        jobData.MovementAmount,
			DateTime:      jobData.DateTime,
		}
		receiptData = formatter.FormatCashInReceipt(cashInPayload)
	} else if jobData.IsCashOutReceipt {
		cashOutPayload := printer.CashOutReceiptData{
			ReceiptNumber: jobData.ReceiptNumber,
			CashierName:   jobData.CashierName,
			Recipient:     jobData.MovementName,
			Note:          jobData.MovementNote,
			Amount:        jobData.MovementAmount,
			DateTime:      jobData.DateTime,
		}
		receiptData = formatter.FormatCashOutReceipt(cashOutPayload)
	} else if printerType == "kitchen" || printerType == "bar" {
		// Kitchen/Bar format - simple order list
		// Convert to printer.ReceiptItem
		printerItems := make([]printer.ReceiptItem, len(jobData.Items))
		for i, item := range jobData.Items {
			printerItems[i] = printer.ReceiptItem{
				Name:     item.Name,
				Quantity: item.Quantity,
				Price:    item.Price,
				Total:    item.Total,
			}
		}
		receiptData = formatter.FormatKitchenOrder(
			printerName,
			jobData.ReceiptNumber,
			jobData.TableNumber,
			jobData.WaiterName,
			printerItems,
			jobData.DateTime,
		)
	} else {
		printerItems := make([]printer.ReceiptItem, len(jobData.Items))
		for i, item := range jobData.Items {
			printerItems[i] = printer.ReceiptItem{
				Name:     item.Name,
				Quantity: item.Quantity,
				Price:    item.Price,
				Total:    item.Total,
			}
		}
		receiptPayload := printer.ReceiptData{
			ReceiptNumber:          jobData.ReceiptNumber,
			TableNumber:            jobData.TableNumber,
			CustomerName:           jobData.CustomerName,
			WaiterName:             jobData.WaiterName,
			CashierName:            jobData.CashierName,
			Items:                  printerItems,
			Subtotal:               jobData.Subtotal,
			AdditionalChargesTotal: jobData.AdditionalChargesTotal,
			AdditionalCharges:      toPrinterCharges(jobData.AdditionalCharges),
			Tax:                    jobData.Tax,
			Total:                  jobData.Total,
			PaymentMethod:          jobData.PaymentMethod,
			PaidAmount:             jobData.PaidAmount,
			ChangeAmount:           jobData.ChangeAmount,
			DateTime:               jobData.DateTime,
		}
		if jobData.IsBill {
			receiptData = formatter.FormatBill(receiptPayload)
		} else if jobData.IsSplitPayment {
			receiptData = formatter.FormatSplitReceipt(receiptPayload)
		} else {
			receiptData = formatter.FormatReceipt(receiptPayload)
		}
	}

	// Send to printer
	err = printer.SendToPrinter(ipAddress, port, receiptData)
	if err != nil {
		// Increment retry count and keep as pending
		w.incrementRetry(jobID, err.Error())
		// log.Printf("❌ Print job #%s failed: %v (will retry)", jobID, err)
		return
	}

	// Mark as done
	w.markJobDone(jobID)
	if jobData.RetryOf != "" {
		w.cleanupRetrySource(jobData.RetryOf)
	}
	// log.Printf("✅ Print job #%s completed successfully (printer: %s)", jobID, printerName)
}

// markJobDone marks a job as done
func (w *PrintWorker) markJobDone(jobID string) {
	_, err := w.db.Exec(`
		UPDATE print_queue 
		SET status = 'done', locked_at = NULL, locked_by = NULL, updated_at = CURRENT_TIMESTAMP 
		WHERE id = ?
	`, jobID)
	if err != nil {
		// log.Printf("❌ Error marking job #%s as done: %v", jobID, err)
	}
}

// markJobFailed marks a job as failed
func (w *PrintWorker) markJobFailed(jobID string, reason string) {
	_, err := w.db.Exec(`
		UPDATE print_queue 
		SET status = 'failed', error_message = ?, locked_at = NULL, locked_by = NULL, updated_at = CURRENT_TIMESTAMP 
		WHERE id = ?
	`, reason, jobID)
	if err != nil {
		// log.Printf("❌ Error marking job #%s as failed: %v", jobID, err)
	} else {
		// log.Printf("❌ Print job #%s marked as failed: %s", jobID, reason)
	}
}

// incrementRetry increments retry count
func (w *PrintWorker) incrementRetry(jobID string, errorMsg string) {
	_, err := w.db.Exec(`
		UPDATE print_queue 
		SET retry_count = retry_count + 1, 
		    error_message = ?, 
		    locked_at = NULL,
		    locked_by = NULL,
		    updated_at = CURRENT_TIMESTAMP 
		WHERE id = ?
	`, errorMsg, jobID)
	if err != nil {
		// log.Printf("❌ Error incrementing retry for job #%s: %v", jobID, err)
	}
}

func (w *PrintWorker) cleanupRetrySource(queueID string) {
	if queueID == "" {
		return
	}
	_, _ = w.db.Exec(`
		DELETE FROM print_queue
		WHERE id = ? AND status = 'failed'
	`, queueID)
}
