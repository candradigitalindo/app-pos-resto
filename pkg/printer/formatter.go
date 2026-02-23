package printer

import (
	"bytes"
	"fmt"
	"strings"
	"time"
)

// OutletConfig holds outlet information for receipts
type OutletConfig struct {
	Name        string
	Address     string
	Phone       string
	SocialMedia string
	Footer      string
}

// ReceiptData holds all data needed to generate a receipt
type ReceiptData struct {
	ReceiptNumber          string
	TableNumber            string
	CustomerName           string
	WaiterName             string
	CashierName            string
	Items                  []ReceiptItem
	Subtotal               int
	AdditionalChargesTotal int
	AdditionalCharges      []ReceiptCharge
	Tax                    int
	Total                  int
	PaymentMethod          string
	PaidAmount             int
	ChangeAmount           int
	DateTime               time.Time
}

type HandoverReceiptData struct {
	ReceiptNumber   string
	CashierFrom     string
	CashierTo       string
	OpeningCash     int
	ClosingCash     int
	ClosingCard     int
	ClosingQris     int
	ClosingTransfer int
	VoidedCount     int
	VoidedTotal     int
	CancelledCount  int
	CancelledTotal  int
	CashIns         []CashMovementData
	CashOuts        []CashMovementData
	DateTime        time.Time
}

type CloseShiftReceiptData struct {
	ReceiptNumber   string
	CashierName     string
	OpeningCash     int
	ClosingCash     int
	ClosingCard     int
	ClosingQris     int
	ClosingTransfer int
	VoidedCount     int
	VoidedTotal     int
	CancelledCount  int
	CancelledTotal  int
	CashIns         []CashMovementData
	CashOuts        []CashMovementData
	DateTime        time.Time
}

type CashInReceiptData struct {
	ReceiptNumber string
	CashierName   string
	Counterpart   string
	Amount        int
	DateTime      time.Time
}

type CashOutReceiptData struct {
	ReceiptNumber string
	CashierName   string
	Recipient     string
	Note          string
	Amount        int
	DateTime      time.Time
}

type CashMovementData struct {
	Name   string
	Amount int
}

// ReceiptItem represents a single item on the receipt
type ReceiptItem struct {
	Name     string
	Quantity int
	Price    int
	Total    int
}

type ReceiptCharge struct {
	Name   string
	Amount int
}

// PrintFormatter formats receipt data into ESC/POS commands
type PrintFormatter struct {
	outlet    OutletConfig
	paperSize string
	charLimit int
}

// NewPrintFormatter creates a new print formatter
func NewPrintFormatter(outlet OutletConfig, paperSize string) *PrintFormatter {
	return &PrintFormatter{
		outlet:    outlet,
		paperSize: paperSize,
		charLimit: GetCharLimit(paperSize),
	}
}

// FormatReceipt generates complete ESC/POS byte array for receipt
func (f *PrintFormatter) FormatReceipt(data ReceiptData) []byte {
	buf := bytes.NewBuffer(nil)

	// Initialize printer
	buf.Write(ESC_INIT)
	buf.Write(ESC_CHARSET_LATIN)

	// Header - Outlet Info (centered)
	f.writeHeader(buf)

	// Transaction Info (left aligned with colon separator)
	f.writeTransactionInfo(buf, data)

	// Items Table
	f.writeItems(buf, data.Items)

	// Summary
	f.writeSummary(buf, data)

	// Footer
	f.writeFooter(buf)

	// Cut paper - optimized with single newline
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_CUT_PARTIAL)

	return buf.Bytes()
}

func (f *PrintFormatter) FormatBill(data ReceiptData) []byte {
	buf := bytes.NewBuffer(nil)

	buf.Write(ESC_INIT)
	buf.Write(ESC_CHARSET_LATIN)

	f.writeBillHeader(buf)
	f.writeBillTransactionInfo(buf, data)
	f.writeItemsBill(buf, data.Items)
	f.writeBillSummary(buf, data)
	f.writeBillFooter(buf)

	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_CUT_PARTIAL)

	return buf.Bytes()
}

func (f *PrintFormatter) FormatSplitReceipt(data ReceiptData) []byte {
	buf := bytes.NewBuffer(nil)

	buf.Write(ESC_INIT)
	buf.Write(ESC_CHARSET_LATIN)

	f.writeHeader(buf)
	f.writeTransactionInfo(buf, data)
	f.writeItems(buf, data.Items)
	f.writeSummary(buf, data)
	f.writeFooter(buf)

	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_CUT_PARTIAL)

	return buf.Bytes()
}

