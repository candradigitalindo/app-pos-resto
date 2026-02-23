package handlers

import (
	"backend/internal/db"
	"backend/internal/middleware"
	"crypto/rand"
	"database/sql"
	"net/http"

	"github.com/labstack/echo/v5"
	"github.com/oklog/ulid/v2"
	"golang.org/x/crypto/bcrypt"
)

type AuthHandler struct {
	queries *db.Queries
}

func NewAuthHandler(dbConn *sql.DB) *AuthHandler {
	return &AuthHandler{
		queries: db.New(dbConn),
	}
}

type RegisterRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
	FullName string `json:"full_name"`
	Role     string `json:"role"`
}

type LoginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type UpdateProfileRequest struct {
	Username    string `json:"username"`
	FullName    string `json:"full_name"`
	OldPassword string `json:"old_password,omitempty"`
	NewPassword string `json:"new_password,omitempty"`
}

type UpdateUserRequest struct {
	Username string `json:"username"`
	FullName string `json:"full_name"`
	Role     string `json:"role"`
	Password string `json:"password"`
	IsActive *bool  `json:"is_active"`
}

type UserResponse struct {
	ID        string `json:"id"`
	Username  string `json:"username"`
	FullName  string `json:"full_name"`
	Role      string `json:"role"`
	IsActive  int64  `json:"is_active"`
	CreatedAt string `json:"created_at"`
	UpdatedAt string `json:"updated_at"`
}

type AuthResponse struct {
	Token string        `json:"token"`
	User  *UserResponse `json:"user"`
}

// toUserResponse converts db.User to UserResponse (hides password_hash)
func toUserResponse(user *db.User) *UserResponse {
	return &UserResponse{
		ID:        user.ID,
		Username:  user.Username,
		FullName:  user.FullName,
		Role:      user.Role,
		IsActive:  user.IsActive,
		CreatedAt: user.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
		UpdatedAt: user.UpdatedAt.Format("2006-01-02T15:04:05Z07:00"),
	}
}

// toUserResponseFromListRow converts db.ListUsersRow to UserResponse (hides password_hash)
func toUserResponseFromListRow(user *db.ListUsersRow) *UserResponse {
	return &UserResponse{
		ID:        user.ID,
		Username:  user.Username,
		FullName:  user.FullName,
		Role:      user.Role,
		IsActive:  user.IsActive,
		CreatedAt: user.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
		UpdatedAt: user.UpdatedAt.Format("2006-01-02T15:04:05Z07:00"),
	}
}

// toUserResponseFromPaginatedRow converts db.ListUsersPaginatedRow to UserResponse (hides password_hash)
func toUserResponseFromPaginatedRow(user *db.ListUsersPaginatedRow) *UserResponse {
	return &UserResponse{
		ID:        user.ID,
		Username:  user.Username,
		FullName:  user.FullName,
		Role:      user.Role,
		IsActive:  user.IsActive,
		CreatedAt: user.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
		UpdatedAt: user.UpdatedAt.Format("2006-01-02T15:04:05Z07:00"),
	}
}

// HandleRegister - Admin only, untuk register user baru
func (h *AuthHandler) HandleRegister(c *echo.Context) error {
	var req RegisterRequest
	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	// Validate
	if req.Username == "" || req.Password == "" || req.FullName == "" {
		return BadRequestResponse(c, "username, PIN, dan full_name wajib diisi")
	}

	// Validate PIN - harus 4 digit angka
	if len(req.Password) != 4 {
		return BadRequestResponse(c, "PIN harus tepat 4 digit")
	}
	for _, char := range req.Password {
		if char < '0' || char > '9' {
			return BadRequestResponse(c, "PIN harus berupa angka")
		}
	}

	// Validate role
	validRoles := map[string]bool{
		"admin": true, "waiter": true, "kitchen": true,
		"bar": true, "cashier": true, "manager": true,
	}
	if !validRoles[req.Role] {
		return BadRequestResponse(c, "Role tidak valid. Role yang tersedia: admin, waiter, kitchen, bar, cashier, manager")
	}

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return InternalErrorResponse(c, "Gagal hash password")
	}

	// Create user
	userID := ulid.MustNew(ulid.Now(), rand.Reader).String()
	user, err := h.queries.CreateUser((*c).Request().Context(), db.CreateUserParams{
		ID:           userID,
		Username:     req.Username,
		PasswordHash: string(hashedPassword),
		FullName:     req.FullName,
		Role:         req.Role,
	})

	if err != nil {
		if err.Error() == "UNIQUE constraint failed: users.username" {
			return ConflictResponse(c, "Username sudah digunakan")
		}
		return InternalErrorResponse(c, "Gagal membuat user: "+err.Error())
	}

	// Generate token
	token, err := middleware.GenerateToken(&user)
	if err != nil {
		return InternalErrorResponse(c, "Gagal generate token")
	}

	return CreatedResponse(c, "User berhasil dibuat", AuthResponse{
		Token: token,
		User:  toUserResponse(&user),
	})
}

