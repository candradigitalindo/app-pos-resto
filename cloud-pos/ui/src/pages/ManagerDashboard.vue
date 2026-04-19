<!--
  ManagerDashboard.vue — Executive Manager Dashboard
  Route: /manager-dashboard
  A powerful, data-rich dashboard for managerial decision-making.
  Charts: revenue trend, order trend, hourly pattern, payment mix, top products, outlet ranking.
-->
<template>
  <div class="space-y-6">

    <!-- ── Header ── -->
    <div class="flex flex-col sm:flex-row sm:items-end justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Manager Dashboard</h1>
        <p class="text-sm text-gray-500 mt-1">Ringkasan performa bisnis untuk pengambilan keputusan</p>
      </div>
      <div class="flex items-center gap-2 px-3 py-1.5 bg-white border border-gray-200 rounded-full text-xs text-gray-500 shadow-sm">
        <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><rect x="3" y="4" width="18" height="18" rx="2" stroke-width="2"/><line x1="16" y1="2" x2="16" y2="6" stroke-width="2"/><line x1="8" y1="2" x2="8" y2="6" stroke-width="2"/><line x1="3" y1="10" x2="21" y2="10" stroke-width="2"/></svg>
        <span class="font-medium text-gray-700">{{ currentDate }}</span>
        <span class="w-1.5 h-1.5 bg-emerald-500 rounded-full animate-pulse" />
        <span class="font-medium text-emerald-600">Live</span>
      </div>
    </div>

    <!-- ── Loading ── -->
    <div v-if="loading" class="py-20 flex flex-col items-center gap-3">
      <AppSpinner size="lg" class="text-blue-600" />
      <p class="text-sm text-gray-400">Memuat data dashboard...</p>
    </div>

    <!-- ── Error ── -->
    <AppAlert v-if="errorMsg" type="error" :message="errorMsg" />

    <template v-if="!loading && data">

      <!-- ═══ KPI Cards ═══ -->
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div v-for="kpi in KPI_CARDS" :key="kpi.key" class="kpi-card group" :class="kpi.color">
          <div class="flex items-center justify-between mb-3">
            <span class="kpi-icon" v-html="kpi.icon" />
            <span v-if="kpi.prevKey" :class="['kpi-trend', trendDir(data[kpi.key], data[kpi.prevKey])]">
              <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="3">
                <polyline v-if="data[kpi.key] >= data[kpi.prevKey]" points="18 15 12 9 6 15"/>
                <polyline v-else points="6 9 12 15 18 9"/>
              </svg>
              {{ pctChange(data[kpi.key], data[kpi.prevKey]) }}
            </span>
          </div>
          <p class="text-xs font-medium text-gray-500 uppercase tracking-wider mb-1">{{ kpi.label }}</p>
          <p class="text-xl sm:text-2xl font-bold text-gray-900 tabular-nums">{{ fmtKPI(kpi, data[kpi.key]) }}</p>
          <p v-if="kpi.sub" class="text-xs text-gray-400 mt-1">{{ kpi.sub(data) }}</p>
        </div>
      </div>

      <!-- ═══ Row 1: Revenue Trend + Payment Mix ═══ -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <!-- Revenue Trend (30 hari) -->
        <div class="chart-card lg:col-span-2">
          <div class="chart-header">
            <div>
              <h3 class="chart-title">Tren Pendapatan</h3>
              <p class="chart-sub">30 hari terakhir</p>
            </div>
            <div class="flex items-center gap-4 text-xs">
              <span class="flex items-center gap-1.5"><span class="w-2.5 h-2.5 rounded-full bg-blue-500"></span>Pendapatan</span>
              <span class="flex items-center gap-1.5"><span class="w-2.5 h-2.5 rounded-full bg-emerald-400"></span>Pesanan</span>
            </div>
          </div>
          <div class="chart-body">
            <Line v-if="revenueTrendData" :data="revenueTrendData" :options="revenueTrendOpts" />
          </div>
        </div>

        <!-- Payment Methods (Donut) -->
        <div class="chart-card">
          <div class="chart-header">
            <div>
              <h3 class="chart-title">Metode Pembayaran</h3>
              <p class="chart-sub">Bulan ini</p>
            </div>
          </div>
          <div class="chart-body flex items-center justify-center">
            <div class="w-full max-w-[220px]">
              <Doughnut v-if="paymentData" :data="paymentData" :options="doughnutOpts" />
            </div>
          </div>
          <div class="px-5 pb-4 space-y-2">
            <div v-for="pm in data.payment_methods" :key="pm.method" class="flex items-center justify-between text-xs">
              <span class="flex items-center gap-2">
                <span class="w-2.5 h-2.5 rounded-full" :style="{ background: pmColor(pm.method) }" />
                <span class="font-medium text-gray-700 capitalize">{{ pmLabel(pm.method) }}</span>
              </span>
              <span class="font-semibold text-gray-900 tabular-nums">{{ formatRupiah(pm.amount) }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- ═══ Row 2: Hourly Pattern + Top Products ═══ -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <!-- Hourly Sales Pattern -->
        <div class="chart-card">
          <div class="chart-header">
            <div>
              <h3 class="chart-title">Pola Penjualan Per Jam</h3>
              <p class="chart-sub">Hari ini — identifikasi jam sibuk</p>
            </div>
          </div>
          <div class="chart-body">
            <Bar v-if="hourlyData" :data="hourlyData" :options="hourlyOpts" />
          </div>
        </div>

        <!-- Top Products -->
        <div class="chart-card">
          <div class="chart-header">
            <div>
              <h3 class="chart-title">Produk Terlaris</h3>
              <p class="chart-sub">10 teratas bulan ini</p>
            </div>
          </div>
          <div class="chart-body-table">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-gray-100">
                  <th class="text-left py-2 px-4 text-xs font-semibold text-gray-500 uppercase tracking-wider">#</th>
                  <th class="text-left py-2 px-4 text-xs font-semibold text-gray-500 uppercase tracking-wider">Produk</th>
                  <th class="text-right py-2 px-4 text-xs font-semibold text-gray-500 uppercase tracking-wider">Qty</th>
                  <th class="text-right py-2 px-4 text-xs font-semibold text-gray-500 uppercase tracking-wider">Revenue</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(p, i) in data.top_products" :key="p.name" class="border-b border-gray-50 hover:bg-gray-50/60 transition-colors">
                  <td class="py-2.5 px-4">
                    <span :class="['inline-flex items-center justify-center w-6 h-6 rounded-full text-xs font-bold', i < 3 ? 'bg-amber-100 text-amber-700' : 'bg-gray-100 text-gray-500']">{{ i + 1 }}</span>
                  </td>
                  <td class="py-2.5 px-4 font-medium text-gray-800">{{ p.name }}</td>
                  <td class="py-2.5 px-4 text-right tabular-nums text-gray-600">{{ p.quantity.toLocaleString('id-ID') }}</td>
                  <td class="py-2.5 px-4 text-right tabular-nums font-medium text-gray-800">{{ formatRupiah(p.revenue) }}</td>
                </tr>
                <tr v-if="!data.top_products?.length">
                  <td colspan="4" class="py-8 text-center text-gray-400 text-sm">Belum ada data produk bulan ini.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- ═══ Row 3: Outlet Ranking Table ═══ -->
      <div class="chart-card">
        <div class="chart-header">
          <div>
            <h3 class="chart-title">Performa Outlet</h3>
            <p class="chart-sub">Ranking berdasarkan pendapatan bulan ini</p>
          </div>
          <RouterLink to="/outlets" class="text-xs text-blue-600 hover:text-blue-700 font-semibold flex items-center gap-1">
            Lihat Detail
            <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
          </RouterLink>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-gray-200 bg-gray-50/60">
                <th class="text-left py-3 px-4 text-xs font-semibold text-gray-500 uppercase tracking-wider">#</th>
                <th class="text-left py-3 px-4 text-xs font-semibold text-gray-500 uppercase tracking-wider">Outlet</th>
                <th class="text-right py-3 px-4 text-xs font-semibold text-gray-500 uppercase tracking-wider">Hari Ini</th>
                <th class="text-right py-3 px-4 text-xs font-semibold text-gray-500 uppercase tracking-wider">Bulan Ini</th>
                <th class="text-right py-3 px-4 text-xs font-semibold text-gray-500 uppercase tracking-wider">Order Hari Ini</th>
                <th class="text-right py-3 px-4 text-xs font-semibold text-gray-500 uppercase tracking-wider">Order Bulan Ini</th>
                <th class="py-3 px-4 text-xs font-semibold text-gray-500 uppercase tracking-wider text-center">Kontribusi</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(o, i) in data.outlet_ranking" :key="o.id" class="border-b border-gray-50 hover:bg-blue-50/30 transition-colors">
                <td class="py-3 px-4">
                  <span :class="['inline-flex items-center justify-center w-7 h-7 rounded-lg text-xs font-bold', rankClass(i)]">{{ i + 1 }}</span>
                </td>
                <td class="py-3 px-4">
                  <RouterLink :to="`/outlets/${o.id}`" class="font-semibold text-gray-800 hover:text-blue-600 transition-colors">{{ o.name }}</RouterLink>
                </td>
                <td class="py-3 px-4 text-right tabular-nums font-medium text-gray-800">{{ formatRupiah(o.today_revenue) }}</td>
                <td class="py-3 px-4 text-right tabular-nums font-semibold text-gray-900">{{ formatRupiah(o.month_revenue) }}</td>
                <td class="py-3 px-4 text-right tabular-nums text-gray-600">{{ o.today_orders }}</td>
                <td class="py-3 px-4 text-right tabular-nums text-gray-600">{{ o.month_orders }}</td>
                <td class="py-3 px-4">
                  <div class="flex items-center gap-2 justify-center">
                    <div class="w-20 h-2 bg-gray-100 rounded-full overflow-hidden">
                      <div class="h-full bg-blue-500 rounded-full transition-all" :style="{ width: contribution(o.month_revenue) + '%' }" />
                    </div>
                    <span class="text-xs font-medium text-gray-500 tabular-nums w-10 text-right">{{ contribution(o.month_revenue).toFixed(1) }}%</span>
                  </div>
                </td>
              </tr>
              <tr v-if="!data.outlet_ranking?.length">
                <td colspan="7" class="py-8 text-center text-gray-400 text-sm">Belum ada data outlet.</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- ═══ Quick Insight Cards ═══ -->
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <!-- Unpaid Alert -->
        <div class="insight-card border-amber-200 bg-amber-50/50">
          <div class="flex items-center gap-3 mb-2">
            <div class="w-9 h-9 rounded-lg bg-amber-100 flex items-center justify-center">
              <svg class="w-5 h-5 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z"/></svg>
            </div>
            <div>
              <p class="text-xs font-semibold text-amber-800 uppercase tracking-wider">Pesanan Belum Lunas</p>
              <p class="text-lg font-bold text-amber-900 tabular-nums">{{ data.unpaid_orders }} pesanan</p>
            </div>
          </div>
          <p class="text-sm font-semibold text-amber-700 tabular-nums">{{ formatRupiah(data.unpaid_amount) }}</p>
        </div>

        <!-- Active Outlets -->
        <div class="insight-card border-blue-200 bg-blue-50/50">
          <div class="flex items-center gap-3 mb-2">
            <div class="w-9 h-9 rounded-lg bg-blue-100 flex items-center justify-center">
              <svg class="w-5 h-5 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/></svg>
            </div>
            <div>
              <p class="text-xs font-semibold text-blue-800 uppercase tracking-wider">Outlet Aktif</p>
              <p class="text-lg font-bold text-blue-900 tabular-nums">{{ data.active_outlets }} outlet</p>
            </div>
          </div>
          <p class="text-sm text-blue-600">Beroperasi dan terhubung</p>
        </div>

        <!-- Total Products -->
        <div class="insight-card border-emerald-200 bg-emerald-50/50">
          <div class="flex items-center gap-3 mb-2">
            <div class="w-9 h-9 rounded-lg bg-emerald-100 flex items-center justify-center">
              <svg class="w-5 h-5 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/></svg>
            </div>
            <div>
              <p class="text-xs font-semibold text-emerald-800 uppercase tracking-wider">Total Produk</p>
              <p class="text-lg font-bold text-emerald-900 tabular-nums">{{ data.total_products }} item</p>
            </div>
          </div>
          <p class="text-sm text-emerald-600">Produk aktif terdaftar</p>
        </div>
      </div>

    </template>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { Line, Bar, Doughnut } from 'vue-chartjs'
import {
  Chart as ChartJS,
  LineElement, BarElement, PointElement, ArcElement,
  CategoryScale, LinearScale,
  Tooltip, Legend, Filler
} from 'chart.js'
import { apiClient } from '@/api/client.js'
import { formatRupiah } from '@/utils/format.js'
import AppSpinner from '@/components/ui/AppSpinner.vue'
import AppAlert from '@/components/ui/AppAlert.vue'

ChartJS.register(LineElement, BarElement, PointElement, ArcElement, CategoryScale, LinearScale, Tooltip, Legend, Filler)

const data     = ref(null)
const loading  = ref(false)
const errorMsg = ref('')

const currentDate = new Date().toLocaleDateString('id-ID', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })

