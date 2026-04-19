<template>
  <div class="space-y-5">
    <!-- Header -->
    <div class="flex items-center gap-3">
      <router-link to="/vendors" class="text-gray-400 hover:text-gray-600">
        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/></svg>
      </router-link>
      <div class="flex-1">
        <h1 class="text-xl font-bold text-gray-900">{{ vendor.name || 'Detail Vendor' }}</h1>
        <p v-if="vendor.email || vendor.phone" class="text-sm text-gray-500">{{ [vendor.phone, vendor.email].filter(Boolean).join(' · ') }}</p>
      </div>
      <span v-if="vendor.id" :class="vendor.is_active
        ? 'bg-emerald-100 text-emerald-700'
        : 'bg-gray-100 text-gray-500'"
        class="px-3 py-1 rounded-full text-xs font-semibold">
        {{ vendor.is_active ? 'Aktif' : 'Nonaktif' }}
      </span>
    </div>

    <AppAlert type="error" :message="errorMsg" />

    <div v-if="loading" class="flex justify-center py-12"><AppSpinner /></div>

    <template v-if="!loading && vendor.id">
      <!-- Info Cards -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <!-- Contact Info -->
        <AppCard>
          <h3 class="text-sm font-semibold text-gray-700 mb-3">Informasi Vendor</h3>
          <div class="space-y-2 text-sm">
            <div class="flex justify-between">
              <span class="text-gray-500">Alamat</span>
              <span class="text-gray-900 text-right max-w-[60%]">{{ vendor.address || '—' }}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-500">Telepon</span>
              <span class="text-gray-900">{{ vendor.phone || '—' }}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-500">Email</span>
              <span class="text-gray-900">{{ vendor.email || '—' }}</span>
            </div>
            <div v-if="vendor.notes" class="flex justify-between">
              <span class="text-gray-500">Catatan</span>
              <span class="text-gray-900 text-right max-w-[60%]">{{ vendor.notes }}</span>
            </div>
          </div>
        </AppCard>

        <!-- Bank Info -->
        <AppCard>
          <h3 class="text-sm font-semibold text-gray-700 mb-3">Detail Pembayaran</h3>
          <div v-if="vendor.bank_name" class="space-y-2 text-sm">
            <div class="flex justify-between">
              <span class="text-gray-500">Bank</span>
              <span class="text-gray-900 font-medium">{{ vendor.bank_name }}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-500">No. Rekening</span>
              <span class="text-gray-900 font-mono">{{ vendor.account_number || '—' }}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-500">Atas Nama</span>
              <span class="text-gray-900">{{ vendor.account_holder || '—' }}</span>
            </div>
          </div>
          <p v-else class="text-sm text-gray-400 italic">Belum ada data pembayaran.</p>
        </AppCard>
      </div>

      <!-- Stats Cards -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div class="bg-white rounded-xl border border-gray-200 p-4">
          <p class="text-xs text-gray-500 uppercase tracking-wide">Total Belanja</p>
          <p class="text-lg font-bold text-gray-900 mt-1">{{ formatRupiah(totalSpent) }}</p>
        </div>
        <div class="bg-white rounded-xl border border-gray-200 p-4">
          <p class="text-xs text-gray-500 uppercase tracking-wide">Sudah Dibayar</p>
          <p class="text-lg font-bold text-emerald-600 mt-1">{{ formatRupiah(totalPaid) }}</p>
        </div>
        <div class="bg-white rounded-xl border border-gray-200 p-4">
          <p class="text-xs text-gray-500 uppercase tracking-wide">Hutang</p>
          <p class="text-lg font-bold text-red-600 mt-1">{{ formatRupiah(totalDebt) }}</p>
        </div>
        <div class="bg-white rounded-xl border border-gray-200 p-4">
          <p class="text-xs text-gray-500 uppercase tracking-wide">Menunggu</p>
          <p class="text-lg font-bold text-amber-600 mt-1">{{ formatRupiah(totalPending) }}</p>
        </div>
      </div>

      <!-- Spending Chart -->
      <AppCard>
        <h3 class="text-sm font-semibold text-gray-700 mb-4">Tren Belanja (12 Bulan Terakhir)</h3>
        <div style="height: 320px">
          <Bar v-if="chartData" :data="chartData" :options="chartOptions" />
        </div>
        <div v-if="monthlySpend.length" class="grid grid-cols-3 gap-4 mt-4 pt-4 border-t border-gray-100">
          <div class="text-center">
            <p class="text-xs text-gray-500">Total Transaksi</p>
            <p class="text-sm font-bold text-gray-800">{{ totalTxCount }} pengadaan</p>
          </div>
          <div class="text-center">
            <p class="text-xs text-gray-500">Total Nominal</p>
            <p class="text-sm font-bold text-gray-800">{{ formatRupiah(totalTxAmount) }}</p>
          </div>
          <div class="text-center">
            <p class="text-xs text-gray-500">Rata-rata/Bulan</p>
            <p class="text-sm font-bold text-gray-800">{{ formatRupiah(avgMonthly) }}</p>
          </div>
        </div>
      </AppCard>

      <!-- Purchase History -->
      <AppCard :padding="false">
        <div class="px-4 py-3 border-b border-gray-100 flex items-center justify-between">
          <h3 class="text-sm font-semibold text-gray-700">Histori Pengadaan</h3>
          <div class="flex items-center gap-2">
            <select v-model="historyFilter" @change="fetchHistory(1)"
              class="rounded-lg border border-gray-300 px-3 py-1.5 text-xs shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500">
              <option value="">Semua Status</option>
              <option value="pending">Pending</option>
              <option value="approved">Disetujui</option>
              <option value="paid">Dibayar</option>
              <option value="received">Diterima</option>
              <option value="rejected">Ditolak</option>
              <option value="cancelled">Dibatalkan</option>
            </select>
          </div>
        </div>
        <AppTable :columns="HISTORY_COLUMNS" :rows="filteredHistory" :loading="historyLoading" emptyText="Belum ada histori pengadaan.">
          <template #cell-created_at="{ row }">
            <span class="text-gray-700 text-xs">{{ formatDate(row.created_at) }}</span>
          </template>
          <template #cell-request_type="{ row }">
            <span :class="row.request_type === 'goods'
              ? 'bg-blue-100 text-blue-700'
              : 'bg-purple-100 text-purple-700'"
              class="px-2 py-0.5 rounded-full text-xs font-medium">
              {{ row.request_type === 'goods' ? 'Barang' : 'Jasa' }}
            </span>
          </template>
          <template #cell-items_summary="{ row }">
            <span class="text-gray-800 text-sm">{{ (row.items || []).map(i => i.name).join(', ') || '-' }}</span>
          </template>
          <template #cell-total_final="{ row }">
            <span class="font-medium text-gray-900">{{ formatRupiah(row.total_final || row.total_hps || row.total_amount) }}</span>
            <div v-if="row.status === 'partial' && row.paid_amount > 0" class="text-[10px] font-normal text-amber-600 mt-0.5">
              Sisa: {{ formatRupiah((row.total_final || row.total_amount || 0) - (row.paid_amount || 0)) }}
            </div>
          </template>
          <template #cell-status="{ row }">
            <span :class="statusBadge(row.status)">{{ statusLabel(row.status) }}</span>
          </template>
        </AppTable>
        <div v-if="historyTotalPages > 1" class="px-4 py-3 border-t border-gray-100">
          <AppPagination :page="historyPage" :totalPages="historyTotalPages" @update:page="fetchHistory" />
        </div>
      </AppCard>
    </template>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { vendorsApi } from '@/api/vendors.js'
