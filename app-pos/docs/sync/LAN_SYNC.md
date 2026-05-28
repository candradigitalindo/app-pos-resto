# 🌐 LAN Sync - Device Pairing via QR Code

Sistem untuk menghubungkan perangkat kasir dan waiter ke server POS melalui jaringan lokal (LAN) menggunakan QR code.

## 🎯 Overview

Fitur ini memungkinkan perangkat mobile (tablet, smartphone) atau desktop untuk terhubung ke server POS secara otomatis dengan scan QR code. Setelah terhubung, perangkat akan mendapatkan akses token dan dapat melakukan sinkronisasi data real-time.

## 🔑 Konsep

1. **Admin** membuka halaman QR code di server
2. **QR code** berisi informasi server (IP, port, pairing token)
3. **Perangkat** scan QR code
4. **Perangkat** register otomatis ke server
5. **Server** berikan access token (JWT)
6. **Perangkat** gunakan token untuk API requests
7. **Heartbeat** periodik untuk maintain connection

## 📋 Flow Diagram

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│   Admin     │         │   Server    │         │   Device    │
│  (Browser)  │         │    (POS)    │         │ (Kasir/     │
│             │         │             │         │  Waiter)    │
└──────┬──────┘         └──────┬──────┘         └──────┬──────┘
       │                       │                       │
       │  1. Generate QR       │                       │
       ├──────────────────────>│                       │
       │                       │                       │
       │  2. QR Code (base64)  │                       │
       │<──────────────────────┤                       │
       │                       │                       │
       │  3. Scan QR           │                       │
       │                       │<──────────────────────┤
       │                       │                       │
       │                       │  4. Register Device   │
       │                       │<──────────────────────┤
       │                       │     (pairing token)   │
       │                       │                       │
       │                       │  5. JWT Token         │
       │                       ├──────────────────────>│
       │                       │                       │
       │                       │  6. Heartbeat         │
       │                       │<──────────────────────┤
       │                       │     (periodic)        │
       │                       │                       │
