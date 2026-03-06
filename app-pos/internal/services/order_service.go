package services

import (
	"backend/internal/db"
	"backend/internal/repositories"
	"context"
	"time"
)

type OrderService interface {
	CreateOrder(ctx context.Context, input repositories.OrderInput) (string, error)
	GetPendingPrintJobs(ctx context.Context) ([]db.PrintQueue, error)
	UpdatePrintJobStatus(ctx context.Context, arg db.UpdatePrintJobStatusParams) error
	UpdateOrderStatus(ctx context.Context, orderID string, status string) error
	UpdateOrderItemStatus(ctx context.Context, itemID string, status string) error
	UpdateOrderItemQty(ctx context.Context, itemID string, qty int64) error
	AddItemsToOrder(ctx context.Context, orderID string, items []repositories.OrderItemInput) error
	ProcessPayment(ctx context.Context, orderID string) error
	ApplyOrderDiscount(ctx context.Context, orderID string, chargeType string, value float64) error
	ApplyOrderCompliment(ctx context.Context, orderID string) error
	GetOrderDetails(ctx context.Context, orderID string) (*db.Order, []db.OrderItem, error)
	GetOrderByTableID(ctx context.Context, tableID string) (*db.Order, []db.OrderItem, error)
	GetAnalytics(ctx context.Context, startDate, endDate time.Time) (*db.GetOrderAnalyticsRow, error)
	GetRevenueByPaymentStatus(ctx context.Context, startDate, endDate time.Time) (paidRevenue, unpaidRevenue float64, err error)
	GetVoidedTotalByDateRange(ctx context.Context, startDate, endDate time.Time) (float64, error)
	GetCancelledTotalByDateRange(ctx context.Context, startDate, endDate time.Time) (float64, error)
	GetAdditionalChargesSummary(ctx context.Context, startDate, endDate time.Time) (total float64, breakdowns []repositories.AdditionalChargeBreakdown, err error)
	GetProductsSold(ctx context.Context, startDate, endDate time.Time) (int64, error)
	GetRevenueTimeSeries(ctx context.Context, startDate, endDate time.Time, period string) ([]repositories.TimeSeriesData, error)
	ListOrders(ctx context.Context, limit, offset int64) ([]db.Order, int64, error)
	ListOrdersByCustomer(ctx context.Context, customerID string, startDate, endDate time.Time) ([]db.Order, error)
	SplitBillPayment(ctx context.Context, orderID string, amount float64, paymentMethod string, note string, createdBy string, items []repositories.SplitBillItem) error
	MergeTables(ctx context.Context, sourceOrderIDs []string, targetTableNumber string) (string, error)
	GetOrderPayments(ctx context.Context, orderID string) ([]db.Payment, error)
	VoidOrder(ctx context.Context, orderID string, voidedBy string, voidReason string) error
	ListVoidedOrders(ctx context.Context, limit, offset int64) ([]repositories.VoidedOrderHistory, int64, error)
	ListVoidedOrdersByDateRange(ctx context.Context, startDate, endDate time.Time, limit, offset int64) ([]repositories.VoidedOrderHistory, int64, error)
}

type orderService struct {
	orderRepo repositories.OrderRepository
}

func NewOrderService(orderRepo repositories.OrderRepository) OrderService {
	return &orderService{
		orderRepo: orderRepo,
	}
}

func (s *orderService) CreateOrder(ctx context.Context, input repositories.OrderInput) (string, error) {
	return s.orderRepo.CreateOrderWithItems(ctx, input)
}

func (s *orderService) GetPendingPrintJobs(ctx context.Context) ([]db.PrintQueue, error) {
	return s.orderRepo.GetPendingJobs(ctx)
}

func (s *orderService) UpdatePrintJobStatus(ctx context.Context, arg db.UpdatePrintJobStatusParams) error {
	return s.orderRepo.UpdatePrintJobStatus(ctx, arg)
}

func (s *orderService) UpdateOrderStatus(ctx context.Context, orderID string, status string) error {
	return s.orderRepo.UpdateOrderStatus(ctx, orderID, status)
}

func (s *orderService) UpdateOrderItemStatus(ctx context.Context, itemID string, status string) error {
	return s.orderRepo.UpdateOrderItemStatus(ctx, itemID, status)
}

func (s *orderService) UpdateOrderItemQty(ctx context.Context, itemID string, qty int64) error {
	return s.orderRepo.UpdateOrderItemQty(ctx, itemID, qty)
}

func (s *orderService) AddItemsToOrder(ctx context.Context, orderID string, items []repositories.OrderItemInput) error {
	return s.orderRepo.AddItemsToOrder(ctx, orderID, items)
}

func (s *orderService) ProcessPayment(ctx context.Context, orderID string) error {
	return s.orderRepo.ProcessPayment(ctx, orderID)
}

