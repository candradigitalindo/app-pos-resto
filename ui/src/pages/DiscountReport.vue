<template>
  <div class="space-y-6">

    <!-- Filter Bar -->
    <AppCard>
      <div class="flex flex-wrap items-end gap-4">
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-gray-700">Dari Tanggal</label>
          <input type="date" v-model="dateFrom" :max="dateTo || undefined"
            class="rounded-lg border border-gray-300 px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-brand-500" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-gray-700">Sampai Tanggal</label>
          <input type="date" v-model="dateTo" :min="dateFrom || undefined"
            class="rounded-lg border border-gray-300 px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-brand-500" />
        </div>
        <div class="flex flex-col gap-1 min-w-45">
          <label class="text-sm font-medium text-gray-700">Outlet</label>
          <SearchSelect
            v-model="selectedOutlet"
            :options="outletOptions"
            placeholder="Semua Outlet"
            searchPlaceholder="Cari outlet..."
            valueKey="value" labelKey="label"
          />
        </div>
        <button @click="page = 1; fetchReport()"
          class="px-4 py-2 bg-emerald-600 text-white text-sm font-medium rounded-lg hover:bg-emerald-700 transition-colors shadow-sm">
          Tampilkan
        </button>
      </div>
    </AppCard>

    <AppAlert type="error" :message="errorMsg" />

    <div v-if="loading" class="flex justify-center py-12">
      <AppSpinner size="lg" />
    </div>

    <template v-if="!loading && report">

      <!-- Summary Cards -->
      <div class="grid grid-cols-2 lg:grid-cols-5 gap-4">
        <AppCard>
          <p class="text-xs text-gray-500 font-medium uppercase tracking-wide">Order</p>
          <p class="text-2xl font-bold text-gray-900">{{ report.summary.total_orders }}</p>
        </AppCard>
        <AppCard>
          <p class="text-xs text-gray-500 font-medium uppercase tracking-wide">Bruto</p>
          <p class="text-xl font-bold text-gray-800">{{ formatRupiah(report.summary.gross) }}</p>
        </AppCard>
        <AppCard>
          <p class="text-xs text-amber-600 font-medium uppercase tracking-wide">Total Diskon</p>
          <p class="text-xl font-bold text-amber-600">{{ formatRupiah(report.summary.discount) }}</p>
        </AppCard>
        <AppCard>
          <p class="text-xs text-violet-600 font-medium uppercase tracking-wide">Nilai Komplimen</p>
          <p class="text-xl font-bold text-violet-600">{{ formatRupiah(report.summary.compliment) }}</p>
        </AppCard>
        <AppCard>
          <p class="text-xs text-emerald-600 font-medium uppercase tracking-wide">Net (Dibayar)</p>
          <p class="text-xl font-bold text-emerald-600">{{ formatRupiah(report.summary.net) }}</p>
        </AppCard>
      </div>

      <!-- Table -->
      <AppCard>
        <div v-if="report.data.length === 0" class="text-center py-12 text-gray-400">
          <svg class="w-12 h-12 mx-auto mb-3 opacity-40" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 14l6-6m-5.5.5h.01m4.99 5h.01M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16l3.5-2 3.5 2 3.5-2 3.5 2z"/></svg>
          <p class="font-medium">Tidak ada diskon / komplimen pada periode ini</p>
          <p class="text-xs mt-1">Data muncul saat aplikasi POS mengirim <code>discount</code> / <code>is_complimentary</code> pada order.</p>
        </div>

        <div v-else class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-gray-200">
                <th class="text-left py-3 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Waktu</th>
                <th class="text-left py-3 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Outlet</th>
                <th class="text-left py-3 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Pelanggan</th>
                <th class="text-right py-3 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Bruto</th>
                <th class="text-right py-3 px-3 text-xs font-semibold text-amber-600 uppercase tracking-wide">Diskon</th>
                <th class="text-right py-3 px-3 text-xs font-semibold text-violet-600 uppercase tracking-wide">Komplimen</th>
                <th class="text-right py-3 px-3 text-xs font-semibold text-emerald-600 uppercase tracking-wide">Net</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <tr v-for="row in report.data" :key="row.id" class="hover:bg-gray-50">
                <td class="py-3 px-3 text-gray-600 whitespace-nowrap">{{ fmtDateTime(row.created_at) }}</td>
                <td class="py-3 px-3 font-medium text-gray-800">{{ row.outlet_name || '—' }}</td>
                <td class="py-3 px-3 text-gray-600">{{ row.customer_name || '—' }}</td>
                <td class="py-3 px-3 text-right text-gray-700">{{ formatRupiah(row.gross) }}</td>
                <td class="py-3 px-3 text-right font-semibold text-amber-600">{{ row.discount > 0 ? formatRupiah(row.discount) : '—' }}</td>
                <td class="py-3 px-3 text-right font-semibold text-violet-600">{{ row.compliment > 0 ? formatRupiah(row.compliment) : '—' }}</td>
                <td class="py-3 px-3 text-right font-semibold text-gray-900">{{ formatRupiah(row.net) }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div v-if="report.total > report.limit" class="flex items-center justify-between pt-4 border-t border-gray-100 mt-4">
          <p class="text-sm text-gray-500">
            Menampilkan {{ (page-1)*report.limit + 1 }}–{{ Math.min(page*report.limit, report.total) }} dari {{ report.total }} data
          </p>
          <div class="flex gap-2">
            <button :disabled="page <= 1" class="px-3 py-1.5 text-sm border rounded-lg disabled:opacity-40 hover:bg-gray-50" @click="page--; fetchReport()">← Prev</button>
            <button :disabled="page * report.limit >= report.total" class="px-3 py-1.5 text-sm border rounded-lg disabled:opacity-40 hover:bg-gray-50" @click="page++; fetchReport()">Next →</button>
          </div>
        </div>
      </AppCard>
    </template>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { apiClient } from '@/api/client.js'
import { outletsApi } from '@/api/outlets.js'
import AppCard from '@/components/ui/AppCard.vue'
import AppAlert from '@/components/ui/AppAlert.vue'
import AppSpinner from '@/components/ui/AppSpinner.vue'
import SearchSelect from '@/components/ui/SearchSelect.vue'

function firstOfMonth() {
  const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-01`
}
function today() {
  const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`
}

const dateFrom = ref(firstOfMonth())
const dateTo   = ref(today())
const selectedOutlet = ref('')
const outletOptions  = ref([{ value: '', label: 'Semua Outlet' }])
const report   = ref(null)
const loading  = ref(false)
const errorMsg = ref('')
const page     = ref(1)

onMounted(async () => {
  try {
    const res = await outletsApi.myOutlets()
    const list = res.data ?? res ?? []
    outletOptions.value = [{ value: '', label: 'Semua Outlet' }, ...list.map(o => ({ value: o.id, label: o.name }))]
  } catch {}
  fetchReport()
})

async function fetchReport() {
  loading.value = true; errorMsg.value = ''
  try {
    const params = new URLSearchParams({ date_from: dateFrom.value, date_to: dateTo.value, page: page.value, limit: 50 })
    if (selectedOutlet.value) params.set('outlet_id', selectedOutlet.value)
    report.value = await apiClient.get(`/admin/discount-report?${params}`)
  } catch (err) {
    errorMsg.value = err?.response?.data?.error ?? 'Gagal memuat laporan diskon & komplimen'
  } finally {
    loading.value = false
  }
}

function formatRupiah(val) { return 'Rp ' + Number(val ?? 0).toLocaleString('id-ID') }
function fmtDateTime(str) {
  if (!str) return '—'
  return new Date(str).toLocaleString('id-ID', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
}
</script>
