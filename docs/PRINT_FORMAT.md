# Print Format Specification

## Overview
Sistem printing menggunakan ESC/POS commands untuk thermal printer dengan support ukuran kertas 58mm dan 80mm.

## Print Queue System

### Database Schema
```sql
CREATE TABLE IF NOT EXISTS print_queue (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL,
    printer_ip TEXT NOT NULL,
    content TEXT NOT NULL,           -- ESC/POS formatted content
    status TEXT DEFAULT 'pending',   -- pending, done, failed
    retry_count INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### Printer Configuration
```sql
CREATE TABLE IF NOT EXISTS printers (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    ip_address TEXT NOT NULL UNIQUE,
    port INTEGER DEFAULT 9100,
    printer_type TEXT CHECK (printer_type IN ('kitchen', 'bar', 'cashier')),
    paper_size TEXT DEFAULT '80mm' CHECK (paper_size IN ('58mm', '80mm')),
    is_active INTEGER DEFAULT 1
);
```

## ESC/POS Format Template

### Complete Receipt Format (80mm - 48 characters)
```
==================================================
          WARUNG NUSANTARA
     Jl. Raya Merdeka No. 123, Jakarta
          Telp: 0812-3456-7890
==================================================

No. Struk : #TRX-001234
Tanggal   : 28/01/2026 14:30
Meja      : #5
Customer  : Andi Wijaya
Waiter    : Budi Santoso
Kasir     : Siti Nurhaliza

--------------------------------------------------
ITEM                     QTY    HARGA      TOTAL
- - - - - - - - - - - - - - - - - - - - - - - - -

Nasi Goreng Spesial        2   17.500    35.000
Es Teh Manis               2    4.000     8.000
Ayam Goreng Kremes         1   25.000    25.000

==================================================
Subtotal                                 68.000
Pajak (10%)                               6.800
- - - - - - - - - - - - - - - - - - - - - - - - -
TOTAL                            Rp     74.800
==================================================
Bayar (Cash)                            100.000
Kembalian                                25.200

==================================================
           *** Terima Kasih ***
            Selamat Menikmati!
            
         IG: @warung.nusantara
         FB: Warung Nusantara
         
- - - - - - - - - - - - - - - - - - - - - - - - -
   Struk ini adalah bukti pembayaran sah
==================================================
```

### Compact Receipt Format (58mm - 32 characters)
```
================================
    WARUNG NUSANTARA
 Jl. Raya Merdeka No. 123
   Telp: 0812-3456-7890
================================

No     : #TRX-001234
Tgl    : 28/01 14:30
Meja   : #5
Cust   : Andi Wijaya
Waiter : Budi
Kasir  : Siti

--------------------------------
ITEM          QTY  HARGA  TOTAL
- - - - - - - - - - - - - - - -

Nasi Goreng    2   17.5k  35.000
  Spesial
Es Teh Manis   2    4.0k   8.000
Ayam Goreng    1   25.0k  25.000
  Kremes

================================
Subtotal               68.000
Pajak (10%)             6.800
- - - - - - - - - - - - - - - -
TOTAL          Rp     74.800
================================
Bayar (Cash)          100.000
Kembalian              25.200

================================
   *** Terima Kasih ***
    Selamat Menikmati!
    
    IG: @warung.nusantara
    FB: Warung Nusantara
    
