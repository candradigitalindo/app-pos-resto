import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import api from '../services/api'

export const useAuthStore = defineStore('auth', () => {
  const user = ref(null)
  const token = ref(localStorage.getItem('token') || null)
  
  const isAuthenticated = computed(() => !!token.value)
  
  async function login(username, password) {
    try {
      const response = await api.post('/auth/login', { username, password })
      
      if (response.data.success) {
        token.value = response.data.data.token
        user.value = response.data.data.user
        localStorage.setItem('token', token.value)
        return { success: true }
      }
      
      return { success: false, message: response.data.message }
    } catch (error) {
      return { 
        success: false, 
        message: error.response?.data?.message || 'Login gagal' 
      }
    }
  }
  
  async function logout() {
    token.value = null
    user.value = null
    localStorage.removeItem('token')
  }

  function setSession(newToken, newUser) {
    token.value = newToken
    user.value = newUser
    if (newToken) {
      localStorage.setItem('token', newToken)
    } else {
      localStorage.removeItem('token')
    }
  }
  
  async function fetchProfile() {
    try {
      const response = await api.get('/auth/profile')
      if (response.data.success) {
        user.value = response.data.data
      }
    } catch (error) {
      console.error('Failed to fetch profile:', error)
    }
  }
  
  return {
    user,
    token,
    isAuthenticated,
    login,
    logout,
    setSession,
    fetchProfile
  }
})