// HandleLogin - Public endpoint untuk login
func (h *AuthHandler) HandleLogin(c *echo.Context) error {
	var req LoginRequest
	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	if req.Username == "" || req.Password == "" {
		return BadRequestResponse(c, "username dan PIN wajib diisi")
	}

	// Get user by username
	user, err := h.queries.GetUserByUsername((*c).Request().Context(), req.Username)
	if err != nil {
		if err == sql.ErrNoRows {
			return UnauthorizedResponse(c, "Username atau PIN salah")
		}
		return InternalErrorResponse(c, "Gagal mendapatkan data user")
	}

	// Check if user is active
	if user.IsActive == 0 {
		return ErrorResponse(c, http.StatusForbidden, "Akun user tidak aktif")
	}

	// Verify password
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return UnauthorizedResponse(c, "Username atau PIN salah")
	}

	// Generate token
	token, err := middleware.GenerateToken(&user)
	if err != nil {
		return InternalErrorResponse(c, "Gagal generate token")
	}

	return SuccessResponse(c, "Login berhasil", AuthResponse{
		Token: token,
		User:  toUserResponse(&user),
	})
}

// HandleGetProfile - Get current user profile
func (h *AuthHandler) HandleGetProfile(c *echo.Context) error {
	claims, err := middleware.GetUserFromContext(c)
	if err != nil {
		return UnauthorizedResponse(c, err.Error())
	}

	user, err := h.queries.GetUserByID((*c).Request().Context(), claims.UserID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mendapatkan profil user")
	}

	return SuccessResponse(c, "Profil berhasil diambil", toUserResponse(&user))
}

// HandleUpdateProfile - Update current user profile
func (h *AuthHandler) HandleUpdateProfile(c *echo.Context) error {
	claims, err := middleware.GetUserFromContext(c)
	if err != nil {
		return UnauthorizedResponse(c, err.Error())
	}

	var req UpdateProfileRequest
	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	// Get current user data
	user, err := h.queries.GetUserByID((*c).Request().Context(), claims.UserID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mendapatkan data user")
	}

	// Update username if provided
	if req.Username != "" && req.Username != user.Username {
		// Check if username already exists
		existingUser, err := h.queries.GetUserByUsername((*c).Request().Context(), req.Username)
		if err == nil && existingUser.ID != claims.UserID {
			return BadRequestResponse(c, "Username sudah digunakan")
		}

		if err := h.queries.UpdateUserUsername((*c).Request().Context(), db.UpdateUserUsernameParams{
			ID:       claims.UserID,
			Username: req.Username,
		}); err != nil {
			return InternalErrorResponse(c, "Gagal update username")
		}
	}

	// Update full_name if provided
	if req.FullName != "" {
		if err := h.queries.UpdateUserFullName((*c).Request().Context(), db.UpdateUserFullNameParams{
			ID:       claims.UserID,
			FullName: req.FullName,
		}); err != nil {
			return InternalErrorResponse(c, "Gagal update nama lengkap")
		}
	}

	// Update password if both old and new password provided
	if req.OldPassword != "" || req.NewPassword != "" {
		// Pastikan kedua field diisi
		if req.OldPassword == "" {
			return BadRequestResponse(c, "PIN lama harus diisi untuk mengubah PIN")
		}
		if req.NewPassword == "" {
			return BadRequestResponse(c, "PIN baru harus diisi untuk mengubah PIN")
		}

		// Verify old password
		if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.OldPassword)); err != nil {
			return BadRequestResponse(c, "PIN lama tidak sesuai")
		}

		// Validate new PIN - harus 4 digit angka
		if len(req.NewPassword) != 4 {
			return BadRequestResponse(c, "PIN baru harus tepat 4 digit")
		}
		for _, char := range req.NewPassword {
			if char < '0' || char > '9' {
				return BadRequestResponse(c, "PIN harus berupa angka")
			}
		}

		// Pastikan PIN baru berbeda dengan PIN lama
		if req.OldPassword == req.NewPassword {
			return BadRequestResponse(c, "PIN baru harus berbeda dengan PIN lama")
		}

		// Hash new password
		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
		if err != nil {
			return InternalErrorResponse(c, "Gagal hash password baru")
		}

		// Update password
		if err := h.queries.UpdateUserPassword((*c).Request().Context(), db.UpdateUserPasswordParams{
			ID:           claims.UserID,
			PasswordHash: string(hashedPassword),
		}); err != nil {
			return InternalErrorResponse(c, "Gagal update password")
		}
	}

	// Get updated user data
	updatedUser, err := h.queries.GetUserByID((*c).Request().Context(), claims.UserID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mendapatkan data user terbaru")
	}

	return SuccessResponse(c, "Profil berhasil diperbarui", toUserResponse(&updatedUser))
}

