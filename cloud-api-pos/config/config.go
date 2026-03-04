package config

import (
	"log"
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

type Config struct {
	Port            string
	DBHost          string
	DBPort          string
	DBUser          string
	DBPassword      string
	DBName          string
	DBSSLMode       string
	JWTSecret       string
	WebhookSecret   string
	RateLimitPerMin int
	AdminToken      string
}

func (c *Config) DSN() string {
	dsn := "host=" + c.DBHost +
		" port=" + c.DBPort +
		" user=" + c.DBUser +
		" dbname=" + c.DBName +
		" sslmode=" + c.DBSSLMode
	if c.DBPassword != "" {
		dsn += " password=" + c.DBPassword
	}
	return dsn
}

func Load() *Config {
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using environment variables")
	}

	rateLimit := 100
	if v := os.Getenv("RATE_LIMIT_PER_MINUTE"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			rateLimit = n
		}
	}

	return &Config{
		Port:            getEnv("PORT", "3000"),
		DBHost:          getEnv("DB_HOST", "localhost"),
		DBPort:          getEnv("DB_PORT", "5432"),
		DBUser:          getEnv("DB_USER", "postgres"),
		DBPassword:      getEnv("DB_PASSWORD", ""),
		DBName:          getEnv("DB_NAME", "cloud_pos"),
		DBSSLMode:       getEnv("DB_SSLMODE", "disable"),
		JWTSecret:       getEnv("JWT_SECRET", "change-me-in-production"),
		WebhookSecret:   getEnv("WEBHOOK_SECRET", "webhook-secret-key"),
		RateLimitPerMin: rateLimit,
		AdminToken:      getEnv("ADMIN_TOKEN", "admin-secret-token"),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
