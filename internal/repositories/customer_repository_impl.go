package repositories

import (
	"backend/internal/db"
	"backend/pkg/utils"
	"context"
	"database/sql"
	"time"
)

type customerRepository struct {
	db      *sql.DB
	queries *db.Queries
}

func NewCustomerRepository(dbConn *sql.DB) CustomerRepository {
	return &customerRepository{
		db:      dbConn,
		queries: db.New(dbConn),
	}
}

func (r *customerRepository) Create(ctx context.Context, name, phone string) (*db.Customer, error) {
	customer, err := r.queries.CreateCustomer(ctx, db.CreateCustomerParams{
		ID:    utils.GenerateULID(),
		Name:  name,
		Phone: phone,
	})
	if err != nil {
		return nil, err
	}
	return &customer, nil
}

func (r *customerRepository) FindByID(ctx context.Context, id string) (*db.Customer, error) {
	customer, err := r.queries.GetCustomerByID(ctx, id)
	if err != nil {
		return nil, err
	}
	return &customer, nil
}

func (r *customerRepository) FindByPhone(ctx context.Context, phone string) (*db.Customer, error) {
	customer, err := r.queries.GetCustomerByPhone(ctx, phone)
	if err != nil {
		return nil, err
	}
	return &customer, nil
}

func (r *customerRepository) GetTopCustomers(ctx context.Context, startDate, endDate time.Time, limit int64) ([]db.GetTopCustomersRow, error) {
	query := `
		SELECT
			c.id,
			c.name,
			c.phone,
			COUNT(o.id) AS total_orders,
			SUM(o.total_amount) AS total_spent
		FROM customers c
		JOIN orders o ON o.customer_id = c.id
		WHERE o.payment_status = 'paid'
		AND o.created_at BETWEEN ? AND ?
		GROUP BY c.id
		ORDER BY total_spent DESC
		LIMIT ?
	`

	rows, err := r.db.QueryContext(ctx, query, startDate, endDate, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	results := []db.GetTopCustomersRow{}
	for rows.Next() {
		var row db.GetTopCustomersRow
		if err := rows.Scan(
			&row.ID,
			&row.Name,
			&row.Phone,
			&row.TotalOrders,
			&row.TotalSpent,
		); err != nil {
			return nil, err
		}
		results = append(results, row)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	return results, nil
}
