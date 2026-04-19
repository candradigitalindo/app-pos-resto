<template>
  <!--
    App.vue — Root component
    Simply renders the current route component.
    RouterView is swapped by vue-router based on the URL.

    AI NOTE: Global overlays (toasts, modals) can be added just before
    </RouterView> so they're always available regardless of the current page.
  -->
  <RouterView />
</template>

<script setup>
import { onMounted } from 'vue'
import { useSettingsStore } from '@/stores/settings.js'

const settingsStore = useSettingsStore()

onMounted(() => {
  settingsStore.fetchTimezone()
})
</script>
