<!--
  Dashboard.vue — Modern Glass Dashboard 2026
  Route: /   meta: { title: 'Dashboard' }
-->
<template>
  <div class="dash-root">

    <!-- ── Page header ── -->
    <div class="page-header">
      <div>
        <h1 class="page-title">Dashboard</h1>
        <p class="page-sub">Ringkasan performa seluruh outlet Anda</p>
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

    <!-- ── Stat cards ── -->
    <div class="stat-grid">
      <div
        v-for="card in STAT_CARDS"
        :key="card.key"
        :class="['stat-card', `sc-${card.theme}`]"
      >
        <div class="sc-glare" aria-hidden="true" />
        <div class="sc-blob"  aria-hidden="true" />

        <!-- label + icon row -->
        <div class="sc-top">
          <div class="sc-icon-wrap" v-html="card.svg" />
          <span class="sc-label">{{ card.label }}</span>
        </div>

        <!-- value -->
        <div class="sc-value-row">
          <span v-if="loading" class="sc-skel" />
          <span v-else class="sc-value">{{ formatStatValue(card, stats?.[card.key]) }}</span>
        </div>

        <!-- footer: trend badge + period label -->
        <div class="sc-footer">
          <template v-if="!loading && stats">
            <!-- outlet card: show active count -->
            <template v-if="card.key === 'total_outlets'">
              <span class="trend-badge pct-neutral">
                <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
                {{ stats.active_outlets }} aktif
              </span>
              <span class="sc-tag">Terdaftar</span>
            </template>
            <!-- cards with prev period comparison -->
            <template v-else-if="card.prevKey != null">
              <span :class="['trend-badge', trendClass(stats[card.key], stats[card.prevKey])]">
                <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
                  <polyline v-if="(stats[card.key] ?? 0) >= (stats[card.prevKey] ?? 0)" points="18 15 12 9 6 15"/>
                  <polyline v-else points="6 9 12 15 18 9"/>
                </svg>
                {{ calcPct(stats[card.key], stats[card.prevKey]) }}
              </span>
              <span class="sc-tag">{{ card.tag }}</span>
            </template>
          </template>
        </div>
      </div>
    </div>

    <!-- ── Error ── -->
    <AppAlert type="error" :message="errorMsg" />

    <!-- ── Outlets table panel ── -->
    <div class="data-panel">

      <!-- Panel header row 1: title + link -->
      <div class="dp-header">
        <div class="dp-title-row">
          <div class="dp-icon">
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/>
            </svg>
          </div>
          <h2 class="dp-title">Outlet Aktif</h2>
          <span class="dp-count">{{ stats?.outlets?.length ?? 0 }}</span>
        </div>
        <RouterLink to="/outlets" class="dp-link">
          Lihat semua
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/>
          </svg>
        </RouterLink>
      </div>

      <!-- Panel header row 2: period selector + custom date range -->
      <div class="dp-filters">
        <!-- Period pills -->
        <div class="period-pills">
          <button
            v-for="p in PERIODS" :key="p.value"
            :class="['period-pill', periodTab === p.value ? 'period-pill--active' : '']"
            @click="setPeriod(p.value)"
          >
            <svg v-if="p.value === 'custom'" width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
              <rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>
            </svg>
            {{ p.label }}
          </button>
        </div>

        <!-- Custom date range inputs (slide-in when custom selected) -->
        <Transition name="dr-slide">
          <div v-if="periodTab === 'custom'" class="date-range">
            <div class="dr-group">
              <label class="dr-label">Dari</label>
              <div class="dr-input-wrap">
                <svg class="dr-ico" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>
                </svg>
                <input type="date" v-model="customFrom" class="dr-input" :max="customTo || undefined" />
              </div>
            </div>
            <span class="dr-sep">→</span>
            <div class="dr-group">
              <label class="dr-label">Sampai</label>
              <div class="dr-input-wrap">
                <svg class="dr-ico" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>
                </svg>
                <input type="date" v-model="customTo" class="dr-input" :min="customFrom || undefined" />
              </div>
            </div>
            <button
              class="dr-apply"
              :disabled="!customFrom || !customTo || loadingCustom"
              @click="applyCustomRange"
            >
              <span v-if="loadingCustom" class="dr-spinner" />
              <span v-else>Terapkan</span>
            </button>
          </div>
        </Transition>
      </div>

      <!-- Table -->
      <AppTable
        :columns="outletCols"
        :rows="stats?.outlets ?? []"
        :loading="loading"
        emptyText="Belum ada outlet terdaftar."
      >
        <template #cell-sales="{ row }">
          <div class="sales-cell">
            <span class="sales-val">{{ formatRupiah(outletSalesVal(row)) }}</span>
            <span :class="['sales-pct', pctClass(outletSalesVal(row), outletPrevVal(row))]">
              <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
                <polyline v-if="outletSalesVal(row) >= outletPrevVal(row)" points="18 15 12 9 6 15"/>
                <polyline v-else points="6 9 12 15 18 9"/>
              </svg>
              {{ calcPct(outletSalesVal(row), outletPrevVal(row)) }}
            </span>
          </div>
        </template>
        <template #cell-unpaid_amount="{ row }">
          <span :class="row.unpaid_amount > 0 ? 'text-amber-600 font-semibold' : 'text-gray-400'">{{ formatRupiah(row.unpaid_amount) }}</span>
        </template>
        <template #cell-last_sync_at="{ row }">
          <span class="sync-time">{{ row.last_sync_at ? timeAgo(row.last_sync_at) : '—' }}</span>
        </template>
      </AppTable>
    </div>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { dashboardApi } from '@/api/dashboard.js'
