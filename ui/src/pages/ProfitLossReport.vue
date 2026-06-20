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
      <!-- F&B Profit & Loss Statement -->
      <AppCard>
        <h3 class="text-sm font-bold text-gray-800 uppercase tracking-wide mb-4">Laporan Laba Rugi F&B</h3>
        <div class="space-y-1 text-sm">
          <!-- Pendapatan -->
          <div class="flex justify-between py-1.5">
            <span class="text-gray-600 pl-4">Penjualan Makanan & Minuman</span>
            <span class="font-medium text-gray-800">{{ formatRupiah(report.summary.sales_revenue) }}</span>
          </div>
          <div class="flex justify-between py-1.5">
            <span class="text-gray-600 pl-4">Pendapatan Lainnya</span>
            <span class="font-medium text-gray-800">{{ formatRupiah(report.summary.other_income) }}</span>
          </div>
          <div class="flex justify-between py-2 border-t border-gray-200 font-semibold">
            <span class="text-gray-800">Total Pendapatan</span>
            <span class="text-emerald-700">{{ formatRupiah(report.summary.total_revenue) }}</span>
          </div>

          <!-- HPP -->
          <div class="flex justify-between py-1.5 mt-2">
            <span class="text-gray-600 pl-4">Harga Pokok Penjualan (Bahan Baku)</span>
            <span class="font-medium text-red-600">{{ formatRupiah(report.summary.cogs) }}</span>
          </div>
          <div class="flex justify-between py-2 border-t border-gray-200 font-semibold">
            <span class="text-gray-800">Laba Kotor</span>
            <span :class="report.summary.gross_profit >= 0 ? 'text-emerald-700' : 'text-red-600'">
              {{ formatRupiah(report.summary.gross_profit) }}
              <span class="text-xs font-normal text-gray-500 ml-1">({{ report.summary.gross_margin.toFixed(1) }}%)</span>
            </span>
          </div>

          <!-- Beban Operasional -->
          <div class="flex justify-between py-1.5 mt-2">
            <span class="text-gray-600 pl-4">Beban Jasa & Layanan</span>
            <span class="font-medium text-red-600">{{ formatRupiah(report.summary.service_expense) }}</span>
          </div>
          <div class="flex justify-between py-1.5">
            <span class="text-gray-600 pl-4">Beban Operasional Outlet</span>
            <span class="font-medium text-red-600">{{ formatRupiah(report.summary.operating_expense) }}</span>
          </div>
          <div class="flex justify-between py-2 border-t border-gray-200 font-semibold">
            <span class="text-gray-800">Total Beban Operasional</span>
            <span class="text-red-600">{{ formatRupiah(report.summary.total_opex) }}</span>
          </div>

          <!-- Laba Operasional -->
          <div class="flex justify-between py-2 border-t-2 border-gray-300 font-bold">
            <span class="text-gray-800">Laba Operasional</span>
            <span :class="report.summary.operating_profit >= 0 ? 'text-emerald-700' : 'text-red-600'">
              {{ formatRupiah(report.summary.operating_profit) }}
            </span>
          </div>

          <!-- Pajak -->
          <div class="flex justify-between py-1.5 mt-2">
            <span class="text-gray-600 pl-4">Pajak Restoran (PB1)</span>
            <span class="font-medium text-red-600">{{ formatRupiah(report.summary.tax_expense) }}</span>
          </div>

          <!-- Laba Bersih -->
          <div class="flex justify-between py-3 border-t-2 border-emerald-300 font-bold text-base mt-2 bg-emerald-50 -mx-4 px-4 rounded-b-lg">
            <span class="text-gray-900">Laba Bersih</span>
            <span :class="report.summary.net_profit >= 0 ? 'text-emerald-700' : 'text-red-600'">
              {{ formatRupiah(report.summary.net_profit) }}
              <span class="text-xs font-normal text-gray-500 ml-1">({{ report.summary.net_margin.toFixed(1) }}%)</span>
            </span>
          </div>
        </div>
      </AppCard>

      <!-- Daily -->
      <AppCard v-if="report.daily?.length > 0" :padding="false">
        <div class="px-4 pt-4 pb-2">
          <h3 class="text-sm font-semibold text-gray-700">Laba Rugi Harian</h3>
        </div>
        <AppTable :columns="DAILY_COLS" :rows="report.daily" :loading="false" emptyText="Tidak ada data.">
          <template #cell-date="{ row }">{{ formatDateStr(row.date) }}</template>
          <template #cell-revenue="{ row }">{{ formatRupiah(row.revenue) }}</template>
          <template #cell-cogs="{ row }">
            <span class="text-red-600">{{ formatRupiah(row.cogs) }}</span>
          </template>
          <template #cell-gross_profit="{ row }">
            <span :class="row.gross_profit >= 0 ? 'text-emerald-700' : 'text-red-600'">{{ formatRupiah(row.gross_profit) }}</span>
          </template>
          <template #cell-operating_expense="{ row }">
            <span class="text-red-600">{{ formatRupiah(row.operating_expense) }}</span>
          </template>
          <template #cell-net_profit="{ row }">
            <span :class="row.net_profit >= 0 ? 'text-emerald-700 font-semibold' : 'text-red-600 font-semibold'">
              {{ formatRupiah(row.net_profit) }}
            </span>
          </template>
        </AppTable>
      </AppCard>

      <!-- By Outlet -->
      <AppCard v-if="report.by_outlet?.length > 1" :padding="false">
        <div class="px-4 pt-4 pb-2">
          <h3 class="text-sm font-semibold text-gray-700">Per Outlet</h3>
        </div>
        <AppTable :columns="OUTLET_COLS" :rows="report.by_outlet" :loading="false" emptyText="Tidak ada data.">
          <template #cell-revenue="{ row }">{{ formatRupiah(row.revenue) }}</template>
          <template #cell-cogs="{ row }">
            <span class="text-red-600">{{ formatRupiah(row.cogs) }}</span>
          </template>
          <template #cell-operating_expense="{ row }">
            <span class="text-red-600">{{ formatRupiah(row.operating_expense) }}</span>
          </template>
          <template #cell-net_profit="{ row }">
            <span :class="row.net_profit >= 0 ? 'text-emerald-700 font-semibold' : 'text-red-600 font-semibold'">
              {{ formatRupiah(row.net_profit) }}
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
  { key: 'date',              label: 'Tanggal' },
  { key: 'revenue',           label: 'Pendapatan', align: 'right' },
  { key: 'cogs',              label: 'HPP', align: 'right' },
  { key: 'gross_profit',      label: 'Laba Kotor', align: 'right' },
  { key: 'operating_expense', label: 'Beban Opex', align: 'right' },
  { key: 'net_profit',        label: 'Laba Bersih', align: 'right' },
]

const OUTLET_COLS = [
  { key: 'outlet_name',       label: 'Outlet' },
  { key: 'revenue',           label: 'Pendapatan', align: 'right' },
  { key: 'cogs',              label: 'HPP', align: 'right' },
  { key: 'operating_expense', label: 'Beban Opex', align: 'right' },
  { key: 'net_profit',        label: 'Laba Bersih', align: 'right' },
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
    report.value = await salesApi.getProfitLossReport(params)
  } catch (err) {
    errorMsg.value = err?.message ?? 'Gagal memuat laporan profit & loss.'
  } finally {
    loading.value = false
  }
}
</script>
