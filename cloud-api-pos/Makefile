.PHONY: run build dev clean migrate

# Run the server
run:
	@echo "🚀 Starting Cloud API server..."
	go run main.go

# Build binary
build:
	@echo "🔨 Building Cloud API..."
	go build -ldflags="-s -w" -o cloud-api main.go
	@echo "✅ Built: cloud-api"

# Build for Linux (production deployment)
build-linux:
	@echo "🔨 Building for Linux..."
	GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o cloud-api-linux main.go
	@echo "✅ Built: cloud-api-linux"

# Development with hot reload (requires air)
dev:
	@which air > /dev/null 2>&1 || (echo "Installing air..." && go install github.com/air-verse/air@latest)
	air

# Clean build artifacts
clean:
	rm -f cloud-api cloud-api-linux

# Download dependencies
deps:
	go mod tidy
	go mod download