// ── KPI card definitions ────────────────────────────────────
const KPI_CARDS = [
  {
    key: 'today_revenue', prevKey: 'yesterday_revenue', label: 'Pendapatan Hari Ini',
    color: 'kpi-emerald', fmt: 'rupiah',
    icon: '<svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>',
    sub: (d) => `Kemarin: ${formatRupiah(d.yesterday_revenue)}`,
  },
  {
    key: 'today_orders', prevKey: 'yesterday_orders', label: 'Pesanan Hari Ini',
    color: 'kpi-blue', fmt: 'number',
    icon: '<svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"/></svg>',
    sub: (d) => `Kemarin: ${d.yesterday_orders} pesanan`,
  },
  {
    key: 'month_revenue', prevKey: 'month_revenue_prev', label: 'Pendapatan Bulan Ini',
    color: 'kpi-violet', fmt: 'rupiah',
    icon: '<svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/></svg>',
    sub: (d) => `Bulan lalu: ${formatRupiah(d.month_revenue_prev)}`,
  },
  {
    key: 'today_avg_order', label: 'Rata-rata per Order',
    color: 'kpi-amber', fmt: 'rupiah',
    icon: '<svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M7 12l3-3 3 3 4-4M8 21l4-4 4 4M3 4h18M4 4h16v12a1 1 0 01-1 1H5a1 1 0 01-1-1V4z"/></svg>',
    sub: (d) => `Total ${d.today_orders} pesanan hari ini`,
  },
]

