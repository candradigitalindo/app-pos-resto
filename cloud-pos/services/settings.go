package services

import (
	"cloud-pos/database"
	"cloud-pos/models"
	"fmt"
	"strconv"
	"time"
)

// validTimezones contains common Indonesian and international timezones
var validTimezones = map[string]bool{
	"Asia/Jakarta":        true,
	"Asia/Makassar":       true,
	"Asia/Jayapura":       true,
	"Asia/Pontianak":      true,
	"Asia/Singapore":      true,
	"Asia/Kuala_Lumpur":   true,
	"Asia/Bangkok":        true,
	"Asia/Tokyo":          true,
	"Asia/Seoul":          true,
	"Asia/Shanghai":       true,
	"Asia/Kolkata":        true,
	"Asia/Dubai":          true,
	"Europe/London":       true,
	"Europe/Paris":        true,
	"Europe/Berlin":       true,
	"America/New_York":    true,
	"America/Chicago":     true,
	"America/Los_Angeles": true,
	"Australia/Sydney":    true,
	"Pacific/Auckland":    true,
	"UTC":                 true,
}

func GetAllSettings() ([]models.AppSetting, error) {
	rows, err := database.DB.Query("SELECT key, value, updated_at FROM app_settings ORDER BY key")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var settings []models.AppSetting
	for rows.Next() {
		var s models.AppSetting
		if err := rows.Scan(&s.Key, &s.Value, &s.UpdatedAt); err != nil {
			return nil, err
		}
		settings = append(settings, s)
	}
	return settings, nil
}

func GetSettingsByKeys(keys []string) (map[string]string, error) {
	result := make(map[string]string)
	for _, key := range keys {
		var value string
		err := database.DB.QueryRow("SELECT value FROM app_settings WHERE key = $1", key).Scan(&value)
		if err != nil {
			result[key] = ""
		} else {
			result[key] = value
		}
	}
	return result, nil
}

func GetSetting(key string) (string, error) {
	var value string
	err := database.DB.QueryRow("SELECT value FROM app_settings WHERE key = $1", key).Scan(&value)
	if err != nil {
		return "", err
	}
	return value, nil
}

func UpdateSettings(settings map[string]string) error {
	for key, value := range settings {
		_, err := database.DB.Exec(
			"INSERT INTO app_settings (key, value, updated_at) VALUES ($1, $2, $3) ON CONFLICT (key) DO UPDATE SET value = $2, updated_at = $3",
			key, value, time.Now().UTC(),
		)
		if err != nil {
			return fmt.Errorf("failed to update setting %s: %w", key, err)
		}
	}
	return nil
}

func GetCompanyIdentity() (models.CompanyIdentity, error) {
	keys := []string{"company_name", "company_address", "company_phone", "company_email", "company_tax_id", "company_logo_url"}
	settings, err := GetSettingsByKeys(keys)
	if err != nil {
		return models.CompanyIdentity{}, err
	}
	return models.CompanyIdentity{
		CompanyName:    settings["company_name"],
		CompanyAddress: settings["company_address"],
		CompanyPhone:   settings["company_phone"],
		CompanyEmail:   settings["company_email"],
		CompanyTaxID:   settings["company_tax_id"],
		CompanyLogoURL: settings["company_logo_url"],
	}, nil
}

func UpdateCompanyIdentity(data models.CompanyIdentity) error {
	settings := map[string]string{
		"company_name":     data.CompanyName,
		"company_address":  data.CompanyAddress,
		"company_phone":    data.CompanyPhone,
		"company_email":    data.CompanyEmail,
		"company_tax_id":   data.CompanyTaxID,
		"company_logo_url": data.CompanyLogoURL,
	}
	return UpdateSettings(settings)
}

func GetTimezone() (string, error) {
	tz, err := GetSetting("timezone")
	if err != nil {
		return "Asia/Jakarta", nil
	}
	return tz, nil
}

// GetTimezoneLocation returns the *time.Location for the configured timezone.
// Used by handlers/services that need to compute "today" or format times in the user's timezone.
func GetTimezoneLocation() *time.Location {
	tz, _ := GetTimezone()
	loc, err := time.LoadLocation(tz)
	if err != nil {
		loc, _ = time.LoadLocation("Asia/Jakarta")
	}
	return loc
}