```

## 🚀 API Endpoints

### 1. Generate QR Code (Admin)

**Endpoint**: `GET /api/v1/devices/qr`

**Auth**: Admin only (JWT required)

**Query Params**:
- `outlet_code` (optional) - Kode outlet, default: "OUTLET-01"

**Response**:
```json
{
  "success": true,
  "data": {
    "qr_code": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...",
    "server_ip": "192.168.1.100",
    "server_port": "8080",
    "pairing_url": "http://192.168.1.100:8080/api/v1/devices/register",
    "expires_at": "2026-01-27T15:30:00Z",
    "expires_in": 300,
    "outlet_code": "OUTLET-01",
    "instructions": "Scan QR code dengan aplikasi kasir/waiter untuk terhubung ke server"
  }
}
```

**QR Code Content** (JSON):
```json
{
  "server_ip": "192.168.1.100",
  "server_port": "8080",
  "pairing_token": "xYz123AbC456...",
  "outlet_code": "OUTLET-01",
  "expires_at": 1706366400,
  "server_version": "1.0.0"
}
```

### 2. Register Device (Public)

**Endpoint**: `POST /api/v1/devices/register`

**Auth**: None (public endpoint)

**Request Body**:
```json
{
  "device_id": "550e8400-e29b-41d4-a716-446655440000",
  "device_name": "Kasir 1",
  "device_type": "cashier",
  "ip_address": "192.168.1.101",
  "mac_address": "00:1B:44:11:3A:B7",
  "pairing_token": "xYz123AbC456...",
  "app_version": "1.0.5",
  "platform": "android"
}
```

**Fields**:
- `device_id` (required) - UUID unik per device
- `device_name` (required) - Nama device (user-friendly)
- `device_type` (required) - `cashier`, `waiter`, `kitchen`, atau `bar`
- `ip_address` (required) - IP address device
- `mac_address` (optional) - MAC address untuk identifikasi
- `pairing_token` (required) - Token dari QR code
- `app_version` (optional) - Versi aplikasi client
- `platform` (optional) - `android`, `ios`, `windows`, `web`

**Response**:
```json
{
  "success": true,
  "message": "Device registered successfully",
  "data": {
    "device_id": "550e8400-e29b-41d4-a716-446655440000",
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "server_ip": "192.168.1.100",
    "server_port": "8080",
    "outlet_code": "OUTLET-01",
    "outlet_name": "Outlet Jakarta",
    "expires_in": 31536000,
    "registered_at": "2026-01-27T15:25:00Z"
  }
}
```

### 3. Device Heartbeat

**Endpoint**: `POST /api/v1/devices/heartbeat`

**Auth**: JWT token (device token)

**Request Body**:
```json
{
  "device_id": "550e8400-e29b-41d4-a716-446655440000",
  "ip_address": "192.168.1.101",
  "app_version": "1.0.5",
  "status": "active"
}
```

**Response**:
```json
{
  "success": true,
  "message": "Heartbeat received",
  "server_time": "2026-01-27T15:30:00Z"
}
```

### 4. Get Device Status (Admin)

**Endpoint**: `GET /api/v1/devices/status`

**Auth**: Admin only

**Response**:
```json
{
  "success": true,
  "data": {
    "server_ip": "192.168.1.100",
    "total_devices": 5,
    "active_devices": 4,
    "devices_by_type": {
      "cashier": 2,
      "waiter": 2,
      "kitchen": 1
    },
    "registered_today": 2,
    "last_activity": "2026-01-27T15:30:00Z",
    "registered_devices": [
      {
        "id": 1,
        "device_id": "550e8400-e29b-41d4-a716-446655440000",
        "device_name": "Kasir 1",
        "device_type": "cashier",
        "ip_address": "192.168.1.101",
        "is_active": true,
        "last_seen_at": "2026-01-27T15:30:00Z",
        "registered_at": "2026-01-27T10:00:00Z"
      }
    ]
  }
}
```

### 5. Get Device List (Admin)

**Endpoint**: `GET /api/v1/devices/list?filter=active`

**Auth**: Admin only

**Query Params**:
- `filter` - `all`, `active`, `cashier`, `waiter`, `kitchen`, `bar`

**Response**:
```json
{
  "success": true,
  "data": [...],
  "count": 5
}
```

### 6. Deactivate Device (Admin)

**Endpoint**: `PUT /api/v1/devices/:device_id/deactivate`

**Auth**: Admin only

### 7. Delete Device (Admin)

**Endpoint**: `DELETE /api/v1/devices/:device_id`

**Auth**: Admin only

## 💻 Client Implementation Guide

### Android/iOS (Scan QR)

```kotlin
// 1. Scan QR Code
val qrContent = scanQRCode() // Returns JSON string

// 2. Parse QR Content
val qrData = JSON.parse(qrContent)
val serverUrl = "http://${qrData.server_ip}:${qrData.server_port}"
val pairingToken = qrData.pairing_token

// 3. Register Device
val response = httpPost("${serverUrl}/api/v1/devices/register", {
    "device_id": UUID.randomUUID().toString(),
    "device_name": "Kasir 1",
    "device_type": "cashier",
    "ip_address": getDeviceIP(),
    "mac_address": getMacAddress(),
    "pairing_token": pairingToken,
    "app_version": "1.0.5",
    "platform": "android"
})

// 4. Save Token
val accessToken = response.data.access_token
saveToSecureStorage("access_token", accessToken)
saveToSecureStorage("server_url", serverUrl)

// 5. Setup Heartbeat (every 5 minutes)
setInterval({
    sendHeartbeat()
}, 5 * 60 * 1000)
```

### Web App (Manual Entry)

```javascript
// Option 1: Scan QR with webcam
const qrData = await scanQRWithWebcam();

// Option 2: Manual entry
const serverIP = document.getElementById('server-ip').value;
const pairingToken = document.getElementById('token').value;

// Register
const response = await fetch(`http://${serverIP}:8080/api/v1/devices/register`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    device_id: generateUUID(),
    device_name: 'Web Kasir 1',
    device_type: 'cashier',
    ip_address: await getClientIP(),
    pairing_token: pairingToken,
    app_version: '1.0.0',
    platform: 'web'
  })
});

