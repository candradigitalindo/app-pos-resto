/**
 * src/api/admins.js — Admin user management API calls
 *
 * Endpoints used:
 *   GET  /admin/admins
 *   POST /admin/admins
 *
 * AI NOTE: To add edit/delete admin endpoints, first implement them in
 * the Go handlers (cloud-pos/handlers/handlers.go) then add
 * the corresponding calls here.
 */

import { apiClient } from './client.js'

export const adminsApi = {
  /** List all admin users */
  list: () =>
    apiClient.get('/admin/admins'),

  /**
   * Create a new admin user.
   * @param {{ username: string, password: string, name: string, role?: string }} payload
   */
  create: (payload) =>
    apiClient.post('/admin/admins', payload),
}
