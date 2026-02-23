# User Dummy untuk Testing

User dummy sudah berhasil dibuat di database dengan masing-masing role.

## Kredensial Login

**PIN untuk semua user: `1234`**

| Username | Full Name | Role | PIN |
|----------|-----------|------|----------|
| `admin` | Administrator System | admin | 1234 |
| `waiter` | Budi Pelayan | waiter | 1234 |
| `kitchen` | Andi Chef | kitchen | 1234 |
| `bartender` | Siti Bartender | bar | 1234 |
| `cashier` | Dewi Kasir | cashier | 1234 |
| `manager` | Joko Manager | manager | 1234 |

## Cara Login

### 1. Login via API

```bash
# Login sebagai Admin
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "1234"
  }'

# Login sebagai Waiter
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "waiter",
    "password": "1234"
  }'

# Login sebagai Cashier
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "cashier",
    "password": "1234"
  }'
```

### 2. Response Login

```json
{
  "success": true,
  "message": "Login berhasil",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": "01HQXYZABC1234567890ABCDEF",
      "username": "admin",
      "full_name": "Administrator System",
      "role": "admin",
      "is_active": 1
    }
  }
}
```

### 3. Gunakan Token untuk Request Berikutnya

```bash
# Simpan token dari response login
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Gunakan token untuk request protected endpoint
curl -X GET http://localhost:8080/api/v1/auth/profile \
  -H "Authorization: Bearer $TOKEN"
```

## Akses per Role

### Admin (admin)
- ✅ Full access ke semua endpoint
- ✅ Register user baru
- ✅ Manage products, categories, tables
- ✅ Create orders, merge tables
- ✅ Process payments
- ✅ View analytics

### Waiter (waiter)
- ✅ Create orders
- ✅ Merge tables
- ✅ Update table status
- ✅ View orders

### Kitchen (kitchen)
- ✅ Update order item status (cooking, ready)
- ✅ View orders

### Bar (bartender)
- ✅ Update order item status (cooking, ready)
- ✅ View orders

### Cashier (cashier)
- ✅ Process payments
- ✅ Split bill payments
- ✅ Create & view transactions
- ✅ View orders

### Manager (manager)
- ✅ View analytics
- ✅ Manage products & categories
- ✅ Manage tables
- ✅ View transactions
- ✅ View orders

## Re-seed Database

Jika ingin reset database dan insert ulang user dummy:

```bash
cd /Users/candrasyahputra/PROJEK-APLIKASI/nusantara/Outlet/POS/backend

# Hapus database lama
rm -f pos.db

# Jalankan server (akan create database baru)
go run cmd/main.go &

# Insert user dummy
cat sql/seeds/users_dummy.sql | sqlite3 pos.db

# Verifikasi
sqlite3 pos.db "SELECT username, full_name, role FROM users;"
```

## Testing Flow

### 1. Test Waiter Flow
```bash
# Login sebagai waiter
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "waiter", "password": "password123"}'

# Create order (gunakan token dari response login)
curl -X POST http://localhost:8080/api/v1/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "table_number": "A1",
    "customer_name": "Customer Test",
    "pax": 4,
    "printer_ip": "192.168.1.100",
    "items": [
      {
        "product_name": "Nasi Goreng",
        "qty": 2,
        "price": 25000,
        "destination": "kitchen"
      }
    ]
  }'
```

### 2. Test Cashier Flow
```bash
# Login sebagai cashier
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "cashier", "password": "password123"}'

# Process payment
curl -X POST http://localhost:8080/api/v1/orders/{order_id}/payment \
  -H "Authorization: Bearer $TOKEN"
```

## Password Hash

BCrypt hash untuk PIN "1234":
```
$2a$10$7L2bxoRd3LCxLkPJQgEdSecrLebgOLfr6a/XEb6On403ofGPvK08u
```

Hash ini digunakan untuk semua user dummy untuk kemudahan testing.
