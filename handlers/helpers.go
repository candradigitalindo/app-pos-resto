package handlers

import (
	"cloud-pos/database"
	"cloud-pos/services"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
)

// clientIP returns the real client IP, honouring Cloudflare / reverse-proxy headers.
func clientIP(c *fiber.Ctx) string {
	if ip := c.Get("CF-Connecting-IP"); ip != "" {
		return ip
	}
	if xff := c.Get("X-Forwarded-For"); xff != "" {
		if i := strings.IndexByte(xff, ','); i >= 0 {
			return strings.TrimSpace(xff[:i])
		}
		return strings.TrimSpace(xff)
	}
	return c.IP()
}

func getPagination(c *fiber.Ctx) (int, int) {
	page, _ := strconv.Atoi(c.Query("page", "1"))
	limit, _ := strconv.Atoi(c.Query("limit", "20"))

	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}

	return page, limit
}

// validDate validates YYYY-MM-DD format. Returns the validated string or empty on invalid.
func validDate(s string) string {
	_, err := time.Parse("2006-01-02", s)
	if err != nil {
		return ""
	}
	return s
}

// getDateRange extracts and validates date_from/date_to query params, defaults to today
// in the configured app timezone.
func getDateRange(c *fiber.Ctx) (string, string, error) {
	loc := services.GetTimezoneLocation()
	today := time.Now().In(loc).Format("2006-01-02")
	dateFrom := c.Query("date_from", today)
	dateTo := c.Query("date_to", today)

	if validDate(dateFrom) == "" || validDate(dateTo) == "" {
		return "", "", fmt.Errorf("format tanggal tidak valid, gunakan YYYY-MM-DD")
	}
	if dateFrom > dateTo {
		return "", "", fmt.Errorf("date_from tidak boleh lebih besar dari date_to")
	}
	return dateFrom, dateTo, nil
}

// getAppTimezone returns the IANA timezone string from app settings for use in SQL queries.
func getAppTimezone() string {
	tz, _ := services.GetTimezone()
	return tz
}

// scopeNoneSentinel is a non-existent ID used when a role has "specific" scope but
// resolves to an EMPTY allow-list. Returning it (instead of nil) forces every query
// — regardless of whether a service gates on `!= nil` or `len() > 0` — to apply the
// filter and match nothing, so a restricted role can never accidentally see all data.
// A real ULID is 26 uppercase chars, so "__none__" can never collide.
const scopeNoneSentinel = "__none__"

// getOutletScope extracts the outlet scope from the Fiber context.
// Returns nil for "all" scope (no restriction); []string of allowed outlet IDs for
// "specific"; or [sentinel] when "specific" resolves to no outlets (match nothing).
func getOutletScope(c *fiber.Ctx) []string {
	scope, _ := c.Locals("admin_scope").(string)
	if scope != "specific" {
		return nil
	}
	ids, _ := c.Locals("admin_outlet_ids").([]string)
	if len(ids) == 0 {
		return []string{scopeNoneSentinel}
	}
	return ids
}

// getWorkUnitScope extracts the work unit scope from the Fiber context.
// Returns nil for "all" scope (no restriction); []string of allowed work unit IDs for
// "specific"; or [sentinel] when "specific" resolves to no work units (match nothing).
func getWorkUnitScope(c *fiber.Ctx) []string {
	scope, _ := c.Locals("admin_scope").(string)
	if scope != "specific" {
		return nil
	}
	ids, _ := c.Locals("admin_work_unit_ids").([]string)
	if len(ids) == 0 {
		return []string{scopeNoneSentinel}
	}
	return ids
}

// validateOutletAccess checks if the given outletID is accessible under the current scope.
// For "all" scope, always returns true.
// For "specific" scope, returns true only if outletID is in the allowed list.
func validateOutletAccess(c *fiber.Ctx, outletID string) bool {
	ids := getOutletScope(c)
	if ids == nil {
		return true // all scope
	}
	for _, id := range ids {
		if id == outletID {
			return true
		}
	}
	return false
}

// applyOutletScope validates the outlet_id query param against the admin's scope.
// If outletID is provided, it must be in scope. If empty and scope is "specific",
// the scope outlet IDs are returned to filter queries.
// Returns (outletID, scopeIDs, error).
func applyOutletScope(c *fiber.Ctx, outletID string) (string, []string, error) {
	ids := getOutletScope(c)
	if ids == nil {
		// All scope — no restriction
		return outletID, nil, nil
	}

	// Specific scope
	if outletID != "" {
		// Validate specific outlet access
		for _, id := range ids {
			if id == outletID {
				return outletID, nil, nil
			}
		}
		return "", nil, fmt.Errorf("akses outlet tidak diizinkan")
	}

	// No outlet specified — return all scoped outlets
	return "", ids, nil
}

// validateWorkUnitAccess checks if the given workUnitID is accessible under the current scope.
// For "all" scope, always returns true.
// For "specific" scope, returns true only if workUnitID is in the allowed list.
func validateWorkUnitAccess(c *fiber.Ctx, workUnitID string) bool {
	ids := getWorkUnitScope(c)
	if ids == nil {
		return true // all scope
	}
	for _, id := range ids {
		if id == workUnitID {
			return true
		}
	}
	return false
}

// validatePurchaseRequestScope checks if a purchase request (by ID) is accessible
// under the current admin's scope. Returns true if access is allowed.
func validatePurchaseRequestScope(c *fiber.Ctx, prID string) bool {
	outletScope := getOutletScope(c)
	wuScope := getWorkUnitScope(c)
	if outletScope == nil && wuScope == nil {
		return true // all scope
	}

	var outletID, workUnitID *string
	err := database.DB.QueryRow(
		"SELECT outlet_id, work_unit_id FROM purchase_requests WHERE id = $1", prID,
	).Scan(&outletID, &workUnitID)
	if err != nil {
		return false
	}

	// Check outlet scope
	if outletID != nil && outletScope != nil {
		for _, id := range outletScope {
			if id == *outletID {
				return true
			}
		}
	}
	// Check work unit scope
	if workUnitID != nil && wuScope != nil {
		for _, id := range wuScope {
			if id == *workUnitID {
				return true
			}
		}
	}

	return false
}
