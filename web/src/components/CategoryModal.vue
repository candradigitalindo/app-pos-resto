<template>
  <div v-if="isOpen" class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 px-2 sm:px-4 backdrop-blur-sm" @click.self="closeModal">
    <div class="w-full max-w-6xl max-h-[95vh] overflow-hidden rounded-2xl sm:rounded-3xl bg-white shadow-2xl flex flex-col">
      <!-- Header -->
      <div class="relative flex items-center justify-between bg-gradient-to-r from-emerald-600 to-emerald-500 px-4 sm:px-8 py-4 sm:py-6 text-white flex-shrink-0">
        <div class="flex items-center gap-2 sm:gap-3">
          <div class="flex h-8 w-8 sm:h-10 sm:w-10 items-center justify-center rounded-lg sm:rounded-xl bg-white/20">
            <svg class="h-4 w-4 sm:h-6 sm:w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"/>
            </svg>
          </div>
          <div>
            <h2 class="text-lg sm:text-2xl font-bold">Kelola Kategori</h2>
            <p class="mt-0.5 sm:mt-1 text-xs sm:text-sm text-emerald-50">Atur kategori dan printer tujuan</p>
          </div>
        </div>
        <button 
          @click="closeModal" 
          class="group flex h-8 w-8 sm:h-10 sm:w-10 items-center justify-center rounded-full bg-white/10 transition-all hover:bg-white/20 hover:rotate-90"
        >
          <svg class="h-4 w-4 sm:h-5 sm:w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
      </div>

      <div class="flex-1 overflow-y-auto">
        <div class="grid gap-4 sm:gap-6 p-3 sm:p-6 lg:grid-cols-2">
          <!-- Form Section -->
          <div class="rounded-xl sm:rounded-2xl border border-slate-200 bg-white p-4 sm:p-6 shadow-sm">
          <div class="flex items-center gap-2 sm:gap-3 border-b border-slate-200 pb-3 sm:pb-4">
            <div class="flex h-8 w-8 sm:h-10 sm:w-10 items-center justify-center rounded-lg sm:rounded-xl bg-gradient-to-br from-emerald-500 to-emerald-600 text-white shadow-lg">
              <svg v-if="editingCategory" class="h-4 w-4 sm:h-5 sm:w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
              </svg>
              <svg v-else class="h-4 w-4 sm:h-5 sm:w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
              </svg>
            </div>
            <h3 class="text-base sm:text-lg font-bold text-slate-900">
              {{ editingCategory ? 'Edit Kategori' : 'Tambah Kategori' }}
            </h3>
          </div>

          <div class="space-y-3 sm:space-y-4">
            <!-- Nama Kategori -->
            <div>
              <label class="mb-2 flex items-center gap-2 text-sm font-semibold text-slate-700">
                <svg class="h-4 w-4 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"/>
                </svg>
                Nama Kategori
              </label>
              <input
                v-model="form.name"
                type="text"
                class="input"
                placeholder="Contoh: Makanan Utama, Minuman, dll"
                @keyup.enter="saveCategory"
              />
            </div>

            <!-- Deskripsi -->
            <div>
              <label class="mb-1.5 sm:mb-2 flex items-center gap-1.5 sm:gap-2 text-xs sm:text-sm font-semibold text-slate-700">
                <svg class="h-3.5 w-3.5 sm:h-4 sm:w-4 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
                Deskripsi
              </label>
              <textarea
                v-model="form.description"
                rows="2"
                class="input resize-none text-sm sm:text-base"
                placeholder="Deskripsi kategori (opsional)"
              ></textarea>
            </div>

            <!-- Pilih Printer -->
            <div class="relative">
              <label class="mb-1.5 sm:mb-2 flex items-center gap-1.5 sm:gap-2 text-xs sm:text-sm font-semibold text-slate-700">
                <svg class="h-3.5 w-3.5 sm:h-4 sm:w-4 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z"/>
                </svg>
                Pilih Printer Target
              </label>
              
              <!-- Searchable Dropdown -->
              <div class="relative">
                <div 
                  @click="togglePrinterDropdown" 
                  class="input flex cursor-pointer items-center justify-between"
                  :class="{'opacity-50 cursor-not-allowed': loadingPrinters || activePrinters.length === 0}"
                >
                  <span :class="form.printer_id ? 'text-slate-900' : 'text-slate-400'">
                    {{ selectedPrinterName || (loadingPrinters ? 'Memuat printer...' : activePrinters.length === 0 ? 'Belum ada printer aktif' : 'Pilih printer') }}
                  </span>
                  <svg class="h-5 w-5 text-slate-400 transition-transform" :class="{'rotate-180': printerDropdownOpen}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
                  </svg>
                </div>

                <!-- Dropdown Menu -->
                <div 
                  v-if="printerDropdownOpen" 
                  class="absolute z-10 mt-1 w-full rounded-lg border border-slate-200 bg-white shadow-lg"
                >
                  <!-- Search Input -->
                  <div class="border-b border-slate-200 p-2">
                    <div class="relative">
                      <svg class="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                      </svg>
                      <input
                        v-model="printerSearchQuery"
                        type="text"
                        placeholder="Cari printer..."
                        class="w-full rounded-md border border-slate-200 py-2 pl-9 pr-3 text-sm focus:border-emerald-500 focus:outline-none focus:ring-1 focus:ring-emerald-500"
                        @click.stop
                      />
                    </div>
                  </div>

                  <!-- Options List -->
                  <div class="max-h-60 overflow-y-auto">
                    <div 
                      v-if="filteredPrinters.length === 0" 
                      class="px-4 py-3 text-center text-sm text-slate-500"
                    >
                      Printer tidak ditemukan
                    </div>
                    <div
                      v-for="printer in filteredPrinters"
                      :key="printer.id"
                      @click="selectPrinter(printer)"
                      class="flex cursor-pointer items-center justify-between px-4 py-2.5 text-sm transition-colors hover:bg-emerald-50"
                      :class="form.printer_id === printer.id ? 'bg-emerald-50 text-emerald-700 font-medium' : 'text-slate-700'"
                    >
                      <span>{{ printer.name }}</span>
                      <svg v-if="form.printer_id === printer.id" class="h-5 w-5 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                      </svg>
                    </div>
                  </div>
                </div>
              </div>
              
              <p class="mt-2 flex items-start gap-2 text-xs text-slate-500">
                <svg class="mt-0.5 h-4 w-4 flex-shrink-0 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
                Menu dari kategori ini akan dicetak ke printer yang dipilih
              </p>
            </div>
          </div>

          <!-- Action Buttons -->
          <div class="flex items-center gap-3 border-t border-slate-200 pt-4">
            <button 
              @click="saveCategory" 
              class="btn-primary flex-1"
              :disabled="!form.name.trim()"
            >
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path v-if="editingCategory" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                <path v-else stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
              </svg>
              {{ editingCategory ? 'Update' : 'Tambah' }}
            </button>
            <button 
              v-if="editingCategory" 
              @click="cancelEdit" 
              class="btn-secondary"
            >
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>

        <!-- Category List Section -->
        <div class="flex flex-col" style="max-height: calc(100vh - 250px);">
          <!-- Table Card with Modern Border -->
          <div class="flex flex-1 flex-col overflow-hidden rounded-xl sm:rounded-2xl border border-slate-200 bg-white shadow-lg">
            <!-- Header inside card -->
            <div class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 sm:gap-0 border-b border-slate-200 bg-gradient-to-r from-emerald-50 to-white px-4 sm:px-6 py-3 sm:py-4">
              <div class="flex items-center gap-2 sm:gap-3">
                <div class="flex h-8 w-8 sm:h-10 sm:w-10 items-center justify-center rounded-lg sm:rounded-xl bg-gradient-to-br from-emerald-500 to-emerald-600 text-white shadow-lg">
                  <svg class="h-4 w-4 sm:h-5 sm:w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
                  </svg>
                </div>
                <h3 class="text-base sm:text-xl font-bold text-slate-900">Daftar Kategori</h3>
              </div>
              <div class="flex items-center gap-2 sm:gap-3 w-full sm:w-auto">
                <button
                  v-if="selectedCategories.length > 0"
                  @click="bulkDeleteCategories"
                  class="flex items-center gap-1.5 sm:gap-2 rounded-lg bg-red-50 px-3 sm:px-4 py-1.5 sm:py-2 text-xs sm:text-sm font-semibold text-red-600 transition-all hover:bg-red-100 flex-1 sm:flex-initial justify-center"
                >
                  <svg class="h-3.5 w-3.5 sm:h-4 sm:w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                  </svg>
                  <span class="hidden sm:inline">Hapus</span> {{ selectedCategories.length }}
                </button>
                <span v-if="!loading && categories.length > 0" class="flex h-6 sm:h-8 min-w-[1.5rem] sm:min-w-[2rem] items-center justify-center rounded-full bg-emerald-100 px-2 sm:px-3 text-xs sm:text-sm font-bold text-emerald-700">
                  {{ categories.length }}
                </span>
              </div>
            </div>

            <!-- Loading State -->
            <div v-if="loading" class="flex flex-1 flex-col items-center justify-center gap-4 py-20">
              <div class="h-12 w-12 animate-spin rounded-full border-4 border-slate-200 border-t-emerald-600"></div>
              <p class="text-sm font-medium text-slate-500">Memuat kategori...</p>
            </div>

            <!-- Empty State -->
            <div v-else-if="categories.length === 0" class="flex flex-1 flex-col items-center justify-center gap-3 py-20">
              <div class="rounded-full bg-emerald-100 p-4">
                <svg class="h-12 w-12 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"/>
              </svg>
              </div>
              <p class="text-sm font-medium text-slate-600">Belum ada kategori</p>
              <p class="text-xs text-slate-400">Tambahkan kategori menggunakan form di samping</p>
            </div>

            <!-- Data Table with Scroll -->
            <div v-else class="flex-1 overflow-y-auto">
              <DataTable :columns="tableColumns" :data="categories" item-key="id">
                <!-- Header Checkbox (Select All) -->
              <template #header-checkbox>
                <input
                  type="checkbox"
                  v-model="allSelected"
                  :disabled="selectableCategories.length === 0"
                  class="h-4 w-4 rounded border-slate-300 text-emerald-600 focus:ring-emerald-500 focus:ring-2 transition-all cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
                  title="Pilih semua kategori yang dapat dihapus"
                />
              </template>
              
              <!-- Checkbox -->
              <template #cell-checkbox="{ item }">
                <div class="flex items-center justify-center">
                  <input
                    type="checkbox"
                    :value="item.id"
                    v-model="selectedCategories"
                    :disabled="item.product_count > 0"
                    class="h-4 w-4 rounded border-slate-300 text-emerald-600 focus:ring-emerald-500 disabled:opacity-50 disabled:cursor-not-allowed"
                  :title="item.product_count > 0 ? 'Kategori tidak dapat dihapus karena masih digunakan produk' : 'Pilih untuk hapus'"
                />
              </div>
              </template>

              <!-- Nama Kategori -->
              <template #cell-name="{ item }">
                <div>
                <p class="font-semibold text-slate-900">{{ item.name }}</p>
                <p v-if="item.description" class="mt-0.5 text-xs text-slate-500">{{ item.description }}</p>
              </div>
              </template>

              <!-- Printer -->
              <template #cell-printer="{ item }">
                <div class="flex items-center justify-center">
                  <span v-if="item.printer_name" class="inline-flex items-center rounded-full bg-emerald-100 px-3 py-1.5 text-xs font-bold text-emerald-700">
                    {{ item.printer_name }}
                  </span>
                <span v-else class="text-xs text-slate-400">-</span>
              </div>
              </template>

              <!-- Product Count -->
              <template #cell-product_count="{ item }">
                <div v-if="item.product_count > 0" class="inline-flex items-center gap-1.5 rounded-full bg-blue-100 px-3 py-1.5 text-xs font-bold text-blue-700">
                  <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
                  </svg>
                {{ item.product_count }}
              </div>
                <span v-else class="text-xs text-slate-400">-</span>
              </template>

              <!-- Actions -->
              <template #cell-actions="{ item }">
                <div class="flex items-center justify-center gap-2">
                  <button 
                    @click="editCategory(item)" 
                    class="flex h-8 w-8 items-center justify-center rounded-lg bg-blue-50 text-blue-700 transition-all hover:bg-blue-100"
                    title="Edit Kategori"
                  >
                    <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                    </svg>
                  </button>
                  <button 
                    @click="deleteCategory(item)" 
                    class="flex h-8 w-8 items-center justify-center rounded-lg bg-red-50 text-red-600 transition-all hover:bg-red-100"
                    title="Hapus Kategori"
                  >
                    <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                    </svg>
                  </button>
                </div>
                </template>
              </DataTable>
            </div>
          </div>
        </div> <!-- Close grid container -->
        </div> <!-- Close grid container -->
      </div> <!-- Close scrollable wrapper -->
    </div> <!-- Close modal container -->
  </div> <!-- Close backdrop -->
