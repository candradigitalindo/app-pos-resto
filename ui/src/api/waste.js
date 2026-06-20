import { apiClient as client } from './client'

export const getWastes = (params) => client.get('/admin/stock-wastes', { params })
export const createWaste = (data) => client.post('/admin/stock-wastes', data)


