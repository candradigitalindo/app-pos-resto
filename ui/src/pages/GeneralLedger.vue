<template>
  <div class="space-y-6">

    <!-- Filter Bar -->
    <AppCard>
      <div class="flex flex-wrap items-end gap-4" @keydown.enter="fetchReport">
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-gray-700">Dari Tanggal</label>
          <input type="date" v-model="dateFrom"
            class="rounded-lg border border-gray-300 px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-gray-700">Sampai Tanggal</label>
          <input type="date" v-model="dateTo"
            class="rounded-lg border border-gray-300 px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500" />
        </div>
        <div class="flex flex-col gap-1" style="min-width:200px">
          <label class="text-sm font-medium text-gray-700">Akun</label>
          <select v-model="selectedAccount"
            class="rounded-lg border border-gray-300 px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500">
            <option value="">Semua Akun</option>
            <option v-for="a in ACCOUNT_OPTIONS" :key="a.value" :value="a.value">{{ a.label }}</option>
          </select>
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
        <button @click="fetchReport"
          class="px-4 py-2 bg-emerald-600 text-white text-sm font-medium rounded-lg hover:bg-emerald-700 transition-colors shadow-sm">
          Tampilkan
        </button>
        <button @click="resetFilters"
          class="px-4 py-2 bg-gray-100 text-gray-600 text-sm font-medium rounded-lg hover:bg-gray-200 transition-colors shadow-sm">
          Reset
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
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <SummaryCard label="Saldo Kas" :value="formatRupiah(report.summary.cash_balance)" icon="revenue" />
        <SummaryCard label="Total Pendapatan" :value="formatRupiah(report.summary.total_revenue)" icon="revenue" />
        <SummaryCard label="Total Beban" :value="formatRupiah(report.summary.total_expense)" icon="payment" />
      </div>

      <!-- Account Cards -->
      <div class="space-y-4">
        <div v-if="report.accounts.length > 1" class="flex items-center justify-between">
          <p class="text-sm font-medium text-gray-600">{{ report.accounts.length }} akun ditemukan</p>
          <button @click="toggleAll"
            class="text-sm text-emerald-600 hover:text-emerald-700 font-medium flex items-center gap-1">
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" :d="allExpanded ? 'M5 15l7-7 7 7' : 'M19 9l-7 7-7-7'" />
            </svg>
            {{ allExpanded ? 'Tutup Semua' : 'Buka Semua' }}
          </button>
        </div>
        <div v-for="account in report.accounts" :key="account.code">
          <AppCard :padding="false">
            <!-- Account Header -->
            <button
              class="w-full flex items-center justify-between px-5 py-4 hover:bg-gray-50 transition-colors"
              @click="toggleAccount(account.code)"
            >
              <div class="flex items-center gap-3">
                <span :class="groupBadge(account.group)">{{ groupLabel(account.group) }}</span>
                <div class="text-left">
                  <p class="text-sm font-semibold text-gray-900">{{ account.code }} — {{ account.name }}</p>
                  <p class="text-xs text-gray-500">{{ account.entries.length }} entri</p>
                </div>
              </div>
              <div class="flex items-center gap-6">
                <div class="text-right">
                  <p class="text-xs text-gray-500">Debit</p>
                  <p class="text-sm font-medium text-gray-800">{{ formatRupiah(account.total_debit) }}</p>
                </div>
                <div class="text-right">
                  <p class="text-xs text-gray-500">Kredit</p>
                  <p class="text-sm font-medium text-gray-800">{{ formatRupiah(account.total_credit) }}</p>
                </div>
                <div class="text-right min-w-[100px]">
                  <p class="text-xs text-gray-500">Saldo</p>
                  <p class="text-sm font-bold" :class="account.balance >= 0 ? 'text-emerald-700' : 'text-red-600'">{{ formatRupiah(account.balance) }}</p>
                </div>
                <svg :class="['w-5 h-5 text-gray-400 transition-transform', expandedAccounts[account.code] ? 'rotate-180' : '']" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                </svg>
              </div>
            </button>

            <!-- Account Entries Table -->
            <div v-if="expandedAccounts[account.code]" class="border-t border-gray-100">
              <div class="overflow-x-auto">
                <table class="w-full text-sm">
                  <thead>
                    <tr class="bg-gray-50 text-left text-gray-500 text-xs uppercase tracking-wide">
                      <th class="py-2.5 px-4 font-medium">Tanggal</th>
                      <th class="py-2.5 px-4 font-medium">Keterangan</th>
                      <th class="py-2.5 px-4 font-medium text-right">Debit</th>
                      <th class="py-2.5 px-4 font-medium text-right">Kredit</th>
                      <th class="py-2.5 px-4 font-medium text-right">Saldo</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="(entry, idx) in paginatedEntries(account)" :key="idx" class="border-b border-gray-50 hover:bg-gray-50/50">
                      <td class="py-2 px-4 text-gray-600 whitespace-nowrap">{{ formatDateStr(entry.date) }}</td>
                      <td class="py-2 px-4 text-gray-800">{{ entry.description }}</td>
                      <td class="py-2 px-4 text-right font-medium" :class="entry.debit > 0 ? 'text-blue-700' : 'text-gray-300'">{{ entry.debit > 0 ? formatRupiah(entry.debit) : '-' }}</td>
                      <td class="py-2 px-4 text-right font-medium" :class="entry.credit > 0 ? 'text-rose-600' : 'text-gray-300'">{{ entry.credit > 0 ? formatRupiah(entry.credit) : '-' }}</td>
                      <td class="py-2 px-4 text-right font-semibold" :class="entry.balance >= 0 ? 'text-emerald-700' : 'text-red-600'">{{ formatRupiah(entry.balance) }}</td>
                    </tr>
                    <tr v-if="account.entries.length === 0">
                      <td colspan="5" class="py-6 px-4 text-center text-gray-400">Tidak ada entri pada periode ini.</td>
                    </tr>
                  </tbody>
                  <tfoot v-if="account.entries.length > 0">
                    <tr class="bg-gray-50 font-semibold text-sm">
                      <td class="py-2.5 px-4 text-gray-700" colspan="2">Total</td>
                      <td class="py-2.5 px-4 text-right text-blue-700">{{ formatRupiah(account.total_debit) }}</td>
                      <td class="py-2.5 px-4 text-right text-rose-600">{{ formatRupiah(account.total_credit) }}</td>
                      <td class="py-2.5 px-4 text-right" :class="account.balance >= 0 ? 'text-emerald-700' : 'text-red-600'">{{ formatRupiah(account.balance) }}</td>
                    </tr>
                  </tfoot>
                </table>
              </div>
              <!-- Pagination per account -->
              <div v-if="account.entries.length > ENTRIES_PER_PAGE" class="flex items-center justify-between px-4 py-3 border-t border-gray-100">
                <p class="text-xs text-gray-500">
                  Menampilkan {{ ((accountPages[account.code] || 1) - 1) * ENTRIES_PER_PAGE + 1 }}–{{ Math.min((accountPages[account.code] || 1) * ENTRIES_PER_PAGE, account.entries.length) }} dari {{ account.entries.length }} entri
                </p>
                <div class="flex items-center gap-1">
                  <button
                    @click="setAccountPage(account.code, (accountPages[account.code] || 1) - 1)"
                    :disabled="(accountPages[account.code] || 1) <= 1"
                    class="px-2 py-1 text-xs rounded border border-gray-200 hover:bg-gray-100 disabled:opacity-40 disabled:cursor-not-allowed"
                  >&laquo; Prev</button>
                  <span class="text-xs text-gray-600 px-2">{{ accountPages[account.code] || 1 }} / {{ Math.ceil(account.entries.length / ENTRIES_PER_PAGE) }}</span>
                  <button
                    @click="setAccountPage(account.code, (accountPages[account.code] || 1) + 1)"
                    :disabled="(accountPages[account.code] || 1) >= Math.ceil(account.entries.length / ENTRIES_PER_PAGE)"
                    class="px-2 py-1 text-xs rounded border border-gray-200 hover:bg-gray-100 disabled:opacity-40 disabled:cursor-not-allowed"
                  >Next &raquo;</button>
                </div>
              </div>
            </div>
          </AppCard>
        </div>
      </div>

      <!-- Empty state -->
      <AppCard v-if="report.accounts.length === 0">
        <p class="text-sm text-gray-500 text-center py-8">Tidak ada data buku besar pada periode ini.</p>
      </AppCard>
    </template>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, computed } from 'vue'