</template>

<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import api from '../services/api'
import { useNotification } from '../composables/useNotification'
import DataTable from './DataTable.vue'

const { success, error, confirm } = useNotification()

const props = defineProps({
  isOpen: {
    type: Boolean,
    default: false
  }
})

const emit = defineEmits(['close', 'updated'])

const categories = ref([])
const printers = ref([])
const loading = ref(false)
const loadingPrinters = ref(false)
const editingCategory = ref(null)
const printerDropdownOpen = ref(false)
const printerSearchQuery = ref('')
const selectedCategories = ref([])
const form = ref({
  name: '',
  description: '',
  printer_id: null
})

// Computed for select all
const selectableCategories = computed(() => {
  return categories.value.filter(cat => cat.product_count === 0)
})

const allSelected = computed({
  get() {
    return selectableCategories.value.length > 0 && 
           selectedCategories.value.length === selectableCategories.value.length
  },
  set(value) {
    if (value) {
      selectedCategories.value = selectableCategories.value.map(cat => cat.id)
    } else {
      selectedCategories.value = []
    }
  }
})

// Table configuration
const tableColumns = [
  { 
    key: 'checkbox', 
    label: '', 
    align: 'text-center'
  },
  { 
    key: 'name', 
    label: 'Nama Kategori', 
    align: 'text-left'
  },
  { 
    key: 'printer', 
    label: 'Printer Target', 
    align: 'text-center'
  },
  { 
    key: 'product_count', 
    label: 'Jumlah Produk', 
    align: 'text-center'
  },
  { 
    key: 'actions', 
    label: 'Aksi', 
    align: 'text-center'
  }
]

