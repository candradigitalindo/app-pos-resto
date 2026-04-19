<template>
  <div class="min-h-screen bg-slate-900 pb-24 lg:pb-4">
    <!-- Compact header -->
    <div class="sticky top-0 z-30 flex items-center justify-between bg-slate-900/95 backdrop-blur px-4 py-3 border-b border-slate-700/50">
      <div class="flex items-center gap-3">
        <div class="h-3 w-3 rounded-full animate-pulse" :class="orders.length > 0 ? 'bg-amber-400' : 'bg-emerald-400'"></div>
        <h1 class="text-lg font-bold text-white tracking-tight">{{ headerTitle }}</h1>
        <span class="rounded-full bg-slate-700 px-2.5 py-0.5 text-xs font-semibold text-slate-300">
          {{ filteredOrders.length }} pesanan
        </span>
      </div>
      <button @click="fetchOrders" :disabled="loading" class="rounded-lg bg-slate-700 p-2 text-slate-300 transition hover:bg-slate-600 active:scale-95">
        <svg class="h-5 w-5" :class="loading ? 'animate-spin' : ''" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
        </svg>
      </button>
    </div>

    <div class="px-3 py-4 sm:px-4">
      <!-- Loading -->
      <div v-if="loading && filteredOrders.length === 0" class="flex items-center justify-center py-20">
        <div class="h-8 w-8 animate-spin rounded-full border-3 border-slate-600 border-t-emerald-400"></div>
      </div>

      <!-- Empty state -->
      <div v-else-if="filteredOrders.length === 0" class="flex flex-col items-center justify-center py-20 text-slate-500">
        <svg class="h-16 w-16 mb-3 opacity-30" viewBox="0 0 24 24" fill="none" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M5 13l4 4L19 7" />
        </svg>
        <div class="text-sm font-medium">Semua pesanan selesai</div>
      </div>

      <!-- Order cards grid -->
      <div v-else class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        <div
          v-for="order in filteredOrders"
          :key="order.order.id"
          class="rounded-2xl border overflow-hidden"
          :class="hasUrgentItems(order) ? 'border-amber-500/50 bg-amber-950/30' : 'border-slate-700/50 bg-slate-800'"
        >
          <!-- Card header: table + time -->
          <div class="flex items-center justify-between px-4 py-3 border-b" :class="hasUrgentItems(order) ? 'border-amber-500/20' : 'border-slate-700/30'">
            <div class="flex items-center gap-2.5">
              <span class="text-2xl font-black text-white tracking-tight">{{ order.order.table_number }}</span>
              <span class="text-[10px] font-medium text-slate-500 uppercase">Meja</span>
            </div>
            <div class="text-right">
              <div class="text-xs font-medium text-slate-400">{{ timeAgo(order.order.created_at) }}</div>
              <div class="text-[10px] text-slate-500">{{ order.items.length }} item</div>
            </div>
          </div>

          <!-- Items -->
          <div class="divide-y" :class="hasUrgentItems(order) ? 'divide-amber-500/10' : 'divide-slate-700/30'">
            <div v-for="item in order.items" :key="item.id" class="flex items-center gap-3 px-4 py-2.5">
              <!-- Status indicator -->
              <div class="flex-shrink-0 h-2.5 w-2.5 rounded-full" :class="dotClass(item.item_status)"></div>

              <!-- Item info -->
              <div class="flex-1 min-w-0">
                <div class="text-sm font-semibold text-slate-100 truncate">
                  <span class="text-slate-400 font-bold mr-1">{{ item.qty }}x</span>{{ item.product_name }}
                </div>
                <div v-if="item.notes" class="text-[11px] text-amber-400/80 truncate">{{ item.notes }}</div>
              </div>

              <!-- Action button -->
              <button
                v-if="item.item_status === 'pending'"
                @click="updateItemStatus(item, 'cooking')"
                :disabled="isUpdating(item.id)"
                class="flex-shrink-0 rounded-lg bg-amber-500 px-3 py-1.5 text-xs font-bold text-white transition hover:bg-amber-400 active:scale-95 disabled:opacity-50"
              >
                {{ isUpdating(item.id) ? '...' : 'Masak' }}
              </button>
              <button
                v-else-if="item.item_status === 'cooking'"
                @click="updateItemStatus(item, 'ready')"
                :disabled="isUpdating(item.id)"
                class="flex-shrink-0 rounded-lg bg-emerald-500 px-3 py-1.5 text-xs font-bold text-white transition hover:bg-emerald-400 active:scale-95 disabled:opacity-50"
              >
                {{ isUpdating(item.id) ? '...' : 'Siap' }}
              </button>
              <span v-else class="flex-shrink-0 text-[10px] font-semibold text-emerald-400 uppercase">✓ Siap</span>
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

const hasUrgentItems = (order) => {
  return order.items.some(item => item.item_status === 'pending')
}

const dotClass = (status) => {
  if (status === 'pending') return 'bg-amber-400 animate-pulse'
  if (status === 'cooking') return 'bg-blue-400'
  return 'bg-emerald-400'
}

const timeAgo = (dateStr) => {
  if (!dateStr) return ''
  const diff = Math.floor((Date.now() - new Date(dateStr).getTime()) / 60000)
  if (diff < 1) return 'Baru'
  if (diff < 60) return diff + ' mnt'
  return Math.floor(diff / 60) + ' jam'
}

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
    event.type === 'table_moved' ||
    event.type === 'payment_completed' ||
    event.type === 'item_status_updated'
  ) {
    await fetchOrders()
  }
}

onMounted(() => {
  fetchOrders()
  realtimeUnsubscribe = subscribeRealtime(handleRealtimeEvent)
})

onUnmounted(() => {
  if (realtimeUnsubscribe) realtimeUnsubscribe()
})
</script>
