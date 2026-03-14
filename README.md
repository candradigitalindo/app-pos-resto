# 🍽️ Nusantara POS — Sistem Point of Sale Restoran

Sistem POS (Point of Sale) lengkap untuk restoran multi-outlet, terdiri dari **App-POS** (aplikasi kasir di outlet) dan **Cloud-POS** (dashboard admin cloud untuk manajemen terpusat).

---

## 📋 Daftar Isi

- [Arsitektur Sistem](#-arsitektur-sistem)
- [Fitur Utama](#-fitur-utama)
- [Tech Stack](#-tech-stack)
- [Prasyarat](#-prasyarat)
- [Instalasi & Setup](#-instalasi--setup)
  - [App-POS (Aplikasi Outlet)](#1-app-pos-aplikasi-outlet)
  - [Cloud-POS (Dashboard Admin)](#2-cloud-pos-dashboard-admin)
- [Konfigurasi](#-konfigurasi)
- [Menjalankan Aplikasi](#-menjalankan-aplikasi)
- [Build & Deploy](#-build--deploy)
- [Struktur Proyek](#-struktur-proyek)
- [API Endpoints](#-api-endpoints)
- [Sinkronisasi Cloud](#-sinkronisasi-cloud)
- [Sistem Printer](#-sistem-printer)
- [User & Role](#-user--role)
- [Akun Default](#-akun-default)

---

## 🏗 Arsitektur Sistem

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLOUD-POS                                │
│            Dashboard Admin Multi-Outlet                         │
│          Go (Fiber) + PostgreSQL + Vue.js                       │
│                   Port: 3000                                    │
└──────────────┬─────────────────────────┬────────────────────────┘
               │  REST API (Push/Pull)   │
               ▼                         ▼
┌──────────────────────┐   ┌──────────────────────┐
│    APP-POS Outlet 1  │   │    APP-POS Outlet 2  │   ...
│  Go (Echo) + SQLite  │   │  Go (Echo) + SQLite  │
│     + Vue.js (PWA)   │   │     + Vue.js (PWA)   │
│     Port: 8080       │   │     Port: 8080       │
└──────────────────────┘   └──────────────────────┘
     │          │                │          │
   Kasir     Dapur            Kasir     Dapur
   Waiter    Bar              Waiter    Bar
```

- **App-POS** berjalan di setiap outlet secara independen (offline-first).
- **Cloud-POS** mengumpulkan data dari semua outlet untuk laporan & manajemen terpusat.
- Sinkronisasi berjalan otomatis di background (interval konfigurabel, default 5 menit).

---

## ✨ Fitur Utama

### App-POS (Aplikasi Outlet)

| Fitur | Keterangan |
|-------|------------|
| **Dashboard** | Ringkasan penjualan, statistik harian |
| **Kasir** | Proses pembayaran, split bill, multi metode bayar |
| **Waiter** | Ambil pesanan, pilih meja, update order |
| **Dapur & Bar** | Tampilkan pesanan masuk, tandai selesai, cetak order |
| **Manajemen Meja** | Layout meja, status (kosong/terisi/reserved) |
| **Produk & Kategori** | CRUD produk, stok, harga, kategori |
| **Pelanggan** | Data pelanggan |
| **Cetak Struk** | Thermal printer ESC/POS (58mm & 80mm), multi printer |
| **Offline Mode** | 100% berfungsi tanpa internet (SQLite lokal) |
| **PWA** | Installable, service worker, offline asset cache |
| **LAN Sync** | QR code pairing untuk perangkat di jaringan lokal |
| **Cloud Sync** | Sinkronisasi otomatis ke server cloud |

### Cloud-POS (Dashboard Admin)

| Fitur | Keterangan |
|-------|------------|
| **Dashboard** | KPI, tren penjualan seluruh outlet |
| **Kelola Outlet** | Tambah/edit outlet, generate API key |
| **Laporan Penjualan** | Analisis penjualan multi-outlet |
| **Pesanan** | Lihat semua pesanan dari tiap outlet |
| **Transaksi** | Riwayat transaksi & laporan |
| **Produk** | Katalog produk global |
| **Admin** | Manajemen user admin |
| **Sync Logs** | Riwayat sinkronisasi per outlet |
| **Conflict Resolution** | Deteksi & resolusi konflik data |

---

## 🛠 Tech Stack

| Komponen | App-POS (Outlet) | Cloud-POS (Admin) |
|----------|-------------------|-------------------|
| **Backend** | Go + Echo v5 | Go + Fiber v2 |
| **Database** | SQLite (embedded) | PostgreSQL |
| **Frontend** | Vue.js 3 + Tailwind CSS | Vue.js 3 + Tailwind CSS |
| **Auth** | JWT + PIN 4-digit | JWT + Password |
| **ORM/Query** | SQLC (type-safe SQL) | Raw SQL + lib/pq |
| **ID** | ULID | ULID |
| **Printer** | ESC/POS via TCP | — |
| **Deploy** | Single binary (embedded UI) | Binary + PostgreSQL |

---

## 📦 Prasyarat

### Wajib

- **Go** >= 1.24 — [golang.org/dl](https://golang.org/dl/)
- **Node.js** >= 18 — [nodejs.org](https://nodejs.org/)
- **npm** >= 9

### Untuk Cloud-POS

- **PostgreSQL** >= 14 — [postgresql.org](https://www.postgresql.org/download/)

### Opsional

- **SQLC** — untuk regenerasi query code (`go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest`)
- **Air** — untuk hot reload development (`go install github.com/air-verse/air@latest`)
- **NSIS** — untuk build installer Windows (app-pos)

---

## 🚀 Instalasi & Setup

### 1. App-POS (Aplikasi Outlet)

```bash
# Clone repository
git clone <repo-url>
cd app-pos-resto/app-pos

# Install dependencies
make install
# atau manual:
go mod download
cd ui && npm install && cd ..

# Copy konfigurasi
cp .env.example .env
```

Edit `.env` sesuai kebutuhan:

```env
DB_PATH=./pos.db
SERVER_PORT=8080
JWT_SECRET=ganti-dengan-secret-aman

# Cloud Sync (opsional, bisa diaktifkan nanti)
SYNC_ENABLED=false
CLOUD_API_URL=
CLOUD_API_KEY=
OUTLET_ID=
OUTLET_CODE=
```

**Jalankan:**

```bash
# Development (frontend + backend terpisah, hot reload)
make dev

# Atau build & jalankan sebagai single binary
make build-all
./pos-app
```

Akses: **http://localhost:8080**

### 2. Cloud-POS (Dashboard Admin)

```bash
cd app-pos-resto/cloud-pos

# Install dependencies
go mod download
cd ui && npm install && cd ..

# Buat database PostgreSQL
createdb cloud_pos

# Copy konfigurasi
cp .env.example .env
```

Edit `.env`:

```env
PORT=3000

DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=cloud_pos
DB_SSLMODE=disable

JWT_SECRET=ganti-dengan-secret-aman
WEBHOOK_SECRET=shared-secret-antara-cloud-dan-pos

RATE_LIMIT_PER_MINUTE=100
```

**Jalankan:**

```bash
# Development (backend + UI dev server dengan hot reload)
make dev-all
# atau
DEV_UI=true go run main.go

# Production build
make build
./cloud-api
```

Akses: **http://localhost:3000**

> Tabel database dibuat otomatis saat pertama kali dijalankan (auto migration).

---

## ⚙ Konfigurasi

### Menghubungkan Outlet ke Cloud

Setelah Cloud-POS berjalan:

1. Buka dashboard Cloud-POS → **Outlet** → Tambah outlet baru.
2. Catat `OUTLET_ID`, `OUTLET_CODE`, dan `API_KEY` yang digenerate.
3. Di App-POS, edit `.env`:

```env
SYNC_ENABLED=true
CLOUD_API_URL=http://<CLOUD_SERVER_IP>:3000
CLOUD_API_KEY=<api_key_dari_dashboard>
OUTLET_ID=<outlet_id>
OUTLET_CODE=JKT-001
WEBHOOK_SECRET=shared-secret-antara-cloud-dan-pos
SYNC_INTERVAL_MINUTES=5
```

4. Restart App-POS. Sinkronisasi akan berjalan otomatis setiap 5 menit.

---

## 🏃 Menjalankan Aplikasi

### Development

```bash
# App-POS (frontend hot reload + backend)
cd app-pos
make dev
# Frontend: http://localhost:5173
# Backend:  http://localhost:8080

# Cloud-POS (frontend hot reload + backend)
cd cloud-pos
make dev-all
# Akses: http://localhost:3000
```

### Production

```bash
# App-POS
cd app-pos
make build-all
./pos-app

# Cloud-POS
cd cloud-pos
make build
./cloud-api
```

---

## 📦 Build & Deploy

### App-POS

Frontend Vue.js di-embed ke dalam binary Go saat build, menghasilkan **satu file executable** yang bisa langsung dijalankan tanpa dependensi eksternal.

```bash
cd app-pos

# Build untuk OS saat ini
make build-all          # → pos-app

# Build untuk platform spesifik
make build-windows      # → pos-app.exe
make build-macos        # → pos-app-macos
make build-linux        # → pos-app-linux

# Build installer Windows (butuh NSIS)
make build-installer-windows  # → pos-app-setup.exe
```

**Deployment di outlet:**
1. Copy binary `pos-app` + file `.env` ke komputer outlet.
2. Jalankan `./pos-app`.
3. Buka browser → `http://localhost:8080`.
4. Database SQLite (`pos.db`) dibuat otomatis.

### Cloud-POS

```bash
cd cloud-pos

make build              # → cloud-api
make build-linux        # → cloud-api-linux (untuk server Linux)
```

**Deployment di server:**
1. Siapkan PostgreSQL, buat database `cloud_pos`.
2. Copy binary + file `.env` ke server.
3. Jalankan `./cloud-api`.
4. Database di-migrate otomatis.

---

## 📁 Struktur Proyek

```
app-pos-resto/
├── app-pos/                    # Aplikasi POS Outlet (per restoran)
│   ├── cmd/                    # Entry point + embedded web
│   │   ├── main.go
│   │   └── web/                # Embedded frontend (build result)
│   ├── config/                 # Konfigurasi aplikasi
│   ├── internal/
│   │   ├── db/                 # SQLC generated (type-safe queries)
│   │   ├── handlers/           # HTTP handler (auth, order, product, dll)
│   │   ├── middleware/         # JWT auth middleware
│   │   ├── models/             # Model sync
│   │   ├── repositories/       # Data access layer (interface + impl)
│   │   ├── services/           # Business logic layer
│   │   └── workers/            # Background workers (print, sync)
│   ├── pkg/
│   │   ├── cloudapi/           # Cloud API client
│   │   ├── database/           # SQLite connection & migration
│   │   ├── printer/            # ESC/POS thermal printer driver
│   │   └── utils/              # Utility helpers
│   ├── sql/
│   │   ├── schema/             # SQL schema (DDL)
│   │   ├── queries/            # SQL queries (untuk SQLC)
│   │   ├── migrations/         # Migration scripts
│   │   └── seeds/              # Seed data
│   ├── ui/                     # Vue.js 3 frontend
│   │   └── src/
│   │       ├── views/          # Halaman (Dashboard, Kasir, Waiter, dll)
│   │       ├── components/     # Komponen reusable
│   │       ├── stores/         # Pinia stores
│   │       └── router/         # Vue Router
│   ├── Makefile
│   ├── sqlc.yaml
│   └── .env.example
│
├── cloud-pos/                  # Dashboard Admin Cloud (multi-outlet)
│   ├── main.go                 # Entry point
│   ├── config/                 # Konfigurasi (env, database)
│   ├── database/               # PostgreSQL connection, migration, seeder
│   ├── handlers/               # HTTP handler
│   ├── middleware/              # JWT auth middleware
│   ├── models/                 # Data models
│   ├── routes/                 # Route definitions
│   ├── services/               # Business logic
│   ├── ui/                     # Vue.js 3 frontend (admin dashboard)
│   │   └── src/
│   │       ├── pages/          # Halaman (Dashboard, Outlet, Laporan, dll)
│   │       ├── components/     # Komponen reusable
│   │       ├── stores/         # Pinia stores
│   │       └── router/         # Vue Router
│   ├── Makefile
│   ├── seed.sql
│   └── .env.example
│
└── README.md                   # ← File ini
```

---

## 🔌 API Endpoints

### App-POS API (Port 8080)

| Method | Endpoint | Keterangan |
|--------|----------|------------|
| POST | `/api/auth/login` | Login (username + PIN) |
| GET | `/api/orders` | Daftar pesanan |
| POST | `/api/orders` | Buat pesanan baru |
| PUT | `/api/orders/:id` | Update pesanan |
| GET | `/api/transactions` | Daftar transaksi |
| POST | `/api/transactions` | Buat transaksi (pembayaran) |
| GET | `/api/products` | Daftar produk |
| POST | `/api/products` | Tambah produk |
| PUT | `/api/products/:id` | Edit produk |
| DELETE | `/api/products/:id` | Hapus produk |
| GET | `/api/categories` | Daftar kategori |
| GET | `/api/tables` | Daftar meja |
| PUT | `/api/tables/:id` | Update status meja |
| GET | `/api/customers` | Daftar pelanggan |
| GET | `/api/printers` | Daftar printer |
| POST | `/api/print` | Kirim print job |
| GET | `/api/config` | Konfigurasi outlet |
| POST | `/api/sync/push` | Manual sync ke cloud |
| GET | `/api/sync/status` | Status sinkronisasi |
| GET | `/api/device/qr` | QR code untuk pairing LAN |

### Cloud-POS API (Port 3000)

**Public:**
| Method | Endpoint | Keterangan |
|--------|----------|------------|
| GET | `/api/v1/ping` | Health check |

**Outlet API** (Auth: Bearer API_KEY):
| Method | Endpoint | Keterangan |
|--------|----------|------------|
| POST | `/api/v1/outlets/:id/sync/batch` | Batch sync data |
| POST | `/api/v1/outlets/:id/orders` | Push pesanan |
| GET | `/api/v1/outlets/:id/orders` | Ambil pesanan |
| POST | `/api/v1/outlets/:id/transactions` | Push transaksi |
| GET | `/api/v1/outlets/:id/transactions` | Ambil transaksi |
| POST | `/api/v1/outlets/:id/products` | Push produk |
| GET | `/api/v1/outlets/:id/products` | Ambil produk |
| POST | `/api/v1/outlets/:id/analytics/daily` | Push analitik |
| GET | `/api/v1/outlets/:id/analytics` | Ambil analitik |
| GET | `/api/v1/outlets/:id/updates?since=` | Pull update terbaru |

**Admin API** (Auth: Bearer JWT Token):
| Method | Endpoint | Keterangan |
|--------|----------|------------|
| GET | `/api/v1/admin/dashboard` | Statistik dashboard |
| POST | `/api/v1/admin/outlets` | Tambah outlet |
| GET | `/api/v1/admin/outlets` | Daftar outlet |
| GET | `/api/v1/admin/outlets/:id` | Detail outlet |
| POST | `/api/v1/admin/outlets/:id/regenerate-key` | Regenerate API key |
| PUT | `/api/v1/admin/outlets/:id/toggle` | Aktifkan/nonaktifkan outlet |

---

## 🔄 Sinkronisasi Cloud

### Alur Sinkronisasi

```
App-POS (Outlet)                           Cloud-POS (Server)
┌──────────────┐                         ┌──────────────────┐
│  Buat Order  │────── Push ────────────▶│  cloud_orders    │
│  Transaksi   │────── Push ────────────▶│  cloud_trans     │
│  Produk      │────── Push ────────────▶│  cloud_products  │
│              │                         │                  │
│  Local DB    │◀───── Pull (updates) ───│  PostgreSQL      │
│  (SQLite)    │                         │  (centralized)   │
└──────────────┘                         └──────────────────┘
```

- **Background Worker**: Sinkronisasi otomatis setiap N menit (default: 5).
- **Offline-first**: Semua operasi disimpan lokal terlebih dahulu, sync saat online.
- **Conflict Resolution**: Deteksi konflik versi, strategi resolusi (cloud-wins / local-wins / manual).
- **Retry & Backoff**: Exponential backoff jika koneksi gagal.
- **Sync Queue**: Setiap perubahan lokal masuk antrian sync, diproses batch.

---

## 🖨 Sistem Printer

App-POS mendukung thermal printer ESC/POS melalui koneksi TCP:

| Fitur | Detail |
|-------|--------|
| **Koneksi** | TCP socket (port 9100) |
| **Ukuran Kertas** | 58mm, 80mm |
| **Tipe Printer** | Struk, Dapur, Bar, Checker |
| **Print Queue** | Antrian otomatis, retry jika gagal |
| **Routing** | Kategori produk → printer tujuan (dapur/bar) |
| **Density** | Konfigurabel (0-100) |
| **Auto-cut** | Full / Partial / None |

Setiap kategori produk dapat diarahkan ke printer tertentu. Misalnya:
- Kategori "Makanan" → Printer Dapur
- Kategori "Minuman" → Printer Bar
- Struk pembayaran → Printer Kasir

---

## 👥 User & Role

### App-POS (Outlet)

| Role | Akses |
|------|-------|
| **Admin** | Semua fitur, kelola user, settings |
| **Manager** | Dashboard, laporan, produk |
| **Cashier** | Kasir, pembayaran, struk |
| **Waiter** | Ambil pesanan, pilih meja |
| **Kitchen** | Tampilan dapur, tandai selesai |
| **Bar** | Tampilan bar, tandai selesai |

### Cloud-POS (Admin)

| Role | Akses |
|------|-------|
| **Super Admin** | Semua fitur, kelola admin |
| **Admin** | Dashboard, outlet, laporan |

---

## 🔑 Akun Default

### App-POS

| Username | PIN | Role |
|----------|-----|------|
| `admin` | `1234` | Admin |

### Cloud-POS

> Akun admin dibuat melalui seed data saat pertama kali setup. Lihat `cloud-pos/seed.sql`.

---

## 📄 Dokumentasi Tambahan

| Dokumen | Lokasi |
|---------|--------|
| API Response Standard | `app-pos/docs/API_RESPONSE_STANDARD.md` |
| Cloud API Contract | `app-pos/docs/CLOUD_API_CONTRACT.md` |
| Panduan Kasir | `app-pos/docs/KASIR_GUIDE.md` |
| Sistem Print | `app-pos/docs/PRINT_SYSTEM_COMPLETE.md` |
| Sistem Sync | `app-pos/docs/SYNC_SYSTEM.md` |
| Offline Mode | `app-pos/OFFLINE_MODE.md` |
| Deployment | `app-pos/DEPLOYMENT.md` |
| LAN Sync | `app-pos/docs/LAN_SYNC.md` |
| Pagination | `app-pos/docs/PAGINATION.md` |

---

## 📜 Lisensi

Private — Hak cipta dilindungi.