const activePrinters = computed(() => {
  return printers.value.filter((p) => p.is_active === 1)
})

const filteredPrinters = computed(() => {
  if (!printerSearchQuery.value) {
    return activePrinters.value
  }
  const query = printerSearchQuery.value.toLowerCase()
  return activePrinters.value.filter(printer => 
    printer.name.toLowerCase().includes(query)
  )
})

const selectedPrinterName = computed(() => {
  if (!form.value.printer_id) return ''
  const printer = activePrinters.value.find(p => p.id === form.value.printer_id)
  return printer ? printer.name : ''
})

watch(
  () => props.isOpen,
  (newVal) => {
    if (newVal) {
      fetchCategories()
      fetchPrinters()
      resetForm()
    }
  }
)

const fetchCategories = async () => {
  loading.value = true
  try {
    const response = await api.get('/categories')
    if (response.data.success) {
      categories.value = response.data.data
    } else {
      error('Gagal memuat daftar kategori')
    }
  } catch (err) {
    console.error('Failed to fetch categories:', err)
    error('Terjadi kesalahan saat memuat kategori')
  } finally {
    loading.value = false
  }
}

const fetchPrinters = async () => {
  loadingPrinters.value = true
  try {
    const response = await api.get('/printers')
    if (response.data.success || response.data.data) {
      printers.value = response.data.data || []
      if (!form.value.printer_id && activePrinters.value.length > 0) {
        form.value.printer_id = activePrinters.value[0].id
      }
    } else {
      error('Gagal memuat daftar printer')
    }
  } catch (err) {
    console.error('Failed to fetch printers:', err)
    error('Terjadi kesalahan saat memuat printer')
  } finally {
    loadingPrinters.value = false
  }
}

