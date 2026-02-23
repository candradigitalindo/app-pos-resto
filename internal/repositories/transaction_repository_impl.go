package repositories

import (
	"backend/internal/db"
	"backend/pkg/utils"
	"context"
	"database/sql"
	"time"
)

type transactionRepository struct {
	queries *db.Queries
}

// NewTransactionRepository membuat instance baru dari TransactionRepository
func NewTransactionRepository(dbConn *sql.DB) TransactionRepository {
	return &transactionRepository{queries: db.New(dbConn)}
}

func (r *transactionRepository) Create(ctx context.Context, orderID string, totalAmount float64, paymentMethod, status string, transactionDate time.Time, createdBy string) (*db.Transaction, error) {
	return r.CreateWithID(ctx, utils.GenerateULID(), orderID, totalAmount, paymentMethod, status, transactionDate, createdBy)
}

func (r *transactionRepository) CreateWithID(ctx context.Context, id, orderID string, totalAmount float64, paymentMethod, status string, transactionDate time.Time, createdBy string) (*db.Transaction, error) {
	if orderID == "" {
		orderID = id
	}
	transaction, err := r.queries.CreateTransaction(ctx, db.CreateTransactionParams{
		ID:              id,
		OrderID:         orderID,
		TotalAmount:     totalAmount,
		PaymentMethod:   paymentMethod,
		Status:          status,
		TransactionDate: transactionDate,
		CreatedBy:       createdBy,
	})
	if err != nil {
		return nil, err
	}
	return &transaction, nil
}

func (r *transactionRepository) CreateItem(ctx context.Context, transactionID, productID string, quantity int64, price float64) (*db.TransactionItem, error) {
	item, err := r.queries.CreateTransactionItem(ctx, db.CreateTransactionItemParams{
		ID:            utils.GenerateULID(),
		TransactionID: transactionID,
		ProductID:     productID,
		Quantity:      quantity,
		Price:         price,
	})
	if err != nil {
		return nil, err
	}
	return &item, nil
}

func (r *transactionRepository) FindByID(ctx context.Context, id string) (*db.Transaction, error) {
	transaction, err := r.queries.GetTransaction(ctx, id)
	if err != nil {
		return nil, err
	}
	return &transaction, nil
}

func (r *transactionRepository) FindAll(ctx context.Context) ([]db.Transaction, error) {
	return r.queries.ListTransactions(ctx)
}

func (r *transactionRepository) FindPaginated(ctx context.Context, limit, offset int64) ([]db.Transaction, error) {
	return r.queries.ListTransactionsPaginated(ctx, db.ListTransactionsPaginatedParams{
		Limit:  limit,
		Offset: offset,
	})
}

func (r *transactionRepository) Count(ctx context.Context) (int64, error) {
	return r.queries.CountTransactions(ctx)
}

func (r *transactionRepository) FindByDateRange(ctx context.Context, startDate, endDate time.Time) ([]db.Transaction, error) {
	return r.queries.ListTransactionsByDateRange(ctx, db.ListTransactionsByDateRangeParams{
		FromTransactionDate: startDate,
		ToTransactionDate:   endDate,
	})
}

func (r *transactionRepository) FindByDateRangePaginated(ctx context.Context, startDate, endDate time.Time, limit, offset int64) ([]db.Transaction, error) {
	items, err := r.queries.ListTransactionsByDateRange(ctx, db.ListTransactionsByDateRangeParams{
		FromTransactionDate: startDate,
		ToTransactionDate:   endDate,
	})
	if err != nil {
		return nil, err
	}

	start := int(offset)
	if start >= len(items) || start < 0 {
		return []db.Transaction{}, nil
	}
	end := start + int(limit)
	if end > len(items) {
		end = len(items)
	}
	return items[start:end], nil
}

func (r *transactionRepository) CountByDateRange(ctx context.Context, startDate, endDate time.Time) (int64, error) {
	items, err := r.queries.ListTransactionsByDateRange(ctx, db.ListTransactionsByDateRangeParams{
		FromTransactionDate: startDate,
		ToTransactionDate:   endDate,
	})
	if err != nil {
		return 0, err
	}
	return int64(len(items)), nil
}

func (r *transactionRepository) FindItems(ctx context.Context, transactionID string) ([]db.ListTransactionItemsRow, error) {
	return r.queries.ListTransactionItems(ctx, transactionID)
}

func (r *transactionRepository) Cancel(ctx context.Context, transactionID, managerID, reason string) error {
	transaction, err := r.queries.GetTransaction(ctx, transactionID)
	if err != nil {
		return err
	}
	if transaction.Status == "cancelled" {
		return ErrTransactionAlreadyCancelled
	}

	_, err = r.queries.CancelTransaction(ctx, db.CancelTransactionParams{
		Status:       "cancelled",
		CancelledAt:  sql.NullTime{Time: time.Now(), Valid: true},
		CancelledBy:  sql.NullString{String: managerID, Valid: managerID != ""},
		CancelReason: sql.NullString{String: reason, Valid: reason != ""},
		UpdatedAt:    time.Now(),
		ID:           transactionID,
	})
	return err
}
