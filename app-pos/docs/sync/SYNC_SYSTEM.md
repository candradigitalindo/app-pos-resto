# ============================================
# SYNC SERVICE
# Layanan untuk sinkronisasi data dengan cloud
# ============================================

## 🎯 Overview

Sync Service menangani sinkronisasi bi-directional antara aplikasi POS lokal dengan cloud server yang merangkum banyak outlet.

## 📋 Komponen Utama

### 1. **Sync Queue System**
- Semua perubahan data (create/update/delete) otomatis masuk ke `sync_queue`
- Background worker akan memproses queue secara berkala
- Retry mechanism untuk failed sync

### 2. **Entity Versioning**
- Setiap entity memiliki `version` untuk conflict detection
- `cloud_version` untuk tracking versi di cloud
- Optimistic locking untuk menghindari data inconsistency

### 3. **Sync Status Tracking**
Setiap record memiliki status:
- `pending`: Belum di-sync
- `synced`: Sudah berhasil di-sync
- `conflict`: Ada konflik dengan cloud
- `failed`: Sync gagal

## 🔄 Flow Sinkronisasi

### Push to Cloud (Local → Cloud)
```
1. User membuat/update data di POS lokal
2. Trigger otomatis masukkan ke sync_queue
3. Background worker ambil dari queue
4. Kirim ke cloud API
5. Update sync_status dan cloud_id
6. Log hasil sync
```

### Pull from Cloud (Cloud → Local)
```
1. Webhook dari cloud atau polling teratur
2. Ambil data terbaru dari cloud
3. Cek version conflict
4. Merge/Update data lokal
5. Update version dan sync_status
```

## 🛠️ Yang Perlu Dibuat

### 1. Models (`internal/models/sync.go`)
```go
type SyncQueue struct {
    ID           int64
    EntityType   string
    EntityID     string
    Operation    string // create, update, delete
    Payload      string // JSON
    Status       string
    RetryCount   int
    ErrorMessage string
    CreatedAt    time.Time
    SyncedAt     *time.Time
}

type OutletConfig struct {
    OutletID     string
    OutletCode   string
    CloudAPIURL  string
    CloudAPIKey  string
    SyncEnabled  bool
    LastSyncAt   *time.Time
}
```

### 2. Repository (`internal/repositories/sync_repository.go`)
```go
type SyncRepository interface {
    // Queue operations
    EnqueueSync(ctx context.Context, entityType, entityID, operation string, payload interface{}) error
    GetPendingSync(ctx context.Context, limit int) ([]SyncQueue, error)
    MarkSyncSuccess(ctx context.Context, id int64) error
    MarkSyncFailed(ctx context.Context, id int64, err error) error
    
    // Config operations
    GetOutletConfig(ctx context.Context) (*OutletConfig, error)
    UpdateLastSync(ctx context.Context) error
    
    // Version tracking
    UpdateEntityVersion(ctx context.Context, entityType, entityID string, version, cloudVersion int) error
}
```

### 3. Service (`internal/services/sync_service.go`)
```go
type SyncService interface {
    // Push to cloud
    PushPendingData(ctx context.Context) error
    PushEntity(ctx context.Context, entityType, entityID string) error
    
    // Pull from cloud
    PullUpdates(ctx context.Context, since time.Time) error
    PullEntity(ctx context.Context, entityType, entityID string) error
    
    // Conflict resolution
    ResolveConflict(ctx context.Context, entityType, entityID string, strategy string) error
    
    // Manual sync
    SyncNow(ctx context.Context) error
    GetSyncStatus(ctx context.Context) (*SyncStatus, error)
}
```

### 4. Background Worker (`internal/workers/sync_worker.go`)
```go
type SyncWorker struct {
    syncService SyncService
    interval    time.Duration
    stop        chan struct{}
}

func (w *SyncWorker) Start() {
    ticker := time.NewTicker(w.interval)
    go func() {
        for {
            select {
            case <-ticker.C:
                w.syncService.PushPendingData(ctx)
                w.syncService.PullUpdates(ctx, time.Now().Add(-w.interval))
            case <-w.stop:
                return
            }
        }
    }()
}
```

### 5. Cloud API Client (`pkg/cloudapi/client.go`)
```go
type CloudAPIClient struct {
    baseURL string
    apiKey  string
    client  *http.Client
}

func (c *CloudAPIClient) PushOrder(ctx context.Context, order *Order) error
func (c *CloudAPIClient) PushTransaction(ctx context.Context, tx *Transaction) error
func (c *CloudAPIClient) PullUpdates(ctx context.Context, since time.Time) (*Updates, error)
func (c *CloudAPIClient) GetEntityVersion(ctx context.Context, entityType, id string) (int, error)
```

