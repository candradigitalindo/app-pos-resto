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

      <div class="card">
        <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h3 class="text-lg font-semibold text-slate-900">Penjualan {{ periodLabel }}</h3>
            <p class="subtitle">{{ activePeriod === 'daily' ? 'Penjualan per Jam' : 'Penjualan Harian' }}</p>
          </div>
          <span class="badge">Total Penjualan</span>
        </div>
        <div class="mt-6 grid gap-4 lg:grid-cols-[auto,1fr]">
          <div class="hidden sm:flex flex-col gap-3 text-xs text-slate-500">
            <span v-for="(label, i) in yAxisLabels" :key="i">{{ label }}</span>
          </div>
          <div class="overflow-x-auto">
            <div class="min-w-[640px] lg:min-w-0">
              <div class="relative h-56 sm:h-64 lg:h-72 w-full rounded-2xl border border-slate-200 bg-slate-50 p-4">
                <svg
                  viewBox="0 0 800 200"
                  class="h-full w-full"
                  @mousemove="handleChartHover"
                  @mouseleave="clearChartHover"
                >
                  <path v-if="chartPath" :d="chartPath" fill="none" stroke="#10B981" stroke-width="3" />
                  <line
                    v-if="hoveredPoint"
                    :x1="hoveredPoint.x"
                    :x2="hoveredPoint.x"
                    y1="0"
                    y2="200"
                    stroke="#10B981"
                    stroke-width="1"
                    stroke-dasharray="4 4"
                    opacity="0.5"
                  />
                  <circle
                    v-if="hoveredPoint"
                    :cx="hoveredPoint.x"
                    :cy="hoveredPoint.y"
                    r="5"
                    fill="#10B981"
                    stroke="white"
                    stroke-width="2"
                  />
                </svg>
                <div
                  v-if="hoveredPoint"
                  class="pointer-events-none absolute z-10 -translate-x-1/2 -translate-y-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-xs shadow-lg"
                  :style="{ left: `${hoveredPoint.offsetX}px`, top: `${hoveredPoint.offsetY}px` }"
                >
                  <div class="font-semibold text-slate-700">{{ hoveredPoint.label }}</div>
                  <div class="font-bold text-emerald-600">{{ formatRupiah(hoveredPoint.revenue) }}</div>
                </div>
              </div>
              <div class="mt-3 flex justify-between text-xs text-slate-500">
                <span v-for="(label, i) in xAxisLabels" :key="i">{{ label }}</span>
              </div>
            </div>
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
const netRevenue = computed(() => analytics.value.total_revenue - analytics.value.void_total - analytics.value.cancelled_total)

const formatRupiah = (amount) => {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    minimumFractionDigits: 0
  }).format(amount)
}

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
  if (chartData.value.length === 0 || maxRevenue.value === 0) return ''

  const width = 800
  const height = 200
  const padding = 20
  const dataPoints = chartData.value.length
  const stepX = dataPoints > 1 ? (width - padding * 2) / (dataPoints - 1) : 0

  let path = ''

  chartData.value.forEach((point, index) => {
    const x = padding + (index * stepX)
    const y = height - padding - ((point.revenue / maxRevenue.value) * (height - padding * 2))

    if (index === 0) {
      path = `M ${x} ${y}`
    } else {
      path += ` L ${x} ${y}`
    }
  })

  return path
})

const getPointLabel = (point) => {
  if (activePeriod.value === 'daily') {
    return `${point.time_label}:00`
  }
  const date = new Date(point.time_label)
  return `${date.getDate()}/${date.getMonth() + 1}`
}

const chartPoints = computed(() => {
  if (chartData.value.length === 0 || maxRevenue.value === 0) return []

  const width = 800
  const height = 200
  const padding = 20
  const dataPoints = chartData.value.length
  const stepX = dataPoints > 1 ? (width - padding * 2) / (dataPoints - 1) : 0

  return chartData.value.map((point, index) => {
    const x = padding + (index * stepX)
    const y = height - padding - ((point.revenue / maxRevenue.value) * (height - padding * 2))
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
  const rect = event.currentTarget.getBoundingClientRect()
  const x = event.clientX - rect.left
  const scaleX = 800 / rect.width
  const chartX = x * scaleX

  let closest = chartPoints.value[0]
  let closestIndex = 0
  let closestDistance = Math.abs(chartPoints.value[0].x - chartX)

  chartPoints.value.forEach((point, index) => {
    const distance = Math.abs(point.x - chartX)
    if (distance < closestDistance) {
      closest = point
      closestIndex = index
      closestDistance = distance
    }
  })

  const offsetX = (closest.x / 800) * rect.width
  const offsetY = (closest.y / 200) * rect.height
  hoveredPoint.value = { ...closest, index: closestIndex, offsetX, offsetY }
}

const clearChartHover = () => {
  hoveredPoint.value = null
}

const yAxisLabels = computed(() => {
  if (maxRevenue.value === 0) return ['0', '1 jt', '2 jt', '3 jt', '4 jt']

  const max = maxRevenue.value
  const formatShort = (amount) => {
    if (amount >= 1000000) return (amount / 1000000).toFixed(1) + ' jt'
    if (amount >= 1000) return (amount / 1000).toFixed(0) + ' rb'
    return amount.toFixed(0)
  }
  
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
    // Show all hours from the data
    return chartData.value.map((d) => d.time_label + ':00')
  }

  const totalPoints = chartData.value.length
  const step = Math.ceil(totalPoints / 10)
  return chartData.value
    .filter((_, i) => i % step === 0)
    .map((d) => {
      const date = new Date(d.time_label)
      return `${date.getDate()}/${date.getMonth() + 1}`
    })
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

onMounted(() => {
  updateDateRange()
  fetchAnalytics()
  fetchChartData()
})
</script>

<style scoped>
/* Pulse Animation */
@keyframes pulse {
  0%, 100% {
    opacity: 1;
  }
  50% {
    opacity: 0.5;
  }
}
</style>
