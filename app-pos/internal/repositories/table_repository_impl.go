package repositories

import (
	"backend/internal/db"
	"backend/pkg/utils"
	"context"
	"database/sql"
)

type tableRepository struct {
	db *sql.DB
}

func NewTableRepository(dbConn *sql.DB) TableRepository {
	return &tableRepository{db: dbConn}
}

func (r *tableRepository) Create(ctx context.Context, tableNumber string, capacity int64) (*db.Table, error) {
	table, err := db.New(r.db).CreateTable(ctx, db.CreateTableParams{
		ID:          utils.GenerateULID(),
		TableNumber: tableNumber,
		Capacity:    capacity,
	})
	if err != nil {
		return nil, err
	}
	return &table, nil
}

func (r *tableRepository) FindAll(ctx context.Context) ([]db.Table, error) {
	return db.New(r.db).GetAllTables(ctx)
}

func (r *tableRepository) FindPaginated(ctx context.Context, limit, offset int64) ([]db.Table, error) {
	return db.New(r.db).ListTablesPaginated(ctx, db.ListTablesPaginatedParams{
		Limit:  limit,
		Offset: offset,
	})
}

func (r *tableRepository) Count(ctx context.Context) (int64, error) {
	return db.New(r.db).CountTables(ctx)
}

func (r *tableRepository) FindByID(ctx context.Context, id string) (*db.Table, error) {
	table, err := db.New(r.db).GetTableByID(ctx, id)
	if err != nil {
		return nil, err
	}
	return &table, nil
}

func (r *tableRepository) FindByNumber(ctx context.Context, tableNumber string) (*db.Table, error) {
	table, err := db.New(r.db).GetTableByNumber(ctx, tableNumber)
	if err != nil {
		return nil, err
	}
	return &table, nil
}

func (r *tableRepository) FindByStatus(ctx context.Context, status string) ([]db.Table, error) {
	return db.New(r.db).GetTablesByStatus(ctx, status)
}

func (r *tableRepository) Update(ctx context.Context, id string, tableNumber string, capacity int64) error {
	return db.New(r.db).UpdateTable(ctx, db.UpdateTableParams{
		TableNumber: tableNumber,
		Capacity:    capacity,
		ID:          id,
	})
}

func (r *tableRepository) UpdateStatus(ctx context.Context, tableNumber string, status string) error {
	return db.New(r.db).UpdateTableStatus(ctx, db.UpdateTableStatusParams{
		Status:      status,
		TableNumber: tableNumber,
	})
}

func (r *tableRepository) Delete(ctx context.Context, id string) error {
	return db.New(r.db).DeleteTable(ctx, id)
}

func (r *tableRepository) GetAvailable(ctx context.Context) ([]db.Table, error) {
	return db.New(r.db).GetAvailableTables(ctx)
}

func (r *tableRepository) GetOccupied(ctx context.Context) ([]db.Table, error) {
	return db.New(r.db).GetOccupiedTables(ctx)
}
