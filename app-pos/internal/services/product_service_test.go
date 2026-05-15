package services

import (
	"backend/internal/db"
	"context"
	"database/sql"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

func TestProductService_CreateProduct(t *testing.T) {
	mockRepo := new(MockProductRepository)
	service := NewProductService(mockRepo)
	ctx := context.Background()

	t.Run("Create with manual code", func(t *testing.T) {
		name := "Nasi Goreng"
		code := "NASGOR"
		desc := "Nasi goreng spesial"
		price := 25000.0
		stock := int64(100)
		categoryID := "cat-1"

		expectedProduct := &db.Product{
			ID:          "prod-1",
			Name:        name,
			Code:        sql.NullString{String: "NASGOR", Valid: true},
			Description: sql.NullString{String: desc, Valid: true},
			Price:       price,
			Stock:       stock,
			CategoryID:  sql.NullString{String: categoryID, Valid: true},
		}

		mockRepo.On("CheckCodeExists", ctx, "NASGOR", "").Return(int64(0), nil)
		mockRepo.On("Create", ctx, name, "NASGOR", desc, price, stock, &categoryID).Return(expectedProduct, nil)

		product, err := service.CreateProduct(ctx, name, code, desc, price, stock, &categoryID)

		assert.NoError(t, err)
		assert.Equal(t, expectedProduct, product)
		mockRepo.AssertExpectations(t)
	})

	t.Run("Create with generated code", func(t *testing.T) {
		name := "Es Teh"
		code := "" // should generate "E"
		desc := "Es teh manis"
		price := 5000.0
		stock := int64(200)

		expectedProduct := &db.Product{
			ID:    "prod-2",
			Name:  name,
			Code:  sql.NullString{String: "E", Valid: true},
			Price: price,
			Stock: stock,
		}

		mockRepo.On("CheckCodeExists", ctx, "E", "").Return(int64(0), nil)
		mockRepo.On("Create", ctx, name, "E", desc, price, stock, mock.Anything).Return(expectedProduct, nil)

		product, err := service.CreateProduct(ctx, name, code, desc, price, stock, nil)

		assert.NoError(t, err)
		assert.Equal(t, "E", product.Code.String)
		mockRepo.AssertExpectations(t)
	})

	t.Run("Create with duplicate code should increment", func(t *testing.T) {
		name := "Bakso"
		code := "B"
		desc := ""
		price := 15000.0
		stock := int64(50)

		expectedProduct := &db.Product{
			ID:    "prod-3",
			Name:  name,
			Code:  sql.NullString{String: "B1", Valid: true},
			Price: price,
			Stock: stock,
		}

		// First check "B" exists, second check "B1" is free
		mockRepo.On("CheckCodeExists", ctx, "B", "").Return(int64(1), nil).Once()
		mockRepo.On("CheckCodeExists", ctx, "B1", "").Return(int64(0), nil).Once()
		mockRepo.On("Create", ctx, name, "B1", desc, price, stock, mock.Anything).Return(expectedProduct, nil)

		product, err := service.CreateProduct(ctx, name, code, desc, price, stock, nil)

		assert.NoError(t, err)
		assert.Equal(t, "B1", product.Code.String)
		mockRepo.AssertExpectations(t)
	})
}

func TestProductService_UpdateProduct(t *testing.T) {
	ctx := context.Background()

	t.Run("Update successfully", func(t *testing.T) {
		mockRepo := new(MockProductRepository)
		service := NewProductService(mockRepo)
		id := "prod-1"
		name := "Nasi Goreng"
		code := "NASGOR"
		desc := "Update desc"
		price := 26000.0
		stock := int64(110)
		categoryID := "cat-1"

		mockRepo.On("CheckCodeExists", ctx, "NASGOR", id).Return(int64(0), nil)
		mockRepo.On("Update", ctx, id, name, "NASGOR", desc, price, stock, &categoryID).Return(nil)

		err := service.UpdateProduct(ctx, id, name, code, desc, price, stock, &categoryID)

		assert.NoError(t, err)
		mockRepo.AssertExpectations(t)
	})

	t.Run("Update with duplicate code should increment", func(t *testing.T) {
		mockRepo := new(MockProductRepository)
		service := NewProductService(mockRepo)
		id := "prod-1"
		name := "Nasi Goreng"
		code := "NASGOR"
		desc := ""
		price := 25000.0
		stock := int64(100)

		mockRepo.On("CheckCodeExists", ctx, "NASGOR", id).Return(int64(1), nil).Once()
		mockRepo.On("CheckCodeExists", ctx, "NASGOR1", id).Return(int64(0), nil).Once()
		mockRepo.On("Update", ctx, id, name, "NASGOR1", desc, price, stock, mock.Anything).Return(nil)

		err := service.UpdateProduct(ctx, id, name, code, desc, price, stock, nil)

		assert.NoError(t, err)
		mockRepo.AssertExpectations(t)
	})
}
