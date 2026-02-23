package handlers

import (
	"backend/internal/db"
	"backend/internal/middleware"
	"backend/internal/repositories"
	"backend/internal/services"
	"backend/internal/workers"
	"backend/pkg/utils"
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"math"
	"net/http"
	"strings"
	"time"

	"github.com/labstack/echo/v5"
	"golang.org/x/crypto/bcrypt"
)

type TransactionHandler struct {
	transactionService services.TransactionService
	queries            *db.Queries
	db                 *sql.DB
}

func NewTransactionHandler(transactionService services.TransactionService, queries *db.Queries, sqlDB *sql.DB) *TransactionHandler {
	return &TransactionHandler{
		transactionService: transactionService,
		queries:            queries,
		db:                 sqlDB,
	}
}

type CreateTransactionRequest struct {
	OrderID       string                          `json:"order_id"`
	TotalAmount   float64                         `json:"total_amount"`
	PaymentMethod string                          `json:"payment_method"`
	Items         []services.TransactionItemInput `json:"items"`
}

type OpenCashierShiftRequest struct {
	OpeningCash *float64 `json:"opening_cash"`
}

type CloseCashierShiftRequest struct {
	ClosingCash     float64 `json:"closing_cash"`
	ClosingCard     float64 `json:"closing_card"`
	ClosingQris     float64 `json:"closing_qris"`
	ClosingTransfer float64 `json:"closing_transfer"`
}

type HandoverCashierShiftRequest struct {
	NextCashierID     string  `json:"next_cashier_id"`
	CurrentCashierPIN string  `json:"current_cashier_pin"`
	NextCashierPIN    string  `json:"next_cashier_pin"`
	ClosingCash       float64 `json:"closing_cash"`
	ClosingCard       float64 `json:"closing_card"`
	ClosingQris       float64 `json:"closing_qris"`
	ClosingTransfer   float64 `json:"closing_transfer"`
}

type CreateCashMovementRequest struct {
	Type   string  `json:"type"`
	Name   string  `json:"name"`
	Note   string  `json:"note"`
	Amount float64 `json:"amount"`
}

type shiftPaymentSummary struct {
	Cash     float64 `json:"cash"`
	Card     float64 `json:"card"`
	Qris     float64 `json:"qris"`
	Transfer float64 `json:"transfer"`
	Total    float64 `json:"total"`
}

type cashierShiftRow struct {
	ID              string
	OpenedBy        string
	OpenedAt        time.Time
	OpeningCash     float64
	ClosedAt        sql.NullTime
	ClosedBy        sql.NullString
	ClosingCash     sql.NullFloat64
	ClosingCard     sql.NullFloat64
	ClosingQris     sql.NullFloat64
	ClosingTransfer sql.NullFloat64
	CarryOverCash   sql.NullFloat64
	PreviousShift   sql.NullString
	HandoverTo      sql.NullString
	Status          string
	Notes           sql.NullString
	CreatedAt       time.Time
	UpdatedAt       time.Time
	OpenedByName    sql.NullString
	ClosedByName    sql.NullString
	HandoverToName  sql.NullString
}

const cashierShiftSelect = `
	SELECT
		cs.id,
		cs.opened_by,
		cs.opened_at,
		cs.opening_cash,
		cs.closed_at,
		cs.closed_by,
		cs.closing_cash,
		cs.closing_card,
		cs.closing_qris,
		cs.closing_transfer,
		cs.carry_over_cash,
		cs.previous_shift_id,
		cs.handover_to,
		cs.status,
		cs.notes,
		cs.created_at,
		cs.updated_at,
		u.full_name,
		u2.full_name,
		u3.full_name
	FROM cashier_shifts cs
	LEFT JOIN users u ON cs.opened_by = u.id
	LEFT JOIN users u2 ON cs.closed_by = u2.id
	LEFT JOIN users u3 ON cs.handover_to = u3.id
`

func cashierShiftToResponse(row *cashierShiftRow) map[string]interface{} {
	response := map[string]interface{}{
		"id":           row.ID,
		"opened_by":    row.OpenedBy,
		"opened_at":    row.OpenedAt,
		"opening_cash": row.OpeningCash,
		"previous_shift_id": func() interface{} {
			if row.PreviousShift.Valid {
				return row.PreviousShift.String
			}
			return nil
		}(),
		"handover_to": func() interface{} {
			if row.HandoverTo.Valid {
				return row.HandoverTo.String
			}
			return nil
		}(),
		"status":     row.Status,
		"created_at": row.CreatedAt,
		"updated_at": row.UpdatedAt,
		"opened_by_name": func() interface{} {
			if row.OpenedByName.Valid {
				return row.OpenedByName.String
			}
			return nil
		}(),
		"closed_at": func() interface{} {
			if row.ClosedAt.Valid {
				return row.ClosedAt.Time
			}
			return nil
		}(),
		"closed_by": func() interface{} {
			if row.ClosedBy.Valid {
				return row.ClosedBy.String
			}
			return nil
		}(),
		"closing_cash": func() interface{} {
			if row.ClosingCash.Valid {
				return row.ClosingCash.Float64
			}
			return nil
		}(),
		"closing_card": func() interface{} {
			if row.ClosingCard.Valid {
				return row.ClosingCard.Float64
			}
			return nil
		}(),
		"closing_qris": func() interface{} {
			if row.ClosingQris.Valid {
				return row.ClosingQris.Float64
			}
			return nil
		}(),
		"closing_transfer": func() interface{} {
			if row.ClosingTransfer.Valid {
				return row.ClosingTransfer.Float64
			}
			return nil
		}(),
		"carry_over_cash": func() interface{} {
			if row.CarryOverCash.Valid {
				return row.CarryOverCash.Float64
			}
			return nil
		}(),
		"closed_by_name": func() interface{} {
			if row.ClosedByName.Valid {
				return row.ClosedByName.String
			}
			return nil
		}(),
		"handover_to_name": func() interface{} {
			if row.HandoverToName.Valid {
				return row.HandoverToName.String
			}
			return nil
		}(),
		"notes": func() interface{} {
			if row.Notes.Valid {
				return row.Notes.String
			}
			return nil
		}(),
	}
	return response
}