### 6. Webhook Handler (`internal/handlers/webhook_handler.go`)
```go
type WebhookHandler struct {
    syncService SyncService
}

// Terima update dari cloud
func (h *WebhookHandler) HandleCloudUpdate(c *echo.Context) error
func (h *WebhookHandler) HandleCloudDelete(c *echo.Context) error
func (h *WebhookHandler) HandleCloudConflict(c *echo.Context) error
```

### 7. Sync Management Handler (`internal/handlers/sync_handler.go`)
```go
// Endpoint untuk monitoring dan kontrol sync
func (h *SyncHandler) GetSyncStatus(c *echo.Context) error
func (h *SyncHandler) TriggerSyncNow(c *echo.Context) error
func (h *SyncHandler) GetSyncLogs(c *echo.Context) error
func (h *SyncHandler) RetrySyncFailed(c *echo.Context) error
func (h *SyncHandler) GetSyncQueue(c *echo.Context) error
```

## 📡 API Endpoints

### Management Endpoints (Admin Only)
```
GET  /api/v1/sync/status          - Status sinkronisasi
POST /api/v1/sync/trigger         - Trigger sync manual
GET  /api/v1/sync/logs            - Log sinkronisasi
GET  /api/v1/sync/queue           - Antrian sync
POST /api/v1/sync/retry/:id       - Retry failed sync
GET  /api/v1/sync/conflicts       - Daftar konflik
POST /api/v1/sync/resolve/:id     - Resolve conflict
```

### Webhook Endpoints (Cloud Server)
```
POST /api/v1/webhooks/cloud/update    - Terima update dari cloud
POST /api/v1/webhooks/cloud/delete    - Terima delete dari cloud
POST /api/v1/webhooks/cloud/conflict  - Notifikasi conflict
```

## 🔐 Security

### Authentication ke Cloud
- API Key based authentication
- Header: `X-API-Key: your-api-key`
- Header: `X-Outlet-ID: outlet-uuid`

### Webhook Security
- Signature verification dengan shared secret
- Header: `X-Cloud-Signature: hmac-sha256-signature`
- IP Whitelist dari cloud server

## 📊 Monitoring & Logging

### Metrics yang perlu di-track:
- Total pending sync
- Sync success rate
- Sync failure rate
- Average sync duration
- Last successful sync time
- Conflict count

### Logging:
- Setiap sync operation log ke `sync_logs`
- Error details untuk debugging
- Performance metrics

## 🚨 Error Handling

### Retry Strategy:
```go
type RetryConfig struct {
    MaxRetries     int           // 3
    InitialBackoff time.Duration // 1 minute
    MaxBackoff     time.Duration // 30 minutes
    Multiplier     float64       // 2.0
}
```

### Conflict Resolution Strategies:
- `cloud_wins`: Cloud data menang
- `local_wins`: Local data menang
- `newest_wins`: Berdasarkan timestamp
- `manual`: Butuh intervensi manual

## 🎯 Prioritas Implementasi

1. **Phase 1** (Critical):
   - Database schema (sudah dibuat)
   - Config integration
   - Sync queue system
   - Basic push to cloud

2. **Phase 2** (Important):
   - Pull from cloud
   - Background worker
   - Webhook handler
   - Version tracking

3. **Phase 3** (Enhancement):
   - Conflict resolution
   - Retry mechanism
   - Management UI
   - Monitoring dashboard

## 💡 Best Practices

1. **Always Queue**: Jangan sync langsung, gunakan queue
2. **Batch Processing**: Sync multiple items dalam 1 request
3. **Offline Support**: Queue tetap berjalan saat offline
4. **Idempotency**: Gunakan unique ID untuk prevent duplicate
5. **Logging**: Log semua sync operation untuk audit
6. **Monitoring**: Alert jika sync gagal > threshold

## 🔧 Configuration Example

```go
// di main.go
cfg := config.LoadConfig()

if cfg.SyncEnabled {
    // Initialize sync components
    syncRepo := repositories.NewSyncRepository(db)
    cloudClient := cloudapi.NewClient(cfg.CloudAPIURL, cfg.CloudAPIKey)
    syncService := services.NewSyncService(syncRepo, cloudClient)
    
    // Start background worker
    syncWorker := workers.NewSyncWorker(syncService, cfg.SyncIntervalMin)
    syncWorker.Start()
    defer syncWorker.Stop()
    
    // Register handlers
    syncHandler := handlers.NewSyncHandler(syncService)
    webhookHandler := handlers.NewWebhookHandler(syncService)
    
    // Routes
    admin := api.Group("/sync", authmw.AdminOnly())
    admin.GET("/status", syncHandler.GetSyncStatus)
    admin.POST("/trigger", syncHandler.TriggerSyncNow)
    
    webhooks := api.Group("/webhooks/cloud")
    webhooks.POST("/update", webhookHandler.HandleCloudUpdate)
}
```
