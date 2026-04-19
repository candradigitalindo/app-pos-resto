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
        <button @click="page = 1; fetchReport()"
          class="px-4 py-2 bg-emerald-600 text-white text-sm font-medium rounded-lg hover:bg-emerald-700 transition-colors shadow-sm">
          Tampilkan
        </button>
      </div>
    </AppCard>

    <AppAlert type="error" :message="errorMsg" />

    <!-- Loading -->
    <div v-if="loading" class="flex justify-center py-12">
      <AppSpinner size="lg" />
    </div>

    <template v-if="!loading && report">
      <!-- Summary Cards -->
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <SummaryCard label="Total Transaksi" :value="report.summary.total_transactions" icon="receipt" />
        <SummaryCard label="Total Pendapatan" :value="formatRupiah(report.summary.total_revenue)" icon="revenue" />
        <SummaryCard label="Rata-rata / Transaksi" :value="formatRupiah(report.summary.avg_per_transaction)" icon="avg" />
        <SummaryCard label="Metode Pembayaran" icon="payment">
          <div class="text-xs space-y-1 mt-1">
            <div class="flex justify-between"><span class="text-gray-500">Cash</span><span class="font-medium">{{ formatRupiah(report.summary.cash_revenue) }}</span></div>
            <div class="flex justify-between"><span class="text-gray-500">QRIS</span><span class="font-medium">{{ formatRupiah(report.summary.qris_revenue) }}</span></div>
            <div class="flex justify-between"><span class="text-gray-500">Card</span><span class="font-medium">{{ formatRupiah(report.summary.card_revenue) }}</span></div>
            <div class="flex justify-between"><span class="text-gray-500">Transfer</span><span class="font-medium">{{ formatRupiah(report.summary.transfer_revenue) }}</span></div>
          </div>
        </SummaryCard>
      </div>

      <!-- Unpaid Orders Summary -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <SummaryCard label="Pesanan Belum Bayar" :value="report.summary.unpaid_orders ?? 0" icon="receipt" />
        <SummaryCard label="Nominal Belum Bayar" :value="formatRupiah(report.summary.unpaid_amount ?? 0)" icon="revenue" />
      </div>

      <!-- Per Outlet -->
      <AppCard v-if="report.by_outlet && report.by_outlet.length > 1">
        <h3 class="text-sm font-semibold text-gray-700 mb-3">Pendapatan per Outlet</h3>
        <div class="overflow-x-auto">
          <table class="min-w-full text-sm">
            <thead>
              <tr class="border-b border-gray-200 text-left text-gray-500">
                <th class="py-2 pr-4 font-medium">Outlet</th>
                <th class="py-2 pr-4 font-medium text-right">Transaksi</th>
                <th class="py-2 pr-4 font-medium text-right">Pendapatan</th>
                <th class="py-2 pr-4 font-medium text-right">Belum Bayar</th>
                <th class="py-2 font-medium text-right">Nominal Belum Bayar</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="o in report.by_outlet" :key="o.outlet_id" class="border-b border-gray-100">
                <td class="py-2 pr-4">{{ o.outlet_name }}</td>
                <td class="py-2 pr-4 text-right">{{ o.total_transactions }}</td>
                <td class="py-2 pr-4 text-right font-medium">{{ formatRupiah(o.total_revenue) }}</td>
                <td class="py-2 pr-4 text-right" :class="o.unpaid_orders > 0 ? 'text-amber-600 font-semibold' : 'text-gray-400'">{{ o.unpaid_orders || 0 }}</td>
                <td class="py-2 text-right" :class="o.unpaid_amount > 0 ? 'text-amber-600 font-semibold' : 'text-gray-400'">{{ formatRupiah(o.unpaid_amount || 0) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </AppCard>

      <!-- Daily Breakdown -->
      <AppCard v-if="report.daily && report.daily.length > 0">
        <h3 class="text-sm font-semibold text-gray-700 mb-3">Penjualan Harian</h3>
        <div class="overflow-x-auto">
          <table class="min-w-full text-sm">
            <thead>
              <tr class="border-b border-gray-200 text-left text-gray-500">
                <th class="py-2 pr-4 font-medium">Tanggal</th>
                <th class="py-2 pr-4 font-medium text-right">Transaksi</th>
                <th class="py-2 pr-4 font-medium text-right">Cash</th>
                <th class="py-2 pr-4 font-medium text-right">QRIS</th>
                <th class="py-2 pr-4 font-medium text-right">Card</th>
                <th class="py-2 pr-4 font-medium text-right">Transfer</th>
                <th class="py-2 font-medium text-right">Total</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="d in report.daily" :key="d.date" class="border-b border-gray-100">
                <td class="py-2 pr-4">{{ formatDateStr(d.date) }}</td>
                <td class="py-2 pr-4 text-right">{{ d.total_transactions }}</td>
                <td class="py-2 pr-4 text-right">{{ formatRupiah(d.cash_revenue) }}</td>
                <td class="py-2 pr-4 text-right">{{ formatRupiah(d.qris_revenue) }}</td>
                <td class="py-2 pr-4 text-right">{{ formatRupiah(d.card_revenue) }}</td>
                <td class="py-2 pr-4 text-right">{{ formatRupiah(d.transfer_revenue) }}</td>
                <td class="py-2 text-right font-semibold">{{ formatRupiah(d.total_revenue) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </AppCard>

      <!-- Transaction Table -->
      <AppCard :padding="false">
        <div class="px-4 pt-4 pb-2">
          <h3 class="text-sm font-semibold text-gray-700">Detail Transaksi</h3>
        </div>
        <AppTable
          :columns="TX_COLUMNS"
          :rows="report.transactions"
          :loading="false"
          emptyText="Tidak ada transaksi pada periode ini."
        >
          <template #cell-total_amount="{ row }">
            {{ formatRupiah(row.total_amount) }}
          </template>
          <template #cell-payment_method="{ row }">
            <span class="capitalize">{{ row.payment_method }}</span>
          </template>
          <template #cell-created_at="{ row }">
            {{ formatDateTime(row.created_at) }}
          </template>
        </AppTable>
        <div class="px-4 py-3 border-t border-gray-100">
          <AppPagination v-model="page" :total="report.total" :perPage="PAGE_SIZE" />
        </div>
      </AppCard>
    </template>
  </div>
</template>

<script setup>
import { ref, watch, onMounted } from 'vue'
import { salesApi } from '@/api/sales.js'
import { outletsApi } from '@/api/outlets.js'
import { formatRupiah, formatDateTime, formatDateStr, todayDateString } from '@/utils/format.js'
import { PAGE_SIZE } from '@/utils/constants.js'
import AppCard       from '@/components/ui/AppCard.vue'
import AppTable      from '@/components/ui/AppTable.vue'
import AppAlert      from '@/components/ui/AppAlert.vue'
import AppPagination from '@/components/ui/AppPagination.vue'
import AppSpinner    from '@/components/ui/AppSpinner.vue'
import SearchSelect  from '@/components/ui/SearchSelect.vue'
import SummaryCard   from '@/components/SummaryCard.vue'

const today = todayDateString()
const dateFrom       = ref(today)
const dateTo         = ref(today)
const selectedOutlet = ref('')
const outletOptions  = ref([])
const loading        = ref(false)
const errorMsg       = ref('')
const report         = ref(null)
const page           = ref(1)

const TX_COLUMNS = [
  { key: 'outlet_name',    label: 'Outlet' },
  { key: 'cashier_name',   label: 'Kasir' },
  { key: 'payment_method', label: 'Metode Bayar' },
  { key: 'total_amount',   label: 'Total' },
  { key: 'created_at',     label: 'Waktu' },
]

onMounted(async () => {
  try {
    const data = await outletsApi.myOutlets()
    const list = data.outlets ?? data ?? []
    outletOptions.value = list.map(o => ({ value: o.id, label: o.name }))
  } catch { /* ignore */ }
  fetchReport()
})

watch(page, fetchReport)

async function fetchReport() {
  loading.value = true
  errorMsg.value = ''
  try {
    const params = {
      date_from: dateFrom.value,
      date_to: dateTo.value,
      page: page.value,
      limit: PAGE_SIZE,
    }
    if (selectedOutlet.value) params.outlet_id = selectedOutlet.value
    report.value = await salesApi.getReport(params)
  } catch (err) {
    errorMsg.value = err?.message ?? 'Gagal memuat laporan penjualan.'
  } finally {
    loading.value = false
  }
}
</script>
