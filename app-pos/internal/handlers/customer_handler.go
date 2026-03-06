package handlers

import (
	"backend/internal/db"
	"backend/internal/services"
	"database/sql"
	"strconv"
	"time"

	"github.com/labstack/echo/v5"
)

type CustomerHandler struct {
	customerService services.CustomerService
	orderService    services.OrderService
}

func NewCustomerHandler(customerService services.CustomerService, orderService services.OrderService) *CustomerHandler {
	return &CustomerHandler{
		customerService: customerService,
		orderService:    orderService,
	}
}

type CustomerResponse struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Phone string `json:"phone"`
}

type TopCustomerResponse struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Phone       string  `json:"phone"`
	TotalOrders int64   `json:"total_orders"`
	TotalSpent  float64 `json:"total_spent"`
}

func toCustomerResponse(customer *db.Customer) CustomerResponse {
	return CustomerResponse{
		ID:    customer.ID,
		Name:  customer.Name,
		Phone: customer.Phone,
	}
}

func (h *CustomerHandler) GetCustomerByPhone(c *echo.Context) error {
	phone := c.Param("phone")
	if phone == "" {
		return BadRequestResponse(c, "Nomor HP tidak valid")
	}

	customer, err := h.customerService.GetCustomerByPhone((*c).Request().Context(), phone)
	if err != nil {
		if err == sql.ErrNoRows {
			return NotFoundResponse(c, "Pelanggan tidak ditemukan")
		}
		return InternalErrorResponse(c, "Gagal mengambil data pelanggan: "+err.Error())
	}

	return SuccessResponse(c, "Pelanggan ditemukan", toCustomerResponse(customer))
}

func (h *CustomerHandler) GetTopCustomers(c *echo.Context) error {
	startDateStr := c.QueryParam("start_date")
	endDateStr := c.QueryParam("end_date")
	limitStr := c.QueryParam("limit")

	var startDate time.Time
	var endDate time.Time
	var err error

	if startDateStr == "" {
		startDate = time.Now().Truncate(24 * time.Hour)
	} else {
		startDate, err = time.Parse("2006-01-02", startDateStr)
		if err != nil {
			return BadRequestResponse(c, "Format start_date tidak valid, gunakan YYYY-MM-DD")
		}
	}

	if endDateStr == "" {
		endDate = time.Now()
	} else {
		endDate, err = time.Parse("2006-01-02", endDateStr)
		if err != nil {
			return BadRequestResponse(c, "Format end_date tidak valid, gunakan YYYY-MM-DD")
		}
		endDate = endDate.Add(23*time.Hour + 59*time.Minute + 59*time.Second)
	}

	limit := int64(10)
	if limitStr != "" {
		parsedLimit, err := strconv.ParseInt(limitStr, 10, 64)
		if err != nil || parsedLimit <= 0 {
			return BadRequestResponse(c, "limit harus berupa angka positif")
		}
		limit = parsedLimit
	}

	rows, err := h.customerService.GetTopCustomers((*c).Request().Context(), startDate, endDate, limit)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil data pelanggan: "+err.Error())
	}

	results := make([]TopCustomerResponse, len(rows))
	for i, row := range rows {
		totalSpent := 0.0
		if row.TotalSpent.Valid {
			totalSpent = row.TotalSpent.Float64
		}
		results[i] = TopCustomerResponse{
			ID:          row.ID,
			Name:        row.Name,
			Phone:       row.Phone,
			TotalOrders: row.TotalOrders,
			TotalSpent:  totalSpent,
		}
	}

	return SuccessResponse(c, "Data pelanggan berhasil diambil", results)
}

func (h *CustomerHandler) GetCustomerOrders(c *echo.Context) error {
	customerID := c.Param("id")
	if customerID == "" {
		return BadRequestResponse(c, "ID pelanggan tidak valid")
	}

	_, err := h.customerService.GetCustomerByID((*c).Request().Context(), customerID)
	if err != nil {
		if err == sql.ErrNoRows {
			return NotFoundResponse(c, "Pelanggan tidak ditemukan")
		}
		return InternalErrorResponse(c, "Gagal mengambil data pelanggan: "+err.Error())
	}

	startDateStr := c.QueryParam("start_date")
	endDateStr := c.QueryParam("end_date")

	var startDate time.Time
	var endDate time.Time

	if startDateStr == "" {
		startDate = time.Now().Truncate(24 * time.Hour)
	} else {
		startDate, err = time.Parse("2006-01-02", startDateStr)
		if err != nil {
			return BadRequestResponse(c, "Format start_date tidak valid, gunakan YYYY-MM-DD")
		}
	}

	if endDateStr == "" {
		endDate = time.Now()
	} else {
		endDate, err = time.Parse("2006-01-02", endDateStr)
		if err != nil {
			return BadRequestResponse(c, "Format end_date tidak valid, gunakan YYYY-MM-DD")
		}
		endDate = endDate.Add(23*time.Hour + 59*time.Minute + 59*time.Second)
	}

	orders, err := h.orderService.ListOrdersByCustomer((*c).Request().Context(), customerID, startDate, endDate)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mengambil histori pelanggan: "+err.Error())
	}

	return SuccessResponse(c, "Histori pelanggan berhasil diambil", orders)
}
