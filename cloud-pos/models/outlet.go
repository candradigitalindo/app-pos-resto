package models

import "time"

type Outlet struct {
	ID         string    `json:"id"`
	Code       string    `json:"code"`
	Name       string    `json:"name"`
	Address    string    `json:"address"`
	Phone      string    `json:"phone"`
	APIKey     string    `json:"api_key,omitempty"`
	WebhookURL string    `json:"webhook_url"`
	IsActive   bool      `json:"is_active"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

type CreateOutletRequest struct {
	Code       string `json:"code"`
	Name       string `json:"name"`
	Address    string `json:"address"`
	Phone      string `json:"phone"`
	WebhookURL string `json:"webhook_url"`
}

type UpdateOutletRequest struct {
	Name       string `json:"name"`
	Address    string `json:"address"`
	Phone      string `json:"phone"`
	WebhookURL string `json:"webhook_url"`
}