func (h *TransactionHandler) CreateTransaction(c *echo.Context) error {
	var req CreateTransactionRequest
	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	claims, err := middleware.GetUserFromContext(c)
	if err != nil {
		return UnauthorizedResponse(c, "User tidak terautentikasi")
	}

	transaction, err := h.transactionService.CreateTransaction((*c).Request().Context(), req.OrderID, req.TotalAmount, req.PaymentMethod, req.Items, claims.UserID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal membuat transaksi: "+err.Error())
	}

	return CreatedResponse(c, "Transaksi berhasil dibuat", transaction)
}

func (h *TransactionHandler) GetTransaction(c *echo.Context) error {
	id := c.Param("id")

	transaction, err := h.transactionService.GetTransactionByID((*c).Request().Context(), id)
	if err != nil {
		if err == sql.ErrNoRows {
			return c.JSON(http.StatusNotFound, map[string]string{"error": "Transaksi tidak ditemukan"})
		}
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, transaction)
}

func (h *TransactionHandler) GetAllTransactions(c *echo.Context) error {
	params := GetPaginationParams(c)
	startDateStr := c.QueryParam("start_date")
	endDateStr := c.QueryParam("end_date")

	if startDateStr != "" || endDateStr != "" {
		startDate, endDate, err := parseDateRangeWithLimit(startDateStr, endDateStr, 3)
		if err != nil {
			return BadRequestResponse(c, err.Error())
		}
		transactions, total, err := h.transactionService.GetTransactionsByDateRangePaginated(
			(*c).Request().Context(),
			startDate,
			endDate,
			int64(params.PageSize),
			int64(params.Offset),
		)
		if err != nil {
			return InternalErrorResponse(c, "Gagal mengambil data transaksi: "+err.Error())
		}
		pagination := CalculatePagination(params.Page, params.PageSize, total)
		return PaginatedSuccessResponse(c, "Data transaksi berhasil diambil", transactions, pagination)
	}

	transactions, total, err := h.transactionService.GetTransactionsPaginated((*c).Request().Context(), int64(params.PageSize), int64(params.Offset))
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data transaksi: "+err.Error())
	}

	pagination := CalculatePagination(params.Page, params.PageSize, total)
	return PaginatedSuccessResponse(c, "Data transaksi berhasil diambil", transactions, pagination)
}
func (h *TransactionHandler) GetTransactionsByDateRange(c *echo.Context) error {
	startDateStr := c.QueryParam("start_date")
	endDateStr := c.QueryParam("end_date")

	startDate, endDate, err := parseDateRangeWithLimit(startDateStr, endDateStr, 3)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	}

	transactions, err := h.transactionService.GetTransactionsByDateRange((*c).Request().Context(), startDate, endDate)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil transaksi: "+err.Error())
	}

	return SuccessResponse(c, "Data transaksi berhasil diambil", transactions)
}

func (h *TransactionHandler) GetCashierShiftState(c *echo.Context) error {
	ctx := (*c).Request().Context()
	state := map[string]interface{}{
		"open_shift":        nil,
		"last_closed_shift": nil,
	}

	openShift, err := h.getOpenCashierShift(ctx)
	if err != nil && err != sql.ErrNoRows {
		return InternalErrorResponse(c, "Gagal mengambil data shift kasir")
	}
	if err == nil {
		summary, err := h.getShiftPaymentSummary(ctx, openShift.OpenedAt, time.Now(), openShift.OpenedBy)
		if err != nil {
			return InternalErrorResponse(c, "Gagal menghitung ringkasan penjualan")
		}
		voidSummary, err := h.getShiftVoidSummary(ctx, openShift.OpenedAt, time.Now(), openShift.OpenedBy)
		if err != nil {
			return InternalErrorResponse(c, "Gagal mengambil data VOID")
		}
		cancelSummary, err := h.getShiftCancelledSummary(ctx, openShift.OpenedAt, time.Now())
		if err != nil {
			return InternalErrorResponse(c, "Gagal mengambil data pembatalan transaksi")
		}
		openShiftResponse := cashierShiftToResponse(openShift)
		openShiftResponse["sales_summary"] = summary
		openShiftResponse["void_summary"] = voidSummary
		openShiftResponse["cancelled_summary"] = cancelSummary
		cashMovements, err := h.getShiftCashMovements(ctx, openShift.ID)
		if err != nil {
			return InternalErrorResponse(c, "Gagal mengambil data uang masuk/keluar")
		}
		openShiftResponse["cash_movements"] = cashMovements
		state["open_shift"] = openShiftResponse
	}

	lastClosed, err := h.getLastClosedCashierShift(ctx)
	if err != nil && err != sql.ErrNoRows {
		return InternalErrorResponse(c, "Gagal mengambil data shift kasir")
	}
	if err == nil {
		lastClosedResponse := cashierShiftToResponse(lastClosed)
		endTime := time.Now()
		if lastClosed.ClosedAt.Valid {
			endTime = lastClosed.ClosedAt.Time
		}
		voidSummary, err := h.getShiftVoidSummary(ctx, lastClosed.OpenedAt, endTime, lastClosed.OpenedBy)
		if err != nil {
			return InternalErrorResponse(c, "Gagal mengambil data VOID")
		}
		cancelSummary, err := h.getShiftCancelledSummary(ctx, lastClosed.OpenedAt, endTime)
		if err != nil {
			return InternalErrorResponse(c, "Gagal mengambil data pembatalan transaksi")
		}
		cashMovements, err := h.getShiftCashMovements(ctx, lastClosed.ID)
		if err != nil {
			return InternalErrorResponse(c, "Gagal mengambil data uang masuk/keluar")
		}
		lastClosedResponse["cash_movements"] = cashMovements
		lastClosedResponse["void_summary"] = voidSummary
		lastClosedResponse["cancelled_summary"] = cancelSummary
		state["last_closed_shift"] = lastClosedResponse
	}

	return SuccessResponse(c, "Data shift kasir berhasil diambil", state)
}

