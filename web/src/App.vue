<template>
  <div id="app" class="batik-background">
    <GlobalNavigation />
    <router-view />
    <NotificationContainer />
  </div>
</template>

<script setup>
import { onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from './stores/auth'
import GlobalNavigation from './components/GlobalNavigation.vue'
import NotificationContainer from './components/NotificationContainer.vue'

const router = useRouter()
const authStore = useAuthStore()

// Function to remove any stuck modal overlays
const removeStuckModals = () => {
  const overlays = document.querySelectorAll('.fixed.inset-0[class*="bg-slate-900"], .fixed.inset-0[class*="bg-black"]')
  
  overlays.forEach(el => {
    const hasModalContent = el.querySelector('.card, .modal, button, input, a')
    const rect = el.getBoundingClientRect()
    
    // Only remove if it's a full-screen overlay without any interactive content
    if (rect.width >= window.innerWidth * 0.9 && 
        rect.height >= window.innerHeight * 0.9 &&
        !hasModalContent) {
      el.remove()
    }
  })
}

onMounted(() => {
  if (authStore.token) {
    authStore.fetchProfile()
  }
  
  // Clean any stuck modals after mount
  setTimeout(removeStuckModals, 200)
})

// Clean stuck modals on route change
watch(() => router.currentRoute.value, () => {
  setTimeout(removeStuckModals, 100)
})
</script>

<style>
html, body, #app {
  pointer-events: auto !important;
}

/* Modern Clean Background with Subtle Pattern */
.batik-background {
  min-height: 100vh;
  background: 
    radial-gradient(circle at 20% 50%, rgba(16, 185, 129, 0.08) 0%, transparent 50%),
    radial-gradient(circle at 80% 80%, rgba(6, 182, 212, 0.08) 0%, transparent 50%),
    radial-gradient(circle at 40% 20%, rgba(16, 185, 129, 0.05) 0%, transparent 50%),
    linear-gradient(180deg, #f0fdf4 0%, #ecfdf5 100%);
  position: relative;
}

.batik-background::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-image: url("data:image/svg+xml,%3Csvg width='100' height='100' viewBox='0 0 100 100' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='%2310b981' fill-opacity='0.02'%3E%3Ccircle cx='10' cy='10' r='1.5'/%3E%3Ccircle cx='90' cy='10' r='1.5'/%3E%3Ccircle cx='50' cy='50' r='1.5'/%3E%3Ccircle cx='10' cy='90' r='1.5'/%3E%3Ccircle cx='90' cy='90' r='1.5'/%3E%3C/g%3E%3C/svg%3E");
  background-size: 100px 100px;
  opacity: 0.4;
  pointer-events: none;
}

/* Prevent empty modal overlays from blocking */
.fixed.inset-0:not(:has(button)):not(:has(input)):not(:has(a)):not(:has(.card)):not(:has(.modal)) {
  pointer-events: none !important;
  opacity: 0 !important;
}
</style>
