package services

import (
	"backend/internal/db"
	"context"

	"github.com/stretchr/testify/mock"
)

type MockProductRepository struct {
	mock.Mock
}

func (m *MockProductRepository) Create(ctx context.Context, name, code, description string, price float64, stock int64, categoryID *string) (*db.Product, error) {
	args := m.Called(ctx, name, code, description, price, stock, categoryID)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*db.Product), args.Error(1)
}

func (m *MockProductRepository) FindByID(ctx context.Context, id string) (*db.Product, error) {
	args := m.Called(ctx, id)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*db.Product), args.Error(1)
}

func (m *MockProductRepository) FindAll(ctx context.Context) ([]db.Product, error) {
	args := m.Called(ctx)
	return args.Get(0).([]db.Product), args.Error(1)
}

func (m *MockProductRepository) FindPaginated(ctx context.Context, limit, offset int64) ([]db.Product, error) {
	args := m.Called(ctx, limit, offset)
	return args.Get(0).([]db.Product), args.Error(1)
}

func (m *MockProductRepository) Count(ctx context.Context) (int64, error) {
	args := m.Called(ctx)
	return args.Get(0).(int64), args.Error(1)
}

func (m *MockProductRepository) Update(ctx context.Context, id string, name, code, description string, price float64, stock int64, categoryID *string) error {
	args := m.Called(ctx, id, name, code, description, price, stock, categoryID)
	return args.Error(0)
}

func (m *MockProductRepository) Delete(ctx context.Context, id string) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockProductRepository) FindByCategory(ctx context.Context, categoryID string) ([]db.Product, error) {
	args := m.Called(ctx, categoryID)
	return args.Get(0).([]db.Product), args.Error(1)
}

func (m *MockProductRepository) SearchPaginated(ctx context.Context, search, categoryID string, limit, offset int64) ([]db.Product, error) {
	args := m.Called(ctx, search, categoryID, limit, offset)
	return args.Get(0).([]db.Product), args.Error(1)
}

func (m *MockProductRepository) CountSearch(ctx context.Context, search, categoryID string) (int64, error) {
	args := m.Called(ctx, search, categoryID)
	return args.Get(0).(int64), args.Error(1)
}

func (m *MockProductRepository) CheckCodeExists(ctx context.Context, code, excludeID string) (int64, error) {
	args := m.Called(ctx, code, excludeID)
	return args.Get(0).(int64), args.Error(1)
}