func UpdateTimezone(tz string) error {
	// Validate timezone by trying to load it
	if _, err := time.LoadLocation(tz); err != nil {
		return fmt.Errorf("zona waktu tidak valid: %s", tz)
	}
	return UpdateSettings(map[string]string{"timezone": tz})
}

func GetAvailableTimezones() []map[string]string {
	tzList := []struct {
		Value string
		Label string
	}{
		{"Asia/Jakarta", "WIB - Asia/Jakarta (UTC+7)"},
		{"Asia/Pontianak", "WIB - Asia/Pontianak (UTC+7)"},
		{"Asia/Makassar", "WITA - Asia/Makassar (UTC+8)"},
		{"Asia/Jayapura", "WIT - Asia/Jayapura (UTC+9)"},
		{"Asia/Singapore", "Asia/Singapore (UTC+8)"},
		{"Asia/Kuala_Lumpur", "Asia/Kuala Lumpur (UTC+8)"},
		{"Asia/Bangkok", "Asia/Bangkok (UTC+7)"},
		{"Asia/Tokyo", "Asia/Tokyo (UTC+9)"},
		{"Asia/Seoul", "Asia/Seoul (UTC+9)"},
		{"Asia/Shanghai", "Asia/Shanghai (UTC+8)"},
		{"Asia/Kolkata", "Asia/Kolkata (UTC+5:30)"},
		{"Asia/Dubai", "Asia/Dubai (UTC+4)"},
		{"Europe/London", "Europe/London (UTC+0/+1)"},
		{"Europe/Paris", "Europe/Paris (UTC+1/+2)"},
		{"Europe/Berlin", "Europe/Berlin (UTC+1/+2)"},
		{"America/New_York", "America/New York (UTC-5/-4)"},
		{"America/Chicago", "America/Chicago (UTC-6/-5)"},
		{"America/Los_Angeles", "America/Los Angeles (UTC-8/-7)"},
		{"Australia/Sydney", "Australia/Sydney (UTC+10/+11)"},
		{"Pacific/Auckland", "Pacific/Auckland (UTC+12/+13)"},
		{"UTC", "UTC (UTC+0)"},
	}

	result := make([]map[string]string, len(tzList))
	for i, tz := range tzList {
		result[i] = map[string]string{
			"value": tz.Value,
			"label": tz.Label,
		}
	}
	return result
}

// ── Tax Settings ────────────────────────────────────────────

func GetTaxSettings() (models.TaxSettings, error) {
	keys := []string{"tax_enabled", "tax_rate", "tax_name"}
	settings, err := GetSettingsByKeys(keys)
	if err != nil {
		return models.TaxSettings{}, err
	}
	rate := 10.0
	if v := settings["tax_rate"]; v != "" {
		if parsed, err := strconv.ParseFloat(v, 64); err == nil {
			rate = parsed
		}
	}
	return models.TaxSettings{
		TaxEnabled: settings["tax_enabled"] == "true",
		TaxRate:    rate,
		TaxName:    settings["tax_name"],
	}, nil
}

func UpdateTaxSettings(data models.TaxSettings) error {
	if data.TaxRate < 0 || data.TaxRate > 100 {
		return fmt.Errorf("tarif pajak harus antara 0-100%%")
	}
	if data.TaxName == "" {
		data.TaxName = "Pajak Restoran (PB1)"
	}
	enabledStr := "false"
	if data.TaxEnabled {
		enabledStr = "true"
	}
	return UpdateSettings(map[string]string{
		"tax_enabled": enabledStr,
		"tax_rate":    strconv.FormatFloat(data.TaxRate, 'f', 2, 64),
		"tax_name":    data.TaxName,
	})
}

// GetTaxRate returns the inclusive tax rate as a fraction (e.g., 10/110 for 10% inclusive).
// Returns 0 if tax is disabled.
func GetTaxRate() float64 {
	ts, err := GetTaxSettings()
	if err != nil || !ts.TaxEnabled || ts.TaxRate <= 0 {
		return 0
	}
	return ts.TaxRate / (100 + ts.TaxRate)
}
