# 🖨️ Print System Implementation - Complete Guide

## Overview
Sistem print telah diimplementasikan lengkap dengan ESC/POS command generator, background print worker, TCP printer connection, dan API endpoints untuk manual print dan reprint.

## ✅ Komponen yang Telah Diimplementasi

### 1. **ESC/POS Command Generator** (`pkg/printer/escpos.go`)
File ini berisi semua ESC/POS commands untuk thermal printer:

**Command Constants:**
- `ESC_INIT` - Initialize printer
- `ESC_ALIGN_LEFT/CENTER/RIGHT` - Text alignment
- `ESC_SIZE_NORMAL/DOUBLE` - Text sizing
- `ESC_BOLD_ON/OFF` - Bold text
- `ESC_CUT_FULL/PARTIAL` - Paper cutting
- `ESC_NEWLINE` - Line break

**Paper Size Constants:**
- `CharsPerLine58mm = 32` - 58mm paper width
- `CharsPerLine80mm = 48` - 80mm paper width

**Helper Functions:**
```go
RepeatChar(char, count) string        // Repeat character
PadRight(text, width) string          // Right padding
PadLeft(text, width) string           // Left padding  
Center(text, width) string            // Center text
FormatRow(label, value, width) string // Two-column layout
FormatItemRow(...) string             // Four-column item table
FormatNumber(n) string                // Thousand separator (68000 → "68.000")
GetCharLimit(paperSize) int           // Get char width
BuildDivider(char, paperSize) string  // Full-width divider
```

---

### 2. **Receipt Formatter Service** (`pkg/printer/formatter.go`)

**Main Struct:**
```go
type PrintFormatter struct {
    outlet    OutletConfig  // Outlet info
    paperSize string        // "58mm" or "80mm"
    charLimit int           // Character width
}
```

**Outlet Configuration:**
```go
type OutletConfig struct {
    Name          string  // Nama outlet
    Address       string  // Alamat
    Phone         string  // Telepon
    Email         string  // Email (optional)
    Instagram     string  // Instagram handle
    Facebook      string  // Facebook page
    ThankYouMsg   string  // Custom thank you message
    FooterNote    string  // Footer note
    TaxPercentage float64 // Tax percentage (e.g., 10.0 for 10%)
}
```

**Receipt Data:**
```go
type ReceiptData struct {
    ReceiptNumber string
    TableNumber   string
    CustomerName  string
    WaiterName    string
    CashierName   string
    Items         []ReceiptItem
    Subtotal      int
    Tax           int
    Total         int
    PaymentMethod string
    PaidAmount    int
    ChangeAmount  int
    DateTime      time.Time
}
```

**Methods:**
- `FormatReceipt(data ReceiptData) []byte` - Generate full receipt
- `FormatKitchenOrder(...) []byte` - Generate kitchen order (simplified)

**Receipt Layout:**
```
==============================================
           NUSANTARA OUTLET
        Jl. Contoh No. 123, Jakarta
           Telp: 021-12345678
==============================================

No. Struk    : TRX-12345
Tanggal      : 28/01/2026 15:30
Meja         : 5
Customer     : John Doe
Waiter       : Budi
Kasir        : Sarah

----------------------------------------------
ITEM                 QTY  HARGA       TOTAL
----------------------------------------------

Nasi Goreng          2    25.000      50.000
Es Teh Manis         2    5.000       10.000

==============================================

Subtotal                              60.000
Pajak (10%)                            6.000
----------------------------------------------
TOTAL                                 66.000
==============================================

Bayar                                100.000
Kembalian                             34.000

==============================================

        *** Terima Kasih ***
         Selamat Menikmati!

          IG: @nusantara_outlet
          FB: NusantaraOutlet

----------------------------------------------
 Struk ini adalah bukti pembayaran yang sah
```

---

### 3. **TCP Printer Connection** (`pkg/printer/tcp.go`)

**Functions:**
```go
// Send ESC/POS data to printer via TCP
func SendToPrinter(ipAddress string, port int, data []byte) error

// Test printer connectivity
func TestPrinterConnection(ipAddress string, port int) error
```

