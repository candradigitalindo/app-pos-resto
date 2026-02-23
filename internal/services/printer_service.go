package services

import (
	"backend/internal/db"
	"backend/internal/repositories"
	"context"
)

type PrinterService interface {
	CreatePrinter(ctx context.Context, name, ipAddress string, port int64, printerType, paperSize string, isActive int64, optional *repositories.PrinterOptionalSettings) (*db.Printer, error)
	GetPrinterByID(ctx context.Context, id string) (*db.Printer, error)
	GetAllPrinters(ctx context.Context) ([]db.Printer, error)
	GetActivePrinters(ctx context.Context) ([]db.Printer, error)
	GetPrintersByType(ctx context.Context, printerType string) ([]db.Printer, error)
	UpdatePrinter(ctx context.Context, id string, name, ipAddress string, port int64, printerType, paperSize string, isActive int64, optional *repositories.PrinterOptionalSettings) error
	DeletePrinter(ctx context.Context, id string) error
	TogglePrinterActive(ctx context.Context, id string, isActive int64) error
}

type printerService struct {
	printerRepo repositories.PrinterRepository
}

func NewPrinterService(printerRepo repositories.PrinterRepository) PrinterService {
	return &printerService{
		printerRepo: printerRepo,
	}
}

func (s *printerService) CreatePrinter(ctx context.Context, name, ipAddress string, port int64, printerType, paperSize string, isActive int64, optional *repositories.PrinterOptionalSettings) (*db.Printer, error) {
	return s.printerRepo.Create(ctx, name, ipAddress, port, printerType, paperSize, isActive, optional)
}

func (s *printerService) GetPrinterByID(ctx context.Context, id string) (*db.Printer, error) {
	return s.printerRepo.FindByID(ctx, id)
}

func (s *printerService) GetAllPrinters(ctx context.Context) ([]db.Printer, error) {
	return s.printerRepo.FindAll(ctx)
}

func (s *printerService) GetActivePrinters(ctx context.Context) ([]db.Printer, error) {
	return s.printerRepo.FindActive(ctx)
}

func (s *printerService) GetPrintersByType(ctx context.Context, printerType string) ([]db.Printer, error) {
	return s.printerRepo.FindByType(ctx, printerType)
}

func (s *printerService) UpdatePrinter(ctx context.Context, id string, name, ipAddress string, port int64, printerType, paperSize string, isActive int64, optional *repositories.PrinterOptionalSettings) error {
	return s.printerRepo.Update(ctx, id, name, ipAddress, port, printerType, paperSize, isActive, optional)
}

func (s *printerService) DeletePrinter(ctx context.Context, id string) error {
	return s.printerRepo.Delete(ctx, id)
}

func (s *printerService) TogglePrinterActive(ctx context.Context, id string, isActive int64) error {
	return s.printerRepo.ToggleActive(ctx, id, isActive)
}
