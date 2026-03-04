package database

import (
	"database/sql"
	"log"

	"golang.org/x/crypto/bcrypt"
)

// SeedAdmin membuat default admin jika belum ada admin di database.
// Default credentials: admin / admin123 (harus diganti setelah login pertama)
func SeedAdmin() error {
	var count int
	err := DB.QueryRow("SELECT COUNT(*) FROM cloud_admins").Scan(&count)
	if err != nil {
		return err
	}

	if count > 0 {
		log.Printf("Admin seeder: %d admin(s) already exist, skipping", count)
		return nil
	}

	// Default admin credentials
	admins := []struct {
		ID       string
		Username string
		Password string
		Name     string
		Role     string
	}{
		{
			ID:       "01ADMIN000SUPERADMIN00001",
			Username: "admin",
			Password: "admin123",
			Name:     "Super Admin",
			Role:     "superadmin",
		},
	}

	for _, a := range admins {
		hash, err := bcrypt.GenerateFromPassword([]byte(a.Password), bcrypt.DefaultCost)
		if err != nil {
			return err
		}

		var existingID string
		err = DB.QueryRow("SELECT id FROM cloud_admins WHERE username = $1", a.Username).Scan(&existingID)
		if err == sql.ErrNoRows {
			_, err = DB.Exec(
				`INSERT INTO cloud_admins (id, username, password_hash, name, role)
				VALUES ($1, $2, $3, $4, $5)`,
				a.ID, a.Username, string(hash), a.Name, a.Role,
			)
			if err != nil {
				log.Printf("Admin seeder: failed to create admin '%s': %v", a.Username, err)
				return err
			}
			log.Printf("Admin seeder: created admin '%s' (role: %s)", a.Username, a.Role)
		} else if err != nil {
			return err
		} else {
			log.Printf("Admin seeder: admin '%s' already exists, skipping", a.Username)
		}
	}

	log.Println("Admin seeder: completed")
	return nil
}
