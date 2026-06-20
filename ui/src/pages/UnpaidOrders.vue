<template>
  <div class="space-y-6">

    <!-- Filter Bar -->
    <AppCard>
      <div class="flex flex-wrap items-end gap-4">
        <div class="flex flex-col gap-1 min-w-45">
          <AppSelect
            v-model="selectedOutlet"
            label="Outlet"
            :options="outletOptions"
            placeholder="Semua Outlet"
          />
        </div>
        <div class="flex flex-col gap-1 min-w-36">
          <AppSelect
            v-model="selectedStatus"
            label="Status"
            :options="statusOptions"
            placeholder="Semua Status"
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
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div class="summary-card">
          <div class="flex items-center gap-2 mb-2">
            <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" class="w-5 h-5 text-orange-500">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
            </svg>
            <span class="text-xs font-medium text-gray-500 uppercase tracking-wide">Total Pesanan Belum Bayar</span>
          </div>
          <div class="text-2xl font-bold text-gray-800">{{ report.total_unpaid }}</div>
        </div>
        <div class="summary-card">
          <div class="flex items-center gap-2 mb-2">
            <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" class="w-5 h-5 text-orange-500">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
            <span class="text-xs font-medium text-gray-500 uppercase tracking-wide">Total Nilai Belum Bayar</span>
          </div>
          <div class="text-2xl font-bold text-gray-800">{{ formatRupiah(report.total_amount) }}</div>
        </div>
      </div>

      <!-- Orders Table -->
      <AppCard :padding="false">
        <div class="px-4 pt-4 pb-2">
          <h3 class="text-sm font-semibold text-gray-700">Daftar Pesanan</h3>
        </div>
        <AppTable
          :columns="COLUMNS"
          :rows="report.orders"
          :loading="false"
          emptyText="Tidak ada pesanan yang belum dibayar."
        >
          <template #cell-total_amount="{ row }">
            {{ formatRupiah(row.total_amount) }}
          </template>
          <template #cell-status="{ row }">
            <AppBadge :status="row.status" />
          </template>
          <template #cell-created_at="{ row }">
            {{ formatDateTime(row.created_at) }}
          </template>
          <template #cell-items="{ row }">
            <button v-if="row.items && row.items !== '[]'" @click="showItems(row)"
              class="text-emerald-600 hover:text-emerald-800 text-xs font-medium underline">
              Lihat Item
            </button>
            <span v-else class="text-gray-400 text-xs">—</span>
          </template>
        </AppTable>
        <div class="px-4 py-3 border-t border-gray-100">
          <AppPagination v-model="page" :total="report.total" :perPage="PAGE_SIZE" />
        </div>
      </AppCard>
    </template>

    <!-- Items Modal -->
    <AppModal :show="modalOpen" title="Detail Item Pesanan" @close="modalOpen = false">
      <div v-if="selectedOrder" class="space-y-2">
        <p class="text-sm text-gray-500 mb-3">
          {{ selectedOrder.outlet_name }} — Meja: {{ selectedOrder.table_number || '—' }}
          — {{ selectedOrder.customer_name || 'Tanpa Nama' }}
        </p>
        <table class="min-w-full text-sm">
          <thead>
            <tr class="border-b border-gray-200 text-left text-gray-500">
              <th class="py-1 pr-3 font-medium">Produk</th>
              <th class="py-1 pr-3 font-medium text-right">Qty</th>
              <th class="py-1 pr-3 font-medium text-right">Harga</th>
              <th class="py-1 font-medium text-right">Subtotal</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(item, i) in parsedItems" :key="i" class="border-b border-gray-50">
              <td class="py-1 pr-3">{{ item.product_name }}</td>
              <td class="py-1 pr-3 text-right">{{ item.qty }}</td>
              <td class="py-1 pr-3 text-right">{{ formatRupiah(item.price) }}</td>
              <td class="py-1 text-right font-medium">{{ formatRupiah(item.subtotal) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </AppModal>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { unpaidOrdersApi } from '@/api/unpaidOrders.js'
import { outletsApi } from '@/api/outlets.js'
import { formatRupiah, formatDateTime } from '@/utils/format.js'
import { PAGE_SIZE } from '@/utils/constants.js'
import AppCard       from '@/components/ui/AppCard.vue'
import AppTable      from '@/components/ui/AppTable.vue'
import AppBadge      from '@/components/ui/AppBadge.vue'
import AppAlert      from '@/components/ui/AppAlert.vue'
import AppPagination from '@/components/ui/AppPagination.vue'
import AppSpinner    from '@/components/ui/AppSpinner.vue'
import AppSelect     from '@/components/ui/AppSelect.vue'
import AppModal      from '@/components/ui/AppModal.vue'

const selectedOutlet = ref('')
const selectedStatus = ref('')
const outletOptions  = ref([])
const loading        = ref(false)
const errorMsg       = ref('')
const report         = ref(null)
const page           = ref(1)
const modalOpen      = ref(false)
const selectedOrder  = ref(null)

const statusOptions = [
  { value: 'pending', label: 'Pending' },
  { value: 'cooking', label: 'Cooking' },
  { value: 'ready',   label: 'Ready' },
  { value: 'served',  label: 'Served' },
]

const COLUMNS = [
  { key: 'outlet_name',   label: 'Outlet' },
  { key: 'table_number',  label: 'Meja' },
  { key: 'customer_name', label: 'Pelanggan' },
  { key: 'total_amount',  label: 'Total' },
  { key: 'status',        label: 'Status' },
  { key: 'items',         label: 'Item' },
  { key: 'created_at',    label: 'Waktu Order' },
]

const parsedItems = computed(() => {
  if (!selectedOrder.value) return []
  try { return JSON.parse(selectedOrder.value.items) } catch { return [] }
})

onMounted(async () => {
  try {
    const data = await outletsApi.myOutlets()
    const list = data.outlets ?? data ?? []
    outletOptions.value = list.map(o => ({ value: o.id, label: o.name }))
  } catch { /* ignore */ }
  fetchReport()
})

watch(page, fetchReport)

function showItems(row) {
  selectedOrder.value = row
  modalOpen.value = true
}

async function fetchReport() {
  loading.value = true
  errorMsg.value = ''
  try {
    const params = { page: page.value, limit: PAGE_SIZE }
    if (selectedOutlet.value) params.outlet_id = selectedOutlet.value
    if (selectedStatus.value) params.status = selectedStatus.value
    report.value = await unpaidOrdersApi.getReport(params)
  } catch (err) {
    errorMsg.value = err?.message ?? 'Gagal memuat data pesanan belum bayar.'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.summary-card {
  border-radius: 1rem;
  background: rgba(255,255,255,.78);
  backdrop-filter: blur(22px) saturate(170%);
  -webkit-backdrop-filter: blur(22px) saturate(170%);
  border: 1px solid rgba(255,255,255,.68);
  box-shadow: 0 2px 16px rgba(0,0,0,.07), 0 1px 0 rgba(255,255,255,.92) inset;
  padding: 1.25rem;
}
</style>