// ── Data fetching ───────────────────────────────────────────
onMounted(fetchData)

async function fetchData() {
  loading.value = true
  errorMsg.value = ''
  try {
    data.value = await apiClient.get('/admin/manager-dashboard')
  } catch (err) {
    errorMsg.value = err?.message ?? 'Gagal memuat data dashboard.'
  } finally {
    loading.value = false
  }
}

// ── Formatters ──────────────────────────────────────────────
function fmtKPI(kpi, val) {
  if (val == null) return '—'
  if (kpi.fmt === 'rupiah') return formatRupiah(val)
  return Number(val).toLocaleString('id-ID')
}

function pctChange(curr, prev) {
  if (!prev) return curr > 0 ? '+100%' : '0%'
  const pct = ((curr - prev) / prev * 100).toFixed(1)
  return (pct > 0 ? '+' : '') + pct + '%'
}

function trendDir(curr, prev) {
  if (curr >= prev) return 'trend-up'
  return 'trend-down'
}

function contribution(monthRevenue) {
  const total = data.value?.outlet_ranking?.reduce((s, o) => s + o.month_revenue, 0) || 1
  return (monthRevenue / total) * 100
}

function rankClass(i) {
  if (i === 0) return 'bg-amber-100 text-amber-700'
  if (i === 1) return 'bg-gray-200 text-gray-700'
  if (i === 2) return 'bg-orange-100 text-orange-700'
  return 'bg-gray-100 text-gray-500'
}