// HandleListUsers - Admin/Manager only
func (h *AuthHandler) HandleListUsers(c *echo.Context) error {
	// Always use pagination (like Laravel)
	params := GetPaginationParams(c)

	users, err := h.queries.ListUsersPaginated((*c).Request().Context(), db.ListUsersPaginatedParams{
		Limit:  int64(params.PageSize),
		Offset: int64(params.Offset),
	})
	if err != nil {
		return InternalErrorResponse(c, "Gagal mendapatkan daftar user")
	}

	// Get total count
	total, err := h.queries.CountUsers((*c).Request().Context())
	if err != nil {
		return InternalErrorResponse(c, "Gagal menghitung total user")
	}

	// Convert to UserResponse to hide password_hash
	userResponses := make([]*UserResponse, len(users))
	for i, user := range users {
		userResponses[i] = toUserResponseFromPaginatedRow(&user)
	}

	pagination := CalculatePagination(params.Page, params.PageSize, total)
	return PaginatedSuccessResponse(c, "Data users berhasil diambil", userResponses, pagination)
}

// HandleGetUser - Admin/Manager only
func (h *AuthHandler) HandleGetUser(c *echo.Context) error {
	userID := (*c).Param("id")
	if userID == "" {
		return BadRequestResponse(c, "User ID tidak valid")
	}

	user, err := h.queries.GetUserByID((*c).Request().Context(), userID)
	if err != nil {
		if err == sql.ErrNoRows {
			return NotFoundResponse(c, "User tidak ditemukan")
		}
		return InternalErrorResponse(c, "Gagal mendapatkan data user")
	}

	return SuccessResponse(c, "Data user berhasil diambil", toUserResponse(&user))
}

