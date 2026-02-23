<template>
  <div class="min-h-screen bg-slate-50 pb-24 lg:pb-6">
    <div class="mx-auto max-w-7xl px-3 sm:px-4 lg:px-8 py-4 sm:py-6 space-y-4 sm:space-y-6">
      <div class="overflow-hidden rounded-2xl bg-gradient-to-r from-emerald-600 to-emerald-500 p-4 sm:p-6 shadow-xl">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div class="flex items-center gap-3">
            <div class="flex h-12 w-12 sm:h-14 sm:w-14 items-center justify-center rounded-xl bg-white/20 backdrop-blur-sm">
              <svg class="h-7 w-7 sm:h-8 sm:w-8 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 7c0-2.21 1.79-4 4-4h4c2.21 0 4 1.79 4 4v2H6V7z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 9h14l-1 10a2 2 0 01-2 2H8a2 2 0 01-2-2L5 9z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 13h6" />
              </svg>
            </div>
            <div>
              <h1 class="text-xl sm:text-2xl font-bold text-white">{{ headerTitle }}</h1>
              <p class="text-xs sm:text-sm text-emerald-100">Pantau pesanan secara realtime</p>
            </div>
          </div>
          <button @click="fetchOrders" class="flex items-center justify-center gap-2 rounded-xl bg-white px-4 py-2.5 font-semibold text-emerald-600 shadow-lg transition-all hover:scale-105 active:scale-95" :disabled="loading">
            <svg class="h-5 w-5" :class="loading ? 'animate-spin' : ''" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
            <span class="hidden sm:inline">{{ loading ? 'Memuat...' : 'Refresh' }}</span>
          </button>
        </div>
      </div>

      <div v-if="loading && filteredOrders.length === 0" class="rounded-2xl bg-white p-12 text-center shadow-lg">
        <div class="mx-auto mb-4 h-10 w-10 animate-spin rounded-full border-4 border-emerald-200 border-t-emerald-500"></div>
        <div class="text-sm font-semibold text-slate-600">Memuat pesanan...</div>
      </div>

      <div v-else-if="filteredOrders.length === 0" class="rounded-2xl bg-white p-12 text-center shadow-lg">
        <div class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-emerald-50 text-emerald-500">
          <svg class="h-6 w-6" viewBox="0 0 24 24" fill="none" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 4h12l-1.5 9h-9L6 4z" />
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 20a1 1 0 100-2 1 1 0 000 2zM16 20a1 1 0 100-2 1 1 0 000 2z" />
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 8h10" />
          </svg>
        </div>
        <div class="mt-3 text-sm font-semibold text-slate-600">Belum ada pesanan aktif</div>
      </div>

      <div v-else class="grid gap-4 lg:grid-cols-2">
        <div v-for="order in filteredOrders" :key="order.order.id" class="overflow-hidden rounded-2xl border border-slate-100 bg-white shadow-lg">
          <div class="border-b border-slate-100 bg-slate-50 px-4 py-3 sm:px-5">
            <div class="flex items-center justify-between">
              <div>
                <div class="text-sm text-slate-500">Meja</div>
                <div class="text-lg font-semibold text-slate-900">#{{ order.order.table_number }}</div>
              </div>
              <div class="text-right">
                <div class="text-xs text-slate-500">Status</div>
                <div :class="orderStatusClass(order.order.order_status)" class="inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold">
                  {{ getOrderStatusText(order.order.order_status) }}
                </div>
              </div>
            </div>
            <div class="mt-2 text-xs text-slate-500">
              {{ formatDateTime(order.order.created_at) }} · {{ order.items.length }} item
            </div>
          </div>

          <div class="divide-y divide-slate-100">
            <div v-for="item in order.items" :key="item.id" class="flex items-center justify-between gap-3 px-4 py-3 sm:px-5">
              <div>
                <div class="text-sm font-semibold text-slate-900">{{ item.product_name }}</div>
                <div class="mt-1 flex items-center gap-2 text-xs text-slate-500">
                  <span>Qty {{ item.qty }}</span>
                  <span class="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-semibold uppercase" :class="destinationClass(item.destination)">
                    {{ item.destination }}
                  </span>
                  <span class="inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-semibold" :class="itemStatusClass(item.item_status)">
                    {{ getItemStatusText(item.item_status) }}
                  </span>
                </div>
              </div>
              <div class="flex items-center gap-2">
                <button
                  class="rounded-xl px-3 py-2 text-xs font-semibold transition-all"
                  :class="item.item_status === 'pending' ? 'bg-amber-100 text-amber-700 hover:bg-amber-200' : 'bg-slate-100 text-slate-400 cursor-not-allowed'"
                  :disabled="item.item_status !== 'pending' || isUpdating(item.id)"
                  @click="updateItemStatus(item, 'cooking')"
                >
                  Proses
                </button>
                <button
                  class="rounded-xl px-3 py-2 text-xs font-semibold transition-all"
                  :class="item.item_status === 'cooking' ? 'bg-emerald-100 text-emerald-700 hover:bg-emerald-200' : 'bg-slate-100 text-slate-400 cursor-not-allowed'"
                  :disabled="item.item_status !== 'cooking' || isUpdating(item.id)"
                  @click="updateItemStatus(item, 'ready')"
                >
                  Selesai
                </button>
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
import api, { subscribeRealtime } from '../services/api'
import { useAuthStore } from '../stores/auth'

