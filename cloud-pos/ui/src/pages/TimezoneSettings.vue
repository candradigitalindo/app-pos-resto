<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-bold text-gray-900">Zona Waktu</h1>
    </div>

    <AppAlert type="info" message="Semua waktu yang ditampilkan di aplikasi akan menggunakan zona waktu yang dipilih di sini." />
    <AppAlert type="error" :message="errorMsg" />

    <AppCard>
      <div v-if="loading" class="flex items-center justify-center py-12">
        <AppSpinner />
      </div>

      <form v-else @submit.prevent="save" class="space-y-4 max-w-xl">
        <AppSelect
          v-model="selectedTimezone"
          label="Zona Waktu"
          :options="timezoneOptions"
          placeholder="Pilih zona waktu..."
        />

        <div class="flex items-center gap-3 p-3 rounded-lg bg-emerald-50 border border-emerald-200">
          <svg class="w-5 h-5 text-emerald-600 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
          <div>
            <p class="text-sm font-medium text-emerald-800">Waktu saat ini</p>
            <p class="text-lg font-bold text-emerald-900">{{ currentTime }}</p>
          </div>
        </div>

        <div class="pt-3">
          <AppButton type="submit" :loading="saving">Simpan</AppButton>
        </div>
      </form>
    </AppCard>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { settingsApi } from '@/api/settings.js'
import { useSettingsStore } from '@/stores/settings.js'
import { useToastStore } from '@/stores/toast.js'
import AppButton  from '@/components/ui/AppButton.vue'
import AppCard    from '@/components/ui/AppCard.vue'
import AppSelect  from '@/components/ui/AppSelect.vue'
import AppAlert   from '@/components/ui/AppAlert.vue'
import AppSpinner from '@/components/ui/AppSpinner.vue'

const toast         = useToastStore()
const settingsStore = useSettingsStore()
const loading       = ref(true)
const saving        = ref(false)
const errorMsg      = ref('')

const selectedTimezone = ref('Asia/Jakarta')
const timezoneOptions  = ref([])
const currentTime      = ref('')

let clockInterval = null

function updateClock() {
  try {
    const parts = new Intl.DateTimeFormat('en-GB', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
      timeZone: selectedTimezone.value,
    }).formatToParts(new Date())
    const get = (t) => parts.find(p => p.type === t)?.value || ''
    currentTime.value = `${get('day')}-${get('month')}-${get('year')}, ${get('hour')}:${get('minute')}`
  } catch {
    currentTime.value = '—'
  }
}

watch(selectedTimezone, () => updateClock())

onMounted(async () => {
  try {
    const data = await settingsApi.getTimezone()
    selectedTimezone.value = data.timezone || 'Asia/Jakarta'
    timezoneOptions.value = (data.timezones || []).map(tz => ({
      label: tz.label,
      value: tz.value,
    }))
  } catch (err) {
    errorMsg.value = 'Gagal memuat pengaturan zona waktu'
  } finally {
    loading.value = false
  }
  updateClock()
  clockInterval = setInterval(updateClock, 1000)
})

onUnmounted(() => {
  if (clockInterval) clearInterval(clockInterval)
})

async function save() {
  saving.value = true
  errorMsg.value = ''
  try {
    await settingsApi.updateTimezone({ timezone: selectedTimezone.value })
    settingsStore.setTimezone(selectedTimezone.value)
    toast.success('Zona waktu berhasil disimpan')
  } catch (err) {
    errorMsg.value = err?.response?.data?.error || 'Gagal menyimpan zona waktu'
  } finally {
    saving.value = false
  }
}
</script>
