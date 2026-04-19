import { apiClient } from './client.js'

export const bankAccountsApi = {
  list: () =>
    apiClient.get('/admin/bank-accounts'),

  create: (data) =>
    apiClient.post('/admin/bank-accounts', data),

  update: (id, data) =>
    apiClient.put(`/admin/bank-accounts/${id}`, data),

  delete: (id) =>
    apiClient.delete(`/admin/bank-accounts/${id}`),
}