- - - - - - - - - - - - - - - -
Struk bukti pembayaran sah
================================
```

## ESC/POS Command Reference

### Basic Commands
```go
const (
    ESC = "\x1b"
    GS  = "\x1d"
    
    // Initialize printer
    INIT = ESC + "@"
    
    // Text alignment
    ALIGN_LEFT   = ESC + "a" + "\x00"
    ALIGN_CENTER = ESC + "a" + "\x01"
    ALIGN_RIGHT  = ESC + "a" + "\x02"
    
    // Text size
    NORMAL     = GS + "!" + "\x00"
    DOUBLE_H   = GS + "!" + "\x01"  // Double height
    DOUBLE_W   = GS + "!" + "\x10"  // Double width
    DOUBLE_HW  = GS + "!" + "\x11"  // Double height and width
    
    // Text style
    BOLD_ON    = ESC + "E" + "\x01"
    BOLD_OFF   = ESC + "E" + "\x00"
    
    // Cut paper
    CUT_FULL   = GS + "V" + "\x00"
    CUT_PARTIAL = GS + "V" + "\x01"
    
    // Line feed
    LF = "\n"
)
```

## Outlet Configuration

### Database Table (Already Exists!)
```sql
CREATE TABLE IF NOT EXISTS outlet_config (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    outlet_id TEXT NOT NULL UNIQUE,
    outlet_name TEXT NOT NULL,              -- "WARUNG NUSANTARA"
    outlet_code TEXT NOT NULL UNIQUE,       -- "WN001"
    address TEXT,                           -- "Jl. Raya Merdeka No. 123, Jakarta"
    phone TEXT,                             -- "0812-3456-7890"
    email TEXT,                             -- "info@warung.com"
    instagram TEXT,                         -- "@warung.nusantara"
    facebook TEXT,                          -- "Warung Nusantara"
    website TEXT,                           -- "www.warung.com"
    thank_you_message TEXT,                 -- "Terima Kasih\nSelamat Menikmati!"
    footer_note TEXT,                       -- "Struk ini adalah bukti pembayaran yang sah"
    tax_percentage REAL DEFAULT 10.0,       -- Tax rate
    
    cloud_api_url TEXT NOT NULL,
    cloud_api_key TEXT NOT NULL,
    is_active INTEGER DEFAULT 1,
    sync_enabled INTEGER DEFAULT 1,
    sync_interval_minutes INTEGER DEFAULT 5,
    last_sync_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### Why Separate Configuration?

✅ **Centralized Management**
- Single source of truth untuk semua info outlet
- Mudah update tanpa ubah code
- Bisa sync ke cloud untuk multi-outlet

✅ **Consistency Across Printers**
- Semua printer (kitchen, bar, cashier) pakai info sama
- Tidak perlu set ulang per printer
- Brand consistency terjaga

✅ **Dynamic Content**
- Admin bisa ubah ucapan sesuai event/promo
- Update sosial media tanpa deploy ulang
- A/B testing pesan marketing

✅ **Multi-Tenant Ready**
- Support multiple outlets dalam 1 sistem
- Tiap outlet punya konfigurasi sendiri
- Franchise-ready architecture

### API Endpoint Structure
```
GET    /api/v1/config/outlet          - Get current outlet config
PUT    /api/v1/config/outlet          - Update outlet config
POST   /api/v1/config/outlet/test-print - Test print dengan config
```

### Usage in Print Formatter
```go
type ReceiptData struct {
    // From outlet_config
    OutletName       string
    Address          string
    Phone            string
    Instagram        string
    Facebook         string
    ThankYouMessage  string
    FooterNote       string
    TaxPercentage    float64
    
    // From transaction
    ReceiptNo        string
    TransactionDate  time.Time
    TableNumber      string
    CustomerName     string
    WaiterName       string
    CashierName      string
    
    // Items
    Items            []OrderItem
    Subtotal         float64
    Tax              float64
    Total            float64
    
    // Payment
    PaymentMethod    string
    PaidAmount       float64
    ChangeAmount     float64
}

func (f *PrintFormatter) FormatReceipt(data ReceiptData) string {
    var sb strings.Builder
    
    // Use outlet config for header
    sb.WriteString(ALIGN_CENTER + BOLD_ON + DOUBLE_HW)
    sb.WriteString(data.OutletName + "\n")
    sb.WriteString(NORMAL + BOLD_OFF)
    sb.WriteString(data.Address + "\n")
    sb.WriteString(data.Phone + "\n")
    if data.Instagram != "" {
        sb.WriteString(data.Instagram + "\n")
    }
    
    // ... format items ...
    
    // Use outlet config for footer
    sb.WriteString(ALIGN_CENTER)
    lines := strings.Split(data.ThankYouMessage, "\n")
    for _, line := range lines {
        sb.WriteString(line + "\n")
    }
    
    if data.Instagram != "" {
        sb.WriteString("\nIG: " + data.Instagram + "\n")
    }
    if data.Facebook != "" {
        sb.WriteString("FB: " + data.Facebook + "\n")
    }
    
    sb.WriteString("\n" + data.FooterNote + "\n")
    
    return sb.String()
}
```

### Print Formatter Service
```go
package services

import (
    "fmt"
    "strings"
    "time"
)

type PrintFormatter struct {
    paperSize string
    maxWidth  int
}

func NewPrintFormatter(paperSize string) *PrintFormatter {
    maxWidth := 48 // 80mm default
    if paperSize == "58mm" {
        maxWidth = 32
    }
    return &PrintFormatter{
        paperSize: paperSize,
        maxWidth:  maxWidth,
    }
}

func (f *PrintFormatter) FormatReceipt(order Order) string {
    var sb strings.Builder
    
    // Header
    sb.WriteString(ESC + "@") // Initialize
    sb.WriteString(ALIGN_CENTER)
    sb.WriteString(BOLD_ON)
    sb.WriteString(DOUBLE_HW)
    sb.WriteString("WARUNG NUSANTARA\n")
    sb.WriteString(NORMAL + BOLD_OFF)
    sb.WriteString("Jl. Merdeka No. 123\n")
    sb.WriteString("Telp: 0812-3456-7890\n")
    sb.WriteString(f.repeatChar("=", f.maxWidth) + "\n")
    
    // Order Info
    sb.WriteString(ALIGN_LEFT)
    sb.WriteString(time.Now().Format("02/01/2006 15:04") + "\n")
    sb.WriteString(fmt.Sprintf("Meja #%s - %s\n", order.TableNumber, order.CustomerName))
    sb.WriteString(f.repeatChar("-", f.maxWidth) + "\n")
    
    // Items
    for _, item := range order.Items {
        itemLine := f.formatItem(item.Name, item.Qty, item.Price)
        sb.WriteString(itemLine + "\n")
    }
    
    // Total
    sb.WriteString(f.repeatChar("=", f.maxWidth) + "\n")
    sb.WriteString(BOLD_ON)
    totalLine := f.formatTotal("TOTAL", order.TotalAmount)
    sb.WriteString(totalLine + "\n")
    sb.WriteString(BOLD_OFF)
    
    // Footer
    sb.WriteString(f.repeatChar("=", f.maxWidth) + "\n")
    sb.WriteString(ALIGN_CENTER)
    sb.WriteString("Terima Kasih\n")
    sb.WriteString("Selamat Menikmati!\n")
    sb.WriteString(f.repeatChar("=", f.maxWidth) + "\n")
    
    // Cut paper
    sb.WriteString(LF + LF + LF)
    sb.WriteString(CUT_PARTIAL)
    
    return sb.String()
}

func (f *PrintFormatter) formatItem(name string, qty int, price float64) string {
    if f.paperSize == "58mm" {
        // 58mm: Single line format
        // "Item Name            2x  35.000"
        maxNameWidth := f.maxWidth - 12 // Reserve space for qty and price
        truncatedName := f.truncate(name, maxNameWidth)
        qtyStr := fmt.Sprintf("%dx", qty)
        priceStr := f.formatPrice(price)
        
        padding := f.maxWidth - len(truncatedName) - len(qtyStr) - len(priceStr)
        return fmt.Sprintf("%s%s%s%s", 
            truncatedName, 
            strings.Repeat(" ", padding-1),
            qtyStr,
            strings.Repeat(" ", 2),
            priceStr,
        )
    } else {
        // 80mm: Two line format
        line1 := name + "\n"
        qtyStr := fmt.Sprintf("%dx", qty)
        priceStr := f.formatPrice(price)
        padding := f.maxWidth - len(qtyStr) - len(priceStr) - 1
        line2 := strings.Repeat(" ", padding) + qtyStr + " " + priceStr
        return line1 + line2
    }
}

func (f *PrintFormatter) formatTotal(label string, amount float64) string {
    priceStr := "Rp " + f.formatPrice(amount)
    padding := f.maxWidth - len(label) - len(priceStr)
    return label + strings.Repeat(" ", padding) + priceStr
}

func (f *PrintFormatter) formatPrice(price float64) string {
    // Format: 35.000 (no Rp prefix in item lines)
    return fmt.Sprintf("%.0f", price)
}

func (f *PrintFormatter) repeatChar(char string, count int) string {
    return strings.Repeat(char, count)
}

func (f *PrintFormatter) truncate(text string, maxLen int) string {
    if len(text) <= maxLen {
        return text
    }
    return text[:maxLen-3] + "..."
}
```

### Print Worker
```go
package workers

import (
    "context"
    "net"
    "time"
    "log"
)

type PrintWorker struct {
    db           *sql.DB
    pollInterval time.Duration
}

func NewPrintWorker(db *sql.DB) *PrintWorker {
    return &PrintWorker{
        db:           db,
        pollInterval: 5 * time.Second,
    }
}

func (w *PrintWorker) Start(ctx context.Context) {
    ticker := time.NewTicker(w.pollInterval)
    defer ticker.Stop()
    
    for {
        select {
        case <-ctx.Done():
            return
        case <-ticker.C:
            w.processPrintQueue()
        }
    }
}

func (w *PrintWorker) processPrintQueue() {
    // Get pending print jobs
    rows, err := w.db.Query(`
        SELECT id, printer_ip, content, retry_count 
        FROM print_queue 
        WHERE status = 'pending' AND retry_count < 3
        ORDER BY created_at ASC
        LIMIT 10
    `)
    if err != nil {
        log.Printf("Failed to fetch print queue: %v", err)
        return
    }
    defer rows.Close()
    
    for rows.Next() {
        var id, printerIP, content string
        var retryCount int
        
        if err := rows.Scan(&id, &printerIP, &content, &retryCount); err != nil {
            log.Printf("Failed to scan print job: %v", err)
            continue
        }
        
        if err := w.sendToPrinter(printerIP, content); err != nil {
            // Update retry count
            w.db.Exec(`
                UPDATE print_queue 
                SET retry_count = retry_count + 1, 
                    status = CASE WHEN retry_count + 1 >= 3 THEN 'failed' ELSE 'pending' END
                WHERE id = ?
            `, id)
            log.Printf("Print failed (retry %d/3): %v", retryCount+1, err)
        } else {
            // Mark as done
            w.db.Exec(`UPDATE print_queue SET status = 'done' WHERE id = ?`, id)
            log.Printf("Print job %s completed successfully", id)
        }
    }
}

func (w *PrintWorker) sendToPrinter(printerIP, content string) error {
    conn, err := net.DialTimeout("tcp", printerIP+":9100", 5*time.Second)
    if err != nil {
        return err
    }
    defer conn.Close()
    
    _, err = conn.Write([]byte(content))
    return err
}
```

## Routing Logic

### Category-Based Printer Selection
```go
func (s *OrderService) CreateOrder(order *Order) error {
    // 1. Save order to database
    if err := s.orderRepo.Create(order); err != nil {
        return err
    }
    
    // 2. Group items by category printer_type
    itemsByPrinter := make(map[string][]OrderItem)
    for _, item := range order.Items {
        category := s.categoryRepo.FindByProductID(item.ProductID)
        printerType := category.PrinterType // "kitchen", "bar", "cashier"
        itemsByPrinter[printerType] = append(itemsByPrinter[printerType], item)
    }
    
    // 3. Create print jobs for each printer type
    for printerType, items := range itemsByPrinter {
        printer := s.printerRepo.FindActiveByType(printerType)
        if printer == nil {
            log.Printf("No active printer found for type: %s", printerType)
            continue
        }
        
        // Format receipt content
        formatter := NewPrintFormatter(printer.PaperSize)
        content := formatter.FormatReceipt(order, items)
        
        // Add to print queue
        s.printQueueRepo.Create(&PrintJob{
            ID:        generateULID(),
            OrderID:   order.ID,
            PrinterIP: printer.IPAddress,
            Content:   content,
            Status:    "pending",
        })
    }
    
    return nil
}
```

## Testing

### Test Print Command
```bash
# Test direct print to thermal printer
echo -e "\x1b@\x1b\x61\x01WARUNG NUSANTARA\n\x1b\x61\x00Test Print\n\n\n\x1d\x56\x01" | nc 192.168.1.100 9100
```

## Next Steps

1. **Implement PrintFormatter Service** - Create Go service untuk format ESC/POS commands
2. **Create Print Worker** - Background worker untuk process print queue
3. **Add Print API Endpoint** - Manual print/reprint functionality
4. **Add Print Logging** - Track semua print activities
5. **Test dengan Physical Printer** - Test dengan printer thermal sesungguhnya

## References
- ESC/POS Command Reference: https://reference.epson-biz.com/modules/ref_escpos/
- Thermal Printer Guide: https://github.com/receipt-print-hq/escpos-tools
