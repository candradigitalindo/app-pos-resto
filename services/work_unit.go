package services

import (
	"cloud-pos/database"
	"cloud-pos/models"
	"database/sql"
	"fmt"

	"github.com/lib/pq"
)

func ListWorkUnits(wuScopeIDs []string) ([]models.WorkUnit, error) {
	where := ""
	var args []interface{}
	if wuScopeIDs != nil {
		if len(wuScopeIDs) == 0 {
			return []models.WorkUnit{}, nil
		}
		where = "WHERE wu.id = ANY($1::text[])"
		args = append(args, pq.Array(wuScopeIDs))
	}

	rows, err := database.DB.Query(fmt.Sprintf(`
		SELECT wu.id, wu.outlet_id, o.name, wu.name, wu.admin_id, ca.name,
		       wu.created_at, wu.updated_at
		FROM work_units wu
		LEFT JOIN outlets o ON o.id = wu.outlet_id
		LEFT JOIN cloud_admins ca ON ca.id = wu.admin_id
		%s
		ORDER BY wu.name ASC
	`, where), args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	units := make([]models.WorkUnit, 0)
	for rows.Next() {
		var wu models.WorkUnit
		if err := rows.Scan(&wu.ID, &wu.OutletID, &wu.OutletName, &wu.Name,
			&wu.AdminID, &wu.AdminName, &wu.CreatedAt, &wu.UpdatedAt); err != nil {
			return nil, err
		}
		units = append(units, wu)
	}
	return units, rows.Err()
}

func GetWorkUnit(id string) (*models.WorkUnit, error) {
	var wu models.WorkUnit
	err := database.DB.QueryRow(`
		SELECT wu.id, wu.outlet_id, o.name, wu.name, wu.admin_id, ca.name,
		       wu.created_at, wu.updated_at
		FROM work_units wu
		LEFT JOIN outlets o ON o.id = wu.outlet_id
		LEFT JOIN cloud_admins ca ON ca.id = wu.admin_id
		WHERE wu.id = $1
	`, id).Scan(&wu.ID, &wu.OutletID, &wu.OutletName, &wu.Name,
		&wu.AdminID, &wu.AdminName, &wu.CreatedAt, &wu.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &wu, nil
}

func GetWorkUnitByAdminID(adminID string) (*models.WorkUnit, error) {
	var wu models.WorkUnit
	err := database.DB.QueryRow(`
		SELECT wu.id, wu.outlet_id, o.name, wu.name, wu.admin_id, ca.name,
		       wu.created_at, wu.updated_at
		FROM work_units wu
		LEFT JOIN outlets o ON o.id = wu.outlet_id
		LEFT JOIN cloud_admins ca ON ca.id = wu.admin_id
		WHERE wu.admin_id = $1
	`, adminID).Scan(&wu.ID, &wu.OutletID, &wu.OutletName, &wu.Name,
		&wu.AdminID, &wu.AdminName, &wu.CreatedAt, &wu.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &wu, nil
}

func UpdateWorkUnit(id string, req models.UpdateWorkUnitRequest) (*models.WorkUnit, error) {
	// If assigning an admin, make sure they are not already assigned to another work unit
	if req.AdminID != nil && *req.AdminID != "" {
		var existing string
		err := database.DB.QueryRow(
			`SELECT id FROM work_units WHERE admin_id = $1 AND id != $2`, *req.AdminID, id,
		).Scan(&existing)
		if err == nil {
			return nil, fmt.Errorf("user sudah ditugaskan ke unit kerja lain")
		}
	}

	if req.AdminID != nil && *req.AdminID == "" {
		req.AdminID = nil
	}

	_, err := database.DB.Exec(`
		UPDATE work_units SET admin_id = $1, updated_at = NOW() WHERE id = $2
	`, req.AdminID, id)
	if err != nil {
		return nil, err
	}
	return GetWorkUnit(id)
}

func CreateWorkUnitForOutlet(outletID, outletName string) error {
	id := NewULID()
	_, err := database.DB.Exec(`
		INSERT INTO work_units (id, outlet_id, name, created_at, updated_at)
		VALUES ($1, $2, $3, NOW(), NOW())
		ON CONFLICT (outlet_id) DO NOTHING
	`, id, outletID, outletName)
	return err
}

func GetWorkUnitByOutletID(outletID string) (*models.WorkUnit, error) {
	var wu models.WorkUnit
	err := database.DB.QueryRow(`
		SELECT wu.id, wu.outlet_id, o.name, wu.name, wu.admin_id, ca.name,
		       wu.created_at, wu.updated_at
		FROM work_units wu
		LEFT JOIN outlets o ON o.id = wu.outlet_id
		LEFT JOIN cloud_admins ca ON ca.id = wu.admin_id
		WHERE wu.outlet_id = $1
	`, outletID).Scan(&wu.ID, &wu.OutletID, &wu.OutletName, &wu.Name,
		&wu.AdminID, &wu.AdminName, &wu.CreatedAt, &wu.UpdatedAt)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &wu, nil
}

func CreateWorkUnit(req models.CreateWorkUnitRequest) (*models.WorkUnit, error) {
	if req.Name == "" {
		return nil, fmt.Errorf("nama unit kerja wajib diisi")
	}
	id := NewULID()
	_, err := database.DB.Exec(`
		INSERT INTO work_units (id, outlet_id, name, created_at, updated_at)
		VALUES ($1, NULL, $2, NOW(), NOW())
	`, id, req.Name)
	if err != nil {
		return nil, err
	}
	return GetWorkUnit(id)
}

// DeleteWorkUnit removes a standalone work unit. Linked purchase requests have
// their work_unit_id set to NULL via FK ON DELETE SET NULL.
func DeleteWorkUnit(id string) error {
	res, err := database.DB.Exec(`DELETE FROM work_units WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return fmt.Errorf("unit kerja tidak ditemukan")
	}
	return nil
}
