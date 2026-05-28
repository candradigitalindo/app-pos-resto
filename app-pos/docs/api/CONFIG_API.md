# Cloud Sync Configuration API

## 🎯 Overview

Konfigurasi cloud sync sekarang **dinamis dan dapat di-CRUD** melalui API, tidak lagi hardcode di environment variables.

**Priority:** Database Config > Environment Variables

## 📡 API Endpoints

### 1. Get Current Configuration
**GET** `/api/v1/config/outlet`

Get konfigurasi outlet saat ini.

**Authorization:** Admin only

**Response:**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "outlet_id": "550e8400-e29b-41d4-a716-446655440000",
    "outlet_name": "Outlet Jakarta Pusat",
    "outlet_code": "JKT-001",
    "cloud_api_url": "https://api.yourcloud.com/v1",
    "cloud_api_key_masked": "abcd****xyz1",
    "is_active": true,
    "sync_enabled": true,
    "sync_interval_minutes": 5,
    "last_sync_at": "2026-01-27T10:00:00Z",
    "created_at": "2026-01-27T08:00:00Z",
    "updated_at": "2026-01-27T10:00:00Z"
  }
}
```

### 2. Create Initial Configuration
**POST** `/api/v1/config/outlet`

Buat konfigurasi outlet pertama kali.

**Authorization:** Admin only

**Request Body:**
```json
{
  "outlet_id": "550e8400-e29b-41d4-a716-446655440000",
  "outlet_name": "Outlet Jakarta Pusat",
  "outlet_code": "JKT-001",
  "cloud_api_url": "https://api.yourcloud.com/v1",
  "cloud_api_key": "your-secure-api-key-from-cloud",
  "sync_enabled": true,
  "sync_interval_minutes": 5
}
```

**Required Fields:**
- `outlet_id` - UUID dari cloud system
- `outlet_name` - Nama outlet
- `outlet_code` - Kode unik outlet (misal: JKT-001)
- `cloud_api_url` - URL API cloud
- `cloud_api_key` - API key untuk autentikasi

**Optional Fields:**
- `sync_enabled` - Default: true
- `sync_interval_minutes` - Default: 5 (minimum 1)

**Response:**
```json
{
  "success": true,
  "message": "Outlet configuration created successfully",
  "data": {
    "outlet_id": "550e8400-e29b-41d4-a716-446655440000",
    "outlet_code": "JKT-001",
    "sync_enabled": true,
    "sync_interval_minutes": 5
  }
}
```

**Error Responses:**
- `400 Bad Request` - Field required tidak lengkap
- `409 Conflict` - Config sudah ada, gunakan PUT untuk update

### 3. Update Configuration
**PUT** `/api/v1/config/outlet`

Update konfigurasi outlet yang sudah ada.

**Authorization:** Admin only

**Request Body:**
```json
{
  "outlet_name": "Outlet Jakarta Pusat - Updated",
  "cloud_api_url": "https://new-api.yourcloud.com/v1",
  "cloud_api_key": "new-api-key",
  "sync_enabled": false,
  "sync_interval_minutes": 10
}
```

**Notes:**
- Semua field **optional** - hanya update field yang dikirim
- `cloud_api_key` hanya diupdate jika dikirim (untuk keamanan)
- Server **perlu restart** untuk apply config baru

**Response:**
```json
{
  "success": true,
  "message": "Outlet configuration updated successfully",
  "data": {
    "outlet_code": "JKT-001",
    "sync_enabled": false,
    "cloud_api_url": "https://new-api.yourcloud.com/v1",
    "sync_interval_minutes": 10
  }
}
```

### 4. Test Cloud Connection
**POST** `/api/v1/config/outlet/test`

Test koneksi ke cloud API (Phase 2).

**Authorization:** Admin only

**Response:**
```json
{
  "success": true,
  "message": "Configuration is valid",
  "data": {
    "cloud_api_url": "https://api.yourcloud.com/v1",
    "outlet_code": "JKT-001",
    "configured": true
  }
}
```

## 🚀 Quick Start

### Step 1: Login sebagai Admin

```bash
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"1234"}' \
  | jq -r '.data.token')
```

### Step 2: Create Initial Configuration

```bash
curl -X POST http://localhost:8080/api/v1/config/outlet \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "outlet_id": "550e8400-e29b-41d4-a716-446655440000",
    "outlet_name": "Outlet Jakarta Pusat",
    "outlet_code": "JKT-001",
    "cloud_api_url": "https://api.yourcloud.com/v1",
    "cloud_api_key": "sk_live_abcdef123456",
    "sync_enabled": true,
    "sync_interval_minutes": 5
  }' | jq
