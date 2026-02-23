package services

import (
	"backend/internal/db"
	"backend/internal/repositories"
	"context"
	"fmt"
	"strings"
)

type ProductService interface {
	CreateProduct(ctx context.Context, name, code, description string, price float64, stock int64, categoryID *string) (*db.Product, error)
	GetProductByID(ctx context.Context, id string) (*db.Product, error)
	GetAllProducts(ctx context.Context) ([]db.Product, error)
	GetProductsPaginated(ctx context.Context, limit, offset int64) ([]db.Product, int64, error)
	SearchProducts(ctx context.Context, search string, categoryID string, limit, offset int64) ([]db.Product, int64, error)
	UpdateProduct(ctx context.Context, id string, name, code, description string, price float64, stock int64, categoryID *string) error
	DeleteProduct(ctx context.Context, id string) error
	GetProductsByCategory(ctx context.Context, categoryID string) ([]db.Product, error)
}

type productService struct {
	productRepo repositories.ProductRepository
}

func NewProductService(productRepo repositories.ProductRepository) ProductService {
	return &productService{
		productRepo: productRepo,
	}
}

// generateProductCode membuat kode produk dari huruf pertama setiap kata
func generateProductCode(name string) string {
	words := strings.Fields(name)
	var code string
	for _, word := range words {
		if len(word) > 0 {
			code += strings.ToUpper(string(word[0]))
		}
	}

	// Batasi maksimal 4 karakter
	if len(code) > 4 {
		code = code[:4]
	}

	if code == "" {
		code = "P"
	}

	return code
}

// ensureUniqueCode memastikan kode produk unik dengan menambah counter jika perlu
func (s *productService) ensureUniqueCode(ctx context.Context, baseCode, excludeID string) (string, error) {
	code := baseCode
	counter := 1

	for {
		// Cek apakah kode sudah digunakan
		count, err := s.productRepo.CheckCodeExists(ctx, code, excludeID)
		if err != nil {
			return "", err
		}

		if count == 0 {
			return code, nil
		}

		// Jika sudah digunakan, tambah counter
		code = fmt.Sprintf("%s%d", baseCode, counter)
		counter++

		// Prevent infinite loop
		if counter > 1000 {
			return "", fmt.Errorf("tidak dapat menemukan kode unik")
		}
	}
}

func (s *productService) CreateProduct(ctx context.Context, name, code, description string, price float64, stock int64, categoryID *string) (*db.Product, error) {
	// Generate code jika tidak diisi
	if code == "" {
		code = generateProductCode(name)
	} else {
		code = strings.ToUpper(code)
	}

	// Pastikan kode unik
	uniqueCode, err := s.ensureUniqueCode(ctx, code, "")
	if err != nil {
		return nil, err
	}

	return s.productRepo.Create(ctx, name, uniqueCode, description, price, stock, categoryID)
}

func (s *productService) GetProductByID(ctx context.Context, id string) (*db.Product, error) {
	return s.productRepo.FindByID(ctx, id)
}

func (s *productService) GetAllProducts(ctx context.Context) ([]db.Product, error) {
	return s.productRepo.FindAll(ctx)
}

func (s *productService) GetProductsPaginated(ctx context.Context, limit, offset int64) ([]db.Product, int64, error) {
	products, err := s.productRepo.FindPaginated(ctx, limit, offset)
	if err != nil {
		return nil, 0, err
	}

	total, err := s.productRepo.Count(ctx)
	if err != nil {
		return nil, 0, err
	}

	return products, total, nil
}

func (s *productService) UpdateProduct(ctx context.Context, id string, name, code, description string, price float64, stock int64, categoryID *string) error {
	// Generate code jika tidak diisi
	if code == "" {
		code = generateProductCode(name)
	} else {
		code = strings.ToUpper(code)
	}

	// Pastikan kode unik (kecuali untuk produk yang sedang diupdate)
	uniqueCode, err := s.ensureUniqueCode(ctx, code, id)
	if err != nil {
		return err
	}

	return s.productRepo.Update(ctx, id, name, uniqueCode, description, price, stock, categoryID)
}

func (s *productService) DeleteProduct(ctx context.Context, id string) error {
	return s.productRepo.Delete(ctx, id)
}

func (s *productService) GetProductsByCategory(ctx context.Context, categoryID string) ([]db.Product, error) {
	return s.productRepo.FindByCategory(ctx, categoryID)
}

func (s *productService) SearchProducts(ctx context.Context, search string, categoryID string, limit, offset int64) ([]db.Product, int64, error) {
	products, err := s.productRepo.SearchPaginated(ctx, search, categoryID, limit, offset)
	if err != nil {
		return nil, 0, err
	}

	total, err := s.productRepo.CountSearch(ctx, search, categoryID)
	if err != nil {
		return nil, 0, err
	}

	return products, total, nil
}
