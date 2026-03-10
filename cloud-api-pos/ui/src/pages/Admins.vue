<!--
  Admins.vue — Admin user management page
  ───────────────────────────────────────────────────────────────
  Route: /admins   meta: { title: 'Admin' }

  Features:
  - List admin users
  - Create new admin (POST /admins)

  AI NOTE: Delete/edit admin can be added here with the same modal pattern.
-->
<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-bold text-gray-900">Admin</h1>
      <AppButton @click="showCreate = true">+ Tambah Admin</AppButton>
    </div>

    <AppAlert type="error" :message="errorMsg" />

    <AppCard :padding="false">
      <AppTable
        :columns="COLUMNS"
        :rows="admins"
        :loading="loading"
        emptyText="Belum ada admin."
      >
        <template #cell-role="{ row }">
          <span class="capitalize">{{ row.role }}</span>
        </template>
        <template #cell-created_at="{ row }">
          {{ formatDateTime(row.created_at) }}
        </template>
      </AppTable>
    </AppCard>

    <!-- Create Admin Modal -->
    <AppModal v-model="showCreate" title="Tambah Admin" size="sm">
      <form class="space-y-4" @submit.prevent="createAdmin">
        <AppAlert type="error" :message="createError" />
        <AppInput v-model="form.username" label="Username" placeholder="username_admin" :error="formErrors.username" />
        <AppInput v-model="form.password" label="Password" type="password" placeholder="min. 8 karakter" :error="formErrors.password" />
        <AppSelect
          v-model="form.role"
          label="Role"
          :options="[{ value: 'admin', label: 'Admin' }, { value: 'manager', label: 'Manager' }]"
          :error="formErrors.role"
        />
      </form>
      <template #footer>
        <AppButton variant="secondary" @click="showCreate = false">Batal</AppButton>
        <AppButton :loading="creating" @click="createAdmin">Simpan</AppButton>
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
  { key: 'role',       label: 'Role' },
  { key: 'created_at', label: 'Dibuat' },
]

const admins      = ref([])
const loading     = ref(false)
const errorMsg    = ref('')
const showCreate  = ref(false)
const creating    = ref(false)
const createError = ref('')
const form        = reactive({ username: '', password: '', role: 'admin' })
const formErrors  = reactive({ username: '', password: '', role: '' })

// Load on mount
loadAdmins()

async function loadAdmins() {
  loading.value = true; errorMsg.value = ''
  try {
    const res    = await adminsApi.list()
    admins.value = res.admins ?? res ?? []
  } catch (err) {
    errorMsg.value = err?.response?.data?.message ?? 'Gagal memuat admin.'
  } finally { loading.value = false }
}

async function createAdmin() {
  formErrors.username = form.username ? '' : 'Username wajib diisi'
  formErrors.password = form.password.length >= 8 ? '' : 'Password minimal 8 karakter'
  formErrors.role     = form.role ? '' : 'Role wajib dipilih'
  if (formErrors.username || formErrors.password || formErrors.role) return

  creating.value = true; createError.value = ''
  try {
    await adminsApi.create(form)
    toast.success('Admin berhasil ditambahkan!')
    showCreate.value = false
    await loadAdmins()
  } catch (err) {
    createError.value = err?.response?.data?.message ?? 'Gagal membuat admin.'
  } finally { creating.value = false }
}

watch(showCreate, (v) => {
  if (!v) {
    form.username = ''; form.password = ''; form.role = 'admin'
    formErrors.username = ''; formErrors.password = ''; formErrors.role = ''; createError.value = ''
  }
})
</script>
