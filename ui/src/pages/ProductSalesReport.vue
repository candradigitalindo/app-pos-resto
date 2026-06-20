<template>
  <div class="space-y-6">

    <!-- Filter Bar -->
    <AppCard>
      <div class="flex flex-wrap items-end gap-4">
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-gray-700">Dari Tanggal</label>
          <input type="date" v-model="dateFrom"
            class="rounded-lg border border-gray-300 px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-brand-500" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-gray-700">Sampai Tanggal</label>
          <input type="date" v-model="dateTo"
            class="rounded-lg border border-gray-300 px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-brand-500" />
        </div>
        <div class="flex flex-col gap-1 min-w-45">
          <label class="text-sm font-medium text-gray-700">Outlet</label>
          <SearchSelect
            v-model="selectedOutlet"
            :options="outletOptions"
            placeholder="Semua Outlet"
            searchPlaceholder="Cari outlet..."
            valueKey="value"
            labelKey="label"
          />
        </div>
        <button @click="fetchReport"
          class="px-4 py-2 bg-emerald-600 text-white text-sm font-medium rounded-lg hover:bg-emerald-700 transition-colors shadow-sm">
          Tampilkan
        </button>
      </div>
    </AppCard>

    <AppAlert type="error" :message="errorMsg" />

    <div v-if="loading" class="flex justify-center py-12">
      <AppSpinner size="lg" />
    </div>

    <template v-if="!loading && report">
      <!-- Summary -->
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <SummaryCard label="Total Produk" :value="report.total" icon="receipt" />
        <SummaryCard label="Total Qty Terjual" :value="totalQty" icon="avg" />
        <SummaryCard label="Total Pendapatan" :value="formatRupiah(totalRevenue)" icon="revenue" />
      </div>

      <!-- Table -->
      <AppCard :padding="false">
        <div class="px-4 pt-4 pb-2 flex items-center justify-between">
          <h3 class="text-sm font-semibold text-gray-700">Penjualan per Produk</h3>
          <span class="text-xs text-gray-400">{{ formatDateStr(report.date_from) }} s/d {{ formatDateStr(report.date_to) }}</span>
        </div>
        <AppTable :columns="COLUMNS" :rows="report.items" :loading="false" emptyText="Tidak ada data penjualan produk.">
          <template #cell-total_revenue="{ row }">
            {{ formatRupiah(row.total_revenue) }}
          </template>
          <template #cell-pct="{ row }">
            <div class="flex items-center gap-2">
              <div class="flex-1 bg-gray-100 rounded-full h-1.5">
                <div class="bg-emerald-500 h-1.5 rounded-full" :style="{ width: pct(row.total_revenue) + '%' }" />
              </div>
              <span class="text-xs text-gray-500 w-10 text-right">{{ pct(row.total_revenue) }}%</span>
            </div>
          </template>
        </AppTable>
      </AppCard>
    </template>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { salesApi }    from '@/api/sales.js'
import { outletsApi }  from '@/api/outlets.js'
import { formatRupiah, formatDateStr, todayDateString } from '@/utils/format.js'
import AppCard      from '@/components/ui/AppCard.vue'
import AppTable     from '@/components/ui/AppTable.vue'
import AppAlert     from '@/components/ui/AppAlert.vue'
import AppSpinner   from '@/components/ui/AppSpinner.vue'
import SearchSelect from '@/components/ui/SearchSelect.vue'
import SummaryCard  from '@/components/SummaryCard.vue'

const today = todayDateString()
const dateFrom       = ref(today)
const dateTo         = ref(today)
const selectedOutlet = ref('')
const outletOptions  = ref([])
const loading        = ref(false)
const errorMsg       = ref('')
const report         = ref(null)

const COLUMNS = [
  { key: 'product_name',  label: 'Nama Produk' },
  { key: 'category_name', label: 'Kategori' },
  { key: 'total_qty',     label: 'Qty', align: 'right' },
  { key: 'total_revenue', label: 'Pendapatan', align: 'right' },
  { key: 'pct',           label: '% Kontribusi' },
]

const totalQty     = computed(() => report.value?.items?.reduce((s, r) => s + r.total_qty, 0) ?? 0)
const totalRevenue = computed(() => report.value?.items?.reduce((s, r) => s + r.total_revenue, 0) ?? 0)

function pct(val) {
  if (!totalRevenue.value) return 0
  return Math.round((val / totalRevenue.value) * 1000) / 10
}

onMounted(async () => {
  try {
    const data = await outletsApi.myOutlets()
    const list = data.outlets ?? data ?? []
    outletOptions.value = list.map(o => ({ value: o.id, label: o.name }))
  } catch { /* ignore */ }
  fetchReport()
})

async function fetchReport() {
  loading.value = true
  errorMsg.value = ''
  try {
    const params = { date_from: dateFrom.value, date_to: dateTo.value }
    if (selectedOutlet.value) params.outlet_id = selectedOutlet.value
    report.value = await salesApi.getProductSalesReport(params)
  } catch (err) {
    errorMsg.value = err?.message ?? 'Gagal memuat laporan penjualan produk.'
  } finally {
    loading.value = false
  }
}
</script>