import { formatRupiah, timeAgo, formatDate } from '@/utils/format.js'
import AppTable  from '@/components/ui/AppTable.vue'
import AppAlert  from '@/components/ui/AppAlert.vue'

// ── Stat card definitions ─────────────────────────────────────
const STAT_CARDS = [
  {
    key: 'total_outlets',
    label: 'Total Outlet',
    prevKey: null,   // handled separately (shows active count)
    tag: 'Terdaftar',
    theme: 'blue',
    format: 'number',
    svg: `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
      <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
      <polyline points="9 22 9 12 15 12 15 22"/>
    </svg>`,
  },
  {
    key: 'month_transactions',
    label: 'Transaksi Bulan Ini',
    prevKey: 'month_transactions_prev',
    tag: 'vs bulan lalu',
    theme: 'emerald',
    format: 'number',
    svg: `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
      <polyline points="14 2 14 8 20 8"/>
      <line x1="16" y1="13" x2="8" y2="13"/>
      <line x1="16" y1="17" x2="8" y2="17"/>
    </svg>`,
  },
  {
    key: 'month_revenue',
    label: 'Revenue Bulan Ini',
    prevKey: 'month_revenue_prev',
    tag: 'vs bulan lalu',
    theme: 'amber',
    format: 'currency',
    svg: `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
      <rect x="2" y="7" width="20" height="14" rx="2"/>
      <path d="M16 3H8"/>
      <path d="M12 3v4"/>
      <circle cx="12" cy="14" r="2.5"/>
      <path d="M6 14h.01M18 14h.01"/>
    </svg>`,
  },
  {
    key: 'today_orders',
    label: 'Order Hari Ini',
    prevKey: 'today_orders_prev',
    tag: 'vs kemarin',
    theme: 'violet',
    format: 'number',
    svg: `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
      <line x1="18" y1="20" x2="18" y2="10"/>
      <line x1="12" y1="20" x2="12" y2="4"/>
      <line x1="6"  y1="20" x2="6"  y2="14"/>
    </svg>`,
  },
]

// ── Period tabs for outlet table ──────────────────────────────
const PERIODS = [
  { value: 'day',    label: 'Hari Ini'  },
  { value: 'week',   label: 'Minggu Ini' },
  { value: 'month',  label: 'Bulan Ini'  },
  { value: 'custom', label: 'Custom'     },
]

// Dynamic outlet column def based on selected period
const periodLabels = { day: 'Hari Ini', week: 'Minggu Ini', month: 'Bulan Ini', custom: 'Rentang Kustom' }
const outletCols = computed(() => [
  { key: 'name',           label: 'Nama Outlet' },
  { key: 'sales',          label: `Penjualan · ${periodLabels[periodTab.value]}` },
  { key: 'unpaid_amount',  label: 'Belum Bayar' },
  { key: 'last_sync_at',   label: 'Terakhir Sync' },
])

// ── State ─────────────────────────────────────────────────────
const stats         = ref(null)
const loading       = ref(false)
const loadingCustom = ref(false)
const errorMsg      = ref('')
const periodTab     = ref('day')
const customFrom    = ref('')
const customTo      = ref('')

