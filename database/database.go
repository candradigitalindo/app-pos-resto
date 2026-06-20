package database

import (
	"cloud-pos/config"
	"database/sql"
	"log"
	"time"

	_ "github.com/lib/pq"
)

var DB *sql.DB

func Connect(cfg *config.Config) error {
	var err error
	DB, err = sql.Open("postgres", cfg.DSN())
	if err != nil {
		return err
	}

	DB.SetMaxOpenConns(25)
	DB.SetMaxIdleConns(5)
	DB.SetConnMaxLifetime(5 * time.Minute)

	if err = DB.Ping(); err != nil {
		return err
	}

	log.Println("Connected to PostgreSQL database")
	return nil
}

func Close() {
	if DB != nil {
		DB.Close()
		log.Println("Database connection closed")
	}
}
