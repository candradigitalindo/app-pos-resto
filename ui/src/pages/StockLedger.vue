<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-bold text-gray-900">Kartu Stok</h1>
      <AppButton @click="openProduceModal" variant="primary">
        <svg class="h-4 w-4 mr-1.5 -ml-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
        </svg>
        Produksi (Masak)
      </AppButton>
    </div>

    <!-- Summary Stats -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div class="bg-white p-4 rounded-xl border border-gray-100 shadow-sm flex items-center gap-4">
        <div class="w-12 h-12 rounded-full bg-blue-50 flex items-center justify-center text-blue-600">
          <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/></svg>
        </div>
        <div>
          <div class="text-xs text-gray-500 uppercase font-bold tracking-wider">Total Item</div>
          <div class="text-xl font-bold text-gray-900">{{ total }}</div>
        </div>
      </div>
      <div class="bg-white p-4 rounded-xl border border-gray-100 shadow-sm flex items-center gap-4">
        <div class="w-12 h-12 rounded-full bg-red-50 flex items-center justify-center text-red-600">
          <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/></svg>
        </div>
        <div>
          <div class="text-xs text-gray-500 uppercase font-bold tracking-wider">Stok Rendah</div>
          <div class="text-xl font-bold text-red-600">{{ lowStockCount }}</div>
        </div>
      </div>
      <div class="bg-white p-4 rounded-xl border border-gray-100 shadow-sm flex items-center gap-4">
        <div class="w-12 h-12 rounded-full bg-emerald-50 flex items-center justify-center text-emerald-600">
          <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
        </div>
        <div>
          <div class="text-xs text-gray-500 uppercase font-bold tracking-wider">Nilai Aset</div>
          <div class="text-xl font-bold text-emerald-700">{{ formatRupiah(totalAssetValue) }}</div>
        </div>
      </div>
    </div>

    <!-- Filters -->
    <AppCard :padding="false">
      <div class="flex flex-wrap items-center gap-3 px-4 py-3 border-b border-gray-100">
        <div class="min-w-[260px] max-w-md">
          <SearchSelect
            v-model="filterWarehouse"
            :options="warehouseOptions"
            placeholder="Semua Gudang"
            searchPlaceholder="Cari gudang..."
            valueKey="value"
            labelKey="label"
            @change="applyFilters"
          />
        </div>
        <input v-model="search" @input="debouncedLoad" placeholder="Cari bahan baku..."
          class="flex-1 min-w-[160px] text-sm border border-gray-200 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-emerald-400" />
        <label class="flex items-center gap-2 text-sm text-gray-600 cursor-pointer select-none">
          <input type="checkbox" v-model="lowStockOnly" @change="load" class="rounded text-red-500" />
          <span class="text-red-600 font-medium">Stok Rendah</span>
        </label>
      </div>

      <AppTable :columns="COLUMNS" :rows="rows" :loading="loading" emptyText="Tidak ada data stok.">
        <template #cell-item_name="{ row }">
          <div>
            <span class="font-medium text-gray-900">{{ row.item_name }}</span>
            <span class="ml-2 font-mono text-xs text-gray-400">{{ row.item_code }}</span>
          </div>
        </template>
        <template #cell-warehouse_name="{ row }">
          <div class="flex flex-col gap-0.5">
            <span class="text-sm font-medium text-gray-700">{{ getWarehouseLabel(row) }}</span>
            <span :class="row.warehouse_type === 'central' ? 'text-blue-700' : 'text-amber-700'"
              class="text-[11px] font-medium">
              {{ row.warehouse_type === 'central' ? 'Gudang Induk' : 'Gudang Outlet' }}
            </span>
          </div>
        </template>
        <template #cell-qty_base="{ row }">
          <div>
            <div :class="['font-semibold', row.is_low ? 'text-red-600' : 'text-gray-900']">
              {{ row.qty_base.toFixed(3) }} {{ row.base_unit }}
              <span v-if="row.is_low" class="ml-1 text-xs text-red-400">(Rendah!)</span>
            </div>
            <div v-if="row.dist_unit !== row.base_unit" class="text-xs text-gray-400">
              ≈ {{ row.qty_dist.toFixed(2) }} {{ row.dist_unit_label || row.dist_unit }}
            </div>
          </div>
        </template>
        <template #cell-avg_cost="{ row }">
          {{ formatRupiah(row.avg_cost) }}/{{ row.base_unit }}
        </template>
        <template #cell-stock_value="{ row }">
          <span class="font-medium">{{ formatRupiah(row.stock_value) }}</span>
        </template>
        <template #cell-actions="{ row }">
          <button @click="openMovements(row)"
            class="text-xs text-emerald-600 hover:text-emerald-800 px-2 py-1 rounded hover:bg-emerald-50">
            Histori
          </button>
          <button @click="openAdjust(row)"
            class="ml-1 text-xs text-gray-600 hover:text-gray-800 px-2 py-1 rounded hover:bg-gray-50">
            Penyesuaian
          </button>
        </template>
      </AppTable>
      <AppPagination v-model:page="page" :total-pages="totalPages" class="px-4 py-3 border-t border-gray-100" />
    </AppCard>

    <!-- Movements Modal -->
    <AppModal v-model="showMovements" title="Histori Pergerakan Stok" size="lg">
      <div class="mb-3 text-sm font-medium text-gray-700">
        {{ movTarget?.item_name }} — {{ movTarget?.warehouse_name }}
      </div>
      <div class="flex gap-2 mb-3">
        <input v-model="movDateFrom" type="date"
          class="text-sm border border-gray-200 rounded-lg px-3 py-1.5 focus:outline-none focus:ring-2 focus:ring-emerald-400" />
        <input v-model="movDateTo" type="date"
          class="text-sm border border-gray-200 rounded-lg px-3 py-1.5 focus:outline-none focus:ring-2 focus:ring-emerald-400" />
        <AppButton size="sm" @click="loadMovements">Tampilkan</AppButton>
      </div>
      <div class="overflow-auto max-h-96">
        <table class="min-w-full text-sm">
          <thead class="bg-gray-50 text-xs text-gray-500">
            <tr>
              <th class="px-3 py-2 text-left">Tanggal</th>
              <th class="px-3 py-2 text-left">Tipe</th>
              <th class="px-3 py-2 text-right">Qty</th>
              <th class="px-3 py-2 text-right">Saldo</th>
              <th class="px-3 py-2 text-left">Ref</th>
              <th class="px-3 py-2 text-left">Kadaluarsa</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <tr v-if="movLoading"><td colspan="6" class="px-3 py-4 text-center text-gray-400">Memuat...</td></tr>
            <tr v-else-if="movements.length === 0"><td colspan="6" class="px-3 py-4 text-center text-gray-400">Tidak ada histori.</td></tr>
            <tr v-for="m in movements" :key="m.id" class="hover:bg-gray-50">
              <td class="px-3 py-2 text-gray-500">{{ m.created_at.slice(0,16).replace('T',' ') }}</td>
              <td class="px-3 py-2">
                <span :class="movTypeCls(m.movement_type)" class="text-xs px-2 py-0.5 rounded-full font-medium">
                  {{ MOV_LABELS[m.movement_type] || m.movement_type }}
                </span>
              </td>
              <td :class="['px-3 py-2 text-right font-mono font-medium', m.qty_base >= 0 ? 'text-emerald-700' : 'text-red-600']">
                {{ m.qty_base >= 0 ? '+' : '' }}{{ m.qty_base.toFixed(3) }} {{ m.unit_used }}
              </td>
              <td class="px-3 py-2 text-right font-mono text-gray-700">{{ m.balance_after.toFixed(3) }}</td>
              <td class="px-3 py-2 text-gray-500 text-xs">{{ m.ref_number || '—' }}</td>
              <td class="px-3 py-2 text-gray-500 text-xs">{{ m.expiry_date || '—' }}</td>
            </tr>
          </tbody>
        </table>
      </div>
      <template #footer>
        <AppButton variant="secondary" @click="showMovements = false">Tutup</AppButton>
      </template>
    </AppModal>

    <!-- Adjustment Modal -->
    <AppModal v-model="showAdjust" title="Penyesuaian Stok" size="sm">
      <div class="space-y-3">
        <p class="text-sm text-gray-600">
          Item: <strong>{{ adjustTarget?.item_name }}</strong><br/>
          Gudang: <strong>{{ adjustTarget?.warehouse_name }}</strong><br/>
          Stok saat ini: <strong>{{ adjustTarget?.qty_base?.toFixed(3) }} {{ adjustTarget?.base_unit }}</strong>
        </p>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Tipe Gerakan</label>
          <div class="grid grid-cols-2 gap-2">
            <label v-for="t in ADJ_TYPES" :key="t.value"
              :class="['border rounded-lg p-2.5 cursor-pointer transition-all text-sm text-center',
                adjForm.movement_type === t.value ? 'border-emerald-400 bg-emerald-50 text-emerald-800 font-medium' : 'border-gray-200 hover:border-gray-300 text-gray-700']"
              @click="adjForm.movement_type = t.value">
              {{ t.label }}
            </label>
          </div>
        </div>
        <AppInput v-model.number="adjForm.qty_base" :label="`Qty (${adjustTarget?.base_unit})`" type="number" step="0.001" placeholder="0" />
        <AppInput v-if="adjForm.movement_type === 'purchase_in'" v-model.number="adjForm.cost_per_base"
          :label="`HPP per ${adjustTarget?.base_unit}`" type="number" step="1" placeholder="0" />
        <AppInput v-if="['purchase_in', 'adjustment', 'return_in'].includes(adjForm.movement_type)" 
          v-model="adjForm.expiry_date" label="Tanggal Kadaluarsa" type="date" />
        <AppInput v-model="adjForm.notes" label="Keterangan" placeholder="Opsional" />
      </div>
      <template #footer>
        <AppButton variant="secondary" @click="showAdjust = false">Batal</AppButton>
        <AppButton :loading="saving" @click="submitAdjust">Simpan</AppButton>
      </template>
    </AppModal>

    <!-- Produce Modal -->
    <AppModal v-model="showProduce" title="Produksi / Memasak" size="sm">
      <div class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Pilih Barang yang Dibuat</label>
          <SearchSelect
            v-model="produceForm.item_id"
            :options="produceItemOptions"
            placeholder="Cari sambel, saos, dll..."
            searchPlaceholder="Cari..."
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Gudang Tempat Produksi</label>
          <SearchSelect
            v-model="produceForm.warehouse_id"
            :options="warehouseOptions.filter(o => o.value !== '')"
            placeholder="Pilih gudang..."
          />
        </div>
        <AppInput v-model.number="produceForm.qty_produce" label="Kuantitas Hasil Produksi" type="number" step="0.001" placeholder="0" />
        <div v-if="produceForm.item_id" class="p-3 bg-amber-50 rounded-lg border border-amber-100 text-xs text-amber-700">
          <strong>Info:</strong> Stok bahan baku penyusun akan otomatis terpotong sesuai resep yang telah diatur, dan HPP akan dihitung secara otomatis.
        </div>
        <AppInput v-model="produceForm.notes" label="Catatan Produksi" placeholder="Opsional" />
      </div>
      <template #footer>
        <AppButton variant="secondary" @click="showProduce = false">Batal</AppButton>
        <AppButton variant="primary" :loading="saving" @click="submitProduce">Proses Produksi</AppButton>
      </template>
    </AppModal>
  </div>
