<template>
  <div class="space-y-6">

    <!-- Filter Bar -->
    <AppCard>
      <div class="flex flex-wrap items-end gap-4">
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-gray-700">Dari Tanggal</label>
          <input type="date" v-model="dateFrom"
            class="rounded-lg border border-gray-300 px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-brand-500" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-gray-700">Sampai Tanggal</label>
          <input type="date" v-model="dateTo"
            class="rounded-lg border border-gray-300 px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-brand-500" />
        </div>
        <div class="flex flex-col gap-1 min-w-45">
          <label class="text-sm font-medium text-gray-700">Outlet</label>
          <SearchSelect
            v-model="selectedOutlet"
            :options="outletOptions"
            placeholder="Semua Outlet"
            searchPlaceholder="Cari outlet..."
            valueKey="value"
            labelKey="label"
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
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <AppCard>
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-xl bg-red-100 flex items-center justify-center">
              <svg class="w-5 h-5 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636"/></svg>
            </div>
            <div>
              <p class="text-xs text-gray-500 font-medium uppercase tracking-wide">Total Order Void</p>
              <p class="text-2xl font-bold text-gray-900">{{ report.summary.total_voided }}</p>
            </div>
          </div>
        </AppCard>
        <AppCard>
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-xl bg-orange-100 flex items-center justify-center">
              <svg class="w-5 h-5 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
            </div>
            <div>
              <p class="text-xs text-gray-500 font-medium uppercase tracking-wide">Total Nilai Void</p>
              <p class="text-2xl font-bold text-gray-900">{{ formatRupiah(report.summary.total_amount) }}</p>
            </div>
          </div>
        </AppCard>
      </div>

      <!-- Table -->
      <AppCard>
        <div v-if="report.data.length === 0" class="text-center py-12 text-gray-400">
          <svg class="w-12 h-12 mx-auto mb-3 opacity-40" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/></svg>
          <p class="font-medium">Tidak ada order void pada periode ini</p>
        </div>

        <div v-else class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-gray-200">
                <th class="text-left py-3 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Waktu Void</th>
                <th class="text-left py-3 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Outlet</th>
                <th class="text-left py-3 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Meja</th>
                <th class="text-left py-3 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Pelanggan</th>
                <th class="text-left py-3 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Item</th>
                <th class="text-right py-3 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Total</th>
                <th class="text-left py-3 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Di-void oleh</th>
                <th class="text-left py-3 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Alasan</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <tr v-for="row in report.data" :key="row.id" class="hover:bg-gray-50">
                <td class="py-3 px-3 text-gray-600 whitespace-nowrap">{{ fmtDateTime(row.voided_at) }}</td>
                <td class="py-3 px-3 font-medium text-gray-800">{{ row.outlet_name || '—' }}</td>
                <td class="py-3 px-3 text-gray-600">{{ row.table_number || '—' }}</td>
                <td class="py-3 px-3 text-gray-600">{{ row.customer_name || '—' }}</td>
                <td class="py-3 px-3">
                  <div class="flex flex-wrap gap-1">
                    <span v-for="item in parseItems(row.items)" :key="item.product_name"
                      class="inline-flex items-center gap-1 px-2 py-0.5 bg-gray-100 text-gray-700 rounded text-xs">
                      {{ item.qty }}× {{ item.product_name }}
                    </span>
                  </div>
                </td>
                <td class="py-3 px-3 text-right font-semibold text-red-600">{{ formatRupiah(row.total_amount) }}</td>
                <td class="py-3 px-3 text-gray-600">{{ row.voided_by || '—' }}</td>
                <td class="py-3 px-3 text-gray-500 italic">{{ row.void_reason || '—' }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Pagination -->
        <div v-if="report.total > report.limit" class="flex items-center justify-between pt-4 border-t border-gray-100 mt-4">
          <p class="text-sm text-gray-500">
            Menampilkan {{ (page-1)*report.limit + 1 }}–{{ Math.min(page*report.limit, report.total) }} dari {{ report.total }} data
          </p>
          <div class="flex gap-2">
            <button :disabled="page <= 1"
              class="px-3 py-1.5 text-sm border rounded-lg disabled:opacity-40 hover:bg-gray-50"
              @click="page--; fetchReport()">← Prev</button>
            <button :disabled="page * report.limit >= report.total"
              class="px-3 py-1.5 text-sm border rounded-lg disabled:opacity-40 hover:bg-gray-50"
              @click="page++; fetchReport()">Next →</button>
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
import AppCard    from '@/components/ui/AppCard.vue'
import AppAlert   from '@/components/ui/AppAlert.vue'
import AppSpinner from '@/components/ui/AppSpinner.vue'
import SearchSelect from '@/components/ui/SearchSelect.vue'

const dateFrom      = ref(new Date(new Date().setDate(1)).toISOString().slice(0,10))
const dateTo        = ref(new Date().toISOString().slice(0,10))
const selectedOutlet = ref('')
const outletOptions  = ref([{ value: '', label: 'Semua Outlet' }])
const report        = ref(null)
const loading       = ref(false)
const errorMsg      = ref('')
const page          = ref(1)

onMounted(async () => {
  try {
    // Use the scoped, permission-free endpoint so the dropdown only ever lists
    // outlets this role may access (consistent with the other report pages).
    const res = await outletsApi.myOutlets()
    const list = res.data ?? res ?? []
    outletOptions.value = [
      { value: '', label: 'Semua Outlet' },
      ...list.map(o => ({ value: o.id, label: o.name })),
    ]
  } catch {}
  fetchReport()
})

async function fetchReport() {
  loading.value = true; errorMsg.value = ''
  try {
    const params = new URLSearchParams({
      date_from: dateFrom.value,
      date_to: dateTo.value,
      page: page.value,
      limit: 50,
    })
    if (selectedOutlet.value) params.set('outlet_id', selectedOutlet.value)
    report.value = await apiClient.get(`/admin/void-report?${params}`)
  } catch (err) {
    errorMsg.value = err?.response?.data?.error ?? 'Gagal memuat laporan void'
  } finally {
    loading.value = false
  }
}

function parseItems(raw) {
  try { return JSON.parse(raw) ?? [] } catch { return [] }
}

function formatRupiah(val) {
  return 'Rp ' + Number(val ?? 0).toLocaleString('id-ID')
}

function fmtDateTime(str) {
  if (!str) return '—'
  return new Date(str).toLocaleString('id-ID', {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  })
}
</script>
