# ANALISIS & OPTIMISASI KODE — NUSANTARA POS (Cloud POS)

## 📋 DAFTAR TEMUAN

| # | Kategori | Severitas | File | Baris |
|---|----------|-----------|------|-------|
| 1 | Bug | **TINGGI** | `services/warehouse.go` | 801 |
| 2 | Bug | **SEDANG** | `services/warehouse.go` | 1399 |
| 3 | Bug | **SEDANG** | `services/sync.go` | 80 |
| 4 | Bug | **SEDANG** | `services/warehouse.go` | 291, 1168, 1231, 1255, 1266 |
| 5 | Bug | **SEDANG** | `services/dashboard.go` | 128, 131 |
| 6 | Bug | **RENDAH** | `services/product.go` | 51, 108 |
| 7 | Bug | **RENDAH** | `services/dashboard.go` | 312 |
| 8 | Bug | **RENDAH** | `services/sync.go` | 388-394 |
| 9 | Dead Code | **SEDANG** | `services/dashboard.go` | 128-131, 144-148, 165-168, 183-186 |
| 10 | Duplikasi | **SEDANG** | `services/purchase.go` | 360-431 |
| 11 | Optimasi Query | **TINGGI** | Semua report | Banyak |
| 12 | Optimasi Query | **SEDANG** | `services/dashboard.go` | 27-106 |
| 13 | Dokumentasi | **RENDAH** | Banyak file | - |
| 14 | Caching | **SARAN** | Semua dashboard | - |
| 15 | Pagination | **SARAN** | Semua list | - |

---

## 🐛 1. BUG: Query di Luar Transaksi (HIGH)

**File:** `services/warehouse.go` — **Baris 801**

```go
// Di dalam fungsi DeductStockByRecipe, KODE ASLI:
var baseUnit string
database.DB.QueryRow(`SELECT base_unit FROM stock_items WHERE id = $1`, itemID).Scan(&baseUnit)

if err := applyMovement(tx, itemID, warehouseID, "sale", baseUnit, ...)
```

**❌ Masalah:**
- Query `SELECT base_unit` menggunakan `database.DB` (koneksi global), **bukan** `tx` (transaksi yang sedang berjalan)
- Error dari `QueryRow` dan `Scan` diabaikan (`_`)
- Jika ada error, `baseUnit` tetap string kosong, tapi fungsi tetap lanjut

**✅ Perbaikan:**

```go
// --- HARUS menggunakan tx, bukan database.DB ---
var baseUnit string
err = tx.QueryRow(`SELECT base_unit FROM stock_items WHERE id = $1 FOR UPDATE`, itemID).Scan(&baseUnit)
if err != nil {
    return fmt.Errorf("bahan baku tidak ditemukan: %w", err)
}
```

---

## 🐛 2. BUG: Race Condition di ProduceStockItem (MEDIUM)

**File:** `services/warehouse.go` — **Baris 1399**

```go
// KODE ASLI (di dalam transaksi tx):
var available float64
_ = tx.QueryRow(`SELECT qty_base FROM stock_ledger WHERE item_id=$1 AND warehouse_id=$2`, 
    r.ChildItemID, req.WarehouseID).Scan(&available)
if available < qtyToDeduct {
    return fmt.Errorf("stok %s tidak mencukupi (butuh %.2f, ada %.2f)", ...)
}

// Kemudian dipotong di applyMovement
err := applyMovement(tx, r.ChildItemID, req.WarehouseID, "production_out", ...)
```

**❌ Masalah:**
- Query `SELECT qty_base` **tanpa `FOR UPDATE`** — Tidak ada row-level lock
- Ada window antara pengecekan stok dan eksekusi deduksi
- Di bawah konkurensi, dua produksi simultan bisa lolos pengecekan dan melebihi stok

**✅ Perbaikan:**

```go
// Tambahkan FOR UPDATE:
_ = tx.QueryRow(`SELECT qty_base FROM stock_ledger WHERE item_id=$1 AND warehouse_id=$2 FOR UPDATE`, 
    r.ChildItemID, req.WarehouseID).Scan(&available)
```

---

## 🐛 3. BUG: sql.NullTime{} sebagai interface{} (MEDIUM)

**File:** `services/sync.go` — **Baris 80-83, 91-113**

```go
var closedAt interface{} = sql.NullTime{}
if req.ClosedAt != "" {
    closedAt = parseTime(req.ClosedAt)
}
```

