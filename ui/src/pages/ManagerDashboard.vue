<!--
  ManagerDashboard.vue — Executive Manager Dashboard
  Route: /manager-dashboard
  A powerful, data-rich dashboard for managerial decision-making.
  Charts (ApexCharts): revenue/order trend (area, dual-axis), hourly pattern (bar),
  payment mix (radialBar), KPI sparklines, outlet ranking & top products tables.
-->
<template>
  <div class="dash-root">

    <!-- ── Header ── -->
    <div class="page-header">
      <div>
        <h1 class="page-title">Dashboard</h1>
        <p class="page-sub">Ringkasan performa bisnis untuk pengambilan keputusan</p>
      </div>
      <div class="date-chip">
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>
        </svg>
        <span>{{ currentDate }}</span>
        <span class="live-dot" />
        <span>Live</span>
      </div>
    </div>

    <!-- ── Loading ── -->
    <div v-if="loading" class="py-20 flex flex-col items-center gap-3">
      <AppSpinner size="lg" class="text-emerald-600" />
      <p class="text-sm text-gray-400">Memuat data dashboard...</p>
    </div>

    <!-- ── Error ── -->
    <AppAlert v-if="errorMsg" type="error" :message="errorMsg" />

    <template v-if="!loading && data">

      <!-- ═══ KPI Cards (with sparklines) ═══ -->
      <div class="stat-grid">
        <div
          v-for="kpi in KPI_CARDS"
          :key="kpi.key"
          :class="['stat-card', `sc-${kpi.theme}`]"
        >
          <div class="sc-glare" aria-hidden="true" />
          <div class="sc-blob" aria-hidden="true" />

          <div class="sc-top">
            <div class="sc-icon-wrap" v-html="kpi.icon" />
            <span v-if="kpi.prevKey" :class="['trend-badge', trendDir(data[kpi.key], data[kpi.prevKey])]">
              <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
                <polyline v-if="data[kpi.key] >= data[kpi.prevKey]" points="18 15 12 9 6 15"/>
                <polyline v-else points="6 9 12 15 18 9"/>
              </svg>
              {{ pctChange(data[kpi.key], data[kpi.prevKey]) }}
            </span>
          </div>

          <p class="sc-label">{{ kpi.label }}</p>
          <p class="sc-value">{{ fmtKPI(kpi, data[kpi.key]) }}</p>
          <p v-if="kpi.sub" class="sc-sub">{{ kpi.sub(data) }}</p>

          <div v-if="kpiSparks[kpi.key]?.length" class="sc-spark">
            <VueApexCharts type="area" height="40" :options="sparkOpts(SPARK_COLOR[kpi.theme])" :series="[{ data: kpiSparks[kpi.key] }]" />
          </div>
        </div>
      </div>

      <!-- ═══ Performa Outlet ═══ -->
      <div class="glass-panel">
        <div class="panel-header">
          <div class="panel-title-row">
            <div class="panel-icon ic-blue">
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>
            </div>
            <div>
              <h3 class="panel-title">Performa Outlet</h3>
              <p class="panel-sub">Ranking berdasarkan pendapatan bulan ini</p>
            </div>
          </div>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="tbl-head">
                <th class="th-l">#</th>
                <th class="th-l">Outlet</th>
                <th class="th-r">Hari Ini</th>
                <th class="th-r">Bulan Ini</th>
                <th class="th-r">Order Bulan Ini</th>
                <th class="th-r">Belum Lunas</th>
                <th class="th-c">Sinkron</th>
                <th class="th-c">Kontribusi</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(o, i) in data.outlet_ranking" :key="o.id" class="tbl-row">
                <td class="py-3 px-4">
                  <span :class="['rank-badge', rankClass(i)]">{{ i + 1 }}</span>
                </td>
                <td class="py-3 px-4">
                  <RouterLink :to="`/outlets/${o.id}`" class="outlet-name">{{ o.name }}</RouterLink>
                </td>
                <td class="py-3 px-4 text-right tabular-nums font-medium text-gray-800">{{ formatRupiah(o.today_revenue) }}</td>
                <td class="py-3 px-4 text-right tabular-nums font-semibold text-gray-900">{{ formatRupiah(o.month_revenue) }}</td>
                <td class="py-3 px-4 text-right tabular-nums text-gray-600">{{ o.month_orders }}</td>
                <td class="py-3 px-4 text-right tabular-nums">
                  <span :class="o.unpaid_amount > 0 ? 'text-amber-600 font-semibold' : 'text-gray-400'">{{ formatRupiah(o.unpaid_amount) }}</span>
                </td>
                <td class="py-3 px-4 text-center">
                  <span v-if="o.last_sync_at" class="inline-flex items-center gap-1.5 text-xs text-gray-500">
                    <span :class="['w-1.5 h-1.5 rounded-full', syncDotClass(o.last_sync_at)]" />
                    {{ timeAgo(o.last_sync_at) }}
                  </span>
                  <span v-else class="text-xs text-gray-300">—</span>
                </td>
                <td class="py-3 px-4">
                  <div class="flex items-center gap-2 justify-center">
                    <div class="contrib-track">
                      <div class="contrib-fill" :style="{ width: contribution(o.month_revenue) + '%' }" />
                    </div>
                    <span class="text-xs font-medium text-gray-500 tabular-nums w-10 text-right">{{ contribution(o.month_revenue).toFixed(1) }}%</span>
                  </div>
                </td>
              </tr>
              <tr v-if="!data.outlet_ranking?.length">
                <td colspan="8" class="py-8 text-center text-gray-400 text-sm">Belum ada data outlet.</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- ═══ Row 1: Revenue Trend + Payment Mix ═══ -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <!-- Revenue Trend (30 hari) -->
        <div class="glass-panel lg:col-span-2">
          <div class="panel-header">
            <div class="panel-title-row">
              <div class="panel-icon ic-blue">
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 17 9 11 13 15 21 7"/><polyline points="14 7 21 7 21 14"/></svg>
              </div>
              <div>
                <h3 class="panel-title">Tren Pendapatan</h3>
                <p class="panel-sub">30 hari terakhir</p>
              </div>
            </div>
            <div class="flex items-center gap-4 text-xs">
              <span class="legend-dot"><span class="ld" style="background:#3b82f6"></span>Pendapatan</span>
              <span class="legend-dot"><span class="ld" style="background:#10b981"></span>Pesanan</span>
            </div>
          </div>
          <!-- mini summary strip -->
          <div class="trend-stats">
            <div class="ts-item">
              <span class="ts-label">Total 30 hari</span>
              <span class="ts-value">{{ formatRupiah(trendTotals.revenue) }}</span>
            </div>
            <div class="ts-divider" />
            <div class="ts-item">
              <span class="ts-label">Rata-rata / hari</span>
              <span class="ts-value">{{ formatRupiah(trendTotals.avgRevenue) }}</span>
            </div>
            <div class="ts-divider" />
            <div class="ts-item">
              <span class="ts-label">Hari terbaik</span>
              <span class="ts-value">{{ formatRupiah(trendTotals.bestValue) }}</span>
              <span class="ts-meta">{{ trendTotals.bestDate }}</span>
            </div>
          </div>
          <div class="chart-body">
            <VueApexCharts v-if="revenueSeries" type="line" height="100%" :options="revenueOpts" :series="revenueSeries" />
          </div>
        </div>

        <!-- Payment Methods (radialBar) -->
        <div class="glass-panel">
          <div class="panel-header">
            <div class="panel-title-row">
              <div class="panel-icon ic-violet">
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="5" width="20" height="14" rx="2"/><line x1="2" y1="10" x2="22" y2="10"/></svg>
              </div>
              <div>
                <h3 class="panel-title">Metode Pembayaran</h3>
                <p class="panel-sub">Bulan ini</p>
              </div>
            </div>
          </div>
          <div class="chart-body-radial">
            <VueApexCharts v-if="paymentSeries.length" type="radialBar" height="240" :options="paymentOpts" :series="paymentSeries" />
            <div v-else class="text-center text-gray-400 text-sm py-10">Belum ada transaksi bulan ini.</div>
          </div>
          <div class="px-5 pb-4 space-y-2.5">
            <div v-for="pm in data.payment_methods" :key="pm.method" class="pm-row">
              <span class="flex items-center gap-2 min-w-0">
                <span class="w-2.5 h-2.5 rounded-full flex-shrink-0" :style="{ background: pmColor(pm.method) }" />
                <span class="font-medium text-gray-700 capitalize truncate">{{ pmLabel(pm.method) }}</span>
                <span class="pm-pct">{{ pmPct(pm.amount) }}%</span>
              </span>
              <span class="font-semibold text-gray-900 tabular-nums">{{ formatRupiah(pm.amount) }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- ═══ Row 2: Hourly Pattern + Top Products ═══ -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <!-- Hourly Sales Pattern -->
        <div class="glass-panel">
          <div class="panel-header">
            <div class="panel-title-row">
              <div class="panel-icon ic-amber">
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><polyline points="12 7 12 12 15 14"/></svg>
              </div>
              <div>
                <h3 class="panel-title">Pola Penjualan Per Jam</h3>
                <p class="panel-sub">Hari ini — identifikasi jam sibuk</p>
              </div>
            </div>
            <span v-if="peakHour" class="peak-chip">
              <svg width="11" height="11" viewBox="0 0 24 24" fill="currentColor"><path d="M13 2L4.5 13.5H11l-1 8.5 8.5-11.5H12z"/></svg>
              Puncak {{ peakHour.label }}
            </span>
          </div>
          <div class="chart-body">
            <VueApexCharts v-if="hourlySeries" type="bar" height="100%" :options="hourlyOpts" :series="hourlySeries" />
          </div>
        </div>

        <!-- Top Products -->
        <div class="glass-panel">
          <div class="panel-header">
            <div class="panel-title-row">
              <div class="panel-icon ic-emerald">
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/></svg>
              </div>
              <div>
                <h3 class="panel-title">Produk Terlaris</h3>
                <p class="panel-sub">10 teratas bulan ini</p>
              </div>
            </div>
          </div>
          <div class="chart-body-table">
            <table class="w-full text-sm">
              <thead>
                <tr class="tbl-head">
                  <th class="th-l">#</th>
                  <th class="th-l">Produk</th>
                  <th class="th-r">Qty</th>
                  <th class="th-r">Revenue</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(p, i) in data.top_products" :key="p.name" class="tbl-row">
                  <td class="py-2.5 px-4">
                    <span :class="['inline-flex items-center justify-center w-6 h-6 rounded-full text-xs font-bold', i < 3 ? 'bg-amber-100 text-amber-700' : 'bg-gray-100 text-gray-500']">{{ i + 1 }}</span>
                  </td>
                  <td class="py-2.5 px-4 font-medium text-gray-800">
                    <div class="prod-name">{{ p.name }}</div>
                    <div class="prod-bar-track"><div class="prod-bar-fill" :style="{ width: prodPct(p.revenue) + '%' }" /></div>
                  </td>
                  <td class="py-2.5 px-4 text-right tabular-nums text-gray-600">{{ p.quantity.toLocaleString('id-ID') }}</td>
                  <td class="py-2.5 px-4 text-right tabular-nums font-semibold text-gray-800">{{ formatRupiah(p.revenue) }}</td>
                </tr>
                <tr v-if="!data.top_products?.length">
                  <td colspan="4" class="py-8 text-center text-gray-400 text-sm">Belum ada data produk bulan ini.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- ═══ Quick Insight Cards ═══ -->
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <div class="insight-card ins-amber">
          <div class="ins-blob" aria-hidden="true" />
          <div class="flex items-center gap-3 mb-2">
            <div class="ins-icon">
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z"/></svg>
            </div>
            <div>
              <p class="ins-label">Pesanan Belum Lunas</p>
              <p class="ins-value">{{ data.unpaid_orders }} pesanan</p>
            </div>
          </div>
          <p class="ins-foot">{{ formatRupiah(data.unpaid_amount) }}</p>
        </div>

        <div class="insight-card ins-blue">
          <div class="ins-blob" aria-hidden="true" />
          <div class="flex items-center gap-3 mb-2">
            <div class="ins-icon">
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/></svg>
            </div>
            <div>
              <p class="ins-label">Outlet Aktif</p>
              <p class="ins-value">{{ data.active_outlets }} outlet</p>
            </div>
          </div>
          <p class="ins-foot-muted">Beroperasi dan terhubung</p>
        </div>

        <div class="insight-card ins-emerald">
          <div class="ins-blob" aria-hidden="true" />
          <div class="flex items-center gap-3 mb-2">
            <div class="ins-icon">
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/></svg>
            </div>
            <div>
              <p class="ins-label">Total Produk</p>
              <p class="ins-value">{{ data.total_products }} item</p>
            </div>
          </div>
          <p class="ins-foot-muted">Produk aktif terdaftar</p>
        </div>
      </div>

    </template>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import VueApexCharts from 'vue3-apexcharts'
import { apiClient } from '@/api/client.js'
import { formatRupiah, timeAgo } from '@/utils/format.js'
import AppSpinner from '@/components/ui/AppSpinner.vue'
import AppAlert from '@/components/ui/AppAlert.vue'

const data     = ref(null)
const loading  = ref(false)
const errorMsg = ref('')

const currentDate = new Date().toLocaleDateString('id-ID', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })

// ── KPI card definitions ────────────────────────────────────
const SPARK_COLOR = { emerald: '#10b981', blue: '#3b82f6', violet: '#8b5cf6', amber: '#f59e0b' }

const KPI_CARDS = [
  {
    key: 'today_revenue', prevKey: 'yesterday_revenue', label: 'Pendapatan Hari Ini',
    theme: 'emerald', fmt: 'rupiah',
    icon: '<svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.9"><path stroke-linecap="round" stroke-linejoin="round" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>',
    sub: (d) => `Kemarin: ${formatRupiah(d.yesterday_revenue)}`,
  },
  {
    key: 'today_orders', prevKey: 'yesterday_orders', label: 'Pesanan Hari Ini',
    theme: 'blue', fmt: 'number',
    icon: '<svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.9"><path stroke-linecap="round" stroke-linejoin="round" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"/></svg>',
    sub: (d) => `Kemarin: ${d.yesterday_orders} pesanan`,
  },
  {
    key: 'month_revenue', prevKey: 'month_revenue_prev', label: 'Pendapatan Bulan Ini',
    theme: 'violet', fmt: 'rupiah',
    icon: '<svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.9"><path stroke-linecap="round" stroke-linejoin="round" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/></svg>',
    sub: (d) => `Bulan lalu: ${formatRupiah(d.month_revenue_prev)}`,
  },
  {
    key: 'today_avg_order', label: 'Rata-rata per Order',
    theme: 'amber', fmt: 'rupiah',
    icon: '<svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.9"><path stroke-linecap="round" stroke-linejoin="round" d="M7 12l3-3 3 3 4-4M8 21l4-4 4 4M3 4h18M4 4h16v12a1 1 0 01-1 1H5a1 1 0 01-1-1V4z"/></svg>',
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

// Compact rupiah for tight spaces (axis ticks, radial center)
function fmtCompact(v) {
  if (v >= 1e9) return 'Rp' + (v / 1e9).toFixed(1) + 'M'
  if (v >= 1e6) return 'Rp' + (v / 1e6).toFixed(1) + 'jt'
  if (v >= 1e3) return 'Rp' + (v / 1e3).toFixed(0) + 'rb'
  return 'Rp' + v
}

function pctChange(curr, prev) {
  if (!prev) return curr > 0 ? '+100%' : '0%'
  const pct = ((curr - prev) / prev * 100).toFixed(1)
  return (pct > 0 ? '+' : '') + pct + '%'
}

function trendDir(curr, prev) {
  return curr >= prev ? 'trend-up' : 'trend-down'
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

function prodPct(revenue) {
  const max = data.value?.top_products?.[0]?.revenue || 1
  return Math.max(4, (revenue / max) * 100)
}

// Warna indikator sinkronisasi: hijau <1 jam, kuning <24 jam, merah lebih lama
function syncDotClass(syncAt) {
  if (!syncAt) return 'bg-gray-300'
  const hours = (Date.now() - new Date(syncAt).getTime()) / 36e5
  if (hours < 1)  return 'bg-emerald-500'
  if (hours < 24) return 'bg-amber-500'
  return 'bg-red-500'
}

// ── Payment method helpers ──────────────────────────────────
const PM_COLORS = { cash: '#10b981', qris: '#6366f1', card: '#f59e0b', transfer: '#3b82f6', other: '#94a3b8' }
const PM_LABELS = { cash: 'Tunai', qris: 'QRIS', card: 'Kartu', transfer: 'Transfer', other: 'Lainnya' }
function pmColor(method) { return PM_COLORS[method] || PM_COLORS.other }
function pmLabel(method) { return PM_LABELS[method] || method }

const paymentTotal = computed(() => (data.value?.payment_methods ?? []).reduce((s, p) => s + p.amount, 0))
function pmPct(amount) { return ((amount / (paymentTotal.value || 1)) * 100).toFixed(0) }

// ── Trend summary strip ─────────────────────────────────────
const trendTotals = computed(() => {
  const t = data.value?.revenue_trend ?? []
  const revenue = t.reduce((s, d) => s + d.value, 0)
  const avgRevenue = t.length ? Math.round(revenue / t.length) : 0
  let best = null
  for (const d of t) if (!best || d.value > best.value) best = d
  return {
    revenue,
    avgRevenue,
    bestValue: best?.value ?? 0,
    bestDate: best ? new Date(best.date).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' }) : '—',
  }
})

// ── KPI sparkline data (data-backed, no fabricated values) ──
const kpiSparks = computed(() => {
  const d = data.value
  if (!d) return {}
  const hs = d.hourly_sales ?? []
  return {
    today_revenue:   hs.map(h => h.value),
    today_orders:    hs.map(h => h.count),
    month_revenue:   (d.revenue_trend ?? []).map(x => x.value),
    today_avg_order: hs.map(h => (h.count > 0 ? Math.round(h.value / h.count) : 0)),
  }
})

function sparkOpts(color) {
  return {
    chart: { type: 'area', sparkline: { enabled: true }, animations: { enabled: true, speed: 600 } },
    stroke: { curve: 'smooth', width: 2 },
    fill: { type: 'gradient', gradient: { shadeIntensity: 1, opacityFrom: 0.45, opacityTo: 0, stops: [0, 100] } },
    colors: [color],
    markers: { size: 0 },
    tooltip: { enabled: false },
  }
}

// ── Revenue + Order trend (area, dual axis) ─────────────────
const revenueSeries = computed(() => {
  if (!data.value?.revenue_trend?.length) return null
  return [
    { name: 'Pendapatan', type: 'area', data: data.value.revenue_trend.map(d => d.value) },
    { name: 'Pesanan',    type: 'line', data: (data.value.order_trend ?? []).map(d => d.value) },
  ]
})

const revenueOpts = computed(() => {
  const cats = (data.value?.revenue_trend ?? []).map(d =>
    new Date(d.date).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' })
  )
  return {
    chart: {
      type: 'line', height: '100%', fontFamily: 'Inter, system-ui, sans-serif',
      toolbar: { show: false }, zoom: { enabled: false },
      animations: { enabled: true, easing: 'easeinout', speed: 800 },
      dropShadow: { enabled: true, enabledOnSeries: [0], top: 6, left: 0, blur: 6, color: '#3b82f6', opacity: 0.18 },
    },
    colors: ['#3b82f6', '#10b981'],
    stroke: { curve: 'smooth', width: [3, 2], dashArray: [0, 5] },
    fill: {
      type: ['gradient', 'solid'],
      gradient: { shadeIntensity: 1, opacityFrom: 0.45, opacityTo: 0.02, stops: [0, 90] },
    },
    markers: { size: 0, strokeWidth: 0, hover: { size: 6, sizeOffset: 3 } },
    dataLabels: { enabled: false },
    grid: { borderColor: 'rgba(0,0,0,0.05)', strokeDashArray: 4, padding: { left: 4, right: 4 }, xaxis: { lines: { show: false } } },
    xaxis: {
      categories: cats,
      tickAmount: 7,
      axisBorder: { show: false }, axisTicks: { show: false },
      labels: { rotate: 0, hideOverlappingLabels: true, style: { colors: '#94a3b8', fontSize: '11px' } },
    },
    yaxis: [
      { seriesName: 'Pendapatan', labels: { style: { colors: '#94a3b8', fontSize: '11px' }, formatter: (v) => v >= 1e6 ? (v / 1e6).toFixed(1) + 'jt' : v >= 1e3 ? (v / 1e3).toFixed(0) + 'rb' : Math.round(v) } },
      { seriesName: 'Pesanan', opposite: true, labels: { style: { colors: '#94a3b8', fontSize: '11px' }, formatter: (v) => Math.round(v) } },
    ],
    legend: { show: false },
    tooltip: {
      theme: 'dark', shared: true, intersect: false,
      x: { show: true },
      y: { formatter: (val, opts) => opts?.seriesIndex === 0 ? formatRupiah(val) : `${Math.round(val)} pesanan` },
    },
  }
})

// ── Hourly sales (distributed bar, peak highlighted) ────────
const peakHour = computed(() => {
  const hs = data.value?.hourly_sales ?? []
  if (!hs.length) return null
  let best = hs[0]
  for (const h of hs) if (h.value > best.value) best = h
  if (!best || best.value <= 0) return null
  return { label: `${String(best.hour).padStart(2, '0')}:00`, value: best.value, hour: best.hour }
})

const hourlySeries = computed(() => {
  if (!data.value?.hourly_sales?.length) return null
  return [{ name: 'Pendapatan', data: data.value.hourly_sales.map(h => h.value) }]
})

const hourlyOpts = computed(() => {
  const hs = data.value?.hourly_sales ?? []
  const peak = peakHour.value?.hour
  return {
    chart: {
      type: 'bar', height: '100%', fontFamily: 'Inter, system-ui, sans-serif',
      toolbar: { show: false },
      animations: { enabled: true, easing: 'easeinout', speed: 700 },
    },
    plotOptions: { bar: { borderRadius: 5, borderRadiusApplication: 'end', columnWidth: '62%', distributed: true } },
    colors: hs.map(h => (h.hour === peak ? '#f59e0b' : '#3b82f6')),
    fill: { type: 'gradient', gradient: { shade: 'light', type: 'vertical', shadeIntensity: 0.35, opacityFrom: 1, opacityTo: 0.78, stops: [0, 100] } },
    states: { hover: { filter: { type: 'darken', value: 0.9 } } },
    dataLabels: { enabled: false },
    legend: { show: false },
    grid: { borderColor: 'rgba(0,0,0,0.05)', strokeDashArray: 4, padding: { left: 4, right: 4 }, xaxis: { lines: { show: false } } },
    xaxis: {
      categories: hs.map(h => `${String(h.hour).padStart(2, '0')}`),
      tickAmount: 12,
      axisBorder: { show: false }, axisTicks: { show: false },
      labels: { rotate: 0, hideOverlappingLabels: true, style: { colors: '#94a3b8', fontSize: '10px' } },
    },
    yaxis: { labels: { style: { colors: '#94a3b8', fontSize: '11px' }, formatter: (v) => v >= 1e6 ? (v / 1e6).toFixed(1) + 'jt' : v >= 1e3 ? (v / 1e3).toFixed(0) + 'rb' : Math.round(v) } },
    tooltip: {
      theme: 'dark',
      custom: ({ dataPointIndex }) => {
        const h = hs[dataPointIndex]
        if (!h) return ''
        return `<div style="padding:8px 12px;font-family:Inter,system-ui,sans-serif">
          <div style="font-weight:600;color:#e2e8f0;margin-bottom:4px">Jam ${String(h.hour).padStart(2, '0')}:00</div>
          <div style="color:#fff">Pendapatan: <b>${formatRupiah(h.value)}</b></div>
          <div style="color:#fff">Transaksi: <b>${h.count}</b></div>
        </div>`
      },
    },
  }
})

// ── Payment mix (radialBar) ─────────────────────────────────
const paymentSeries = computed(() =>
  (data.value?.payment_methods ?? []).map(p => Number(((p.amount / (paymentTotal.value || 1)) * 100).toFixed(1)))
)

const paymentOpts = computed(() => {
  const pm = data.value?.payment_methods ?? []
  return {
    chart: { type: 'radialBar', height: 240, fontFamily: 'Inter, system-ui, sans-serif', animations: { enabled: true, speed: 700 } },
    colors: pm.map(p => pmColor(p.method)),
    labels: pm.map(p => pmLabel(p.method)),
    plotOptions: {
      radialBar: {
        hollow: { size: '44%' },
        track: { background: 'rgba(0,0,0,0.05)', strokeWidth: '100%', margin: 5 },
        dataLabels: {
          name: { fontSize: '12px', color: '#6b7f74', offsetY: -4 },
          value: { fontSize: '16px', fontWeight: 700, color: '#0f2d1d', offsetY: 4, formatter: (v) => `${v}%` },
          total: {
            show: true, label: 'TOTAL', color: '#94a3b8', fontSize: '11px', fontWeight: 600,
            formatter: () => fmtCompact(paymentTotal.value),
          },
        },
      },
    },
    stroke: { lineCap: 'round' },
    legend: { show: false },
  }
})
</script>

<style scoped>
/* ── Root ── */
.dash-root { display: flex; flex-direction: column; gap: 1.25rem; }

/* ── Page header ── */
.page-header { display: flex; align-items: flex-end; justify-content: space-between; flex-wrap: wrap; gap: .75rem; }
.page-title { font-size: 1.5rem; font-weight: 800; color: #0f4226; letter-spacing: -.03em; line-height: 1.15; }
.page-sub { margin-top: .2rem; font-size: .82rem; color: #5a7866; }

.date-chip {
  display: flex; align-items: center; gap: .4rem;
  padding: .32rem .85rem; border-radius: 999px;
  background: rgba(255,255,255,.72);
  backdrop-filter: blur(16px) saturate(160%);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  border: 1px solid rgba(255,255,255,.6);
  box-shadow: 0 1px 6px rgba(0,0,0,.07);
  font-size: .73rem; color: #2d5c40; font-weight: 500;
}
.live-dot {
  display: inline-block; width: 6px; height: 6px; border-radius: 50%;
  background: #22c55e; box-shadow: 0 0 0 2px rgba(34,197,94,.25);
  animation: pulse-dot 2s ease-in-out infinite;
}
@keyframes pulse-dot {
  0%,100% { box-shadow: 0 0 0 2px rgba(34,197,94,.25); }
  50%      { box-shadow: 0 0 0 5px rgba(34,197,94,.10); }
}

/* ── Stat grid ── */
.stat-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(210px, 1fr)); gap: .875rem; }

/* ── Glass KPI card ── */
.stat-card {
  position: relative; overflow: hidden; border-radius: 1.1rem;
  padding: 1.1rem 1.15rem .65rem;
  background: rgba(255,255,255,.75);
  backdrop-filter: blur(24px) saturate(180%);
  -webkit-backdrop-filter: blur(24px) saturate(180%);
  border: 1px solid rgba(255,255,255,.68);
  box-shadow: 0 2px 14px rgba(0,0,0,.07), 0 1px 0 rgba(255,255,255,.95) inset;
  transition: transform .18s ease, box-shadow .18s ease;
}
.stat-card:hover { transform: translateY(-3px); box-shadow: 0 8px 28px rgba(0,0,0,.10), 0 1px 0 rgba(255,255,255,.95) inset; }
.sc-glare { position: absolute; inset: 0; pointer-events: none; border-radius: inherit; background: linear-gradient(135deg, rgba(255,255,255,.52) 0%, rgba(255,255,255,0) 55%); }
.sc-blob { position: absolute; top: -28px; right: -28px; width: 90px; height: 90px; border-radius: 50%; filter: blur(28px); opacity: .18; pointer-events: none; }
.sc-blue    .sc-blob { background: #3b82f6; }
.sc-emerald .sc-blob { background: #10b981; }
.sc-amber   .sc-blob { background: #f59e0b; }
.sc-violet  .sc-blob { background: #8b5cf6; }

.sc-icon-wrap { display: flex; align-items: center; justify-content: center; width: 36px; height: 36px; border-radius: .7rem; flex-shrink: 0; }
.sc-blue    .sc-icon-wrap { background: rgba(59,130,246,.12);  color: #2563eb; }
.sc-emerald .sc-icon-wrap { background: rgba(16,185,129,.13);  color: #059669; }
.sc-amber   .sc-icon-wrap { background: rgba(245,158,11,.13);  color: #d97706; }
.sc-violet  .sc-icon-wrap { background: rgba(139,92,246,.12);  color: #7c3aed; }

.sc-top { display: flex; align-items: center; justify-content: space-between; gap: .5rem; margin-bottom: .85rem; position: relative; }
.sc-label { font-size: .68rem; font-weight: 700; text-transform: uppercase; letter-spacing: .07em; color: #6b7f74; line-height: 1.3; position: relative; }
.sc-value { font-size: clamp(1.15rem, 2.8vw, 1.55rem); font-weight: 800; color: #0f2d1d; letter-spacing: -.035em; line-height: 1.1; margin-top: .25rem; word-break: break-word; position: relative; }
.sc-sub { font-size: .7rem; color: #8a9e93; margin-top: .45rem; position: relative; }
.sc-spark { margin: .1rem -.35rem -.35rem; position: relative; }

/* Trend badge */
.trend-badge { display: inline-flex; align-items: center; gap: .2rem; font-size: .68rem; font-weight: 700; border-radius: 999px; padding: .16rem .46rem; position: relative; }
.trend-up   { background: rgba(22,163,74,.13);  color: #16a34a; }
.trend-down { background: rgba(220,38,38,.10);   color: #dc2626; }

/* ── Glass panel ── */
.glass-panel {
  position: relative; border-radius: 1.1rem; overflow: hidden;
  background: rgba(255,255,255,.78);
  backdrop-filter: blur(24px) saturate(180%);
  -webkit-backdrop-filter: blur(24px) saturate(180%);
  border: 1px solid rgba(255,255,255,.68);
  box-shadow: 0 2px 16px rgba(0,0,0,.07), 0 1px 0 rgba(255,255,255,.95) inset;
}

.panel-header { display: flex; align-items: flex-start; justify-content: space-between; gap: .75rem; padding: 1.1rem 1.25rem .35rem; }
.panel-title-row { display: flex; align-items: center; gap: .6rem; }
.panel-icon { display: flex; align-items: center; justify-content: center; width: 30px; height: 30px; border-radius: .6rem; flex-shrink: 0; }
.ic-blue    { background: rgba(59,130,246,.12);  color: #2563eb; }
.ic-emerald { background: rgba(16,185,129,.13);  color: #059669; }
.ic-amber   { background: rgba(245,158,11,.13);  color: #d97706; }
.ic-violet  { background: rgba(139,92,246,.12);  color: #7c3aed; }
.panel-title { font-size: .94rem; font-weight: 700; color: #0f3d23; line-height: 1.2; }
.panel-sub { font-size: .73rem; color: #9ab5a5; margin-top: .1rem; }
.panel-link { display: inline-flex; align-items: center; gap: .3rem; font-size: .75rem; font-weight: 600; color: #2d8f56; text-decoration: none; padding: .28rem .65rem; border-radius: .5rem; background: rgba(45,143,86,.08); transition: background .15s; white-space: nowrap; }
.panel-link:hover { background: rgba(45,143,86,.16); }

.legend-dot { display: inline-flex; align-items: center; gap: .4rem; color: #5a7866; font-weight: 500; }
.legend-dot .ld { width: 9px; height: 9px; border-radius: 50%; display: inline-block; }

.peak-chip { display: inline-flex; align-items: center; gap: .3rem; font-size: .68rem; font-weight: 700; color: #b45309; background: rgba(245,158,11,.14); border-radius: 999px; padding: .2rem .55rem; }

/* Trend summary strip */
.trend-stats { display: flex; align-items: stretch; gap: .25rem; margin: .5rem 1.25rem 0; padding: .6rem .85rem; border-radius: .75rem; background: rgba(240,247,243,.7); border: 1px solid rgba(0,0,0,.04); }
.ts-item { display: flex; flex-direction: column; gap: .1rem; flex: 1; min-width: 0; }
.ts-label { font-size: .62rem; font-weight: 600; text-transform: uppercase; letter-spacing: .05em; color: #8a9e93; }
.ts-value { font-size: .9rem; font-weight: 700; color: #0f2d1d; line-height: 1.15; }
.ts-meta { font-size: .64rem; color: #9ab5a5; }
.ts-divider { width: 1px; background: rgba(0,0,0,.07); margin: .1rem .15rem; }

.chart-body { padding: 1rem 1.25rem 1.25rem; height: 290px; }
.chart-body-radial { padding: .75rem 1rem 0; }
.chart-body-table { max-height: 340px; overflow-y: auto; padding-bottom: .25rem; }

/* ── Tables ── */
.tbl-head { border-bottom: 1px solid rgba(0,0,0,.06); background: rgba(240,247,243,.55); }
.tbl-head th { font-size: .67rem; font-weight: 700; color: #6b7f74; text-transform: uppercase; letter-spacing: .05em; padding: .7rem 1rem; }
.th-l { text-align: left; }
.th-r { text-align: right; }
.th-c { text-align: center; }
.tbl-row { border-bottom: 1px solid rgba(0,0,0,.04); transition: background .12s; }
.tbl-row:hover { background: rgba(59,130,246,.04); }
.rank-badge { display: inline-flex; align-items: center; justify-content: center; width: 1.75rem; height: 1.75rem; border-radius: .55rem; font-size: .72rem; font-weight: 700; }
.outlet-name { font-weight: 600; color: #1f2937; transition: color .12s; }
.outlet-name:hover { color: #2563eb; }

.contrib-track { width: 5rem; height: .5rem; background: rgba(0,0,0,.06); border-radius: 999px; overflow: hidden; }
.contrib-fill { height: 100%; border-radius: 999px; background: linear-gradient(90deg, #60a5fa, #2563eb); transition: width .4s ease; }

.prod-name { line-height: 1.2; }
.prod-bar-track { height: .3rem; width: 100%; max-width: 140px; background: rgba(0,0,0,.05); border-radius: 999px; overflow: hidden; margin-top: .3rem; }
.prod-bar-fill { height: 100%; border-radius: 999px; background: linear-gradient(90deg, #34d399, #059669); transition: width .4s ease; }

/* Payment list rows */
.pm-row { display: flex; align-items: center; justify-content: space-between; gap: .5rem; font-size: .8rem; }
.pm-pct { font-size: .66rem; font-weight: 700; color: #94a3b8; background: rgba(0,0,0,.04); border-radius: 999px; padding: .05rem .4rem; }

/* ── Insight Cards (glass) ── */
.insight-card {
  position: relative; overflow: hidden;
  padding: 1.05rem 1.25rem; border-radius: 1.1rem;
  background: rgba(255,255,255,.78);
  backdrop-filter: blur(20px) saturate(170%);
  -webkit-backdrop-filter: blur(20px) saturate(170%);
  border: 1px solid rgba(255,255,255,.68);
  box-shadow: 0 2px 14px rgba(0,0,0,.06), 0 1px 0 rgba(255,255,255,.92) inset;
  transition: transform .18s ease, box-shadow .18s ease;
}
.insight-card:hover { transform: translateY(-2px); box-shadow: 0 8px 24px rgba(0,0,0,.09), 0 1px 0 rgba(255,255,255,.92) inset; }
.ins-blob { position: absolute; top: -30px; right: -30px; width: 100px; height: 100px; border-radius: 50%; filter: blur(30px); opacity: .2; pointer-events: none; }
.ins-icon { display: flex; align-items: center; justify-content: center; width: 2.35rem; height: 2.35rem; border-radius: .7rem; flex-shrink: 0; position: relative; }
.ins-label { font-size: .67rem; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; position: relative; }
.ins-value { font-size: 1.15rem; font-weight: 800; line-height: 1.1; position: relative; letter-spacing: -.02em; }
.ins-foot { font-size: .9rem; font-weight: 700; position: relative; }
.ins-foot-muted { font-size: .8rem; position: relative; }

.ins-amber .ins-blob { background: #f59e0b; }
.ins-amber .ins-icon { background: rgba(245,158,11,.14); color: #d97706; }
.ins-amber .ins-label { color: #b45309; }
.ins-amber .ins-value { color: #92400e; }
.ins-amber .ins-foot { color: #b45309; }

.ins-blue .ins-blob { background: #3b82f6; }
.ins-blue .ins-icon { background: rgba(59,130,246,.13); color: #2563eb; }
.ins-blue .ins-label { color: #1d4ed8; }
.ins-blue .ins-value { color: #1e3a8a; }
.ins-blue .ins-foot-muted { color: #2563eb; }

.ins-emerald .ins-blob { background: #10b981; }
.ins-emerald .ins-icon { background: rgba(16,185,129,.14); color: #059669; }
.ins-emerald .ins-label { color: #047857; }
.ins-emerald .ins-value { color: #065f46; }
.ins-emerald .ins-foot-muted { color: #059669; }

/* ── Mobile tweaks ── */
@media (max-width: 640px) {
  .chart-body { height: 230px; padding: .75rem; }
  .stat-card { padding: 1rem; }
  .trend-stats { flex-wrap: wrap; }
}
</style>