// HandleUpdateUser - Admin/Manager only
func (h *AuthHandler) HandleUpdateUser(c *echo.Context) error {
	claims, err := middleware.GetUserFromContext(c)
	if err != nil {
		return UnauthorizedResponse(c, err.Error())
	}

	userID := (*c).Param("id")
	if userID == "" {
		return BadRequestResponse(c, "User ID tidak valid")
	}
	if userID == claims.UserID {
		return BadRequestResponse(c, "Gunakan update profil untuk akun sendiri")
	}

	var req UpdateUserRequest
	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	hasChanges := req.Username != "" || req.FullName != "" || req.Role != "" || req.Password != "" || req.IsActive != nil
	if !hasChanges {
		return BadRequestResponse(c, "Tidak ada data yang diubah")
	}

	_, err = h.queries.GetUserByID((*c).Request().Context(), userID)
	if err != nil {
		if err == sql.ErrNoRows {
			return NotFoundResponse(c, "User tidak ditemukan")
		}
		return InternalErrorResponse(c, "Gagal mendapatkan data user")
	}

	if req.Username != "" {
		existingUser, err := h.queries.GetUserByUsername((*c).Request().Context(), req.Username)
		if err == nil && existingUser.ID != userID {
			return BadRequestResponse(c, "Username sudah digunakan")
		}
		if err := h.queries.UpdateUserUsername((*c).Request().Context(), db.UpdateUserUsernameParams{
			ID:       userID,
			Username: req.Username,
		}); err != nil {
			return InternalErrorResponse(c, "Gagal update username")
		}
	}

	if req.FullName != "" {
		if err := h.queries.UpdateUserFullName((*c).Request().Context(), db.UpdateUserFullNameParams{
			ID:       userID,
			FullName: req.FullName,
		}); err != nil {
			return InternalErrorResponse(c, "Gagal update nama lengkap")
		}
	}

	if req.Role != "" {
		validRoles := map[string]bool{
			"admin": true, "waiter": true, "kitchen": true,
			"bar": true, "cashier": true, "manager": true,
		}
		if !validRoles[req.Role] {
			return BadRequestResponse(c, "Role tidak valid. Role yang tersedia: admin, waiter, kitchen, bar, cashier, manager")
		}
		if err := h.queries.UpdateUserRole((*c).Request().Context(), db.UpdateUserRoleParams{
			ID:   userID,
			Role: req.Role,
		}); err != nil {
			return InternalErrorResponse(c, "Gagal update role user")
		}
	}

	if req.Password != "" {
		if len(req.Password) != 4 {
			return BadRequestResponse(c, "PIN harus tepat 4 digit")
		}
		for _, char := range req.Password {
			if char < '0' || char > '9' {
				return BadRequestResponse(c, "PIN harus berupa angka")
			}
		}
		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			return InternalErrorResponse(c, "Gagal hash password")
		}
		if err := h.queries.UpdateUserPassword((*c).Request().Context(), db.UpdateUserPasswordParams{
			ID:           userID,
			PasswordHash: string(hashedPassword),
		}); err != nil {
			return InternalErrorResponse(c, "Gagal update password")
		}
	}

	if req.IsActive != nil {
		if !*req.IsActive {
			if err := h.queries.DeactivateUser((*c).Request().Context(), userID); err != nil {
				return InternalErrorResponse(c, "Gagal menonaktifkan user")
			}
		} else {
			if err := h.queries.ActivateUser((*c).Request().Context(), userID); err != nil {
				return InternalErrorResponse(c, "Gagal mengaktifkan user")
			}
		}
	}

	updatedUser, err := h.queries.GetUserByID((*c).Request().Context(), userID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mendapatkan data user terbaru")
	}

	return SuccessResponse(c, "User berhasil diperbarui", toUserResponse(&updatedUser))
}

// HandleUpdateUserRole - Admin/Manager only - untuk mengubah role user lain
func (h *AuthHandler) HandleUpdateUserRole(c *echo.Context) error {
	// Get current user from JWT
	claims, err := middleware.GetUserFromContext(c)
	if err != nil {
		return UnauthorizedResponse(c, err.Error())
	}

	// Get user ID from URL parameter
	userID := (*c).Param("id")
	if userID == "" {
		return BadRequestResponse(c, "User ID tidak valid")
	}

	// Prevent user from changing their own role
	if userID == claims.UserID {
		return BadRequestResponse(c, "Tidak dapat mengubah role diri sendiri. Minta admin lain untuk mengubahnya.")
	}

	var req struct {
		Role string `json:"role"`
	}
	if err := (*c).Bind(&req); err != nil {
		return BadRequestResponse(c, "Body request tidak valid")
	}

	// Validate role
	validRoles := map[string]bool{
		"admin": true, "waiter": true, "kitchen": true,
		"bar": true, "cashier": true, "manager": true,
	}
	if !validRoles[req.Role] {
		return BadRequestResponse(c, "Role tidak valid. Role yang tersedia: admin, waiter, kitchen, bar, cashier, manager")
	}

	// Check if user exists
	_, err = h.queries.GetUserByID(c.Request().Context(), userID)
	if err != nil {
		if err == sql.ErrNoRows {
			return NotFoundResponse(c, "User tidak ditemukan")
		}
		return InternalErrorResponse(c, "Gagal mendapatkan data user")
	}

	// Update role
	if err := h.queries.UpdateUserRole((*c).Request().Context(), db.UpdateUserRoleParams{
		ID:   userID,
		Role: req.Role,
	}); err != nil {
		return InternalErrorResponse(c, "Gagal update role user")
	}

	// Get updated user data
	updatedUser, err := h.queries.GetUserByID((*c).Request().Context(), userID)
	if err != nil {
		return InternalErrorResponse(c, "Gagal mendapatkan data user terbaru")
	}

	return SuccessResponse(c, "Role user berhasil diperbarui", toUserResponse(&updatedUser))
}