const data = await response.json();
localStorage.setItem('access_token', data.data.access_token);
```

## 🔐 Security

### Pairing Token
- **One-time use** - Token dihapus setelah digunakan
- **Expires in 5 minutes** - Token expired otomatis
- **Cryptographically secure** - Generated dengan crypto/rand

### JWT Token
- **HS256 signing** - Secure HMAC signature
- **1 year validity** - Access token berlaku 1 tahun
- **2 years refresh token** - Untuk renew access token
- **Device bound** - Token include device_id

### Network
- **LAN only** - Sistem untuk jaringan lokal
- **Optional TLS** - Bisa enable HTTPS untuk production
- **MAC filtering** - Optional whitelist MAC address

## 📊 Database Schema

### registered_devices
```sql
CREATE TABLE registered_devices (
    id INTEGER PRIMARY KEY,
    device_id TEXT UNIQUE,
    device_name TEXT,
    device_type TEXT,  -- cashier, waiter, kitchen, bar
    ip_address TEXT,
    mac_address TEXT,
    app_version TEXT,
    platform TEXT,
    is_active BOOLEAN,
    last_seen_at TIMESTAMP,
    registered_at TIMESTAMP,
    registered_by TEXT,
    updated_at TIMESTAMP
);
```

### pairing_tokens
```sql
CREATE TABLE pairing_tokens (
    id INTEGER PRIMARY KEY,
    token TEXT UNIQUE,
    expires_at TIMESTAMP,
    used BOOLEAN,
    used_at TIMESTAMP,
    created_at TIMESTAMP
);
```

## 🎨 Frontend Integration

### Admin Dashboard

```html
<!-- QR Code Display -->
<div id="qr-container">
  <h3>Scan untuk Menghubungkan Device</h3>
  <img id="qr-image" src="" />
  <p>Expires in: <span id="countdown">5:00</span></p>
  <button onclick="refreshQR()">Generate New QR</button>
</div>

<script>
async function loadQR() {
  const response = await fetch('/api/v1/devices/qr', {
    headers: { 'Authorization': 'Bearer ' + getToken() }
  });
  const data = await response.json();
  
  document.getElementById('qr-image').src = 
    'data:image/png;base64,' + data.data.qr_code;
  
  startCountdown(data.data.expires_in);
}
</script>
```

### Device List

```html
<table>
  <tr>
    <th>Device Name</th>
    <th>Type</th>
    <th>IP</th>
    <th>Status</th>
    <th>Last Seen</th>
    <th>Actions</th>
  </tr>
  <!-- Loop devices -->
</table>
```

## 🚨 Troubleshooting

### QR Code tidak muncul
- Cek apakah admin sudah login
- Cek endpoint `/api/v1/devices/qr`
- Cek log server untuk error

### Device tidak bisa register
- Pastikan pairing token belum expired (< 5 menit)
- Cek network connectivity ke server IP
- Validate request body format

### Token invalid
- Token expired? Refresh atau register ulang
- JWT secret berbeda? Cek config server
- Token corrupted? Clear storage dan register ulang

### Heartbeat failed
- Cek device masih connected ke LAN
- Server restart? Token masih valid
- Update device IP jika berubah

## 📱 Supported Platforms

- ✅ Android (Native, React Native, Flutter)
- ✅ iOS (Native, React Native, Flutter)
- ✅ Windows Desktop (Electron, WPF, UWP)
- ✅ Web Browser (Chrome, Firefox, Safari, Edge)
- ✅ Tablet (iPad, Android Tablet)

## 🎯 Best Practices

1. **Device ID** - Gunakan UUID persistent (jangan generate baru tiap restart)
2. **Heartbeat** - Kirim setiap 5 menit untuk maintain connection
3. **Token Storage** - Simpan di secure storage (Keychain/KeyStore)
4. **Network Change** - Re-register jika IP berubah
5. **Error Handling** - Retry dengan exponential backoff
6. **Offline Mode** - Queue operations saat disconnected

## 📚 Related Docs

- [SYNC_SYSTEM.md](./SYNC_SYSTEM.md) - Cloud sync architecture
- [CONFIG_API.md](./CONFIG_API.md) - Configuration management
- [API_RESPONSE_STANDARD.md](./API_RESPONSE_STANDARD.md) - API standards