const saveCategory = async () => {
  if (!form.value.name.trim()) {
    error('Nama kategori harus diisi!')
    return
  }

  try {
    if (editingCategory.value) {
      const response = await api.put(`/categories/${editingCategory.value.id}`, form.value)
      if (response.data.success) {
        await fetchCategories()
        resetForm()
        emit('updated')
        success('✓ Kategori berhasil diperbarui!')
      } else {
        error(response.data.message || 'Gagal memperbarui kategori')
      }
    } else {
      const response = await api.post('/categories', form.value)
      if (response.data.success) {
        await fetchCategories()
        resetForm()
        emit('updated')
        success('✓ Kategori berhasil ditambahkan!')
      } else {
        error(response.data.message || 'Gagal menambahkan kategori')
      }
    }
  } catch (err) {
    console.error('Failed to save category:', err)
    const errorMsg = err.response?.data?.message || 'Terjadi kesalahan saat menyimpan kategori'
    error(errorMsg)
  }
}

const editCategory = (category) => {
  editingCategory.value = category
  form.value = {
    name: category.name,
    description: category.description || '',
    printer_id: category.printer_id || null
  }
}

const cancelEdit = () => {
  resetForm()
}

const deleteCategory = async (category) => {
  // Prevent deletion if category has products
  if (category.product_count > 0) {
    error(`Kategori "${category.name}" tidak dapat dihapus!\n${category.product_count} produk masih menggunakan kategori ini.`)
    return
  }
  
  confirm(
    `Apakah Anda yakin ingin menghapus kategori "${category.name}"?`,
    async () => {
      try {
        const response = await api.delete(`/categories/${category.id}`)
        if (response.data.success) {
          await fetchCategories()
          emit('updated')
          success('✓ Kategori berhasil dihapus!')
        } else {
          error(response.data.message || 'Gagal menghapus kategori')
        }
      } catch (err) {
        console.error('Failed to delete category:', err)
        const errorMsg = err.response?.data?.message || 'Terjadi kesalahan saat menghapus kategori'
        error(errorMsg)
      }
    }
  )
}

