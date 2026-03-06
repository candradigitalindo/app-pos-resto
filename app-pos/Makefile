.PHONY: build-frontend build-backend build-all run dev dev-backend dev-frontend clean install build-installer-windows

# Build frontend Vue.js
build-frontend:
	@echo "🔨 Building Vue.js frontend..."
	cd web && npm run build
	@echo "📦 Copying dist to cmd/web/dist..."
	rm -rf cmd/web/dist
	cp -r web/dist cmd/web/dist
	@echo "✅ Frontend built successfully!"

# Build Go backend with embedded frontend
build-backend: build-frontend
	@echo "🔨 Building Go backend with embedded frontend..."
	go build -ldflags="-s -w" -o pos-app ./cmd
	@echo "✅ Backend built successfully!"
	@echo "📦 Single binary created: pos-app"

# Build for Windows
build-windows: build-frontend
	@echo "🔨 Building for Windows..."
	GOOS=windows GOARCH=amd64 go build -ldflags="-s -w" -o pos-app.exe ./cmd
	@echo "✅ Windows build complete: pos-app.exe"

build-installer-windows: build-windows
	@echo "📦 Building Windows installer..."
	makensis installer/pos-app.nsi
	@echo "✅ Windows installer created: pos-app-setup.exe"

# Build for macOS
build-macos: build-frontend
	@echo "🔨 Building for macOS..."
	GOOS=darwin GOARCH=amd64 go build -ldflags="-s -w" -o pos-app-macos ./cmd
	@echo "✅ macOS build complete: pos-app-macos"

# Build for Linux
build-linux: build-frontend
	@echo "🔨 Building for Linux..."
	GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o pos-app-linux ./cmd
	@echo "✅ Linux build complete: pos-app-linux"

# Build all platforms
build-all-platforms: build-windows build-macos build-linux
	@echo "✅ All platform builds complete!"

# Build all (alias for current platform)
build-all: build-backend

# Run production build
run: build-all
	@echo "🚀 Starting POS application..."
	./pos-app

# Development mode (separate frontend & backend)
dev:
	@echo "🔧 Starting development servers..."
	@echo "Backend: http://localhost:8080"
	@echo "Frontend: http://localhost:5173"
	@make -j2 dev-backend dev-frontend

dev-backend:
	@echo "🔧 Starting Go backend..."
	go run ./cmd

dev-frontend:
	@echo "🔧 Starting Vue.js frontend..."
	cd web && npm run dev

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf web/dist
	rm -f pos-app pos-app.exe pos-app-macos pos-app-linux pos-app-setup.exe
	rm -rf bin/
	@echo "✅ Clean complete!"

# Install dependencies
install:
	@echo "📦 Installing Go dependencies..."
	go mod download
	@echo "📦 Installing Node dependencies..."
	cd web && npm install
	@echo "✅ All dependencies installed!"

# Run tests
test:
	@echo "🧪 Running Go tests..."
	go test ./...

# Build and run (quick start)
start: build-all run