// HandleDeactivateUser - Admin/Manager only - untuk menonaktifkan user
func (h *AuthHandler) HandleDeactivateUser(c *echo.Context) error {
	// Get current user from JWT
	claims, err := middleware.GetUserFromContext(c)
	if err != nil {
		return UnauthorizedResponse(c, err.Error())
	}

	userID := (*c).Param("id")
	if userID == "" {
		return BadRequestResponse(c, "User ID tidak valid")
	}

	// Prevent user from deactivating themselves
	if userID == claims.UserID {
		return BadRequestResponse(c, "Tidak dapat menonaktifkan akun diri sendiri")
	}

	// Check if user exists
	_, err = h.queries.GetUserByID((*c).Request().Context(), userID)
	if err != nil {
		if err == sql.ErrNoRows {
			return NotFoundResponse(c, "User tidak ditemukan")
		}
		return InternalErrorResponse(c, "Gagal mendapatkan data user")
	}

	// Deactivate user
	if err := h.queries.DeactivateUser((*c).Request().Context(), userID); err != nil {
		return InternalErrorResponse(c, "Gagal menonaktifkan user")
	}

	return SuccessResponse(c, "User berhasil dinonaktifkan", nil)
}

// HandleActivateUser - Admin/Manager only - untuk mengaktifkan kembali user
func (h *AuthHandler) HandleActivateUser(c *echo.Context) error {
	userID := (*c).Param("id")
	if userID == "" {
		return BadRequestResponse(c, "User ID tidak valid")
	}

	// Check if user exists
	_, err := h.queries.GetUserByID((*c).Request().Context(), userID)
	if err != nil {
		if err == sql.ErrNoRows {
			return NotFoundResponse(c, "User tidak ditemukan")
		}
		return InternalErrorResponse(c, "Gagal mendapatkan data user")
	}

	// Activate user
	if err := h.queries.ActivateUser((*c).Request().Context(), userID); err != nil {
		return InternalErrorResponse(c, "Gagal mengaktifkan user")
	}

	return SuccessResponse(c, "User berhasil diaktifkan", nil)
}

// HandleDeleteUser - Admin/Manager only - untuk menonaktifkan user
func (h *AuthHandler) HandleDeleteUser(c *echo.Context) error {
	claims, err := middleware.GetUserFromContext(c)
	if err != nil {
		return UnauthorizedResponse(c, err.Error())
	}

	userID := (*c).Param("id")
	if userID == "" {
		return BadRequestResponse(c, "User ID tidak valid")
	}
	if userID == claims.UserID {
		return BadRequestResponse(c, "Tidak dapat menonaktifkan akun diri sendiri")
	}

	_, err = h.queries.GetUserByID((*c).Request().Context(), userID)
	if err != nil {
		if err == sql.ErrNoRows {
			return NotFoundResponse(c, "User tidak ditemukan")
		}
		return InternalErrorResponse(c, "Gagal mendapatkan data user")
	}

	if err := h.queries.DeactivateUser((*c).Request().Context(), userID); err != nil {
		return InternalErrorResponse(c, "Gagal menonaktifkan user")
	}

	return SuccessResponse(c, "User berhasil dinonaktifkan", nil)
}
