# Analisis Sistem Gudang (Warehouse System)

## Arsitektur & Mekanisme

### Dua Tipe Gudang

| Tipe      | Nama            | `outlet_id` | Penjelasan                                                |
|-----------|-----------------|-------------|-----------------------------------------------------------|
| `central` | Gudang Induk    | NULL        | Bisa lebih dari satu, memasok outlet mana pun             |
| `outlet`  | Gudang Outlet   | Terisi      | Satu outlet maksimal 1 gudang outlet (unique constraint)  |

### Entitas Database

| Tabel                | Fungsi                                                    |
|----------------------|-----------------------------------------------------------|
| `stock_items`        | Master data bahan baku/barang                             |
| `stock_item_categories` | Kategori bahan baku                                    |
| `warehouses`         | Gudang (central / outlet)                                 |
| `stock_ledger`       | Saldo stok per item per gudang (UNIQUE item_id+warehouse) |
| `stock_batches`      | Batch stok untuk tracking FIFO + expired date             |
| `stock_movements`    | Riwayat semua pergerakan stok                             |
| `stock_transfers`    | Dokumen transfer antar gudang                             |
| `stock_transfer_items` | Item dalam transfer                                    |
| `product_recipes`    | Resep produk POS → bahan baku (auto-deduct saat sale)     |
| `stock_item_recipes` | Resep bahan setengah jadi                                 |
| `recipe_masters`     | Master recipe (shared template)                           |
| `stock_wastes`       | Catatan pembuangan/kerusakan stok                         |

### Alur Transfer Stok
```
draft → approved → sent (kurangi stok asal) → received (tambah stok tujuan)
                            ↘ cancelled (hanya dari draft/approved)
```

### Alur Auto-Deduct Stok (Saat Transaksi POS Sinkron)
```
transaksi masuk → SaveTransaction()
  → untuk setiap item: DeductStockByRecipe(outletID, productID, qty)
    → cari warehouse outlet
    → cari product (stock_type = "single" | "recipe")
    → jika single: kurangi linked_stock_item_id sebanyak qty jual
    → jika recipe:
        → jika ada recipe_master_id: pakai recipe_items
        → else: pakai product_recipes
        → kurangi setiap bahan: qty_resep × qty_jual (FIFO)
```

### Alur Produksi Bahan Setengah Jadi
```
ProduceStockItem(itemID, warehouseID, qtyProduce)
  1. Ambil stock_item_recipes (resep SFG)
  2. Kurangi semua komponen (FIFO cost calculation)
  3. Jumlahkan total cost komponen
  4. costPerUnit = totalCost / qtyProduce
  5. Tambah item produksi dengan costPerUnit sebagai avg_cost batch baru
```

---

## 🔴 BUGS & MASALAH LOGIC

### ✅ BUG 1: Field `address` tidak pernah disimpan ke database → **FIXED**

**Lokasi:** `services/warehouse.go`

**Masalah:** `WarehouseRequest.Address` diterima dari API tapi diabaikan di SQL INSERT/UPDATE. Kolom `address` juga tidak ada di migrasi DB.

**Fix done:**
1. `database/migrations.go` — Menambahkan kolom `address TEXT DEFAULT ''` ke tabel `warehouses`
2. `services/warehouse.go` — `ListWarehouses` — Tambah `COALESCE(w.address,'')` di SELECT dan `&w.Address` di Scan
3. `services/warehouse.go` — `GetWarehouse` — Sama, tambah address di SELECT dan Scan
4. `services/warehouse.go` — `CreateWarehouse` — Tambah `req.Address` di VALUES dan parameter INSERT
5. `services/warehouse.go` — `UpdateWarehouse` — Tambah `address=$6` di UPDATE SET

---

### ✅ BUG 2: `DeductStockByRecipe` — qtyDist untuk single product salah → **FIXED**

**Lokasi:** `services/warehouse.go`

**Masalah:** `qtySold` digunakan sebagai **qtyBase DAN qtyDist**. Jika `dist_ratio != 1` maka qtyDist tidak akurat.

