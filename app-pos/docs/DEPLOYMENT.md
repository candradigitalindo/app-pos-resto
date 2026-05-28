# POS System - Deployment Guide

## ✅ Implementation Complete!

Single binary POS application dengan embedded Vue.js frontend sudah berhasil diimplementasikan.

## 🎯 What's Been Built

✅ **Backend Go dengan embedded Vue.js**
✅ **Single binary executable (1 file)**
✅ **Auto-serve UI + API**
✅ **LAN access ready**
✅ **Login page dengan PIN 4 digit**
✅ **Dashboard dengan role-based routing**
✅ **Makefile untuk easy build**

## 🚀 Quick Start

### Development Mode
```bash
# Terminal 1 - Backend
go run cmd/main.go

# Terminal 2 - Frontend (hot reload)
cd web && npm run dev
```

Frontend: http://localhost:5173 (dev dengan hot reload)
Backend API: http://localhost:8080/api/v1

### Production Build
```bash
# Build frontend & backend jadi 1 binary
make build-all

# Jalankan
./pos-app
```

Access: http://localhost:8080 (UI + API dalam 1 server)

## 📦 Files Generated

```
backend/
├── pos-app                 # ← Single binary executable! 🎉
├── cmd/web/dist/           # Frontend build (embedded ke binary)
├── web/                    # Vue.js source
│   ├── src/
│   │   ├── views/          # LoginView, DashboardView, dll
│   │   ├── stores/         # Pinia auth store
│   │   ├── router/         # Vue Router setup
│   │   └── services/       # API service dengan axios
│   └── dist/               # Build output
└── Makefile                # Build automation
```

## 🌐 Server Status

✅ Server running pada: **http://localhost:8080**
✅ LAN Access: **http://192.168.1.43:8080**
✅ Frontend UI: **Served at root path /**
✅ API: **Available at /api/v1**

## 🔐 Default Login

```
Username: admin
PIN: 1234
```

## 📱 Cara Deploy di Windows

1. **Build untuk Windows**:
   ```bash
   make build-windows
   ```
   Output: `pos-app.exe`

2. **Copy ke komputer Windows**:
   - Copy file `pos-app.exe`
   - Copy file `.env` (jika ada)
   - Copy folder `pos.db` (database)

3. **Run**:
   ```cmd
   pos-app.exe
   ```

4. **Access**:
   - Dari server: http://localhost:8080
   - Dari LAN: http://IP_SERVER:8080

## 🔥 Features Implemented

### Frontend (Vue.js)
- ✅ Login page with 4-digit PIN validation
- ✅ Dashboard with menu cards
- ✅ Vue Router with authentication guard
- ✅ Pinia store for state management
- ✅ Axios interceptors for JWT token
- ✅ Responsive design
- ✅ Role-based page access

### Backend (Go)
- ✅ Embed Vue.js dist files
- ✅ Serve static assets (/assets/*, /favicon.ico)
- ✅ SPA routing (serve index.html for non-API routes)
- ✅ API endpoints tetap available
- ✅ Display local IP untuk LAN access
- ✅ Graceful shutdown

## 🎨 UI Pages Available

1. **Login** (`/login`) - Public
2. **Dashboard** (`/`) - Authenticated users
3. **Cashier** (`/cashier`) - Role: admin, cashier
4. **Waiter** (`/waiter`) - Role: admin, waiter
5. **Kitchen** (`/kitchen`) - Role: admin, kitchen, bar

## 🛠️ Build Commands

```bash
# Install dependencies
make install

# Development mode (hot reload)
make dev

# Build for current platform
make build-all

# Build for Windows
make build-windows

# Build for macOS
make build-macos

# Build for Linux
make build-linux

# Build all platforms
make build-all-platforms

# Clean build artifacts
make clean

# Build and run
make start
```

## 📊 Server Output

```
2026/01/27 13:27:44 Database connected and migrated successfully
2026/01/27 13:27:44 Cloud sync disabled - Configure via /api/v1/config/outlet
2026/01/27 13:27:44 Config management endpoints registered
2026/01/27 13:27:44 LAN device sync endpoints registered
2026/01/27 13:27:44 ✅ Frontend UI served at root path /
2026/01/27 13:27:44 ============================================
2026/01/27 13:27:44 🚀 POS Server starting on port 8080
2026/01/27 13:27:44 📱 UI: http://localhost:8080
2026/01/27 13:27:44 🌐 API: http://localhost:8080/api/v1
2026/01/27 13:27:44 🌍 LAN Access: http://192.168.1.43:8080
2026/01/27 13:27:44 ============================================
```

## 🎯 Next Steps

1. **Test Login**: Buka http://localhost:8080
2. **Develop Pages**: Lengkapi Cashier, Waiter, Kitchen views
3. **Build Production**: `make build-windows` untuk deployment
4. **Deploy**: Copy `pos-app.exe` ke Windows server
5. **LAN Test**: Akses dari device lain via IP

## 🔗 API Integration

Frontend sudah terhubung ke backend API:

```javascript
// services/api.js
import axios from 'axios'

const api = axios.create({
  baseURL: '/api/v1',  // Proxy ke backend
  headers: {
    'Content-Type': 'application/json'
  }
})

// Auto-attach JWT token
api.interceptors.request.use(config => {
  const token = localStorage.getItem('token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})
```

## 💡 Tips

- **Development**: Gunakan `make dev` untuk hot reload
- **Production**: Gunakan `make build-all` untuk single binary
- **Testing API**: Tetap bisa akses `/api/v1/*` langsung
- **Frontend Only**: Dev mode di http://localhost:5173
- **Full Stack**: Production di http://localhost:8080

---

**🎉 Implementation Success!**

Single binary POS application siap untuk deployment!