// ── Payment method helpers ──────────────────────────────────
const PM_COLORS = { cash: '#10b981', qris: '#6366f1', card: '#f59e0b', transfer: '#3b82f6', other: '#94a3b8' }
const PM_LABELS = { cash: 'Tunai', qris: 'QRIS', card: 'Kartu', transfer: 'Transfer', other: 'Lainnya' }

function pmColor(method) { return PM_COLORS[method] || PM_COLORS.other }
function pmLabel(method) { return PM_LABELS[method] || method }

// ── Chart: Revenue + Order Trend ────────────────────────────
const revenueTrendData = computed(() => {
  if (!data.value?.revenue_trend?.length) return null
  const labels = data.value.revenue_trend.map(d => {
    const dt = new Date(d.date)
    return dt.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' })
  })
  return {
    labels,
    datasets: [
      {
        label: 'Pendapatan',
        data: data.value.revenue_trend.map(d => d.value),
        borderColor: '#3b82f6',
        backgroundColor: 'rgba(59,130,246,0.08)',
        fill: true,
        tension: 0.4,
        pointRadius: 0,
        pointHoverRadius: 5,
        yAxisID: 'y',
      },
      {
        label: 'Pesanan',
        data: data.value.order_trend.map(d => d.value),
        borderColor: '#34d399',
        backgroundColor: 'rgba(52,211,153,0.08)',
        fill: true,
        tension: 0.4,
        pointRadius: 0,
        pointHoverRadius: 5,
        borderDash: [4, 4],
        yAxisID: 'y1',
      },
    ],
  }
})