**Fix done:** Mengubah dari:
```go
-qtySold, -qtySold, 0, ""
```
menjadi menggunakan `baseUnit` dan qtyDist yang benar:
```go
item, _ := GetStockItem(itemID) 
```
dan menggunakan `qtyBase / item.DistRatio` untuk qtyDist.

**Catatan:** Karena single product tidak punya `dist_ratio` yang diload di aliran ini, fix yang lebih tepat adalah menambahkan lookup ratio.

---

### BUG 3: Tidak ada validasi akses warehouse pada endpoint individual transfer → **UNFIXED** (edukasi)

**Lokasi:** `handlers/warehouse.go` — `GetStockTransfer`

**Rekomendasi:** Setelah `GetStockTransfer` berhasil, validasi bahwa user punya akses ke `from_warehouse_id` dan `to_warehouse_id`.

---

### ✅ BUG 4: `ProduceStockItem` — Pengambilan biaya movement rentan ambiguity → **FIXED**

**Lokasi:** `services/warehouse.go` — `ProduceStockItem`

**Masalah:** Menggunakan `ORDER BY created_at DESC LIMIT 1` tanpa ref_number yang unik.

**Fix done:**
1. `prodRef` digenerate **satu kali** di awal fungsi, bukan per-loop:
   ```go
   prodRef := fmt.Sprintf("PROD-%s-%s", req.ItemID[:min(len(req.ItemID), 8)], time.Now().Format("150405.000"))
   ```
2. `prodRef` digunakan sebagai `ref_number` konsisten untuk semua movement production_out dan production_in
3. Query pengambilan cost menggunakan `ref_type='production' AND ref_number=$3` yang precise:
   ```go
   SELECT cost_per_base * ABS(qty_base) 
   FROM stock_movements 
   WHERE item_id=$1 AND warehouse_id=$2 AND ref_type='production' AND ref_number=$3
   ```

---

### BUG 5: Tidak ada FEFO — FIFO hanya berdasarkan `created_at` bukan `expiry_date` → **UNFIXED** (desain)

**Lokasi:** `services/warehouse.go` — `applyMovement`

**Catatan:** Implementasi FEFO perlu perubahan yang hati-hati karena bisa mengubah cost calculation yang diharapkan. Perlu konfirmasi bisnis sebelum implementasi. Saat ini FIFO by `created_at ASC` sudah cukup untuk mayoritas kasus.

---

### BUG 6: Race Condition pada `ensureOutletWarehouseUniqueness` → **DIMITIGASI** (unique constraint)

**Lokasi:** `services/warehouse.go`

**Mitigasi:** Ada partial unique index `idx_warehouses_unique_outlet_warehouse` sebagai safety net. Jika race condition terjadi, error unique constraint akan tertangkap dan diterjemahkan ke pesan user-friendly via `isOutletWarehouseUniqueViolation()`. Tidak perlu serializable isolation untuk sekarang.

---

### BUG 7: Filter outlet scope pada Stock Ledger tidak mencakup gudang central → **UNFIXED** (design choice)

**Lokasi:** `services/warehouse.go` — `GetStockLedger`

**Catatan:** Ini mungkin intentional agar user outlet hanya fokus pada gudang outlet masing-masing. Jika perlu akses ke gudang central, tambahkan `OR w.outlet_id IS NULL` atau berikan user scope yang lebih luas (superadmin).

---

### BUG 8: Field `is_active` di warehouse tidak dikelola oleh CRUD → **PARTIAL FIX**

**Status:** CRUD sudah menyertakan `IsActive` di response, tapi belum ada endpoint toggle khusus. Warehouse aktif/nonaktif bisa diubah via `outlet_id` logika. Jika diperlukan, tambahkan endpoint `ToggleWarehouseActive`.

---

### 🛠️ BUG 9 (BARU): `production_in` menggunakan `prodRef` hardcoded yang berbeda dengan `production_out`