</template>

<script setup>
import { computed, ref, watch, onMounted } from 'vue'
import { warehousesApi, stockLedgerApi, stockItemsApi } from '@/api/warehouse.js'
import { useToastStore } from '@/stores/toast.js'
import AppButton     from '@/components/ui/AppButton.vue'
import AppCard       from '@/components/ui/AppCard.vue'
import AppTable      from '@/components/ui/AppTable.vue'
import AppModal      from '@/components/ui/AppModal.vue'
import AppInput      from '@/components/ui/AppInput.vue'
import AppAlert      from '@/components/ui/AppAlert.vue'
import AppPagination from '@/components/ui/AppPagination.vue'
import SearchSelect  from '@/components/ui/SearchSelect.vue'
import { formatWarehouseOptionLabel } from '@/utils/warehouse.js'

const toast = useToastStore()
const loading = ref(false)
const saving = ref(false)
const rows = ref([])
const total = ref(0)
const lowStockCount = ref(0)
const totalAssetValue = ref(0)
const page = ref(1)
const limit = 30
const totalPages = ref(1)
const search = ref('')
const filterWarehouse = ref('')
const lowStockOnly = ref(false)
const warehouseList = ref([])

// Movements
const showMovements = ref(false)
const movTarget = ref(null)
const movements = ref([])
const movLoading = ref(false)
const movDateFrom = ref('')
const movDateTo = ref('')

