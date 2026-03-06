package repositories

import (
	"backend/internal/db"
	"context"
)

// CategoryRepository adalah interface untuk operasi database category
type CategoryRepository interface {
	Create(ctx context.Context, name, description, printerID string) (*db.Category, error)
	FindByID(ctx context.Context, id string) (*db.GetCategoryRow, error)
	FindAll(ctx context.Context) ([]db.ListCategoriesRow, error)
	FindPaginated(ctx context.Context, limit, offset int64) ([]db.ListCategoriesPaginatedRow, error)
	Count(ctx context.Context) (int64, error)
	Update(ctx context.Context, id string, name, description, printerID string) error
	Delete(ctx context.Context, id string) error
}