**❌ Masalah:**
- `sql.NullTime{}` adalah **struct**, bukan `nil`
- Driver PostgreSQL mungkin tidak menangani `sql.NullTime{}` dengan benar sebagai parameter query
- Fungsi `parseTime` mengembalikan campuran `time.Time` dan `sql.NullTime`
- Ketidakonsistenan tipe return bisa menyebabkan panic

**✅ Perbaikan:**

```go
var closedAt interface{} = nil  // Gunakan nil, bukan sql.NullTime{}
if req.ClosedAt != "" {
    if t, err := time.Parse(time.RFC3339, req.ClosedAt); err == nil {
        closedAt = t
    }
}
```

---

## 🐛 4. BUG: rows.Scan Tanpa Pengecekan Error (MEDIUM)

**File:** Berbagai file, terutama `services/warehouse.go`

```go
// Baris 291
rows.Scan(&w.ID, &w.Code, ...)  // Tidak ada error check!

// Baris 1168
rows.Scan(&r.ID, &r.ProductID, ...)  // Tidak ada error check!

// Baris 1231
rows.Scan(&rm.ID, &rm.Name, ...)  // Tidak ada error check!

// Baris 1255
rows.Scan(&ri.ID, &ri.ItemID, ...)  // Tidak ada error check!

// Baris 1266
rows.Scan(&oid)  // Tidak ada error check!
```

**❌ Masalah:**
- Jika `Scan()` gagal (misal kolom NULL, tipe mismatch), data dikembalikan dengan nilai kosong/zero
- Tidak ada log error, aplikasi seolah-olah berhasil
- Data menjadi tidak konsisten

**✅ Perbaikan:**

```go
// Setiap rows.Scan harus diperiksa:
if err := rows.Scan(...); err != nil {
    return nil, fmt.Errorf("scan gagal: %w", err)
}
```

---

## 🐛 5. BUG: Kolom Tidak Pernah Terisi (MEDIUM)

**File:** `services/dashboard.go` — **Baris 128-131, 144-148, 165-168, 183-186**

```sql
-- Dalam 4 varian query (outletStdTail, outletStdTailScoped, outletRangeTail, outletRangeTailScoped):
0::float8 AS sales_custom,
0::float8 AS sales_custom_prev,
```

**❌ Masalah:**
- Kolom `SalesCustom` dan `SalesCustomPrev` di struct `OutletDashboardRow` selalu bernilai 0
- Fitur custom date range untuk dashboard outlet **tidak berfungsi**
- Data palsu (selalu 0) dikirim ke frontend

**✅ Perbaikan:** Implementasi query untuk custom date range atau hapus field dari struct.

---

## 🐛 6. BUG: Error Count Query Diabaikan (LOW)

**File:** `services/product.go` — **Baris 51, 108**

```go
_ = database.DB.QueryRow("SELECT COUNT(*) FROM cloud_products WHERE outlet_id = $1 AND is_deleted = false", outletID).Scan(&total)
```

**❌ Masalah:**
- Jika query count gagal, `total` tetap 0, menyebabkan pagination tidak berfungsi
- Di `GetProducts()` (baris 51): total selalu 0 jika query count error
- Pola yang sama di `GetAllProducts()` (baris 108)

---

## 🐛 7. BUG: Error Dashboard Diabaikan (LOW)

**File:** `services/dashboard.go` — **Baris 312**

```go
_ = database.DB.QueryRow(countQuery, scopeParam).Scan(
    &stats.ActiveOutlets, &stats.TotalProducts, 
    &stats.UnpaidOrders, &stats.UnpaidAmount)
```

**❌ Masalah:**
- Tidak hanya error silent, tapi jika query count gagal, seluruh statistik dashboard akan kosong
- User melihat data 0 yang menyesatkan

---

## 🐛 8. BUG: Type Assertion Tidak Aman (LOW)

**File:** `services/sync.go` — **Baris 388-394**

```go
sinceRaw := parseTime(since)  // Bisa return sql.NullTime{} atau time.Time
var sinceTime interface{}
if t, ok := sinceRaw.(time.Time); ok {  // Type assertion aman
    sinceTime = t.Local()
} else {
    sinceTime = sinceRaw  // Masih bisa sql.NullTime{} di sini
}
```

**❌ Masalah:**
- Jika `parseTime` mengembalikan `sql.NullTime{}`, maka akan digunakan langsung di query SQL
- Perbandingan `updated_at > $2` dengan `sql.NullTime{}` mungkin tidak berfungsi

---

## 🗑️ 9. DEAD CODE: Kolom SalesCustom Selalu 0

**File:** `services/dashboard.go` — **Baris 128-131 dan 144-148**

```sql
-- Di 4 template query outlet yang berbeda:
0::float8 AS sales_custom,
0::float8 AS sales_custom_prev,
```

