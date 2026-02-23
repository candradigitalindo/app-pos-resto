<template>
  <div class="min-h-screen pb-20 lg:pb-6">
    <div class="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
      <!-- Header Card -->
      <div class="mb-6 overflow-hidden rounded-2xl bg-gradient-to-r from-emerald-600 to-emerald-500 p-6 shadow-xl">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div class="flex items-center gap-4">
            <button @click="goBack" class="flex h-10 w-10 items-center justify-center rounded-xl bg-white/20 text-white backdrop-blur-sm transition-all hover:bg-white/30 hover:scale-105 active:scale-95">
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
              </svg>
            </button>
            <div>
              <h1 class="text-2xl font-bold text-white">Manajemen Meja</h1>
              <p class="mt-1 text-sm text-emerald-100">Kelola meja restoran</p>
            </div>
          </div>
          <button @click="openAddModal" class="flex items-center justify-center gap-2 rounded-xl bg-white px-4 py-2.5 font-semibold text-emerald-600 shadow-lg transition-all hover:shadow-xl hover:scale-105 active:scale-95">
            <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
            </svg>
            Tambah Meja
          </button>
        </div>
      </div>

      <!-- Stats -->
      <div class="mb-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div class="overflow-hidden rounded-2xl bg-white p-4 shadow-lg">
          <div class="flex items-center gap-4">
            <div class="flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-br from-slate-100 to-slate-200">
              <svg class="h-6 w-6 text-slate-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
              </svg>
            </div>
            <div>
              <div class="text-2xl font-semibold text-slate-900">{{ totalTables }}</div>
              <div class="text-sm text-slate-500">Total Meja</div>
            </div>
          </div>
        </div>
        <div class="overflow-hidden rounded-2xl bg-white p-4 shadow-lg">
          <div class="flex items-center gap-4">
            <div class="flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-br from-emerald-100 to-emerald-200">
              <svg class="h-6 w-6 text-emerald-700" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
            </div>
            <div>
              <div class="text-2xl font-semibold text-slate-900">{{ availableCount }}</div>
              <div class="text-sm text-slate-500">Tersedia</div>
            </div>
          </div>
        </div>
        <div class="overflow-hidden rounded-2xl bg-white p-4 shadow-lg">
          <div class="flex items-center gap-4">
            <div class="flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-br from-red-100 to-red-200">
              <svg class="h-6 w-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
            </div>
            <div>
              <div class="text-2xl font-semibold text-slate-900">{{ occupiedCount }}</div>
              <div class="text-sm text-slate-500">Terisi</div>
            </div>
          </div>
        </div>
        <div class="overflow-hidden rounded-2xl bg-white p-4 shadow-lg">
          <div class="flex items-center gap-4">
            <div class="flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-br from-amber-100 to-amber-200">
              <svg class="h-6 w-6 text-amber-700" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z"/>
              </svg>
            </div>
            <div>
              <div class="text-2xl font-semibold text-slate-900">{{ reservedCount }}</div>
              <div class="text-sm text-slate-500">Reservasi</div>
            </div>
          </div>
        </div>
      </div>

      <!-- Filter Card -->
      <div class="mb-6 overflow-hidden rounded-2xl bg-white p-4 shadow-lg">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div class="relative flex-1">
            <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
              <svg class="h-5 w-5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
              </svg>
            </div>
            <input
              v-model="searchQuery"
              type="text"
              class="w-full rounded-xl border-2 border-slate-200 py-2.5 pl-10 pr-4 transition-all focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-200"
              placeholder="Cari nomor meja..."
            />
          </div>
          <div class="relative sm:w-64">
            <select v-model="filterStatus" class="w-full appearance-none rounded-xl border-2 border-slate-200 bg-white py-2.5 pl-4 pr-10 transition-all focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-200">
              <option value="">Semua Status</option>
              <option value="available">Tersedia</option>
              <option value="occupied">Terisi</option>
              <option value="reserved">Reservasi</option>
            </select>
            <div class="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-3">
              <svg class="h-5 w-5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
              </svg>
            </div>
          </div>
        </div>
      </div>

      <!-- Empty State - No Data at All -->
      <div v-if="!loading && tables.length === 0 && !searchQuery && !filterStatus" class="overflow-hidden rounded-2xl bg-white p-12 shadow-lg">
        <div class="flex flex-col items-center gap-6 text-center">
          <div class="flex h-24 w-24 items-center justify-center rounded-full bg-gradient-to-br from-emerald-100 to-emerald-200">
            <svg class="h-12 w-12 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M3 14h18m-9-4v8m-7 0h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
            </svg>
          </div>
          <div>
            <h3 class="text-2xl font-bold text-slate-900">Belum Ada Meja</h3>
            <p class="mt-2 text-slate-500">Mulai dengan menambahkan meja pertama</p>
          </div>
          <button @click="openAddModal" class="flex items-center gap-2 rounded-xl bg-gradient-to-r from-emerald-600 to-emerald-500 px-5 py-3 font-semibold text-white shadow-lg transition-all hover:shadow-xl hover:scale-105 active:scale-95">
            <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
            </svg>
            Tambah Meja Pertama
          </button>
        </div>
      </div>

      <!-- Not Found State - Search/Filter Result Empty -->
      <div v-else-if="!loading && tables.length === 0" class="overflow-hidden rounded-2xl bg-white p-12 shadow-lg">
        <div class="flex flex-col items-center gap-6 text-center">
          <div class="relative">
            <div class="flex h-24 w-24 items-center justify-center rounded-full bg-gradient-to-br from-amber-100 to-amber-200 animate-pulse">
              <svg class="h-12 w-12 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
              </svg>
            </div>
            <div class="absolute -right-1 -top-1 flex h-8 w-8 items-center justify-center rounded-full bg-red-500 shadow-lg">
              <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </div>
          </div>
          <div class="max-w-md">
            <h3 class="text-2xl font-bold text-slate-900">Meja Tidak Ditemukan</h3>
            <p class="mt-2 text-slate-500">Tidak ada meja yang cocok dengan pencarian</p>
            <div v-if="searchQuery" class="mt-4 inline-flex items-center gap-2 rounded-xl bg-slate-100 px-4 py-2">
              <svg class="h-4 w-4 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
              </svg>
              <span class="text-sm font-semibold text-slate-700">{{ searchQuery }}</span>
            </div>
          </div>
          <div class="flex flex-wrap items-center justify-center gap-3">
            <button @click="clearFilters" class="flex items-center gap-2 rounded-xl bg-gradient-to-r from-slate-600 to-slate-700 px-5 py-3 font-semibold text-white shadow-lg transition-all hover:from-slate-700 hover:to-slate-800 hover:scale-105 active:scale-95">
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
              </svg>
              Reset Pencarian
            </button>
            <button @click="openAddModal" class="flex items-center gap-2 rounded-xl bg-gradient-to-r from-emerald-600 to-emerald-500 px-5 py-3 font-semibold text-white shadow-lg transition-all hover:shadow-xl hover:scale-105 active:scale-95">
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
              </svg>
              Tambah Meja Baru
            </button>
          </div>
        </div>
      </div>

      <!-- Table -->
      <div v-else-if="tables.length > 0" class="overflow-hidden rounded-2xl bg-white shadow-lg">
        <DataTable 
          :columns="tableColumns"
          :data="tables"
          emptyMessage="Tidak ada data meja"
        >
          <template #cell-table_number="{ item }">
            <div class="font-semibold text-slate-900">{{ item.table_number }}</div>
          </template>
          
          <template #cell-capacity="{ item }">
            <div class="flex items-center gap-2 text-slate-700">
              <svg class="h-4 w-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
              </svg>
              <span>{{ item.capacity }} orang</span>
            </div>
          </template>
          
          <template #cell-status="{ item }">
            <div class="flex justify-center">
              <span
                :class="[
                  'inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-semibold',
                  item.status === 'available' ? 'bg-emerald-100 text-emerald-800' :
                  item.status === 'occupied' ? 'bg-red-100 text-red-800' :
                  'bg-amber-100 text-amber-800'
                ]"
              >
              <span
                :class="[
                  'inline-block h-1.5 w-1.5 rounded-full',
                  item.status === 'available' ? 'bg-emerald-500' :
                  item.status === 'occupied' ? 'bg-red-500' :
                  'bg-amber-500'
                ]"
              ></span>
              {{ item.status === 'available' ? 'Tersedia' : item.status === 'occupied' ? 'Terisi' : 'Reservasi' }}
              </span>
            </div>
          </template>
          
          <template #cell-actions="{ item }">
            <div class="flex items-center justify-center gap-2">
              <button
                @click="openEditModal(item)"
                class="rounded-lg bg-blue-50 p-2 text-blue-600 transition-all hover:bg-blue-100 hover:scale-110 active:scale-95"
                title="Edit"
              >
                <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                </svg>
              </button>
              <button
                @click="confirmDelete(item)"
                class="rounded-lg bg-red-50 p-2 text-red-600 transition-all hover:bg-red-100 hover:scale-110 active:scale-95"
                title="Hapus"
              >
                <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                </svg>
              </button>
            </div>
          </template>
        </DataTable>
      </div>

      <!-- Pagination -->
      <div v-if="pagination.total_pages > 1" class="mt-6">
        <Pagination
          :current-page="pagination.current_page"
          :total-pages="pagination.total_pages"
          :total-items="pagination.total_items"
          @page-change="goToPage"
        />
      </div>
    </div>

    <!-- Add/Edit Modal -->
    <div v-if="showModal" class="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 px-4" @click="closeModal">
      <div class="w-full max-w-lg overflow-hidden rounded-2xl bg-white shadow-2xl" @click.stop>
        <!-- Modal Header -->
        <div class="bg-gradient-to-r from-emerald-600 to-emerald-500 px-6 py-4">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-3">
              <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-white/20">
                <svg v-if="!editMode" class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                </svg>
                <svg v-else class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                </svg>
              </div>
              <h2 class="text-lg font-semibold text-white">{{ editMode ? 'Edit Meja' : 'Tambah Meja Baru' }}</h2>
            </div>
            <button @click="closeModal" class="flex h-8 w-8 items-center justify-center rounded-lg bg-white/20 text-white transition-all hover:bg-white/30">
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>

        <!-- Modal Body -->
        <div class="p-6">
          <form @submit.prevent="submitForm" class="space-y-4">
            <div>
              <label class="text-sm font-semibold text-slate-700">Nomor Meja *</label>
              <input 
                v-model="form.table_number" 
                type="text"
                required
                placeholder="Contoh: A1, 01, VIP-1"
                class="input mt-2"
                :disabled="editMode"
              />
              <p class="mt-1 text-xs text-slate-500">Nomor meja harus unik</p>
            </div>
            <div>
              <label class="text-sm font-semibold text-slate-700">Kapasitas (Orang) *</label>
              <input 
                v-model.number="form.capacity" 
                type="number"
                min="1"
                max="50"
                required
                placeholder="Berapa orang?"
                class="input mt-2"
              />
            </div>
            <div class="flex items-center justify-end gap-3 pt-4">
              <button type="button" @click="closeModal" class="rounded-xl border-2 border-slate-200 bg-white px-5 py-2.5 font-semibold text-slate-700 transition-all hover:bg-slate-50">
                Batal
              </button>
              <button type="submit" class="flex items-center gap-2 rounded-xl bg-gradient-to-r from-emerald-600 to-emerald-500 px-5 py-2.5 font-semibold text-white shadow-lg transition-all hover:shadow-xl hover:scale-105 active:scale-95" :disabled="submitting">
                <svg v-if="!submitting" class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                </svg>
                <div v-else class="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent"></div>
                {{ submitting ? 'Menyimpan...' : (editMode ? 'Update' : 'Tambah') }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import api from '../services/api'
import { useNotification } from '../composables/useNotification'
import DataTable from '../components/DataTable.vue'
import Pagination from '../components/Pagination.vue'

const router = useRouter()
const { success: showSuccess, error: showError, confirm } = useNotification()

// Table Columns
const tableColumns = [
  { key: 'table_number', label: 'Nomor Meja', sortable: true },
  { key: 'capacity', label: 'Kapasitas', sortable: true },
  { key: 'status', label: 'Status', sortable: true, align: 'center' },
  { key: 'actions', label: 'Aksi', align: 'center' }
]

// State
const loading = ref(false)
const submitting = ref(false)
const tables = ref([])
const showModal = ref(false)
const editMode = ref(false)
const currentTable = ref(null)
const searchQuery = ref('')
const filterStatus = ref('')

// Form
const form = ref({
  table_number: '',
  capacity: 1
})

// Pagination & Stats
const pagination = ref({
  current_page: 1,
  total_pages: 1,
  total_items: 0,
  page_size: 20
})

const stats = ref({
  total: 0,
  available: 0,
  occupied: 0,
  reserved: 0
})

// Computed
const totalTables = computed(() => stats.value.total)
const availableCount = computed(() => stats.value.available)
const occupiedCount = computed(() => stats.value.occupied)
const reservedCount = computed(() => stats.value.reserved)

// Methods
const goBack = () => {
  router.push('/')
}

const fetchTables = async () => {
  loading.value = true
  try {
    const params = {
      page: pagination.value.current_page,
      page_size: pagination.value.page_size
    }
    
    if (searchQuery.value) {
      params.search = searchQuery.value
    }
    
    if (filterStatus.value) {
      params.status = filterStatus.value
    }

    const response = await api.get('/tables', { params })
    tables.value = response.data.data || []
    
    if (response.data.pagination) {
      pagination.value = response.data.pagination
    }
    
    // Update stats (hitung dari response atau gunakan dari API jika tersedia)
    if (response.data.stats) {
      stats.value = response.data.stats
    } else {
      // Fallback: hitung dari data yang ada (hanya untuk display)
      stats.value.total = pagination.value.total_items
      const all = tables.value
      stats.value.available = all.filter(t => t.status === 'available').length
      stats.value.occupied = all.filter(t => t.status === 'occupied').length
      stats.value.reserved = all.filter(t => t.status === 'reserved').length
    }
  } catch (error) {
    showError('Gagal memuat data meja')
  } finally {
    loading.value = false
  }
}

const openAddModal = () => {
  editMode.value = false
  currentTable.value = null
  form.value = {
    table_number: '',
    capacity: 1
  }
  showModal.value = true
}

const openEditModal = (table) => {
  editMode.value = true
  currentTable.value = table
  form.value = {
    table_number: table.table_number,
    capacity: table.capacity
  }
  showModal.value = true
}

const closeModal = () => {
  showModal.value = false
  editMode.value = false
  currentTable.value = null
  form.value = {
    table_number: '',
    capacity: 1
  }
}

const submitForm = async () => {
  submitting.value = true
  try {
    if (editMode.value) {
      await api.put(`/tables/${currentTable.value.id}`, form.value)
      showSuccess('Meja berhasil diupdate!')
    } else {
      await api.post('/tables', form.value)
      showSuccess('Meja berhasil ditambahkan!')
    }
    closeModal()
    await fetchTables()
  } catch (error) {
    const errorMessage = error.response?.data?.error || error.response?.data?.message || error.message || 'Gagal menyimpan data'
    showError(errorMessage)
  } finally {
    submitting.value = false
  }
}

const confirmDelete = (table) => {
  confirm(
    `Apakah Anda yakin ingin menghapus meja ${table.table_number}? Data tidak dapat dikembalikan!`,
    async () => {
      try {
        await api.delete(`/tables/${table.id}`)
        showSuccess('Meja berhasil dihapus!')
        await fetchTables()
      } catch (error) {
        const errorMessage = error.response?.data?.error || error.response?.data?.message || error.message || 'Gagal menghapus meja'
        showError(errorMessage)
      }
    }
  )
}

const goToPage = async (page) => {
  pagination.value.current_page = page
  await fetchTables()
}

const clearFilters = async () => {
  searchQuery.value = ''
  filterStatus.value = ''
  pagination.value.current_page = 1
  await fetchTables()
}

// Watch for search and filter changes
watch([searchQuery, filterStatus], () => {
  pagination.value.current_page = 1
  fetchTables()
})

// Lifecycle
onMounted(() => {
  fetchTables()
})
</script>