const authStore = useAuthStore()

const orders = ref([])
const loading = ref(false)
const updatingItems = ref({})
let realtimeUnsubscribe = null

const headerTitle = computed(() => {
  const role = authStore.user?.role
  if (role === 'bar') return 'Bar Display'
  return 'Kitchen Display'
})

const destinationRole = computed(() => {
  const role = authStore.user?.role
  if (role === 'kitchen' || role === 'bar') return role
  return ''
})

const filteredOrders = computed(() => {
  if (!destinationRole.value) return orders.value

  return orders.value
    .map((order) => {
      const items = (order.items || []).filter(item => item.destination === destinationRole.value)
      return { ...order, items }
    })
    .filter(order => order.items.length > 0)
})

const fetchOrders = async () => {
  loading.value = true
  try {
    const response = await api.get('/orders/pending')
    orders.value = response.data.data?.orders || []
  } catch (error) {
    orders.value = []
  } finally {
    loading.value = false
  }
}

const isUpdating = (itemId) => !!updatingItems.value[itemId]

const updateItemStatus = async (item, status) => {
  if (isUpdating(item.id)) return
  updatingItems.value = { ...updatingItems.value, [item.id]: true }
  try {
    await api.put(`/orders/items/${item.id}/status`, { status })
    await fetchOrders()
  } catch (error) {
  } finally {
    updatingItems.value = { ...updatingItems.value, [item.id]: false }
  }
}

const handleRealtimeEvent = async (event) => {
  if (!event?.type) return
  if (
    event.type === 'order_created' ||
    event.type === 'order_items_updated' ||
    event.type === 'orders_merged' ||
    event.type === 'payment_completed' ||
    event.type === 'item_status_updated'
  ) {
    await fetchOrders()
  }
}

const getItemStatusText = (status) => {
  const map = {
    pending: 'Pending',
    cooking: 'Diproses',
    ready: 'Siap',
    served: 'Disajikan'
  }
  return map[status] || status
}

const getOrderStatusText = (status) => {
  const map = {
    cooking: 'Diproses',
    ready: 'Siap',
    served: 'Disajikan'
  }
  return map[status] || status
}

const itemStatusClass = (status) => {
  const classes = {
    pending: 'bg-amber-100 text-amber-700',
    cooking: 'bg-blue-100 text-blue-700',
    ready: 'bg-emerald-100 text-emerald-700',
    served: 'bg-slate-100 text-slate-600'
  }
  return classes[status] || 'bg-slate-100 text-slate-600'
}

const orderStatusClass = (status) => {
  const classes = {
    cooking: 'bg-blue-100 text-blue-700',
    ready: 'bg-emerald-100 text-emerald-700',
    served: 'bg-slate-100 text-slate-600'
  }
  return classes[status] || 'bg-slate-100 text-slate-600'
}

const destinationClass = (destination) => {
  return destination === 'kitchen' ? 'bg-orange-100 text-orange-700' : 'bg-purple-100 text-purple-700'
}

const formatDateTime = (dateString) => {
  if (!dateString) return '-'
  const date = new Date(dateString)
  return date.toLocaleDateString('id-ID', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}

onMounted(() => {
  fetchOrders()
  realtimeUnsubscribe = subscribeRealtime(handleRealtimeEvent)
})

onUnmounted(() => {
  if (realtimeUnsubscribe) realtimeUnsubscribe()
})
</script>