const revenueTrendOpts = {
  responsive: true,
  maintainAspectRatio: false,
  interaction: { mode: 'index', intersect: false },
  plugins: {
    legend: { display: false },
    tooltip: {
      backgroundColor: 'rgba(15,23,42,0.9)',
      titleFont: { size: 12 },
      bodyFont: { size: 12 },
      padding: 10,
      cornerRadius: 8,
      callbacks: {
        label: (ctx) => {
          if (ctx.datasetIndex === 0) return `Pendapatan: ${formatRupiah(ctx.raw)}`
          return `Pesanan: ${ctx.raw}`
        },
      },
    },
  },
  scales: {
    x: { grid: { display: false }, ticks: { maxTicksLimit: 10, font: { size: 11 } } },
    y: {
      position: 'left',
      grid: { color: 'rgba(0,0,0,0.04)' },
      ticks: { font: { size: 11 }, callback: (v) => v >= 1000000 ? (v / 1000000).toFixed(1) + 'jt' : v >= 1000 ? (v / 1000).toFixed(0) + 'rb' : v },
    },
    y1: {
      position: 'right',
      grid: { display: false },
      ticks: { font: { size: 11 } },
    },
  },
}

// ── Chart: Hourly Sales ─────────────────────────────────────
const hourlyData = computed(() => {
  if (!data.value?.hourly_sales?.length) return null
  const labels = data.value.hourly_sales.map(h => `${String(h.hour).padStart(2, '0')}:00`)
  const values = data.value.hourly_sales.map(h => h.value)
  const maxVal = Math.max(...values)
  return {
    labels,
    datasets: [{
      label: 'Pendapatan',
      data: values,
      backgroundColor: values.map(v => v === maxVal && maxVal > 0 ? 'rgba(239,68,68,0.7)' : 'rgba(59,130,246,0.6)'),
      borderRadius: 4,
      barPercentage: 0.7,
    }],
  }
})