const bulkDeleteCategories = async () => {
  if (selectedCategories.value.length === 0) return
  
  confirm(
    `Apakah Anda yakin ingin menghapus ${selectedCategories.value.length} kategori?`,
    async () => {
      try {
        let successCount = 0
        let failedCount = 0
        
        for (const categoryId of selectedCategories.value) {
          try {
            const response = await api.delete(`/categories/${categoryId}`)
            if (response.data.success) {
              successCount++
            } else {
              failedCount++
            }
          } catch (err) {
            failedCount++
          }
        }
        
        await fetchCategories()
        selectedCategories.value = []
        emit('updated')
        
        if (failedCount === 0) {
          success(`✓ ${successCount} kategori berhasil dihapus!`)
        } else {
          error(`${successCount} kategori berhasil dihapus, ${failedCount} gagal.`)
        }
      } catch (err) {
        console.error('Failed to bulk delete categories:', err)
        error('Terjadi kesalahan saat menghapus kategori')
      }
    }
  )
}

const resetForm = () => {
  editingCategory.value = null
  form.value = {
    name: '',
    description: '',
    printer_id: activePrinters.value.length > 0 ? activePrinters.value[0].id : ''
  }
}

const closeModal = () => {
  resetForm()
  printerDropdownOpen.value = false
  printerSearchQuery.value = ''
  emit('close')
}

const togglePrinterDropdown = () => {
  if (loadingPrinters.value || activePrinters.value.length === 0) return
  printerDropdownOpen.value = !printerDropdownOpen.value
  if (printerDropdownOpen.value) {
    printerSearchQuery.value = ''
  }
}

const selectPrinter = (printer) => {
  form.value.printer_id = printer.id
  printerDropdownOpen.value = false
  printerSearchQuery.value = ''
}

// Close dropdown when clicking outside
const handleClickOutside = (event) => {
  const dropdown = event.target.closest('.relative')
  if (!dropdown) {
    printerDropdownOpen.value = false
  }
}

onMounted(() => {
  document.addEventListener('click', handleClickOutside)
})

onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside)
})
</script>