// Adjustment
const showAdjust = ref(false)
const adjustTarget = ref(null)
const adjForm = ref({ movement_type: 'purchase_in', qty_base: 0, cost_per_base: 0, notes: '' })

// Produce
const showProduce = ref(false)
const produceForm = ref({ item_id: '', warehouse_id: '', qty_produce: 0, notes: '' })
const allStockItems = ref([])

const produceItemOptions = computed(() =>
  allStockItems.value.map(i => ({ value: i.id, label: `${i.name} (${i.code})` }))
)

function openProduceModal() {
  produceForm.value = { item_id: '', warehouse_id: filterWarehouse.value, qty_produce: 0, notes: '' }
  showProduce.value = true
  if (allStockItems.value.length === 0) loadAllItems()
}

async function loadAllItems() {
  try {
    const res = await stockItemsApi.list({ limit: 500, active_only: true })
    allStockItems.value = res.data || []
  } catch (e) {}
}

async function submitProduce() {
  if (!produceForm.value.item_id || !produceForm.value.warehouse_id || produceForm.value.qty_produce <= 0) {
    toast.error('Data produksi tidak lengkap')
    return
  }
  saving.value = true
  try {
    await stockLedgerApi.produce(produceForm.value)
    toast.success('Proses produksi berhasil')
    showProduce.value = false
    load()
  } catch (e) {
    toast.error(e?.message || 'Gagal memproses produksi')
  } finally {
    saving.value = false
  }
}

