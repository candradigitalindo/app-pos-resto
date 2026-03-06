<template>
  <div class="page-shell relative">
    <div class="page-container space-y-6 relative z-10 pb-24 lg:pb-6">
      <div class="card lg:hidden">
        <div class="flex items-center justify-between">
          <div>
            <div class="flex items-center gap-3 mb-2">
              <h1 class="text-2xl font-bold bg-gradient-to-r from-emerald-600 to-emerald-500 bg-clip-text text-transparent">Dashboard</h1>
              <div class="px-2 py-1 bg-emerald-50 rounded-lg">
                <span class="text-xs font-semibold flex items-center gap-1">
                  <span 
                    :class="[
                      'w-1.5 h-1.5 rounded-full',
                      isOnline ? 'bg-emerald-500 animate-pulse' : 'bg-red-500'
                    ]"
                  ></span>
                  <span :class="isOnline ? 'text-emerald-700' : 'text-red-700'">
                    {{ isOnline ? 'Online' : 'Offline' }}
                  </span>
                </span>
              </div>
            </div>
            <p class="text-sm text-slate-500">Diperbarui {{ lastUpdated }}</p>
          </div>
        </div>
      </div>
      
      <div class="hidden lg:block">
        <p class="subtitle">Diperbarui {{ lastUpdated }}</p>
      </div>

      <div class="card flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
        <div class="flex flex-wrap gap-2">
          <button
            @click="setPeriod('daily')"
            :class="[activePeriod === 'daily' ? 'bg-emerald-600 text-white' : 'bg-white text-slate-600 border border-slate-200', 'cursor-pointer rounded-xl px-4 py-2 text-sm font-semibold transition hover:scale-105 active:scale-95']"
          >
            Harian
          </button>
          <button
            @click="setPeriod('weekly')"
            :class="[activePeriod === 'weekly' ? 'bg-emerald-600 text-white' : 'bg-white text-slate-600 border border-slate-200', 'cursor-pointer rounded-xl px-4 py-2 text-sm font-semibold transition hover:scale-105 active:scale-95']"
          >
            Mingguan
          </button>
          <button
            @click="setPeriod('monthly')"
            :class="[activePeriod === 'monthly' ? 'bg-emerald-600 text-white' : 'bg-white text-slate-600 border border-slate-200', 'cursor-pointer rounded-xl px-4 py-2 text-sm font-semibold transition hover:scale-105 active:scale-95']"
          >
            Bulanan
          </button>
        </div>
        <div class="flex items-center gap-3">
          <button @click="navigatePeriod(-1)" class="btn-secondary cursor-pointer">‹</button>
          <span class="text-sm font-semibold text-slate-700">{{ periodLabel }}</span>
          <button @click="navigatePeriod(1)" class="btn-secondary cursor-pointer">›</button>
        </div>
      </div>

      <div class="card">
        <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
          <div>
            <p class="text-sm font-semibold text-slate-500">Total Penjualan</p>
            <p class="mt-2 text-3xl font-semibold text-slate-900" v-if="!isLoading">
              {{ formatRupiah(netRevenue) }}
            </p>
            <p class="mt-2 text-3xl font-semibold text-slate-900" v-else>Memuat...</p>
            <div v-if="analytics.void_total || analytics.cancelled_total" class="mt-2 flex flex-wrap gap-3 text-xs text-slate-500">
              <span v-if="analytics.void_total">Void: -{{ formatRupiah(analytics.void_total) }}</span>
              <span v-if="analytics.cancelled_total">Batal: -{{ formatRupiah(analytics.cancelled_total) }}</span>
            </div>
            <div v-if="analytics.additional_charges_items && analytics.additional_charges_items.length" class="mt-2 flex flex-wrap gap-2 text-xs text-slate-500">
              <span v-for="(item, index) in analytics.additional_charges_items" :key="index">
                {{ formatAdditionalChargeLabel(item) }}
              </span>
            </div>
          </div>
          <span class="rounded-full px-3 py-1 text-xs font-semibold" :class="getChangeClass(analytics.revenue_change_pct)">
            {{ formatChange(analytics.revenue_change_pct) }}
          </span>
        </div>

        <div class="mt-4 grid gap-3 sm:grid-cols-2">
          <div class="rounded-xl border border-slate-200 bg-slate-50 p-3">
            <p class="text-xs text-slate-500">Penjualan Terbayar</p>
            <p class="mt-1 text-lg font-semibold text-slate-900">{{ formatRupiah(analytics.paid_revenue) }}</p>
            <span class="mt-2 inline-flex rounded-full px-2 py-1 text-xs font-semibold" :class="getChangeClass(analytics.paid_revenue_change_pct)">
              {{ formatChange(analytics.paid_revenue_change_pct) }}
            </span>
          </div>
          <div class="rounded-xl border border-slate-200 bg-slate-50 p-3">
            <p class="text-xs text-slate-500">Penjualan Belum Dibayar</p>
            <p class="mt-1 text-lg font-semibold text-slate-900">{{ formatRupiah(analytics.unpaid_revenue) }}</p>
            <span class="mt-2 inline-flex rounded-full px-2 py-1 text-xs font-semibold" :class="getChangeClass(analytics.unpaid_revenue_change_pct)">
              {{ formatChange(analytics.unpaid_revenue_change_pct) }}
            </span>
          </div>
        </div>

        <div class="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <div class="rounded-xl border border-slate-200 bg-white p-3">
            <p class="text-xs text-slate-500">Transaksi</p>
            <p class="mt-1 text-lg font-semibold text-slate-900">{{ analytics.total_orders }}</p>
            <span class="mt-2 inline-flex rounded-full px-2 py-1 text-xs font-semibold" :class="getChangeClass(analytics.orders_change_pct)">
              {{ formatChange(analytics.orders_change_pct) }}
            </span>
          </div>
          <div class="rounded-xl border border-slate-200 bg-white p-3">
            <p class="text-xs text-slate-500">Basket Value</p>
            <p class="mt-1 text-lg font-semibold text-slate-900">{{ formatRupiah(analytics.avg_order_value) }}</p>
            <span class="mt-2 inline-flex rounded-full px-2 py-1 text-xs font-semibold" :class="getChangeClass(analytics.avg_order_change_pct)">
              {{ formatChange(analytics.avg_order_change_pct) }}
            </span>
          </div>
          <div class="rounded-xl border border-slate-200 bg-white p-3">
            <p class="text-xs text-slate-500">Produk Terjual</p>
            <p class="mt-1 text-lg font-semibold text-slate-900">{{ Math.round(analytics.products_sold) }}</p>
            <span class="mt-2 inline-flex rounded-full px-2 py-1 text-xs font-semibold" :class="getChangeClass(analytics.products_sold_change_pct)">
              {{ formatChange(analytics.products_sold_change_pct) }}
            </span>
          </div>
          <div class="rounded-xl border border-slate-200 bg-white p-3">
            <p class="text-xs text-slate-500">Penjualan per Transaksi</p>
            <p class="mt-1 text-lg font-semibold text-slate-900">{{ formatRupiah(analytics.avg_order_value) }}</p>
            <span class="mt-2 inline-flex rounded-full px-2 py-1 text-xs font-semibold" :class="getChangeClass(analytics.avg_order_change_pct)">
              {{ formatChange(analytics.avg_order_change_pct) }}
            </span>
          </div>
        </div>
      </div>

      <div class="card overflow-hidden">
        <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between mb-4">
          <div>
            <h3 class="text-lg font-semibold text-slate-900">Penjualan {{ periodLabel }}</h3>
            <p class="text-sm text-slate-500">{{ activePeriod === 'daily' ? 'Penjualan per Jam' : 'Penjualan Harian' }}</p>
          </div>
          <div class="flex items-center gap-2">
            <span class="inline-flex items-center gap-1.5 text-xs font-medium text-slate-500">
              <span class="w-3 h-0.5 rounded-full bg-emerald-500"></span>
              Total Penjualan
            </span>
          </div>
        </div>

        <!-- Chart Container -->
        <div class="relative" ref="chartContainer">
          <!-- Y-axis labels -->
          <div class="absolute left-0 top-0 bottom-8 flex flex-col justify-between text-[10px] sm:text-xs text-slate-400 font-medium z-10 pr-2">
            <span v-for="(label, i) in yAxisLabels" :key="i" class="leading-none">{{ label }}</span>
          </div>

          <!-- Chart area -->
          <div class="ml-10 sm:ml-14">
            <div class="relative h-48 sm:h-56 lg:h-64 w-full">
              <!-- Grid lines -->
              <div class="absolute inset-0 flex flex-col justify-between pointer-events-none">
                <div v-for="i in 5" :key="i" class="border-b border-dashed border-slate-100 w-full" :class="i === 5 ? 'border-slate-200' : ''"></div>
              </div>

              <!-- SVG Chart -->
              <svg
                class="absolute inset-0 w-full h-full"
                :viewBox="`0 0 ${svgWidth} ${svgHeight}`"
                preserveAspectRatio="none"
                @mousemove="handleChartHover"
                @touchmove.prevent="handleChartTouch"
                @mouseleave="clearChartHover"
                @touchend="clearChartHover"
              >
                <defs>
                  <linearGradient id="chartGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stop-color="#10B981" stop-opacity="0.3" />
                    <stop offset="50%" stop-color="#10B981" stop-opacity="0.1" />
                    <stop offset="100%" stop-color="#10B981" stop-opacity="0.02" />
                  </linearGradient>
                  <filter id="glow">
                    <feGaussianBlur stdDeviation="2" result="blur" />
                    <feMerge><feMergeNode in="blur" /><feMergeNode in="SourceGraphic" /></feMerge>
                  </filter>
                </defs>

                <!-- Area fill -->
                <path v-if="chartAreaPath" :d="chartAreaPath" fill="url(#chartGradient)" />

                <!-- Line -->
                <path v-if="chartPath" :d="chartPath" fill="none" stroke="#10B981" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round" vector-effect="non-scaling-stroke" />

                <!-- Hover line -->
                <line
                  v-if="hoveredPoint"
                  :x1="hoveredPoint.x"
                  :x2="hoveredPoint.x"
                  y1="0"
                  :y2="svgHeight"
                  stroke="#10B981"
                  stroke-width="1"
                  stroke-dasharray="4 4"
                  opacity="0.4"
                  vector-effect="non-scaling-stroke"
                />

                <!-- Data points on hover -->
                <circle
                  v-if="hoveredPoint"
                  :cx="hoveredPoint.x"
                  :cy="hoveredPoint.y"
                  r="5"
                  fill="#10B981"
                  stroke="white"
                  stroke-width="2"
                  filter="url(#glow)"
                  vector-effect="non-scaling-stroke"
                />
              </svg>

              <!-- Hover Tooltip -->
              <div
                v-if="hoveredPoint"
                class="pointer-events-none absolute z-20 transition-all duration-100"
                :style="tooltipStyle"
              >
                <div class="rounded-xl border border-emerald-100 bg-white/95 backdrop-blur-sm px-3 py-2 shadow-lg shadow-emerald-500/10 whitespace-nowrap">
                  <div class="text-[10px] font-medium text-slate-400">{{ hoveredPoint.label }}</div>
                  <div class="text-sm font-bold text-emerald-600">{{ formatRupiah(hoveredPoint.revenue) }}</div>
                </div>
              </div>
            </div>

            <!-- X-axis labels -->
            <div class="flex justify-between mt-2 overflow-hidden">
              <span
                v-for="(label, i) in xAxisLabelsFiltered"
                :key="i"
                class="text-[9px] sm:text-[10px] lg:text-xs text-slate-400 font-medium truncate text-center"
                :style="{ width: `${100 / xAxisLabelsFiltered.length}%` }"
              >{{ label }}</span>
            </div>
          </div>
        </div>

        <!-- Summary stats below chart -->
        <div v-if="chartData.length > 0 && !isLoading" class="mt-4 pt-4 border-t border-slate-100 grid grid-cols-3 gap-3">
          <div class="text-center">
            <p class="text-[10px] sm:text-xs text-slate-400 font-medium">Tertinggi</p>
            <p class="text-xs sm:text-sm font-bold text-emerald-600 mt-0.5">{{ formatRupiah(chartMax) }}</p>
          </div>
          <div class="text-center">
            <p class="text-[10px] sm:text-xs text-slate-400 font-medium">Rata-rata</p>
            <p class="text-xs sm:text-sm font-bold text-slate-700 mt-0.5">{{ formatRupiah(chartAvg) }}</p>
          </div>
          <div class="text-center">
            <p class="text-[10px] sm:text-xs text-slate-400 font-medium">Terendah</p>
            <p class="text-xs sm:text-sm font-bold text-slate-400 mt-0.5">{{ formatRupiah(chartMin) }}</p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import api from '../services/api'
