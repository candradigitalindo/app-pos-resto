package repositories

import (
	"backend/internal/db"
	"backend/pkg/utils"
	"context"
	"database/sql"
)

type categoryRepository struct {
	queries *db.Queries
}

// NewCategoryRepository membuat instance baru dari CategoryRepository
func NewCategoryRepository(dbConn *sql.DB) CategoryRepository {
	return &categoryRepository{queries: db.New(dbConn)}
}

func (r *categoryRepository) Create(ctx context.Context, name, description, printerID string) (*db.Category, error) {
	var nullDesc sql.NullString
	if description != "" {
		nullDesc = sql.NullString{String: description, Valid: true}
	}

	// Optional printer ID
	var nullPrinterID sql.NullString
	if printerID != "" {
		nullPrinterID = sql.NullString{String: printerID, Valid: true}
	}

	category, err := r.queries.CreateCategory(ctx, db.CreateCategoryParams{
		ID:          utils.GenerateULID(),
		Name:        name,
		Description: nullDesc,
		PrinterID:   nullPrinterID,
	})
	if err != nil {
		return nil, err
	}
	return &category, nil
}

func (r *categoryRepository) FindByID(ctx context.Context, id string) (*db.GetCategoryRow, error) {
	category, err := r.queries.GetCategory(ctx, id)
	if err != nil {
		return nil, err
	}
	return &category, nil
}

func (r *categoryRepository) FindAll(ctx context.Context) ([]db.ListCategoriesRow, error) {
	return r.queries.ListCategories(ctx)
}

func (r *categoryRepository) FindPaginated(ctx context.Context, limit, offset int64) ([]db.ListCategoriesPaginatedRow, error) {
	return r.queries.ListCategoriesPaginated(ctx, db.ListCategoriesPaginatedParams{
		Limit:  limit,
		Offset: offset,
	})
}

func (r *categoryRepository) Count(ctx context.Context) (int64, error) {
	return r.queries.CountCategories(ctx)
}

func (r *categoryRepository) Update(ctx context.Context, id string, name, description, printerID string) error {
	var nullDesc sql.NullString
	if description != "" {
		nullDesc = sql.NullString{String: description, Valid: true}
	}

	// Optional printer ID
	var nullPrinterID sql.NullString
	if printerID != "" {
		nullPrinterID = sql.NullString{String: printerID, Valid: true}
	}

	return r.queries.UpdateCategory(ctx, db.UpdateCategoryParams{
		Name:        name,
		Description: nullDesc,
		PrinterID:   nullPrinterID,
		ID:          id,
	})
}

func (r *categoryRepository) Delete(ctx context.Context, id string) error {
	return r.queries.DeleteCategory(ctx, id)
}
