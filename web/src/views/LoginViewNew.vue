<template>
  <div class="login-wrapper">
    <!-- Animated Background with Particles -->
    <div class="animated-bg">
      <!-- Gradient Orbs -->
      <div class="gradient-orb orb-1"></div>
      <div class="gradient-orb orb-2"></div>
      <div class="gradient-orb orb-3"></div>
      
      <!-- Floating Particles -->
      <div class="particles">
        <div class="particle" v-for="n in 20" :key="n" :style="getParticleStyle(n)"></div>
      </div>
      
      <!-- Grid Pattern Overlay -->
      <div class="grid-pattern"></div>
    </div>

    <div class="login-container">
      <!-- Left Section - Branding -->
      <section class="branding-section">
        <div class="brand-glass-card">
          <!-- Floating Icon with Glow -->
          <div class="brand-icon-wrapper">
            <div class="icon-glow"></div>
            <div class="brand-icon">
              <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <rect x="2" y="3" width="20" height="14" rx="3" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
                <path d="M2 10H22" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"/>
                <circle cx="7" cy="14" r="1.5" fill="currentColor"/>
                <path d="M8 21H16" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
                <path d="M12 17V21" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </div>
          </div>
          
          <!-- Brand Title -->
          <h1 class="brand-title">
            <span class="title-main">POS</span>
            <span class="title-accent">System</span>
          </h1>
          <p class="brand-tagline">Point of Sale Modern</p>
          <button type="button" class="qr-trigger-btn" @click="openQrModal">Tampilkan QR Code Server</button>
        </div>
      </section>

      <!-- Right Section - Login Form -->
      <section class="form-section">
        <div class="form-glass-card">
          <!-- Form Header -->
          <div class="form-header">
            <div class="welcome-badge">
              <svg viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-6-3a2 2 0 11-4 0 2 2 0 014 0zm-2 4a5 5 0 00-4.546 2.916A5.986 5.986 0 0010 16a5.986 5.986 0 004.546-2.084A5 5 0 0010 11z" clip-rule="evenodd"/>
              </svg>
              <span>Selamat Datang Kembali</span>
            </div>
            <h2 class="form-title">Masuk ke Dashboard</h2>
            <p class="form-subtitle">Kelola bisnis Anda dengan mudah dan efisien</p>
          </div>

          <!-- Login Form -->
          <form @submit.prevent="handleLogin" class="login-form">
            <!-- Username Field -->
            <div class="form-group">
              <label class="form-label">
                <svg class="label-icon" viewBox="0 0 20 20" fill="currentColor">
                  <path d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z"/>
                </svg>
                <span>Username</span>
              </label>
              <div class="input-wrapper">
                <input
                  v-model="username"
                  type="text"
                  class="form-input"
                  placeholder="Masukkan username Anda"
                  autocomplete="username"
                  required
                />
                <div class="input-shine"></div>
              </div>
            </div>

            <!-- PIN Field -->
            <div class="form-group">
              <label class="form-label">
                <svg class="label-icon" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd"/>
                </svg>
                <span>PIN (4 Digit)</span>
              </label>
              <div class="input-wrapper">
                <input
                  v-model="password"
                  type="text"
                  inputmode="numeric"
                  pattern="[0-9]{4}"
                  maxlength="4"
                  minlength="4"
                  class="form-input pin-input"
                  placeholder="• • • •"
                  autocomplete="off"
                  required
                  @input="validatePin"
                />
                <div class="input-shine"></div>
              </div>
            </div>

            <!-- Submit Button -->
            <button type="submit" class="submit-btn" :disabled="loading">
              <span class="btn-gradient"></span>
              <span class="btn-content">
                <template v-if="!loading">
                  <svg class="btn-icon" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-8.707l-3-3a1 1 0 00-1.414 1.414L10.586 9H7a1 1 0 100 2h3.586l-1.293 1.293a1 1 0 101.414 1.414l3-3a1 1 0 000-1.414z" clip-rule="evenodd"/>
                  </svg>
                  <span>Masuk ke Dashboard</span>
                </template>
                <template v-else>
                  <svg class="btn-icon spinning" viewBox="0 0 24 24" fill="none">
                    <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" opacity="0.25"/>
                    <path fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" opacity="0.75"/>
                  </svg>
                  <span>Memproses...</span>
                </template>
              </span>
            </button>
          </form>

          <!-- Form Footer -->
          <div class="form-footer">
            <div class="security-badge">
              <svg class="security-icon" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M2.166 4.999A11.954 11.954 0 0010 1.944 11.954 11.954 0 0017.834 5c.11.65.166 1.32.166 2.001 0 5.225-3.34 9.67-8 11.317C5.34 16.67 2 12.225 2 7c0-.682.057-1.35.166-2.001zm11.541 3.708a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
              </svg>
              <span>Koneksi terenkripsi & aman</span>
            </div>
            <div class="version-badge">v1.0.0 © 2026</div>
          </div>
        </div>
      </section>
    </div>

    <!-- Error Modal -->
    <transition name="modal">
      <div v-if="error" class="modal-overlay" @click="error = ''">
        <div class="modal-card" @click.stop>
          <div class="modal-icon error">
            <svg viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
            </svg>
          </div>
          <h3 class="modal-title">Login Gagal</h3>
          <p class="modal-message">{{ error }}</p>
          <button @click="error = ''" class="modal-btn">Tutup</button>
        </div>
      </div>
    </transition>
    <transition name="modal">
      <div v-if="showQrModal" class="modal-overlay" @click="showQrModal = false">
        <div class="modal-card" @click.stop>
          <h3 class="modal-title">QR Code Server</h3>
          <p class="modal-message">Scan untuk koneksi perangkat</p>
          <div class="qr-card">
            <div v-if="qrLoading" class="qr-placeholder">Memuat QR...</div>
            <img v-else-if="serverQr" class="qr-image" :src="`data:image/png;base64,${serverQr}`" alt="QR Server" />
            <div v-else class="qr-placeholder">{{ qrError || 'QR tidak tersedia' }}</div>
          </div>
          <div v-if="serverUrl" class="qr-url">{{ serverUrl }}</div>
          <button @click="showQrModal = false" class="modal-btn">Tutup</button>
        </div>
      </div>
    </transition>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import api from '../services/api'

