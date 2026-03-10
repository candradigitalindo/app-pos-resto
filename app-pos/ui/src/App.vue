<template>
  <div id="app" class="app-background">
    <GlobalNavigation />
    <router-view v-slot="{ Component, route }">
      <div :key="route.path">
        <component :is="Component" />
      </div>
    </router-view>
    <NotificationContainer />
  </div>
</template>

<script setup>
import { onMounted } from 'vue'
import { useAuthStore } from './stores/auth'
import GlobalNavigation from './components/GlobalNavigation.vue'
import NotificationContainer from './components/NotificationContainer.vue'

const authStore = useAuthStore()

onMounted(() => {
  if (authStore.token) {
    authStore.fetchProfile()
  }
})
</script>

<style>
/* Modern Clean Background */
.app-background {
  min-height: 100vh;
  background:
    radial-gradient(ellipse at 20% 50%, rgba(16, 185, 129, 0.06) 0%, transparent 50%),
    radial-gradient(ellipse at 80% 80%, rgba(6, 182, 212, 0.05) 0%, transparent 50%),
    linear-gradient(180deg, #f0fdf4 0%, #f8fafc 100%);
}
</style>
