package services

import (
	"backend/internal/db"
	"backend/internal/repositories"
	"context"
)

type TableService interface {
	CreateTable(ctx context.Context, tableNumber string, capacity int64) (*db.Table, error)
	GetAllTables(ctx context.Context) ([]db.Table, error)
	GetTablesPaginated(ctx context.Context, limit, offset int64) ([]db.Table, int64, error)
	GetTableByID(ctx context.Context, id string) (*db.Table, error)
	GetTableByNumber(ctx context.Context, tableNumber string) (*db.Table, error)
	GetTablesByStatus(ctx context.Context, status string) ([]db.Table, error)
	UpdateTable(ctx context.Context, id string, tableNumber string, capacity int64) error
	UpdateTableStatus(ctx context.Context, tableNumber string, status string) error
	DeleteTable(ctx context.Context, id string) error
	GetAvailableTables(ctx context.Context) ([]db.Table, error)
	GetOccupiedTables(ctx context.Context) ([]db.Table, error)
}

type tableService struct {
	tableRepo repositories.TableRepository
}

func NewTableService(tableRepo repositories.TableRepository) TableService {
	return &tableService{
		tableRepo: tableRepo,
	}
}

func (s *tableService) CreateTable(ctx context.Context, tableNumber string, capacity int64) (*db.Table, error) {
	return s.tableRepo.Create(ctx, tableNumber, capacity)
}

func (s *tableService) GetAllTables(ctx context.Context) ([]db.Table, error) {
	return s.tableRepo.FindAll(ctx)
}

func (s *tableService) GetTablesPaginated(ctx context.Context, limit, offset int64) ([]db.Table, int64, error) {
	tables, err := s.tableRepo.FindPaginated(ctx, limit, offset)
	if err != nil {
		return nil, 0, err
	}

	total, err := s.tableRepo.Count(ctx)
	if err != nil {
		return nil, 0, err
	}

	return tables, total, nil
}

func (s *tableService) GetTableByID(ctx context.Context, id string) (*db.Table, error) {
	return s.tableRepo.FindByID(ctx, id)
}

func (s *tableService) GetTableByNumber(ctx context.Context, tableNumber string) (*db.Table, error) {
	return s.tableRepo.FindByNumber(ctx, tableNumber)
}

func (s *tableService) GetTablesByStatus(ctx context.Context, status string) ([]db.Table, error) {
	return s.tableRepo.FindByStatus(ctx, status)
}

func (s *tableService) UpdateTable(ctx context.Context, id string, tableNumber string, capacity int64) error {
	return s.tableRepo.Update(ctx, id, tableNumber, capacity)
}

func (s *tableService) UpdateTableStatus(ctx context.Context, tableNumber string, status string) error {
	return s.tableRepo.UpdateStatus(ctx, tableNumber, status)
}

func (s *tableService) DeleteTable(ctx context.Context, id string) error {
	return s.tableRepo.Delete(ctx, id)
}

func (s *tableService) GetAvailableTables(ctx context.Context) ([]db.Table, error) {
	return s.tableRepo.GetAvailable(ctx)
}

func (s *tableService) GetOccupiedTables(ctx context.Context) ([]db.Table, error) {
	return s.tableRepo.GetOccupied(ctx)
}
