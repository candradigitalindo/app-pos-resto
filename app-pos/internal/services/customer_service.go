package services

import (
	"backend/internal/db"
	"backend/internal/repositories"
	"context"
	"time"
)

type CustomerService interface {
	CreateCustomer(ctx context.Context, name, phone string) (*db.Customer, error)
	GetCustomerByID(ctx context.Context, id string) (*db.Customer, error)
	GetCustomerByPhone(ctx context.Context, phone string) (*db.Customer, error)
	GetTopCustomers(ctx context.Context, startDate, endDate time.Time, limit int64) ([]db.GetTopCustomersRow, error)
}

type customerService struct {
	customerRepo repositories.CustomerRepository
}

func NewCustomerService(customerRepo repositories.CustomerRepository) CustomerService {
	return &customerService{
		customerRepo: customerRepo,
	}
}

func (s *customerService) CreateCustomer(ctx context.Context, name, phone string) (*db.Customer, error) {
	return s.customerRepo.Create(ctx, name, phone)
}

func (s *customerService) GetCustomerByID(ctx context.Context, id string) (*db.Customer, error) {
	return s.customerRepo.FindByID(ctx, id)
}

func (s *customerService) GetCustomerByPhone(ctx context.Context, phone string) (*db.Customer, error) {
	return s.customerRepo.FindByPhone(ctx, phone)
}

func (s *customerService) GetTopCustomers(ctx context.Context, startDate, endDate time.Time, limit int64) ([]db.GetTopCustomersRow, error) {
	return s.customerRepo.GetTopCustomers(ctx, startDate, endDate, limit)
}
