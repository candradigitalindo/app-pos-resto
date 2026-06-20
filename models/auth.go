package models

import "time"

type CloudAdmin struct {
	ID          string     `json:"id"`
	Username    string     `json:"username"`
	Password    string     `json:"-"`
	Name        string     `json:"name"`
	Role        string     `json:"role"`
	IsActive    bool       `json:"is_active"`
	LastLoginAt *time.Time `json:"last_login_at"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
}

type AdminLoginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type AdminLoginResponse struct {
	Token          string     `json:"token"`
	Admin          CloudAdmin `json:"admin"`
	Permissions    []string   `json:"permissions"`
	ScopeType      string     `json:"scope_type"`
	ScopeOutletIDs []string   `json:"scope_outlet_ids"`
	RedirectTo     string     `json:"redirect_to"`
}

type CreateAdminRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
	Name     string `json:"name"`
	Role     string `json:"role"`
}

type UpdateAdminRoleRequest struct {
	Role string `json:"role"`
}

type UpdateRolePermissionsRequest struct {
	Permissions []string `json:"permissions"`
}

type Role struct {
	Name        string    `json:"name"`
	Description string    `json:"description"`
	IsSystem    bool      `json:"is_system"`
	ScopeType   string    `json:"scope_type"`
	RedirectTo  string    `json:"redirect_to"`
	CreatedAt   time.Time `json:"created_at"`
}

type CreateRoleRequest struct {
	Name        string   `json:"name"`
	Description string   `json:"description"`
	Permissions []string `json:"permissions"`
	ScopeType   string   `json:"scope_type"`
	WorkUnitIDs []string `json:"work_unit_ids"`
	RedirectTo  string   `json:"redirect_to"`
}

type UpdateRoleScopeRequest struct {
	ScopeType   string   `json:"scope_type"`
	WorkUnitIDs []string `json:"work_unit_ids"`
}

type UpdateRoleRequest struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	RedirectTo  string `json:"redirect_to"`
}

type ChangePasswordRequest struct {
	CurrentPassword string `json:"current_password"`
	NewPassword     string `json:"new_password"`
}

type UpdateProfileRequest struct {
	Name string `json:"name"`
}

type UpdateAdminRequest struct {
	Name string `json:"name"`
	Role string `json:"role"`
}

type ResetAdminPasswordRequest struct {
	NewPassword string `json:"new_password"`
}

type RoleScopeInfo struct {
	ScopeType   string   `json:"scope_type"`
	WorkUnitIDs []string `json:"work_unit_ids"`
}