const router = useRouter()
const authStore = useAuthStore()

const username =ref('')
const password = ref('')
const error = ref('')
const loading = ref(false)
const serverQr = ref('')
const serverUrl = ref('')
const qrLoading = ref(false)
const qrError = ref('')
const showQrModal = ref(false)

// Generate random particle styles
const getParticleStyle = (index) => {
  const directions = [
    { x: Math.random() * 100, y: Math.random() * 100 },
    { x: -Math.random() * 100, y: Math.random() * 100 },
    { x: Math.random() * 100, y: -Math.random() * 100 },
    { x: -Math.random() * 100, y: -Math.random() * 100 }
  ]
  const direction = directions[index % 4]
  
  return {
    left: `${Math.random() * 100}%`,
    top: `${Math.random() * 100}%`,
    width: `${Math.random() * 6 + 2}px`,
    height: `${Math.random() * 6 + 2}px`,
    animationDelay: `${Math.random() * 10}s`,
    animationDuration: `${Math.random() * 20 + 15}s`,
    '--move-x': `${direction.x}px`,
    '--move-y': `${direction.y}px`
  }
}

const validatePin = (e) => {
  // Hanya izinkan angka
  password.value = password.value.replace(/[^0-9]/g, '')
  // Maksimal 4 digit
  if (password.value.length > 4) {
    password.value = password.value.slice(0, 4)
  }
}

const handleEscape = (e) => {
  if (e.key === 'Escape') {
    if (showQrModal.value) {
      showQrModal.value = false
    }
    if (error.value) {
      error.value = ''
    }
  }
}

const fetchServerQRCode = async () => {
  qrLoading.value = true
  qrError.value = ''
  try {
    const response = await api.get('/server/qr')
    if (response.data?.success) {
      serverQr.value = response.data.data?.qr_code || ''
      serverUrl.value = response.data.data?.server_url || ''
      return
    }
    qrError.value = response.data?.message || 'QR tidak tersedia'
  } catch (err) {
    qrError.value = err.message || 'QR tidak tersedia'
  } finally {
    qrLoading.value = false
  }
}

