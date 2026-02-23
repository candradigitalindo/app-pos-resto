# ULID Migration Guide

## Status: IN PROGRESS

### Completed ✅
1. **Test Print Enhancement** - Test print now shows IP address, port, and printer details in receipt
2. **Schema Migration** - All tables updated to use ULID (TEXT PRIMARY KEY CHECK length=26):
   - tables (id: TEXT)
   - categories (id: TEXT)
   - products (id: TEXT, category_id: TEXT)
   - printers (id: TEXT)
   - transactions (id: TEXT)
   - transaction_items (id: TEXT, transaction_id: TEXT, product_id: TEXT)
   - print_queue (id: TEXT, printer_id: TEXT)

3. **SQL Queries Updated** - All CREATE queries now accept ULID parameter:
   - CreateTable
   - CreateCategory
   - CreateProduct
   - CreatePrinter
   - CreateTransaction
   - CreateTransactionItem
   - CreatePrintJob

4. **Models Regenerated** - sqlc regenerated with all IDs as string type
5. **ULID Utility Created** - `pkg/utils/ulid.go` with GenerateULID() function
6. **Printer Repository** - Updated to use string IDs with ULID generation

### In Progress 🔄
- Updating remaining repositories

### Pending ❌

#### Repositories to Update
All repository interfaces and implementations need updates:

1. **Table Repository**
   - Interface: `internal/repositories/table_repository.go`
   - Implementation: `internal/repositories/table_repository_impl.go`
   - Changes needed:
     - `FindByID(id string)` instead of `int64`
     - `Update(id string, ...)` instead of `int64`
     - `Delete(id string)` instead of `int64`
     - Add `utils.GenerateULID()` in Create method

2. **Category Repository**
   - Interface: `internal/repositories/category_repository.go`
   - Implementation: `internal/repositories/category_repository_impl.go`
   - Changes needed:
     - `FindByID(id string)` instead of `int64`
     - `Update(id string, ...)` instead of `int64`
     - `Delete(id string)` instead of `int64`
     - Add `utils.GenerateULID()` in Create method

3. **Product Repository**
   - Interface: `internal/repositories/product_repository.go`
   - Implementation: `internal/repositories/product_repository_impl.go`
   - Changes needed:
     - `FindByID(id string)` instead of `int64`
     - `Update(id string, ...)` instead of `int64`
     - `Delete(id string)` instead of `int64`
     - `Create(..., categoryID *string)` instead of `*int64` - use `sql.NullString`
     - `FindByCategory(categoryID string)` instead of `int64`
     - Add `utils.GenerateULID()` in Create method

4. **Transaction Repository**
   - Interface: `internal/repositories/transaction_repository.go`
   - Implementation: `internal/repositories/transaction_repository_impl.go`
   - Changes needed:
     - `FindByID(id string)` instead of `int64`
     - `CreateItem(id string, transactionID string, productID string, ...)` - all string params
     - `FindItemsByTransaction(transactionID string)` instead of `int64`
     - Add `utils.GenerateULID()` in Create and CreateItem methods

#### Services to Update
All service files need to handle string IDs:

1. **Printer Service** - `internal/services/printer_service.go`
   - `GetPrinterByID(id string)`
   - `UpdatePrinter(id string, ...)`
   - `DeletePrinter(id string)`
   - `ToggleActive(id string, ...)`

2. **Table Service** - `internal/services/table_service.go`
   - All ID parameters to string

3. **Category Service** - `internal/services/category_service.go`
   - All ID parameters to string

4. **Product Service** - `internal/services/product_service.go`
   - All ID parameters to string
   - CategoryID as string

5. **Transaction Service** - `internal/services/transaction_service.go`
   - All ID parameters to string

#### Handlers to Update
All handler files need to:
- Parse string IDs from URL params (not int64)
- Remove `strconv.ParseInt()` for IDs
- Use string IDs directly
- Handle ULID validation

Files:
1. `internal/handlers/printer_handler.go` ✅ Partially done (test print works)
2. `internal/handlers/table_handler.go`
3. `internal/handlers/category_handler.go`
4. `internal/handlers/product_handler.go`
5. `internal/handlers/transaction_handler.go`

#### Database Migration Script
Create migration to:
1. Backup existing data
2. Drop old tables
3. Create new tables with ULID schema
4. Regenerate ULIDs for existing data
5. Restore data with new ULIDs

### Implementation Pattern

**Repository Example:**
```go
package repositories

import (
	"backend/internal/db"
	"backend/pkg/utils"
	"context"
	"database/sql"
)

func (r *repository) Create(ctx context.Context, params...) (*db.Model, error) {
	result, err := r.queries.CreateModel(ctx, db.CreateModelParams{
		ID: utils.GenerateULID(),  // Generate ULID
		// ... other params
	})
	if err != nil {
		return nil, err
	}
	return &result, nil
}

func (r *repository) FindByID(ctx context.Context, id string) (*db.Model, error) {
	// id is now string, not int64
	result, err := r.queries.GetModel(ctx, id)
	if err != nil {
		return nil, err
	}
	return &result, nil
}
```

**Handler Example:**
```go
func (h *Handler) GetByID(c *echo.Context) error {
	id := c.PathParam("id")  // Already string, no parsing needed
	
	// Optional: validate ULID format
	if !utils.IsValidULID(id) {
		return BadRequestResponse(c, "Invalid ID format")
	}
	
	result, err := h.service.GetByID(c.Request().Context(), id)
	// ...
}
```

### Next Steps
1. Complete all repository updates
2. Update all services
3. Update all handlers
4. Create and run database migration
5. Test all CRUD operations
6. Update frontend to handle string IDs
7. Test print system with ULID IDs

### Testing Checklist
- [ ] Test print with ULID printer ID
- [ ] Create new printer with ULID
- [ ] Create new table with ULID
- [ ] Create new category with ULID
- [ ] Create new product with ULID (with category FK)
- [ ] Create new transaction with ULID
- [ ] Create new order with ULID
- [ ] Print queue with ULID foreign keys
- [ ] All foreign key relationships working
