package models

import "time"

type PushProductRequest struct {
	LocalID      string  `json:"local_id"`
	OutletID     string  `json:"outlet_id"`
	Name         string  `json:"name"`
	Code         string  `json:"code"`
	Description  string  `json:"description"`
	CategoryID   string  `json:"category_id"`
	CategoryName string  `json:"category_name"`
	Price        float64 `json:"price"`
	Destination  string  `json:"destination"`
	Version      int     `json:"version"`
	UpdatedAt    string  `json:"updated_at"`
}

type CloudProduct struct {
	ID           string    `json:"id"`
	LocalID      string    `json:"local_id"`
	OutletID     string    `json:"outlet_id"`
	OutletName   string    `json:"outlet_name,omitempty"`
	Name         string    `json:"name"`
	Code         string    `json:"code"`
	Description  string    `json:"description"`
	CategoryID   string    `json:"category_id"`
	CategoryName string    `json:"category_name"`
	Price        float64   `json:"price"`
	Destination  string    `json:"destination"`
	IsDeleted    bool      `json:"is_deleted"`
	Version      int       `json:"version"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
	SyncedAt     time.Time `json:"synced_at"`
}

type PushCategoryRequest struct {
	LocalID     string `json:"local_id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	CodePrefix  string `json:"code_prefix"`
	Version     int    `json:"version"`
}

type CloudCategory struct {
	ID         string    `json:"id"`
	LocalID    string    `json:"local_id"`
	OutletID   string    `json:"outlet_id"`
	OutletName string    `json:"outlet_name,omitempty"`
	Name       string    `json:"name"`
	CodePrefix string    `json:"code_prefix"`
	PrinterID  string    `json:"printer_id"`
	IsDeleted  bool      `json:"is_deleted"`
	Version    int       `json:"version"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
	SyncedAt   time.Time `json:"synced_at"`
}

type AdminCreateProductRequest struct {
	OutletID     string  `json:"outlet_id"`
	Name         string  `json:"name"`
	Code         string  `json:"code"`
	Description  string  `json:"description"`
	CategoryID   string  `json:"category_id"`
	CategoryName string  `json:"category_name"`
	Price        float64 `json:"price"`
	Destination  string  `json:"destination"`
}

type AdminUpdateProductRequest struct {
	Name         string  `json:"name"`
	Code         string  `json:"code"`
	Description  string  `json:"description"`
	CategoryID   string  `json:"category_id"`
	CategoryName string  `json:"category_name"`
	Price        float64 `json:"price"`
	Destination  string  `json:"destination"`
}

type AdminCreateCategoryRequest struct {
	OutletID   string `json:"outlet_id"`
	Name       string `json:"name"`
	CodePrefix string `json:"code_prefix"`
}

type AdminUpdateCategoryRequest struct {
	Name       string `json:"name"`
	CodePrefix string `json:"code_prefix"`
}
