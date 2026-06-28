# Sync Transaksi — Rincian Pembayaran (Gabung Bayar / Split Bill)

Dokumen ini menjelaskan perubahan payload sync transaksi dari app POS (Flutter)
agar **rincian pembayaran multi-metode** (mis. QRIS 50.000 + Cash 30.000)
tercatat di cloud. Perubahan sisi app **sudah selesai**; backend perlu menyesuaikan.

## Latar belakang

Sebelumnya, saat sebuah order dibayar dengan **lebih dari satu metode**
(fitur *Gabung Bayar* / *Split Bill*), cloud hanya menerima **satu**
`payment_method` (metode terakhir) untuk total penuh. Pecahan metode hilang,
sehingga **rekap omzet per metode pembayaran di cloud meleset**.

Omzet total & jumlah transaksi tetap benar — yang hilang hanya rincian per metode.

## Payload baru (endpoint sync transaksi)

```json
{
  "local_id": "01J...",
  "order_id": "01J...",
  "subtotal": 70000,
  "tax_amount": 7700,
  "other_charges_total": 0,
  "charges": [ { "name": "PB1", "charge_type": "percentage", "value": 11, "amount": 7700 } ],
  "total_amount": 80000,

  "payment_method": "mixed",      // BARU: bisa "mixed" bila >1 metode
  "cash_amount": 30000,           // BERUBAH: total tunai sebenarnya
  "change_amount": 0,
  "payments": [                   // BARU: rincian per metode
    { "payment_method": "qris", "amount": 50000, "payment_note": null, "created_at": "2026-06-25T10:00:00" },
    { "payment_method": "cash", "amount": 30000, "payment_note": null, "created_at": "2026-06-25T10:01:00" }
  ],

  "cashier_name": "",
  "created_by": "01J...",
  "items": [
    { "product_name": "Nasi Goreng", "quantity": 1, "price": 70000, "subtotal": 70000 }
  ],
  "created_at": "2026-06-25T10:01:00"
}
```

### Field yang berubah / baru

| Field | Status | Keterangan |
|---|---|---|
| `payment_method` | berubah | Bisa bernilai **`"mixed"`** bila transaksi punya >1 metode. Untuk 1 metode tetap seperti biasa (`cash` / `qris` / `card` / `transfer`). |
| `cash_amount` | berubah | Kini = **total tunai sebenarnya** (jumlah seluruh pembayaran bermetode `cash`). Sebelumnya hanya terisi bila metode tunggal = `cash`. |
| `payments[]` | **baru** | Array rincian tiap pembayaran. **Selalu ada** (minimal 1 elemen) untuk transaksi dari app versi baru. |

## Yang perlu dilakukan backend

### 1. Tabel baru `transaction_payments`

```sql
CREATE TABLE transaction_payments (
    id              BIGSERIAL PRIMARY KEY,
    transaction_id  BIGINT NOT NULL REFERENCES transactions(id),
    payment_method  VARCHAR(20) NOT NULL,   -- cash | qris | card | transfer
    amount          NUMERIC(14,2) NOT NULL,
    payment_note    TEXT,
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX idx_transaction_payments_txid   ON transaction_payments(transaction_id);
CREATE INDEX idx_transaction_payments_method ON transaction_payments(payment_method);
```

### 2. Terima field baru di DTO/struct transaksi

- Izinkan `payment_method = "mixed"` (jangan ditolak validasi enum lama).
- Map `cash_amount` apa adanya.
- Tambah field `payments []PaymentLine` pada struct request, contoh:

```go
type PaymentLine struct {
    PaymentMethod string  `json:"payment_method"`
    Amount        float64 `json:"amount"`
    PaymentNote   *string `json:"payment_note"`
    CreatedAt     string  `json:"created_at"`
}

type TransactionSyncRequest struct {
    // ... field lama ...
    PaymentMethod string        `json:"payment_method"`
    CashAmount    float64       `json:"cash_amount"`
    ChangeAmount  float64       `json:"change_amount"`
    Payments      []PaymentLine `json:"payments"`
    // ... field lama ...
}
```

### 3. Logika simpan

1. Insert header `transactions` seperti biasa.
2. Loop `payments[]` → insert tiap elemen ke `transaction_payments`.
3. **Fallback** (klien lama tanpa `payments[]`): buat 1 baris dari
   `payment_method` + `total_amount`. App versi baru selalu mengirim
   `payments[]`, jadi backend cukup mengandalkan array ini bila ada.

### 4. Laporan / rekap per metode

Rekap "berapa cash vs QRIS" diambil dari **`transaction_payments`**
(jumlahkan `amount` per `payment_method`), **bukan** dari kolom
`payment_method` di header `transactions` — karena header bisa bernilai `"mixed"`.

