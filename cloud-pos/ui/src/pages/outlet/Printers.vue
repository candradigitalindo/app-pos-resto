<!--
  Printers.vue — Printer list for one outlet
  ───────────────────────────────────────────────────────────────
  Route: /outlets/:id/printers   (child of OutletDetail)
  Data: pushed from local POS via POST /outlets/:id/printers

  AI NOTE: Printers are read-only here (managed from local POS).
  The local POS pushes them via enqueuePrinterSync().
-->
<template>
  <div class="space-y-4">
    <AppAlert type="error" :message="errorMsg" />
    <AppCard :padding="false">
      <AppTable :columns="COLUMNS" :rows="items" :loading="loading" emptyText="Belum ada printer.">
        <template #cell-is_active="{ row }">
          <AppBadge :status="row.is_active ? 'active' : 'inactive'" />
        </template>
        <template #cell-printer_type="{ row }">
          <span class="capitalize">{{ row.printer_type }}</span>
        </template>
      </AppTable>
    </AppCard>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute } from 'vue-router'
import { outletsApi } from '@/api/outlets.js'
import AppCard  from '@/components/ui/AppCard.vue'
import AppTable from '@/components/ui/AppTable.vue'
import AppBadge from '@/components/ui/AppBadge.vue'
import AppAlert from '@/components/ui/AppAlert.vue'

const route    = useRoute()
const outletId = computed(() => route.params.id)

const COLUMNS = [
  { key: 'name',         label: 'Nama Printer' },
  { key: 'printer_type', label: 'Tipe' },
  { key: 'ip_address',   label: 'IP Address', class: 'font-mono text-xs' },
  { key: 'port',         label: 'Port', class: 'font-mono text-xs' },
  { key: 'paper_size',   label: 'Kertas' },
  { key: 'is_active',    label: 'Status' },
]

const items = ref([]); const loading = ref(false); const errorMsg = ref('')

onMounted(async () => {
  loading.value = true; errorMsg.value = ''
  try {
    const res   = await outletsApi.printers(outletId.value)
    items.value = res.data?.data ?? res.data ?? []
  } catch (err) {
    errorMsg.value = err?.response?.data?.message ?? 'Gagal memuat printer.'
  } finally { loading.value = false }
})
</script>