**File: models/dashboard.go** — Validasi kolom terkait

```go
type OutletDashboardRow struct {
    SalesCustom     float64  // ⚠️ SELALU 0
    SalesCustomPrev float64  // ⚠️ SELALU 0
}
```

**Rekomendasi:** Hapus kolom `SalesCustom` dan `SalesCustomPrev` dari struct dan query.

---

## 🔄 10. DUPLIKASI KODE: getPurchaseChildren

**File:** `services/purchase.go` — **Baris 360-431**

Fungsi `getPurchaseChildren` menduplikasi ~70 baris query SQL dan scan yang sama persis dengan `GetPurchaseRequest` (baris 276-357) dan `ListPurchaseRequests` (baris 49-229).

**✅ Perbaikan:** Jadikan `getPurchaseChildren` memanggil `GetPurchaseRequest` dalam loop atau gunakan shared query builder.

---

## ⚡ 11. OPTIMASI QUERY: Laporan Keuangan (HIGH)

**File:** `services/report.go` — Semua fungsi laporan

### Masalah N+1 Query:

Setiap fungsi laporan menjalankan 3-6 query terpisah:

| Fungsi Laporan | Jumlah Query |
|----------------|-------------|
| GetSalesReport | **5 query** (summary, unpaid, daily, byOutlet, transactions) |
| GetTaxReport | **3 query** (summary, daily, byOutlet) |
| GetCashFlowReport | **3 query + UNION** |
| GetBalanceReport | **6 subquery** + query null-outlet + query null-AP |
| GetProfitLossReport | **5 query** (daily, revenue, income, procurement, opex, byOutlet) |
| GetGeneralLedger | **6 query** (revenue, cash, procurement, payable, receivable, tax) |

### ✅ Rekomendasi Optimasi:

**Gunakan CTE (Common Table Expression) untuk menggabungkan query:**

```sql
-- Contoh optimasi untuk SalesReport (menggabungkan 3 query jadi 1):
WITH summary AS (
    SELECT COUNT(*)::int AS total_tx, COALESCE(SUM(total_amount), 0) AS total_rev
    FROM cloud_transactions WHERE tz_date(created_at) BETWEEN $1 AND $2
    AND ($3 IS NULL OR outlet_id = ANY($3))
),
daily AS (
    SELECT tz_date(created_at) AS date, COUNT(*) AS cnt, SUM(total_amount) AS rev
    FROM cloud_transactions WHERE tz_date(created_at) BETWEEN $1 AND $2
    AND ($3 IS NULL OR outlet_id = ANY($3))
    GROUP BY tz_date(created_at)
)
SELECT * FROM summary, daily;
```

### Index yang Disarankan:

```sql
-- Index untuk tz_date() yang banyak digunakan di laporan
CREATE INDEX idx_cloud_transactions_tz_date 
  ON cloud_transactions (tz_date(created_at));

CREATE INDEX idx_cloud_orders_tz_date 
  ON cloud_orders (tz_date(created_at));

CREATE INDEX idx_cloud_cash_movements_tz_date 
  ON cloud_cash_movements (tz_date(created_at));

-- Composite index untuk filter outlet + date
CREATE INDEX idx_cloud_transactions_outlet_tz_date 
  ON cloud_transactions (outlet_id, tz_date(created_at));

CREATE INDEX idx_purchase_requests_outlet_date 
  ON purchase_requests (outlet_id, tz_date(paid_at))
  WHERE status IN ('partial','paid','received');
```

---

## ⚡ 12. OPTIMASI QUERY: Dashboard (MEDIUM)

**File:** `services/dashboard.go` — **Baris 27-106**

### Masalah:

Query statistik utama menggunakan **17 subquery independen** dalam satu SELECT:

```sql
SELECT
    (SELECT COUNT(*) FROM outlets WHERE ...),        -- subquery 1
    (SELECT COUNT(*) FROM outlets WHERE ...),        -- subquery 2
    (SELECT COUNT(*) FROM cloud_orders WHERE ...),   -- subquery 3
    -- ... total 17 subquery!
```

Setiap subquery men-scan tabel secara terpisah = 17 full table scans per panggilan.

### ✅ Rekomendasi:

**Gunakan agregasi dalam satu pass atau CTE:**

```sql
WITH stats AS (
    SELECT
        COUNT(*) FILTER (WHERE ...) AS total_outlets,
        COUNT(*) FILTER (WHERE is_active) AS active_outlets,
        -- agregasi lainnya
    FROM outlets
)
SELECT * FROM stats;
```