func (f *PrintFormatter) FormatHandoverReceipt(data HandoverReceiptData) []byte {
	buf := bytes.NewBuffer(nil)

	buf.Write(ESC_INIT)
	buf.Write(ESC_CHARSET_LATIN)

	f.writeHeader(buf)

	buf.Write(ESC_ALIGN_CENTER)
	buf.Write(ESC_BOLD_ON)
	buf.WriteString("SERAH TERIMA SHIFT")
	buf.Write(ESC_BOLD_OFF)
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_ALIGN_LEFT)
	buf.WriteString(BuildDivider("-", f.paperSize))
	buf.Write(ESC_NEWLINE)

	buf.WriteString(FormatRow("No. Struk", data.ReceiptNumber, f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(FormatRow("Tanggal", data.DateTime.Format("02/01/2006 15:04"), f.charLimit))
	buf.Write(ESC_NEWLINE)
	if data.CashierFrom != "" {
		buf.WriteString(FormatRow("Kasir Lama", data.CashierFrom, f.charLimit))
		buf.Write(ESC_NEWLINE)
	}
	if data.CashierTo != "" {
		buf.WriteString(FormatRow("Kasir Baru", data.CashierTo, f.charLimit))
		buf.Write(ESC_NEWLINE)
	}

	buf.WriteString(BuildDivider("-", f.paperSize))
	buf.Write(ESC_NEWLINE)

	buf.WriteString(FormatRow("Modal Awal", FormatNumber(data.OpeningCash), f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(FormatRow("Tunai", FormatNumber(data.ClosingCash), f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(FormatRow("Kartu", FormatNumber(data.ClosingCard), f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(FormatRow("QRIS", FormatNumber(data.ClosingQris), f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(FormatRow("Transfer", FormatNumber(data.ClosingTransfer), f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(FormatRow(fmt.Sprintf("VOID (%d)", data.VoidedCount), FormatNumber(data.VoidedTotal), f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(FormatRow(fmt.Sprintf("Batal Transaksi (%d)", data.CancelledCount), FormatNumber(data.CancelledTotal), f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(BuildDivider("-", f.paperSize))
	buf.Write(ESC_NEWLINE)

	totalCashIn := 0
	for _, item := range data.CashIns {
		totalCashIn += item.Amount
	}
	totalCashOut := 0
	for _, item := range data.CashOuts {
		totalCashOut += item.Amount
	}

	if len(data.CashIns) > 0 {
		buf.WriteString("UANG MASUK")
		buf.Write(ESC_NEWLINE)
		for _, item := range data.CashIns {
			buf.WriteString(FormatRow(item.Name, FormatNumber(item.Amount), f.charLimit))
			buf.Write(ESC_NEWLINE)
		}
		buf.WriteString(FormatRow("Total Masuk", FormatNumber(totalCashIn), f.charLimit))
		buf.Write(ESC_NEWLINE)
	}
	if len(data.CashOuts) > 0 {
		if len(data.CashIns) > 0 {
			buf.Write(ESC_NEWLINE)
		}
		buf.WriteString("UANG KELUAR")
		buf.Write(ESC_NEWLINE)
		for _, item := range data.CashOuts {
			buf.WriteString(FormatRow(item.Name, FormatNumber(item.Amount), f.charLimit))
			buf.Write(ESC_NEWLINE)
		}
		buf.WriteString(FormatRow("Total Keluar", FormatNumber(totalCashOut), f.charLimit))
		buf.Write(ESC_NEWLINE)
	}
	if len(data.CashIns) > 0 || len(data.CashOuts) > 0 {
		buf.WriteString(BuildDivider("-", f.paperSize))
		buf.Write(ESC_NEWLINE)
	}

	totalSales := data.ClosingCash + data.ClosingCard + data.ClosingQris + data.ClosingTransfer
	grandTotal := data.OpeningCash + totalSales + totalCashIn - totalCashOut
	buf.WriteString(FormatRow("Total Penjualan", FormatNumber(totalSales), f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(FormatRow("Uang Masuk", FormatNumber(totalCashIn), f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(FormatRow("Uang Keluar", FormatNumber(totalCashOut), f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(BuildDivider("-", f.paperSize))
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_BOLD_ON)
	buf.WriteString(FormatRow("TOTAL", FormatNumber(grandTotal), f.charLimit))
	buf.Write(ESC_BOLD_OFF)
	buf.Write(ESC_NEWLINE)
	buf.WriteString(BuildDivider("=", f.paperSize))
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_NEWLINE)

	leftWidth := f.charLimit / 2
	rightWidth := f.charLimit - leftWidth
	buf.WriteString(PadRight("TTD Kasir Lama", leftWidth) + PadLeft("TTD Kasir Baru", rightWidth))
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_NEWLINE)
	buf.WriteString(PadRight(RepeatChar("_", leftWidth-2), leftWidth) + PadLeft(RepeatChar("_", rightWidth-2), rightWidth))
	buf.Write(ESC_NEWLINE)

	f.writeFooter(buf)

	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_CUT_PARTIAL)

	return buf.Bytes()
}

func (f *PrintFormatter) FormatCloseShiftReceipt(data CloseShiftReceiptData) []byte {
	buf := bytes.NewBuffer(nil)

	buf.Write(ESC_INIT)
	buf.Write(ESC_CHARSET_LATIN)

	f.writeHeader(buf)

	buf.Write(ESC_ALIGN_CENTER)
	buf.Write(ESC_BOLD_ON)
	buf.WriteString("TUTUP SHIFT")
	buf.Write(ESC_BOLD_OFF)
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_ALIGN_LEFT)
	buf.WriteString(BuildDivider("-", f.paperSize))
	buf.Write(ESC_NEWLINE)

	buf.WriteString(FormatRow("No. Struk", data.ReceiptNumber, f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(FormatRow("Tanggal", data.DateTime.Format("02/01/2006 15:04"), f.charLimit))
	buf.Write(ESC_NEWLINE)
	if data.CashierName != "" {
		buf.WriteString(FormatRow("Kasir", data.CashierName, f.charLimit))
		buf.Write(ESC_NEWLINE)
	}

	buf.WriteString(BuildDivider("-", f.paperSize))
	buf.Write(ESC_NEWLINE)

	buf.WriteString(FormatRow("Modal Awal", FormatNumber(data.OpeningCash), f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(FormatRow("Tunai", FormatNumber(data.ClosingCash), f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(FormatRow("Kartu", FormatNumber(data.ClosingCard), f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(FormatRow("QRIS", FormatNumber(data.ClosingQris), f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(FormatRow("Transfer", FormatNumber(data.ClosingTransfer), f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(FormatRow(fmt.Sprintf("VOID (%d)", data.VoidedCount), FormatNumber(data.VoidedTotal), f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(FormatRow(fmt.Sprintf("Batal Transaksi (%d)", data.CancelledCount), FormatNumber(data.CancelledTotal), f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(BuildDivider("-", f.paperSize))
	buf.Write(ESC_NEWLINE)

	totalCashIn := 0
	for _, item := range data.CashIns {
		totalCashIn += item.Amount
	}
	totalCashOut := 0
	for _, item := range data.CashOuts {
		totalCashOut += item.Amount
	}

	if len(data.CashIns) > 0 {
		buf.WriteString("UANG MASUK")
		buf.Write(ESC_NEWLINE)
		for _, item := range data.CashIns {
			buf.WriteString(FormatRow(item.Name, FormatNumber(item.Amount), f.charLimit))
			buf.Write(ESC_NEWLINE)
		}
		buf.WriteString(FormatRow("Total Masuk", FormatNumber(totalCashIn), f.charLimit))
		buf.Write(ESC_NEWLINE)
	}
	if len(data.CashOuts) > 0 {
		if len(data.CashIns) > 0 {
			buf.Write(ESC_NEWLINE)
		}
		buf.WriteString("UANG KELUAR")
		buf.Write(ESC_NEWLINE)
		for _, item := range data.CashOuts {
			buf.WriteString(FormatRow(item.Name, FormatNumber(item.Amount), f.charLimit))
			buf.Write(ESC_NEWLINE)
		}
		buf.WriteString(FormatRow("Total Keluar", FormatNumber(totalCashOut), f.charLimit))
		buf.Write(ESC_NEWLINE)
	}
	if len(data.CashIns) > 0 || len(data.CashOuts) > 0 {
		buf.WriteString(BuildDivider("-", f.paperSize))
		buf.Write(ESC_NEWLINE)
	}

	totalSales := data.ClosingCash + data.ClosingCard + data.ClosingQris + data.ClosingTransfer
	grandTotal := data.OpeningCash + totalSales + totalCashIn - totalCashOut
	buf.WriteString(FormatRow("Total Penjualan", FormatNumber(totalSales), f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(FormatRow("Uang Masuk", FormatNumber(totalCashIn), f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(FormatRow("Uang Keluar", FormatNumber(totalCashOut), f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(BuildDivider("-", f.paperSize))
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_BOLD_ON)
	buf.WriteString(FormatRow("TOTAL", FormatNumber(grandTotal), f.charLimit))
	buf.Write(ESC_BOLD_OFF)
	buf.Write(ESC_NEWLINE)
	buf.WriteString(BuildDivider("=", f.paperSize))
	buf.Write(ESC_NEWLINE)

	f.writeFooter(buf)

	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_CUT_PARTIAL)

	return buf.Bytes()
}

func (f *PrintFormatter) FormatCashInReceipt(data CashInReceiptData) []byte {
	buf := bytes.NewBuffer(nil)

	buf.Write(ESC_INIT)
	buf.Write(ESC_CHARSET_LATIN)

	f.writeHeader(buf)

	buf.Write(ESC_ALIGN_CENTER)
	buf.Write(ESC_BOLD_ON)
	buf.WriteString("KWITANSI PENERIMAAN")
	buf.Write(ESC_BOLD_OFF)
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_ALIGN_LEFT)
	buf.WriteString(BuildDivider("-", f.paperSize))
	buf.Write(ESC_NEWLINE)

	buf.WriteString(FormatRow("No. Struk", data.ReceiptNumber, f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(FormatRow("Tanggal", data.DateTime.Format("02/01/2006 15:04"), f.charLimit))
	buf.Write(ESC_NEWLINE)
	if data.CashierName != "" {
		buf.WriteString(FormatRow("Kasir", data.CashierName, f.charLimit))
		buf.Write(ESC_NEWLINE)
	}
	if data.Counterpart != "" {
		buf.WriteString(FormatRow("Diterima Dari", data.Counterpart, f.charLimit))
		buf.Write(ESC_NEWLINE)
	}

	buf.WriteString(BuildDivider("-", f.paperSize))
	buf.Write(ESC_NEWLINE)

	buf.WriteString(FormatRow("Nominal", FormatNumber(data.Amount), f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(BuildDivider("=", f.paperSize))
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_NEWLINE)

	leftWidth := f.charLimit / 2
	rightWidth := f.charLimit - leftWidth
	buf.WriteString(PadRight("TTD Kasir", leftWidth) + PadLeft("Pemberi", rightWidth))
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_NEWLINE)
	buf.WriteString(PadRight(RepeatChar("_", leftWidth-2), leftWidth) + PadLeft(RepeatChar("_", rightWidth-2), rightWidth))
	buf.Write(ESC_NEWLINE)

	f.writeFooter(buf)

	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_CUT_PARTIAL)

	return buf.Bytes()
}

func (f *PrintFormatter) FormatCashOutReceipt(data CashOutReceiptData) []byte {
	buf := bytes.NewBuffer(nil)

	buf.Write(ESC_INIT)
	buf.Write(ESC_CHARSET_LATIN)

	f.writeHeader(buf)

	buf.Write(ESC_ALIGN_CENTER)
	buf.Write(ESC_BOLD_ON)
	buf.WriteString("KWITANSI PENGELUARAN")
	buf.Write(ESC_BOLD_OFF)
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_ALIGN_LEFT)
	buf.WriteString(BuildDivider("-", f.paperSize))
	buf.Write(ESC_NEWLINE)

	buf.WriteString(FormatRow("No. Struk", data.ReceiptNumber, f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(FormatRow("Tanggal", data.DateTime.Format("02/01/2006 15:04"), f.charLimit))
	buf.Write(ESC_NEWLINE)
	if data.CashierName != "" {
		buf.WriteString(FormatRow("Kasir", data.CashierName, f.charLimit))
		buf.Write(ESC_NEWLINE)
	}
	if data.Recipient != "" {
		buf.WriteString(FormatRow("Penerima", data.Recipient, f.charLimit))
		buf.Write(ESC_NEWLINE)
	}
	if data.Note != "" {
		buf.WriteString(FormatRow("Keterangan", data.Note, f.charLimit))
		buf.Write(ESC_NEWLINE)
	}

	buf.WriteString(BuildDivider("-", f.paperSize))
	buf.Write(ESC_NEWLINE)

	buf.WriteString(FormatRow("Nominal", FormatNumber(data.Amount), f.charLimit))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(BuildDivider("=", f.paperSize))
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_NEWLINE)

	leftWidth := f.charLimit / 2
	rightWidth := f.charLimit - leftWidth
	buf.WriteString(PadRight("TTD Kasir", leftWidth) + PadLeft("Penerima", rightWidth))
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_NEWLINE)
	buf.WriteString(PadRight(RepeatChar("_", leftWidth-2), leftWidth) + PadLeft(RepeatChar("_", rightWidth-2), rightWidth))
	buf.Write(ESC_NEWLINE)

	f.writeFooter(buf)

	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_CUT_PARTIAL)

	return buf.Bytes()
}

// writeHeader writes outlet information header
func (f *PrintFormatter) writeHeader(buf *bytes.Buffer) {
	// Outlet name - bold, centered
	buf.Write(ESC_ALIGN_CENTER)
	buf.Write(ESC_BOLD_ON)
	buf.WriteString(f.outlet.Name)
	buf.Write(ESC_BOLD_OFF)
	buf.Write(ESC_NEWLINE)

	// Address - centered, normal
	buf.WriteString(f.outlet.Address)
	buf.Write(ESC_NEWLINE)

	// Phone - centered
	buf.WriteString("Telp: " + f.outlet.Phone)
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_ALIGN_LEFT)
	buf.WriteString(BuildDivider("-", f.paperSize))
	buf.Write(ESC_NEWLINE)
}

func (f *PrintFormatter) writeBillHeader(buf *bytes.Buffer) {
	buf.Write(ESC_ALIGN_CENTER)
	buf.Write(ESC_BOLD_ON)
	buf.WriteString("BILL")
	buf.Write(ESC_BOLD_OFF)
	buf.Write(ESC_NEWLINE)

	buf.Write(ESC_BOLD_ON)
	buf.WriteString(f.outlet.Name)
	buf.Write(ESC_BOLD_OFF)
	buf.Write(ESC_NEWLINE)

	buf.WriteString(f.outlet.Address)
	buf.Write(ESC_NEWLINE)

	buf.WriteString("Telp: " + f.outlet.Phone)
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_ALIGN_LEFT)
	buf.WriteString(BuildDivider("-", f.paperSize))
	buf.Write(ESC_NEWLINE)
}

// writeTransactionInfo writes transaction details
func (f *PrintFormatter) writeTransactionInfo(buf *bytes.Buffer, data ReceiptData) {
	labelWidth := 11
	formatLine := func(label, value string) string {
		prefix := PadRight(label, labelWidth) + " : "
		available := f.charLimit - len(prefix)
		if available < 1 {
			available = 1
		}
		if len(value) > available {
			value = value[:available]
		}
		return prefix + value
	}

	buf.WriteString(formatLine("No. Struk", data.ReceiptNumber))
	buf.Write(ESC_NEWLINE)

	dateStr := data.DateTime.Format("02/01/2006 15:04")
	buf.WriteString(formatLine("Tanggal", dateStr))
	buf.Write(ESC_NEWLINE)

	buf.WriteString(formatLine("Meja", data.TableNumber))
	buf.Write(ESC_NEWLINE)

	if data.CustomerName != "" {
		buf.WriteString(formatLine("Customer", data.CustomerName))
		buf.Write(ESC_NEWLINE)
	}

	if data.WaiterName != "" {
		buf.WriteString(formatLine("Waiter", data.WaiterName))
		buf.Write(ESC_NEWLINE)
	}

	if data.CashierName != "" {
		buf.WriteString(formatLine("Kasir", data.CashierName))
		buf.Write(ESC_NEWLINE)
	}

	buf.Write(ESC_NEWLINE)
	buf.WriteString(BuildDivider("-", f.paperSize))
	buf.Write(ESC_NEWLINE)
}

func (f *PrintFormatter) writeBillTransactionInfo(buf *bytes.Buffer, data ReceiptData) {
	labelWidth := 11
	formatLine := func(label, value string) string {
		prefix := PadRight(label, labelWidth) + " : "
		available := f.charLimit - len(prefix)
		if available < 1 {
			available = 1
		}
		if len(value) > available {
			value = value[:available]
		}
		return prefix + value
	}

	buf.WriteString(formatLine("No. Bill", data.ReceiptNumber))
	buf.Write(ESC_NEWLINE)

	dateStr := data.DateTime.Format("02/01/2006 15:04")
	buf.WriteString(formatLine("Tanggal", dateStr))
	buf.Write(ESC_NEWLINE)

	buf.WriteString(formatLine("Meja", data.TableNumber))
	buf.Write(ESC_NEWLINE)

	if data.WaiterName != "" {
		buf.WriteString(formatLine("Waiter", data.WaiterName))
		buf.Write(ESC_NEWLINE)
	}

	customerName := data.CustomerName
	if customerName == "" {
		customerName = "-"
	}
	buf.WriteString(formatLine("Customer", customerName))
	buf.Write(ESC_NEWLINE)

	buf.Write(ESC_NEWLINE)
	buf.WriteString(BuildDivider("-", f.paperSize))
	buf.Write(ESC_NEWLINE)
}

// writeItems writes items table
func (f *PrintFormatter) writeItems(buf *bytes.Buffer, items []ReceiptItem) {
	// Table header positions
	nameWidth, qtyWidth, priceWidth, totalWidth := GetItemColumnWidths(f.charLimit)
	headerLine := PadRight("ITEM", nameWidth)
	headerLine += PadLeft("QTY", qtyWidth)
	headerLine += PadLeft("HARGA", priceWidth)
	headerLine += PadLeft("TOTAL", totalWidth)

	buf.Write(ESC_BOLD_ON)
	buf.WriteString(headerLine)
	buf.Write(ESC_BOLD_OFF)
	buf.Write(ESC_NEWLINE)

	// Divider
	buf.WriteString(BuildDivider("-", f.paperSize))
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_NEWLINE)

	// Items
	for _, item := range items {
		row := FormatItemRow(item.Name, item.Quantity, item.Price, item.Total, f.charLimit)
		buf.WriteString(row)
		buf.Write(ESC_NEWLINE)
	}

	buf.Write(ESC_NEWLINE)
	buf.WriteString(BuildDivider("=", f.paperSize))
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_NEWLINE)
}

func (f *PrintFormatter) writeItemsBill(buf *bytes.Buffer, items []ReceiptItem) {
	nameWidth, qtyWidth, priceWidth, totalWidth := GetItemColumnWidths(f.charLimit)
	headerLine := PadRight("ITEM", nameWidth)
	headerLine += PadLeft("QTY", qtyWidth)
	headerLine += PadLeft("HARGA", priceWidth)
	headerLine += PadLeft("TOTAL", totalWidth)

	buf.Write(ESC_BOLD_ON)
	buf.WriteString(headerLine)
	buf.Write(ESC_BOLD_OFF)
	buf.Write(ESC_NEWLINE)

	buf.WriteString(BuildDivider("-", f.paperSize))
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_NEWLINE)

	for _, item := range items {
		row := FormatItemRowBill(item.Name, item.Quantity, item.Price, item.Total, f.charLimit)
		buf.WriteString(row)
		buf.Write(ESC_NEWLINE)
	}

	buf.Write(ESC_NEWLINE)
	buf.WriteString(BuildDivider("=", f.paperSize))
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_NEWLINE)
}

// writeSummary writes payment summary
func (f *PrintFormatter) writeSummary(buf *bytes.Buffer, data ReceiptData) {
	// Subtotal
	subtotalStr := FormatNumber(data.Subtotal)
	buf.WriteString(FormatRow("Subtotal", subtotalStr, f.charLimit))
	buf.Write(ESC_NEWLINE)

	for _, charge := range data.AdditionalCharges {
		if charge.Amount == 0 {
			continue
		}
		chargeStr := FormatNumber(charge.Amount)
		buf.WriteString(FormatRow(charge.Name, chargeStr, f.charLimit))
		buf.Write(ESC_NEWLINE)
	}

	// Tax (jika ada)
	if data.Tax > 0 {
		taxStr := FormatNumber(data.Tax)
		buf.WriteString(FormatRow("Pajak", taxStr, f.charLimit))
		buf.Write(ESC_NEWLINE)
	}

	// Divider
	buf.WriteString(BuildDivider("-", f.paperSize))
	buf.Write(ESC_NEWLINE)

	// Total - bold
	buf.Write(ESC_BOLD_ON)
	totalStr := FormatNumber(data.Total)
	buf.WriteString(FormatRow("TOTAL", totalStr, f.charLimit))
	buf.Write(ESC_BOLD_OFF)
	buf.Write(ESC_NEWLINE)

	// Divider
	buf.WriteString(BuildDivider("=", f.paperSize))
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_NEWLINE)

	// Payment details
	paidStr := FormatNumber(data.PaidAmount)
	buf.WriteString(FormatRow("Bayar", paidStr, f.charLimit))
	buf.Write(ESC_NEWLINE)

	changeStr := FormatNumber(data.ChangeAmount)
	buf.WriteString(FormatRow("Kembalian", changeStr, f.charLimit))
	buf.Write(ESC_NEWLINE)

	buf.Write(ESC_NEWLINE)
	buf.WriteString(BuildDivider("=", f.paperSize))
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_NEWLINE)
}

func (f *PrintFormatter) writeBillSummary(buf *bytes.Buffer, data ReceiptData) {
	subtotalStr := FormatNumber(data.Subtotal)
	buf.WriteString(FormatRow("Subtotal", subtotalStr, f.charLimit))
	buf.Write(ESC_NEWLINE)

	for _, charge := range data.AdditionalCharges {
		if charge.Amount == 0 {
			continue
		}
		chargeStr := FormatNumber(charge.Amount)
		buf.WriteString(FormatRow(charge.Name, chargeStr, f.charLimit))
		buf.Write(ESC_NEWLINE)
	}

	if data.Tax > 0 {
		taxStr := FormatNumber(data.Tax)
		buf.WriteString(FormatRow("Pajak", taxStr, f.charLimit))
		buf.Write(ESC_NEWLINE)
	}

	buf.WriteString(BuildDivider("-", f.paperSize))
	buf.Write(ESC_NEWLINE)

	buf.Write(ESC_BOLD_ON)
	totalStr := FormatNumber(data.Total)
	buf.WriteString(FormatRow("TOTAL", totalStr, f.charLimit))
	buf.Write(ESC_BOLD_OFF)
	buf.Write(ESC_NEWLINE)

	buf.WriteString(BuildDivider("=", f.paperSize))
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_NEWLINE)
}

// writeFooter writes receipt footer
func (f *PrintFormatter) writeFooter(buf *bytes.Buffer) {
	hasFooter := f.outlet.Footer != ""
	hasSocial := f.outlet.SocialMedia != ""
	writeWrapped := func(text string) int {
		lines := wrapText(text, f.charLimit)
		if len(lines) == 0 {
			return 0
		}
		for _, line := range lines {
			buf.WriteString(line)
			buf.Write(ESC_NEWLINE)
		}
		return len(lines)
	}
	if hasFooter || hasSocial {
		buf.Write(ESC_ALIGN_CENTER)
		buf.Write(ESC_BOLD_ON)
		buf.WriteString("*** Terima Kasih ***")
		buf.Write(ESC_BOLD_OFF)
		buf.Write(ESC_NEWLINE)
		buf.Write(ESC_NEWLINE)
	}

	// Footer/Salam penutup dari config
	totalLines := 0
	if hasFooter {
		totalLines += writeWrapped(f.outlet.Footer)
	}

	// Social media
	if hasSocial {
		if hasFooter {
			buf.Write(ESC_NEWLINE)
		}
		totalLines += writeWrapped(f.outlet.SocialMedia)
	}
	if totalLines > 0 {
		feedLines := 3
		if totalLines > feedLines {
			feedLines = totalLines
		}
		for i := 0; i < feedLines; i++ {
			buf.Write(ESC_NEWLINE)
		}
	}
	buf.Write(ESC_ALIGN_LEFT)
}

func (f *PrintFormatter) writeBillFooter(buf *bytes.Buffer) {
	hasFooter := f.outlet.Footer != ""
	hasSocial := f.outlet.SocialMedia != ""
	writeWrapped := func(text string) int {
		lines := wrapText(text, f.charLimit)
		if len(lines) == 0 {
			return 0
		}
		for _, line := range lines {
			buf.WriteString(line)
			buf.Write(ESC_NEWLINE)
		}
		return len(lines)
	}
	if hasFooter || hasSocial {
		buf.Write(ESC_ALIGN_CENTER)
		buf.Write(ESC_BOLD_ON)
		buf.WriteString("*** Terima Kasih ***")
		buf.Write(ESC_BOLD_OFF)
		buf.Write(ESC_NEWLINE)
		buf.Write(ESC_NEWLINE)
	}

	totalLines := 0
	if hasFooter {
		totalLines += writeWrapped(f.outlet.Footer)
	}

	if hasSocial {
		if hasFooter {
			buf.Write(ESC_NEWLINE)
		}
		totalLines += writeWrapped(f.outlet.SocialMedia)
	}
	if totalLines > 0 {
		feedLines := 3
		if totalLines > feedLines {
			feedLines = totalLines
		}
		for i := 0; i < feedLines; i++ {
			buf.Write(ESC_NEWLINE)
		}
	}
	buf.Write(ESC_ALIGN_LEFT)
}

func (f *PrintFormatter) writeSplitFooter(buf *bytes.Buffer) {
	buf.Write(ESC_ALIGN_LEFT)
}

// FormatKitchenOrder formats order for kitchen printer (simple format)
func (f *PrintFormatter) FormatKitchenOrder(headerTitle, orderNumber, tableName, waiterName string, items []ReceiptItem, timestamp time.Time) []byte {
	buf := bytes.NewBuffer(nil)

	buf.Write(ESC_INIT)
	buf.Write(ESC_CHARSET_LATIN)

	// Header
	buf.Write(ESC_ALIGN_CENTER)
	buf.Write(ESC_SIZE_DOUBLE)
	buf.Write(ESC_BOLD_ON)
	buf.WriteString(headerTitle)
	buf.Write(ESC_BOLD_OFF)
	buf.Write(ESC_SIZE_NORMAL)
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_NEWLINE)

	buf.Write(ESC_ALIGN_LEFT)
	buf.WriteString(BuildDivider("=", f.paperSize))
	buf.Write(ESC_NEWLINE)

	// Order info
	labelWidth := 7
	formatLine := func(label, value string) string {
		prefix := PadRight(label, labelWidth) + " : "
		available := f.charLimit - len(prefix)
		if available < 1 {
			available = 1
		}
		if len(value) > available {
			value = value[:available]
		}
		return prefix + value
	}

	buf.WriteString(formatLine("Order", orderNumber))
	buf.Write(ESC_NEWLINE)
	buf.WriteString(formatLine("Meja", tableName))
	buf.Write(ESC_NEWLINE)
	if waiterName != "" {
		buf.WriteString(formatLine("Waiter", waiterName))
		buf.Write(ESC_NEWLINE)
	}
	buf.WriteString(formatLine("Waktu", timestamp.Format("15:04")))
	buf.Write(ESC_NEWLINE)

	buf.WriteString(BuildDivider("-", f.paperSize))
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_NEWLINE)

	// Items
	buf.Write(ESC_SIZE_NORMAL)
	for _, item := range items {
		prefix := fmt.Sprintf("%d x ", item.Quantity)
		availableWidth := f.charLimit - len(prefix)
		if availableWidth < 1 {
			availableWidth = 1
		}
		lines := wrapText(item.Name, availableWidth)
		if len(lines) == 0 {
			lines = []string{""}
		}
		for i, line := range lines {
			if i == 0 {
				buf.Write(ESC_BOLD_ON)
				buf.WriteString(prefix)
				buf.Write(ESC_BOLD_OFF)
				buf.WriteString(line)
				buf.Write(ESC_NEWLINE)
				continue
			}
			buf.WriteString(strings.Repeat(" ", len(prefix)))
			buf.WriteString(line)
			buf.Write(ESC_NEWLINE)
		}
	}

	buf.Write(ESC_NEWLINE)
	buf.WriteString(BuildDivider("=", f.paperSize))
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_NEWLINE)

	// Cut
	buf.Write(ESC_CUT_PARTIAL)

	return buf.Bytes()
}

func wrapText(text string, width int) []string {
	if width <= 0 {
		return []string{text}
	}
	words := strings.Fields(text)
	if len(words) == 0 {
		return []string{}
	}
	lines := []string{}
	current := ""
	for _, word := range words {
		if len(word) > width {
			if current != "" {
				lines = append(lines, current)
				current = ""
			}
			for len(word) > width {
				lines = append(lines, word[:width])
				word = word[width:]
			}
			if word != "" {
				current = word
			}
			continue
		}
		if current == "" {
			current = word
			continue
		}
		if len(current)+1+len(word) <= width {
			current += " " + word
			continue
		}
		lines = append(lines, current)
		current = word
	}
	if current != "" {
		lines = append(lines, current)
	}
	return lines
}

// FormatTestPrint generates minimal test print
func (f *PrintFormatter) FormatTestPrint(printerName, ipPort string) []byte {
	buf := bytes.NewBuffer(nil)

	// Initialize printer
	buf.Write(ESC_INIT)
	buf.Write(ESC_CHARSET_LATIN)

	// Center align
	buf.Write(ESC_ALIGN_CENTER)
	buf.Write(ESC_BOLD_ON)
	buf.WriteString("TEST OK")
	buf.Write(ESC_BOLD_OFF)
	buf.Write(ESC_NEWLINE)

	buf.WriteString(printerName)
	buf.Write(ESC_NEWLINE)

	buf.WriteString(ipPort)
	buf.Write(ESC_NEWLINE)
	buf.Write(ESC_NEWLINE)

	// Cut paper
	buf.Write(ESC_CUT_PARTIAL)

	return buf.Bytes()
}
