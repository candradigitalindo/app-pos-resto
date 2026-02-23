#!/bin/bash

# Test Printer Optional Settings API
# This script tests the updated printer API with optional settings

API_URL="http://localhost:8080/api"

echo "==================================="
echo "Testing Printer Optional Settings"
echo "==================================="
echo ""

# Test 1: Create printer with Fast Kitchen preset
echo "Test 1: Creating printer with Fast Kitchen preset..."
curl -X POST "$API_URL/printers" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Kitchen Printer Fast",
    "ip_address": "192.168.1.201",
    "port": 9100,
    "printer_type": "kitchen",
    "paper_size": "80mm",
    "is_active": 1,
    "connection_timeout": 2,
    "write_timeout": 3,
    "retry_attempts": 1,
    "print_density": 40,
    "print_speed": "fast",
    "cut_mode": "partial",
    "enable_beep": 0,
    "auto_cut": 1,
    "charset": "latin"
  }' | jq .

echo ""
echo ""

# Test 2: Create printer with Quality Cashier preset
echo "Test 2: Creating printer with Quality Cashier preset..."
curl -X POST "$API_URL/printers" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Cashier Printer Quality",
    "ip_address": "192.168.1.202",
    "port": 9100,
    "printer_type": "cashier",
    "paper_size": "80mm",
    "is_active": 1,
    "connection_timeout": 3,
    "write_timeout": 5,
    "retry_attempts": 2,
    "print_density": 60,
    "print_speed": "normal",
    "cut_mode": "full",
    "enable_beep": 0,
    "auto_cut": 1,
    "charset": "utf8"
  }' | jq .

echo ""
echo ""

# Test 3: Create printer with Reliable Bar preset
echo "Test 3: Creating printer with Reliable Bar preset..."
curl -X POST "$API_URL/printers" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Bar Printer Reliable",
    "ip_address": "192.168.1.203",
    "port": 9100,
    "printer_type": "bar",
    "paper_size": "80mm",
    "is_active": 1,
    "connection_timeout": 4,
    "write_timeout": 6,
    "retry_attempts": 3,
    "print_density": 50,
    "print_speed": "normal",
    "cut_mode": "partial",
    "enable_beep": 1,
    "auto_cut": 1,
    "charset": "latin"
  }' | jq .

echo ""
echo ""

# Test 4: List all printers
echo "Test 4: Listing all printers..."
curl -X GET "$API_URL/printers" | jq .

echo ""
echo ""

# Test 5: Verify database content
echo "Test 5: Checking database for optional settings..."
cd /Users/candrasyahputra/PROJEK-APLIKASI/nusantara/Outlet/POS/backend
sqlite3 pos.db "SELECT id, name, connection_timeout, write_timeout, retry_attempts, print_density, print_speed, cut_mode FROM printers WHERE name LIKE '%Fast%' OR name LIKE '%Quality%' OR name LIKE '%Reliable%';"

echo ""
echo "==================================="
echo "Tests completed!"
echo "==================================="