import { salesApi } from '@/api/sales.js'
import { outletsApi } from '@/api/outlets.js'
import { formatRupiah, formatDateStr, todayDateString } from '@/utils/format.js'
import AppCard       from '@/components/ui/AppCard.vue'
import AppAlert      from '@/components/ui/AppAlert.vue'
import AppSpinner    from '@/components/ui/AppSpinner.vue'
import SearchSelect  from '@/components/ui/SearchSelect.vue'
import SummaryCard   from '@/components/SummaryCard.vue'

const ENTRIES_PER_PAGE = 20

const today    = todayDateString()
const startOfMonth = today.slice(0, 8) + '01'
const dateFrom = ref(startOfMonth)
const dateTo   = ref(today)
const selectedOutlet  = ref('')
const selectedAccount = ref('')
const outletOptions   = ref([])
const loading  = ref(false)
const errorMsg = ref('')
const report   = ref(null)

const expandedAccounts = reactive({})
const accountPages     = reactive({})

const ACCOUNT_OPTIONS = [
  { value: '1-100', label: '1-100 Kas & Setara Kas' },
  { value: '1-200', label: '1-200 Piutang Usaha' },
  { value: '2-100', label: '2-100 Hutang Usaha' },
  { value: '2-200', label: '2-200 Hutang Pajak Restoran' },
  { value: '4-100', label: '4-100 Pendapatan Penjualan' },
  { value: '4-200', label: '4-200 Pendapatan Lainnya' },
  { value: '5-100', label: '5-100 HPP - Bahan Baku' },
  { value: '5-200', label: '5-200 Beban Jasa & Layanan' },
  { value: '5-300', label: '5-300 Beban Operasional' },
  { value: '6-100', label: '6-100 Beban Pajak Restoran' },
]

