/**
 * src/main.js — Application bootstrap
 *
 * Registers:
 *   1. Pinia   — state management
 *   2. Router  — client-side routing
 *   3. App.vue — root component
 *
 * AI NOTE: To add a global plugin (e.g. i18n, toast), import it here
 * and call app.use(plugin) before app.mount('#app').
 */

import { createApp } from 'vue'
import { createPinia } from 'pinia'

import App from './App.vue'
import router from './router/index.js'
import { useSettingsStore } from './stores/settings.js'
import './style.css'

// ── Create application instance ──────────────────────────
const app = createApp(App)

// ── Register global plugins ───────────────────────────────
app.use(createPinia()) // Must register Pinia before Router if stores are used in guards
app.use(router)

// ── Fetch app-wide timezone setting ──────────────────────
const settingsStore = useSettingsStore()
settingsStore.fetchTimezone()

// ── Mount to DOM ──────────────────────────────────────────
app.mount('#app')
