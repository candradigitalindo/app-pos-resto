package main

import (
	"cloud-api-pos/config"
	"cloud-api-pos/database"
	"cloud-api-pos/routes"
	"fmt"
	"log"
	"net"
	"os"
	"os/signal"
	"syscall"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
)

func main() {
	cfg := config.Load()

	if err := database.Connect(cfg); err != nil {
		log.Fatalf("Database connection failed: %v", err)
	}
	defer database.Close()

	if err := database.RunMigrations(); err != nil {
		log.Fatalf("Migration failed: %v", err)
	}

	if err := database.SeedAdmin(); err != nil {
		log.Printf("Admin seeder warning: %v", err)
	}

	app := fiber.New(fiber.Config{
		AppName:      "Nusantara POS Cloud API v1.0.0",
		BodyLimit:    10 * 1024 * 1024,
		ServerHeader: "NusantaraPOS-Cloud",
		ErrorHandler: func(c *fiber.Ctx, err error) error {
			code := fiber.StatusInternalServerError
			if e, ok := err.(*fiber.Error); ok {
				code = e.Code
			}
			return c.Status(code).JSON(fiber.Map{
				"success": false,
				"error":   err.Error(),
			})
		},
	})

	app.Use(recover.New())
	app.Use(logger.New(logger.Config{
		Format:     "${time} | ${status} | ${latency} | ${ip} | ${method} ${path}\n",
		TimeFormat: "2006-01-02 15:04:05",
	}))
	app.Use(cors.New(cors.Config{
		AllowOrigins: "*",
		AllowHeaders: "Origin, Content-Type, Accept, Authorization, X-Outlet-ID, X-Outlet-Code, X-Cloud-Signature",
		AllowMethods: "GET, POST, PUT, DELETE, OPTIONS",
	}))

	routes.Setup(app, cfg)

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-quit
		log.Println("Shutting down Cloud API server...")
		app.Shutdown()
	}()

	addr := fmt.Sprintf(":%s", cfg.Port)
	log.Printf("Nusantara POS Cloud API running on http://localhost%s", addr)

	if lanIP := getLANIP(); lanIP != "" {
		log.Printf("LAN access: http://%s%s", lanIP, addr)
	}

	if err := app.Listen(addr); err != nil {
		log.Fatalf("Server error: %v", err)
	}
}

func getLANIP() string {
	ifaces, err := net.Interfaces()
	if err != nil {
		return ""
	}
	for _, iface := range ifaces {
		if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 {
			continue
		}
		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}
		for _, addr := range addrs {
			var ip net.IP
			switch v := addr.(type) {
			case *net.IPNet:
				ip = v.IP
			case *net.IPAddr:
				ip = v.IP
			}
			if ip == nil || ip.IsLoopback() || ip.To4() == nil {
				continue
			}
			return ip.String()
		}
	}
	return ""
}