const openQrModal = async () => {
  showQrModal.value = true
  if (!serverQr.value && !qrLoading.value) {
    await fetchServerQRCode()
  }
}

onMounted(() => {
  document.addEventListener('keydown', handleEscape)
})

onUnmounted(() => {
  document.removeEventListener('keydown', handleEscape)
})

const handleLogin = async () => {
  error.value = ''
  loading.value = true

  try {
    const result = await authStore.login(username.value, password.value)
    if (!result.success) {
      error.value = result.message || 'Login gagal'
      return
    }

    await router.push('/')
  } catch (err) {
    error.value = err.message || 'Login gagal'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
/* ==================== BASE STYLES ==================== */
.login-wrapper {
  position: relative;
  min-height: 100vh;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
}

/* ==================== ANIMATED BACKGROUND ==================== */
.animated-bg {
  position: absolute;
  inset: 0;
  background: linear-gradient(135deg, #0f766e 0%, #10b981 50%, #6ee7b7 100%);
  z-index: 0;
}

/* Floating Gradient Orbs */
.gradient-orb {
  position: absolute;
  border-radius: 50%;
  filter: blur(120px);
  opacity: 0.5;
  animation: float 25s infinite ease-in-out;
}

.orb-1 {
  width: 600px;
  height: 600px;
  background: radial-gradient(circle, rgba(16, 185, 129, 0.6) 0%, transparent 70%);
  top: -15%;
  left: -15%;
  animation-delay: 0s;
}

.orb-2 {
  width: 500px;
  height: 500px;
  background: radial-gradient(circle, rgba(110, 231, 183, 0.6) 0%, transparent 70%);
  bottom: -15%;
  right: -15%;
  animation-delay: 8s;
}

.orb-3 {
  width: 400px;
  height: 400px;
  background: radial-gradient(circle, rgba(6, 78, 59, 0.6) 0%, transparent 70%);
  top: 40%;
  left: 40%;
  animation-delay: 16s;
}

@keyframes float {
  0%, 100% { 
    transform: translate(0, 0) scale(1) rotate(0deg); 
  }
  33% { 
    transform: translate(50px, -50px) scale(1.1) rotate(120deg); 
  }
  66% { 
    transform: translate(-40px, 40px) scale(0.9) rotate(240deg); 
  }
}

/* Floating Particles */
.particles {
  position: absolute;
  inset: 0;
  pointer-events: none;
  overflow: hidden;
}

.particle {
  position: absolute;
  background: rgba(255, 255, 255, 0.3);
  border-radius: 50%;
  animation: particleFloat var(--duration, 20s) infinite ease-in-out;
}

@keyframes particleFloat {
  0%, 100% { 
    transform: translate(0, 0);
    opacity: 0;
  }
  10% {
    opacity: 0.3;
  }
  50% { 
    transform: translate(var(--move-x), var(--move-y));
    opacity: 0.6;
  }
  90% {
    opacity: 0.3;
  }
}

/* Grid Pattern Overlay */
.grid-pattern {
  position: absolute;
  inset: 0;
  background-image: 
    linear-gradient(rgba(255, 255, 255, 0.03) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255, 255, 255, 0.03) 1px, transparent 1px);
  background-size: 50px 50px;
  opacity: 0.5;
}

/* ==================== LOGIN CONTAINER ==================== */
.login-container {
  position: relative;
  z-index: 1;
  width: 100%;
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 4rem;
  align-items: center;
}

/* ==================== BRANDING SECTION ==================== */
.branding-section {
  animation: slideInLeft 0.8s cubic-bezier(0.16, 1, 0.3, 1);
}

.brand-glass-card {
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 32px;
  padding: 4rem 3rem;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3),
              inset 0 1px 0 rgba(255, 255, 255, 0.3);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2rem;
  position: relative;
  overflow: hidden;
}

.brand-glass-card::before {
  content: '';
  position: absolute;
  top: 0;
  left: -50%;
  width: 50%;
  height: 100%;
  background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.1), transparent);
  animation: shimmer 3s infinite;
}

