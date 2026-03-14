/**
 * products.js — Admin API for products & categories across all outlets
 */
import { apiClient } from './client.js'

export const productsApi = {
  // ── Products ──────────────────────────────────────────────
  listProducts:   (params = {})      => apiClient.get('/admin/products', { params }),
  createProduct:  (data)             => apiClient.post('/admin/products', data),
  updateProduct:  (id, data)         => apiClient.put(`/admin/products/${id}`, data),
  deleteProduct:  (id)               => apiClient.delete(`/admin/products/${id}`),

  // ── Categories ────────────────────────────────────────────
  listCategories:   (params = {})    => apiClient.get('/admin/categories', { params }),
  createCategory:   (data)           => apiClient.post('/admin/categories', data),
  updateCategory:   (id, data)       => apiClient.put(`/admin/categories/${id}`, data),
  deleteCategory:   (id)             => apiClient.delete(`/admin/categories/${id}`),
}