**Terapkan caching untuk dashboard (data tidak berubah setiap detik):**

```go
var (
    dashboardCache     *models.DashboardStats
    dashboardCacheMu   sync.RWMutex
    dashboardCacheTime time.Time
)

func GetCachedDashboard(dateFrom, dateTo string, scopeIDs []string) (*models.DashboardStats, error) {
    dashboardCacheMu.RLock()
    if time.Since(dashboardCacheTime) < 60*time.Second && dashboardCache != nil {
        defer dashboardCacheMu.RUnlock()
        return dashboardCache, nil
    }
    dashboardCacheMu.RUnlock()
    
    dashboardCacheMu.Lock()
    defer dashboardCacheMu.Unlock()
    
    stats, err := GetDashboardStats(dateFrom, dateTo, scopeIDs)
    if err == nil {
        dashboardCache = stats
        dashboardCacheTime = time.Now()
    }
    return stats, err
}
```

---

## ⚡ 13. OPTIMASI: Pagination dengan Keyset

**Masalah:** Semua list menggunakan `OFFSET` yang makin lambat di halaman besar.

```go
offset := (page - 1) * limit
```

### ✅ Rekomendasi Keyset Pagination:

```go
func ListOrdersAfter(cursor time.Time, limit int) ([]Order, error) {
    rows, err := db.Query(`
        SELECT ... FROM orders 
        WHERE created_at < $1 
        ORDER BY created_at DESC 
        LIMIT $2`, cursor, limit)
    ...
}
```

---

## 💾 14. SARAN CACHING

### Query yang Paling Sering Dipanggil (Perlu Cache):

| Query | Frekuensi | Data Change | Rekomendasi Cache |
|-------|-----------|-------------|-------------------|
| Dashboard Stats | Setiap load halaman | Per menit | **TTL 60 detik** |
| Manager Dashboard | Setiap load halaman | Per menit | **TTL 60 detik** |
| Tax Rate | Setiap laporan | Jarang | **TTL 1 jam / startup** |
| Timezone Settings | Setiap request | Jarang | **TTL 1 jam / startup** |
| Laporan Keuangan | On-demand | Sesuai data | **TTL sesuai request** |
| Company Identity | Setiap halaman | Sangat jarang | **Cache saat startup** |

### Implementasi Cache di `services/settings.go`:

```go
var (
    taxRateCache   float64
    taxRateCacheMu sync.RWMutex
    taxRateLastGet time.Time
)

func GetTaxRate() float64 {
    taxRateCacheMu.RLock()
    if time.Since(taxRateLastGet) < 5*time.Minute {
        defer taxRateCacheMu.RUnlock()
        return taxRateCache
    }
    taxRateCacheMu.RUnlock()
    
    taxRateCacheMu.Lock()
    defer taxRateCacheMu.Unlock()
    taxRateCache = getTaxRateFromDB()
    taxRateLastGet = time.Now()
    return taxRateCache
}
```

---

## 🔧 15. PENGGUNAAN `INT` UNTUK QTY

**File:** Beberapa tempat di `services/report.go`

```sql
SUM(COALESCE((item->>'qty')::int, 0))
```

**Masalah:** `qty` diparse sebagai `int` tapi bisa berupa desimal (misal 0.5 porsi).

**✅ Perbaikan:** Gunakan `::float8` atau `::numeric` sebagai ganti `::int`.

---

## 📝 16. DOKUMENTASI BAHASA INDONESIA

Semua dokumentasi komentar dan error message sudah dalam Bahasa Indonesia — bagus! Namun beberapa fungsi masih menggunakan komentar Bahasa Inggris:

### Yang Perlu Diubah:

**services/helpers.go baris 39**: `// normalizeSyncFields ...`
**services/warehouse.go baris 1365**: `// ProduceStockItem creates a ...`
**services/purchase.go baris 36**: `// generateRequestNumber creates ...`
**services/dashboard.go baris 13**: `// GetDashboardStats mengambil ...` ← sudah Indonesia ✅
**services/dashboard.go baris 243**: `// GetManagerDashboard mengembalikan ...` ← sudah Indonesia ✅

---

## 📊 RINGKASAN BIAYA PERBAIKAN

