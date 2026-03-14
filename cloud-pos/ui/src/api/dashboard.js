/**
 * src/api/dashboard.js — Dashboard statistics API calls
 *
 * Endpoints used:
 *   GET /admin/dashboard
 *
 * Returns DashboardStats object:
 *   { total_outlets, active_outlets, total_orders,
 *     total_transactions, total_revenue,
 *     today_orders, today_revenue,
 *     total_products, total_sync_logs, pending_conflicts }
 *
 * AI NOTE: To add chart data (e.g. revenue trend), extend the Go
 * GetDashboard handler to query time-series data and return it
 * alongside the existing stats object.
 */

import { apiClient } from './client.js'

export const dashboardApi = {
  /**
   * Returns global dashboard statistics.
   * @param {object} [params]  Optional query params: { date_from, date_to } (YYYY-MM-DD)
   */
  getStats: (params) =>
    apiClient.get('/admin/dashboard', { params }),
}