const COLUMNS = [
  { key: 'item_name',      label: 'Bahan Baku', sortable: false },
  { key: 'warehouse_name', label: 'Gudang',     sortable: false },
  { key: 'qty_base',       label: 'Stok',       sortable: false },
  { key: 'avg_cost',       label: 'HPP',        sortable: false },
  { key: 'stock_value',    label: 'Nilai Stok', sortable: false },
  { key: 'actions',        label: '',           sortable: false },
]

const MOV_LABELS = {
  purchase_in: 'Pembelian', transfer_out: 'Transfer Keluar', transfer_in: 'Transfer Masuk',
  adjustment: 'Penyesuaian', waste: 'Pemborosan', return_in: 'Retur',
  spoiled: 'Rusak', expired: 'Kadaluarsa',
}

const ADJ_TYPES = [
  { value: 'purchase_in', label: 'Pembelian Masuk' },
  { value: 'adjustment',  label: 'Koreksi Stok' },
  { value: 'return_in',   label: 'Retur Masuk' },
  { value: 'waste',       label: 'Pemborosan' },
  { value: 'spoiled',     label: 'Rusak (Spoiled)' },
  { value: 'expired',     label: 'Kadaluarsa' },
]

const warehouseMap = computed(() => Object.fromEntries(warehouseList.value.map(w => [w.id, w])))
const warehouseOptions = computed(() =>
  [
    { value: '', label: 'Semua Gudang' },
    ...warehouseList.value.map(w => ({ value: w.id, label: formatWarehouseOptionLabel(w) })),
  ]
)