import { formatRupiah } from '../utils/currency'

const router = useRouter()
const authStore = useAuthStore()

const isOnline = ref(navigator.onLine)

// Monitor internet connection status
const updateOnlineStatus = () => {
  isOnline.value = navigator.onLine
}

onMounted(() => {
  window.addEventListener('online', updateOnlineStatus)
  window.addEventListener('offline', updateOnlineStatus)
  updateDateRange()
  fetchAnalytics()
  fetchChartData()
})

// Cleanup event listeners on unmount
onUnmounted(() => {
  window.removeEventListener('online', updateOnlineStatus)
  window.removeEventListener('offline', updateOnlineStatus)
})

const lastUpdated = ref(new Date().toLocaleString('id-ID'))

const startDate = ref('')
const endDate = ref('')
const activePeriod = ref('daily')
const periodLabel = ref('')
const currentDate = ref(new Date())

const analytics = ref({
  total_orders: 0,
  total_revenue: 0,
  avg_order_value: 0,
  avg_basket_size: 0,
  avg_pax: 0,
  total_pax: 0,
  revenue_change_pct: 0,
  orders_change_pct: 0,
  avg_order_change_pct: 0,
  basket_change_pct: 0,
  paid_revenue: 0,
  unpaid_revenue: 0,
  paid_revenue_change_pct: 0,
  unpaid_revenue_change_pct: 0,
  additional_charges_total: 0,
  additional_charges_items: [],
  void_total: 0,
  cancelled_total: 0,
  products_sold: 0,
  products_sold_change_pct: 0
})