@keyframes shimmer {
  0% { left: -50%; }
  100% { left: 150%; }
}

/* Brand Icon with Glow */
.brand-icon-wrapper {
  position: relative;
  margin-bottom: 1.5rem;
}

.icon-glow {
  position: absolute;
  inset: -30px;
  background: radial-gradient(circle, rgba(255, 255, 255, 0.4) 0%, transparent 60%);
  border-radius: 50%;
  animation: pulse 3s infinite;
}

@keyframes pulse {
  0%, 100% { 
    opacity: 0.4;
    transform: scale(0.8); 
  }
  50% { 
    opacity: 0.7;
    transform: scale(1.1); 
  }
}

.brand-icon {
  position: relative;
  width: 100px;
  height: 100px;
  background: rgba(255, 255, 255, 0.15);
  backdrop-filter: blur(10px);
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-radius: 28px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2),
              inset 0 1px 0 rgba(255, 255, 255, 0.4);
  animation: iconFloat 6s infinite ease-in-out;
}

@keyframes iconFloat {
  0%, 100% { transform: translateY(0) rotate(0deg); }
  50% { transform: translateY(-10px) rotate(5deg); }
}

.brand-icon svg {
  width: 56px;
  height: 56px;
  filter: drop-shadow(0 2px 10px rgba(0, 0, 0, 0.2));
}

/* Brand Title */
.brand-title {
  font-size: 4rem;
  font-weight: 800;
  margin: 0;
  color: white;
  text-align: center;
  letter-spacing: -0.02em;
  line-height: 1;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.title-main {
  display: block;
  background: linear-gradient(135deg, #ffffff 0%, #e0f2f1 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
  filter: drop-shadow(0 4px 20px rgba(255, 255, 255, 0.3));
  animation: titleGlow 3s infinite;
}

@keyframes titleGlow {
  0%, 100% { filter: drop-shadow(0 4px 20px rgba(255, 255, 255, 0.3)); }
  50% { filter: drop-shadow(0 4px 30px rgba(255, 255, 255, 0.5)); }
}

.title-accent {
  font-size: 2rem;
  font-weight: 600;
  color: rgba(255, 255, 255, 0.9);
  letter-spacing: 0.1em;
  text-transform: uppercase;
}

.brand-tagline {
  font-size: 1.125rem;
  color: rgba(255, 255, 255, 0.85);
  margin: 0;
  text-align: center;
}

.qr-trigger-btn {
  margin-top: 1.5rem;
  padding: 0.75rem 1.5rem;
  border-radius: 999px;
  border: 1px solid rgba(255, 255, 255, 0.35);
  background: rgba(255, 255, 255, 0.15);
  color: white;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  box-shadow: 0 6px 18px rgba(0, 0, 0, 0.2);
}

.qr-trigger-btn:hover {
  background: rgba(255, 255, 255, 0.25);
  transform: translateY(-2px);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.25);
}

/* ==================== FORM SECTION ==================== */
.form-section {
  animation: slideInRight 0.8s cubic-bezier(0.16, 1, 0.3, 1);
}

.form-glass-card {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.5);
  border-radius: 32px;
  padding: 3rem;
  box-shadow: 0 30px 80px rgba(0, 0, 0, 0.25),
              0 0 0 1px rgba(255, 255, 255, 0.5);
  position: relative;
  overflow: hidden;
}

.form-glass-card::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 200px;
  background: linear-gradient(180deg, rgba(16, 185, 129, 0.05) 0%, transparent 100%);
  pointer-events: none;
}

/* Form Header */
.form-header {
  margin-bottom: 2.5rem;
  text-align: center;
  position: relative;
}

.welcome-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  background: linear-gradient(135deg, #10b981 0%, #059669 100%);
  color: white;
  font-size: 0.8125rem;
  font-weight: 600;
  padding: 0.625rem 1.25rem;
  border-radius: 50px;
  margin-bottom: 1.5rem;
  box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
  animation: fadeInDown 0.6s ease-out 0.3s both;
}