import { formatRupiah } from '@/utils/format.js'
import AppCard   from '@/components/ui/AppCard.vue'
import AppTable  from '@/components/ui/AppTable.vue'
import AppAlert  from '@/components/ui/AppAlert.vue'
import AppSpinner from '@/components/ui/AppSpinner.vue'
import AppPagination from '@/components/ui/AppPagination.vue'
import {
  Chart as ChartJS,
  CategoryScale, LinearScale, BarElement, PointElement, LineElement, LineController,
  Tooltip, Legend, Filler,
} from 'chart.js'
import { Bar } from 'vue-chartjs'

ChartJS.register(CategoryScale, LinearScale, BarElement, PointElement, LineElement, LineController, Tooltip, Legend, Filler)

const route = useRoute()
const vendorId = route.params.id

const loading     = ref(true)
const errorMsg    = ref('')
const vendor      = ref({})
const totalSpent  = ref(0)
const totalPaid   = ref(0)
const totalDebt   = ref(0)
const totalPending = ref(0)
const purchaseCount = ref(0)
const monthlySpend = ref([])

// History
const historyLoading    = ref(false)
const historyPage       = ref(1)
const historyTotalPages = ref(1)
const historyData       = ref([])
const historyFilter     = ref('')

const filteredHistory = computed(() => {
  if (!historyFilter.value) return historyData.value
  return historyData.value.filter(r => r.status === historyFilter.value)
})

const HISTORY_COLUMNS = [
  { key: 'created_at',    label: 'Tanggal' },
  { key: 'request_type',  label: 'Tipe' },
  { key: 'items_summary', label: 'Pengadaan' },
  { key: 'total_final',   label: 'Nominal', align: 'right' },
  { key: 'status',        label: 'Status', align: 'center' },
]

