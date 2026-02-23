package services

import (
	"backend/internal/db"
	"backend/internal/repositories"
	"context"
	"time"
)

type TransactionService interface {
	CreateTransaction(ctx context.Context, orderID string, totalAmount float64, paymentMethod string, items []TransactionItemInput, createdBy string) (*db.Transaction, error)
	CreateTransactionForOrder(ctx context.Context, orderID string, totalAmount float64, paymentMethod string, createdBy string) (*db.Transaction, error)
	GetTransactionByID(ctx context.Context, id string) (*TransactionWithItems, error)
	GetAllTransactions(ctx context.Context) ([]db.Transaction, error)
	GetTransactionsPaginated(ctx context.Context, limit, offset int64) ([]db.Transaction, int64, error)
	GetTransactionsByDateRange(ctx context.Context, startDate, endDate time.Time) ([]db.Transaction, error)
	GetTransactionsByDateRangePaginated(ctx context.Context, startDate, endDate time.Time, limit, offset int64) ([]db.Transaction, int64, error)
	CancelTransaction(ctx context.Context, transactionID, managerID, reason string) error
}

type TransactionItemInput struct {
	ProductID string  `json:"product_id"`
	Quantity  int64   `json:"quantity"`
	Price     float64 `json:"price"`
}

type TransactionWithItems struct {
	Transaction db.Transaction
	Items       []db.ListTransactionItemsRow
}

type transactionService struct {
	transactionRepo repositories.TransactionRepository
	productRepo     repositories.ProductRepository
}

func NewTransactionService(
	transactionRepo repositories.TransactionRepository,
	productRepo repositories.ProductRepository,
) TransactionService {
	return &transactionService{
		transactionRepo: transactionRepo,
		productRepo:     productRepo,
	}
}

func (s *transactionService) CreateTransaction(ctx context.Context, orderID string, totalAmount float64, paymentMethod string, items []TransactionItemInput, createdBy string) (*db.Transaction, error) {
	transactionDate := time.Now().UTC()

	transaction, err := s.transactionRepo.Create(ctx, orderID, totalAmount, paymentMethod, "completed", transactionDate, createdBy)
	if err != nil {
		return nil, err
	}

	// Create transaction items
	for _, item := range items {
		_, err := s.transactionRepo.CreateItem(ctx, transaction.ID, item.ProductID, item.Quantity, item.Price)
		if err != nil {
			return nil, err
		}
	}

	return transaction, nil
}

func (s *transactionService) CreateTransactionForOrder(ctx context.Context, orderID string, totalAmount float64, paymentMethod string, createdBy string) (*db.Transaction, error) {
	transactionDate := time.Now().UTC()
	transaction, err := s.transactionRepo.Create(ctx, orderID, totalAmount, paymentMethod, "completed", transactionDate, createdBy)
	if err != nil {
		return nil, err
	}
	return transaction, nil
}

func (s *transactionService) GetTransactionByID(ctx context.Context, id string) (*TransactionWithItems, error) {
	transaction, err := s.transactionRepo.FindByID(ctx, id)
	if err != nil {
		return nil, err
	}

	items, err := s.transactionRepo.FindItems(ctx, id)
	if err != nil {
		return nil, err
	}

	return &TransactionWithItems{
		Transaction: *transaction,
		Items:       items,
	}, nil
}

func (s *transactionService) GetAllTransactions(ctx context.Context) ([]db.Transaction, error) {
	return s.transactionRepo.FindAll(ctx)
}

func (s *transactionService) GetTransactionsPaginated(ctx context.Context, limit, offset int64) ([]db.Transaction, int64, error) {
	transactions, err := s.transactionRepo.FindPaginated(ctx, limit, offset)
	if err != nil {
		return nil, 0, err
	}

	total, err := s.transactionRepo.Count(ctx)
	if err != nil {
		return nil, 0, err
	}

	return transactions, total, nil
}

func (s *transactionService) GetTransactionsByDateRange(ctx context.Context, startDate, endDate time.Time) ([]db.Transaction, error) {
	return s.transactionRepo.FindByDateRange(ctx, startDate, endDate)
}

func (s *transactionService) GetTransactionsByDateRangePaginated(ctx context.Context, startDate, endDate time.Time, limit, offset int64) ([]db.Transaction, int64, error) {
	transactions, err := s.transactionRepo.FindByDateRangePaginated(ctx, startDate, endDate, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	total, err := s.transactionRepo.CountByDateRange(ctx, startDate, endDate)
	if err != nil {
		return nil, 0, err
	}
	return transactions, total, nil
}

func (s *transactionService) CancelTransaction(ctx context.Context, transactionID, managerID, reason string) error {
	return s.transactionRepo.Cancel(ctx, transactionID, managerID, reason)
}
