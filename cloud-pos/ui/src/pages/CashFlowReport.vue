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
      <!-- Cash Flow Statement -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <!-- Penerimaan -->
        <AppCard>
          <h4 class="text-xs font-bold text-gray-500 uppercase tracking-wide mb-3">Penerimaan Operasi</h4>
          <div class="space-y-2 text-sm">
            <div class="flex justify-between">
              <span class="text-gray-600">Penjualan</span>
              <span class="font-medium text-gray-800">{{ formatRupiah(report.summary.sales_receipts) }}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-600">Pemasukan Kas Lainnya</span>
              <span class="font-medium text-gray-800">{{ formatRupiah(report.summary.other_receipts) }}</span>
            </div>
            <div class="flex justify-between pt-2 border-t border-emerald-200 font-semibold">
              <span class="text-emerald-700">Total Penerimaan</span>
              <span class="text-emerald-700">{{ formatRupiah(report.summary.total_receipts) }}</span>
            </div>
          </div>
        </AppCard>

        <!-- Pengeluaran -->
        <AppCard>
          <h4 class="text-xs font-bold text-gray-500 uppercase tracking-wide mb-3">Pengeluaran Operasi</h4>
          <div class="space-y-2 text-sm">
            <div class="flex justify-between">
              <span class="text-gray-600">Pembelian Bahan Baku</span>
              <span class="font-medium text-red-600">{{ formatRupiah(report.summary.cogs_payments) }}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-600">Pembayaran Jasa</span>
              <span class="font-medium text-red-600">{{ formatRupiah(report.summary.service_payments) }}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-600">Pengeluaran Operasional</span>
              <span class="font-medium text-red-600">{{ formatRupiah(report.summary.opex_payments) }}</span>
            </div>
            <div class="flex justify-between pt-2 border-t border-red-200 font-semibold">
              <span class="text-red-600">Total Pengeluaran</span>
              <span class="text-red-600">{{ formatRupiah(report.summary.total_payments) }}</span>
            </div>
          </div>
        </AppCard>

        <!-- Arus Kas Bersih -->
        <AppCard>
          <h4 class="text-xs font-bold text-gray-500 uppercase tracking-wide mb-3">Arus Kas Bersih</h4>
          <div class="flex items-center justify-center h-20">
            <span class="text-2xl font-bold" :class="report.summary.net_cash_flow >= 0 ? 'text-emerald-700' : 'text-red-600'">
              {{ formatRupiah(report.summary.net_cash_flow) }}
            </span>
          </div>
        </AppCard>
      </div>

      <!-- Daily -->
      <AppCard v-if="report.daily?.length > 0" :padding="false">
        <div class="px-4 pt-4 pb-2">
          <h3 class="text-sm font-semibold text-gray-700">Arus Kas Harian</h3>
        </div>
        <AppTable :columns="DAILY_COLS" :rows="report.daily" :loading="false" emptyText="Tidak ada data.">
          <template #cell-date="{ row }">{{ formatDateStr(row.date) }}</template>
          <template #cell-sales_receipts="{ row }">{{ formatRupiah(row.sales_receipts) }}</template>
          <template #cell-other_receipts="{ row }">{{ formatRupiah(row.other_receipts) }}</template>
          <template #cell-cogs_payments="{ row }">
            <span class="text-red-600">{{ formatRupiah(row.cogs_payments) }}</span>
          </template>
          <template #cell-service_payments="{ row }">
            <span class="text-red-600">{{ formatRupiah(row.service_payments) }}</span>
          </template>
          <template #cell-opex_payments="{ row }">
            <span class="text-red-600">{{ formatRupiah(row.opex_payments) }}</span>
          </template>
          <template #cell-net_cash_flow="{ row }">
            <span :class="row.net_cash_flow >= 0 ? 'text-emerald-700 font-semibold' : 'text-red-600 font-semibold'">
              {{ formatRupiah(row.net_cash_flow) }}
            </span>
          </template>
        </AppTable>
      </AppCard>
    </template>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { salesApi }    from '@/api/sales.js'
import { outletsApi }  from '@/api/outlets.js'
import { formatRupiah, formatDateStr, todayDateString } from '@/utils/format.js'
import AppCard      from '@/components/ui/AppCard.vue'
import AppTable     from '@/components/ui/AppTable.vue'
import AppAlert     from '@/components/ui/AppAlert.vue'
import AppSpinner   from '@/components/ui/AppSpinner.vue'
import SearchSelect from '@/components/ui/SearchSelect.vue'

const today = todayDateString()
const dateFrom       = ref(today)
const dateTo         = ref(today)
const selectedOutlet = ref('')
const outletOptions  = ref([])
const loading        = ref(false)
const errorMsg       = ref('')
const report         = ref(null)

const DAILY_COLS = [
  { key: 'date',             label: 'Tanggal' },
  { key: 'sales_receipts',   label: 'Penjualan', align: 'right' },
  { key: 'other_receipts',   label: 'Kas Masuk', align: 'right' },
  { key: 'cogs_payments',    label: 'Bahan Baku', align: 'right' },
  { key: 'service_payments', label: 'Jasa', align: 'right' },
  { key: 'opex_payments',    label: 'Opex', align: 'right' },
  { key: 'net_cash_flow',    label: 'Arus Bersih', align: 'right' },
]

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
    report.value = await salesApi.getCashFlowReport(params)
  } catch (err) {
    errorMsg.value = err?.message ?? 'Gagal memuat laporan arus kas.'
  } finally {
    loading.value = false
  }
}
</script>
