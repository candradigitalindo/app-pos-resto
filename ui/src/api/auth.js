/**
 * src/api/auth.js — Authentication API calls
 *
 * Endpoints used:
 *   POST /api/v1/admin/login
 *
 * Returns: { token: string, admin: AdminObject }
 *
 * AI NOTE: To add refresh token, add a `refreshToken(token)` export
 * that calls POST /api/v1/admin/refresh with the current JWT.
 */

import { apiClient } from './client.js'

export const authApi = {
  /**
   * Login an admin user.
   * @param {string} username
   * @param {string} password
   * @returns {Promise<{token: string, admin: object}>}
   */
  login: (username, password) =>
    apiClient.post('/admin/login', { username, password }),

  changePassword: (currentPassword, newPassword) =>
    apiClient.put('/admin/me/password', { current_password: currentPassword, new_password: newPassword }),

  updateProfile: (name) =>
    apiClient.put('/admin/me/profile', { name }),
}
