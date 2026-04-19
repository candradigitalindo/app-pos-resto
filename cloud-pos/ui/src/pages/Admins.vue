<!--
  Admins.vue — Pengguna (user management) page
  ───────────────────────────────────────────────────────────────
  Route: /admins   meta: { title: 'Pengguna' }

  Features:
  - List all users
  - Create new user (POST /admins)
  - Inline role editing (PUT /admins/:id/role)
-->
<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-bold text-gray-900">Pengguna</h1>
      <AppButton @click="showCreate = true">+ Tambah Pengguna</AppButton>
    </div>

    <AppAlert type="error" :message="errorMsg" />

    <AppCard :padding="false">
      <AppTable
        :columns="COLUMNS"
        :rows="admins"
        :loading="loading"
        emptyText="Belum ada pengguna."
      >
        <template #cell-role="{ row }">
          <span class="inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold bg-blue-50 text-blue-700 capitalize">{{ row.role }}</span>
        </template>
        <template #cell-is_active="{ row }">
          <span :class="[
            'inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-semibold',
            row.is_active ? 'bg-emerald-100 text-emerald-700' : 'bg-red-100 text-red-700'
          ]">
            <span :class="['inline-block h-1.5 w-1.5 rounded-full', row.is_active ? 'bg-emerald-500' : 'bg-red-500']"></span>
            {{ row.is_active ? 'Aktif' : 'Nonaktif' }}
          </span>
        </template>
        <template #cell-created_at="{ row }">
          {{ formatDateTime(row.created_at) }}
        </template>
        <template #cell-actions="{ row }">
          <div class="flex items-center gap-1">
            <button @click="openEdit(row)" class="p-1.5 rounded-lg text-gray-400 hover:text-blue-600 hover:bg-blue-50 transition" title="Edit">
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/></svg>
            </button>
            <button @click="openResetPw(row)" class="p-1.5 rounded-lg text-gray-400 hover:text-amber-600 hover:bg-amber-50 transition" title="Reset Password">
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z"/></svg>
            </button>
            <button @click="toggleActive(row)" class="p-1.5 rounded-lg transition" :class="row.is_active ? 'text-gray-400 hover:text-red-600 hover:bg-red-50' : 'text-gray-400 hover:text-emerald-600 hover:bg-emerald-50'" :title="row.is_active ? 'Nonaktifkan' : 'Aktifkan'">
              <svg v-if="row.is_active" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636"/></svg>
              <svg v-else class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
            </button>
            <button @click="confirmDelete(row)" class="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition" title="Hapus">
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/></svg>
            </button>
          </div>
        </template>
      </AppTable>
    </AppCard>

    <!-- Create User Modal -->
    <AppModal v-model="showCreate" title="Tambah Pengguna" size="sm">
      <form class="space-y-4" @submit.prevent="createAdmin">
        <AppAlert type="error" :message="createError" />
        <AppInput v-model="form.username" label="Username" placeholder="username" :error="formErrors.username" />
        <AppInput v-model="form.password" label="Password" type="password" placeholder="min. 8 karakter" :error="formErrors.password" />
        <AppInput v-model="form.name" label="Nama" placeholder="Nama lengkap" :error="formErrors.name" />
        <AppSelect
          v-model="form.role"
          label="Role"
          :options="availableRoles.map(r => ({ value: r.name, label: r.name }))"
          :error="formErrors.role"
        />
      </form>
      <template #footer>
        <AppButton variant="secondary" @click="showCreate = false">Batal</AppButton>
        <AppButton :loading="creating" @click="createAdmin">Simpan</AppButton>
      </template>
    </AppModal>

    <!-- Edit User Modal -->
    <AppModal v-model="showEdit" title="Edit Pengguna" size="sm">
      <form class="space-y-4" @submit.prevent="saveEdit">
        <AppAlert type="error" :message="editError" />
        <AppInput :modelValue="editRow?.username" label="Username" disabled />
        <AppInput v-model="editForm.name" label="Nama" placeholder="Nama lengkap" />
        <AppSelect
          v-model="editForm.role"
          label="Role"
          :options="availableRoles.map(r => ({ value: r.name, label: r.name }))"
        />
      </form>
      <template #footer>
        <AppButton variant="secondary" @click="showEdit = false">Batal</AppButton>
        <AppButton :loading="editLoading" @click="saveEdit">Simpan</AppButton>
      </template>
    </AppModal>

    <!-- Reset Password Modal -->
    <AppModal v-model="showResetPw" title="Reset Password" size="sm">
      <div class="space-y-4">
        <AppAlert type="error" :message="resetPwError" />
        <p class="text-sm text-gray-600">Reset password untuk <strong>{{ resetPwRow?.username }}</strong></p>
        <AppInput v-model="resetPwForm.newPassword" type="password" label="Password Baru" placeholder="Minimal 6 karakter" />
        <AppInput v-model="resetPwForm.confirmPassword" type="password" label="Konfirmasi Password" placeholder="Ulangi password baru" />
      </div>
      <template #footer>
        <AppButton variant="secondary" @click="showResetPw = false">Batal</AppButton>
        <AppButton :loading="resetPwLoading" @click="saveResetPw">Reset Password</AppButton>
      </template>
    </AppModal>

    <!-- Delete Confirmation Modal -->
    <AppModal v-model="showDelete" title="Hapus Pengguna" size="sm">
      <p class="text-sm text-gray-600">Yakin ingin menghapus pengguna <strong>{{ deleteRow?.username }}</strong>? Tindakan ini tidak dapat dibatalkan.</p>
      <template #footer>
        <AppButton variant="secondary" @click="showDelete = false">Batal</AppButton>
        <AppButton variant="danger" :loading="deleteLoading" @click="doDelete">Hapus</AppButton>
      </template>
    </AppModal>
  </div>
