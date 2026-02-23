package handlers

import (
	"backend/internal/db"
	"backend/internal/services"
	"math"
	"net/http"
	"strings"
	"time"

	"github.com/labstack/echo/v5"
)

type TableHandler struct {
	service services.TableService
	queries *db.Queries
}

func NewTableHandler(service services.TableService, queries *db.Queries) *TableHandler {
	return &TableHandler{
		service: service,
		queries: queries,
	}
}

type CreateTableRequest struct {
	TableNumber string `json:"table_number"`
	Capacity    int64  `json:"capacity"`
}

type UpdateTableRequest struct {
	TableNumber string `json:"table_number"`
	Capacity    int64  `json:"capacity"`
}

type UpdateTableStatusRequest struct {
	Status string `json:"status"`
}

func (h *TableHandler) CreateTable(c *echo.Context) error {
	var req CreateTableRequest
	if err := (*c).Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Body request tidak valid",
		})
	}

	if req.TableNumber == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "table_number wajib diisi",
		})
	}

	if req.Capacity <= 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "capacity harus lebih dari 0",
		})
	}

	table, err := h.service.CreateTable((*c).Request().Context(), req.TableNumber, req.Capacity)
	if err != nil {
		// Check if it's a unique constraint error
		if strings.Contains(err.Error(), "UNIQUE constraint failed") || strings.Contains(err.Error(), "table_number") {
			return c.JSON(http.StatusConflict, map[string]string{
				"error": "Nomor meja " + req.TableNumber + " sudah digunakan",
			})
		}
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Gagal membuat meja: " + err.Error(),
		})
	}

	return c.JSON(http.StatusCreated, map[string]interface{}{
		"message": "Meja berhasil dibuat",
		"table":   table,
	})
}

func (h *TableHandler) GetAllTables(c *echo.Context) error {
	// Get pagination params
	params := GetPaginationParams(c)

	// Get filter params
	search := c.QueryParam("search")
	status := c.QueryParam("status")

	// Fetch all tables first (we'll filter in memory for now)
	// TODO: Move filtering to SQL query for better performance
	allTables, err := h.service.GetAllTables((*c).Request().Context())
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Gagal mendapatkan data meja: " + err.Error(),
		})
	}

	// Apply filters
	filtered := allTables
	if status != "" {
		var temp []db.Table
		for _, t := range filtered {
			if t.Status == status {
				temp = append(temp, t)
			}
		}
		filtered = temp
	}

	if search != "" {
		var temp []db.Table
		searchLower := strings.ToLower(search)
		for _, t := range filtered {
			if strings.Contains(strings.ToLower(t.TableNumber), searchLower) {
				temp = append(temp, t)
			}
		}
		filtered = temp
	}

	// Calculate total after filtering
	total := int64(len(filtered))

	// Apply pagination
	start := params.Offset
	end := params.Offset + params.PageSize
	if start > len(filtered) {
		start = len(filtered)
	}
	if end > len(filtered) {
		end = len(filtered)
	}

	paginatedTables := filtered[start:end]

	// Enrich tables with active order info
	type TableWithOrder struct {
		db.Table
		ActiveOrder *struct {
			OrderID               string    `json:"order_id"`
			CustomerName          string    `json:"customer_name"`
			Pax                   int64     `json:"pax"`
			BasketSize            int64     `json:"basket_size"`
			TotalAmount           float64   `json:"total_amount"`
			PaidAmount            float64   `json:"paid_amount"`
			RemainingAmount       float64   `json:"remaining_amount"`
			OrderStatus           string    `json:"order_status"`
			CreatedBy             string    `json:"created_by"`
			WaiterName            string    `json:"waiter_name"`
			PaymentStatus         string    `json:"payment_status"`
			IsMerged              bool      `json:"is_merged"`
			MergedFrom            string    `json:"merged_from"`
			MergedFromTableNumber string    `json:"merged_from_table_number"`
			CreatedAt             time.Time `json:"created_at"`
		} `json:"active_order,omitempty"`
	}

	enrichedTables := make([]TableWithOrder, len(paginatedTables))
	for i, table := range paginatedTables {
		enrichedTables[i].Table = table

		// Get active order for this table
		order, err := h.queries.GetActiveOrderByTable((*c).Request().Context(), table.TableNumber)
		if err == nil {
			// Order found
			customerName := ""
			if order.CustomerName.Valid {
				customerName = order.CustomerName.String
			}
			totalAmount := order.TotalAmount
			basketSize := order.BasketSize
			if totalAmount == 0 {
				items, err := h.queries.GetOrderItems((*c).Request().Context(), order.ID)
				if err == nil {
					for _, item := range items {
						totalAmount += item.Price * float64(item.Qty)
					}
					if basketSize == 0 {
						basketSize = int64(len(items))
					}
				}
			}
			waiterName := ""
			if order.CreatedBy.Valid && order.CreatedBy.String != "" {
				user, err := h.queries.GetUserByID((*c).Request().Context(), order.CreatedBy.String)
				if err == nil {
					waiterName = user.FullName
				}
			}
			mergedFromTableNumber := ""
			if order.MergedFrom.Valid && order.MergedFrom.String != "" {
				mergedOrder, err := h.queries.GetOrderWithItems((*c).Request().Context(), order.MergedFrom.String)
				if err == nil {
					mergedFromTableNumber = mergedOrder.TableNumber
				}
			}

			enrichedTables[i].ActiveOrder = &struct {
				OrderID               string    `json:"order_id"`
				CustomerName          string    `json:"customer_name"`
				Pax                   int64     `json:"pax"`
				BasketSize            int64     `json:"basket_size"`
				TotalAmount           float64   `json:"total_amount"`
				PaidAmount            float64   `json:"paid_amount"`
				RemainingAmount       float64   `json:"remaining_amount"`
				OrderStatus           string    `json:"order_status"`
				CreatedBy             string    `json:"created_by"`
				WaiterName            string    `json:"waiter_name"`
				PaymentStatus         string    `json:"payment_status"`
				IsMerged              bool      `json:"is_merged"`
				MergedFrom            string    `json:"merged_from"`
				MergedFromTableNumber string    `json:"merged_from_table_number"`
				CreatedAt             time.Time `json:"created_at"`
			}{
				OrderID:               order.ID,
				CustomerName:          customerName,
				Pax:                   order.Pax,
				BasketSize:            basketSize,
				TotalAmount:           totalAmount,
				PaidAmount:            order.PaidAmount,
				RemainingAmount:       math.Max(totalAmount-order.PaidAmount, 0),
				OrderStatus:           order.OrderStatus,
				CreatedBy:             order.CreatedBy.String,
				WaiterName:            waiterName,
				PaymentStatus:         order.PaymentStatus,
				IsMerged:              order.IsMerged == 1,
				MergedFrom:            order.MergedFrom.String,
				MergedFromTableNumber: mergedFromTableNumber,
				CreatedAt:             order.CreatedAt,
			}
		}
		// If error (no active order), ActiveOrder stays nil
	}

	// Calculate stats
	stats := map[string]int64{
		"total":     total,
		"available": 0,
		"occupied":  0,
		"reserved":  0,
	}

	for _, t := range filtered {
		switch t.Status {
		case "available":
			stats["available"]++
		case "occupied":
			stats["occupied"]++
		case "reserved":
			stats["reserved"]++
		}
	}

	pagination := CalculatePagination(params.Page, params.PageSize, total)
	return c.JSON(http.StatusOK, map[string]interface{}{
		"success":    true,
		"message":    "Data meja berhasil diambil",
		"data":       enrichedTables,
		"pagination": pagination,
		"stats":      stats,
	})
}