const hourlyOpts = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { display: false },
    tooltip: {
      backgroundColor: 'rgba(15,23,42,0.9)',
      cornerRadius: 8,
      callbacks: {
        title: (items) => `Jam ${items[0].label}`,
        label: (ctx) => {
          const h = data.value.hourly_sales[ctx.dataIndex]
          return [`Pendapatan: ${formatRupiah(ctx.raw)}`, `Transaksi: ${h.count}`]
        },
      },
    },
  },
  scales: {
    x: { grid: { display: false }, ticks: { font: { size: 10 }, maxRotation: 0 } },
    y: { grid: { color: 'rgba(0,0,0,0.04)' }, ticks: { font: { size: 11 }, callback: (v) => v >= 1000000 ? (v / 1000000).toFixed(1) + 'jt' : v >= 1000 ? (v / 1000).toFixed(0) + 'rb' : v } },
  },
}

// ── Chart: Payment Methods Donut ────────────────────────────
const paymentData = computed(() => {
  if (!data.value?.payment_methods?.length) return null
  return {
    labels: data.value.payment_methods.map(p => pmLabel(p.method)),
    datasets: [{
      data: data.value.payment_methods.map(p => p.amount),
      backgroundColor: data.value.payment_methods.map(p => pmColor(p.method)),
      borderWidth: 0,
      spacing: 2,
    }],
  }
})

const doughnutOpts = {
  responsive: true,
  maintainAspectRatio: true,
  cutout: '65%',
  plugins: {
    legend: { display: false },
    tooltip: {
      backgroundColor: 'rgba(15,23,42,0.9)',
      cornerRadius: 8,
      callbacks: {
        label: (ctx) => `${ctx.label}: ${formatRupiah(ctx.raw)}`,
      },
    },
  },
}
</script>

<style scoped>
/* ── KPI Cards ────────────────────────────────────────────── */
.kpi-card {
  padding: 1.25rem;
  border-radius: 1rem;
  background: white;
  border: 1px solid #e5e7eb;
  box-shadow: 0 1px 3px rgba(0,0,0,0.04);
  transition: all 0.2s;
}
.kpi-card:hover {
  box-shadow: 0 4px 12px rgba(0,0,0,0.08);
  transform: translateY(-1px);
}

.kpi-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 2.25rem;
  height: 2.25rem;
  border-radius: 0.625rem;
}

.kpi-emerald .kpi-icon { background: #ecfdf5; color: #059669; }
.kpi-blue .kpi-icon    { background: #eff6ff; color: #2563eb; }
.kpi-violet .kpi-icon  { background: #f5f3ff; color: #7c3aed; }
.kpi-amber .kpi-icon   { background: #fffbeb; color: #d97706; }

.kpi-trend {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.125rem 0.5rem;
  border-radius: 9999px;
  font-size: 0.7rem;
  font-weight: 700;
  letter-spacing: 0.02em;
}
.trend-up   { background: #ecfdf5; color: #059669; }
.trend-down { background: #fef2f2; color: #dc2626; }

/* ── Chart Cards ──────────────────────────────────────────── */
.chart-card {
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 1rem;
  box-shadow: 0 1px 3px rgba(0,0,0,0.04);
  overflow: hidden;
}

.chart-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  padding: 1.25rem 1.25rem 0;
}

.chart-title {
  font-size: 0.9375rem;
  font-weight: 700;
  color: #111827;
}

.chart-sub {
  font-size: 0.75rem;
  color: #9ca3af;
  margin-top: 0.125rem;
}

.chart-body {
  padding: 1rem 1.25rem 1.25rem;
  height: 280px;
}

.chart-body-table {
  max-height: 320px;
  overflow-y: auto;
}

/* ── Insight Cards ────────────────────────────────────────── */
.insight-card {
  padding: 1rem 1.25rem;
  border-radius: 1rem;
  border: 1px solid;
}

/* ── Mobile tweaks ────────────────────────────────────────── */
@media (max-width: 640px) {
  .chart-body {
    height: 220px;
    padding: 0.75rem;
  }
  .kpi-card {
    padding: 1rem;
  }
}
</style>
