package main

import (
	"backend/config"
	"backend/internal/db"
	"backend/internal/handlers"
	authmw "backend/internal/middleware"
	"backend/internal/repositories"
	"backend/internal/services"
	"backend/internal/workers"
	"backend/pkg/cloudapi"
	"backend/pkg/database"
	"backend/pkg/printer"
	"context"
	"embed"
	"encoding/json"
	"io/fs"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	socketio "github.com/googollee/go-socket.io"
	"github.com/googollee/go-socket.io/engineio"
	"github.com/googollee/go-socket.io/engineio/transport"
	"github.com/googollee/go-socket.io/engineio/transport/polling"
	"github.com/googollee/go-socket.io/engineio/transport/websocket"
	"github.com/labstack/echo/v5"
	"github.com/labstack/echo/v5/middleware"
)

//go:embed all:web/dist
var embeddedFiles embed.FS

type socketBroadcaster struct {
	server *socketio.Server
}

func (b *socketBroadcaster) Emit(event string, payload map[string]interface{}) {
	if b == nil || b.server == nil {
		return
	}
	b.server.BroadcastToNamespace("/", event, payload)
}

// APIResponse struktur standar untuk response
type APIResponse struct {
	Success bool        `json:"success"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

// getLocalIP gets the local IP address for LAN access
func getLocalIP() string {
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		return ""
	}
	for _, addr := range addrs {
		if ipnet, ok := addr.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
			if ipnet.IP.To4() != nil {
				return ipnet.IP.String()
			}
		}
	}
	return ""
}

// customHTTPErrorHandler handles HTTP errors dengan format standar
func customHTTPErrorHandler(c *echo.Context, err error) {
	code := http.StatusInternalServerError
	message := "Terjadi kesalahan pada server"

	// Log the actual error for debugging
	log.Printf("ERROR HANDLER: %v (type: %T)", err, err)

	// Try type assertion to *echo.HTTPError (exported type)
	if he, ok := err.(*echo.HTTPError); ok {
		code = he.Code
		log.Printf("HTTPError (exported): code=%d", code)
	} else if sc, ok := err.(interface{ StatusCode() int }); ok {
		// Use Echo's HTTPStatusCoder interface
		code = sc.StatusCode()
		log.Printf("HTTPStatusCoder: code=%d", code)
	} else {
		log.Printf("Unknown error type: %T, error: %v", err, err)
	}

	// Set message based on status code
	switch code {
	case http.StatusNotFound:
		message = "Endpoint tidak ditemukan"
	case http.StatusMethodNotAllowed:
		message = "Method tidak diizinkan"
	case http.StatusBadRequest:
		message = "Request tidak valid"
	case http.StatusUnauthorized:
		message = "Unauthorized"
	case http.StatusForbidden:
		message = "Forbidden"
	case http.StatusInternalServerError:
		message = "Terjadi kesalahan pada server"
	}

	log.Printf("Response: code=%d, message=%s", code, message)

	// Create response
	response := APIResponse{
		Success: false,
		Message: message,
	}

	// Set content type and status code
	(*c).Response().Header().Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
	(*c).Response().WriteHeader(code)

	// Encode response
	if err := json.NewEncoder((*c).Response()).Encode(response); err != nil {
		log.Printf("Failed to encode error response: %v", err)
	}
}

func main() {
	// Load configuration
	cfg := config.LoadConfig()
	location, err := time.LoadLocation(cfg.Timezone)
	if err != nil {
		log.Printf("Invalid TIMEZONE %s, using UTC", cfg.Timezone)
		location = time.UTC
	}
	time.Local = location

	// Initialize database
	sqlDB, err := database.NewDatabase(cfg.GetDBPath())
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}
	defer sqlDB.Close()

	// Initialize queries
	queries := db.New(sqlDB)

	// Initialize Echo
	e := echo.New()

	// Custom HTTP error handler
	e.HTTPErrorHandler = customHTTPErrorHandler

	socketServer := socketio.NewServer(&engineio.Options{
		PingTimeout:  60 * time.Second,
		PingInterval: 25 * time.Second,
		Transports: []transport.Transport{
			polling.Default,
			websocket.Default,
		},
		RequestChecker: func(r *http.Request) (http.Header, error) {
			return nil, nil
		},
	})
	socketServer.OnConnect("/", func(s socketio.Conn) error {
		url := s.URL()
		token := url.Query().Get("token")
		claims, err := authmw.ParseJWTClaims(token)
		if err != nil {
			return err
		}
		s.SetContext(claims)
		return nil
	})
	socketServer.OnError("/", func(s socketio.Conn, err error) {
		log.Printf("Socket error: %v", err)
	})
	socketServer.OnDisconnect("/", func(s socketio.Conn, reason string) {
		log.Printf("Socket disconnected: %s", reason)
	})

	go func() {
		if err := socketServer.Serve(); err != nil {
			log.Printf("Socket server error: %v", err)
		}
	}()
	defer socketServer.Close()

	// Middleware
	e.Use(middleware.Recover())
	e.Use(middleware.RequestLoggerWithConfig(middleware.RequestLoggerConfig{
		LogURI:    true,
		LogStatus: true,
		LogValuesFunc: func(c *echo.Context, v middleware.RequestLoggerValues) error {
			log.Printf("REQUEST: uri=%v, status=%v\n", v.URI, v.Status)
			return nil
		},
	}))
	e.Use(middleware.CORSWithConfig(middleware.CORSConfig{
		AllowOrigins: []string{"*"},
		AllowMethods: []string{"GET", "PUT", "POST", "DELETE"},
	}))

	// Initialize repositories
	productRepo := repositories.NewProductRepository(sqlDB)
	categoryRepo := repositories.NewCategoryRepository(sqlDB)
	transactionRepo := repositories.NewTransactionRepository(sqlDB)
	orderRepo := repositories.NewOrderRepository(sqlDB)
	tableRepo := repositories.NewTableRepository(sqlDB)
	syncRepo := repositories.NewSyncRepository(sqlDB)
	deviceRepo := repositories.NewDeviceRepository(sqlDB)
	printerRepo := repositories.NewPrinterRepository(sqlDB)
	customerRepo := repositories.NewCustomerRepository(sqlDB)

	// Load sync configuration from database (priority), fallback to env
	var cloudClient *cloudapi.Client
	var syncService services.SyncService

	dbConfig, err := syncRepo.GetOutletConfig(context.Background())
	if err != nil {
		log.Printf("Warning: Failed to load config from database: %v", err)
	}

	// Determine which config to use
	var outletID, outletCode, cloudURL, cloudKey string
	var syncEnabled bool

	if dbConfig != nil && dbConfig.SyncEnabled {
		// Use database config (priority)
		outletID = dbConfig.OutletID
		outletCode = dbConfig.OutletCode
		cloudURL = dbConfig.CloudAPIURL
		cloudKey = dbConfig.CloudAPIKey
		syncEnabled = dbConfig.SyncEnabled
		log.Println("Using sync configuration from database")
	} else if cfg.SyncEnabled && cfg.CloudAPIURL != "" {
		// Fallback to environment variables
		outletID = cfg.OutletID
		outletCode = cfg.OutletCode
		cloudURL = cfg.CloudAPIURL
		cloudKey = cfg.CloudAPIKey
		syncEnabled = cfg.SyncEnabled
		log.Println("Using sync configuration from environment variables")
	}

	// Initialize cloud client if configured
	if syncEnabled && cloudURL != "" {
		cloudClient = cloudapi.NewClient(cloudURL, cloudKey, outletID, outletCode)
		syncService = services.NewSyncService(syncRepo, cloudClient, sqlDB)
		log.Printf("Cloud sync enabled: %s (Outlet: %s)", cloudURL, outletCode)
	} else {
		log.Println("Cloud sync disabled - Configure via /api/v1/config/outlet")
	}

	// Initialize services
	productService := services.NewProductService(productRepo)
	categoryService := services.NewCategoryService(categoryRepo)
	transactionService := services.NewTransactionService(transactionRepo, productRepo)
	orderService := services.NewOrderService(orderRepo)
	tableService := services.NewTableService(tableRepo)
	printerService := services.NewPrinterService(printerRepo)
	customerService := services.NewCustomerService(customerRepo)

	// Initialize handlers
	authHandler := handlers.NewAuthHandler(sqlDB)
	productHandler := handlers.NewProductHandler(productService)
	categoryHandler := handlers.NewCategoryHandler(categoryService)
	transactionHandler := handlers.NewTransactionHandler(transactionService, queries, sqlDB)
	socketBroadcaster := &socketBroadcaster{server: socketServer}
	orderHandler := handlers.NewOrderHandler(orderService, transactionService, customerService, queries, sqlDB, socketBroadcaster)
	tableHandler := handlers.NewTableHandler(tableService, queries)
	printerHandler := handlers.NewPrinterHandler(printerService, syncRepo)
	printHandler := handlers.NewPrintHandler(sqlDB)
	customerHandler := handlers.NewCustomerHandler(customerService, orderService)

	// Config handler - always available for managing sync config
	configHandler := handlers.NewConfigHandler(syncRepo)

	// Device handler - for LAN device registration
	deviceHandler := handlers.NewDeviceHandler(deviceRepo, cfg.JWTSecret, cfg.ServerPort)

	// Sync components
	var syncHandler *handlers.SyncHandler
	var webhookHandler *handlers.WebhookHandler
	var syncWorker *workers.SyncWorker

	if syncService != nil {
		syncHandler = handlers.NewSyncHandler(syncService)

		// Initialize webhook handler with secret from config
		webhookSecret := cfg.WebhookSecret // Add this to your config
		if webhookSecret == "" {
			webhookSecret = "default-secret-change-me" // Default for dev
		}
		webhookHandler = handlers.NewWebhookHandler(syncService, webhookSecret)

		// Initialize background sync worker
		syncIntervalMin := 5 // Default
		if dbConfig != nil && dbConfig.SyncIntervalMin > 0 {
			syncIntervalMin = dbConfig.SyncIntervalMin
		}
		syncWorker = workers.NewSyncWorker(syncService, syncIntervalMin, syncEnabled)
		syncWorker.Start()
		if syncEnabled {
			log.Printf("✅ Background sync worker started (interval: %d minutes)", syncIntervalMin)
		} else {
			log.Printf("⏸️  Background sync worker initialized but disabled")
		}

		// Set sync worker to config handler for real-time control
		configHandler.SetSyncWorker(syncWorker)
	}

	// Initialize print worker - get outlet config from database
	outletCfg, err := syncRepo.GetOutletConfig(context.Background())
	if err != nil {
		log.Printf("Warning: Could not load outlet config, using defaults: %v", err)
	}

	outletConfig := printer.OutletConfig{
		Name:        "Outlet",
		Address:     "Alamat Outlet",
		Phone:       "Telp: -",
		SocialMedia: "",
		Footer:      "Terima kasih atas kunjungan Anda!",
	}

	// Override with actual config if available
	if outletCfg != nil {
		outletConfig.Name = outletCfg.OutletName
		outletConfig.Address = outletCfg.OutletAddress
		outletConfig.Phone = outletCfg.OutletPhone
		outletConfig.SocialMedia = outletCfg.SocialMedia
		outletConfig.Footer = outletCfg.ReceiptFooter
	}

	printWorker := workers.NewPrintWorker(sqlDB, outletConfig)

	// Start print worker in background
	ctx, cancelPrint := context.WithCancel(context.Background())
	go printWorker.Start(ctx)
	log.Println("🖨️  Print worker started")

	// Routes
	api := e.Group("/api/v1")

	// Public routes - No auth required
	api.POST("/auth/login", authHandler.HandleLogin)

	// Protected routes - Require JWT
	protected := api.Group("", authmw.JWTMiddleware())

	// Auth routes
	protected.GET("/auth/profile", authHandler.HandleGetProfile)
	protected.PUT("/auth/profile", authHandler.HandleUpdateProfile)
	protected.POST("/auth/register", authHandler.HandleRegister, authmw.AdminOnly())

	// User management routes - Admin/Manager only
	protected.GET("/users", authHandler.HandleListUsers, authmw.ManagerOrAdmin())
	protected.GET("/users/:id", authHandler.HandleGetUser, authmw.ManagerOrAdmin())
	protected.PUT("/users/:id", authHandler.HandleUpdateUser, authmw.ManagerOrAdmin())
	protected.DELETE("/users/:id", authHandler.HandleDeleteUser, authmw.ManagerOrAdmin())
	protected.PUT("/users/:id/role", authHandler.HandleUpdateUserRole, authmw.ManagerOrAdmin())
	protected.PUT("/users/:id/deactivate", authHandler.HandleDeactivateUser, authmw.ManagerOrAdmin())
	protected.PUT("/users/:id/activate", authHandler.HandleActivateUser, authmw.ManagerOrAdmin())

	// Order routes - Role-based access
	// Waiter can create orders and merge tables
	protected.POST("/orders", orderHandler.HandleCreateOrder, authmw.WaiterOrAdmin())
	protected.GET("/orders", orderHandler.HandleListOrders)
	protected.POST("/orders/merge", orderHandler.HandleMergeTables, authmw.WaiterOrAdmin())
	protected.POST("/orders/:id/items", orderHandler.HandleAddItemsToOrder, authmw.WaiterOrAdmin())
	protected.POST("/orders/table/:table_id/items", orderHandler.HandleAddItemsToOrderByTable, authmw.WaiterOrAdmin())
	// Kitchen/Bar can update item status
	protected.PUT("/orders/items/:id/status", orderHandler.HandleUpdateOrderItemStatus, authmw.KitchenBarOrAdmin())
	protected.PUT("/orders/items/:id/qty", orderHandler.HandleUpdateOrderItemQty, authmw.CashierOrAdmin())
	protected.GET("/orders/pending", orderHandler.HandleGetDisplayOrders, authmw.KitchenBarOrAdmin())
	// Cashier can process payment (full or split bill)
	protected.POST("/orders/:id/payment", orderHandler.HandleProcessPayment, authmw.CashierOrAdmin())
	protected.POST("/orders/:id/discount", orderHandler.HandleApplyDiscount, authmw.CashierOrAdmin())
	protected.POST("/orders/:id/compliment", orderHandler.HandleApplyCompliment, authmw.CashierOrAdmin())
	protected.POST("/orders/:id/split-payment", orderHandler.HandleSplitBillPayment, authmw.CashierOrAdmin())
	protected.POST("/orders/:id/void", orderHandler.HandleVoidOrder, authmw.CashierManagerOrAdmin())
	protected.GET("/orders/voided", orderHandler.HandleGetVoidedOrders, authmw.CashierManagerOrAdmin())
	// Manager/Admin/Cashier can view analytics
	protected.GET("/orders/analytics", orderHandler.HandleGetOrderAnalytics, authmw.CashierManagerOrAdmin())
	protected.GET("/orders/chart", orderHandler.HandleGetRevenueChart, authmw.ManagerOrAdmin())
	// All authenticated can view order details
	protected.GET("/orders/:id", orderHandler.HandleGetOrderDetails)
	protected.GET("/orders/table/:table_id", orderHandler.HandleGetOrderByTable)

	// Product routes - Admin/Manager only for CUD, all can read
	protected.POST("/products", productHandler.CreateProduct, authmw.ManagerOrAdmin())
	protected.GET("/products", productHandler.GetAllProducts)
	protected.GET("/products/:id", productHandler.GetProduct)
	protected.PUT("/products/:id", productHandler.UpdateProduct, authmw.ManagerOrAdmin())
	protected.DELETE("/products/:id", productHandler.DeleteProduct, authmw.AdminOnly())
	protected.GET("/products/category/:categoryId", productHandler.GetProductsByCategory)

	// Category routes - Admin/Manager only for CUD, all can read
	protected.POST("/categories", categoryHandler.CreateCategory, authmw.ManagerOrAdmin())
	protected.GET("/categories", categoryHandler.GetAllCategories)
	protected.GET("/categories/:id", categoryHandler.GetCategory)
	protected.PUT("/categories/:id", categoryHandler.UpdateCategory, authmw.ManagerOrAdmin())
	protected.DELETE("/categories/:id", categoryHandler.DeleteCategory, authmw.AdminOnly())

	// Printer routes - Admin only
	protected.POST("/printers", printerHandler.CreatePrinter, authmw.AdminOnly())
	protected.GET("/printers", printerHandler.GetAllPrinters)
	protected.GET("/printers/:id", printerHandler.GetPrinter)
	protected.PUT("/printers/:id", printerHandler.UpdatePrinter, authmw.AdminOnly())
	protected.DELETE("/printers/:id", printerHandler.DeletePrinter, authmw.AdminOnly())
	protected.PATCH("/printers/:id/toggle", printerHandler.TogglePrinter, authmw.AdminOnly())
	protected.POST("/printers/:id/test", printerHandler.TestPrintHandler, authmw.AdminOnly())

	// Print routes - Cashier/Admin can print
	protected.POST("/print/order", printHandler.HandlePrintOrder, authmw.CashierOrAdmin())
	protected.POST("/print/reprint/:id", printHandler.HandleReprintOrder, authmw.CashierOrAdmin())
	protected.POST("/print/bill/:id", printHandler.HandlePrintBill, authmw.CashierOrAdmin())
	protected.GET("/print/queue", printHandler.HandleGetPrintQueue, authmw.ManagerOrAdmin())
	protected.POST("/print/queue/:id/retry", printHandler.HandleRetryPrintQueue, authmw.ManagerOrAdmin())

	// Table routes - Admin/Manager/Waiter
	protected.POST("/tables", tableHandler.CreateTable, authmw.ManagerOrAdmin())
	protected.GET("/tables", tableHandler.GetAllTables)
	protected.GET("/tables/:id", tableHandler.GetTable)
	protected.GET("/tables/number/:number", tableHandler.GetTableByNumber)
	protected.GET("/tables/available", tableHandler.GetAvailableTables)
	protected.GET("/tables/occupied", tableHandler.GetOccupiedTables)
	protected.PUT("/tables/:id", tableHandler.UpdateTable, authmw.ManagerOrAdmin())
	protected.PUT("/tables/status/:number", tableHandler.UpdateTableStatus, authmw.WaiterManagerOrAdmin())
	protected.DELETE("/tables/:id", tableHandler.DeleteTable, authmw.AdminOnly())

	protected.GET("/customers/phone/:phone", customerHandler.GetCustomerByPhone, authmw.WaiterOrAdmin())
	protected.GET("/customers/top", customerHandler.GetTopCustomers, authmw.ManagerOrAdmin())
	protected.GET("/customers/:id/orders", customerHandler.GetCustomerOrders, authmw.WaiterOrAdmin())

	// Transaction routes - Cashier/Admin can create, all can read
	protected.POST("/transactions", transactionHandler.CreateTransaction, authmw.CashierOrAdmin())
	protected.GET("/transactions", transactionHandler.GetAllTransactions, authmw.CashierManagerOrAdmin())
	protected.GET("/transactions/:id", transactionHandler.GetTransaction, authmw.CashierManagerOrAdmin())
	protected.POST("/transactions/:id/cancel", transactionHandler.CancelTransaction, authmw.CashierManagerOrAdmin())
	protected.GET("/transactions/date-range", transactionHandler.GetTransactionsByDateRange, authmw.ManagerOrAdmin())

	cashierShiftGroup := protected.Group("/cashier", authmw.CashierOrAdmin())
	cashierShiftGroup.GET("/shifts/state", transactionHandler.GetCashierShiftState)
	cashierShiftGroup.POST("/shifts/open", transactionHandler.OpenCashierShift)
	cashierShiftGroup.POST("/shifts/close", transactionHandler.CloseCashierShift)
	cashierShiftGroup.POST("/shifts/handover", transactionHandler.HandoverCashierShift)
	cashierShiftGroup.POST("/shifts/movements", transactionHandler.CreateCashMovement)
	cashierShiftGroup.GET("/users", transactionHandler.ListCashierUsers)

	// Config routes - Admin or Manager
	configGroup := protected.Group("/config", authmw.ManagerOrAdmin())
	configGroup.GET("/outlet", configHandler.GetOutletConfig)
	configGroup.POST("/outlet", configHandler.CreateOutletConfig)
	configGroup.PUT("/outlet", configHandler.UpdateOutletConfig)
	configGroup.POST("/outlet/test", configHandler.TestCloudConnection)
	configGroup.GET("/sync", configHandler.GetSyncSettings)
	configGroup.POST("/sync/toggle", configHandler.ToggleSync)
	configGroup.GET("/additional-charges", configHandler.GetAdditionalCharges)
	configGroup.POST("/additional-charges", configHandler.CreateAdditionalCharge)
	configGroup.PUT("/additional-charges/:id", configHandler.UpdateAdditionalCharge)
	configGroup.DELETE("/additional-charges/:id", configHandler.DeleteAdditionalCharge)
	log.Println("Config management endpoints registered")

	// Device LAN Sync routes
	api.GET("/server/qr", deviceHandler.GenerateServerURLQRCode)

	// Public endpoint for QR generation (admin only)
	deviceAdminGroup := protected.Group("/devices", authmw.AdminOnly())
	deviceAdminGroup.GET("/qr", deviceHandler.GenerateQRCode)
	deviceAdminGroup.GET("/status", deviceHandler.GetDeviceStatus)
	deviceAdminGroup.GET("/list", deviceHandler.GetDeviceList)
	deviceAdminGroup.DELETE("/:device_id", deviceHandler.DeleteDevice)
	deviceAdminGroup.PUT("/:device_id/deactivate", deviceHandler.DeactivateDevice)

	// Public endpoint for device registration (no auth required for initial setup)
	api.POST("/devices/register", deviceHandler.RegisterDevice)

	// Protected endpoint for device heartbeat (requires device token)
	protected.POST("/devices/heartbeat", deviceHandler.DeviceHeartbeat)

	log.Println("LAN device sync endpoints registered")

	// Sync routes - Admin only
	if syncHandler != nil {
		syncGroup := protected.Group("/sync", authmw.AdminOnly())
		syncGroup.GET("/status", syncHandler.GetSyncStatus)
		syncGroup.POST("/trigger", syncHandler.TriggerSync)
		syncGroup.GET("/logs", syncHandler.GetSyncLogs)
		syncGroup.GET("/failed", syncHandler.GetFailedSync)
		syncGroup.POST("/retry/:id", syncHandler.RetrySync)
		log.Println("Sync management endpoints registered")
	}

	// Webhook routes - Public (verified via signature)
	if webhookHandler != nil {
		webhooks := api.Group("/webhooks/cloud")
		webhooks.POST("/update", webhookHandler.HandleCloudUpdate)
		webhooks.POST("/delete", webhookHandler.HandleCloudDelete)
		webhooks.POST("/conflict", webhookHandler.HandleCloudConflict)
		webhooks.POST("/bulk-update", webhookHandler.HandleCloudBulkUpdate)
		log.Println("Cloud webhook endpoints registered")
	}

	e.Any("/socket.io", echo.WrapHandler(socketServer))
	e.Any("/socket.io/", echo.WrapHandler(socketServer))
	e.Any("/socket.io/*", echo.WrapHandler(socketServer))

	// ============================================
	// SERVE EMBEDDED FRONTEND (Vue.js)
	// ============================================
	// Try to load embedded filesystem
	staticFiles, err := fs.Sub(embeddedFiles, "web/dist")
	if err != nil {
		log.Printf("Warning: Failed to load embedded frontend: %v", err)
		log.Println("Running in API-only mode. Frontend not available.")
	} else {
		// Serve static files (CSS, JS, images, fonts)
		e.GET("/assets/*", echo.WrapHandler(http.FileServer(http.FS(staticFiles))))

		// Serve other static files (favicon, manifest, sw, icons, etc.)
		e.GET("/favicon.ico", echo.WrapHandler(http.FileServer(http.FS(staticFiles))))
		e.GET("/manifest.json", echo.WrapHandler(http.FileServer(http.FS(staticFiles))))
		e.GET("/sw.js", echo.WrapHandler(http.FileServer(http.FS(staticFiles))))
		e.GET("/vite.svg", echo.WrapHandler(http.FileServer(http.FS(staticFiles))))
		e.GET("/icon-192.png", echo.WrapHandler(http.FileServer(http.FS(staticFiles))))
		e.GET("/icon-192.png.txt", echo.WrapHandler(http.FileServer(http.FS(staticFiles))))

		// Serve index.html for all non-API routes (SPA routing)
		e.GET("/*", func(c *echo.Context) error {
			path := (*c).Request().URL.Path

			// Skip API routes
			if len(path) >= 4 && path[:4] == "/api" {
				return echo.NewHTTPError(http.StatusNotFound, "API endpoint not found")
			}

			// Skip socket.io
			if len(path) >= 10 && path[:10] == "/socket.io" {
				return echo.NewHTTPError(http.StatusNotFound, "Socket endpoint not found")
			}

			// Skip assets
			if len(path) >= 7 && path[:7] == "/assets" {
				return echo.NewHTTPError(http.StatusNotFound, "Asset not found")
			}

			// Read index.html from embedded files
			indexHTML, err := staticFiles.Open("index.html")
			if err != nil {
				return echo.NewHTTPError(http.StatusInternalServerError, "Failed to load UI")
			}
			defer indexHTML.Close()

			return (*c).Stream(http.StatusOK, "text/html", indexHTML)
		})

		log.Println("✅ Frontend UI served at root path /")
	}

	// Start server
	log.Println("============================================")
	log.Printf("🚀 POS Server starting on port %s", cfg.ServerPort)
	log.Printf("📱 UI: http://localhost:%s", cfg.ServerPort)
	log.Printf("🌐 API: http://localhost:%s/api/v1", cfg.ServerPort)

	// Get local IP for LAN access
	if localIP := getLocalIP(); localIP != "" {
		log.Printf("🌍 LAN Access: http://%s:%s", localIP, cfg.ServerPort)
	}
	log.Println("============================================")

	// Setup graceful shutdown
	go func() {
		if err := e.Start(":" + cfg.ServerPort); err != nil && err != http.ErrServerClosed {
			log.Fatal("Failed to start server:", err)
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt, syscall.SIGTERM)
	<-quit

	log.Println("Server shutting down...")

	// Stop sync worker gracefully
	if syncWorker != nil {
		syncWorker.Stop()
	}

	// Stop print worker gracefully
	cancelPrint()
	log.Println("🖨️  Print worker stopped")

	// Close the server
	log.Println("Server exited")
}
