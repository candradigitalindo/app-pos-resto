<template>
  <div class="min-h-screen pb-20 lg:pb-6">
    <div class="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
      <div class="mb-6 overflow-hidden rounded-2xl bg-gradient-to-r from-emerald-600 to-emerald-500 p-6 shadow-xl">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div class="flex items-center gap-4">
            <button @click="goBack" class="flex h-10 w-10 items-center justify-center rounded-xl bg-white/20 text-white backdrop-blur-sm transition-all hover:bg-white/30 hover:scale-105 active:scale-95">
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
              </svg>
            </button>
            <div>
              <h1 class="text-2xl font-bold text-white">Manajemen User</h1>
              <p class="mt-1 text-sm text-emerald-100">Kelola akun pengguna dan hak akses</p>
            </div>
          </div>
          <div class="flex items-center gap-3">
            <div class="flex h-11 w-11 items-center justify-center rounded-xl bg-white/20 text-lg font-bold text-white shadow-lg">
              {{ totalUsers }}
            </div>
            <div>
              <div class="text-sm font-semibold text-white">User aktif</div>
              <div class="text-xs text-emerald-100">Total terdaftar</div>
            </div>
          </div>
        </div>
      </div>

      <div class="mb-6 grid gap-4 lg:grid-cols-3">
        <div class="rounded-2xl bg-white p-4 shadow-lg">
          <div class="flex items-center gap-3">
            <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-100 text-emerald-600">
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5.121 17.804A13.937 13.937 0 0112 16c2.5 0 4.847.655 6.879 1.804M15 10a3 3 0 11-6 0 3 3 0 016 0z"/>
              </svg>
            </div>
            <div>
              <div class="text-xs text-slate-500">Total User</div>
              <div class="text-lg font-bold text-slate-900">{{ totalUsers }}</div>
            </div>
          </div>
        </div>
        <div class="rounded-2xl bg-white p-4 shadow-lg">
          <div class="flex items-center gap-3">
            <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-slate-100 text-slate-600">
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 11c2.209 0 4-1.791 4-4S14.209 3 12 3s-4 1.791-4 4 1.791 4 4 4zM4 21v-1a7 7 0 0114 0v1"/>
              </svg>
            </div>
            <div>
              <div class="text-xs text-slate-500">Admin</div>
              <div class="text-lg font-bold text-slate-900">{{ roleStats.admin }}</div>
            </div>
          </div>
        </div>
        <div class="rounded-2xl bg-white p-4 shadow-lg">
          <div class="flex items-center gap-3">
            <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-amber-100 text-amber-600">
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a4 4 0 00-3-3.87M9 20h5v-2a4 4 0 00-3-3.87M3 20h5v-2a4 4 0 00-3-3.87M9 7a3 3 0 106 0 3 3 0 00-6 0z"/>
              </svg>
            </div>
            <div>
              <div class="text-xs text-slate-500">Non-admin</div>
              <div class="text-lg font-bold text-slate-900">{{ totalUsers - roleStats.admin }}</div>
            </div>
          </div>
        </div>
      </div>

      <div class="mb-6 flex flex-col gap-3 rounded-2xl bg-white p-4 shadow-lg sm:flex-row sm:items-center sm:justify-between">
        <div class="flex items-center gap-3">
          <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-100 text-emerald-600">
            <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 017 7H5a7 7 0 017-7z"/>
            </svg>
          </div>
          <div>
            <div class="text-sm font-semibold text-slate-900">Daftar User</div>
            <div class="text-xs text-slate-500">Data user aktif dari backend</div>
          </div>
        </div>
        <div class="flex items-center gap-2">
          <div class="relative w-64">
            <input v-model="searchQuery" type="text" class="input w-full pr-10" placeholder="Cari username atau nama..." />
            <div class="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-slate-400">
              <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
              </svg>
            </div>
          </div>
          <select v-model="roleFilter" class="input w-44">
            <option value="">Semua Role</option>
            <option v-for="role in roleOptions" :key="role.value" :value="role.value">
              {{ role.label }}
            </option>
          </select>
          <button @click="clearFilters" class="btn-secondary">Reset</button>
          <button @click="openUserForm()" class="btn-primary">Tambah User</button>
        </div>
      </div>

      <div v-if="loading" class="rounded-2xl bg-white p-12 text-center shadow-lg">
        <div class="mx-auto mb-4 h-10 w-10 animate-spin rounded-full border-4 border-emerald-200 border-t-emerald-500"></div>
        <div class="text-sm font-semibold text-slate-600">Memuat data user...</div>
      </div>

      <div v-else class="space-y-4">
        <DataTable :columns="userColumns" :data="filteredUsers" item-key="id">
          <template #cell-role="{ item }">
            <select
              :value="item.role"
              class="input text-sm"
              :disabled="busyMap[item.id]"
              @change="(event) => changeRole(item, event.target.value)"
            >
              <option v-for="role in roleOptions" :key="role.value" :value="role.value">
                {{ role.label }}
              </option>
            </select>
          </template>
          <template #cell-status="{ item }">
            <span class="inline-flex items-center gap-1 rounded-full bg-emerald-100 px-2.5 py-1 text-xs font-semibold text-emerald-700">
              Aktif
            </span>
          </template>
          <template #cell-actions="{ item }">
            <div class="flex items-center justify-center gap-2">
              <button
                class="rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-1.5 text-xs font-semibold text-emerald-700 transition hover:bg-emerald-100 disabled:cursor-not-allowed disabled:opacity-60"
                :disabled="busyMap[item.id]"
                @click="openUserForm(item)"
              >
                Edit
              </button>
              <button
                class="rounded-lg border border-rose-200 bg-rose-50 px-3 py-1.5 text-xs font-semibold text-rose-600 transition hover:bg-rose-100 disabled:cursor-not-allowed disabled:opacity-60"
                :disabled="busyMap[item.id]"
                @click="confirmDelete(item)"
              >
                Nonaktifkan
              </button>
            </div>
          </template>
        </DataTable>

        <Pagination
          :current-page="pagination.current_page"
          :total-pages="pagination.total_pages"
          :total-items="pagination.total_items"
          item-name="user"
          @page-change="handlePageChange"
        />
      </div>
    </div>
  </div>

  <div v-if="showUserForm" class="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 backdrop-blur-sm px-4" @click.self="closeUserForm">
    <div class="w-full max-w-2xl overflow-hidden rounded-2xl bg-white shadow-2xl">
      <div class="bg-gradient-to-r from-emerald-600 to-emerald-500 p-6">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="flex h-12 w-12 items-center justify-center rounded-xl bg-white/20 backdrop-blur-sm">
              <svg class="h-6 w-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 017 7H5a7 7 0 017-7z"/>
              </svg>
            </div>
            <div>
              <h2 class="text-xl font-bold text-white">{{ editingUser ? 'Edit User' : 'Tambah User' }}</h2>
              <p class="text-sm text-emerald-100">{{ editingUser ? 'Update informasi user' : 'Tambahkan user baru' }}</p>
            </div>
          </div>
          <button @click="closeUserForm" class="flex h-10 w-10 items-center justify-center rounded-xl bg-white/20 text-white backdrop-blur-sm transition-all hover:bg-white/30 hover:rotate-90">
            <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
      </div>
      <div class="max-h-[60vh] overflow-y-auto p-6">
        <div class="space-y-5">
          <div>
            <label class="mb-2 block text-sm font-bold text-slate-700">Username</label>
            <input v-model="userForm.username" type="text" class="input w-full" placeholder="Masukkan username" />
          </div>
          <div>
            <label class="mb-2 block text-sm font-bold text-slate-700">Nama Lengkap</label>
            <input v-model="userForm.full_name" type="text" class="input w-full" placeholder="Masukkan nama lengkap" />
          </div>
          <div>
            <label class="mb-2 block text-sm font-bold text-slate-700">Role</label>
            <select v-model="userForm.role" class="input w-full">
              <option value="" disabled>Pilih role</option>
              <option v-for="role in roleOptions" :key="role.value" :value="role.value">
                {{ role.label }}
              </option>
            </select>
          </div>
          <div>
            <label class="mb-2 block text-sm font-bold text-slate-700">PIN</label>
            <input v-model="userForm.password" type="password" class="input w-full" :placeholder="editingUser ? 'Kosongkan jika tidak diubah' : 'Masukkan PIN 4 digit'" maxlength="4" />
          </div>
        </div>
      </div>
      <div class="flex items-center justify-end gap-2 border-t border-slate-100 px-6 py-4">
        <button @click="closeUserForm" class="btn-secondary">Batal</button>
        <button @click="saveUser" class="btn-primary" :disabled="formLoading">
          {{ formLoading ? 'Menyimpan...' : 'Simpan' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import api from '../services/api'
import { useNotification } from '../composables/useNotification'
import DataTable from '../components/DataTable.vue'
import Pagination from '../components/Pagination.vue'

const router = useRouter()
const { success: showSuccess, error: showError, confirm } = useNotification()

const userColumns = [
  { key: 'username', label: 'Username' },
  { key: 'full_name', label: 'Nama Lengkap' },
  { key: 'role', label: 'Role', align: 'text-center' },
  { key: 'status', label: 'Status', align: 'text-center' },
  { key: 'actions', label: 'Aksi', align: 'text-center' }
]

const roleOptions = [
  { value: 'admin', label: 'Admin' },
  { value: 'manager', label: 'Manager' },
  { value: 'cashier', label: 'Kasir' },
  { value: 'waiter', label: 'Waiter' },
  { value: 'kitchen', label: 'Kitchen' },
  { value: 'bar', label: 'Bar' }
]

const loading = ref(false)
const users = ref([])
const showUserForm = ref(false)
const editingUser = ref(null)
const formLoading = ref(false)
const userForm = ref({
  username: '',
  full_name: '',
  role: '',
  password: ''
})
const pagination = ref({
  current_page: 1,
  total_pages: 1,
  total_items: 0,
  page_size: 10
})
const searchQuery = ref('')
const roleFilter = ref('')
const busyMap = ref({})

const totalUsers = computed(() => pagination.value.total_items)

const roleStats = computed(() => {
  const stats = roleOptions.reduce((acc, role) => {
    acc[role.value] = 0
    return acc
  }, {})
  users.value.forEach(user => {
    if (stats[user.role] !== undefined) {
      stats[user.role] += 1
    }
  })
  return stats
})

const filteredUsers = computed(() => {
  const query = searchQuery.value.trim().toLowerCase()
  return users.value.filter(user => {
    const matchesQuery = !query ||
      user.username?.toLowerCase().includes(query) ||
      user.full_name?.toLowerCase().includes(query)
    const matchesRole = !roleFilter.value || user.role === roleFilter.value
    return matchesQuery && matchesRole
  })
})

const setBusy = (id, value) => {
  busyMap.value = { ...busyMap.value, [id]: value }
}

const goBack = () => {
  router.push('/')
}

const fetchUsers = async () => {
  loading.value = true
  try {
    const params = {
      page: pagination.value.current_page,
      page_size: pagination.value.page_size
    }
    const response = await api.get('/users', { params })
    users.value = response.data.data || []
    if (response.data.pagination) {
      pagination.value = response.data.pagination
    }
  } catch (error) {
    showError('Gagal memuat data user')
  } finally {
    loading.value = false
  }
}

const changeRole = async (user, newRole) => {
  if (!newRole || newRole === user.role) {
    return
  }
  setBusy(user.id, true)
  try {
    const response = await api.put(`/users/${user.id}/role`, { role: newRole })
    const updatedUser = response.data.data
    users.value = users.value.map(item => item.id === user.id ? updatedUser : item)
    showSuccess('Role user berhasil diperbarui')
  } catch (error) {
    showError(error.response?.data?.message || 'Gagal memperbarui role user')
    await fetchUsers()
  } finally {
    setBusy(user.id, false)
  }
}

const confirmDelete = (user) => {
  confirm(`Nonaktifkan user ${user.username}?`, async () => {
    setBusy(user.id, true)
    try {
      await api.delete(`/users/${user.id}`)
      showSuccess('User berhasil dinonaktifkan')
      await fetchUsers()
    } catch (error) {
      showError(error.response?.data?.message || 'Gagal menonaktifkan user')
    } finally {
      setBusy(user.id, false)
    }
  })
}

const handlePageChange = (page) => {
  pagination.value.current_page = page
  fetchUsers()
}

const clearFilters = () => {
  searchQuery.value = ''
  roleFilter.value = ''
}

const openUserForm = (user = null) => {
  if (user) {
    editingUser.value = user
    userForm.value = {
      username: user.username || '',
      full_name: user.full_name || '',
      role: user.role || '',
      password: ''
    }
  } else {
    editingUser.value = null
    userForm.value = {
      username: '',
      full_name: '',
      role: '',
      password: ''
    }
  }
  showUserForm.value = true
}

const closeUserForm = () => {
  showUserForm.value = false
  editingUser.value = null
  userForm.value = {
    username: '',
    full_name: '',
    role: '',
    password: ''
  }
}

const saveUser = async () => {
  const payload = {}
  if (!userForm.value.username.trim()) {
    showError('Username wajib diisi')
    return
  }
  if (!userForm.value.full_name.trim()) {
    showError('Nama lengkap wajib diisi')
    return
  }
  if (!userForm.value.role) {
    showError('Role wajib dipilih')
    return
  }

  if (editingUser.value) {
    if (userForm.value.username !== editingUser.value.username) {
      payload.username = userForm.value.username.trim()
    }
    if (userForm.value.full_name !== editingUser.value.full_name) {
      payload.full_name = userForm.value.full_name.trim()
    }
    if (userForm.value.role !== editingUser.value.role) {
      payload.role = userForm.value.role
    }
    if (userForm.value.password) {
      if (!/^\d{4}$/.test(userForm.value.password)) {
        showError('PIN harus 4 digit angka')
        return
      }
      payload.password = userForm.value.password
    }
    if (Object.keys(payload).length === 0) {
      showError('Tidak ada data yang diubah')
      return
    }
  } else {
    if (!/^\d{4}$/.test(userForm.value.password)) {
      showError('PIN harus 4 digit angka')
      return
    }
    payload.username = userForm.value.username.trim()
    payload.full_name = userForm.value.full_name.trim()
    payload.role = userForm.value.role
    payload.password = userForm.value.password
  }

  try {
    formLoading.value = true
    if (editingUser.value) {
      await api.put(`/users/${editingUser.value.id}`, payload)
      showSuccess('User berhasil diperbarui')
    } else {
      await api.post('/auth/register', payload)
      showSuccess('User berhasil ditambahkan')
    }
    await fetchUsers()
    closeUserForm()
  } catch (error) {
    showError(error.response?.data?.message || 'Gagal menyimpan user')
  } finally {
    formLoading.value = false
  }
}

watch([searchQuery, roleFilter], () => {
  pagination.value.current_page = 1
})

onMounted(() => {
  fetchUsers()
})
</script>
