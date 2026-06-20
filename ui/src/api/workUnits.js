import { apiClient } from './client.js'

export const workUnitsApi = {
  list: () =>
    apiClient.get('/admin/work-units'),

  /** Scope-filtered work units for dropdown (requires procurement.view) */
  myWorkUnits: () =>
    apiClient.get('/admin/my-work-units'),

  get: (id) =>
    apiClient.get(`/admin/work-units/${id}`),

  getMyWorkUnit: () =>
    apiClient.get('/admin/work-units/me'),

  create: (data) =>
    apiClient.post('/admin/work-units', data),

  update: (id, data) =>
    apiClient.put(`/admin/work-units/${id}`, data),

  remove: (id) =>
    apiClient.delete(`/admin/work-units/${id}`),
}