**Features:**
- Connection timeout: 5 seconds
- Write deadline: 10 seconds
- Automatic connection cleanup
- Error handling for network issues

---

### 4. **Print Worker** (`internal/workers/print_worker.go`)

Background job processor yang polling print queue dan mengirim ke printer.

**Worker Configuration:**
```go
type PrintWorker struct {
    db            *sql.DB
    queries       *db.Queries
    pollInterval  time.Duration  // Default: 2 seconds
    maxRetries    int            // Default: 3
    outletConfig  printer.OutletConfig
    stopChan      chan struct{}
    stoppedChan   chan struct{}
}
```

**Job Processing Flow:**
1. Poll `print_queue` table setiap 2 detik
2. Fetch pending jobs (status = 'pending')
3. Get printer configuration by ID
4. Validate printer is active
5. Format receipt (full/kitchen) berdasarkan printer_type
6. Send to printer via TCP
7. Update status:
   - Success → status = 'done'
   - Failed → increment retry_count, keep pending
   - Max retries exceeded → status = 'failed'

**Print Queue Table Structure:**
```sql
CREATE TABLE print_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    printer_id INTEGER NOT NULL,
    data TEXT NOT NULL,  -- JSON: PrintJobData
    status TEXT NOT NULL CHECK (status IN ('pending', 'done', 'failed')),
    retry_count INTEGER DEFAULT 0,
    error_message TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (printer_id) REFERENCES printers(id)
);
```

**PrintJobData JSON Structure:**
```json
{
  "order_id": 123,
  "receipt_number": "TRX-12345",
  "table_number": "5",
  "customer_name": "John Doe",
  "waiter_name": "Budi",
  "cashier_name": "Sarah",
  "items": [
    {
      "name": "Nasi Goreng",
      "quantity": 2,
      "price": 25000,
      "total": 50000
    }
  ],
  "subtotal": 60000,
  "tax": 6000,
  "total": 66000,
  "payment_method": "cash",
  "paid_amount": 100000,
  "change_amount": 34000,
  "datetime": "2026-01-28T15:30:00Z"
}
```

**Logging:**
- `🖨️ Processing print job #123 (printer #5, retry 0)`
- `✅ Print job #123 completed successfully (printer: Kitchen 1)`
- `❌ Print job #456 failed: connection timeout (will retry)`
- `❌ Print job #789 marked as failed: Max retries (3) exceeded`

---

### 5. **Print API Endpoints** (`internal/handlers/print_handler.go`)

#### **POST /api/v1/print/order** - Manual Print
Menambahkan order ke print queue secara manual.

**Request Body:**
```json
{
  "order_id": 123,
  "printer_id": 5,
  "print_type": "full"  // or "kitchen"
}
```

**Response Success:**
```json
{
  "success": true,
  "message": "Order added to print queue successfully"
}
```

**Use Cases:**
- Print ulang dari halaman order detail
- Print ke printer tertentu
- Manual trigger saat auto-print gagal

---

#### **POST /api/v1/print/reprint/:id** - Reprint Order
Reprint order yang sudah pernah diprint.

**URL Parameters:**
- `id` - Order ID

**Query Parameters (optional):**
- `printer_id` - Specific printer, default ke cashier printer yang active

**Response Success:**
```json
{
  "success": true,
  "message": "Reprint order added to queue successfully"
}
```

**Features:**
- Menambahkan label "(REPRINT)" pada receipt number
- Auto-detect cashier printer jika tidak specify printer_id
- Validasi printer active

---

#### **GET /api/v1/print/queue** - View Print Queue
Melihat status print queue.

**Query Parameters (optional):**
- `status` - Filter by status (pending/done/failed)

**Response:**
```json
{
  "success": true,
  "message": "Print queue fetched successfully",
  "data": [
    {
      "id": 123,
      "printer_id": 5,
      "printer_name": "Cashier 1",
      "status": "pending",
      "retry_count": 1,
      "error_message": "connection timeout",
      "created_at": "2026-01-28T15:30:00Z"
    }
  ]
}
```

**Use Cases:**
- Monitoring print queue status
- Debugging failed prints
- Admin dashboard