const chartData = ref([])
const maxRevenue = ref(0)
const isLoading = ref(false)
const hoveredPoint = ref(null)
const chartContainer = ref(null)
const netRevenue = computed(() => analytics.value.total_revenue)

const svgWidth = 1000
const svgHeight = 300
const svgPadding = { top: 10, bottom: 10, left: 0, right: 0 }

const formatAdditionalChargeLabel = (item) => {
  if (!item) return ''
  const name = item.name || ''
  if (item.charge_type === 'percentage') {
    const hasPercentInName = name.includes('%')
    const value = item.value
    const percentValue = value != null && !Number.isNaN(value) ? `${value}%` : '%'
    const label = hasPercentInName ? name : `${name} (${percentValue})`
    return `${label}: ${formatRupiah(item.total_amount)}`
  }
  return `${name} (Rp): ${formatRupiah(item.total_amount)}`
}

const formatChange = (pct) => {
  const abs = Math.abs(pct)
  const formatted = abs.toFixed(2)
  return pct >= 0 ? `▲ ${formatted}%` : `▼ ${formatted}%`
}

const getChangeClass = (pct) => {
  return pct >= 0 ? 'bg-emerald-100 text-emerald-700' : 'bg-red-100 text-red-600'
}

const formatDateInput = (date) => {
  const target = new Date(date)
  const year = target.getFullYear()
  const month = String(target.getMonth() + 1).padStart(2, '0')
  const day = String(target.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

const chartPath = computed(() => {
  if (chartData.value.length === 0) return ''

  const max = maxRevenue.value || 1
  const points = chartData.value.length
  const usableW = svgWidth - svgPadding.left - svgPadding.right
  const usableH = svgHeight - svgPadding.top - svgPadding.bottom
  const stepX = points > 1 ? usableW / (points - 1) : 0

  return chartData.value.map((point, i) => {
    const x = svgPadding.left + (i * stepX)
    const y = svgPadding.top + usableH - ((point.revenue / max) * usableH)
    return `${i === 0 ? 'M' : 'L'} ${x} ${y}`
  }).join(' ')
})

const chartAreaPath = computed(() => {
  if (!chartPath.value) return ''
  const points = chartData.value.length
  const usableW = svgWidth - svgPadding.left - svgPadding.right
  const stepX = points > 1 ? usableW / (points - 1) : 0
  const lastX = svgPadding.left + ((points - 1) * stepX)
  const firstX = svgPadding.left
  return `${chartPath.value} L ${lastX} ${svgHeight} L ${firstX} ${svgHeight} Z`
})

const getPointLabel = (point) => {
  if (activePeriod.value === 'daily') {
    return `${point.time_label}:00`
  }
  const date = new Date(point.time_label)
  return `${date.getDate()}/${date.getMonth() + 1}`
}

const chartPoints = computed(() => {
  if (chartData.value.length === 0) return []

  const max = maxRevenue.value || 1
  const points = chartData.value.length
  const usableW = svgWidth - svgPadding.left - svgPadding.right
  const usableH = svgHeight - svgPadding.top - svgPadding.bottom
  const stepX = points > 1 ? usableW / (points - 1) : 0

  return chartData.value.map((point, index) => {
    const x = svgPadding.left + (index * stepX)
    const y = svgPadding.top + usableH - ((point.revenue / max) * usableH)
    return {
      x,
      y,
      revenue: point.revenue || 0,
      label: getPointLabel(point)
    }
  })
})

const handleChartHover = (event) => {
  if (chartPoints.value.length === 0) return
  const svg = event.currentTarget
  const rect = svg.getBoundingClientRect()
  const x = event.clientX - rect.left
  const scaleX = svgWidth / rect.width
  const chartX = x * scaleX

  let closest = chartPoints.value[0]
  let closestDistance = Math.abs(chartPoints.value[0].x - chartX)

  chartPoints.value.forEach((point) => {
    const distance = Math.abs(point.x - chartX)
    if (distance < closestDistance) {
      closest = point
      closestDistance = distance
    }
  })

  // Calculate pixel position for tooltip
  const pxX = (closest.x / svgWidth) * rect.width
  const pxY = (closest.y / svgHeight) * rect.height

  hoveredPoint.value = { ...closest, pxX, pxY }
}

const handleChartTouch = (event) => {
  if (event.touches.length === 0) return
  const touch = event.touches[0]
  const svg = event.currentTarget
  const rect = svg.getBoundingClientRect()
  const fakeEvent = { currentTarget: svg, clientX: touch.clientX, clientY: touch.clientY }
  handleChartHover(fakeEvent)
}

const tooltipStyle = computed(() => {
  if (!hoveredPoint.value || !chartContainer.value) return {}
  const containerW = chartContainer.value?.querySelector('.relative')?.offsetWidth || 300
  const pxX = hoveredPoint.value.pxX || 0
  const pxY = hoveredPoint.value.pxY || 0

  // Flip tooltip to right if too close to left edge
  const flipX = pxX < 80
  const left = flipX ? `${pxX + 12}px` : `${pxX - 12}px`
  const transform = flipX ? 'translateY(-100%)' : 'translate(-100%, -100%)'

  return {
    left,
    top: `${pxY - 8}px`,
    transform
  }
})

const chartMax = computed(() => Math.max(...chartData.value.map(d => d.revenue || 0), 0))
const chartMin = computed(() => {
  const revenues = chartData.value.map(d => d.revenue || 0)
  return revenues.length > 0 ? Math.min(...revenues) : 0
})
const chartAvg = computed(() => {
  if (chartData.value.length === 0) return 0
  const total = chartData.value.reduce((sum, d) => sum + (d.revenue || 0), 0)
  return total / chartData.value.length
})

const clearChartHover = () => {
  hoveredPoint.value = null
}

const yAxisLabels = computed(() => {
  const max = maxRevenue.value
  if (max === 0) return ['0', '0', '0', '0', '0']

  const formatShort = (amount) => {
    if (amount >= 1000000) {
      const v = amount / 1000000
      return v % 1 === 0 ? v.toFixed(0) + ' jt' : v.toFixed(1) + ' jt'
    }
    if (amount >= 1000) return (amount / 1000).toFixed(0) + ' rb'
    return amount.toFixed(0)
  }
  
  // Top to bottom: max → 0
  return [
    formatShort(max),
    formatShort(max * 0.75),
    formatShort(max * 0.5),
    formatShort(max * 0.25),
    '0'
  ]
})

const xAxisLabels = computed(() => {
  if (chartData.value.length === 0) return []

  if (activePeriod.value === 'daily') {
    return chartData.value.map((d) => d.time_label + ':00')
  }

  return chartData.value.map((d) => {
    const date = new Date(d.time_label)
    return `${date.getDate()}/${date.getMonth() + 1}`
  })
})

// Adaptive filtered labels for display (avoid crowding)
const xAxisLabelsFiltered = computed(() => {
  const labels = xAxisLabels.value
  if (labels.length <= 8) return labels

  // Show roughly 6-10 labels evenly
  const targetCount = window.innerWidth < 640 ? 6 : window.innerWidth < 1024 ? 8 : 12
  const step = Math.ceil(labels.length / targetCount)
  return labels.filter((_, i) => i % step === 0 || i === labels.length - 1)
})

const updateDateRange = () => {
  const date = new Date(currentDate.value)

  if (activePeriod.value === 'daily') {
    startDate.value = formatDateInput(date)
    endDate.value = formatDateInput(date)
    periodLabel.value = date.toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' })
  } else if (activePeriod.value === 'weekly') {
    const firstDay = new Date(date)
    firstDay.setDate(date.getDate() - date.getDay())
    const lastDay = new Date(firstDay)
    lastDay.setDate(firstDay.getDate() + 6)

    startDate.value = formatDateInput(firstDay)
    endDate.value = formatDateInput(lastDay)
    periodLabel.value = `${firstDay.getDate()} ${firstDay.toLocaleDateString('id-ID', { month: 'short' })} - ${lastDay.getDate()} ${lastDay.toLocaleDateString('id-ID', { month: 'short', year: 'numeric' })}`
  } else {
    const firstDay = new Date(date.getFullYear(), date.getMonth(), 1)
    const lastDay = new Date(date.getFullYear(), date.getMonth() + 1, 0)

    startDate.value = formatDateInput(firstDay)
    endDate.value = formatDateInput(lastDay)
    periodLabel.value = date.toLocaleDateString('id-ID', { month: 'long', year: 'numeric' })
  }
}

const setPeriod = (period) => {
  activePeriod.value = period
  currentDate.value = new Date()
  updateDateRange()
  fetchAnalytics()
  fetchChartData()
}

const navigatePeriod = (direction) => {
  const date = new Date(currentDate.value)

  if (activePeriod.value === 'daily') {
    date.setDate(date.getDate() + direction)
  } else if (activePeriod.value === 'weekly') {
    date.setDate(date.getDate() + direction * 7)
  } else {
    date.setMonth(date.getMonth() + direction)
  }

  currentDate.value = date
  updateDateRange()
  fetchAnalytics()
  fetchChartData()
}

const fetchAnalytics = async () => {
  isLoading.value = true
  try {
    const response = await api.get('/orders/analytics', {
      params: {
        start_date: startDate.value,
        end_date: endDate.value
      }
    })

    if (response.data?.success) {
      const payload = response.data.data.analytics || {}
      const items = Array.isArray(payload.additional_charges_items)
        ? payload.additional_charges_items.filter((item) => (item?.total_amount || 0) !== 0)
        : []
      analytics.value = {
        ...payload,
        additional_charges_items: items
      }
      lastUpdated.value = new Date().toLocaleString('id-ID')
    }
  } catch (error) {
    console.error('Failed to fetch analytics:', error)
  } finally {
    isLoading.value = false
  }
}

const fetchChartData = async () => {
  try {
    const response = await api.get('/orders/chart', {
      params: {
        start_date: startDate.value,
        end_date: endDate.value,
        period: activePeriod.value
      }
    })

    if (response.data?.success) {
      chartData.value = response.data.data.data || []
      maxRevenue.value = Math.max(...chartData.value.map((item) => item.revenue || 0), 0)
    }
  } catch (error) {
    console.error('Failed to fetch chart data:', error)
  }
}

const handleLogout = async () => {
  await authStore.logout()
  router.push('/login')
}
</script>
