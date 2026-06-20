/**
 * src/api/outlets.js — Outlet management API calls
 *
 * Admin endpoints (require admin JWT):
 *   GET    /admin/outlets
 *   POST   /admin/outlets
 *   GET    /admin/outlets/:id
 *   POST   /admin/outlets/:id/toggle
 *   POST   /admin/outlets/:id/regenerate-key
 *
 * AI NOTE: All functions return the unwrapped data object from the API.
 * Pagination is currently not supported by the outlet list endpoint.
 */

import { apiClient } from './client.js'

export const outletsApi = {
  /** Fetch all outlets (requires outlets.view permission) */
  list: (params = {}) =>
    apiClient.get('/admin/outlets', { params }),

  /** Fetch outlets accessible to the current user based on scope (no permission required) */
  myOutlets: () =>
    apiClient.get('/admin/my-outlets'),

  /** Update outlet details (name, address, phone, webhook_url) */
  update: (id, payload) =>
    apiClient.put(`/admin/outlets/${id}`, payload),

  /** Get a single outlet by id */
  get: (id) =>
    apiClient.get(`/admin/outlets/${id}`),

  /**
   * Create a new outlet.
   * @param {{ code: string, name: string, address?: string, webhook_url?: string }} payload
   */
  create: (payload) =>
    apiClient.post('/admin/outlets', payload),

  /** Toggle outlet active/inactive */
  toggle: (id) =>
    apiClient.post(`/admin/outlets/${id}/toggle`),

  /** Regenerate API key for outlet */
  regenerateKey: (id) =>
    apiClient.post(`/admin/outlets/${id}/regenerate-key`),

  /** Delete an outlet and all its related data */
  delete: (id) =>
    apiClient.delete(`/admin/outlets/${id}`),

  // ── Outlet-scoped data (requires outlet API key in token — handled by apiClient) ──

  /** Get dashboard stats for a specific outlet's sync data */
  getOrders: (outletId, params = {}) =>
    apiClient.get(`/outlets/${outletId}/orders`, { params }),

  getTransactions: (outletId, params = {}) =>
    apiClient.get(`/outlets/${outletId}/transactions`, { params }),

  getProducts: (outletId, params = {}) =>
    apiClient.get(`/outlets/${outletId}/products`, { params }),

  getCategories: (outletId) =>
    apiClient.get(`/outlets/${outletId}/categories`),

  getPrinters: (outletId) =>
    apiClient.get(`/outlets/${outletId}/printers`),

  updateCategoryPrinter: (outletId, categoryId, printerId) =>
    apiClient.put(`/outlets/${outletId}/categories/${categoryId}/printer`, { printer_id: printerId }),

  getSyncLogs: (outletId, params = {}) =>
    apiClient.get(`/outlets/${outletId}/sync/logs`, { params }),

  getConflicts: (outletId) =>
    apiClient.get(`/outlets/${outletId}/conflicts`),

  resolveConflict: (outletId, conflictId, payload) =>
    apiClient.post(`/outlets/${outletId}/conflicts/${conflictId}/resolve`, payload),

  /** Get procurement dashboard stats for an outlet */
  getProcurementDashboard: (outletId) =>
    apiClient.get(`/admin/outlets/${outletId}/procurement-dashboard`),
}
