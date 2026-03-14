import { apiClient } from './client.js'

export const unpaidOrdersApi = {
  getReport: (params) =>
    apiClient.get('/admin/unpaid-orders', { params }),
}