</template>

<script setup>
import { ref, reactive, watch } from 'vue'
import { adminsApi } from '@/api/admins.js'
import { formatDateTime } from '@/utils/format.js'
import { useToastStore } from '@/stores/toast.js'
import AppButton  from '@/components/ui/AppButton.vue'
import AppCard    from '@/components/ui/AppCard.vue'
import AppTable   from '@/components/ui/AppTable.vue'
import AppModal   from '@/components/ui/AppModal.vue'
import AppInput   from '@/components/ui/AppInput.vue'
import AppSelect  from '@/components/ui/AppSelect.vue'
import AppAlert   from '@/components/ui/AppAlert.vue'

const toast = useToastStore()

const COLUMNS = [
  { key: 'username',   label: 'Username' },
  { key: 'name',       label: 'Nama' },
  { key: 'role',       label: 'Role' },
  { key: 'is_active',  label: 'Status' },
  { key: 'created_at', label: 'Dibuat' },
  { key: 'actions',    label: '', width: '140px' },
]

const admins      = ref([])
const loading     = ref(false)
const errorMsg    = ref('')
const showCreate  = ref(false)
const creating    = ref(false)
const createError = ref('')
const form        = reactive({ username: '', password: '', name: '', role: 'admin' })
const formErrors  = reactive({ username: '', password: '', name: '', role: '' })

// Edit
const showEdit    = ref(false)
const editRow     = ref(null)
const editForm    = reactive({ name: '', role: '' })
const editLoading = ref(false)
const editError   = ref('')

// Reset password
const showResetPw    = ref(false)
const resetPwRow     = ref(null)
const resetPwForm    = reactive({ newPassword: '', confirmPassword: '' })
const resetPwLoading = ref(false)
const resetPwError   = ref('')

// Delete
const showDelete    = ref(false)
const deleteRow     = ref(null)
const deleteLoading = ref(false)

// Dynamic roles from API
const availableRoles = ref([])

// Load on mount
loadAdmins()
loadRoles()

async function loadAdmins() {
  loading.value = true; errorMsg.value = ''
  try {
    const res    = await adminsApi.list()
    admins.value = res.admins ?? res ?? []
  } catch (err) {
    errorMsg.value = err?.response?.data?.message ?? 'Gagal memuat pengguna.'
  } finally { loading.value = false }
}