func (s *orderService) ApplyOrderDiscount(ctx context.Context, orderID string, chargeType string, value float64) error {
	return s.orderRepo.ApplyOrderDiscount(ctx, orderID, chargeType, value)
}

func (s *orderService) ApplyOrderCompliment(ctx context.Context, orderID string) error {
	return s.orderRepo.ApplyOrderCompliment(ctx, orderID)
}

func (s *orderService) GetOrderDetails(ctx context.Context, orderID string) (*db.Order, []db.OrderItem, error) {
	return s.orderRepo.GetOrderWithItems(ctx, orderID)
}

func (s *orderService) GetOrderByTableID(ctx context.Context, tableID string) (*db.Order, []db.OrderItem, error) {
	return s.orderRepo.GetOrderByTableID(ctx, tableID)
}

func (s *orderService) GetAnalytics(ctx context.Context, startDate, endDate time.Time) (*db.GetOrderAnalyticsRow, error) {
	return s.orderRepo.GetOrderAnalytics(ctx, startDate, endDate)
}

func (s *orderService) GetRevenueByPaymentStatus(ctx context.Context, startDate, endDate time.Time) (paidRevenue, unpaidRevenue float64, err error) {
	return s.orderRepo.GetRevenueByPaymentStatus(ctx, startDate, endDate)
}

func (s *orderService) GetVoidedTotalByDateRange(ctx context.Context, startDate, endDate time.Time) (float64, error) {
	return s.orderRepo.GetVoidedTotalByDateRange(ctx, startDate, endDate)
}

func (s *orderService) GetCancelledTotalByDateRange(ctx context.Context, startDate, endDate time.Time) (float64, error) {
	return s.orderRepo.GetCancelledTotalByDateRange(ctx, startDate, endDate)
}

func (s *orderService) GetAdditionalChargesSummary(ctx context.Context, startDate, endDate time.Time) (total float64, breakdowns []repositories.AdditionalChargeBreakdown, err error) {
	return s.orderRepo.GetAdditionalChargesSummary(ctx, startDate, endDate)
}

func (s *orderService) GetProductsSold(ctx context.Context, startDate, endDate time.Time) (int64, error) {
	return s.orderRepo.GetProductsSold(ctx, startDate, endDate)
}

func (s *orderService) GetRevenueTimeSeries(ctx context.Context, startDate, endDate time.Time, period string) ([]repositories.TimeSeriesData, error) {
	return s.orderRepo.GetRevenueTimeSeries(ctx, startDate, endDate, period)
}

func (s *orderService) ListOrders(ctx context.Context, limit, offset int64) ([]db.Order, int64, error) {
	return s.orderRepo.ListOrders(ctx, limit, offset)
}

func (s *orderService) ListOrdersByCustomer(ctx context.Context, customerID string, startDate, endDate time.Time) ([]db.Order, error) {
	return s.orderRepo.ListOrdersByCustomer(ctx, customerID, startDate, endDate)
}

func (s *orderService) SplitBillPayment(ctx context.Context, orderID string, amount float64, paymentMethod string, note string, createdBy string, items []repositories.SplitBillItem) error {
	return s.orderRepo.SplitBillPayment(ctx, orderID, amount, paymentMethod, note, createdBy, items)
}

func (s *orderService) MergeTables(ctx context.Context, sourceOrderIDs []string, targetTableNumber string) (string, error) {
	return s.orderRepo.MergeTables(ctx, sourceOrderIDs, targetTableNumber)
}

func (s *orderService) GetOrderPayments(ctx context.Context, orderID string) ([]db.Payment, error) {
	return s.orderRepo.GetOrderPayments(ctx, orderID)
}

func (s *orderService) VoidOrder(ctx context.Context, orderID string, voidedBy string, voidReason string) error {
	return s.orderRepo.VoidOrder(ctx, orderID, voidedBy, voidReason)
}

func (s *orderService) ListVoidedOrders(ctx context.Context, limit, offset int64) ([]repositories.VoidedOrderHistory, int64, error) {
	items, err := s.orderRepo.ListVoidedOrders(ctx, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	total, err := s.orderRepo.CountVoidedOrders(ctx)
	if err != nil {
		return nil, 0, err
	}
	return items, total, nil
}

func (s *orderService) ListVoidedOrdersByDateRange(ctx context.Context, startDate, endDate time.Time, limit, offset int64) ([]repositories.VoidedOrderHistory, int64, error) {
	items, err := s.orderRepo.ListVoidedOrdersByDateRange(ctx, startDate, endDate, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	total, err := s.orderRepo.CountVoidedOrdersByDateRange(ctx, startDate, endDate)
	if err != nil {
		return nil, 0, err
	}
	return items, total, nil
}