const statusMap = {
  pending:   { label: 'Pending',          cls: 'bg-amber-100 text-amber-700' },
  approved:  { label: 'Disetujui',        cls: 'bg-blue-100 text-blue-700' },
  partial:   { label: 'Dibayar Sebagian', cls: 'bg-amber-100 text-amber-700' },
  paid:      { label: 'Dibayar',          cls: 'bg-emerald-100 text-emerald-700' },
  received:  { label: 'Diterima',         cls: 'bg-green-100 text-green-800' },
  rejected:  { label: 'Ditolak',          cls: 'bg-red-100 text-red-700' },
  cancelled: { label: 'Dibatalkan',       cls: 'bg-gray-100 text-gray-500' },
}
function statusBadge(s) {
  const m = statusMap[s] || statusMap.pending
  return `inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold ${m.cls}`
}
function statusLabel(s) { return (statusMap[s] || statusMap.pending).label }

function formatDate(s) {
  if (!s) return '-'
  return new Date(s).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' })
}

// Chart
const MONTH_SHORT = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des']

const chartData = computed(() => {
  if (!monthlySpend.value.length) return null
  const labels = monthlySpend.value.map(m => {
    const [y, mo] = m.month.split('-')
    return `${MONTH_SHORT[parseInt(mo)-1]} '${y.slice(2)}`
  })
  return {
    labels,
    datasets: [
      {
        label: 'Nominal',
        data: monthlySpend.value.map(m => m.total_amount),
        backgroundColor: 'rgba(16, 185, 129, 0.7)',
        borderColor: 'rgb(16, 185, 129)',
        borderWidth: 1,
        borderRadius: 6,
        yAxisID: 'y',
      },
      {
        label: 'Jumlah PO',
        data: monthlySpend.value.map(m => m.count),
        type: 'line',
        borderColor: 'rgb(59, 130, 246)',
        backgroundColor: 'rgba(59, 130, 246, 0.1)',
        borderWidth: 2,
        pointRadius: 4,
        pointBackgroundColor: 'rgb(59, 130, 246)',
        fill: true,
        tension: 0.3,
        yAxisID: 'y1',
      },
    ],
  }
})

const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  interaction: { intersect: false, mode: 'index' },
  plugins: {
    legend: { position: 'top', labels: { usePointStyle: true, padding: 16 } },
    tooltip: {
      callbacks: {
        label(ctx) {
          if (ctx.dataset.yAxisID === 'y1') return `Jumlah: ${ctx.raw} pengadaan`
          return `Nominal: ${formatRupiah(ctx.raw)}`
        },
      },
    },
  },
  scales: {
    y: {
      position: 'left',
      grid: { color: 'rgba(0,0,0,0.04)' },
      ticks: { callback: v => formatRupiah(v) },
    },
    y1: {
      position: 'right',
      grid: { drawOnChartArea: false },
      ticks: { stepSize: 1 },
    },
    x: { grid: { display: false } },
  },
}

const totalTxCount = computed(() => monthlySpend.value.reduce((s, m) => s + m.count, 0))
const totalTxAmount = computed(() => monthlySpend.value.reduce((s, m) => s + m.total_amount, 0))
const avgMonthly = computed(() => {
  const active = monthlySpend.value.filter(m => m.count > 0).length
  return active ? totalTxAmount.value / active : 0
})

// Fetch
onMounted(async () => {
  await Promise.all([fetchDetail(), fetchHistory(1)])
})

async function fetchDetail() {
  loading.value = true; errorMsg.value = ''
  try {
    const data = await vendorsApi.detail(vendorId)
    const d = data?.data || data
    vendor.value = d.vendor || {}
    totalSpent.value = d.total_spent || 0
    totalPaid.value = d.total_paid || 0
    totalDebt.value = d.total_debt || 0
    totalPending.value = d.total_pending || 0
    purchaseCount.value = d.purchase_count || 0
    monthlySpend.value = d.monthly_spend || []
  } catch (err) {
    errorMsg.value = err?.message ?? 'Gagal memuat data vendor.'
  } finally {
    loading.value = false
  }
}

async function fetchHistory(p) {
  historyPage.value = p || 1
  historyLoading.value = true
  try {
    const data = await vendorsApi.purchases(vendorId, { page: historyPage.value, limit: 20 })
    const d = data?.data || data
    historyData.value = d.requests || []
    historyTotalPages.value = d.total_pages || 1
  } catch { historyData.value = [] }
  finally { historyLoading.value = false }
}
</script>
