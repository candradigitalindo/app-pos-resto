# POS Backend - Repository Pattern with SQLC

Backend aplikasi Point of Sale (POS) menggunakan Go dengan arsitektur Repository Pattern dan SQLC untuk type-safe SQL queries.

## Struktur Proyek

```
backend/
├── cmd/
│   └── main.go                 # Entry point aplikasi
├── config/
│   └── config.go               # Konfigurasi aplikasi
├── internal/
│   ├── db/                     # SQLC generated code
│   │   ├── db.go
│   │   ├── models.go
│   │   ├── querier.go
│   │   ├── products.sql.go
│   │   ├── categories.sql.go
│   │   └── transactions.sql.go
│   ├── repositories/           # Data access layer (interface + implementasi)
│   │   ├── product_repository.go
│   │   ├── product_repository_impl.go
│   │   ├── category_repository.go
│   │   ├── category_repository_impl.go
│   │   ├── transaction_repository.go
│   │   └── transaction_repository_impl.go
│   ├── services/               # Business logic layer
│   │   ├── product_service.go
│   │   ├── category_service.go
│   │   └── transaction_service.go
│   └── handlers/               # HTTP handlers
│       ├── product_handler.go
│       ├── category_handler.go
│       └── transaction_handler.go
├── pkg/
│   └── database/               # Database connection & migrations
│       └── database.go
├── sql/
│   ├── schema/                 # SQL schema definitions
│   │   └── 001_init.sql
│   └── queries/                # SQL queries untuk SQLC
│       ├── products.sql
│       ├── categories.sql
│       └── transactions.sql
├── sqlc.yaml                   # SQLC configuration
├── .env.example                # Environment variables template
├── go.mod
└── README.md
```

## Teknologi yang Digunakan

- **Go**: Bahasa pemrograman
- **Echo v5**: Web framework
- **SQLC**: Type-safe SQL code generator
- **SQLite**: Database (embeddable, zero-configuration)

## Instalasi

1. Clone repository
2. Copy `.env.example` ke `.env` dan sesuaikan konfigurasi (optional)
3. Install SQLC (jika belum):
```bash
go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest
```

4. Install dependencies:
```bash
go mod download
```

5. Generate SQLC code (jika mengubah SQL queries):
```bash
sqlc generate
```

6. Build aplikasi:
```bash
go build -o bin/server cmd/main.go
```

7. Jalankan aplikasi:
```bash
./bin/server
# atau
go run cmd/main.go
```

## API Endpoints

### Products
- `POST /api/v1/products` - Create product
- `GET /api/v1/products` - Get all products
- `GET /api/v1/products/:id` - Get product by ID
- `PUT /api/v1/products/:id` - Update product
- `DELETE /api/v1/products/:id` - Delete product
- `GET /api/v1/products/category/:categoryId` - Get products by category

### Categories
- `POST /api/v1/categories` - Create category
- `GET /api/v1/categories` - Get all categories
- `GET /api/v1/categories/:id` - Get category by ID
- `PUT /api/v1/categories/:id` - Update category
- `DELETE /api/v1/categories/:id` - Delete category

### Transactions
- `POST /api/v1/transactions` - Create transaction
- `GET /api/v1/transactions` - Get all transactions
- `GET /api/v1/transactions/:id` - Get transaction by ID
- `GET /api/v1/transactions/date-range?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD` - Get transactions by date range

## Arsitektur Repository Pattern dengan SQLC

Proyek ini menggunakan Repository Pattern dengan SQLC untuk type-safe database queries:

### Layer Arsitektur:

1. **SQL Queries** (`sql/queries/`): Raw SQL queries dengan anotasi SQLC
2. **Generated Code** (`internal/db/`): Type-safe Go code yang di-generate oleh SQLC
3. **Repositories** (`internal/repositories/`): Interface dan implementasi untuk akses database
4. **Services** (`internal/services/`): Business logic dan orchestration
5. **Handlers** (`internal/handlers/`): HTTP request handlers

### Keuntungan SQLC:

- ✅ Type-safe: Compile-time error detection untuk SQL queries
- ✅ No reflection: Direct mapping tanpa runtime overhead
- ✅ Standard library: Menggunakan `database/sql` standar Go
- ✅ Full SQL support: Menulis SQL murni, bukan abstraksi ORM
- ✅ Auto-generated: Code generation otomatis dari SQL queries

### Keuntungan Repository Pattern:

- ✅ Separation of concerns
- ✅ Testability: Mudah untuk mock repositories
- ✅ Maintainability: Perubahan database tidak mempengaruhi business logic
- ✅ Dependency injection

## Development Workflow

### Menambah Query Baru

1. Edit file SQL di `sql/queries/` (contoh: `products.sql`)
2. Jalankan `sqlc generate` untuk generate Go code
3. Update repository interface dan implementation jika diperlukan
4. Update service layer jika diperlukan
5. Update handler jika diperlukan

### Mengubah Schema

1. Buat file migration baru di `sql/schema/` (contoh: `002_add_column.sql`)
2. Update `pkg/database/database.go` untuk apply migration
3. Jalankan `sqlc generate` jika ada perubahan pada struktur table
4. Update code yang terpengaruh

## Database

Database menggunakan SQLite yang disimpan sebagai file (`pos.db` by default). Database dan table akan otomatis dibuat saat aplikasi pertama kali dijalankan.

## Environment Variables

```
DB_PATH=./pos.db       # Path ke file database SQLite
SERVER_PORT=8080       # Port untuk HTTP server
```
