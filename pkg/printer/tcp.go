package printer

import (
	"fmt"
	"net"
	"time"
)

// SendToPrinter sends ESC/POS data to thermal printer via TCP
func SendToPrinter(ipAddress string, port int, data []byte) error {
	// Build connection address
	address := net.JoinHostPort(ipAddress, fmt.Sprintf("%d", port))

	// Set connection timeout - optimized for faster printing
	conn, err := net.DialTimeout("tcp", address, 3*time.Second)
	if err != nil {
		return fmt.Errorf("failed to connect to printer at %s: %w", address, err)
	}
	defer conn.Close()

	// Set write deadline - faster timeout for quick response
	conn.SetWriteDeadline(time.Now().Add(5 * time.Second))

	// Send data to printer in one write operation
	_, err = conn.Write(data)
	if err != nil {
		return fmt.Errorf("failed to send data to printer: %w", err)
	}

	return nil
}

// TestPrinterConnection tests if printer is reachable
func TestPrinterConnection(ipAddress string, port int) error {
	address := net.JoinHostPort(ipAddress, fmt.Sprintf("%d", port))

	conn, err := net.DialTimeout("tcp", address, 3*time.Second)
	if err != nil {
		return fmt.Errorf("printer not reachable at %s: %w", address, err)
	}
	defer conn.Close()

	return nil
}