func (h *TransactionHandler) OpenCashierShift(c *echo.Context) error {
	claims, err := middleware.GetUserFromContext(c)
	if err != nil {
		return UnauthorizedResponse(c, "User tidak terautentikasi")
	}

	var req OpenCashierShiftRequest
	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	if req.OpeningCash != nil && *req.OpeningCash < 0 {
		return BadRequestResponse(c, "Uang modal tidak valid")
	}

	ctx := (*c).Request().Context()
	existingShift, err := h.getOpenCashierShift(ctx)
	if err == nil && existingShift != nil {
		return ErrorResponse(c, http.StatusConflict, "Shift kasir masih terbuka")
	}
	if err != nil && err != sql.ErrNoRows {
		return InternalErrorResponse(c, "Gagal memeriksa shift kasir")
	}

	openingCash := 0.0
	if req.OpeningCash != nil {
		openingCash = *req.OpeningCash
	}
	var previousShiftID interface{}
	lastClosed, err := h.getLastClosedCashierShift(ctx)
	if err == nil {
		previousShiftID = lastClosed.ID
		if req.OpeningCash == nil && lastClosed.CarryOverCash.Valid {
			openingCash = lastClosed.CarryOverCash.Float64
		}
	} else if err != sql.ErrNoRows {
		return InternalErrorResponse(c, "Gagal memeriksa shift kasir")
	}

	shiftID := utils.GenerateULID()
	_, err = h.db.ExecContext(ctx, `
		INSERT INTO cashier_shifts (
			id,
			opened_by,
			opening_cash,
			status,
			opened_at,
			previous_shift_id,
			created_at,
			updated_at
		)
		VALUES (?, ?, ?, 'open', CURRENT_TIMESTAMP, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
	`, shiftID, claims.UserID, openingCash, previousShiftID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal membuka shift kasir")
	}

	shift, err := h.getCashierShiftByID(ctx, shiftID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data shift kasir")
	}

	return CreatedResponse(c, "Shift kasir dibuka", cashierShiftToResponse(shift))
}

func (h *TransactionHandler) CloseCashierShift(c *echo.Context) error {
	claims, err := middleware.GetUserFromContext(c)
	if err != nil {
		return UnauthorizedResponse(c, "User tidak terautentikasi")
	}

	var req CloseCashierShiftRequest
	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	ctx := (*c).Request().Context()
	openShift, err := h.getOpenCashierShift(ctx)
	if err != nil {
		if err == sql.ErrNoRows {
			return BadRequestResponse(c, "Tidak ada shift kasir yang terbuka")
		}
		return InternalErrorResponse(c, "Gagal memeriksa shift kasir")
	}
	pendingCount, err := h.getPendingOrdersCount(ctx)
	if err != nil {
		return InternalErrorResponse(c, "Gagal memeriksa transaksi pending")
	}
	if pendingCount > 0 {
		return BadRequestResponse(c, "Masih ada transaksi yang belum dibayar. Selesaikan transaksi sebelum tutup shift")
	}

	now := time.Now()
	startTime := openShift.OpenedAt
	summary, err := h.getShiftPaymentSummary(ctx, startTime, now, openShift.OpenedBy)
	if err != nil {
		return InternalErrorResponse(c, "Gagal menghitung ringkasan penjualan")
	}

	voidSummary, err := h.getShiftVoidSummary(ctx, startTime, now, openShift.OpenedBy)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data VOID")
	}

	cancelSummary, err := h.getShiftCancelledSummary(ctx, startTime, now)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data pembatalan transaksi")
	}

	cashMovements, err := h.getShiftCashMovements(ctx, openShift.ID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data uang masuk/keluar")
	}
	carryOverCash := openShift.OpeningCash + summary.Cash + cashMovements.TotalIn - cashMovements.TotalOut

	tx, err := h.db.BeginTx(ctx, nil)
	if err != nil {
		return InternalErrorResponse(c, "Gagal menutup shift kasir")
	}

	result, err := tx.ExecContext(ctx, `
		UPDATE cashier_shifts
		SET
			status = 'closed',
			closed_at = CURRENT_TIMESTAMP,
			closed_by = ?,
			closing_cash = ?,
			closing_card = ?,
			closing_qris = ?,
			closing_transfer = ?,
			carry_over_cash = ?,
			updated_at = CURRENT_TIMESTAMP
		WHERE id = ? AND status = 'open'
	`, claims.UserID, summary.Cash, summary.Card, summary.Qris, summary.Transfer, carryOverCash, openShift.ID)
	if err != nil {
		_ = tx.Rollback()
		return InternalErrorResponse(c, "Gagal menutup shift kasir")
	}

	affected, err := result.RowsAffected()
	if err == nil && affected == 0 {
		_ = tx.Rollback()
		return BadRequestResponse(c, "Shift kasir sudah ditutup")
	}

	if err := tx.Commit(); err != nil {
		return InternalErrorResponse(c, "Gagal menyimpan tutup shift kasir")
	}

	shift, err := h.getCashierShiftByID(ctx, openShift.ID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data shift kasir")
	}

	h.enqueueCloseShiftReceipt(ctx, openShift, summary, voidSummary, cancelSummary, openShift.ID, cashMovements.CashIn, cashMovements.CashOut)

	shiftResponse := cashierShiftToResponse(shift)
	shiftResponse["cash_movements"] = cashMovements

	return SuccessResponse(c, "Shift kasir ditutup", shiftResponse)
}

