package repositories

import (
	"backend/internal/db"
	"context"
)

// TableRepository adalah interface untuk operasi database table
type TableRepository interface {
	Create(ctx context.Context, tableNumber string, capacity int64) (*db.Table, error)
	FindAll(ctx context.Context) ([]db.Table, error)
	FindPaginated(ctx context.Context, limit, offset int64) ([]db.Table, error)
	Count(ctx context.Context) (int64, error)
	FindByID(ctx context.Context, id string) (*db.Table, error)
	FindByNumber(ctx context.Context, tableNumber string) (*db.Table, error)
	FindByStatus(ctx context.Context, status string) ([]db.Table, error)
	Update(ctx context.Context, id string, tableNumber string, capacity int64) error
	UpdateStatus(ctx context.Context, tableNumber string, status string) error
	Delete(ctx context.Context, id string) error
	GetAvailable(ctx context.Context) ([]db.Table, error)
	GetOccupied(ctx context.Context) ([]db.Table, error)
}