.welcome-badge svg {
  width: 16px;
  height: 16px;
}

.form-title {
  font-size: 2rem;
  font-weight: 700;
  color: #0f172a;
  margin: 0 0 0.75rem 0;
  letter-spacing: -0.02em;
  animation: fadeInDown 0.6s ease-out 0.4s both;
}

.form-subtitle {
  font-size: 0.9375rem;
  color: #64748b;
  margin: 0;
  animation: fadeInDown 0.6s ease-out 0.5s both;
}

/* Login Form */
.login-form {
  margin-bottom: 2rem;
}

.qr-card {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1rem;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 16px;
}

.qr-image {
  width: 180px;
  height: 180px;
}

.qr-placeholder {
  font-size: 0.875rem;
  color: #94a3b8;
}

.qr-url {
  font-size: 0.8125rem;
  color: #64748b;
  word-break: break-all;
}

.form-group {
  margin-bottom: 1.75rem;
  animation: fadeInUp 0.6s ease-out both;
}

.form-group:nth-child(1) { animation-delay: 0.6s; }
.form-group:nth-child(2) { animation-delay: 0.7s; }

.form-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  font-weight: 600;
  color: #1e293b;
  margin-bottom: 0.75rem;
}

.label-icon {
  width: 18px;
  height: 18px;
  color: #10b981;
}

/* Input Wrapper with Shine Effect */
.input-wrapper {
  position: relative;
}

.input-shine {
  position: absolute;
  top: 0;
  left: -100%;
  width: 50%;
  height: 100%;
  background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.8), transparent);
  pointer-events: none;
  border-radius: 16px;
}

.form-input:focus ~ .input-shine {
  animation: shine 1.5s;
}

@keyframes shine {
  0% { left: -100%; }
  100% { left: 150%; }
}

.form-input {
  width: 100%;
  padding: 1rem 1.25rem;
  font-size: 0.9375rem;
  color: #0f172a;
  border: 2px solid #e2e8f0;
  border-radius: 16px;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  outline: none;
  background: #ffffff;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
}

.form-input::placeholder {
  color: #94a3b8;
}

.form-input:hover {
  border-color: #cbd5e1;
  background: #fafafa;
}

.form-input:focus {
  border-color: #10b981;
  background: #ffffff;
  box-shadow: 0 0 0 4px rgba(16, 185, 129, 0.1),
              0 4px 12px rgba(16, 185, 129, 0.15);
  transform: translateY(-1px);
}

.pin-input {
  text-align: center;
  font-size: 1.5rem;
  font-weight: 600;
  letter-spacing: 0.75rem;
  font-family: 'SF Mono', 'Monaco', 'Courier New', monospace;
}

.pin-input::placeholder {
  font-size: 1.25rem;
  letter-spacing: 0.5rem;
}

/* Submit Button */
.submit-btn {
  width: 100%;
  margin-top: 0.5rem;
  padding: 1.125rem;
  position: relative;
  background: #0f172a;
  color: white;
  font-weight: 600;
  font-size: 1rem;
  border: none;
  border-radius: 16px;
  cursor: pointer;
  overflow: hidden;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  box-shadow: 0 8px 24px rgba(16, 185, 129, 0.3),
              0 4px 12px rgba(0, 0, 0, 0.1);
  animation: fadeInUp 0.6s ease-out 0.8s both;
}

.btn-gradient {
  position: absolute;
  inset: 0;
  background: linear-gradient(135deg, #10b981 0%, #059669 50%, #10b981 100%);
  background-size: 200% 100%;
  opacity: 1;
  transition: opacity 0.3s, background-position 0.3s;
}

.submit-btn:hover .btn-gradient {
  background-position: 100% 0;
}

.submit-btn:hover:not(:disabled) {
  transform: translateY(-3px);
  box-shadow: 0 12px 32px rgba(16, 185, 129, 0.4),
              0 6px 16px rgba(0, 0, 0, 0.15);
}

.submit-btn:active:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 6px 20px rgba(16, 185, 129, 0.35),
              0 3px 10px rgba(0, 0, 0, 0.1);
}

