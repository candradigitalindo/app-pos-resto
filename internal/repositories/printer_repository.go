package repositories

import (
	"backend/internal/db"
	"context"
)

type PrinterOptionalSettings struct {
	ConnectionTimeout *int64
	WriteTimeout      *int64
	RetryAttempts     *int64
	PrintDensity      *int64
	PrintSpeed        *string
	CutMode           *string
	EnableBeep        *int64
	AutoCut           *int64
	Charset           *string
}

type PrinterRepository interface {
	Create(ctx context.Context, name, ipAddress string, port int64, printerType, paperSize string, isActive int64, optional *PrinterOptionalSettings) (*db.Printer, error)
	FindByID(ctx context.Context, id string) (*db.Printer, error)
	FindAll(ctx context.Context) ([]db.Printer, error)
	FindActive(ctx context.Context) ([]db.Printer, error)
	FindByType(ctx context.Context, printerType string) ([]db.Printer, error)
	Update(ctx context.Context, id string, name, ipAddress string, port int64, printerType, paperSize string, isActive int64, optional *PrinterOptionalSettings) error
	Delete(ctx context.Context, id string) error
	ToggleActive(ctx context.Context, id string, isActive int64) error
	Count(ctx context.Context) (int64, error)
}