function movTypeCls(t) {
  const map = {
    purchase_in: 'bg-emerald-100 text-emerald-700',
    transfer_in: 'bg-blue-100 text-blue-700',
    transfer_out: 'bg-orange-100 text-orange-700',
    adjustment: 'bg-gray-100 text-gray-600',
    waste: 'bg-red-100 text-red-600',
    spoiled: 'bg-amber-100 text-amber-700',
    expired: 'bg-rose-100 text-rose-700',
    return_in: 'bg-purple-100 text-purple-700',
  }
  return map[t] || 'bg-gray-100 text-gray-600'
}

function formatRupiah(v) {
  return 'Rp ' + Number(v || 0).toLocaleString('id-ID')
}

let debounceTimer = null
function debouncedLoad() {
  clearTimeout(debounceTimer)
  debounceTimer = setTimeout(() => { page.value = 1; load() }, 400)
}

async function load() {
  loading.value = true
  try {
    const data = await stockLedgerApi.list({
      page: page.value, limit,
      warehouse_id: filterWarehouse.value,
      search: search.value,
      low_stock: lowStockOnly.value ? 'true' : '',
    })
    rows.value = data.data || []
    total.value = data.total || 0
    lowStockCount.value = data.low_stock_count || 0
    totalAssetValue.value = data.total_asset_value || 0
    totalPages.value = data.total_pages || 1
  } catch (e) {
    toast.error(e?.message || 'Gagal memuat kartu stok')
  } finally {
    loading.value = false
  }
}

function applyFilters() {
  page.value = 1
  load()
}

function getWarehouseLabel(row) {
  return formatWarehouseOptionLabel(warehouseMap.value[row.warehouse_id] || row)
}

async function loadWarehouses() {
  try {
    const data = await warehousesApi.list({ limit: 200 })
    warehouseList.value = data.data || []
  } catch (e) {
    toast.error(e?.message || 'Gagal memuat daftar gudang')
  }
}

watch(page, load)
onMounted(() => { load(); loadWarehouses() })

function openMovements(row) {
  movTarget.value = row
  movements.value = []
  showMovements.value = true
  loadMovements()
}

async function loadMovements() {
  movLoading.value = true
  try {
    const data = await stockLedgerApi.movements({
      item_id: movTarget.value.item_id,
      warehouse_id: movTarget.value.warehouse_id,
      date_from: movDateFrom.value,
      date_to: movDateTo.value,
      limit: 100,
    })
    movements.value = data.data || []
  } catch (e) {
    movements.value = []
    toast.error(e?.message || 'Gagal memuat histori stok')
  } finally {
    movLoading.value = false
  }
}

function openAdjust(row) {
  adjustTarget.value = row
  adjForm.value = { movement_type: 'purchase_in', qty_base: 0, cost_per_base: 0, expiry_date: '', notes: '' }
  showAdjust.value = true
}

async function submitAdjust() {
  saving.value = true
  try {
    await stockLedgerApi.adjust({
      item_id: adjustTarget.value.item_id,
      warehouse_id: adjustTarget.value.warehouse_id,
      qty_base: adjForm.value.qty_base,
      cost_per_base: adjForm.value.cost_per_base,
      movement_type: adjForm.value.movement_type,
      expiry_date: adjForm.value.expiry_date,
      notes: adjForm.value.notes,
    })
    toast.success('Penyesuaian stok berhasil dicatat')
    showAdjust.value = false
    load()
  } catch (e) {
    toast.error(e?.message || 'Gagal menyimpan')
  } finally {
    saving.value = false
  }
}
</script>
