package repositories

import (
	"backend/internal/db"
	"backend/pkg/utils"
	"context"
	"database/sql"
)

type productRepository struct {
	queries *db.Queries
}

// NewProductRepository membuat instance baru dari ProductRepository
func NewProductRepository(dbConn *sql.DB) ProductRepository {
	return &productRepository{queries: db.New(dbConn)}
}

func (r *productRepository) Create(ctx context.Context, name, code, description string, price float64, stock int64, categoryID *string) (*db.Product, error) {
	var nullDesc sql.NullString
	if description != "" {
		nullDesc = sql.NullString{String: description, Valid: true}
	}

	var nullCatID sql.NullString
	if categoryID != nil && *categoryID != "" {
		nullCatID = sql.NullString{String: *categoryID, Valid: true}
	}

	var nullCode sql.NullString
	if code != "" {
		nullCode = sql.NullString{String: code, Valid: true}
	}

	product, err := r.queries.CreateProduct(ctx, db.CreateProductParams{
		ID:          utils.GenerateULID(),
		Name:        name,
		Code:        nullCode,
		Description: nullDesc,
		Price:       price,
		Stock:       stock,
		CategoryID:  nullCatID,
	})
	if err != nil {
		return nil, err
	}
	return &product, nil
}

func (r *productRepository) FindByID(ctx context.Context, id string) (*db.Product, error) {
	product, err := r.queries.GetProduct(ctx, id)
	if err != nil {
		return nil, err
	}
	return &product, nil
}

func (r *productRepository) FindAll(ctx context.Context) ([]db.Product, error) {
	return r.queries.ListProducts(ctx)
}

func (r *productRepository) FindPaginated(ctx context.Context, limit, offset int64) ([]db.Product, error) {
	return r.queries.ListProductsPaginated(ctx, db.ListProductsPaginatedParams{
		Limit:  limit,
		Offset: offset,
	})
}

func (r *productRepository) Count(ctx context.Context) (int64, error) {
	return r.queries.CountProducts(ctx)
}

func (r *productRepository) Update(ctx context.Context, id string, name, code, description string, price float64, stock int64, categoryID *string) error {
	var nullDesc sql.NullString
	if description != "" {
		nullDesc = sql.NullString{String: description, Valid: true}
	}

	var nullCatID sql.NullString
	if categoryID != nil && *categoryID != "" {
		nullCatID = sql.NullString{String: *categoryID, Valid: true}
	}

	var nullCode sql.NullString
	if code != "" {
		nullCode = sql.NullString{String: code, Valid: true}
	}

	return r.queries.UpdateProduct(ctx, db.UpdateProductParams{
		Name:        name,
		Code:        nullCode,
		Description: nullDesc,
		Price:       price,
		Stock:       stock,
		CategoryID:  nullCatID,
		ID:          id,
	})
}

func (r *productRepository) Delete(ctx context.Context, id string) error {
	return r.queries.DeleteProduct(ctx, id)
}

func (r *productRepository) FindByCategory(ctx context.Context, categoryID string) ([]db.Product, error) {
	nullCatID := sql.NullString{String: categoryID, Valid: categoryID != ""}
	return r.queries.ListProductsByCategory(ctx, nullCatID)
}

func (r *productRepository) SearchPaginated(ctx context.Context, search string, categoryID string, limit, offset int64) ([]db.Product, error) {
	return r.queries.SearchProductsPaginated(ctx, db.SearchProductsPaginatedParams{
		Column1:    search,
		Column2:    sql.NullString{String: search, Valid: search != ""},
		Column3:    sql.NullString{String: search, Valid: search != ""},
		Column4:    categoryID,
		CategoryID: sql.NullString{String: categoryID, Valid: categoryID != ""},
		Limit:      limit,
		Offset:     offset,
	})
}

func (r *productRepository) CountSearch(ctx context.Context, search string, categoryID string) (int64, error) {
	return r.queries.CountSearchProducts(ctx, db.CountSearchProductsParams{
		Column1:    search,
		Column2:    sql.NullString{String: search, Valid: search != ""},
		Column3:    sql.NullString{String: search, Valid: search != ""},
		Column4:    categoryID,
		CategoryID: sql.NullString{String: categoryID, Valid: categoryID != ""},
	})
}

func (r *productRepository) CheckCodeExists(ctx context.Context, code, excludeID string) (int64, error) {
	return r.queries.CheckCodeExists(ctx, db.CheckCodeExistsParams{
		Code: sql.NullString{String: code, Valid: true},
		ID:   excludeID,
	})
}
