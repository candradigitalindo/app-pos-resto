# Pagination Helper Documentation

## Overview
Sistem pagination standar telah diimplementasikan di semua endpoint list untuk mendukung pengambilan data secara bertahap.

## Cara Penggunaan

### Query Parameters
- `page` (optional): Nomor halaman yang diinginkan (default: 1)
- `page_size` (optional): Jumlah item per halaman (default: 10, max: 100)

### Contoh Request

#### Tanpa Pagination (mengambil semua data)
```bash
GET /api/v1/products
GET /api/v1/categories
GET /api/v1/tables
GET /api/v1/transactions
GET /api/v1/users
```

#### Dengan Pagination
```bash
# Page 1, 10 items (default)
GET /api/v1/products?page=1&page_size=10

# Page 2, 20 items
GET /api/v1/categories?page=2&page_size=20

# Custom pagination
GET /api/v1/users?page=1&page_size=5
```

## Response Format

### Tanpa Pagination
```json
{
  "success": true,
  "message": "Data berhasil diambil",
  "data": [...]
}
```

### Dengan Pagination
```json
{
  "success": true,
  "message": "Data berhasil diambil",
  "data": [...],
  "pagination": {
    "current_page": 1,
    "page_size": 10,
    "total_items": 50,
    "total_pages": 5
  }
}
```

## Metadata Pagination

| Field | Type | Description |
|-------|------|-------------|
| `current_page` | int | Halaman saat ini |
| `page_size` | int | Jumlah item per halaman |
| `total_items` | int | Total item di database |
| `total_pages` | int | Total halaman yang tersedia |

## Endpoints dengan Pagination Support

1. **Products** - `GET /api/v1/products`
2. **Categories** - `GET /api/v1/categories`
3. **Tables** - `GET /api/v1/tables`
4. **Transactions** - `GET /api/v1/transactions`
5. **Users** - `GET /api/v1/users` (Admin/Manager only)

## Contoh Penggunaan

### JavaScript/TypeScript
```javascript
// Fetch page 1 with 20 items
const response = await fetch('/api/v1/products?page=1&page_size=20', {
  headers: {
    'Authorization': `Bearer ${token}`
  }
});

const result = await response.json();
console.log('Current page:', result.pagination.current_page);
console.log('Total pages:', result.pagination.total_pages);
console.log('Items:', result.data);
```

### cURL
```bash
# Login first
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"1234"}' \
  | jq -r '.data.token')

# Get paginated data
curl -s "http://localhost:8080/api/v1/users?page=1&page_size=5" \
  -H "Authorization: Bearer $TOKEN" \
  | jq '{pagination, data_count: (.data | length)}'
```

## Batasan

- **Maximum page_size**: 100 item per halaman
- **Minimum page**: 1
- **Default page_size**: 10 jika tidak dispesifikasikan

## Backward Compatibility

Semua endpoint tetap mendukung request **tanpa** parameter pagination. Jika `page` atau `page_size` tidak diberikan, endpoint akan mengembalikan semua data tanpa metadata pagination (backward compatible dengan client yang sudah ada).

## Implementation Details

### Helper Functions
- `GetPaginationParams(c *echo.Context)` - Parse query parameters
- `CalculatePagination(page, pageSize int, totalItems int64)` - Hitung metadata
- `PaginatedSuccessResponse(c, message, data, pagination)` - Response dengan pagination

### SQL Queries
Semua query list telah ditambahkan versi paginated-nya:
- `ListProductsPaginated`
- `ListCategoriesPaginated`
- `ListTablesPaginated`
- `ListTransactionsPaginated`
- `ListUsersPaginated`

Ditambah query count:
- `CountProducts`
- `CountCategories`
- `CountTables`
- `CountTransactions`
- `CountUsers`
