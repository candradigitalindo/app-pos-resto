import { apiClient } from './client.js'

export const salesApi = {
  getReport: (params) =>
    apiClient.get('/admin/sales-report', { params }),
}
