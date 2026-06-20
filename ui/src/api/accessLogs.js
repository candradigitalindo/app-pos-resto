import { apiClient } from './client.js'

export const accessLogsApi = {
  list: (params = {}) => apiClient.get('/admin/access-logs', { params }),
}