| # | Perbaikan | Dampak | Estimasi Waktu |
|---|-----------|--------|----------------|
| 1 | Bug Transaksi (warehouse.go:801) | **Data inconsistency** | 10 menit |
| 2 | Race Condition (warehouse.go:1399) | **Double deduction** | 5 menit |
| 3 | sql.NullTime (sync.go:80) | **Query gagal diam-diam** | 10 menit |
| 4 | rows.Scan error checks | **Data diam-diam kosong** | 30 menit |
| 5 | Dead code sales_custom | **Kebingungan frontend** | 15 menit |
| 6 | Error count query | **Pagination rusak** | 15 menit |
| 7 | Error dashboard | **Dashboard data 0** | 10 menit |
| 8 | Type assertion (sync.go:388) | **Sync rusak** | 10 menit |
| 9 | Duplikasi purchase code | **Maintenance sulit** | 30 menit |
| 10 | **Optimasi Query Laporan** | **~70% lebih cepat** | 4-6 jam |
| 11 | Optimasi Dashboard | **~50% lebih cepat** | 2-3 jam |
| 12 | Caching | **10x lebih cepat** | 2 jam |
| 13 | Keyset Pagination | **Skalabilitas** | 2 jam |
| 14 | int → float8 untuk qty | **Data presisi** | 15 menit |

---

## 🚀 PRIORITAS EKSEKUSI

### 🔴 SEGERA (1-2 jam):
1. Fix bug transaksi `warehouse.go:801` — Gunakan `tx`, bukan `database.DB`
2. Fix race condition `warehouse.go:1399` — Tambah `FOR UPDATE`
3. Fix `sql.NullTime` di `sync.go` — Ganti dengan `nil`
4. Fix semua `rows.Scan` tanpa error check

### 🟡 PENTING (1 hari):
5. Hapus dead code `sales_custom` dan `sales_custom_prev`
6. Fix semua error silent di count query
7. Optimasi query dashboard dengan CTE
8. Implementasi caching untuk settings (tax rate, timezone)

### 🟢 OPTIMALISASI (2-3 hari):
9. Optimasi query laporan dengan CTE
10. Tambah database index
11. Implementasi caching dashboard
12. Refactor `getPurchaseChildren` (eliminasi duplikasi)

### 🔵 SKALABILITAS (4-5 hari):
13. Keyset pagination untuk data besar
14. Implementasi full caching layer
15. Connection pooling tuning

---

## 📐 POLA PENULISAN KODE YANG DIREKOMENDASIKAN

### ✅ Error Handling Pattern:

```go
func GetSomething(id string) (*Something, error) {
    rows, err := database.DB.Query("SELECT ... FROM table WHERE id = $1", id)
    if err != nil {
        return nil, fmt.Errorf("gagal mengambil data: %w", err)
    }
    defer rows.Close()

    results := make([]Something, 0)
    for rows.Next() {
        var s Something
        if err := rows.Scan(&s.ID, &s.Name); err != nil {
            return nil, fmt.Errorf("gagal scan baris: %w", err)
        }
        results = append(results, s)
    }
    if err := rows.Err(); err != nil {
        return nil, fmt.Errorf("error iterasi: %w", err)
    }
    return &results, nil
}
```

### ✅ Query Count Pattern:

```go
var total int
if err := database.DB.QueryRow("SELECT COUNT(*) FROM ... WHERE ...", args...).Scan(&total); err != nil {
    log.Printf("Peringatan: gagal menghitung total: %v", err)
    total = 0 // atau return error
}
```

### ✅ Transaksi Pattern:

```go
tx, err := database.DB.Begin()
if err != nil {
    return fmt.Errorf("gagal memulai transaksi: %w", err)
}
defer tx.Rollback() // Aman: akan diabaikan jika sudah Commit

// GUNAKAN tx, bukan database.DB
if _, err := tx.Exec(...); err != nil {
    return fmt.Errorf("...: %w", err)
}

if err := tx.Commit(); err != nil {
    return fmt.Errorf("gagal commit transaksi: %w", err)
}
return nil
```

---

## 🎯 KESIMPULAN

Aplikasi Cloud POS ini memiliki arsitektur yang solid dengan Go + Fiber + Vue 3. 

**Temuan kritis yang harus segera diperbaiki:**
1. **Bug transaksi** di `DeductStockByRecipe` — menggunakan koneksi global di dalam transaksi (data inconsistency risk)
2. **Race condition** di `ProduceStockItem` — tanpa `FOR UPDATE` (double deduction risk)
3. **Dead code** kolom `sales_custom` di dashboard (selalu 0)

**Optimasi database yang memberikan dampak terbesar:**
1. **Index** untuk kolom `tz_date()` yang dipakai puluhan kali di laporan
2. **CTE** untuk mengurangi jumlah query laporan dari 5-6 menjadi 1-2
3. **Caching** untuk settings yang jarang berubah (tax rate, timezone)

**Estimasi total perbaikan:** 3-5 hari untuk implementasi penuh
