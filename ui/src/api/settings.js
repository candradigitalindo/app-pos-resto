import { apiClient } from './client.js'

export const settingsApi = {
  getAll:             ()     => apiClient.get('/admin/settings'),
  getCompany:         ()     => apiClient.get('/admin/settings/company'),
  updateCompany:      (data) => apiClient.put('/admin/settings/company', data),
  getTimezone:        ()     => apiClient.get('/admin/settings/timezone'),
  updateTimezone:     (data) => apiClient.put('/admin/settings/timezone', data),
  getPublicTimezone:  ()     => apiClient.get('/timezone'),
  getTax:             ()     => apiClient.get('/admin/settings/tax'),
  updateTax:          (data) => apiClient.put('/admin/settings/tax', data),
}
