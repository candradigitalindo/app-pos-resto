package models

import "time"

// WorkUnit represents a procurement work unit, auto-created from each outlet or standalone.
type WorkUnit struct {
	ID         string    `json:"id"`
	OutletID   *string   `json:"outlet_id"`
	OutletName *string   `json:"outlet_name,omitempty"`
	Name       string    `json:"name"`
	AdminID    *string   `json:"admin_id"`
	AdminName  *string   `json:"admin_name,omitempty"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

// CreateWorkUnitRequest is the payload for creating a standalone work unit.
type CreateWorkUnitRequest struct {
	Name string `json:"name"`
}

// UpdateWorkUnitRequest is the payload for updating a work unit's procurement user.
type UpdateWorkUnitRequest struct {
	AdminID *string `json:"admin_id"`
}
