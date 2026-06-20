<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-bold text-gray-900">Gudang</h1>
      <AppButton @click="openCreate">+ Tambah Gudang</AppButton>
    </div>

    <AppAlert type="error" :message="errorMsg" />

    <AppCard :padding="false">
      <div class="flex items-center gap-3 px-4 py-3 border-b border-gray-100">
        <div class="min-w-[220px]">
          <SearchSelect
            v-model="filterType"
            :options="warehouseTypeOptions"
            placeholder="Semua Tipe"
            searchPlaceholder="Cari tipe gudang..."
            valueKey="value"
            labelKey="label"
            @change="applyFilters"
          />
        </div>
      </div>
      <AppTable :columns="COLUMNS" :rows="warehouses" :loading="loading" emptyText="Belum ada gudang.">
        <template #cell-code="{ row }">
          <span class="font-mono text-xs bg-gray-100 px-2 py-0.5 rounded">{{ row.code }}</span>
        </template>
        <template #cell-type="{ row }">
          <span :class="row.type === 'central' ? 'bg-blue-100 text-blue-700' : 'bg-amber-100 text-amber-700'"
            class="text-xs font-medium px-2 py-0.5 rounded-full">
            {{ row.type === 'central' ? 'Gudang Induk' : 'Gudang Outlet' }}
          </span>
        </template>
        <template #cell-outlet_name="{ row }">
          <span v-if="row.outlet_name" class="text-gray-900">{{ row.outlet_name }}</span>
          <span v-else class="text-gray-400 italic">—</span>
        </template>
        <template #cell-is_active="{ row }">
          <span :class="row.is_active ? 'bg-emerald-100 text-emerald-700' : 'bg-gray-100 text-gray-500'"
            class="text-xs font-medium px-2 py-0.5 rounded-full">
            {{ row.is_active ? 'Aktif' : 'Nonaktif' }}
          </span>
        </template>
        <template #cell-actions="{ row }">
          <div class="flex items-center gap-1">
            <button @click="openEdit(row)" class="p-1.5 text-emerald-600 hover:bg-emerald-50 rounded-md transition-colors" title="Edit">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4">
                <path stroke-linecap="round" stroke-linejoin="round" d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931Zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0 1 15.75 21H5.25A2.25 2.25 0 0 1 3 18.75V8.25A2.25 2.25 0 0 1 5.25 6H10" />
              </svg>
            </button>
            <button @click="confirmDelete(row)" class="p-1.5 text-red-500 hover:bg-red-50 rounded-md transition-colors" title="Hapus">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4">
                <path stroke-linecap="round" stroke-linejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0" />
              </svg>
            </button>
          </div>
        </template>
      </AppTable>
      <AppPagination v-model:page="page" :total-pages="totalPages" class="px-4 py-3 border-t border-gray-100" />
    </AppCard>

    <!-- Create / Edit Modal -->
    <AppModal v-model="showForm" :title="editTarget ? 'Edit Gudang' : 'Tambah Gudang'" size="sm">
      <div class="space-y-3">
        <div class="grid grid-cols-2 gap-3">
          <AppInput v-model="form.code" label="Kode" placeholder="Contoh: GDG-INDUK" />
          <AppInput v-model="form.name" label="Nama Gudang" placeholder="Contoh: Gudang Pusat" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Tipe Gudang</label>
          <div class="grid grid-cols-2 gap-2">
            <label v-for="t in TYPES" :key="t.value"
              :class="['border rounded-lg p-3 cursor-pointer transition-all text-sm',
                form.type === t.value ? 'border-emerald-400 bg-emerald-50 text-emerald-800 font-medium' : 'border-gray-200 hover:border-gray-300']"
              @click="form.type = t.value; if(t.value==='central') form.outlet_id=''">
              <div class="font-medium">{{ t.label }}</div>
              <div class="text-xs text-gray-500 mt-0.5">{{ t.desc }}</div>
            </label>
          </div>
        </div>
        <div v-if="form.type === 'outlet'" class="space-y-1">
          <label class="block text-sm font-medium text-gray-700">Outlet Terkait</label>
          <SearchSelect
            v-model="form.outlet_id"
            :options="outletOptions"
            placeholder="Pilih outlet..."
            searchPlaceholder="Cari outlet..."
            valueKey="value"
            labelKey="label"
          />
        </div>
        <p v-if="form.type === 'outlet'" class="text-xs text-gray-500 -mt-1">
          Setiap outlet hanya boleh memiliki satu gudang outlet. Gudang induk A dan B tetap bisa sama-sama transfer ke gudang outlet yang sama, dan transfer antar gudang outlet juga bisa.
        </p>
        <AppInput v-model="form.notes" label="Keterangan" placeholder="Opsional" />
      </div>
      <template #footer>
        <AppButton variant="secondary" @click="showForm = false">Batal</AppButton>
        <AppButton :loading="saving" @click="submitForm">Simpan</AppButton>
      </template>
    </AppModal>

    <!-- Delete confirm -->
    <AppModal v-model="showDelete" title="Hapus Gudang" size="sm">
      <p class="text-sm text-gray-600">Hapus gudang <strong>{{ deleteTarget?.name }}</strong>?</p>
      <template #footer>
        <AppButton variant="secondary" @click="showDelete = false">Batal</AppButton>
        <AppButton variant="danger" :loading="saving" @click="submitDelete">Hapus</AppButton>
      </template>
    </AppModal>
  </div>
