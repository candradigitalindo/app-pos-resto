package middleware

import (
	"backend/internal/db"
	"context"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/labstack/echo/v5"
)

// APIResponse struktur standar untuk response
type APIResponse struct {
	Success bool        `json:"success"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

// errorResponse helper untuk response error
func errorResponse(c *echo.Context, status int, message string) error {
	return c.JSON(status, APIResponse{
		Success: false,
		Message: message,
		Data:    nil,
	})
}

type JWTClaims struct {
	UserID   string `json:"user_id"`
	Username string `json:"username"`
	Role     string `json:"role"`
	jwt.RegisteredClaims
}

const (
	UserContextKey = "user"
)

var (
	jwtSecret = []byte(getJWTSecret())
)

func getJWTSecret() string {
	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		secret = "default-secret-change-in-production"
	}
	return secret
}

// GenerateToken generates JWT token for authenticated user
func GenerateToken(user *db.User) (string, error) {
	claims := JWTClaims{
		UserID:   user.ID,
		Username: user.Username,
		Role:     user.Role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(jwtSecret)
}

// JWTMiddleware validates JWT token
func JWTMiddleware() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c *echo.Context) error {
			authHeader := c.Request().Header.Get("Authorization")
			if authHeader == "" {
				return errorResponse(c, http.StatusUnauthorized, "Authorization header tidak ditemukan")
			}

			tokenString := strings.TrimPrefix(authHeader, "Bearer ")
			if tokenString == authHeader {
				return errorResponse(c, http.StatusUnauthorized, "Format authorization tidak valid, gunakan 'Bearer <token>'")
			}

			token, err := jwt.ParseWithClaims(tokenString, &JWTClaims{}, func(token *jwt.Token) (interface{}, error) {
				if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
					return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
				}
				return jwtSecret, nil
			})

			if err != nil {
				return errorResponse(c, http.StatusUnauthorized, "Token tidak valid: "+err.Error())
			}

			if claims, ok := token.Claims.(*JWTClaims); ok && token.Valid {
				ctx := context.WithValue(c.Request().Context(), UserContextKey, claims)
				c.SetRequest(c.Request().WithContext(ctx))
				return next(c)
			}

			return errorResponse(c, http.StatusUnauthorized, "Token claims tidak valid")
		}
	}
}

// RoleMiddleware checks if user has required role
func RoleMiddleware(allowedRoles ...string) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c *echo.Context) error {
			claims, ok := c.Request().Context().Value(UserContextKey).(*JWTClaims)
			if !ok {
				return errorResponse(c, http.StatusUnauthorized, "User tidak terautentikasi")
			}

			for _, role := range allowedRoles {
				if claims.Role == role {
					return next(c)
				}
			}

			return errorResponse(c, http.StatusForbidden, fmt.Sprintf("Akses ditolak. Role yang diizinkan: %v, role Anda: %s", allowedRoles, claims.Role))
		}
	}
}

// GetUserFromContext retrieves user claims from context
func GetUserFromContext(c *echo.Context) (*JWTClaims, error) {
	claims, ok := c.Request().Context().Value(UserContextKey).(*JWTClaims)
	if !ok {
		return nil, fmt.Errorf("user not found in context")
	}
	return claims, nil
}

func ParseJWTClaims(tokenString string) (*JWTClaims, error) {
	if tokenString == "" {
		return nil, fmt.Errorf("token kosong")
	}

	token, err := jwt.ParseWithClaims(tokenString, &JWTClaims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return jwtSecret, nil
	})
	if err != nil {
		return nil, err
	}

	claims, ok := token.Claims.(*JWTClaims)
	if !ok || !token.Valid {
		return nil, fmt.Errorf("token claims tidak valid")
	}
	return claims, nil
}

// Convenience middleware untuk role-specific access

// AdminOnly - hanya admin yang bisa akses
func AdminOnly() echo.MiddlewareFunc {
	return RoleMiddleware("admin")
}

// Kombinasi role yang sering digunakan

// WaiterOrAdmin - waiter atau admin
func WaiterOrAdmin() echo.MiddlewareFunc {
	return RoleMiddleware("waiter", "admin")
}

// CashierOrAdmin - cashier atau admin
func CashierOrAdmin() echo.MiddlewareFunc {
	return RoleMiddleware("cashier", "admin")
}

// ManagerOrAdmin - manager atau admin
func ManagerOrAdmin() echo.MiddlewareFunc {
	return RoleMiddleware("manager", "admin")
}

// KitchenBarOrAdmin - kitchen, bar, atau admin
func KitchenBarOrAdmin() echo.MiddlewareFunc {
	return RoleMiddleware("kitchen", "bar", "admin")
}

// WaiterManagerOrAdmin - waiter, manager, atau admin
func WaiterManagerOrAdmin() echo.MiddlewareFunc {
	return RoleMiddleware("waiter", "manager", "admin")
}

// CashierManagerOrAdmin - cashier, manager, atau admin
func CashierManagerOrAdmin() echo.MiddlewareFunc {
	return RoleMiddleware("cashier", "manager", "admin")
}
