/**
 * src/stores/auth.js — Authentication state (Pinia store)
 *
 * Responsibilities:
 *   - Store JWT token + admin info in localStorage (persisted across tabs)
 *   - Expose login / logout actions
 *   - Provide computed `isAuthenticated` + `currentAdmin` getters
 *
 * Token lifecycle:
 *   login()  → calls POST /api/v1/admin/login → stores token
 *   logout() → clears token + redirects to /login
 *
 * AI NOTE: To add refresh-token logic, add a `refreshToken` action
 * that calls a /api/v1/admin/refresh endpoint and updates `token`.
 */

import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { authApi } from '@/api/auth.js'

// Storage key used in localStorage
const TOKEN_KEY  = 'cloud_pos_token'
const ADMIN_KEY  = 'cloud_pos_admin'

export const useAuthStore = defineStore('auth', () => {
  // ── State ────────────────────────────────────────────────
  const token = ref(localStorage.getItem(TOKEN_KEY) || '')
  const admin = ref(JSON.parse(localStorage.getItem(ADMIN_KEY) || 'null'))

  // ── Getters ──────────────────────────────────────────────
  /** True when a valid token exists */
  const isAuthenticated = computed(() => !!token.value)

  /** The currently logged-in admin object */
  const currentAdmin = computed(() => admin.value)

  // ── Actions ──────────────────────────────────────────────

  /**
   * login — Authenticate admin credentials against the API.
   * @param {string} username
   * @param {string} password
   * @throws {Error} when credentials are invalid
   */
  async function login(username, password) {
    const data = await authApi.login(username, password)
    token.value = data.token
    admin.value = data.admin
    localStorage.setItem(TOKEN_KEY, data.token)
    localStorage.setItem(ADMIN_KEY, JSON.stringify(data.admin))
  }

  /**
   * logout — Clear session and navigate to /login.
   * Called by the UI on manual logout or on 401 response from API.
   */
  function logout() {
    token.value = ''
    admin.value = null
    localStorage.removeItem(TOKEN_KEY)
    localStorage.removeItem(ADMIN_KEY)
  }

  return {
    token,
    admin,
    isAuthenticated,
    currentAdmin,
    login,
    logout,
  }
})
