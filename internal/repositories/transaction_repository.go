package repositories

import (
	"backend/internal/db"
	"context"
	"errors"
	"time"
)

var (
	ErrTransactionAlreadyCancelled = errors.New("transaksi sudah dibatalkan")
)

// TransactionRepository adalah interface untuk operasi database transaction
type TransactionRepository interface {
	Create(ctx context.Context, orderID string, totalAmount float64, paymentMethod, status string, transactionDate time.Time, createdBy string) (*db.Transaction, error)
	CreateWithID(ctx context.Context, id, orderID string, totalAmount float64, paymentMethod, status string, transactionDate time.Time, createdBy string) (*db.Transaction, error)
	CreateItem(ctx context.Context, transactionID, productID string, quantity int64, price float64) (*db.TransactionItem, error)
	FindByID(ctx context.Context, id string) (*db.Transaction, error)
	FindAll(ctx context.Context) ([]db.Transaction, error)
	FindPaginated(ctx context.Context, limit, offset int64) ([]db.Transaction, error)
	Count(ctx context.Context) (int64, error)
	FindByDateRange(ctx context.Context, startDate, endDate time.Time) ([]db.Transaction, error)
	FindByDateRangePaginated(ctx context.Context, startDate, endDate time.Time, limit, offset int64) ([]db.Transaction, error)
	CountByDateRange(ctx context.Context, startDate, endDate time.Time) (int64, error)
	FindItems(ctx context.Context, transactionID string) ([]db.ListTransactionItemsRow, error)
	Cancel(ctx context.Context, transactionID, managerID, reason string) error
}
