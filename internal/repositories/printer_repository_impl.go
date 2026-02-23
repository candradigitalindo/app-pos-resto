package repositories

import (
	"backend/internal/db"
	"backend/pkg/utils"
	"context"
	"database/sql"
)

type printerRepository struct {
	queries *db.Queries
}

func NewPrinterRepository(dbConn *sql.DB) PrinterRepository {
	return &printerRepository{queries: db.New(dbConn)}
}

func (r *printerRepository) Create(ctx context.Context, name, ipAddress string, port int64, printerType, paperSize string, isActive int64, optional *PrinterOptionalSettings) (*db.Printer, error) {
	params := db.CreatePrinterParams{
		ID:          utils.GenerateULID(),
		Name:        name,
		IpAddress:   ipAddress,
		Port:        port,
		PrinterType: printerType,
		PaperSize:   paperSize,
		IsActive:    isActive,
	}

	// Apply optional settings if provided
	if optional != nil {
		if optional.ConnectionTimeout != nil {
			params.ConnectionTimeout = sql.NullInt64{Int64: *optional.ConnectionTimeout, Valid: true}
		}
		if optional.WriteTimeout != nil {
			params.WriteTimeout = sql.NullInt64{Int64: *optional.WriteTimeout, Valid: true}
		}
		if optional.RetryAttempts != nil {
			params.RetryAttempts = sql.NullInt64{Int64: *optional.RetryAttempts, Valid: true}
		}
		if optional.PrintDensity != nil {
			params.PrintDensity = sql.NullInt64{Int64: *optional.PrintDensity, Valid: true}
		}
		if optional.PrintSpeed != nil {
			params.PrintSpeed = sql.NullString{String: *optional.PrintSpeed, Valid: true}
		}
		if optional.CutMode != nil {
			params.CutMode = sql.NullString{String: *optional.CutMode, Valid: true}
		}
		if optional.EnableBeep != nil {
			params.EnableBeep = sql.NullInt64{Int64: *optional.EnableBeep, Valid: true}
		}
		if optional.AutoCut != nil {
			params.AutoCut = sql.NullInt64{Int64: *optional.AutoCut, Valid: true}
		}
		if optional.Charset != nil {
			params.Charset = sql.NullString{String: *optional.Charset, Valid: true}
		}
	}

	printer, err := r.queries.CreatePrinter(ctx, params)
	if err != nil {
		return nil, err
	}
	return &printer, nil
}

func (r *printerRepository) FindByID(ctx context.Context, id string) (*db.Printer, error) {
	printer, err := r.queries.GetPrinter(ctx, id)
	if err != nil {
		return nil, err
	}
	return &printer, nil
}

func (r *printerRepository) FindAll(ctx context.Context) ([]db.Printer, error) {
	return r.queries.ListPrinters(ctx)
}

func (r *printerRepository) FindActive(ctx context.Context) ([]db.Printer, error) {
	return r.queries.ListActivePrinters(ctx)
}

func (r *printerRepository) FindByType(ctx context.Context, printerType string) ([]db.Printer, error) {
	return r.queries.ListPrintersByType(ctx, printerType)
}

func (r *printerRepository) Update(ctx context.Context, id string, name, ipAddress string, port int64, printerType, paperSize string, isActive int64, optional *PrinterOptionalSettings) error {
	params := db.UpdatePrinterParams{
		Name:        name,
		IpAddress:   ipAddress,
		Port:        port,
		PrinterType: printerType,
		PaperSize:   paperSize,
		IsActive:    isActive,
		ID:          id,
	}

	// Apply optional settings if provided
	if optional != nil {
		if optional.ConnectionTimeout != nil {
			params.ConnectionTimeout = sql.NullInt64{Int64: *optional.ConnectionTimeout, Valid: true}
		}
		if optional.WriteTimeout != nil {
			params.WriteTimeout = sql.NullInt64{Int64: *optional.WriteTimeout, Valid: true}
		}
		if optional.RetryAttempts != nil {
			params.RetryAttempts = sql.NullInt64{Int64: *optional.RetryAttempts, Valid: true}
		}
		if optional.PrintDensity != nil {
			params.PrintDensity = sql.NullInt64{Int64: *optional.PrintDensity, Valid: true}
		}
		if optional.PrintSpeed != nil {
			params.PrintSpeed = sql.NullString{String: *optional.PrintSpeed, Valid: true}
		}
		if optional.CutMode != nil {
			params.CutMode = sql.NullString{String: *optional.CutMode, Valid: true}
		}
		if optional.EnableBeep != nil {
			params.EnableBeep = sql.NullInt64{Int64: *optional.EnableBeep, Valid: true}
		}
		if optional.AutoCut != nil {
			params.AutoCut = sql.NullInt64{Int64: *optional.AutoCut, Valid: true}
		}
		if optional.Charset != nil {
			params.Charset = sql.NullString{String: *optional.Charset, Valid: true}
		}
	}

	return r.queries.UpdatePrinter(ctx, params)
}

func (r *printerRepository) Delete(ctx context.Context, id string) error {
	return r.queries.DeletePrinter(ctx, id)
}

func (r *printerRepository) ToggleActive(ctx context.Context, id string, isActive int64) error {
	return r.queries.TogglePrinterActive(ctx, db.TogglePrinterActiveParams{
		IsActive: isActive,
		ID:       id,
	})
}

func (r *printerRepository) Count(ctx context.Context) (int64, error) {
	return r.queries.CountPrinters(ctx)
}
