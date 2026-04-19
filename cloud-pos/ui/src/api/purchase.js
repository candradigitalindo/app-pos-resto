import { apiClient } from './client.js'

export const purchaseApi = {
  list: (params) =>
    apiClient.get('/admin/purchase-requests', { params }),

  get: (id) =>
    apiClient.get(`/admin/purchase-requests/${id}`),

  create: (data) =>
    apiClient.post('/admin/purchase-requests', data),

  updateStatus: (id, data) =>
    apiClient.put(`/admin/purchase-requests/${id}/status`, data),

  updateItems: (id, data) =>
    apiClient.put(`/admin/purchase-requests/${id}/items`, data),

  splitVendor: (id, data) =>
    apiClient.post(`/admin/purchase-requests/${id}/split`, data),

  delete: (id) =>
    apiClient.delete(`/admin/purchase-requests/${id}`),

  getDashboard: () =>
    apiClient.get('/admin/procurement-dashboard'),

  getPaymentStats: () =>
    apiClient.get('/admin/payment-stats'),

  getPaymentHistories: (id) =>
    apiClient.get(`/admin/purchase-requests/${id}/payment-histories`),
}
