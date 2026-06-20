package services

import (
	"fmt"
	"strings"

	"cloud-pos/database"
	"cloud-pos/models"
)

// parseUserAgent extracts a friendly browser, OS and device type from a raw UA string.
func parseUserAgent(ua string) (browser, os, device string) {
	u := strings.ToLower(ua)

	switch {
	case strings.Contains(u, "edg/") || strings.Contains(u, "edge"):
		browser = "Edge"
	case strings.Contains(u, "opr/") || strings.Contains(u, "opera"):
		browser = "Opera"
	case strings.Contains(u, "samsungbrowser"):
		browser = "Samsung Internet"
	case strings.Contains(u, "firefox") || strings.Contains(u, "fxios"):
		browser = "Firefox"
	case strings.Contains(u, "chrome") || strings.Contains(u, "crios"):
		browser = "Chrome"
	case strings.Contains(u, "safari"):
		browser = "Safari"
	default:
		browser = "Lainnya"
	}

	switch {
	case strings.Contains(u, "windows"):
		os = "Windows"
	case strings.Contains(u, "android"):
		os = "Android"
	case strings.Contains(u, "iphone") || strings.Contains(u, "ipad") || strings.Contains(u, "ios"):
		os = "iOS"
	case strings.Contains(u, "mac os") || strings.Contains(u, "macintosh"):
		os = "macOS"
	case strings.Contains(u, "linux"):
		os = "Linux"
	default:
		os = "Lainnya"
	}

	switch {
	case strings.Contains(u, "ipad") || strings.Contains(u, "tablet"):
		device = "Tablet"
	case strings.Contains(u, "mobile") || strings.Contains(u, "iphone") || strings.Contains(u, "android"):
		device = "Mobile"
	case ua == "":
		device = "—"
	default:
		device = "Desktop"
	}
	return
}

// RecordLogin saves a login/access event. Best-effort — never blocks login.
func RecordLogin(username, role, status, ip, ua string) {
	browser, os, device := parseUserAgent(ua)
	if len(ua) > 1000 {
		ua = ua[:1000]
	}
	_, _ = database.DB.Exec(`
		INSERT INTO access_logs (id, username, role, status, ip, user_agent, browser, os, device)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
		NewULID(), username, role, status, ip, ua, browser, os, device)
}

// ListAccessLogs returns paginated access logs (newest first) with optional filters.
// dateFrom/dateTo (YYYY-MM-DD) filter by the app-timezone calendar day.
func ListAccessLogs(search, status, dateFrom, dateTo string, page, limit int) ([]models.AccessLog, int, error) {
	where := "WHERE 1=1"
	args := []interface{}{}
	i := 1
	if search != "" {
		where += fmt.Sprintf(" AND (username ILIKE $%d OR ip ILIKE $%d OR role ILIKE $%d)", i, i, i)
		args = append(args, "%"+search+"%")
		i++
	}
	if status != "" {
		where += fmt.Sprintf(" AND status = $%d", i)
		args = append(args, status)
		i++
	}
	if dateFrom != "" {
		where += fmt.Sprintf(" AND tz_date(created_at) >= $%d::date", i)
		args = append(args, dateFrom)
		i++
	}
	if dateTo != "" {
		where += fmt.Sprintf(" AND tz_date(created_at) <= $%d::date", i)
		args = append(args, dateTo)
		i++
	}

	var total int
	if err := database.DB.QueryRow("SELECT COUNT(*) FROM access_logs "+where, args...).Scan(&total); err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * limit
	args = append(args, limit, offset)
	rows, err := database.DB.Query(fmt.Sprintf(`
		SELECT id, username, role, status, ip, user_agent, browser, os, device,
		       TO_CHAR(created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
		FROM access_logs %s
		ORDER BY created_at DESC LIMIT $%d OFFSET $%d`, where, i, i+1), args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	logs := []models.AccessLog{}
	for rows.Next() {
		var l models.AccessLog
		if err := rows.Scan(&l.ID, &l.Username, &l.Role, &l.Status, &l.IP, &l.UserAgent, &l.Browser, &l.OS, &l.Device, &l.CreatedAt); err != nil {
			return nil, 0, err
		}
		logs = append(logs, l)
	}
	return logs, total, nil
}