---

### 6. **Main.go Integration**

Print worker dijalankan sebagai background goroutine dengan graceful shutdown.

```go
// Initialize outlet config (TODO: Load from database)
outletConfig := printer.OutletConfig{
    Name:          "Nusantara Outlet",
    Address:       "Jl. Contoh No. 123, Jakarta",
    Phone:         "021-12345678",
    Email:         "info@nusantara.com",
    Instagram:     "@nusantara_outlet",
    Facebook:      "NusantaraOutlet",
    ThankYouMsg:   "Selamat Menikmati!",
    FooterNote:    "Struk ini adalah bukti pembayaran yang sah",
    TaxPercentage: 10.0,
}

// Start print worker
printWorker := workers.NewPrintWorker(db, outletConfig)
ctx, cancelPrint := context.WithCancel(context.Background())
go printWorker.Start(ctx)

// Graceful shutdown
signal.Notify(quit, os.Interrupt, syscall.SIGTERM)
<-quit
cancelPrint()  // Stop print worker
```

---

## 🚀 How to Use

### 1. **Setup Printer**
Tambah printer melalui UI Setting → Printer Management:
- Name: "Cashier 1"
- IP Address: 192.168.1.100
- Port: 9100 (default)
- Type: cashier/kitchen/bar
- Paper Size: 58mm/80mm

### 2. **Auto Print on Payment**
Saat order selesai payment, tambahkan ke print queue:

```go
// In order payment handler
data := workers.PrintJobData{
    OrderID:       orderID,
    ReceiptNumber: fmt.Sprintf("TRX-%d", orderID),
    TableNumber:   order.TableNumber,
    // ... fill other fields
}

dataJSON, _ := json.Marshal(data)

_, err = db.Exec(`
    INSERT INTO print_queue (printer_id, data, status, retry_count)
    VALUES (?, ?, 'pending', 0)
`, cashierPrinterID, string(dataJSON))
```

### 3. **Manual Print/Reprint**
Via API endpoint:
```bash
# Manual print
curl -X POST http://localhost:8080/api/v1/print/order \
  -H "Content-Type: application/json" \
  -d '{"order_id": 123, "printer_id": 5}'

# Reprint
curl -X POST http://localhost:8080/api/v1/print/reprint/123

# View queue
curl http://localhost:8080/api/v1/print/queue?status=pending
```

### 4. **Monitor Print Queue**
Lihat status queue:
```bash
curl http://localhost:8080/api/v1/print/queue
```

Check failed prints:
```bash
curl http://localhost:8080/api/v1/print/queue?status=failed
```

---

## 🔧 Troubleshooting

### Printer Not Printing
1. **Check printer status:**
   - Pastikan printer active di database
   - Test koneksi: `telnet <printer-ip> 9100`
   
2. **Check print queue:**
   ```bash
   curl http://localhost:8080/api/v1/print/queue?status=failed
   ```
   
3. **Common errors:**
   - `connection timeout` → Printer offline/IP salah
   - `Max retries exceeded` → Printer unreachable > 3x
   - `Printer not active` → Toggle printer di UI

### Receipt Format Issues
1. **Paper size mismatch:**
   - Pastikan setting paper_size sesuai dengan printer fisik
   - 58mm = 32 chars per line
   - 80mm = 48 chars per line

2. **Character encoding:**
   - ESC/POS menggunakan LATIN charset
   - Pastikan karakter Indonesia (é, ñ, dll) di-escape

### Performance Issues
1. **Print queue backlog:**
   - Worker poll interval: 2 detik
   - Jika ada banyak antrian, pertimbangkan scale worker
   
2. **Network latency:**
   - Connection timeout: 5 detik
   - Write timeout: 10 detik
   - Pastikan LAN stabil

---

## 📝 TODO / Future Improvements

1. **Outlet Config from Database**
   - Buat tabel `outlet_config` untuk simpan info outlet
   - Load dinamis saat worker start
   - Update tanpa restart server

2. **Printer Status Monitoring**
   - Real-time printer health check
   - Auto-disable offline printer
   - Alert notification

