package repositories

import (
	"backend/internal/db"
	"context"
)

// ProductRepository adalah interface untuk operasi database product
type ProductRepository interface {
	Create(ctx context.Context, name, code, description string, price float64, stock int64, categoryID *string) (*db.Product, error)
	FindByID(ctx context.Context, id string) (*db.Product, error)
	FindAll(ctx context.Context) ([]db.Product, error)
	FindPaginated(ctx context.Context, limit, offset int64) ([]db.Product, error)
	Count(ctx context.Context) (int64, error)
	Update(ctx context.Context, id string, name, code, description string, price float64, stock int64, categoryID *string) error
	Delete(ctx context.Context, id string) error
	FindByCategory(ctx context.Context, categoryID string) ([]db.Product, error)
	SearchPaginated(ctx context.Context, search string, categoryID string, limit, offset int64) ([]db.Product, error)
	CountSearch(ctx context.Context, search string, categoryID string) (int64, error)
	CheckCodeExists(ctx context.Context, code, excludeID string) (int64, error)
}
