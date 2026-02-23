package printer

import (
	"fmt"
	"strconv"
)

// ESC/POS Commands - Standard thermal printer control codes
var (
	// Initialize printer
	ESC_INIT = []byte{0x1B, 0x40}

	// Text alignment
	ESC_ALIGN_LEFT   = []byte{0x1B, 0x61, 0x00}
	ESC_ALIGN_CENTER = []byte{0x1B, 0x61, 0x01}

	// Text size (width x height multipliers)
	ESC_SIZE_NORMAL = []byte{0x1D, 0x21, 0x00} // 1x1
	ESC_SIZE_DOUBLE = []byte{0x1D, 0x21, 0x11} // 2x2

	// Text emphasis
	ESC_BOLD_ON  = []byte{0x1B, 0x45, 0x01}
	ESC_BOLD_OFF = []byte{0x1B, 0x45, 0x00}

	// Line feed
	ESC_NEWLINE = []byte{0x0A}

	// Cut paper
	ESC_CUT_PARTIAL = []byte{0x1D, 0x56, 0x01}

	// Character code table (Indonesia/Latin)
	ESC_CHARSET_LATIN = []byte{0x1B, 0x74, 0x00}
)

// Paper size constants
const (
	PaperSize58mm = "58mm"
	PaperSize80mm = "80mm"
)

// Character width limits per paper size
const (
	CharsPerLine58mm = 32
	CharsPerLine80mm = 48
)

// Helper functions to build ESC/POS commands

// RepeatChar repeats a character n times
func RepeatChar(char string, count int) string {
	result := ""
	for i := 0; i < count; i++ {
		result += char
	}
	return result
}

// PadRight pads string to the right
func PadRight(text string, width int) string {
	if len(text) >= width {
		return text[:width]
	}
	return text + RepeatChar(" ", width-len(text))
}

// PadLeft pads string to the left
func PadLeft(text string, width int) string {
	if len(text) >= width {
		return text[:width]
	}
	return RepeatChar(" ", width-len(text)) + text
}

// FormatRow formats a two-column row (label: value)
func FormatRow(label, value string, width int) string {
	// Calculate spacing needed
	contentLen := len(label) + len(value)
	if contentLen >= width {
		return label + value[:width-len(label)]
	}
	spaces := width - contentLen
	return label + RepeatChar(" ", spaces) + value
}

func GetItemColumnWidths(width int) (int, int, int, int) {
	qtyPos := int(float64(width) * 0.60)
	pricePos := int(float64(width) * 0.70)
	totalPos := int(float64(width) * 0.85)
	nameWidth := qtyPos
	qtyWidth := pricePos - qtyPos
	priceWidth := totalPos - pricePos
	totalWidth := width - totalPos
	if totalWidth < 1 {
		totalWidth = 1
		nameWidth = width - qtyWidth - priceWidth - totalWidth
	}
	return nameWidth, qtyWidth, priceWidth, totalWidth
}

// FormatItemRow formats item table row (name, qty, price, total)
func FormatItemRow(name string, qty, price, total int, width int) string {
	nameWidth, qtyWidth, priceWidth, totalWidth := GetItemColumnWidths(width)

	// Truncate name if too long
	if len(name) > nameWidth {
		name = name[:nameWidth-2] + ".."
	}

	// Format numbers
	qtyStr := fmt.Sprintf("%dx", qty)
	priceStr := FormatNumber(price)
	totalStr := FormatNumber(total)

	// Build row
	row := PadRight(name, nameWidth)
	row += PadLeft(qtyStr, qtyWidth)
	row += PadLeft(priceStr, priceWidth)
	row += PadLeft(totalStr, totalWidth)

	return row
}

func FormatItemRowBill(name string, qty, price, total int, width int) string {
	nameWidth, qtyWidth, priceWidth, totalWidth := GetItemColumnWidths(width)

	if len(name) > nameWidth {
		name = name[:nameWidth-2] + ".."
	}

	qtyStr := fmt.Sprintf("%dx", qty)
	priceStr := FormatNumber(price)
	totalStr := FormatNumber(total)

	row := PadRight(name, nameWidth)
	row += PadLeft(qtyStr, qtyWidth)
	row += PadLeft(priceStr, priceWidth)
	row += PadLeft(totalStr, totalWidth)

	return row
}

// FormatNumber formats number with thousand separator
func FormatNumber(n int) string {
	s := ""
	num := n
	if num < 0 {
		num = -num
	}

	// Convert to string with separators
	str := ""
	count := 0
	for num > 0 {
		if count > 0 && count%3 == 0 {
			str = "." + str
		}
		str = strconv.Itoa(num%10) + str
		num /= 10
		count++
	}

	if str == "" {
		str = "0"
	}

	if n < 0 {
		s = "-" + str
	} else {
		s = str
	}

	return s
}

// GetCharLimit returns character limit based on paper size
func GetCharLimit(paperSize string) int {
	if paperSize == PaperSize58mm {
		return CharsPerLine58mm
	}
	return CharsPerLine80mm
}

// BuildDivider creates a divider line
func BuildDivider(char string, paperSize string) string {
	width := GetCharLimit(paperSize)
	return RepeatChar(char, width)
}
