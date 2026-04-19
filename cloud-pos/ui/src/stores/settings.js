import { defineStore } from 'pinia'
import { ref } from 'vue'
import { settingsApi } from '@/api/settings.js'

const TZ_KEY = 'cloud_pos_timezone'

export const useSettingsStore = defineStore('settings', () => {
  const timezone = ref(localStorage.getItem(TZ_KEY) || 'Asia/Jakarta')

  async function fetchTimezone() {
    try {
      const data = await settingsApi.getPublicTimezone()
      timezone.value = data.timezone || 'Asia/Jakarta'
      localStorage.setItem(TZ_KEY, timezone.value)
    } catch {
      // fallback to cached or default
    }
  }

  function setTimezone(tz) {
    timezone.value = tz
    localStorage.setItem(TZ_KEY, tz)
  }

  return { timezone, fetchTimezone, setTimezone }
})
