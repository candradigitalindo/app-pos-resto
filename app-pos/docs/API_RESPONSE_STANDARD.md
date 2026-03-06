# Standar Response API

Semua endpoint API menggunakan format response yang konsisten dengan pesan dalam bahasa Indonesia.

## Format Response Standar

### Success Response (200 OK)
```json
{
  "success": true,
  "message": "Pesan sukses dalam bahasa Indonesia",
  "data": {
    // data object atau array
  }
}
```

### Created Response (201 Created)
```json
{
  "success": true,
  "message": "Data berhasil dibuat",
  "data": {
    // data yang baru dibuat
  }
}
```

### Error Response (4xx/5xx)
```json
{
  "success": false,
  "message": "Pesan error dalam bahasa Indonesia"
}
```

## HTTP Status Codes

- **200 OK**: Request berhasil
- **201 Created**: Resource baru berhasil dibuat
- **400 Bad Request**: Request tidak valid (validasi gagal)
- **401 Unauthorized**: Tidak terautentikasi atau token tidak valid
- **403 Forbidden**: Tidak memiliki permission untuk akses resource
- **404 Not Found**: Resource tidak ditemukan
- **409 Conflict**: Conflict data (misalnya username sudah ada)
- **500 Internal Server Error**: Error di sisi server

## Contoh Response Per Module

### Auth Module

#### Login Sukses
```json
{
  "success": true,
  "message": "Login berhasil",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "user": {
      "id": "01HQXYZ...",
      "username": "admin",
      "full_name": "Administrator",
      "role": "admin",
      "is_active": true
    }
  }
}
```

#### Login Gagal (401)
```json
{
  "success": false,
  "message": "Username atau password salah"
}
```

### Product Module

#### Get All Products (200)
```json
{
  "success": true,
  "message": "Data produk berhasil diambil",
  "data": [
    {
      "id": 1,
      "name": "Nasi Goreng",
      "description": "Nasi goreng spesial",
      "price": 25000,
      "stock": 100,
      "category_id": 1
    }
  ]
}
```

#### Create Product (201)
```json
{
  "success": true,
  "message": "Produk berhasil dibuat",
  "data": {
    "id": 1,
    "name": "Nasi Goreng",
    "description": "Nasi goreng spesial",
    "price": 25000,
    "stock": 100,
    "category_id": 1
  }
}
```

#### Product Not Found (404)
```json
{
  "success": false,
  "message": "Produk tidak ditemukan"
}
```

### Order Module

#### Create Order (200)
```json
{
  "success": true,
  "message": "Order berhasil dibuat, print jobs dalam antrian",
  "data": {
    "order_id": "01HQXYZ..."
  }
}
```

#### Validation Error (400)
```json
{
  "success": false,
  "message": "table_number wajib diisi"
}
```

### Category Module

#### Get All Categories (200)
```json
{
  "success": true,
  "message": "Data kategori berhasil diambil",
  "data": [
    {
      "id": 1,
      "name": "Makanan"
    },
    {
      "id": 2,
      "name": "Minuman"
    }
  ]
}
```

### Transaction Module

#### Get Transactions (200)
```json
{
  "success": true,
  "message": "Data transaksi berhasil diambil",
  "data": [
    {
      "id": 1,
      "total_amount": 50000,
      "payment_method": "cash",
      "created_at": "2026-01-26T12:00:00Z"
    }
  ]
}
```

### Table Module

#### Get All Tables (200)
```json
{
  "success": true,
  "message": "Data meja berhasil diambil",
  "data": [
    {
      "id": 1,
      "table_number": "A1",
      "capacity": 4,
      "status": "available"
    }
  ]
}
```

## Helper Functions (Response Helpers)

Semua handler menggunakan helper functions dari `handlers/response.go`:

```go
// Success responses
SuccessResponse(c, message, data)       // 200 OK
CreatedResponse(c, message, data)       // 201 Created

// Error responses
BadRequestResponse(c, message)          // 400 Bad Request
UnauthorizedResponse(c, message)        // 401 Unauthorized
NotFoundResponse(c, message)            // 404 Not Found
ConflictResponse(c, message)            // 409 Conflict
InternalErrorResponse(c, message)       // 500 Internal Error
ErrorResponse(c, statusCode, message)   // Custom status code
```

## Pesan Error Standar dalam Bahasa Indonesia

### Validasi
- "Body request tidak valid"
- "ID tidak valid"
- "username dan password wajib diisi"
- "table_number wajib diisi"
- "pax harus lebih dari 0"
- "items tidak boleh kosong"

### Authentication & Authorization
- "Username atau password salah"
- "Token tidak valid"
- "Akun user tidak aktif"
- "Tidak memiliki akses"

### Not Found
- "Produk tidak ditemukan"
- "Kategori tidak ditemukan"
- "Transaksi tidak ditemukan"
- "Meja tidak ditemukan"
- "User tidak ditemukan"

### Success Messages
- "Login berhasil"
- "Produk berhasil dibuat"
- "Data berhasil diupdate"
- "Data berhasil dihapus"
- "Order berhasil dibuat"
- "Pembayaran berhasil diproses"
- "Meja berhasil digabung"

### Server Errors
- "Gagal membuat produk"
- "Gagal mengambil data"
- "Gagal update data"
- "Gagal menghapus data"
- "Gagal generate token"