const GROUP_MAP = {
  aset:       { label: 'Aset',       cls: 'bg-blue-100 text-blue-700' },
  pendapatan: { label: 'Pendapatan', cls: 'bg-emerald-100 text-emerald-700' },
  beban:      { label: 'Beban',      cls: 'bg-amber-100 text-amber-700' },
  kewajiban:  { label: 'Kewajiban',  cls: 'bg-red-100 text-red-700' },
  ekuitas:    { label: 'Ekuitas',    cls: 'bg-purple-100 text-purple-700' },
}

function groupLabel(g) { return GROUP_MAP[g]?.label ?? g }
function groupBadge(g) {
  const cls = GROUP_MAP[g]?.cls ?? 'bg-gray-100 text-gray-700'
  return `inline-flex items-center px-2 py-0.5 rounded text-xs font-semibold ${cls}`
}

function toggleAccount(code) {
  expandedAccounts[code] = !expandedAccounts[code]
}

const allExpanded = computed(() => {
  if (!report.value?.accounts?.length) return false
  return report.value.accounts.every(a => expandedAccounts[a.code])
})

function toggleAll() {
  const expand = !allExpanded.value
  report.value?.accounts?.forEach(a => { expandedAccounts[a.code] = expand })
}

function resetFilters() {
  dateFrom.value = startOfMonth
  dateTo.value = today
  selectedOutlet.value = ''
  selectedAccount.value = ''
  fetchReport()
}

function setAccountPage(code, page) {
  const maxPage = Math.ceil((report.value?.accounts?.find(a => a.code === code)?.entries?.length || 0) / ENTRIES_PER_PAGE)
  if (page < 1) page = 1
  if (page > maxPage) page = maxPage
  accountPages[code] = page
}

function paginatedEntries(account) {
  const page = accountPages[account.code] || 1
  const start = (page - 1) * ENTRIES_PER_PAGE
  return account.entries.slice(start, start + ENTRIES_PER_PAGE)
}

onMounted(async () => {
  try {
    const data = await outletsApi.myOutlets()
    const list = data.outlets ?? data ?? []
    outletOptions.value = list.map(o => ({ value: o.id, label: o.name }))
  } catch { /* ignore */ }
  fetchReport()
})

async function fetchReport() {
  loading.value = true
  errorMsg.value = ''
  try {
    const params = {
      date_from: dateFrom.value,
      date_to: dateTo.value,
    }
    if (selectedOutlet.value) params.outlet_id = selectedOutlet.value
    if (selectedAccount.value) params.account = selectedAccount.value

    report.value = await salesApi.getGeneralLedger(params)

    // Reset expanded states and pages
    Object.keys(expandedAccounts).forEach(k => { expandedAccounts[k] = false })
    Object.keys(accountPages).forEach(k => { accountPages[k] = 1 })

    // Auto-expand first account or the single filtered account
    if (report.value?.accounts?.length > 0) {
      if (report.value.accounts.length === 1) {
        expandedAccounts[report.value.accounts[0].code] = true
      }
    }
  } catch (err) {
    errorMsg.value = err?.message ?? 'Gagal memuat buku besar.'
  } finally {
    loading.value = false
  }
}
</script>
