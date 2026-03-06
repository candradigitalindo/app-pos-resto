package repositories

import (
	"backend/internal/db"
	"context"
	"time"
)

type CustomerRepository interface {
	Create(ctx context.Context, name, phone string) (*db.Customer, error)
	FindByID(ctx context.Context, id string) (*db.Customer, error)
	FindByPhone(ctx context.Context, phone string) (*db.Customer, error)
	GetTopCustomers(ctx context.Context, startDate, endDate time.Time, limit int64) ([]db.GetTopCustomersRow, error)
}
