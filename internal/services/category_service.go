package services

import (
	"backend/internal/db"
	"backend/internal/repositories"
	"context"
)

type CategoryService interface {
	CreateCategory(ctx context.Context, name, description, printerID string) (*db.Category, error)
	GetCategoryByID(ctx context.Context, id string) (*db.GetCategoryRow, error)
	GetAllCategories(ctx context.Context) ([]db.ListCategoriesRow, error)
	GetCategoriesPaginated(ctx context.Context, limit, offset int64) ([]db.ListCategoriesPaginatedRow, int64, error)
	UpdateCategory(ctx context.Context, id string, name, description, printerID string) error
	DeleteCategory(ctx context.Context, id string) error
}

type categoryService struct {
	categoryRepo repositories.CategoryRepository
}

func NewCategoryService(categoryRepo repositories.CategoryRepository) CategoryService {
	return &categoryService{
		categoryRepo: categoryRepo,
	}
}

func (s *categoryService) CreateCategory(ctx context.Context, name, description, printerID string) (*db.Category, error) {
	return s.categoryRepo.Create(ctx, name, description, printerID)
}

func (s *categoryService) GetCategoryByID(ctx context.Context, id string) (*db.GetCategoryRow, error) {
	return s.categoryRepo.FindByID(ctx, id)
}

func (s *categoryService) GetAllCategories(ctx context.Context) ([]db.ListCategoriesRow, error) {
	return s.categoryRepo.FindAll(ctx)
}

func (s *categoryService) GetCategoriesPaginated(ctx context.Context, limit, offset int64) ([]db.ListCategoriesPaginatedRow, int64, error) {
	categories, err := s.categoryRepo.FindPaginated(ctx, limit, offset)
	if err != nil {
		return nil, 0, err
	}

	total, err := s.categoryRepo.Count(ctx)
	if err != nil {
		return nil, 0, err
	}

	return categories, total, nil
}

func (s *categoryService) UpdateCategory(ctx context.Context, id string, name, description, printerID string) error {
	return s.categoryRepo.Update(ctx, id, name, description, printerID)
}

func (s *categoryService) DeleteCategory(ctx context.Context, id string) error {
	return s.categoryRepo.Delete(ctx, id)
}
