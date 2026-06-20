<!--
  Categories.vue — Category list with code_prefix + printer assignment
  ───────────────────────────────────────────────────────────────
  Route: /outlets/:id/categories   (child of OutletDetail)

  Features:
  - List categories with code_prefix
  - Inline printer assignment select (uses outlet's printer list)
  - PUT /outlets/:id/categories/:catId/printer

  AI NOTE: Printer list is loaded once from outletsApi.printers(outletId).
  The "Tidak ada printer" option clears the assignment.
-->
<template>
  <div class="space-y-4">
    <AppAlert type="error" :message="errorMsg" />
    <AppCard :padding="false">
      <AppTable :columns="COLUMNS" :rows="items" :loading="loading" emptyText="Belum ada kategori.">
        <template #cell-code_prefix="{ row }">
          <span class="font-mono text-xs bg-gray-100 px-2 py-0.5 rounded">{{ row.code_prefix || '—' }}</span>
        </template>

        <template #cell-printer="{ row }">
          <!-- Searchable inline select for printer assignment -->
          <div style="min-width:200px; display:inline-block;">
            <SearchSelect
              :modelValue="row.printer_id ?? ''"
              :options="printerOptions"
              placeholder="Pilih printer…"
              searchPlaceholder="Cari printer…"
              :disabled="!!savingCategoryId"
              @change="v => assignPrinter(row, v)"
            />
          </div>
          <AppSpinner v-if="savingCategoryId === row.id" size="sm" class="ml-2 inline" />
        </template>
      </AppTable>
    </AppCard>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute } from 'vue-router'
import { outletsApi } from '@/api/outlets.js'
import { useToastStore } from '@/stores/toast.js'
import AppCard    from '@/components/ui/AppCard.vue'
import AppTable   from '@/components/ui/AppTable.vue'
import AppAlert   from '@/components/ui/AppAlert.vue'
import AppSpinner from '@/components/ui/AppSpinner.vue'
import SearchSelect from '@/components/ui/SearchSelect.vue'

const route    = useRoute()
const outletId = computed(() => route.params.id)
const toast    = useToastStore()

const COLUMNS = [
  { key: 'name',        label: 'Nama Kategori' },
  { key: 'code_prefix', label: 'Prefix Kode' },
  { key: 'printer',     label: 'Printer Cetak', class: 'min-w-[200px]' },
]

const items            = ref([])
const printers         = ref([])
const loading          = ref(false)
const errorMsg         = ref('')
const savingCategoryId = ref(null)

// Searchable printer options
const printerOptions = computed(() => [
  { id: '', name: '— Tidak ada printer —' },
  ...printers.value.map(p => ({ id: p.id, name: `${p.name} (${p.printer_type})` })),
])

onMounted(async () => {
  loading.value = true; errorMsg.value = ''
  try {
    const [catRes, printerRes] = await Promise.all([
      outletsApi.categories(outletId.value),
      outletsApi.printers(outletId.value),
    ])
    items.value    = catRes.data?.data     ?? catRes.data    ?? []
    printers.value = printerRes.data?.data ?? printerRes.data ?? []
  } catch (err) {
    errorMsg.value = err?.response?.data?.message ?? 'Gagal memuat data kategori.'
  } finally { loading.value = false }
})

async function assignPrinter(category, printerId) {
  savingCategoryId.value = category.id
  try {
    await outletsApi.updateCategoryPrinter(outletId.value, category.id, printerId || null)
    category.printer_id = printerId || null
    toast.success('Printer kategori diperbarui.')
  } catch (err) {
    toast.error(err?.response?.data?.message ?? 'Gagal mengubah printer kategori.')
  } finally {
    savingCategoryId.value = null
  }
}
</script>