func (h *TableHandler) GetTable(c *echo.Context) error {
	id := c.Param("id")

	table, err := h.service.GetTableByID((*c).Request().Context(), id)
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{
			"error": "Meja tidak ditemukan",
		})
	}

	return c.JSON(http.StatusOK, table)
}

func (h *TableHandler) GetTableByNumber(c *echo.Context) error {
	tableNumber := c.Param("number")

	table, err := h.service.GetTableByNumber((*c).Request().Context(), tableNumber)
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{
			"error": "Meja tidak ditemukan",
		})
	}

	return c.JSON(http.StatusOK, table)
}

func (h *TableHandler) UpdateTable(c *echo.Context) error {
	id := c.Param("id")

	var req UpdateTableRequest
	if err := (*c).Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Body request tidak valid",
		})
	}

	if req.TableNumber == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "table_number wajib diisi",
		})
	}

	if req.Capacity <= 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "capacity harus lebih dari 0",
		})
	}

	if err := h.service.UpdateTable((*c).Request().Context(), id, req.TableNumber, req.Capacity); err != nil {
		// Check if it's a unique constraint error
		if strings.Contains(err.Error(), "UNIQUE constraint failed") || strings.Contains(err.Error(), "table_number") {
			return c.JSON(http.StatusConflict, map[string]string{
				"error": "Nomor meja " + req.TableNumber + " sudah digunakan",
			})
		}
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Gagal update meja: " + err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]string{
		"message": "Meja berhasil diupdate",
	})
}

func (h *TableHandler) UpdateTableStatus(c *echo.Context) error {
	tableNumber := c.Param("number")

	var req UpdateTableStatusRequest
	if err := (*c).Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Body request tidak valid",
		})
	}

	validStatuses := map[string]bool{
		"available": true,
		"occupied":  true,
		"reserved":  true,
	}

	if !validStatuses[req.Status] {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "status harus: available, occupied, atau reserved",
		})
	}

	if err := h.service.UpdateTableStatus((*c).Request().Context(), tableNumber, req.Status); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Gagal update status meja: " + err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]string{
		"message": "Status meja berhasil diupdate",
	})
}

func (h *TableHandler) DeleteTable(c *echo.Context) error {
	id := c.Param("id")

	if err := h.service.DeleteTable((*c).Request().Context(), id); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Gagal hapus meja: " + err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]string{
		"message": "Meja berhasil dihapus",
	})
}

func (h *TableHandler) GetAvailableTables(c *echo.Context) error {
	tables, err := h.service.GetAvailableTables((*c).Request().Context())
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Gagal mendapatkan meja tersedia: " + err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"tables": tables,
	})
}

func (h *TableHandler) GetOccupiedTables(c *echo.Context) error {
	tables, err := h.service.GetOccupiedTables((*c).Request().Context())
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Gagal mendapatkan meja terisi: " + err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"tables": tables,
	})
}