3. **Print History**
   - Archive successful prints
   - Audit log
   - Statistics (total prints, failed ratio)

4. **Multiple Workers**
   - Scale worker untuk high-volume
   - Load balancing per printer

5. **Web Socket Notifications**
   - Real-time print status update ke frontend
   - Toast notification saat print sukses/gagal

6. **Advanced Formatting**
   - Logo support (ESC/POS image commands)
   - Barcode/QR code
   - Custom fonts

7. **Test Mode**
   - Test print button (print sample receipt)
   - Dry-run mode tanpa kirim ke printer fisik

---

## 🎯 Architecture Summary

```
┌─────────────────┐
│  Order Payment  │
│   (Frontend)    │
└────────┬────────┘
         │
         │ POST /api/v1/orders/:id/payment
         ▼
┌─────────────────┐
│ Order Handler   │  Insert into print_queue
│  (Backend)      ├──────────────┐
└─────────────────┘              │
                                 ▼
                        ┌─────────────────┐
                        │  print_queue    │
                        │  (SQLite)       │
                        └────────┬────────┘
                                 │
                                 │ Poll every 2s
                                 ▼
                        ┌─────────────────┐
                        │  Print Worker   │
                        │  (Background)   │
                        └────────┬────────┘
                                 │
                                 │ Format receipt
                                 ▼
                        ┌─────────────────┐
                        │ PrintFormatter  │
                        │  (ESC/POS)      │
                        └────────┬────────┘
                                 │
                                 │ ESC/POS bytes
                                 ▼
                        ┌─────────────────┐
                        │  TCP Handler    │
                        │  192.168.1.100  │
                        │  Port: 9100     │
                        └────────┬────────┘
                                 │
                                 ▼
                        ┌─────────────────┐
                        │ Thermal Printer │
                        │   (Hardware)    │
                        └─────────────────┘
```

---

## ✅ Verification Checklist

- [x] ESC/POS commands implemented
- [x] Receipt formatter service created
- [x] TCP printer connection handler
- [x] Print worker background job
- [x] Print queue table
- [x] API endpoints (print, reprint, queue status)
- [x] Main.go integration with graceful shutdown
- [x] Error handling and retry mechanism
- [x] Logging for monitoring
- [x] Support 58mm and 80mm paper
- [x] Kitchen vs Cashier receipt formats
- [x] Printer type routing (cashier/kitchen/bar)
- [x] Documentation complete

---

## 📊 Server Logs

Saat server berjalan, Anda akan melihat:

```
2026/01/28 09:17:06 Database connected and migrated successfully
2026/01/28 09:17:06 Cloud sync disabled - Configure via /api/v1/config/outlet
2026/01/28 09:17:06 🖨️  Print worker started
2026/01/28 09:17:06 🖨️  Print Worker started
2026/01/28 09:17:06 Config management endpoints registered
2026/01/28 09:17:06 LAN device sync endpoints registered
2026/01/28 09:17:06 ✅ Frontend UI served at root path /
2026/01/28 09:17:06 ============================================
2026/01/28 09:17:06 🚀 POS Server starting on port 8080
2026/01/28 09:17:06 📱 UI: http://localhost:8080
2026/01/28 09:17:06 🌐 API: http://localhost:8080/api/v1
2026/01/28 09:17:06 🌍 LAN Access: http://192.168.1.6:8080
2026/01/28 09:17:06 ============================================
```

**Konfirmasi print worker running:**
- ✅ `🖨️ Print worker started` - Worker initialized
- ✅ `🖨️ Print Worker started` - Worker loop running

Print job logs akan muncul saat ada job di queue:
- `🖨️ Processing print job #123 (printer #5, retry 0)`
- `✅ Print job #123 completed successfully (printer: Cashier 1)`

---

**🎉 Print System Implementation Complete!**

Semua komponen telah diimplementasikan dan server berjalan dengan sukses.
Print worker sudah polling print queue setiap 2 detik, siap memproses print jobs.

**Next Steps:**
1. Setup printer fisik di jaringan LAN
2. Tambah printer via UI (Setting → Printer Management)
3. Test print saat order payment
4. Monitor print queue via API endpoint