</template>

<script setup>
import { ref, watch, onMounted } from 'vue'
import { warehousesApi } from '@/api/warehouse.js'
import { outletsApi } from '@/api/outlets.js'
import { useToastStore } from '@/stores/toast.js'
import AppButton     from '@/components/ui/AppButton.vue'
import AppCard       from '@/components/ui/AppCard.vue'
import AppTable      from '@/components/ui/AppTable.vue'
import AppModal      from '@/components/ui/AppModal.vue'
import AppInput      from '@/components/ui/AppInput.vue'
import AppAlert      from '@/components/ui/AppAlert.vue'
import AppPagination from '@/components/ui/AppPagination.vue'
import SearchSelect  from '@/components/ui/SearchSelect.vue'

const toast = useToastStore()
const loading = ref(false)
const saving = ref(false)
const errorMsg = ref('')
const warehouses = ref([])
const page = ref(1)
const limit = 20
const totalPages = ref(1)
const filterType = ref('')

const showForm = ref(false)
const showDelete = ref(false)
const editTarget = ref(null)
const deleteTarget = ref(null)
const outletOptions = ref([])

const TYPES = [
  { value: 'central', label: 'Gudang Induk', desc: 'Bisa lebih dari satu dan dapat memasok outlet mana pun' },
  { value: 'outlet',  label: 'Gudang Outlet', desc: 'Satu outlet satu gudang outlet, bisa terima pasokan dari banyak gudang dan transfer antar outlet' },
]
const warehouseTypeOptions = [
  { value: '', label: 'Semua Tipe' },
  ...TYPES.map(t => ({ value: t.value, label: t.label })),
]

const EMPTY_FORM = () => ({ code: '', name: '', type: 'central', outlet_id: '', notes: '' })
const form = ref(EMPTY_FORM())

const COLUMNS = [
  { key: 'code',        label: 'Kode',       sortable: false },
  { key: 'name',        label: 'Nama',       sortable: false },
  { key: 'type',        label: 'Tipe',       sortable: false },
  { key: 'outlet_name', label: 'Outlet',     sortable: false },
  { key: 'notes',       label: 'Keterangan', sortable: false },
  { key: 'is_active',   label: 'Status',     sortable: false },
  { key: 'actions',     label: '',           sortable: false },
]

async function load() {
  loading.value = true
  errorMsg.value = ''
  try {
    const data = await warehousesApi.list({ page: page.value, limit, type: filterType.value })
    warehouses.value = data.data || []
    totalPages.value = data.total_pages || 1
  } catch (e) {
    errorMsg.value = e?.message || 'Gagal memuat data'
  } finally {
    loading.value = false
  }
}

function applyFilters() {
  page.value = 1
  load()
}

async function loadOutlets() {
  try {
    const data = await outletsApi.list({ limit: 200 })
    const outlets = data.outlets || data.data || data || []
    outletOptions.value = outlets.map(o => ({ value: o.id, label: o.name }))
  } catch (e) {
    toast.error(e?.message || 'Gagal memuat daftar outlet')
  }
}

watch(page, load)
onMounted(() => { load(); loadOutlets() })

function openCreate() {
  editTarget.value = null
  form.value = EMPTY_FORM()
  showForm.value = true
}
function openEdit(row) {
  editTarget.value = row
  form.value = { code: row.code, name: row.name, type: row.type, outlet_id: row.outlet_id || '', notes: row.notes }
  showForm.value = true
}
function confirmDelete(row) {
  deleteTarget.value = row
  showDelete.value = true
}

async function submitForm() {
  if (form.value.type === 'outlet' && !form.value.outlet_id) {
    toast.error('Gudang outlet wajib memilih outlet')
    return
  }
  saving.value = true
  try {
    if (editTarget.value) {
      await warehousesApi.update(editTarget.value.id, form.value)
      toast.success('Gudang diperbarui')
    } else {
      await warehousesApi.create(form.value)
      toast.success('Gudang ditambahkan')
    }
    showForm.value = false
    load()
  } catch (e) {
    toast.error(e?.message || 'Gagal menyimpan')
  } finally {
    saving.value = false
  }
}

async function submitDelete() {
  saving.value = true
  try {
    await warehousesApi.delete(deleteTarget.value.id)
    toast.success('Gudang dihapus')
    showDelete.value = false
    load()
  } catch (e) {
    toast.error(e?.message || 'Gagal menghapus')
  } finally {
    saving.value = false
  }
}
</script>
