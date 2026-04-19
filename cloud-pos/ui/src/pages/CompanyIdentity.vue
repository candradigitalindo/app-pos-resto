<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-bold text-gray-900">Identitas Perusahaan</h1>
    </div>

    <AppAlert type="error" :message="errorMsg" />

    <AppCard>
      <div v-if="loading" class="flex items-center justify-center py-12">
        <AppSpinner />
      </div>

      <form v-else @submit.prevent="save" class="space-y-4 max-w-xl">
        <AppInput v-model="form.company_name" label="Nama Perusahaan" placeholder="PT. Contoh Sejahtera" />
        <AppInput v-model="form.company_address" label="Alamat" placeholder="Jl. Contoh No. 1, Jakarta" />

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <AppInput v-model="form.company_phone" label="Telepon" placeholder="021-12345678" />
          <AppInput v-model="form.company_email" label="Email" placeholder="info@perusahaan.com" type="email" />
        </div>

        <AppInput v-model="form.company_tax_id" label="NPWP" placeholder="12.345.678.9-012.345" />
        <AppInput v-model="form.company_logo_url" label="URL Logo" placeholder="https://example.com/logo.png" />

        <div v-if="form.company_logo_url" class="mt-2">
          <p class="text-xs text-gray-500 mb-1">Preview Logo:</p>
          <img
            :src="form.company_logo_url"
            alt="Logo Preview"
            class="h-16 object-contain rounded border border-gray-200 p-1 bg-white"
            @error="logoError = true"
            @load="logoError = false"
          />
          <p v-if="logoError" class="text-xs text-red-500 mt-1">Gagal memuat gambar logo</p>
        </div>

        <div class="pt-3">
          <AppButton type="submit" :loading="saving">Simpan</AppButton>
        </div>
      </form>
    </AppCard>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
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
const logoError = ref(false)

const form = ref({
  company_name: '',
  company_address: '',
  company_phone: '',
  company_email: '',
  company_tax_id: '',
  company_logo_url: '',
})

onMounted(async () => {
  try {
    const data = await settingsApi.getCompany()
    form.value = {
      company_name:     data.company_name || '',
      company_address:  data.company_address || '',
      company_phone:    data.company_phone || '',
      company_email:    data.company_email || '',
      company_tax_id:   data.company_tax_id || '',
      company_logo_url: data.company_logo_url || '',
    }
  } catch (err) {
    errorMsg.value = 'Gagal memuat data identitas perusahaan'
  } finally {
    loading.value = false
  }
})

async function save() {
  saving.value = true
  errorMsg.value = ''
  try {
    await settingsApi.updateCompany(form.value)
    toast.success('Identitas perusahaan berhasil disimpan')
  } catch (err) {
    errorMsg.value = err?.response?.data?.error || 'Gagal menyimpan data'
  } finally {
    saving.value = false
  }
}
</script>