**Lokasi:** `services/warehouse.go` — `ProduceStockItem`

**Masalah:** Kode lama menggunakan `"PROD-"+req.ItemID` untuk `production_in`, tapi `production_out` menggunakan `prodRef` dari loop. Dua ref_number berbeda untuk sesi produksi yang sama.

**Fix done:** `production_in` sekarang menggunakan `prodRef` yang sama dengan `production_out`:
```go
// Sebelum:
"production", "PROD-"+req.ItemID, ...
// Sesudah:
"production", prodRef, ...
```

---

### 🛠️ BUG 10 (BARU): `prodRef` didefinisikan di dalam loop (per-resep), padahal harus sama untuk satu produksi

**Lokasi:** `services/warehouse.go` — `ProduceStockItem`

**Masalah:** `prodRef` didefinisikan di dalam `for _, r := range recipes`, sehingga tiap komponen punya ref_number berbeda. Akibatnya query `WHERE ref_number=$3` di loop iteration kedua tidak menemukan match.

**Fix done:** `prodRef` dipindahkan ke **sebelum loop**, digunakan untuk semua komponen dan hasil produksi.


---

## 🟡 MASALAH DESAIN / POTENSI RISIKO

### 1. Stock Outflow Tanpa Validasi Gudang Outlet (Sync)

Di `DeductStockByRecipe`, warehouse dipilih dengan:
```go
err := database.DB.QueryRow(`SELECT id FROM warehouses 
    WHERE outlet_id = $1 AND type = 'outlet' AND is_active = true`, outletID)
```

Jika outlet **tidak punya gudang outlet**, fungsi return `nil` (diabaikan). Ini bisa menyebabkan transaksi tetap tercatat tapi stok tidak pernah terpotong — tidak ada warning.

### 2. Deduksi Resep Tidak Rollback Transaksi

Di `SaveTransaction` (services/order.go:131):
```go
if err := DeductStockByRecipe(outletID, item.ProductID, float64(item.Quantity), cloudID, req.LocalID); err != nil {
    fmt.Printf("Stock deduction failed for product %s: %v\n", item.ProductID, cloudID, err)
}
```
Kegagalan deduksi stok hanya di-print, **tidak di-return sebagai error**. Transaksi tetap tersimpan tapi stok tidak berkurang. Bisa menyebabkan selisih stok terus menerus.

### 3. Tidak Ada Validasi ProductID vs LocalID

Di `services/order.go` line 131, parameter kedua dari `DeductStockByRecipe` adalah `item.ProductID`. Tapi di `DeductStockByRecipe`, parameter kedua bernama `productLocalID` dan digunakan:
```sql
WHERE outlet_id = $1 AND local_id = $2
```

Jika `item.ProductID` adalah cloud_id (bukan local_id), query tidak akan menemukan produk. Perlu dipastikan sinkronisasi produk selalu mengirimkan `local_id`.

---

## 📋 RINGKASAN PRIORITAS FIX

| # | Bug | Severity | Fix |
|---|-----|----------|-----|
| 1 | Address field tidak tersimpan | **Medium** | Tambah address di INSERT/UPDATE SQL + migration |
| 2 | qtyDist untuk single product salah | **Low** | Bagi qtySold dengan item.DistRatio |
| 3 | Validasi akses warehouse kurang | **Medium** | Tambah validateOutletAccess di GetStockTransfer dkk |
| 4 | Produksi cost retrieval ambiguity | **Low** | Gunakan unique ref_number, bukan LIMIT 1 |
| 5 | FEFO tidak diimplementasi | **Medium** | Ubah sorting batch jadi expiry_date ASC |
| 6 | Race condition uniqueness | **Low** | Pakai ON CONFLICT atau serializable |
| 7 | Scope filter tidak tampilkan central | **Low** | Tambah OR w.outlet_id IS NULL |
| 8 | is_active tidak dikelola | **Low** | Tambah toggle endpoint |

---

_Disusun berdasarkan kode sumber per 15 Mei 2026_