func (h *TransactionHandler) HandoverCashierShift(c *echo.Context) error {
	claims, err := middleware.GetUserFromContext(c)
	if err != nil {
		return UnauthorizedResponse(c, "User tidak terautentikasi")
	}

	var req HandoverCashierShiftRequest
	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	if req.NextCashierID == "" {
		return BadRequestResponse(c, "Kasir tujuan wajib dipilih")
	}
	if len(req.CurrentCashierPIN) != 4 || len(req.NextCashierPIN) != 4 {
		return BadRequestResponse(c, "PIN harus tepat 4 digit")
	}
	for _, char := range req.CurrentCashierPIN {
		if char < '0' || char > '9' {
			return BadRequestResponse(c, "PIN harus berupa angka")
		}
	}
	for _, char := range req.NextCashierPIN {
		if char < '0' || char > '9' {
			return BadRequestResponse(c, "PIN harus berupa angka")
		}
	}

	ctx := (*c).Request().Context()
	nextUser, err := h.queries.GetUserByID(ctx, req.NextCashierID)
	if err != nil {
		if err == sql.ErrNoRows {
			return NotFoundResponse(c, "Kasir tujuan tidak ditemukan")
		}
		return InternalErrorResponse(c, "Gagal mendapatkan data kasir tujuan")
	}

	if nextUser.IsActive == 0 || nextUser.Role != "cashier" {
		return BadRequestResponse(c, "Kasir tujuan tidak valid")
	}

	openShift, err := h.getOpenCashierShift(ctx)
	if err != nil {
		if err == sql.ErrNoRows {
			return BadRequestResponse(c, "Tidak ada shift kasir yang terbuka")
		}
		return InternalErrorResponse(c, "Gagal memeriksa shift kasir")
	}
	pendingCount, err := h.getPendingOrdersCount(ctx)
	if err != nil {
		return InternalErrorResponse(c, "Gagal memeriksa transaksi pending")
	}
	if pendingCount > 0 {
		return BadRequestResponse(c, "Masih ada transaksi yang belum dibayar. Selesaikan transaksi sebelum serah terima")
	}
	currentCashierID := openShift.OpenedBy
	if claims.Role == "admin" || claims.Role == "manager" {
		currentCashierID = claims.UserID
	}
	if req.NextCashierID == currentCashierID {
		return BadRequestResponse(c, "Kasir tujuan harus berbeda")
	}

	currentCashier, err := h.queries.GetUserByID(ctx, currentCashierID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mendapatkan data kasir saat ini")
	}
	if currentCashier.IsActive == 0 {
		return BadRequestResponse(c, "Kasir saat ini tidak aktif")
	}
	currentPinValid := bcrypt.CompareHashAndPassword([]byte(currentCashier.PasswordHash), []byte(req.CurrentCashierPIN)) == nil
	nextPinValid := bcrypt.CompareHashAndPassword([]byte(nextUser.PasswordHash), []byte(req.NextCashierPIN)) == nil
	if !currentPinValid && !nextPinValid {
		return UnauthorizedResponse(c, "PIN kasir saat ini dan kasir tujuan salah")
	}
	if !currentPinValid {
		return UnauthorizedResponse(c, "PIN kasir saat ini salah")
	}
	if !nextPinValid {
		return UnauthorizedResponse(c, "PIN kasir tujuan salah")
	}

	now := time.Now()
	startTime := openShift.OpenedAt
	summary, err := h.getShiftPaymentSummary(ctx, startTime, now, openShift.OpenedBy)
	if err != nil {
		return InternalErrorResponse(c, "Gagal menghitung ringkasan penjualan")
	}

	voidSummary, err := h.getShiftVoidSummary(ctx, startTime, now, openShift.OpenedBy)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data VOID")
	}

	cancelSummary, err := h.getShiftCancelledSummary(ctx, startTime, now)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data pembatalan transaksi")
	}

	cashMovements, err := h.getShiftCashMovements(ctx, openShift.ID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data uang masuk/keluar")
	}

	tx, err := h.db.BeginTx(ctx, nil)
	if err != nil {
		return InternalErrorResponse(c, "Gagal memulai proses serah terima")
	}

	shiftID := utils.GenerateULID()
	carryOverCash := openShift.OpeningCash + summary.Cash + cashMovements.TotalIn - cashMovements.TotalOut

	_, err = tx.ExecContext(ctx, `
		UPDATE cashier_shifts
		SET
			status = 'closed',
			closed_at = CURRENT_TIMESTAMP,
			closed_by = ?,
			closing_cash = ?,
			closing_card = ?,
			closing_qris = ?,
			closing_transfer = ?,
			carry_over_cash = ?,
			handover_to = ?,
			updated_at = CURRENT_TIMESTAMP
		WHERE id = ? AND status = 'open'
	`, currentCashierID, summary.Cash, summary.Card, summary.Qris, summary.Transfer, carryOverCash, req.NextCashierID, openShift.ID)
	if err != nil {
		_ = tx.Rollback()
		return InternalErrorResponse(c, "Gagal menutup shift kasir")
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO cashier_shifts (
			id,
			opened_by,
			opening_cash,
			status,
			opened_at,
			previous_shift_id,
			created_at,
			updated_at
		)
		VALUES (?, ?, ?, 'open', CURRENT_TIMESTAMP, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
	`, shiftID, req.NextCashierID, carryOverCash, openShift.ID)
	if err != nil {
		_ = tx.Rollback()
		return InternalErrorResponse(c, "Gagal membuka shift kasir baru")
	}

	if err := tx.Commit(); err != nil {
		return InternalErrorResponse(c, "Gagal menyimpan serah terima kasir")
	}

	newShift, err := h.getCashierShiftByID(ctx, shiftID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data shift kasir")
	}

	h.enqueueHandoverReceipt(ctx, openShift, nextUser, summary, voidSummary, cancelSummary, shiftID, cashMovements.CashIn, cashMovements.CashOut)

	token, err := middleware.GenerateToken(&nextUser)
	if err != nil {
		return InternalErrorResponse(c, "Gagal generate token kasir baru")
	}

	return SuccessResponse(c, "Serah terima kasir berhasil", map[string]interface{}{
		"shift": cashierShiftToResponse(newShift),
		"auth": AuthResponse{
			Token: token,
			User:  toUserResponse(&nextUser),
		},
	})
}

func (h *TransactionHandler) CreateCashMovement(c *echo.Context) error {
	_, err := middleware.GetUserFromContext(c)
	if err != nil {
		return UnauthorizedResponse(c, "User tidak terautentikasi")
	}

	var req CreateCashMovementRequest
	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	req.Name = strings.TrimSpace(req.Name)
	req.Note = strings.TrimSpace(req.Note)
	if req.Name == "" {
		return BadRequestResponse(c, "Nama harus diisi")
	}
	if req.Amount <= 0 {
		return BadRequestResponse(c, "Nominal harus lebih dari 0")
	}
	if req.Type != "in" && req.Type != "out" {
		return BadRequestResponse(c, "Tipe uang harus in atau out")
	}
	if req.Type == "out" && req.Note == "" {
		return BadRequestResponse(c, "Keterangan harus diisi")
	}

	ctx := (*c).Request().Context()
	openShift, err := h.getOpenCashierShift(ctx)
	if err != nil {
		if err == sql.ErrNoRows {
			return BadRequestResponse(c, "Tidak ada shift kasir yang terbuka")
		}
		return InternalErrorResponse(c, "Gagal memeriksa shift kasir")
	}

	movementID := utils.GenerateULID()
	_, err = h.db.ExecContext(ctx, `
		INSERT INTO cashier_cash_movements (
			id,
			shift_id,
			movement_type,
			amount,
			counterpart_name,
			note,
			created_at
		)
		VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
	`, movementID, openShift.ID, req.Type, req.Amount, req.Name, req.Note)
	if err != nil {
		return InternalErrorResponse(c, "Gagal menyimpan uang masuk/keluar")
	}

	if req.Type == "in" {
		h.enqueueCashInReceipt(ctx, openShift, movementID, req.Name, req.Amount)
	} else {
		h.enqueueCashOutReceipt(ctx, openShift, movementID, req.Name, req.Note, req.Amount)
	}

	cashMovements, err := h.getShiftCashMovements(ctx, openShift.ID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data uang masuk/keluar")
	}

	return CreatedResponse(c, "Uang masuk/keluar tersimpan", cashMovements)
}

func (h *TransactionHandler) ListCashierUsers(c *echo.Context) error {
	ctx := (*c).Request().Context()
	rows, err := h.db.QueryContext(ctx, `
		SELECT id, full_name
		FROM users
		WHERE role = 'cashier' AND is_active = 1
		ORDER BY full_name
	`)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil daftar kasir")
	}
	defer rows.Close()

	type cashierUser struct {
		ID       string `json:"id"`
		FullName string `json:"full_name"`
	}

	users := []cashierUser{}
	for rows.Next() {
		var user cashierUser
		if err := rows.Scan(&user.ID, &user.FullName); err != nil {
			return InternalErrorResponse(c, "Gagal mengambil daftar kasir")
		}
		users = append(users, user)
	}

	if err := rows.Err(); err != nil {
		return InternalErrorResponse(c, "Gagal mengambil daftar kasir")
	}

	return SuccessResponse(c, "Daftar kasir berhasil diambil", users)
}

func (h *TransactionHandler) enqueueHandoverReceipt(ctx context.Context, openShift *cashierShiftRow, nextUser db.User, summary shiftPaymentSummary, voidSummary shiftVoidSummary, cancelSummary shiftCancelledSummary, shiftID string, cashIns []cashMovementItem, cashOuts []cashMovementItem) {
	printerID, ok := h.getReceiptPrinterID(ctx)
	if !ok {
		return
	}

	fromName := ""
	if openShift.OpenedByName.Valid {
		fromName = openShift.OpenedByName.String
	}

	toPrintMovements := func(items []cashMovementItem) []workers.CashMovementData {
		printItems := make([]workers.CashMovementData, 0, len(items))
		for _, item := range items {
			printItems = append(printItems, workers.CashMovementData{
				Name:   item.Name,
				Amount: int(math.Round(item.Amount)),
			})
		}
		return printItems
	}

	payload := workers.PrintJobData{
		ReceiptNumber:   "SHIFT-" + shiftID,
		DateTime:        time.Now(),
		IsHandover:      true,
		HandoverFrom:    fromName,
		HandoverTo:      nextUser.FullName,
		OpeningCash:     int(math.Round(openShift.OpeningCash)),
		ClosingCash:     int(math.Round(summary.Cash)),
		ClosingCard:     int(math.Round(summary.Card)),
		ClosingQris:     int(math.Round(summary.Qris)),
		ClosingTransfer: int(math.Round(summary.Transfer)),
		VoidedCount:     voidSummary.Count,
		VoidedTotal:     int(math.Round(voidSummary.Total)),
		CancelledCount:  cancelSummary.Count,
		CancelledTotal:  int(math.Round(cancelSummary.Total)),
		CashIns:         toPrintMovements(cashIns),
		CashOuts:        toPrintMovements(cashOuts),
	}

	payloadJSON, err := json.Marshal(payload)
	if err != nil {
		return
	}

	_, _ = h.queries.CreatePrintJob(ctx, db.CreatePrintJobParams{
		ID:        utils.GenerateULID(),
		PrinterID: printerID,
		Data:      string(payloadJSON),
	})
}

func (h *TransactionHandler) enqueueCloseShiftReceipt(ctx context.Context, openShift *cashierShiftRow, summary shiftPaymentSummary, voidSummary shiftVoidSummary, cancelSummary shiftCancelledSummary, shiftID string, cashIns []cashMovementItem, cashOuts []cashMovementItem) {
	printerID, ok := h.getReceiptPrinterID(ctx)
	if !ok {
		return
	}

	cashierName := ""
	if openShift.OpenedByName.Valid {
		cashierName = openShift.OpenedByName.String
	}

	toPrintMovements := func(items []cashMovementItem) []workers.CashMovementData {
		printItems := make([]workers.CashMovementData, 0, len(items))
		for _, item := range items {
			printItems = append(printItems, workers.CashMovementData{
				Name:   item.Name,
				Amount: int(math.Round(item.Amount)),
			})
		}
		return printItems
	}

	payload := workers.PrintJobData{
		ReceiptNumber:   "SHIFT-" + shiftID,
		DateTime:        time.Now(),
		IsCloseShift:    true,
		CashierName:     cashierName,
		OpeningCash:     int(math.Round(openShift.OpeningCash)),
		ClosingCash:     int(math.Round(summary.Cash)),
		ClosingCard:     int(math.Round(summary.Card)),
		ClosingQris:     int(math.Round(summary.Qris)),
		ClosingTransfer: int(math.Round(summary.Transfer)),
		VoidedCount:     voidSummary.Count,
		VoidedTotal:     int(math.Round(voidSummary.Total)),
		CancelledCount:  cancelSummary.Count,
		CancelledTotal:  int(math.Round(cancelSummary.Total)),
		CashIns:         toPrintMovements(cashIns),
		CashOuts:        toPrintMovements(cashOuts),
	}

	payloadJSON, err := json.Marshal(payload)
	if err != nil {
		return
	}

	_, _ = h.queries.CreatePrintJob(ctx, db.CreatePrintJobParams{
		ID:        utils.GenerateULID(),
		PrinterID: printerID,
		Data:      string(payloadJSON),
	})
}

func (h *TransactionHandler) enqueueCashInReceipt(ctx context.Context, openShift *cashierShiftRow, movementID string, counterpart string, amount float64) {
	printerID, ok := h.getReceiptPrinterID(ctx)
	if !ok {
		return
	}

	cashierName := ""
	if openShift.OpenedByName.Valid {
		cashierName = openShift.OpenedByName.String
	}

	payload := workers.PrintJobData{
		ReceiptNumber:   "IN-" + movementID,
		DateTime:        time.Now(),
		IsCashInReceipt: true,
		CashierName:     cashierName,
		MovementName:    counterpart,
		MovementAmount:  int(math.Round(amount)),
	}

	payloadJSON, err := json.Marshal(payload)
	if err != nil {
		return
	}

	_, _ = h.queries.CreatePrintJob(ctx, db.CreatePrintJobParams{
		ID:        utils.GenerateULID(),
		PrinterID: printerID,
		Data:      string(payloadJSON),
	})
}

func (h *TransactionHandler) enqueueCashOutReceipt(ctx context.Context, openShift *cashierShiftRow, movementID string, recipient string, note string, amount float64) {
	printerID, ok := h.getReceiptPrinterID(ctx)
	if !ok {
		return
	}

	cashierName := ""
	if openShift.OpenedByName.Valid {
		cashierName = openShift.OpenedByName.String
	}

	payload := workers.PrintJobData{
		ReceiptNumber:    "OUT-" + movementID,
		DateTime:         time.Now(),
		IsCashOutReceipt: true,
		CashierName:      cashierName,
		MovementName:     recipient,
		MovementNote:     note,
		MovementAmount:   int(math.Round(amount)),
	}

	payloadJSON, err := json.Marshal(payload)
	if err != nil {
		return
	}

	_, _ = h.queries.CreatePrintJob(ctx, db.CreatePrintJobParams{
		ID:        utils.GenerateULID(),
		PrinterID: printerID,
		Data:      string(payloadJSON),
	})
}

func (h *TransactionHandler) getReceiptPrinterID(ctx context.Context) (string, bool) {
	strukPrinters, err := h.queries.ListPrintersByType(ctx, "struk")
	if err == nil && len(strukPrinters) > 0 {
		return strukPrinters[0].ID, true
	}

	cashierPrinters, err := h.queries.ListPrintersByType(ctx, "cashier")
	if err == nil && len(cashierPrinters) > 0 {
		return cashierPrinters[0].ID, true
	}

	return "", false
}

func (h *TransactionHandler) getCashierShiftByQuery(ctx context.Context, query string, args ...interface{}) (*cashierShiftRow, error) {
	row := h.db.QueryRowContext(ctx, query, args...)
	var shift cashierShiftRow
	err := row.Scan(
		&shift.ID,
		&shift.OpenedBy,
		&shift.OpenedAt,
		&shift.OpeningCash,
		&shift.ClosedAt,
		&shift.ClosedBy,
		&shift.ClosingCash,
		&shift.ClosingCard,
		&shift.ClosingQris,
		&shift.ClosingTransfer,
		&shift.CarryOverCash,
		&shift.PreviousShift,
		&shift.HandoverTo,
		&shift.Status,
		&shift.Notes,
		&shift.CreatedAt,
		&shift.UpdatedAt,
		&shift.OpenedByName,
		&shift.ClosedByName,
		&shift.HandoverToName,
	)
	if err != nil {
		return nil, err
	}
	return &shift, nil
}

func (h *TransactionHandler) getOpenCashierShift(ctx context.Context) (*cashierShiftRow, error) {
	return h.getCashierShiftByQuery(ctx, cashierShiftSelect+" WHERE cs.status = 'open' ORDER BY cs.opened_at DESC LIMIT 1")
}

func (h *TransactionHandler) getLastClosedCashierShift(ctx context.Context) (*cashierShiftRow, error) {
	return h.getCashierShiftByQuery(ctx, cashierShiftSelect+" WHERE cs.status = 'closed' ORDER BY cs.closed_at DESC LIMIT 1")
}

func (h *TransactionHandler) getCashierShiftByID(ctx context.Context, shiftID string) (*cashierShiftRow, error) {
	return h.getCashierShiftByQuery(ctx, cashierShiftSelect+" WHERE cs.id = ?", shiftID)
}

func (h *TransactionHandler) getPendingOrdersCount(ctx context.Context) (int, error) {
	row := h.db.QueryRowContext(ctx, `
		SELECT COALESCE(COUNT(*), 0)
		FROM orders
		WHERE payment_status != 'paid'
		AND is_merged = 0
		AND voided_at IS NULL
	`)
	var count int
	if err := row.Scan(&count); err != nil {
		return 0, err
	}
	return count, nil
}

func (h *TransactionHandler) getShiftPaymentSummary(ctx context.Context, start time.Time, end time.Time, cashierID string) (shiftPaymentSummary, error) {
	row := h.db.QueryRowContext(ctx, `
		SELECT
			COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN amount ELSE 0 END), 0) AS cash,
			COALESCE(SUM(CASE WHEN payment_method = 'card' THEN amount ELSE 0 END), 0) AS card,
			COALESCE(SUM(CASE WHEN payment_method = 'qris' THEN amount ELSE 0 END), 0) AS qris,
			COALESCE(SUM(CASE WHEN payment_method = 'transfer' THEN amount ELSE 0 END), 0) AS transfer
		FROM (
			SELECT payment_method, amount, created_by, created_at
			FROM payments
			UNION ALL
			SELECT payment_method, total_amount AS amount, created_by, transaction_date AS created_at
			FROM transactions
			WHERE cancelled_at IS NULL
		) t
		WHERE created_at BETWEEN ? AND ? AND created_by = ?
	`, start, end, cashierID)
	summary := shiftPaymentSummary{}
	if err := row.Scan(&summary.Cash, &summary.Card, &summary.Qris, &summary.Transfer); err != nil {
		return summary, err
	}
	summary.Total = summary.Cash + summary.Card + summary.Qris + summary.Transfer
	return summary, nil
}

type shiftVoidSummary struct {
	Count int     `json:"count"`
	Total float64 `json:"total"`
}

type shiftCancelledSummary struct {
	Count int     `json:"count"`
	Total float64 `json:"total"`
}

func (h *TransactionHandler) getShiftVoidSummary(ctx context.Context, start time.Time, end time.Time, cashierID string) (shiftVoidSummary, error) {
	row := h.db.QueryRowContext(ctx, `
		SELECT
			COALESCE(COUNT(*), 0) AS total_count,
			COALESCE(SUM(total_amount), 0) AS total_amount
		FROM orders
		WHERE voided_at IS NOT NULL
		AND voided_at BETWEEN ? AND ?
		AND voided_by = ?
	`, start, end, cashierID)
	summary := shiftVoidSummary{}
	if err := row.Scan(&summary.Count, &summary.Total); err != nil {
		return summary, err
	}
	return summary, nil
}

func (h *TransactionHandler) getShiftCancelledSummary(ctx context.Context, start time.Time, end time.Time) (shiftCancelledSummary, error) {
	row := h.db.QueryRowContext(ctx, `
		SELECT
			COALESCE(COUNT(*), 0) AS total_count,
			COALESCE(SUM(total_amount), 0) AS total_amount
		FROM transactions
		WHERE cancelled_at IS NOT NULL
		AND cancelled_at BETWEEN ? AND ?
	`, start, end)
	summary := shiftCancelledSummary{}
	if err := row.Scan(&summary.Count, &summary.Total); err != nil {
		return summary, err
	}
	return summary, nil
}

type cashMovementItem struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	Note      string    `json:"note"`
	Amount    float64   `json:"amount"`
	CreatedAt time.Time `json:"created_at"`
}

type cashMovementsSummary struct {
	CashIn   []cashMovementItem `json:"cash_in"`
	CashOut  []cashMovementItem `json:"cash_out"`
	TotalIn  float64            `json:"total_in"`
	TotalOut float64            `json:"total_out"`
}

func (h *TransactionHandler) getShiftCashMovements(ctx context.Context, shiftID string) (cashMovementsSummary, error) {
	rows, err := h.db.QueryContext(ctx, `
		SELECT id, movement_type, amount, counterpart_name, note, created_at
		FROM cashier_cash_movements
		WHERE shift_id = ?
		ORDER BY created_at ASC
	`, shiftID)
	if err != nil {
		return cashMovementsSummary{}, err
	}
	defer rows.Close()

	summary := cashMovementsSummary{
		CashIn:  []cashMovementItem{},
		CashOut: []cashMovementItem{},
	}
	totalIn := 0.0
	totalOut := 0.0
	for rows.Next() {
		var id string
		var movementType string
		var amount float64
		var name string
		var note string
		var createdAt time.Time
		if err := rows.Scan(&id, &movementType, &amount, &name, &note, &createdAt); err != nil {
			return cashMovementsSummary{}, err
		}
		item := cashMovementItem{
			ID:        id,
			Name:      name,
			Note:      note,
			Amount:    amount,
			CreatedAt: createdAt,
		}
		switch movementType {
		case "in":
			summary.CashIn = append(summary.CashIn, item)
			totalIn += amount
		case "out":
			summary.CashOut = append(summary.CashOut, item)
			totalOut += amount
		}
	}
	if err := rows.Err(); err != nil {
		return cashMovementsSummary{}, err
	}
	summary.TotalIn = totalIn
	summary.TotalOut = totalOut
	return summary, nil
}

func parseDateRangeWithLimit(startDateStr string, endDateStr string, maxMonths int) (time.Time, time.Time, error) {
	if startDateStr == "" || endDateStr == "" {
		return time.Time{}, time.Time{}, errors.New("start_date dan end_date wajib diisi (format: YYYY-MM-DD)")
	}

	startDate, err := time.Parse("2006-01-02", startDateStr)
	if err != nil {
		return time.Time{}, time.Time{}, errors.New("format start_date tidak valid, gunakan YYYY-MM-DD")
	}

	endDate, err := time.Parse("2006-01-02", endDateStr)
	if err != nil {
		return time.Time{}, time.Time{}, errors.New("format end_date tidak valid, gunakan YYYY-MM-DD")
	}

	if endDate.Before(startDate) {
		return time.Time{}, time.Time{}, errors.New("end_date harus sama atau setelah start_date")
	}

	maxEnd := startDate.AddDate(0, maxMonths, 0)
	if endDate.After(maxEnd) {
		return time.Time{}, time.Time{}, errors.New("rentang tanggal maksimal 3 bulan")
	}

	endDate = endDate.Add(23*time.Hour + 59*time.Minute + 59*time.Second)
	return startDate, endDate, nil
}

func (h *TransactionHandler) CancelTransaction(c *echo.Context) error {
	transactionID := c.Param("id")
	var req struct {
		ManagerPIN string `json:"manager_pin"`
		Reason     string `json:"reason"`
	}

	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}
	if len(req.ManagerPIN) != 4 {
		return BadRequestResponse(c, "PIN harus tepat 4 digit")
	}
	for _, char := range req.ManagerPIN {
		if char < '0' || char > '9' {
			return BadRequestResponse(c, "PIN harus berupa angka")
		}
	}

	managers, err := h.queries.ListActiveManagers((*c).Request().Context())
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data manager")
	}

	var managerID string
	for _, manager := range managers {
		if err := bcrypt.CompareHashAndPassword([]byte(manager.PasswordHash), []byte(req.ManagerPIN)); err == nil {
			managerID = manager.ID
			break
		}
	}
	if managerID == "" {
		return UnauthorizedResponse(c, "PIN manager salah")
	}

	if err := h.transactionService.CancelTransaction((*c).Request().Context(), transactionID, managerID, req.Reason); err != nil {
		if err == sql.ErrNoRows {
			return NotFoundResponse(c, "Transaksi tidak ditemukan")
		}
		if err == repositories.ErrTransactionAlreadyCancelled {
			return BadRequestResponse(c, "Transaksi sudah dibatalkan")
		}
		return InternalErrorResponse(c, "Gagal membatalkan transaksi: "+err.Error())
	}

	return SuccessResponse(c, "Transaksi berhasil dibatalkan", map[string]interface{}{
		"transaction_id": transactionID,
	})
}
