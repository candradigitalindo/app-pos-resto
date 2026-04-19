package handlers

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"cloud-pos/models"

	"github.com/gofiber/fiber/v2"
	"github.com/oklog/ulid/v2"
)

func UploadFile(c *fiber.Ctx) error {
	file, err := c.FormFile("file")
	if err != nil {
		return c.Status(400).JSON(models.APIResponse{Success: false, Error: "File tidak ditemukan."})
	}

	// Max 5MB
	if file.Size > 5*1024*1024 {
		return c.Status(400).JSON(models.APIResponse{Success: false, Error: "Ukuran file maksimal 5MB."})
	}

	// Allowed extensions
	ext := strings.ToLower(filepath.Ext(file.Filename))
	allowed := map[string]bool{".jpg": true, ".jpeg": true, ".png": true, ".pdf": true, ".webp": true}
	if !allowed[ext] {
		return c.Status(400).JSON(models.APIResponse{Success: false, Error: "Format file tidak didukung. Gunakan JPG, PNG, PDF, atau WebP."})
	}

	// Ensure uploads directory exists
	uploadDir := "uploads"
	if err := os.MkdirAll(uploadDir, 0755); err != nil {
		return c.Status(500).JSON(models.APIResponse{Success: false, Error: "Gagal menyiapkan folder upload."})
	}

	// Generate unique filename
	id := ulid.Make().String()
	datePath := time.Now().Format("2006-01")
	dir := filepath.Join(uploadDir, datePath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return c.Status(500).JSON(models.APIResponse{Success: false, Error: "Gagal menyiapkan folder upload."})
	}

	filename := fmt.Sprintf("%s%s", id, ext)
	savePath := filepath.Join(dir, filename)

	if err := c.SaveFile(file, savePath); err != nil {
		return c.Status(500).JSON(models.APIResponse{Success: false, Error: "Gagal menyimpan file."})
	}

	url := fmt.Sprintf("/uploads/%s/%s", datePath, filename)
	return c.JSON(models.APIResponse{
		Success: true,
		Data: fiber.Map{
			"url":      url,
			"filename": file.Filename,
		},
	})
}
