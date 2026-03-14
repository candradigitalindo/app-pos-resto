# Nusantara POS - Cloud API

Backend cloud server untuk sinkronisasi data multi-outlet POS.

## Tech Stack
- **Go** + **Fiber v2** (HTTP framework)
- **PostgreSQL** (database)
- **JWT** untuk admin auth
- **API Key** untuk outlet auth

## Quick Start

### 1. Setup PostgreSQL
```bash
createdb cloud_pos
```

### 2. Configure
```bash
cp .env.example .env
# Edit .env sesuai konfigurasi database
```

### 3. Run
```bash
make deps  # Download dependencies
make run   # Run server
```

### 4. Build
```bash
make build        # Build binary
make build-linux  # Build untuk Linux (production)
```

## API Endpoints

### Public
| Method | Endpoint | Keterangan |
|--------|----------|------------|
| GET | `/api/v1/ping` | Health check |

### Outlet API (Auth: Bearer API_KEY)
| Method | Endpoint | Keterangan |
|--------|----------|------------|
| POST | `/api/v1/outlets/:id/sync/batch` | Batch sync data |
| POST | `/api/v1/outlets/:id/orders` | Push order |
| POST | `/api/v1/outlets/:id/transactions` | Push transaction |
| POST | `/api/v1/outlets/:id/products` | Push product |
| POST | `/api/v1/outlets/:id/analytics/daily` | Push analytics |
| GET | `/api/v1/outlets/:id/updates?since=` | Pull updates |
| GET | `/api/v1/outlets/:id/orders` | List orders |
| GET | `/api/v1/outlets/:id/transactions` | List transactions |
| GET | `/api/v1/outlets/:id/products` | List products |
| GET | `/api/v1/outlets/:id/analytics` | Get analytics |
| GET | `/api/v1/outlets/:id/conflicts` | Get conflicts |
| POST | `/api/v1/outlets/:id/conflicts/:cid/resolve` | Resolve conflict |
| GET | `/api/v1/outlets/:id/sync/logs` | Sync logs |

### Admin API (Auth: Bearer ADMIN_TOKEN)
| Method | Endpoint | Keterangan |
|--------|----------|------------|
| GET | `/api/v1/admin/dashboard` | Dashboard stats |
| POST | `/api/v1/admin/outlets` | Create outlet |
| GET | `/api/v1/admin/outlets` | List outlets |
| GET | `/api/v1/admin/outlets/:id` | Get outlet detail |
| POST | `/api/v1/admin/outlets/:id/regenerate-key` | Regenerate API key |
| PUT | `/api/v1/admin/outlets/:id/toggle` | Activate/deactivate outlet |

## Flow Sinkronisasi

```
POS Outlet (pos-app.exe)
    │
    ├─ Push: Orders, Transactions, Products ──→ Cloud API ──→ PostgreSQL
    │
    └─ Pull: GET /updates?since=... ←── Cloud API ←── PostgreSQL
```

## Konfigurasi di POS App

Setelah cloud API running, setting di POS app (`.env`):
```
SYNC_ENABLED=true
CLOUD_API_URL=https://cloud-api.example.com
CLOUD_API_KEY=<api_key dari admin>
OUTLET_ID=<outlet_id>
OUTLET_CODE=JKT-001
WEBHOOK_SECRET=shared-secret
```
