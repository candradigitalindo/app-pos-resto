<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-bold text-gray-900">Pengaturan Pajak</h1>
    </div>

    <AppAlert type="info" message="Pengaturan pajak berlaku untuk semua outlet. Pajak dihitung secara inklusif dari total transaksi." />
    <AppAlert type="error" :message="errorMsg" />

    <AppCard>
      <div v-if="loading" class="flex items-center justify-center py-12">
        <AppSpinner />
      </div>

      <form v-else @submit.prevent="save" class="space-y-5 max-w-xl">
        <!-- Toggle Pajak -->
        <div class="flex items-center justify-between p-4 rounded-lg border" :class="taxEnabled ? 'bg-emerald-50 border-emerald-200' : 'bg-gray-50 border-gray-200'">
          <div>
            <p class="font-medium" :class="taxEnabled ? 'text-emerald-900' : 'text-gray-700'">Pajak Aktif</p>
            <p class="text-sm" :class="taxEnabled ? 'text-emerald-700' : 'text-gray-500'">
              {{ taxEnabled ? 'Pajak akan dihitung pada setiap transaksi' : 'Pajak tidak aktif' }}
            </p>
          </div>
          <button type="button" @click="taxEnabled = !taxEnabled"
            class="relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:ring-offset-2"
            :class="taxEnabled ? 'bg-emerald-600' : 'bg-gray-300'"
          >
            <span class="pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out"
              :class="taxEnabled ? 'translate-x-5' : 'translate-x-0'"
            />
          </button>
        </div>

        <!-- Nama Pajak -->
        <AppInput v-model="taxName" label="Nama Pajak" placeholder="Contoh: Pajak Restoran (PB1)" />

        <!-- Tarif Pajak -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Tarif Pajak (%)</label>
          <div class="relative">
            <input
              v-model.number="taxRate"
              type="number"
              step="0.01"
              min="0"
              max="100"
              class="block w-full rounded-lg border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm pr-10"
              placeholder="10"
            />
            <span class="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-500 text-sm">%</span>
          </div>
        </div>

        <!-- Preview -->
        <div v-if="taxEnabled && taxRate > 0" class="p-4 rounded-lg bg-blue-50 border border-blue-200">
          <p class="text-sm font-medium text-blue-800 mb-2">Simulasi Perhitungan</p>
          <div class="space-y-1 text-sm text-blue-700">
            <p>Contoh total transaksi: <strong>Rp 110.000</strong></p>
            <p>{{ taxName || 'Pajak' }} ({{ taxRate }}% inklusif): <strong>Rp {{ formatNumber(simulatedTax) }}</strong></p>
            <p>Pendapatan bersih: <strong>Rp {{ formatNumber(simulatedNet) }}</strong></p>
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
import { ref, computed, onMounted } from 'vue'
import { settingsApi } from '@/api/settings.js'
import { useToastStore } from '@/stores/toast.js'
import AppButton  from '@/components/ui/AppButton.vue'
import AppCard    from '@/components/ui/AppCard.vue'
import AppInput   from '@/components/ui/AppInput.vue'
import AppAlert   from '@/components/ui/AppAlert.vue'
import AppSpinner from '@/components/ui/AppSpinner.vue'

const toast    = useToastStore()
const loading  = ref(true)
const saving   = ref(false)
const errorMsg = ref('')

const taxEnabled = ref(false)
const taxRate    = ref(10)
const taxName    = ref('Pajak Restoran (PB1)')

const simulatedTax = computed(() => {
  const rate = taxRate.value / (100 + taxRate.value)
  return Math.round(110000 * rate)
})

const simulatedNet = computed(() => 110000 - simulatedTax.value)

function formatNumber(n) {
  return new Intl.NumberFormat('id-ID').format(n)
}

onMounted(async () => {
  try {
    const data = await settingsApi.getTax()
    taxEnabled.value = data.tax_enabled ?? false
    taxRate.value    = data.tax_rate ?? 10
    taxName.value    = data.tax_name || 'Pajak Restoran (PB1)'
  } catch {
    errorMsg.value = 'Gagal memuat pengaturan pajak'
  } finally {
    loading.value = false
  }
})

async function save() {
  saving.value = true
  errorMsg.value = ''
  try {
    await settingsApi.updateTax({
      tax_enabled: taxEnabled.value,
      tax_rate:    taxRate.value,
      tax_name:    taxName.value,
    })
    toast.success('Pengaturan pajak berhasil disimpan')
  } catch (err) {
    errorMsg.value = err?.response?.data?.error || 'Gagal menyimpan pengaturan pajak'
  } finally {
    saving.value = false
  }
}
</script>
