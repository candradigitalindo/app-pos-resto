package config

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

type Config struct {
	DBPath     string
	ServerPort string
	JWTSecret  string
	Timezone   string

	// Cloud Sync Configuration
	CloudAPIURL     string
	CloudAPIKey     string
	OutletID        string
	OutletCode      string
	WebhookSecret   string
	SyncEnabled     bool
	SyncIntervalMin int
}

func LoadConfig() *Config {
	loadDotEnv(".env")
	syncEnabled, _ := strconv.ParseBool(getEnv("SYNC_ENABLED", "false"))
	syncInterval, _ := strconv.Atoi(getEnv("SYNC_INTERVAL_MINUTES", "5"))
	dbPath := os.Getenv("DB_PATH")
	if dbPath == "" {
		dbPath = defaultDBPath()
	}

	return &Config{
		DBPath:     dbPath,
		ServerPort: getEnv("SERVER_PORT", "8080"),
		JWTSecret:  getEnv("JWT_SECRET", "your-secret-key-change-in-production"),
		Timezone:   getEnv("TIMEZONE", "Asia/Jakarta"),

		// Cloud Sync
		CloudAPIURL:     getEnv("CLOUD_API_URL", ""),
		CloudAPIKey:     getEnv("CLOUD_API_KEY", ""),
		OutletID:        getEnv("OUTLET_ID", ""),
		OutletCode:      getEnv("OUTLET_CODE", ""),
		WebhookSecret:   getEnv("WEBHOOK_SECRET", ""),
		SyncEnabled:     syncEnabled,
		SyncIntervalMin: syncInterval,
	}
}

func loadDotEnv(path string) {
	content, err := os.ReadFile(path)
	if err != nil {
		return
	}

	lines := strings.Split(string(content), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if strings.HasPrefix(line, "export ") {
			line = strings.TrimSpace(strings.TrimPrefix(line, "export "))
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		if key == "" {
			continue
		}
		if os.Getenv(key) != "" {
			continue
		}
		value := strings.TrimSpace(parts[1])
		if len(value) >= 2 {
			if (value[0] == '"' && value[len(value)-1] == '"') || (value[0] == '\'' && value[len(value)-1] == '\'') {
				value = value[1 : len(value)-1]
			}
		}
		_ = os.Setenv(key, value)
	}
}

func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}

func (c *Config) GetDBPath() string {
	return c.DBPath
}

func defaultDBPath() string {
	configDir, err := os.UserConfigDir()
	if err == nil && configDir != "" {
		return filepath.Join(configDir, "POSApp", "pos.db")
	}
	return "./pos.db"
}
