import { apiClient } from './client.js'

export const vendorsApi = {
  list: (params) => apiClient.get('/admin/vendors', { params }),
  get: (id) => apiClient.get(`/admin/vendors/${id}`),
  detail: (id) => apiClient.get(`/admin/vendors/${id}/detail`),
  purchases: (id, params) => apiClient.get(`/admin/vendors/${id}/purchases`, { params }),
  create: (data) => apiClient.post('/admin/vendors', data),
  update: (id, data) => apiClient.put(`/admin/vendors/${id}`, data),
  toggle: (id) => apiClient.post(`/admin/vendors/${id}/toggle`),
  delete: (id) => apiClient.delete(`/admin/vendors/${id}`),
}
