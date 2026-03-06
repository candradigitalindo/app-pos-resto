# Quick Start - Cloud Sync

## ✅ Phase 1 Implementation Complete!

Berikut yang sudah diimplementasikan:

### 📦 Components

1. **Models** (`internal/models/sync.go`)
   - SyncQueue, OutletConfig, SyncLog, EntityVersion
   - Cloud request/response structures

2. **Repository** (`internal/repositories/sync_repository.go`)
   - Queue management
   - Config operations
   - Version tracking
   - Logging

3. **Cloud Client** (`pkg/cloudapi/client.go`)
   - HTTP client untuk komunikasi dengan cloud
   - Batch push support
   - Individual entity push

4. **Sync Service** (`internal/services/sync_service.go`)
   - Push pending data to cloud
   - Get sync status
   - Retry failed sync

5. **Sync Handler** (`internal/handlers/sync_handler.go`)
   - API endpoints untuk management

6. **Database Schema** (`sql/schema/002_sync_system.sql`)
   - Tabel sync_queue, outlet_config, sync_logs, entity_versions
   - Triggers untuk auto-queue

## 🚀 Setup

### 1. Jalankan Migrasi Database

Jika belum ada, jalankan schema sync:

```bash
sqlite3 pos.db < sql/schema/002_sync_system.sql
```

### 2. Konfigurasi Outlet

Update config di database:

```sql
UPDATE outlet_config SET
  outlet_id = 'your-outlet-uuid-from-cloud',
  outlet_name = 'Outlet Jakarta Pusat',
  outlet_code = 'JKT-001',
  cloud_api_url = 'https://api.yourcloud.com/v1',
  cloud_api_key = 'your-api-key',
  sync_enabled = 1
WHERE id = 1;
```

### 3. Environment Variables

Edit `.env`:

```env
SYNC_ENABLED=true
CLOUD_API_URL=https://api.yourcloud.com/v1
CLOUD_API_KEY=your-api-key-here
OUTLET_ID=your-outlet-uuid
OUTLET_CODE=JKT-001
SYNC_INTERVAL_MINUTES=5
```

### 4. Restart Server

```bash
go run cmd/main.go
```

Jika sync enabled, akan muncul log:
```
Cloud sync enabled: https://api.yourcloud.com/v1 (Outlet: JKT-001)
Sync management endpoints registered
```

## 📡 API Endpoints

### GET /api/v1/sync/status
Cek status sinkronisasi (Admin only)

**Response:**
```json
{
  "success": true,
  "data": {
    "outlet_id": "uuid",
    "outlet_code": "JKT-001",
    "sync_enabled": true,
    "last_sync_at": "2026-01-27T10:00:00Z",
    "pending_count": 5,
    "failed_count": 0,
    "conflict_count": 0,
    "total_synced": 150
  }
}
```

### POST /api/v1/sync/trigger
Trigger manual sync (Admin only)

**Response:**
```json
{
  "success": true,
  "message": "Sync triggered successfully"
}
```

### GET /api/v1/sync/logs?limit=50
Get sync logs (Admin only)

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "sync_type": "push",
      "entity_type": "mixed",
      "entity_count": 15,
      "status": "success",
      "started_at": "2026-01-27T10:00:00Z",
      "completed_at": "2026-01-27T10:00:05Z",
      "duration_ms": 5000
    }
  ]
}
```

### GET /api/v1/sync/failed
Get failed sync items (Admin only)

**Response:**
```json
{
  "success": true,
  "count": 2,
  "data": [
    {
      "id": 123,
      "entity_type": "order",
      "entity_id": "ORD-001",
      "operation": "create",
      "retry_count": 3,
      "error_message": "Cloud API timeout",
      "created_at": "2026-01-27T09:55:00Z"
    }
  ]
}
```

### POST /api/v1/sync/retry/:id
Retry specific failed sync (Admin only)

**Response:**
```json
{
  "success": true,
  "message": "Sync retry triggered"
}
```

## 🔄 Cara Kerja

### Automatic Queueing

Semua perubahan data otomatis masuk ke queue melalui database triggers:

1. User create order → Trigger insert ke `sync_queue`
2. User update product → Trigger insert ke `sync_queue`
3. Background worker (Phase 2) akan process queue

### Manual Sync

```bash
# Login sebagai admin
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"1234"}' \
  | jq -r '.data.token')

# Cek status
curl http://localhost:8080/api/v1/sync/status \
  -H "Authorization: Bearer $TOKEN"

# Trigger manual sync
curl -X POST http://localhost:8080/api/v1/sync/trigger \
  -H "Authorization: Bearer $TOKEN"

# Lihat logs
curl http://localhost:8080/api/v1/sync/logs?limit=10 \
  -H "Authorization: Bearer $TOKEN"
```

## 📊 Monitoring

### Check Pending Queue

```sql
SELECT 
  entity_type,
  COUNT(*) as count,
  status
FROM sync_queue
GROUP BY entity_type, status;
```

### Check Recent Logs

```sql
SELECT 
  sync_type,
  entity_type,
  status,
  entity_count,
  duration_ms,
  started_at
FROM sync_logs
ORDER BY started_at DESC
LIMIT 10;
```

### Check Failed Items

```sql
SELECT 
  id,
  entity_type,
  entity_id,
  operation,
  retry_count,
  error_message,
  created_at
FROM sync_queue
WHERE status = 'failed'
ORDER BY created_at DESC;
```

## 🎯 Next Steps (Phase 2)

- [ ] Background worker untuk auto-sync
- [ ] Webhook handler untuk terima update dari cloud
- [ ] Pull updates dari cloud
- [ ] Conflict resolution
- [ ] Retry mechanism dengan exponential backoff
- [ ] Batch optimization
- [ ] Health check endpoint

## 🚨 Troubleshooting

### Sync tidak jalan?

1. Check config:
   ```bash
   curl http://localhost:8080/api/v1/sync/status -H "Authorization: Bearer $TOKEN"
   ```

2. Check queue:
   ```sql
   SELECT COUNT(*) FROM sync_queue WHERE status = 'pending';
   ```

3. Trigger manual:
   ```bash
   curl -X POST http://localhost:8080/api/v1/sync/trigger -H "Authorization: Bearer $TOKEN"
   ```

### Error "Cloud API not configured"?

Set environment variables di `.env` atau database `outlet_config`

### Banyak failed sync?

Check error message:
```bash
curl http://localhost:8080/api/v1/sync/failed -H "Authorization: Bearer $TOKEN"
```

Retry individual:
```bash
curl -X POST http://localhost:8080/api/v1/sync/retry/123 -H "Authorization: Bearer $TOKEN"
```
