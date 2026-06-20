package services

import (
	"cloud-pos/database"
	"cloud-pos/models"
	"errors"
	"strings"
	"time"

	"github.com/oklog/ulid/v2"
)

func ListBankAccounts() ([]models.BankAccount, error) {
	rows, err := database.DB.Query(`
		SELECT id, bank_name, account_number, account_holder, is_active, created_at, updated_at
		FROM bank_accounts
		ORDER BY is_active DESC, bank_name ASC, created_at DESC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	accounts := make([]models.BankAccount, 0)
	for rows.Next() {
		var a models.BankAccount
		if err := rows.Scan(&a.ID, &a.BankName, &a.AccountNumber, &a.AccountHolder, &a.IsActive, &a.CreatedAt, &a.UpdatedAt); err != nil {
			return nil, err
		}
		accounts = append(accounts, a)
	}
	return accounts, rows.Err()
}

func GetBankAccount(id string) (*models.BankAccount, error) {
	var a models.BankAccount
	err := database.DB.QueryRow(`
		SELECT id, bank_name, account_number, account_holder, is_active, created_at, updated_at
		FROM bank_accounts WHERE id = $1
	`, id).Scan(&a.ID, &a.BankName, &a.AccountNumber, &a.AccountHolder, &a.IsActive, &a.CreatedAt, &a.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &a, nil
}

func CreateBankAccount(req models.CreateBankAccountRequest) (*models.BankAccount, error) {
	req.BankName = strings.TrimSpace(req.BankName)
	req.AccountNumber = strings.TrimSpace(req.AccountNumber)
	req.AccountHolder = strings.TrimSpace(req.AccountHolder)

	if req.BankName == "" || req.AccountNumber == "" || req.AccountHolder == "" {
		return nil, errors.New("bank, nomor rekening, dan atas nama wajib diisi")
	}

	id := ulid.Make().String()
	now := time.Now().UTC()

	_, err := database.DB.Exec(`
		INSERT INTO bank_accounts (id, bank_name, account_number, account_holder, is_active, created_at, updated_at)
		VALUES ($1, $2, $3, $4, true, $5, $5)
	`, id, req.BankName, req.AccountNumber, req.AccountHolder, now)
	if err != nil {
		return nil, err
	}

	return GetBankAccount(id)
}

func UpdateBankAccount(id string, req models.UpdateBankAccountRequest) (*models.BankAccount, error) {
	req.BankName = strings.TrimSpace(req.BankName)
	req.AccountNumber = strings.TrimSpace(req.AccountNumber)
	req.AccountHolder = strings.TrimSpace(req.AccountHolder)

	if req.BankName == "" || req.AccountNumber == "" || req.AccountHolder == "" {
		return nil, errors.New("bank, nomor rekening, dan atas nama wajib diisi")
	}

	now := time.Now().UTC()
	isActive := true
	if req.IsActive != nil {
		isActive = *req.IsActive
	}

	res, err := database.DB.Exec(`
		UPDATE bank_accounts SET bank_name=$1, account_number=$2, account_holder=$3, is_active=$4, updated_at=$5
		WHERE id=$6
	`, req.BankName, req.AccountNumber, req.AccountHolder, isActive, now, id)
	if err != nil {
		return nil, err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return nil, errors.New("rekening tidak ditemukan")
	}

	return GetBankAccount(id)
}

func DeleteBankAccount(id string) error {
	res, err := database.DB.Exec(`DELETE FROM bank_accounts WHERE id=$1`, id)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return errors.New("rekening tidak ditemukan")
	}
	return nil
}
