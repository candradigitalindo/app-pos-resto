package models

// AccessLog records a login/access event (visible to superadmin only).
type AccessLog struct {
	ID        string `json:"id"`
	Username  string `json:"username"`
	Role      string `json:"role"`
	Status    string `json:"status"` // success | failed
	IP        string `json:"ip"`
	UserAgent string `json:"user_agent"`
	Browser   string `json:"browser"`
	OS        string `json:"os"`
	Device    string `json:"device"`
	CreatedAt string `json:"created_at"`
}
