/**
 * src/api/client.js — Axios HTTP client singleton
 *
 * Every API module imports `apiClient` from here — there is one shared
 * Axios instance for the whole app.
 *
 * Features configured here:
 *   - baseURL      : reads VITE_API_BASE_URL env var (falls back to /api/v1)
 *   - Request interceptor  : auto-attaches Bearer token from localStorage
 *   - Response interceptor : unwraps { success, data } envelope
 *                            auto-redirects to /login on 401
 *
 * AI NOTE: To add a request timeout, set `timeout: 10000` in the config.
 * To add retry logic, integrate the `axios-retry` package here.
 */

import axios from 'axios'

// Base URL — override with VITE_API_BASE_URL in .env for staging/prod
const BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api/v1'
const TOKEN_KEY = 'cloud_pos_token'

// ── Axios instance ─────────────────────────────────────────
export const apiClient = axios.create({
  baseURL: BASE_URL,
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  },
})

// ── Request interceptor ────────────────────────────────────
// Attaches the JWT token to every outgoing request
apiClient.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem(TOKEN_KEY)
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  (error) => Promise.reject(error),
)

// ── Response interceptor ───────────────────────────────────
// Unwraps the standard { success, data, error } envelope from the Go API.
// On 401, clears the token and redirects to /login.
apiClient.interceptors.response.use(
  (response) => {
    // Our API always returns { success: bool, data: any }
    const body = response.data
    if (body && typeof body === 'object' && 'success' in body) {
      if (!body.success) {
        const msg = body.error || 'Unknown error from server'
        return Promise.reject(new Error(msg))
      }
      // Paginated responses ({ success, data, page, total, total_pages }) →
      // return the FULL body so callers can read both `data` (array) and the
      // pagination metadata (total_pages, total). Detected by `total_pages`.
      if ('total_pages' in body) return body
      // Standard envelope → return the `data` payload directly to callers
      return body.data ?? body
    }
    return response.data
  },
  (error) => {
    const isLoginRequest = error.config?.url?.includes('/admin/login')

    if (error.response?.status === 401 && !isLoginRequest) {
      // Token expired or invalid — clear session and redirect to login
      // (skip redirect when the failed request IS the login call itself,
      //  so Login.vue can display the "wrong credentials" error)
      localStorage.removeItem(TOKEN_KEY)
      localStorage.removeItem('cloud_pos_admin')
      window.location.href = '/login'
    }
    const message =
      error.response?.data?.error ||
      error.message ||
      'Terjadi kesalahan jaringan'
    return Promise.reject(new Error(message))
  },
)