```

### Step 3: Get Current Configuration

```bash
curl http://localhost:8080/api/v1/config/outlet \
  -H "Authorization: Bearer $TOKEN" | jq
```

### Step 4: Update Configuration

```bash
curl -X PUT http://localhost:8080/api/v1/config/outlet \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "sync_enabled": true,
    "sync_interval_minutes": 10
  }' | jq
```

### Step 5: Restart Server

Setelah create/update config, restart server untuk apply:

```bash
# Stop server (Ctrl+C atau kill process)
# Then start again
./bin/server
```

Log akan menunjukkan:
```
Using sync configuration from database
Cloud sync enabled: https://api.yourcloud.com/v1 (Outlet: JKT-001)
```

## 🔐 Security

### API Key Protection
- API key **di-mask** di response GET
- Format mask: `abcd****xyz1` (show first 4 & last 4)
- Full API key hanya dikirim saat create/update

### Access Control
- Semua endpoint **Admin only**
- Require valid JWT token
- Role check via middleware

## 🎯 Best Practices

### 1. Initial Setup
```bash
# 1. Create config via API
curl -X POST /api/v1/config/outlet ...

# 2. Restart server
./bin/server

# 3. Verify sync status
curl /api/v1/sync/status
```

### 2. Update Config
```bash
# 1. Update only what you need
curl -X PUT /api/v1/config/outlet -d '{"sync_enabled": false}'

# 2. Restart server to apply
./bin/server
```

### 3. Rotate API Key
```bash
# Update only API key
curl -X PUT /api/v1/config/outlet \
  -d '{"cloud_api_key": "new-secure-key"}'
```

### 4. Disable Sync Temporarily
```bash
# Disable without changing other settings
curl -X PUT /api/v1/config/outlet \
  -d '{"sync_enabled": false}'
```

## 📊 Configuration Priority

1. **Database Config** (Priority 1)
   - Loaded from `outlet_config` table
   - Managed via API
   - Dynamic, no restart needed for data

2. **Environment Variables** (Fallback)
   - From `.env` file
   - Only used if database config not found
   - Legacy support

**Recommendation:** Always use database config via API

## 🔄 Migration from .env

Jika sebelumnya menggunakan `.env`:

```bash
# 1. Ambil nilai dari .env
OUTLET_ID="from-env"
CLOUD_API_URL="from-env"
# etc...

# 2. Create via API
curl -X POST /api/v1/config/outlet -d '{
  "outlet_id": "'$OUTLET_ID'",
  ...
}'

# 3. (Optional) Remove from .env
# Comment out or remove:
# SYNC_ENABLED=true
# CLOUD_API_URL=...
```

## ❌ Troubleshooting

### Config Not Applied?
**Problem:** Update config tapi masih pakai yang lama

**Solution:** Restart server setelah create/update

### Can't Create Config?
**Problem:** Error "Config already exists"

**Solution:** Use PUT to update instead of POST

### Sync Still Disabled?
**Problem:** Config ada tapi sync disabled

**Check:**
```bash
# 1. Get config
curl /api/v1/config/outlet

# 2. Check sync_enabled field
# If false, update:
curl -X PUT /api/v1/config/outlet -d '{"sync_enabled": true}'

# 3. Restart server
```

### API Key Invalid?
**Problem:** Cloud API reject request

**Solution:**
```bash
# 1. Get new API key from cloud dashboard
# 2. Update via API
curl -X PUT /api/v1/config/outlet \
  -d '{"cloud_api_key": "new-valid-key"}'
# 3. Restart server
```

## 📋 Example Workflow

### Setup New Outlet

```bash
#!/bin/bash

# Get admin token
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"1234"}' \
  | jq -r '.data.token')

# Create outlet configuration
curl -X POST http://localhost:8080/api/v1/config/outlet \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "outlet_id": "550e8400-e29b-41d4-a716-446655440000",
    "outlet_name": "Outlet Bandung",
    "outlet_code": "BDG-001",
    "cloud_api_url": "https://api.yourcloud.com/v1",
    "cloud_api_key": "sk_live_bandung_12345",
    "sync_enabled": true,
    "sync_interval_minutes": 5
  }'

echo "Configuration created. Please restart server."
echo "Then check: curl /api/v1/sync/status -H \"Authorization: Bearer \$TOKEN\""
```

## 🎯 Next Steps

Setelah konfigurasi:
1. ✅ Restart server
2. ✅ Check sync status: `GET /api/v1/sync/status`
3. ✅ Test manual sync: `POST /api/v1/sync/trigger`
4. ✅ Monitor logs: `GET /api/v1/sync/logs`