```sql
SELECT payment_method, SUM(amount) AS total
FROM transaction_payments tp
JOIN transactions t ON t.id = tp.transaction_id
WHERE t.created_at::date = CURRENT_DATE
GROUP BY payment_method;
```

## Ringkas

> Sync transaksi kini bisa berisi `payment_method: "mixed"` dan array
> `payments[]` (rincian metode + nominal). Tindakan: (a) buat tabel
> `transaction_payments`, (b) terima nilai `"mixed"`, (c) simpan tiap elemen
> `payments[]`, (d) ubah rekap per-metode agar baca dari tabel itu.
> `cash_amount` sekarang = total tunai sebenarnya.

## Nama Kasir & Nama Pemesan

Selain rincian pembayaran, payload sync juga membawa **nama kasir** (pemroses
bayar) dan **nama pemesan** (pembuat order / waiter). Sebelumnya `cashier_name`
dikirim kosong dan nama pemesan tidak dikirim sama sekali.

### Konsep "Pemesan" (sama dengan struk)

Struk mengelompokkan item **per pemesan** ("Pemesan : Nama") berdasarkan
`waiter_name` tiap item. Label pemesan di kepala struk = **gabungan nama
pemesan unik** (dipisah koma), fallback ke pembuat order bila item tak ber-nama.

Payload sync mengikuti konsep yang sama:

- **`items[].waiter_name`** = sumber otoritatif. Cloud dapat **merekonstruksi
  pengelompokan persis seperti struk** dengan mengelompokkan item per
  `waiter_name`.
- **`orderer_name`** (root) = label gabungan siap-pakai (mis. `"Andi, Budi"`),
  identik dengan baris "Pemesan" di struk.
- **`created_by`** (order) = pembuat order tunggal (1 orang) — berbeda dari
  `orderer_name` yang bisa berisi banyak nama.

### Payload **order** (entityType `order`)

| Field | Letak | Keterangan |
|---|---|---|
| `created_by` | root | Nama akun **pembuat order** (1 orang). |
| `orderer_name` | root | Label **pemesan** gabungan (= baris "Pemesan" di struk). |
| `customer_name` | root | Nama **pelanggan** (beda dari pemesan). |
| `pax` | root | **Jumlah tamu** (≥1). Wajib diisi kasir/waiter saat order baru. Simpan di kolom `pax`. |
| `items[].waiter_name` | per item | Nama **pemesan item** itu — sumber pengelompokan struk. |

### Payload **transaction** (entityType `transaction`)

| Field | Keterangan |
|---|---|
| `cashier_name` | Nama **kasir** pemroses bayar (kini terisi, bukan kosong lagi). |
| `created_by` | Sama dengan `cashier_name` (nama kasir). |
| `orderer_name` | Label **pemesan** gabungan (= baris "Pemesan" di struk). |
| `items[].waiter_name` | Nama pemesan tiap item — sumber pengelompokan struk. |

> Catatan: nilai-nilai ini berupa **nama akun** (string), bukan ID numerik.
> Bila backend ingin memetakan ke user, lakukan lookup by nama/username, atau
> minta app mengirim ID di iterasi berikutnya.

Backend perlu: tambah kolom `cashier_name` & `orderer_name` di `transactions`
(atau tabel terkait), dan `created_by` / `waiter_name` di order & order_items
bila ingin menyimpannya.

## Waktu transaksi (transaksi offline / tertunda)

Transaksi bisa dibuat saat **offline** lalu disinkron belakangan (outbox). Payload
karena itu membawa **waktu transaksi ASLI** — backend WAJIB memakainya, bukan
waktu terima/sync.

| Field | Keterangan |
|---|---|
| `transaction_date` | **Waktu transaksi asli** (saat pembayaran di perangkat). Pakai ini untuk kolom tanggal transaksi & laporan. |
| `created_at` | Sama (kompatibilitas). |
| `sync_timestamp` (batch) | Waktu batch dikirim — **metadata saja**, JANGAN dijadikan tanggal transaksi. |

Jadi: jangan set `transaction_date = now()` di server saat menerima. Selalu ambil
dari payload `transaction_date` (fallback `created_at`). Bila tidak, transaksi
offline yang baru tersinkron akan tercatat dengan tanggal yang salah (hari sync).

## Sumber payload (sisi app)

`app-pos-flutter/lib/repositories/order_repository.dart` →
fungsi `_enqueueTransaction` (membangun payload) dan `splitBillPayment`
(mengumpulkan `payments[]` dari tabel `payments` lokal saat order lunas).