.submit-btn:disabled {
  opacity: 0.7;
  cursor: not-allowed;
  transform: none !important;
}

.btn-content {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  z-index: 1;
}

.btn-icon {
  width: 20px;
  height: 20px;
}

.spinning {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* Form Footer */
.form-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-top: 2rem;
  border-top: 1px solid #e2e8f0;
  animation: fadeInUp 0.6s ease-out 0.9s both;
}

.security-badge {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.8125rem;
  color: #64748b;
  font-weight: 500;
}

.security-icon {
  width: 18px;
  height: 18px;
  color: #10b981;
}

.version-badge {
  font-size: 0.8125rem;
  color: #94a3b8;
  font-weight: 500;
}

/* ==================== MODAL ==================== */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(15, 23, 42, 0.75);
  backdrop-filter: blur(8px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 50;
  padding: 1rem;
}

.modal-card {
  background: white;
  border-radius: 24px;
  padding: 2.5rem;
  max-width: 420px;
  width: 100%;
  text-align: center;
  box-shadow: 0 25px 50px rgba(0, 0, 0, 0.25);
  animation: modalSlideIn 0.4s cubic-bezier(0.16, 1, 0.3, 1);
}

.modal-icon {
  width: 72px;
  height: 72px;
  margin: 0 auto 1.5rem;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 8px 24px rgba(239, 68, 68, 0.2);
}

.modal-icon.error {
  background: linear-gradient(135deg, #fee2e2 0%, #fecaca 100%);
  color: #dc2626;
}

.modal-icon svg {
  width: 36px;
  height: 36px;
}

.modal-title {
  font-size: 1.5rem;
  font-weight: 700;
  color: #0f172a;
  margin: 0 0 0.75rem 0;
}

.modal-message {
  font-size: 0.9375rem;
  color: #64748b;
  margin: 0 0 2rem 0;
  line-height: 1.6;
}

.modal-btn {
  padding: 0.875rem 2.5rem;
  background: linear-gradient(135deg, #10b981 0%, #059669 100%);
  color: white;
  font-weight: 600;
  border: none;
  border-radius: 12px;
  cursor: pointer;
  box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.modal-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(16, 185, 129, 0.4);
}

/* Modal Transitions */
.modal-enter-active, .modal-leave-active {
  transition: opacity 0.3s;
}

.modal-enter-from, .modal-leave-to {
  opacity: 0;
}

@keyframes modalSlideIn {
  from {
    opacity: 0;
    transform: translateY(-40px) scale(0.9);
  }
  to {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}

/* ==================== ANIMATIONS ==================== */
@keyframes slideInLeft {
  from {
    opacity: 0;
    transform: translateX(-80px);
  }
  to {
    opacity: 1;
    transform: translateX(0);
  }
}

@keyframes slideInRight {
  from {
    opacity: 0;
    transform: translateX(80px);
  }
  to {
    opacity: 1;
    transform: translateX(0);
  }
}

@keyframes fadeInUp {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes fadeInDown {
  from {
    opacity: 0;
    transform: translateY(-20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* ==================== RESPONSIVE ==================== */
@media (max-width: 1024px) {
  .login-container {
    grid-template-columns: 1fr;
    gap: 2rem;
    padding: 1.5rem;
  }

  .branding-section {
    display: none;
  }

  .form-section {
    width: 100%;
    max-width: 520px;
    margin: 0 auto;
  }
}

@media (max-width: 640px) {
  .login-wrapper {
    padding: 1rem;
  }

  .form-glass-card {
    padding: 2rem 1.5rem;
    border-radius: 24px;
  }

  .form-title {
    font-size: 1.75rem;
  }

  .brand-title {
    font-size: 3rem;
  }

  .title-accent {
    font-size: 1.5rem;
  }

  .feature-pills {
    gap: 0.75rem;
  }

  .pill {
    font-size: 0.8125rem;
    padding: 0.5rem 1rem;
  }
}

@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
</style>