async function createAdmin() {
  formErrors.username = form.username ? '' : 'Username wajib diisi'
  formErrors.password = form.password.length >= 8 ? '' : 'Password minimal 8 karakter'
  formErrors.name     = form.name ? '' : 'Nama wajib diisi'
  formErrors.role     = form.role ? '' : 'Role wajib dipilih'
  if (formErrors.username || formErrors.password || formErrors.name || formErrors.role) return

  creating.value = true; createError.value = ''
  try {
    await adminsApi.create(form)
    toast.success('Pengguna berhasil ditambahkan!')
    showCreate.value = false
    await loadAdmins()
  } catch (err) {
    createError.value = err?.response?.data?.message ?? 'Gagal membuat pengguna.'
  } finally { creating.value = false }
}

// ── Edit ──
function openEdit(row) {
  editRow.value = row
  editForm.name = row.name
  editForm.role = row.role
  editError.value = ''
  showEdit.value = true
}

async function saveEdit() {
  if (!editForm.name.trim()) { editError.value = 'Nama wajib diisi'; return }
  editLoading.value = true; editError.value = ''
  try {
    await adminsApi.updateAdmin(editRow.value.id, { name: editForm.name.trim(), role: editForm.role })
    toast.success('Pengguna berhasil diperbarui')
    showEdit.value = false
    await loadAdmins()
  } catch (err) {
    editError.value = err?.response?.data?.error ?? 'Gagal memperbarui pengguna'
  } finally { editLoading.value = false }
}

// ── Reset password ──
function openResetPw(row) {
  resetPwRow.value = row
  resetPwForm.newPassword = ''
  resetPwForm.confirmPassword = ''
  resetPwError.value = ''
  showResetPw.value = true
}

async function saveResetPw() {
  if (!resetPwForm.newPassword || resetPwForm.newPassword.length < 6) {
    resetPwError.value = 'Password minimal 6 karakter'; return
  }
  if (resetPwForm.newPassword !== resetPwForm.confirmPassword) {
    resetPwError.value = 'Konfirmasi password tidak cocok'; return
  }
  resetPwLoading.value = true; resetPwError.value = ''
  try {
    await adminsApi.resetPassword(resetPwRow.value.id, resetPwForm.newPassword)
    toast.success(`Password ${resetPwRow.value.username} berhasil direset`)
    showResetPw.value = false
  } catch (err) {
    resetPwError.value = err?.response?.data?.error ?? 'Gagal mereset password'
  } finally { resetPwLoading.value = false }
}

// ── Toggle active ──
async function toggleActive(row) {
  try {
    const res = await adminsApi.toggleActive(row.id)
    const updated = res
    const idx = admins.value.findIndex(a => a.id === row.id)
    if (idx >= 0) admins.value[idx] = updated
    toast.success(updated.is_active ? `${row.username} diaktifkan` : `${row.username} dinonaktifkan`)
  } catch (err) {
    toast.error(err?.response?.data?.error ?? 'Gagal mengubah status')
  }
}

// ── Delete ──
function confirmDelete(row) {
  deleteRow.value = row
  showDelete.value = true
}

async function doDelete() {
  deleteLoading.value = true
  try {
    await adminsApi.deleteAdmin(deleteRow.value.id)
    toast.success(`${deleteRow.value.username} berhasil dihapus`)
    showDelete.value = false
    await loadAdmins()
  } catch (err) {
    toast.error(err?.response?.data?.error ?? 'Gagal menghapus pengguna')
  } finally { deleteLoading.value = false }
}

async function loadRoles() {
  try {
    const res = await adminsApi.listRoles()
    availableRoles.value = res.roles ?? []
    if (availableRoles.value.length > 0 && !availableRoles.value.find(r => r.name === form.role)) {
      form.role = availableRoles.value[0].name
    }
  } catch (err) {
    // fallback
  }
}

watch(showCreate, (v) => {
  if (!v) {
    form.username = ''; form.password = ''; form.name = ''; form.role = 'admin'
    formErrors.username = ''; formErrors.password = ''; formErrors.name = ''; formErrors.role = ''; createError.value = ''
  }
})
</script>
