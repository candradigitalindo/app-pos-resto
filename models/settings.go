package models

import "time"

type AppSetting struct {
	Key       string    `json:"key"`
	Value     string    `json:"value"`
	UpdatedAt time.Time `json:"updated_at"`
}

type UpdateSettingsRequest struct {
	Settings map[string]string `json:"settings"`
}

type CompanyIdentity struct {
	CompanyName    string `json:"company_name"`
	CompanyAddress string `json:"company_address"`
	CompanyPhone   string `json:"company_phone"`
	CompanyEmail   string `json:"company_email"`
	CompanyTaxID   string `json:"company_tax_id"`
	CompanyLogoURL string `json:"company_logo_url"`
}

type TimezoneSettings struct {
	Timezone string `json:"timezone"`
}

type TaxSettings struct {
	TaxEnabled bool    `json:"tax_enabled"`
	TaxRate    float64 `json:"tax_rate"`
	TaxName    string  `json:"tax_name"`
}