// ── Current date ──────────────────────────────────────────────
const currentDate = computed(() => {
  const tz = localStorage.getItem('cloud_pos_timezone') || 'Asia/Jakarta'
  return new Date().toLocaleDateString('id-ID', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric', timeZone: tz })
})

// ── Lifecycle ─────────────────────────────────────────────────
onMounted(fetchStats)

async function fetchStats(params) {
  loading.value  = true
  errorMsg.value = ''
  try {
    stats.value = await dashboardApi.getStats(params)
  } catch (err) {
    errorMsg.value = err?.message ?? 'Gagal memuat statistik dashboard.'
  } finally {
    loading.value = false
  }
}

// ── Period selector ───────────────────────────────────────────
function setPeriod(val) {
  periodTab.value = val
  // When switching away from custom, clear dates but keep existing stats
  if (val !== 'custom') {
    customFrom.value = ''
    customTo.value   = ''
  }
}

async function applyCustomRange() {
  if (!customFrom.value || !customTo.value) return
  loadingCustom.value = true
  errorMsg.value = ''
  try {
    stats.value = await dashboardApi.getStats({ date_from: customFrom.value, date_to: customTo.value })
  } catch (err) {
    errorMsg.value = err?.message ?? 'Gagal memuat data rentang kustom.'
  } finally {
    loadingCustom.value = false
  }
}

// ── Outlet table helpers ──────────────────────────────────────
function outletSalesVal(row) {
  if (periodTab.value === 'day')    return row.sales_day    ?? 0
  if (periodTab.value === 'week')   return row.sales_week   ?? 0
  if (periodTab.value === 'custom') return row.sales_custom ?? 0
  return row.sales_month ?? 0
}
function outletPrevVal(row) {
  if (periodTab.value === 'day')    return row.sales_day_prev    ?? 0
  if (periodTab.value === 'week')   return row.sales_week_prev   ?? 0
  if (periodTab.value === 'custom') return row.sales_custom_prev ?? 0
  return row.sales_month_prev ?? 0
}

// ── Helpers ───────────────────────────────────────────────────
function formatStatValue(card, val) {
  if (val == null) return '—'
  if (card.format === 'currency') return formatRupiah(val)
  return Number(val).toLocaleString('id-ID')
}

function calcPct(curr, prev) {
  const c = curr ?? 0, p = prev ?? 0
  if (p === 0) return c > 0 ? '+100%' : '0%'
  const pct = ((c - p) / p) * 100
  return (pct >= 0 ? '+' : '') + pct.toFixed(1) + '%'
}

function trendClass(curr, prev) {
  const c = curr ?? 0, p = prev ?? 0
  if (c === p || p === 0 && c === 0) return 'pct-neutral'
  return c >= p ? 'pct-up' : 'pct-down'
}

function pctClass(curr, prev) {
  return trendClass(curr, prev)
}
</script>

<style scoped>
/* ── Root ── */
.dash-root { display: flex; flex-direction: column; gap: 1.5rem; }

/* ── Page header ── */
.page-header {
  display: flex; align-items: flex-end;
  justify-content: space-between; flex-wrap: wrap; gap: .75rem;
}
.page-title {
  font-size: 1.5rem; font-weight: 800; color: #0f4226;
  letter-spacing: -.03em; line-height: 1.15;
}
.page-sub { margin-top: .2rem; font-size: .82rem; color: #5a7866; }

.date-chip {
  display: flex; align-items: center; gap: .4rem;
  padding: .32rem .85rem; border-radius: 999px;
  background: rgba(255,255,255,.72);
  backdrop-filter: blur(16px) saturate(160%);
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
.stat-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: .875rem;
}

/* ── Stat card ── */
.stat-card {
  position: relative; overflow: hidden; border-radius: 1.1rem;
  padding: 1.1rem 1.15rem .9rem;
  background: rgba(255,255,255,.75);
  backdrop-filter: blur(24px) saturate(180%);
  border: 1px solid rgba(255,255,255,.68);
  box-shadow: 0 2px 14px rgba(0,0,0,.07), 0 1px 0 rgba(255,255,255,.95) inset;
  transition: transform .18s ease, box-shadow .18s ease;
  cursor: default;
}
.stat-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 8px 28px rgba(0,0,0,.10), 0 1px 0 rgba(255,255,255,.95) inset;
}
.sc-glare {
  position: absolute; inset: 0; pointer-events: none; border-radius: inherit;
  background: linear-gradient(135deg, rgba(255,255,255,.52) 0%, rgba(255,255,255,0) 55%);
}
.sc-blob {
  position: absolute; top: -28px; right: -28px;
  width: 90px; height: 90px; border-radius: 50%;
  filter: blur(28px); opacity: .16; pointer-events: none;
}
.sc-blue    .sc-blob { background: #3b82f6; }
.sc-emerald .sc-blob { background: #10b981; }
.sc-amber   .sc-blob { background: #f59e0b; }
.sc-violet  .sc-blob { background: #8b5cf6; }

.sc-icon-wrap {
  display: flex; align-items: center; justify-content: center;
  width: 34px; height: 34px; border-radius: .65rem; flex-shrink: 0;
}
.sc-blue    .sc-icon-wrap { background: rgba(59,130,246,.12);  color: #2563eb; }
.sc-emerald .sc-icon-wrap { background: rgba(16,185,129,.13);  color: #059669; }
.sc-amber   .sc-icon-wrap { background: rgba(245,158,11,.13);  color: #d97706; }
.sc-violet  .sc-icon-wrap { background: rgba(139,92,246,.12);  color: #7c3aed; }

.sc-top { display: flex; align-items: center; gap: .65rem; margin-bottom: .75rem; }
.sc-label {
  font-size: .68rem; font-weight: 700; text-transform: uppercase;
  letter-spacing: .07em; color: #6b7f74; line-height: 1.3;
}

.sc-value-row { margin-bottom: .7rem; min-height: 1.8rem; }
.sc-value {
  font-size: clamp(1.1rem, 2.8vw, 1.45rem);
  font-weight: 800; color: #0f2d1d;
  letter-spacing: -.035em; line-height: 1;
  word-break: break-word;
}
.sc-skel {
  display: inline-block; width: 72px; height: 1.5rem; border-radius: .4rem;
  background: linear-gradient(90deg, #e5eae7 25%, #f0f4f1 50%, #e5eae7 75%);
  background-size: 200% 100%; animation: shimmer 1.4s infinite;
}
@keyframes shimmer {
  0%   { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

.sc-footer {
  display: flex; align-items: center; justify-content: space-between; gap: .5rem;
  padding-top: .55rem; border-top: 1px solid rgba(0,0,0,.06);
  min-height: 1.6rem;
}
.sc-tag { font-size: .67rem; color: #8a9e93; font-weight: 500; }

/* Trend badge inside card footer */
.trend-badge {
  display: inline-flex; align-items: center; gap: .2rem;
  font-size: .67rem; font-weight: 700;
  border-radius: 999px; padding: .14rem .44rem;
}
.pct-up      { background: rgba(22,163,74,.13);  color: #16a34a; }
.pct-down    { background: rgba(220,38,38,.10);   color: #dc2626; }
.pct-neutral { background: rgba(107,114,128,.10); color: #6b7280; }

/* ── Data panel (outlet table) ── */
.data-panel {
  border-radius: 1.1rem; overflow: hidden;
  background: rgba(255,255,255,.78);
  backdrop-filter: blur(24px) saturate(180%);
  border: 1px solid rgba(255,255,255,.68);
  box-shadow: 0 2px 16px rgba(0,0,0,.07), 0 1px 0 rgba(255,255,255,.95) inset;
}
.dp-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: .9rem 1.2rem;
  border-bottom: 1px solid rgba(0,0,0,.06);
  background: linear-gradient(135deg, rgba(255,255,255,.6) 0%, rgba(240,249,244,.4) 100%);
}
.dp-title-row { display: flex; align-items: center; gap: .55rem; }
.dp-icon {
  display: flex; align-items: center; justify-content: center;
  width: 30px; height: 30px; border-radius: .55rem;
  background: rgba(16,185,129,.12); color: #059669;
}
.dp-title { font-size: .9rem; font-weight: 700; color: #0f3d23; }
.dp-count {
  display: inline-flex; align-items: center; justify-content: center;
  min-width: 20px; height: 20px; padding: 0 .4rem;
  border-radius: 999px; background: rgba(16,185,129,.15);
  color: #059669; font-size: .67rem; font-weight: 700;
}
.dp-link {
  display: inline-flex; align-items: center; gap: .3rem;
  font-size: .75rem; font-weight: 600; color: #2d8f56;
  text-decoration: none; padding: .28rem .65rem;
  border-radius: .5rem; background: rgba(45,143,86,.08);
  transition: background .15s;
}
.dp-link:hover { background: rgba(45,143,86,.16); }

/* ── Filter row ── */
.dp-filters {
  display: flex; align-items: center; flex-wrap: wrap; gap: .75rem;
  padding: .7rem 1.2rem;
  border-bottom: 1px solid rgba(0,0,0,.05);
  background: rgba(248,252,249,.6);
}

/* Period pills */
.period-pills { display: flex; gap: .35rem; }
.period-pill {
  display: inline-flex; align-items: center; gap: .28rem;
  padding: .26rem .75rem; border-radius: 999px; cursor: pointer;
  font-size: .72rem; font-weight: 600;
  background: rgba(255,255,255,.7);
  backdrop-filter: blur(8px);
  border: 1px solid rgba(0,0,0,.07);
  color: #5a7866;
  transition: all .15s ease;
}
.period-pill:hover { background: rgba(255,255,255,.92); border-color: rgba(45,143,86,.2); color: #2d5c40; }
.period-pill--active {
  background: linear-gradient(135deg, #1a5c38, #0f4226);
  color: #fff; border-color: transparent;
  box-shadow: 0 2px 8px rgba(15,66,38,.3);
}

/* Custom date range inputs */
.date-range {
  display: flex; align-items: flex-end; flex-wrap: wrap; gap: .55rem;
  padding: .5rem .75rem; border-radius: .8rem;
  background: rgba(255,255,255,.82);
  backdrop-filter: blur(16px) saturate(160%);
  border: 1px solid rgba(255,255,255,.7);
  box-shadow: 0 2px 12px rgba(0,0,0,.07);
}
.dr-group { display: flex; flex-direction: column; gap: .18rem; }
.dr-label { font-size: .62rem; font-weight: 600; color: #7a9e8a; text-transform: uppercase; letter-spacing: .06em; }
.dr-input-wrap {
  position: relative; display: flex; align-items: center;
}
.dr-ico {
  position: absolute; left: .55rem; color: #7a9e8a; pointer-events: none; z-index: 1;
}
.dr-input {
  padding: .3rem .6rem .3rem 1.8rem;
  border-radius: .55rem;
  background: rgba(240,247,243,.9);
  border: 1px solid rgba(0,0,0,.08);
  color: #1a3d2a; font-size: .75rem; font-weight: 500;
  outline: none; cursor: pointer;
  transition: border-color .15s, box-shadow .15s;
  -webkit-appearance: none;
  /* ensure calendar icon is visible but styled */
  color-scheme: light;
}
.dr-input:focus {
  border-color: rgba(45,143,86,.4);
  box-shadow: 0 0 0 3px rgba(45,143,86,.1);
}
.dr-sep { font-size: .9rem; color: #9ab5a5; font-weight: 300; padding-bottom: .15rem; }
.dr-apply {
  display: inline-flex; align-items: center; justify-content: center; gap: .3rem;
  padding: .32rem .9rem; border-radius: .55rem;
  background: linear-gradient(135deg, #1a5c38, #0f4226);
  color: #fff; font-size: .72rem; font-weight: 700;
  cursor: pointer; border: none;
  box-shadow: 0 2px 8px rgba(15,66,38,.28);
  transition: opacity .15s, transform .15s;
  min-width: 72px;
}
.dr-apply:disabled { opacity: .45; cursor: not-allowed; transform: none; }
.dr-apply:not(:disabled):hover { opacity: .88; transform: translateY(-1px); }
.dr-spinner {
  display: inline-block; width: 12px; height: 12px; border-radius: 50%;
  border: 2px solid rgba(255,255,255,.3);
  border-top-color: #fff;
  animation: spin .7s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }

/* Slide-in transition for date range panel */
.dr-slide-enter-active { transition: all .22s ease-out; }
.dr-slide-leave-active { transition: all .18s ease-in; }
.dr-slide-enter-from, .dr-slide-leave-to { opacity: 0; transform: translateX(-8px); }

/* ── Sales cell in table ── */
.sales-cell { display: flex; flex-direction: column; gap: .14rem; }
.sales-val  { font-size: .82rem; font-weight: 600; color: #0f2d1d; }
.sales-pct  {
  display: inline-flex; align-items: center; gap: .15rem;
  font-size: .66rem; font-weight: 700;
  border-radius: 999px; padding: .1rem .38rem; width: fit-content;
}
.sync-time { font-size: .78rem; color: #7a9e8a; }
</style>
