<template>
  <div class="min-h-screen bg-slate-50 pb-24 lg:pb-6">
    <div class="mx-auto max-w-7xl px-3 sm:px-4 lg:px-8 py-4 sm:py-6 space-y-4 sm:space-y-6">
      <!-- Header -->
      <div class="overflow-hidden rounded-2xl bg-gradient-to-r from-emerald-600 to-emerald-500 p-4 sm:p-6 shadow-xl">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div class="flex items-center gap-3">
            <div class="flex h-12 w-12 sm:h-14 sm:w-14 items-center justify-center rounded-xl bg-white/20 backdrop-blur-sm">
              <svg class="h-6 w-6 sm:h-7 sm:w-7 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
            </div>
            <div>
              <h1 class="text-xl sm:text-2xl font-bold text-white">Kasir</h1>
              <p class="text-xs sm:text-sm text-emerald-100">Proses Pembayaran</p>
            </div>
          </div>
          <button @click="refreshData" class="flex items-center justify-center gap-2 rounded-xl bg-white px-4 py-2.5 font-semibold text-emerald-600 shadow-lg transition-all hover:scale-105 active:scale-95" :disabled="loading">
            <svg class="h-5 w-5" :class="loading ? 'animate-spin' : ''" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
            <span class="hidden sm:inline">{{ loading ? 'Memuat...' : 'Refresh' }}</span>
          </button>
        </div>
      </div>

      <div class="overflow-hidden rounded-2xl bg-white p-4 shadow-lg">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <div class="text-sm font-semibold text-slate-700">Shift Kasir</div>
            <div class="text-xs text-slate-500">Status dan uang modal kasir</div>
          </div>
          <div v-if="shiftLoading" class="text-xs font-semibold text-slate-500">Memuat...</div>
          <div v-else class="flex flex-col sm:flex-row gap-2">
            <button
              v-if="!isShiftOpen"
              @click="openOpenShiftModal"
              class="px-4 py-2.5 rounded-xl bg-emerald-600 text-white text-sm font-semibold hover:bg-emerald-700 transition-all"
            >
              Buka Shift
            </button>
            <template v-else>
              <button
                @click="openHandoverShiftModal"
                class="px-4 py-2.5 rounded-xl bg-amber-500 text-white text-sm font-semibold hover:bg-amber-600 transition-all"
              >
                Serah Terima
              </button>
              <button
                @click="openCloseShiftModal"
                class="px-4 py-2.5 rounded-xl bg-rose-600 text-white text-sm font-semibold hover:bg-rose-700 transition-all"
              >
                Tutup Shift
              </button>
            </template>
          </div>
        </div>
        <div v-if="!shiftLoading" class="mt-4 grid gap-4 lg:grid-cols-2">
          <div class="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
            <div class="flex items-center justify-between">
              <div>
                <div class="text-xs text-slate-500">Ringkasan Shift</div>
                <div class="text-sm font-semibold text-slate-800">
                  {{ isShiftOpen ? 'Shift Aktif' : 'Belum ada shift aktif' }}
                </div>
              </div>
              <span
                :class="isShiftOpen ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-500'"
                class="px-3 py-1 rounded-full text-[11px] font-semibold"
              >
                {{ isShiftOpen ? 'Sedang berlangsung' : 'Menunggu buka shift' }}
              </span>
            </div>
            <div v-if="isShiftOpen" class="mt-3 grid gap-3 sm:grid-cols-2">
              <div class="rounded-xl border border-emerald-100 bg-emerald-50 px-3 py-2">
                <div class="text-[11px] text-emerald-700">Kasir</div>
                <div class="text-sm font-semibold text-emerald-900">{{ currentShift?.opened_by_name || 'Kasir' }}</div>
              </div>
              <div class="rounded-xl border border-emerald-100 bg-emerald-50 px-3 py-2">
                <div class="text-[11px] text-emerald-700">Mulai</div>
                <div class="text-sm font-semibold text-emerald-900">{{ formatDateTime(currentShift?.opened_at) }}</div>
              </div>
              <div class="rounded-xl border border-slate-200 bg-white px-3 py-2 sm:col-span-2">
                <div class="text-[11px] text-slate-500">Modal Awal</div>
                <div class="text-base font-bold text-slate-900">
                  {{ formatCurrency(currentShift?.opening_cash || 0) }}
                </div>
              </div>
            </div>
            <div v-else class="mt-3 grid gap-3">
              <div v-if="lastClosedShift" class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
                <div class="text-[11px] text-slate-500">Shift terakhir ditutup</div>
                <div class="text-sm font-semibold text-slate-700">{{ formatDateTime(lastClosedShift?.closed_at) }}</div>
              </div>
              <div v-if="lastClosedShift?.carry_over_cash != null" class="rounded-xl border border-slate-200 bg-white px-3 py-2">
                <div class="text-[11px] text-slate-500">Modal Terakhir</div>
                <div class="text-base font-bold text-slate-900">
                  {{ formatCurrency(lastClosedShift?.carry_over_cash || 0) }}
                </div>
              </div>
              <div v-if="lastClosedShift" class="grid grid-cols-2 gap-2 text-xs text-slate-600">
                <div>Cash {{ formatCurrency(lastClosedShift?.closing_cash || 0) }}</div>
                <div>QRIS {{ formatCurrency(lastClosedShift?.closing_qris || 0) }}</div>
                <div>Kartu {{ formatCurrency(lastClosedShift?.closing_card || 0) }}</div>
                <div>Transfer {{ formatCurrency(lastClosedShift?.closing_transfer || 0) }}</div>
              </div>
            </div>
          </div>
          <div class="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
            <div class="flex items-center justify-between">
              <div>
                <div class="text-xs text-slate-500">Uang Masuk/Keluar</div>
                <div class="text-sm font-semibold text-slate-800">
                  {{ isShiftOpen ? 'Shift Aktif' : 'Shift Terakhir' }}
                </div>
              </div>
              <div v-if="isShiftOpen" class="flex gap-2">
                <button
                  type="button"
                  @click="openCashMovementModal('in')"
                  class="px-3 py-1 rounded-full bg-emerald-100 text-[11px] font-semibold text-emerald-700 hover:bg-emerald-200"
                >
                  Uang Masuk
                </button>
                <button
                  type="button"
                  @click="openCashMovementModal('out')"
                  class="px-3 py-1 rounded-full bg-amber-100 text-[11px] font-semibold text-amber-700 hover:bg-amber-200"
                >
                  Uang Keluar
                </button>
              </div>
            </div>
            <div class="mt-3 grid gap-2 sm:grid-cols-2">
              <div class="rounded-xl border border-emerald-100 bg-emerald-50 px-3 py-2">
                <div class="flex items-center justify-between">
                  <div class="text-[11px] text-emerald-700">Total Uang Masuk</div>
                  <button
                    type="button"
                    @click="openCashMovementHistoryModal('in', isShiftOpen ? 'current' : 'last')"
                    class="text-[11px] font-semibold text-emerald-600 hover:text-emerald-700"
                  >
                    Riwayat
                  </button>
                </div>
                <div class="text-sm font-semibold text-emerald-800">
                  {{ formatCurrency(displayCashMovements.total_in || 0) }}
                </div>
              </div>
              <div class="rounded-xl border border-amber-100 bg-amber-50 px-3 py-2">
                <div class="flex items-center justify-between">
                  <div class="text-[11px] text-amber-700">Total Uang Keluar</div>
                  <button
                    type="button"
                    @click="openCashMovementHistoryModal('out', isShiftOpen ? 'current' : 'last')"
                    class="text-[11px] font-semibold text-amber-600 hover:text-amber-700"
                  >
                    Riwayat
                  </button>
                </div>
                <div class="text-sm font-semibold text-amber-800">
                  {{ formatCurrency(displayCashMovements.total_out || 0) }}
                </div>
              </div>
            </div>
            <div v-if="!isShiftOpen && !lastClosedShift?.cash_movements" class="mt-3 text-xs text-slate-500">
              Belum ada data uang masuk/keluar.
            </div>
          </div>
        </div>
      </div>

      <!-- Stats -->
      <div class="grid gap-3 sm:gap-4 grid-cols-2 lg:grid-cols-4">
        <div class="overflow-hidden rounded-2xl bg-white p-3 sm:p-4 shadow-lg">
          <div class="flex flex-col sm:flex-row items-center gap-2 sm:gap-3">
            <div class="flex h-10 w-10 sm:h-12 sm:w-12 items-center justify-center rounded-xl bg-emerald-100">
              <svg class="h-5 w-5 sm:h-6 sm:w-6 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div class="text-center sm:text-left">
              <div class="text-xs text-slate-500">Pendapatan Hari Ini</div>
              <div class="text-lg sm:text-xl font-bold text-slate-900">{{ formatCurrency(todayRevenue) }}</div>
            </div>
          </div>
        </div>
        <div class="overflow-hidden rounded-2xl bg-white p-3 sm:p-4 shadow-lg">
          <div class="flex flex-col sm:flex-row items-center gap-2 sm:gap-3">
            <div class="flex h-10 w-10 sm:h-12 sm:w-12 items-center justify-center rounded-xl bg-blue-100">
              <svg class="h-5 w-5 sm:h-6 sm:w-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
              </svg>
            </div>
            <div class="text-center sm:text-left">
              <div class="text-xs text-slate-500">Transaksi Hari Ini</div>
              <div class="text-lg sm:text-xl font-bold text-slate-900">{{ todayTransactions }}</div>
            </div>
          </div>
        </div>
        <div class="overflow-hidden rounded-2xl bg-white p-3 sm:p-4 shadow-lg">
          <div class="flex flex-col sm:flex-row items-center gap-2 sm:gap-3">
            <div class="flex h-10 w-10 sm:h-12 sm:w-12 items-center justify-center rounded-xl bg-red-100">
              <svg class="h-5 w-5 sm:h-6 sm:w-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div class="text-center sm:text-left">
              <div class="text-xs text-slate-500">Pending Payment</div>
              <div class="text-lg sm:text-xl font-bold text-slate-900">{{ pendingTables.length }}</div>
            </div>
          </div>
        </div>
        <div class="overflow-hidden rounded-2xl bg-white p-3 sm:p-4 shadow-lg">
          <div class="flex flex-col sm:flex-row items-center gap-2 sm:gap-3">
            <div class="flex h-10 w-10 sm:h-12 sm:w-12 items-center justify-center rounded-xl bg-amber-100">
              <svg class="h-5 w-5 sm:h-6 sm:w-6 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
              </svg>
            </div>
            <div class="text-center sm:text-left">
              <div class="text-xs text-slate-500">Rata-rata</div>
              <div class="text-lg sm:text-xl font-bold text-slate-900">{{ formatCurrency(avgTransaction) }}</div>
            </div>
          </div>
        </div>
      </div>

      <!-- Tabs -->
      <div class="overflow-hidden rounded-2xl bg-white p-3 sm:p-4 shadow-lg">
        <div class="flex gap-2">
          <button
            @click="activeTab = 'orders'"
            :class="[
              'flex-1 rounded-xl px-4 py-3 text-sm sm:text-base font-bold transition-all',
              activeTab === 'orders' 
                ? 'bg-gradient-to-r from-emerald-600 to-emerald-500 text-white shadow-lg' 
                : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
            ]"
          >
            <svg class="inline-block h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z" />
            </svg>
            Pending Orders
          </button>
          <button
            @click="activeTab = 'history'"
            :class="[
              'flex-1 rounded-xl px-4 py-3 text-sm sm:text-base font-bold transition-all',
              activeTab === 'history' 
                ? 'bg-gradient-to-r from-emerald-600 to-emerald-500 text-white shadow-lg' 
                : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
            ]"
          >
            <svg class="inline-block h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            Riwayat
          </button>
        </div>
      </div>

      <!-- Pending Orders Tab -->
      <div v-if="activeTab === 'orders'">
        <div v-if="loading" class="flex justify-center items-center py-12">
          <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-emerald-600"></div>
        </div>
        <div v-else>
          <div v-if="pendingTables.length > 0" class="overflow-hidden rounded-2xl bg-white p-3 sm:p-4 shadow-lg mb-4">
            <div class="relative">
              <input
                v-model="tableSearchQuery"
                type="text"
                placeholder="Cari nomor meja..."
                class="w-full h-11 pl-11 pr-10 rounded-xl border-2 border-slate-200 bg-slate-50 text-sm sm:text-base font-medium placeholder-slate-400 focus:outline-none focus:border-emerald-500 focus:bg-white focus:ring-4 focus:ring-emerald-100 transition-all"
              />
              <svg class="absolute left-3.5 top-1/2 -translate-y-1/2 h-5 w-5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 9 9 0 0114 0z" />
              </svg>
              <button
                v-if="tableSearchQuery"
                @click="tableSearchQuery = ''"
                class="absolute right-3 top-1/2 -translate-y-1/2 p-1 rounded-full hover:bg-slate-100 transition-colors"
              >
                <svg class="h-4 w-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
          </div>

          <div v-if="pendingTables.length === 0" class="overflow-hidden rounded-2xl bg-white p-12 shadow-lg">
            <div class="flex flex-col items-center gap-6 text-center">
              <div class="flex h-24 w-24 items-center justify-center rounded-full bg-gradient-to-br from-emerald-100 to-emerald-200">
                <svg class="h-12 w-12 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <div>
                <h3 class="text-2xl font-bold text-slate-900">Tidak Ada Order Pending</h3>
                <p class="mt-2 text-slate-500">Semua pembayaran sudah diproses</p>
              </div>
            </div>
          </div>

          <div v-else-if="filteredPendingTables.length === 0" class="overflow-hidden rounded-2xl bg-white p-12 shadow-lg">
            <div class="flex flex-col items-center gap-6 text-center">
              <div class="flex h-24 w-24 items-center justify-center rounded-full bg-gradient-to-br from-slate-100 to-slate-200">
                <svg class="h-12 w-12 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
              </div>
              <div>
                <h3 class="text-2xl font-bold text-slate-900">Meja Tidak Ditemukan</h3>
                <p class="mt-2 text-slate-500">Coba kata kunci lain</p>
              </div>
            </div>
          </div>

          <div v-else class="overflow-hidden rounded-2xl bg-white shadow-lg">
            <div class="overflow-x-auto">
              <table class="w-full">
                <thead class="bg-slate-50">
                  <tr>
                    <th class="px-4 py-3 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">Meja</th>
                    <th class="px-4 py-3 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">Waiter</th>
                    <th class="px-4 py-3 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">Tamu</th>
                    <th class="px-4 py-3 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">Basket</th>
                    <th class="px-4 py-3 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">Nomor Pesanan</th>
                    <th class="px-4 py-3 text-right text-xs font-semibold text-slate-600 uppercase tracking-wider">Total</th>
                    <th class="px-4 py-3 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">Waktu</th>
                    <th class="px-4 py-3 text-center text-xs font-semibold text-slate-600 uppercase tracking-wider">Item</th>
                    <th class="px-4 py-3 text-center text-xs font-semibold text-slate-600 uppercase tracking-wider">Status</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-100">
                  <tr
                    v-for="table in filteredPendingTables"
                    :key="table.id"
                    class="hover:bg-slate-50 transition-colors cursor-pointer"
                    @click="viewOrder(table)"
                  >
                    <td class="px-4 py-3 text-sm font-semibold text-slate-900">
                      <div class="flex items-center gap-2">
                        <span>Meja {{ table.table_number }}</span>
                        <span
                          v-if="table.active_order?.is_merged"
                          class="inline-flex items-center rounded-full bg-amber-100 px-2 py-0.5 text-[10px] font-semibold text-amber-700"
                        >
                          Gabung ke {{ table.active_order?.merged_from_table_number || '-' }}
                        </span>
                      </div>
                    </td>
                    <td class="px-4 py-3 text-sm text-slate-700">{{ table.active_order?.waiter_name || '-' }}</td>
                    <td class="px-4 py-3 text-sm text-slate-700">{{ table.active_order?.pax || 0 }} orang</td>
                    <td class="px-4 py-3 text-sm text-slate-700">{{ table.active_order?.basket_size || 0 }}</td>
                    <td class="px-4 py-3 text-sm font-mono text-slate-600">{{ table.active_order?.order_id || '-' }}</td>
                    <td class="px-4 py-3 text-right text-sm font-bold text-emerald-600">{{ formatCurrency(getRemainingAmount(table.active_order)) }}</td>
                    <td class="px-4 py-3 text-sm text-slate-600">{{ formatTime(table.active_order?.created_at) }}</td>
                    <td class="px-4 py-3 text-center">
                      <button
                        type="button"
                        class="inline-flex items-center justify-center rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-1.5 text-xs font-semibold text-emerald-700 hover:bg-emerald-100"
                        @click.stop="openItemsModal(table)"
                      >
                        Lihat Item
                      </button>
                    </td>
                    <td class="px-4 py-3 text-center">
                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-700">
                        {{ (table.active_order?.payment_status || 'unpaid').toUpperCase() }}
                      </span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <!-- History Tab -->
      <div v-if="activeTab === 'history'">
        <div v-if="historyLoading" class="flex justify-center items-center py-12">
          <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-emerald-600"></div>
        </div>
        
        <div v-else-if="transactions.length === 0 && voidedOrders.length === 0" class="overflow-hidden rounded-2xl bg-white p-12 shadow-lg">
          <div class="flex flex-col items-center gap-6 text-center">
            <div class="flex h-24 w-24 items-center justify-center rounded-full bg-gradient-to-br from-slate-100 to-slate-200">
              <svg class="h-12 w-12 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div>
              <h3 class="text-2xl font-bold text-slate-900">Belum Ada Riwayat</h3>
              <p class="mt-2 text-slate-500">Transaksi yang sudah diproses akan muncul di sini</p>
            </div>
          </div>
        </div>

        <div v-else class="flex flex-col gap-6">
          <div class="overflow-hidden rounded-2xl bg-white p-4 shadow-lg">
            <div class="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
              <div class="flex flex-col gap-3 sm:flex-row sm:items-end">
                <div>
                  <div class="text-xs font-semibold text-slate-500 mb-1">Tanggal Mulai</div>
                  <input
                    v-model="historyStartDate"
                    type="date"
                    class="h-11 w-full sm:w-44 px-3 rounded-xl border-2 border-slate-200 bg-slate-50 text-sm font-medium focus:outline-none focus:border-emerald-500 focus:bg-white focus:ring-4 focus:ring-emerald-100 transition-all"
                    :max="historyStartMax"
                  />
                </div>
                <div>
                  <div class="text-xs font-semibold text-slate-500 mb-1">Tanggal Akhir</div>
                  <input
                    v-model="historyEndDate"
                    type="date"
                    class="h-11 w-full sm:w-44 px-3 rounded-xl border-2 border-slate-200 bg-slate-50 text-sm font-medium focus:outline-none focus:border-emerald-500 focus:bg-white focus:ring-4 focus:ring-emerald-100 transition-all"
                    :min="historyStartDate"
                    :max="historyEndMax"
                  />
                </div>
              </div>
              <div class="flex gap-2">
                <button
                  type="button"
                  @click="applyHistoryFilter"
                  class="h-11 px-4 rounded-xl bg-emerald-600 text-white text-sm font-semibold hover:bg-emerald-700 transition-all"
                >
                  Terapkan
                </button>
                <button
                  type="button"
                  @click="resetHistoryFilter"
                  class="h-11 px-4 rounded-xl border-2 border-slate-200 text-slate-600 text-sm font-semibold hover:bg-slate-50 transition-all"
                >
                  Hari Ini
                </button>
              </div>
            </div>
            <div class="mt-2 text-xs text-slate-500">Maksimal rentang 3 bulan</div>
          </div>
          <div class="overflow-hidden rounded-2xl bg-white shadow-lg">
            <div class="flex items-center justify-between border-b border-slate-100 px-4 py-3">
              <div class="text-sm font-semibold text-slate-700">Histori Bayar</div>
              <div class="flex items-center gap-3 text-xs text-slate-500">
                <span>{{ transactionPagination.total_items }} data</span>
                <span>Total Nominal {{ formatCurrency(totalPaidAmount) }}</span>
              </div>
            </div>
            <DataTable :columns="transactionColumns" :data="transactions">
              <template #cell-time="{ item }">
                <span class="text-sm text-slate-900">{{ formatDateTime(item.created_at) }}</span>
              </template>
              <template #cell-id="{ item }">
                <span class="text-sm font-mono text-slate-600">{{ item.order_id || item.id || '-' }}</span>
              </template>
              <template #cell-payment_method="{ item }">
                <span :class="getPaymentMethodClass(item.payment_method)" class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium">
                  {{ getPaymentMethodText(item.payment_method) }}
                </span>
              </template>
              <template #cell-total_amount="{ item }">
                <span class="text-sm font-bold text-slate-900">{{ formatCurrency(item.total_amount) }}</span>
              </template>
              <template #cell-status="{ item }">
                <span :class="getTransactionStatusClass(item.status)" class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium">
                  {{ getTransactionStatusText(item.status) }}
                </span>
              </template>
              <template #cell-actions="{ item }">
                <div class="flex items-center justify-center gap-2">
                  <button
                    type="button"
                    class="inline-flex items-center justify-center rounded-lg border border-emerald-200 px-3 py-1.5 text-xs font-semibold text-emerald-600 hover:bg-emerald-50"
                    @click.stop="openReceiptDetail(item)"
                  >
                    Detail
                  </button>
                  <button
                    type="button"
                    class="inline-flex items-center justify-center rounded-lg border border-red-200 px-3 py-1.5 text-xs font-semibold text-red-600 hover:bg-red-50 disabled:opacity-50 disabled:cursor-not-allowed"
                    :disabled="item.status === 'cancelled'"
                    @click.stop="openCancelTransactionModal(item)"
                  >
                    Batalkan
                  </button>
                </div>
              </template>
            </DataTable>
          </div>
          <div v-if="transactionPagination.total_items > 0" class="mt-4">
            <Pagination
              :current-page="transactionPagination.current_page"
              :total-pages="transactionPagination.total_pages"
              :total-items="transactionPagination.total_items"
              item-name="transaksi"
              @page-change="goToTransactionPage"
            />
          </div>
          <div class="overflow-hidden rounded-2xl bg-white shadow-lg">
            <div class="flex items-center justify-between border-b border-slate-100 px-4 py-3">
              <div class="text-sm font-semibold text-slate-700">Histori Void Order</div>
              <div class="flex items-center gap-3 text-xs text-slate-500">
                <span>{{ voidPagination.total_items }} data</span>
                <span>Total Void {{ formatCurrency(totalVoidAmount) }}</span>
              </div>
            </div>
            <DataTable :columns="voidColumns" :data="voidedOrders">
              <template #cell-voided_at="{ item }">
                <span class="text-sm text-slate-900">{{ formatDateTime(item.voided_at || item.created_at) }}</span>
              </template>
              <template #cell-id="{ item }">
                <span class="text-sm font-mono text-slate-600">{{ item.order_id || item.id || '-' }}</span>
              </template>
              <template #cell-table_number="{ item }">
                <span class="text-sm text-slate-700">{{ item.table_number || '-' }}</span>
              </template>
              <template #cell-total_amount="{ item }">
                <span class="text-sm font-bold text-slate-900">{{ formatCurrency(item.total_amount) }}</span>
              </template>
              <template #cell-voided_by="{ item }">
                <span class="text-sm text-slate-700">{{ item.voided_by_name || item.voided_by || '-' }}</span>
              </template>
              <template #cell-void_reason="{ item }">
                <span class="text-sm text-slate-600">{{ item.void_reason || '-' }}</span>
              </template>
            </DataTable>
          </div>
          <div v-if="voidPagination.total_items > 0" class="mt-4">
            <Pagination
              :current-page="voidPagination.current_page"
              :total-pages="voidPagination.total_pages"
              :total-items="voidPagination.total_items"
              item-name="void"
              @page-change="goToVoidPage"
            />
          </div>
        </div>
      </div>
    </div>

    <!-- Order Detail Modal -->
    <el-dialog
      v-model="showOrderModal"
      title="Detail Order"
      width="92%"
      style="max-width: 720px;"
      :close-on-click-modal="false"
    >
      <div v-if="loadingOrderDetail" class="flex justify-center items-center py-12">
        <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-emerald-600"></div>
      </div>
      
      <div v-else-if="currentOrder" class="flex flex-col gap-4">
        <div class="bg-slate-50 rounded-xl p-4">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
            <div>
              <div class="text-slate-500">Meja</div>
              <div class="font-bold text-slate-900">{{ currentOrder.order.table_number }}</div>
            </div>
            <div>
              <div class="text-slate-500">Tamu</div>
              <div class="font-bold text-slate-900">{{ currentOrder.order.pax }} orang</div>
            </div>
            <div>
              <div class="text-slate-500">Nomor Pesanan</div>
              <div class="font-mono text-xs text-slate-600">{{ currentOrder.order.id }}</div>
            </div>
            <div>
              <div class="text-slate-500">Waktu</div>
              <div class="text-slate-900">{{ formatDateTime(currentOrder.order.created_at) }}</div>
            </div>
            <div>
              <div class="text-slate-500">Waiter</div>
              <div class="font-bold text-slate-900">{{ currentOrder.order.waiter_name || '-' }}</div>
            </div>
            <div>
              <div class="text-slate-500">Basket</div>
              <div class="font-bold text-slate-900">{{ currentOrder.order.basket_size || orderItems.length }}</div>
            </div>
            <div>
              <div class="text-slate-500">Status Pesanan</div>
              <div :class="getOrderStatusClass(currentOrder.order.order_status)" class="inline-flex px-2 py-1 rounded-full text-xs font-semibold">
                {{ getOrderStatusText(currentOrder.order.order_status) }}
              </div>
            </div>
            <div>
              <div class="text-slate-500">Status Pembayaran</div>
              <div :class="getPaymentStatusClass(currentOrder.order.payment_status)" class="inline-flex px-2 py-1 rounded-full text-xs font-semibold">
                {{ getPaymentStatusText(currentOrder.order.payment_status) }}
              </div>
            </div>
            <div>
              <div class="text-slate-500">Total</div>
              <div class="font-bold text-slate-900">{{ formatCurrency(getOrderTotal(currentOrder.order)) }}</div>
            </div>
            <div>
              <div class="text-slate-500">Dibayar</div>
              <div class="font-bold text-slate-900">{{ formatCurrency(currentOrder.order.paid_amount || 0) }}</div>
            </div>
            <div>
              <div class="text-slate-500">Sisa</div>
              <div class="font-semibold text-rose-600">{{ formatCurrency(getRemainingAmount(currentOrder.order)) }}</div>
            </div>
            <div>
              <div class="text-slate-500">Update Terakhir</div>
              <div class="text-slate-900">{{ formatDateTime(currentOrder.order.updated_at || currentOrder.order.created_at) }}</div>
            </div>
            <div v-if="currentOrder.order.is_merged">
              <div class="text-slate-500">Gabungan</div>
              <div class="font-semibold text-amber-700">Digabung ke Meja {{ currentOrder.order.merged_from_table_number || '-' }}</div>
            </div>
          </div>
        </div>

        <div v-if="splitPayments.length" class="rounded-xl border border-slate-200 bg-white overflow-hidden">
          <div class="flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between px-3 py-2 bg-slate-50 border-b border-slate-200">
            <div class="text-sm font-semibold text-slate-700">Histori Split Bill ({{ splitPayments.length }})</div>
            <div class="text-xs text-slate-500">Pembayaran parsial</div>
          </div>
          <div class="divide-y divide-slate-100">
            <div
              v-for="payment in splitPayments"
              :key="payment.id"
              class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between px-3 py-2"
            >
              <div>
                <div class="text-sm font-semibold text-slate-900">{{ getPaymentMethodText(payment.payment_method) }}</div>
                <div class="text-xs text-slate-500">{{ formatDateTime(payment.created_at) }}</div>
              </div>
              <div class="text-left sm:text-right">
                <div class="text-sm font-bold text-slate-900">{{ formatCurrency(payment.amount) }}</div>
                <div v-if="getPaymentNote(payment.payment_note)" class="text-xs text-slate-500">{{ getPaymentNote(payment.payment_note) }}</div>
              </div>
            </div>
          </div>
        </div>

        <div class="bg-white pt-2">
          <div
            v-if="splitPayments.length"
            class="flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 mb-4"
          >
            <div class="text-sm font-semibold text-slate-600">Sisa Tagihan</div>
            <div class="text-sm font-bold text-red-600">{{ formatCurrency(getRemainingAmount(currentOrder.order)) }}</div>
          </div>

          <div v-if="manualAdjustments.length" class="rounded-xl border border-slate-200 bg-white overflow-hidden mb-4">
            <div class="flex items-center justify-between px-3 py-2 bg-slate-50 border-b border-slate-200">
              <div class="text-sm font-semibold text-slate-700">Penyesuaian</div>
              <div class="text-xs text-slate-500">Diskon & Kompliment</div>
            </div>
            <div class="divide-y divide-slate-100">
              <div
                v-for="(adjustment, index) in manualAdjustments"
                :key="`${adjustment.name}-${index}`"
                class="flex items-center justify-between px-3 py-2"
              >
                <div class="text-sm text-slate-700">{{ adjustment.name }}</div>
                <div
                  class="text-sm font-semibold"
                  :class="adjustment.applied_amount < 0 ? 'text-rose-600' : 'text-emerald-600'"
                >
                  {{ formatCurrency(adjustment.applied_amount) }}
                </div>
              </div>
            </div>
          </div>

          <!-- Total -->
          <div class="border-t border-slate-200 pt-4">
            <div class="flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between mb-4">
              <div class="text-lg font-semibold text-slate-900">Total Tagihan</div>
              <div class="text-2xl font-bold text-emerald-600">{{ formatCurrency(getRemainingAmount(currentOrder.order)) }}</div>
            </div>

            <!-- Payment Method Selection -->
            <div class="mb-4">
              <label class="block text-sm font-semibold text-slate-600 mb-2">Metode Pembayaran</label>
              <div class="grid grid-cols-2 sm:grid-cols-4 gap-2">
                <button
                  v-for="method in paymentMethods"
                  :key="method.value"
                  @click="selectedPaymentMethod = method.value"
                  :class="getPaymentMethodButtonClass(method.value, selectedPaymentMethod === method.value)"
                >
                  {{ method.label }}
                </button>
              </div>
            </div>

            <div class="mb-4">
              <label class="block text-sm font-semibold text-slate-600 mb-2">Jumlah Bayar</label>
              <div class="flex flex-col sm:flex-row gap-2">
                <input
                  :value="fullPaidAmountDisplay"
                  @input="handleFullPaidAmountInput"
                  type="text"
                  inputmode="numeric"
                  placeholder="Rp 0"
                  class="flex-1 px-4 py-3 rounded-xl border-2 border-slate-200 focus:border-emerald-500 focus:outline-none"
                />
                <button
                  type="button"
                  @click="setFullExactAmount"
                  class="px-4 py-3 rounded-xl border border-slate-200 text-slate-600 font-semibold hover:bg-slate-50 transition-all"
                >
                  Uang Pas
                </button>
              </div>
              <div class="flex items-center justify-between text-sm text-slate-600 mt-2">
                <span>Kembalian</span>
                <span class="font-semibold text-emerald-600">{{ formatCurrency(fullChangeAmount) }}</span>
              </div>
            </div>

            <!-- Action Buttons -->
            <div class="grid grid-cols-3 gap-2">
              <button
                @click="printBill"
                :disabled="printingBill"
                class="flex items-center justify-center gap-2 px-3 py-3 rounded-xl bg-slate-700 text-white text-sm font-semibold hover:bg-slate-800 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M7 8V4h10v4" />
                  <rect x="6" y="12" width="12" height="8" rx="2" />
                  <path d="M6 10h12" />
                </svg>
                <span>{{ printingBill ? 'Mencetak...' : 'Cetak Bill' }}</span>
              </button>
              <button
                @click="openDiscountModal"
                :disabled="discountSubmitting || complimentSubmitting || getRemainingAmount(currentOrder.order) <= 0"
                class="flex items-center justify-center gap-2 px-3 py-3 rounded-xl border border-emerald-200 text-emerald-700 text-sm font-semibold hover:bg-emerald-50 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <circle cx="8.5" cy="8.5" r="2.5" />
                  <circle cx="15.5" cy="15.5" r="2.5" />
                  <path d="M5 19L19 5" />
                </svg>
                <span>Diskon</span>
              </button>
              <button
                @click="submitCompliment"
                :disabled="discountSubmitting || complimentSubmitting || getRemainingAmount(currentOrder.order) <= 0"
                class="flex items-center justify-center gap-2 px-3 py-3 rounded-xl border border-amber-200 text-amber-600 text-sm font-semibold hover:bg-amber-50 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M7 12h7l3.5-3.5a2.1 2.1 0 0 1 3 3L16 16H7a3 3 0 0 1 0-6z" />
                  <path d="M3 12h4v6H3z" />
                </svg>
                <span>{{ complimentSubmitting ? 'Memproses...' : 'Kompliment' }}</span>
              </button>
              <button
                @click="openSplitPaymentModal"
                class="flex items-center justify-center gap-2 px-3 py-3 rounded-xl bg-amber-500 text-white text-sm font-semibold hover:bg-amber-600 transition-all"
              >
                <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M6 7h6a4 4 0 1 1 0 8h-2" />
                  <path d="M10 15l-3 3-3-3" />
                  <path d="M18 9l3-3-3-3" />
                </svg>
                <span>Split Bill</span>
              </button>
              <button
                @click="openVoidModal"
                class="flex items-center justify-center gap-2 px-3 py-3 rounded-xl border border-red-200 text-red-600 text-sm font-semibold hover:bg-red-50 transition-all"
              >
                <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <circle cx="12" cy="12" r="9" />
                  <path d="M8.5 8.5l7 7M15.5 8.5l-7 7" />
                </svg>
                <span>Void Order</span>
              </button>
              <button
                @click="processPayment(currentOrder.order.id, getRemainingAmount(currentOrder.order))"
                :disabled="processingPayment || !selectedPaymentMethod"
                class="flex items-center justify-center gap-2 px-4 py-3 rounded-xl bg-gradient-to-r from-emerald-600 to-emerald-500 text-white text-sm font-semibold hover:shadow-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <rect x="3" y="6" width="18" height="12" rx="2" />
                  <path d="M3 10h18" />
                  <path d="M9 14l2 2 4-4" />
                </svg>
                <span>{{ processingPayment ? 'Memproses...' : 'Bayar Penuh' }}</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </el-dialog>

    <el-dialog
      v-model="showDiscountModal"
      title="Diskon Order"
      width="90%"
      style="max-width: 420px;"
      :close-on-click-modal="false"
    >
      <div class="flex flex-col gap-4">
        <div>
          <label class="block text-sm font-semibold text-slate-600 mb-2">Tipe Diskon</label>
          <div class="grid grid-cols-2 gap-2">
            <button
              type="button"
              @click="discountType = 'percentage'"
              :class="discountType === 'percentage' ? 'border-emerald-500 bg-emerald-50 text-emerald-700' : 'border-slate-200 text-slate-600'"
              class="px-4 py-2.5 rounded-xl border text-sm font-semibold transition-all"
            >
              Persentase
            </button>
            <button
              type="button"
              @click="discountType = 'fixed'"
              :class="discountType === 'fixed' ? 'border-emerald-500 bg-emerald-50 text-emerald-700' : 'border-slate-200 text-slate-600'"
              class="px-4 py-2.5 rounded-xl border text-sm font-semibold transition-all"
            >
              Nominal
            </button>
          </div>
        </div>
        <div>
          <label class="block text-sm font-semibold text-slate-600 mb-2">Nilai Diskon</label>
          <div class="relative">
            <input
              :value="discountValueDisplay"
              @input="handleDiscountValueInput"
              type="text"
              inputmode="numeric"
              :placeholder="discountType === 'percentage' ? '0-100' : 'Rp 0'"
              class="w-full px-4 py-3 rounded-xl border-2 border-slate-200 focus:border-emerald-500 focus:outline-none"
            />
            <span v-if="discountType === 'percentage'" class="absolute right-4 top-1/2 -translate-y-1/2 text-slate-500 text-sm font-semibold">%</span>
          </div>
          <div v-if="discountType === 'percentage'" class="text-xs text-slate-500 mt-2">Maksimal 100%</div>
        </div>
        <div class="flex flex-col sm:flex-row gap-2">
          <button
            type="button"
            @click="closeDiscountModal"
            class="flex-1 px-4 py-3 rounded-xl border border-slate-200 text-slate-600 font-semibold hover:bg-slate-50 transition-all"
          >
            Batal
          </button>
          <button
            type="button"
            @click="submitDiscount"
            :disabled="discountSubmitting"
            class="flex-1 px-4 py-3 rounded-xl bg-emerald-600 text-white font-semibold hover:bg-emerald-700 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ discountSubmitting ? 'Menyimpan...' : 'Simpan Diskon' }}
          </button>
        </div>
      </div>
    </el-dialog>

    <el-dialog
      v-model="showItemsModal"
      title="Item Pesanan"
      width="90%"
      style="max-width: 560px;"
      :close-on-click-modal="false"
    >
      <div v-if="loadingItemsModal" class="flex justify-center items-center py-12">
        <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-emerald-600"></div>
      </div>

      <div v-else class="max-h-[70vh] overflow-y-auto">
        <div class="bg-slate-50 rounded-xl p-4 mb-4">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
            <div>
              <div class="text-slate-500">Meja</div>
              <div class="font-bold text-slate-900">{{ itemsModalOrder?.table_number || '-' }}</div>
            </div>
            <div>
              <div class="text-slate-500">Waiter</div>
              <div class="font-bold text-slate-900">{{ itemsModalOrder?.waiter_name || '-' }}</div>
            </div>
            <div>
              <div class="text-slate-500">Basket</div>
              <div class="font-bold text-slate-900">{{ itemsModalOrder?.basket_size || itemsModalItems.length }}</div>
            </div>
            <div>
              <div class="text-slate-500">Total</div>
              <div class="font-bold text-emerald-600">{{ formatCurrency(itemsModalOrder?.total_amount || 0) }}</div>
            </div>
          </div>
        </div>

        <div>
          <div class="rounded-xl border border-slate-200 bg-white overflow-hidden">
            <div class="flex items-center justify-between px-3 py-2 bg-slate-50 border-b border-slate-200">
              <div class="text-sm font-semibold text-slate-700">Daftar Item ({{ itemsModalItems.length }})</div>
              <div class="text-xs text-slate-500">Scroll untuk lihat semua</div>
            </div>
            <div class="divide-y divide-slate-100">
              <div
                v-for="item in itemsModalItems"
                :key="item.id"
                class="flex items-center justify-between px-3 py-2 gap-3"
              >
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2">
                    <div class="font-medium text-slate-900 truncate">{{ item.product_name }}</div>
                    <span :class="itemStatusClass(item.item_status)" class="inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-semibold uppercase">
                      {{ getItemStatusText(item.item_status) }}
                    </span>
                  </div>
                  <div class="text-xs text-slate-500">{{ item.qty }} x {{ formatCurrency(item.price) }}</div>
                </div>
                <div class="flex items-center gap-3">
                  <div class="text-right font-bold text-slate-900 w-24">
                    {{ formatCurrency(item.qty * item.price) }}
                  </div>
                  <div class="flex items-center gap-1">
                    <button
                      type="button"
                      class="h-8 w-8 rounded-lg border border-slate-200 text-slate-600 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed"
                      :disabled="!canEditItem(item) || isItemUpdating(item.id)"
                      @click="adjustItemQty(item, -1)"
                    >
                      -
                    </button>
                    <div class="min-w-[28px] text-center text-sm font-semibold text-slate-700">
                      {{ item.qty }}
                    </div>
                    <button
                      type="button"
                      class="h-8 w-8 rounded-lg border border-slate-200 text-slate-600 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed"
                      :disabled="!canEditItem(item) || isItemUpdating(item.id)"
                      @click="adjustItemQty(item, 1)"
                    >
                      +
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </el-dialog>

    <el-dialog
      v-model="showOpenShiftModal"
      title="Buka Shift Kasir"
      width="90%"
      style="max-width: 420px;"
      :close-on-click-modal="false"
    >
      <div class="flex flex-col gap-4">
        <div class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
          <div class="flex items-center justify-between">
            <div class="text-sm text-slate-500">Modal Tersedia</div>
            <div class="text-sm font-semibold text-slate-700">{{ formatCurrency(lastClosedShift?.carry_over_cash || 0) }}</div>
          </div>
        </div>
        <div>
          <label class="block text-sm font-semibold text-slate-600 mb-2">Uang Modal</label>
          <input
            :value="openingCashDisplay"
            @input="handleOpeningCashInput"
            type="text"
            inputmode="numeric"
            class="w-full px-4 py-3 rounded-xl border-2 border-slate-200 focus:border-emerald-500 focus:outline-none"
            placeholder="Masukkan uang modal"
          />
          <div class="text-xs text-slate-500 mt-2">Kosongkan untuk memakai modal terakhir</div>
        </div>
        <div class="flex flex-col sm:flex-row gap-2">
          <button
            @click="showOpenShiftModal = false"
            class="flex-1 px-4 py-3 rounded-xl border border-slate-200 text-slate-600 font-semibold hover:bg-slate-50 transition-all"
          >
            Batal
          </button>
          <button
            @click="submitOpenShift"
            :disabled="shiftLoading"
            class="flex-1 px-4 py-3 rounded-xl bg-emerald-600 text-white font-semibold hover:bg-emerald-700 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ shiftLoading ? 'Memproses...' : 'Buka Shift' }}
          </button>
        </div>
      </div>
    </el-dialog>

    <el-dialog
      v-model="showCloseShiftModal"
      title="Tutup Shift Kasir"
      width="90%"
      style="max-width: 420px;"
      :close-on-click-modal="false"
    >
      <div class="flex flex-col gap-4">
        <div class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
          <div class="flex items-center justify-between">
            <div class="text-sm text-slate-500">Modal Awal</div>
            <div class="text-sm font-semibold text-slate-700">{{ formatCurrency(currentShift?.opening_cash || 0) }}</div>
          </div>
        </div>
        <div class="grid gap-3 sm:grid-cols-2">
          <div class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
            <div class="text-xs text-slate-500">Cash</div>
            <div class="text-sm font-semibold text-slate-700">{{ formatCurrency(shiftSalesSummary.cash || 0) }}</div>
          </div>
          <div class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
            <div class="text-xs text-slate-500">Kartu</div>
            <div class="text-sm font-semibold text-slate-700">{{ formatCurrency(shiftSalesSummary.card || 0) }}</div>
          </div>
          <div class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
            <div class="text-xs text-slate-500">QRIS</div>
            <div class="text-sm font-semibold text-slate-700">{{ formatCurrency(shiftSalesSummary.qris || 0) }}</div>
          </div>
          <div class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
            <div class="text-xs text-slate-500">Transfer</div>
            <div class="text-sm font-semibold text-slate-700">{{ formatCurrency(shiftSalesSummary.transfer || 0) }}</div>
          </div>
            <div class="rounded-xl border border-rose-100 bg-rose-50 px-3 py-2">
              <div class="text-xs text-rose-600">Void</div>
              <div class="text-sm font-semibold text-rose-700">-{{ formatCurrency(shiftVoidSummary.total || 0) }}</div>
            </div>
            <div class="rounded-xl border border-rose-100 bg-rose-50 px-3 py-2">
              <div class="text-xs text-rose-600">Batal</div>
              <div class="text-sm font-semibold text-rose-700">-{{ formatCurrency(shiftCancelledSummary.total || 0) }}</div>
            </div>
          <div class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
            <div class="text-xs text-slate-500">Uang Masuk</div>
            <div class="text-sm font-semibold text-slate-700">{{ formatCurrency(closeShiftCashInTotal) }}</div>
          </div>
          <div class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
            <div class="text-xs text-slate-500">Uang Keluar</div>
            <div class="text-sm font-semibold text-slate-700">{{ formatCurrency(closeShiftCashOutTotal) }}</div>
          </div>
        </div>
        <div class="rounded-xl border border-emerald-200 bg-emerald-50 px-3 py-2">
          <div class="text-xs text-emerald-700">Total</div>
          <div class="text-base font-bold text-emerald-900">{{ formatCurrency(closeShiftGrandTotal) }}</div>
        </div>
        <div class="flex flex-col sm:flex-row gap-2">
          <button
            @click="showCloseShiftModal = false"
            class="flex-1 px-4 py-3 rounded-xl border border-slate-200 text-slate-600 font-semibold hover:bg-slate-50 transition-all"
          >
            Batal
          </button>
          <button
            @click="submitCloseShift"
            :disabled="shiftLoading"
            class="flex-1 px-4 py-3 rounded-xl bg-rose-600 text-white font-semibold hover:bg-rose-700 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ shiftLoading ? 'Memproses...' : 'Tutup Shift' }}
          </button>
        </div>
      </div>
    </el-dialog>

    <el-dialog
      v-model="showHandoverShiftModal"
      title="Serah Terima Shift Kasir"
      width="90%"
      style="max-width: 460px;"
      :close-on-click-modal="false"
    >
      <div class="flex flex-col gap-4">
        <div class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
          <div class="flex items-center justify-between">
            <div class="text-sm text-slate-500">Kasir Saat Ini</div>
            <div class="text-sm font-semibold text-slate-700">{{ currentUserName }}</div>
          </div>
          <div class="flex items-center justify-between mt-2">
            <div class="text-sm text-slate-500">Modal Awal</div>
            <div class="text-sm font-semibold text-slate-700">{{ formatCurrency(currentShift?.opening_cash || 0) }}</div>
          </div>
        </div>
        <div>
          <label class="block text-sm font-semibold text-slate-600 mb-2">Kasir Tujuan</label>
          <div v-if="cashierUsersLoading" class="text-xs text-slate-500">Memuat daftar kasir...</div>
          <el-select
            v-else
            v-model="selectedHandoverCashier"
            filterable
            clearable
            placeholder="Pilih kasir"
            class="w-full"
          >
            <el-option
              v-for="user in cashierOptions"
              :key="user.id"
              :label="user.label"
              :value="user.id"
            />
          </el-select>
          <div v-if="!cashierUsersLoading && handoverCandidates.length === 0" class="text-xs text-slate-500 mt-2">
            Tidak ada kasir lain yang aktif
          </div>
        </div>
        <div>
          <label class="block text-sm font-semibold text-slate-600 mb-2">Ringkasan Penjualan Terbayar</label>
          <div class="grid gap-3 sm:grid-cols-2">
            <div class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
              <div class="text-xs text-slate-500">Cash</div>
              <div class="text-sm font-semibold text-slate-700">{{ formatCurrency(shiftSalesSummary.cash || 0) }}</div>
            </div>
            <div class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
              <div class="text-xs text-slate-500">Kartu</div>
              <div class="text-sm font-semibold text-slate-700">{{ formatCurrency(shiftSalesSummary.card || 0) }}</div>
            </div>
            <div class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
              <div class="text-xs text-slate-500">QRIS</div>
              <div class="text-sm font-semibold text-slate-700">{{ formatCurrency(shiftSalesSummary.qris || 0) }}</div>
            </div>
            <div class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
              <div class="text-xs text-slate-500">Transfer</div>
              <div class="text-sm font-semibold text-slate-700">{{ formatCurrency(shiftSalesSummary.transfer || 0) }}</div>
            </div>
            <div class="rounded-xl border border-rose-100 bg-rose-50 px-3 py-2">
              <div class="text-xs text-rose-600">Void</div>
              <div class="text-sm font-semibold text-rose-700">-{{ formatCurrency(shiftVoidSummary.total || 0) }}</div>
            </div>
            <div class="rounded-xl border border-rose-100 bg-rose-50 px-3 py-2">
              <div class="text-xs text-rose-600">Batal</div>
              <div class="text-sm font-semibold text-rose-700">-{{ formatCurrency(shiftCancelledSummary.total || 0) }}</div>
            </div>
          </div>
        </div>
        <div>
          <label class="block text-sm font-semibold text-slate-600 mb-2">Ringkasan Uang Masuk/Keluar</label>
          <div class="grid gap-3 sm:grid-cols-2">
            <div class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
              <div class="text-xs text-slate-500">Uang Masuk</div>
              <div class="text-sm font-semibold text-slate-700">{{ formatCurrency(closeShiftCashInTotal) }}</div>
            </div>
            <div class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
              <div class="text-xs text-slate-500">Uang Keluar</div>
              <div class="text-sm font-semibold text-slate-700">{{ formatCurrency(closeShiftCashOutTotal) }}</div>
            </div>
          </div>
          <div class="rounded-xl border border-emerald-200 bg-emerald-50 px-3 py-2 mt-3">
            <div class="text-xs text-emerald-700">Total</div>
            <div class="text-base font-bold text-emerald-900">{{ formatCurrency(closeShiftGrandTotal) }}</div>
          </div>
        </div>
        <div class="flex flex-col sm:flex-row gap-2">
          <button
            @click="showHandoverShiftModal = false"
            class="flex-1 px-4 py-3 rounded-xl border border-slate-200 text-slate-600 font-semibold hover:bg-slate-50 transition-all"
          >
            Batal
          </button>
          <button
            @click="openHandoverPinModal"
            :disabled="shiftLoading || cashierUsersLoading || !selectedHandoverCashier"
            class="flex-1 px-4 py-3 rounded-xl bg-amber-500 text-white font-semibold hover:bg-amber-600 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ shiftLoading ? 'Memproses...' : 'Serah Terima' }}
          </button>
        </div>
      </div>
    </el-dialog>

    <el-dialog
      v-model="showHandoverPinModal"
      title="Konfirmasi PIN Serah Terima"
      width="90%"
      style="max-width: 420px;"
      :close-on-click-modal="false"
    >
      <div class="flex flex-col gap-4">
        <div class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
          <div class="flex items-center justify-between">
            <div class="text-sm text-slate-500">Kasir Saat Ini</div>
            <div class="text-sm font-semibold text-slate-700">{{ currentUserName }}</div>
          </div>
          <div class="flex items-center justify-between mt-2">
            <div class="text-sm text-slate-500">Kasir Tujuan</div>
            <div class="text-sm font-semibold text-slate-700">{{ selectedHandoverCashierName }}</div>
          </div>
        </div>
        <div>
          <label class="block text-sm font-semibold text-slate-600 mb-2">PIN Kasir Saat Ini</label>
          <input
            v-model="handoverCurrentPin"
            type="password"
            inputmode="numeric"
            pattern="[0-9]{4}"
            maxlength="4"
            minlength="4"
            @input="handleHandoverCurrentPinInput"
            class="w-full px-4 py-3 rounded-xl border-2 border-slate-200 focus:border-amber-500 focus:outline-none"
            placeholder="Masukkan PIN 4 digit"
          />
        </div>
        <div>
          <label class="block text-sm font-semibold text-slate-600 mb-2">PIN Kasir Tujuan</label>
          <input
            v-model="handoverNextPin"
            type="password"
            inputmode="numeric"
            pattern="[0-9]{4}"
            maxlength="4"
            minlength="4"
            @input="handleHandoverNextPinInput"
            class="w-full px-4 py-3 rounded-xl border-2 border-slate-200 focus:border-amber-500 focus:outline-none"
            placeholder="Masukkan PIN 4 digit"
          />
        </div>
        <div class="flex flex-col sm:flex-row gap-2">
          <button
            @click="closeHandoverPinModal"
            class="flex-1 px-4 py-3 rounded-xl border border-slate-200 text-slate-600 font-semibold hover:bg-slate-50 transition-all"
          >
            Batal
          </button>
          <button
            @click="submitHandoverShift"
            :disabled="shiftLoading || handoverCurrentPin.length !== 4 || handoverNextPin.length !== 4"
            class="flex-1 px-4 py-3 rounded-xl bg-amber-500 text-white font-semibold hover:bg-amber-600 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ shiftLoading ? 'Memproses...' : 'Konfirmasi' }}
          </button>
        </div>
      </div>
    </el-dialog>

    <el-dialog
      v-model="showCashMovementModal"
      :title="cashMovementType === 'in' ? 'Tambah Uang Masuk' : 'Tambah Uang Keluar'"
      width="90%"
      style="max-width: 420px;"
      :close-on-click-modal="false"
    >
      <div class="flex flex-col gap-4">
        <div class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
          <div class="flex items-center justify-between">
            <div class="text-sm text-slate-500">Shift Aktif</div>
            <div class="text-sm font-semibold text-slate-700">{{ currentShift?.opened_by_name || 'Kasir' }}</div>
          </div>
        </div>
        <div>
          <label class="block text-sm font-semibold text-slate-600 mb-2">
            {{ cashMovementType === 'in' ? 'Sumber Uang' : 'Penerima Uang' }}
          </label>
          <input
            v-model="cashMovementName"
            type="text"
            class="w-full px-4 py-3 rounded-xl border-2 border-slate-200 focus:border-emerald-500 focus:outline-none"
            placeholder="Masukkan nama"
          />
        </div>
        <div v-if="cashMovementType === 'out'">
          <label class="block text-sm font-semibold text-slate-600 mb-2">Keterangan</label>
          <input
            v-model="cashMovementNote"
            type="text"
            class="w-full px-4 py-3 rounded-xl border-2 border-slate-200 focus:border-emerald-500 focus:outline-none"
            placeholder="Masukkan keterangan"
          />
        </div>
        <div>
          <label class="block text-sm font-semibold text-slate-600 mb-2">Nominal</label>
          <input
            :value="cashMovementAmountDisplay"
            @input="handleCashMovementAmountInput"
            type="text"
            inputmode="numeric"
            class="w-full px-4 py-3 rounded-xl border-2 border-slate-200 focus:border-emerald-500 focus:outline-none"
            placeholder="Rp 0"
          />
        </div>
        <div class="flex flex-col sm:flex-row gap-2">
          <button
            @click="closeCashMovementModal"
            class="flex-1 px-4 py-3 rounded-xl border border-slate-200 text-slate-600 font-semibold hover:bg-slate-50 transition-all"
          >
            Batal
          </button>
          <button
            @click="submitCashMovement"
            :disabled="cashMovementSubmitting"
            class="flex-1 px-4 py-3 rounded-xl bg-emerald-600 text-white font-semibold hover:bg-emerald-700 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ cashMovementSubmitting ? 'Menyimpan...' : 'Simpan' }}
          </button>
        </div>
      </div>
    </el-dialog>

    <el-dialog
      v-model="showCashMovementHistoryModal"
      :title="cashMovementHistoryType === 'in' ? 'Riwayat Uang Masuk' : 'Riwayat Uang Keluar'"
      width="90%"
      style="max-width: 420px;"
      :close-on-click-modal="false"
    >
      <div class="flex flex-col gap-4">
        <div class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
          <div class="flex items-center justify-between">
            <div class="text-sm text-slate-500">
              {{ cashMovementHistorySource === 'last' ? 'Shift Terakhir' : 'Shift Aktif' }}
            </div>
            <div class="text-sm font-semibold text-slate-700">
              {{ cashMovementHistoryType === 'in' ? 'Uang Masuk' : 'Uang Keluar' }}
            </div>
          </div>
          <div class="mt-2 text-base font-semibold text-slate-900">
            {{ formatCurrency(cashMovementHistoryTotal) }}
          </div>
        </div>
        <div class="rounded-xl border border-slate-200 bg-white max-h-60 overflow-y-auto">
          <div v-if="cashMovementHistoryItems.length === 0" class="p-4 text-sm text-slate-500 text-center">
            Belum ada riwayat
          </div>
          <div v-else class="divide-y divide-slate-100">
            <div
              v-for="item in cashMovementHistoryItems"
              :key="item.id"
              class="flex items-center justify-between px-4 py-3 text-sm text-slate-700"
            >
              <span class="truncate max-w-[180px]">{{ item.name }}</span>
              <span class="font-semibold text-slate-900">{{ formatCurrency(item.amount) }}</span>
            </div>
          </div>
        </div>
        <button
          @click="closeCashMovementHistoryModal"
          class="px-4 py-3 rounded-xl border border-slate-200 text-slate-600 font-semibold hover:bg-slate-50 transition-all"
        >
          Tutup
        </button>
      </div>
    </el-dialog>

    <!-- Split Payment Modal -->
    <el-dialog
      v-model="showSplitPaymentModal"
      title="Split Bill"
      width="90%"
      style="max-width: 500px;"
      :close-on-click-modal="false"
    >
      <div v-if="currentOrder">
        <div class="bg-slate-50 rounded-xl p-4 mb-4">
          <div class="flex items-center justify-between mb-2">
            <div class="text-sm text-slate-500">Total Tagihan</div>
            <div class="text-lg font-bold text-slate-900">{{ formatCurrency(getRemainingAmount(currentOrder.order)) }}</div>
          </div>
          <div class="flex items-center justify-between mb-2">
            <div class="text-sm text-slate-500">Total Split</div>
            <div class="text-lg font-bold text-emerald-600">{{ formatCurrency(splitItemsTotal) }}</div>
          </div>
          <div class="flex items-center justify-between">
            <div class="text-sm text-slate-500">Sisa Belum Dibayar</div>
            <div class="text-lg font-bold text-red-600">{{ formatCurrency(getRemainingAmount(currentOrder.order)) }}</div>
          </div>
        </div>

        <div class="mb-4">
          <label class="block text-sm font-semibold text-slate-600 mb-2">Pilih Item dan Jumlah</label>
          <div class="rounded-xl border border-slate-200 bg-white divide-y divide-slate-100 max-h-64 overflow-y-auto">
            <div
              v-for="item in orderItems"
              :key="item.id"
              class="flex items-center justify-between px-3 py-2 gap-3"
            >
              <div class="flex-1 min-w-0">
                <div class="font-medium text-slate-900 truncate">{{ item.product_name }}</div>
                <div class="text-xs text-slate-500">{{ item.qty }} x {{ formatCurrency(item.price) }}</div>
              </div>
              <div class="flex items-center gap-1">
                <button
                  type="button"
                  class="h-8 w-8 rounded-lg border border-slate-200 text-slate-600 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed"
                  :disabled="item.qty <= 0 || getSplitItemQty(item.id) === 0"
                  @click="adjustSplitItemQty(item, -1)"
                >
                  -
                </button>
                <input
                  :value="getSplitItemQty(item.id)"
                  @input="handleSplitItemQtyInput(item, $event)"
                  type="number"
                  min="0"
                  :max="item.qty"
                  :disabled="item.qty <= 0"
                  class="w-16 px-2 py-2 rounded-lg border border-slate-200 text-center text-sm font-semibold text-slate-700 focus:border-emerald-500 focus:outline-none disabled:opacity-40 disabled:cursor-not-allowed"
                />
                <button
                  type="button"
                  class="h-8 w-8 rounded-lg border border-slate-200 text-slate-600 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed"
                  :disabled="item.qty <= 0 || getSplitItemQty(item.id) >= item.qty"
                  @click="adjustSplitItemQty(item, 1)"
                >
                  +
                </button>
              </div>
            </div>
          </div>
          <div v-if="splitTotalExceedsRemaining" class="text-xs text-red-600 mt-2">
            Total split melebihi sisa tagihan
          </div>
        </div>

        <div class="mb-4">
          <label class="block text-sm font-semibold text-slate-600 mb-2">Metode Pembayaran</label>
          <div class="grid grid-cols-2 gap-2">
            <button
              v-for="method in paymentMethods"
              :key="method.value"
              @click="selectedSplitPaymentMethod = method.value"
              :class="getPaymentMethodButtonClass(method.value, selectedSplitPaymentMethod === method.value)"
            >
              {{ method.label }}
            </button>
          </div>
        </div>

        <div class="mb-4">
          <label class="block text-sm font-semibold text-slate-600 mb-2">Jumlah Bayar</label>
          <div class="flex flex-col sm:flex-row gap-2">
            <input
              :value="splitPaidAmountDisplay"
              @input="handleSplitPaidAmountInput"
              type="text"
              inputmode="numeric"
              placeholder="Rp 0"
              class="flex-1 px-4 py-3 rounded-xl border-2 border-slate-200 focus:border-emerald-500 focus:outline-none"
            />
            <button
              type="button"
              @click="setSplitExactAmount"
              class="px-4 py-3 rounded-xl border border-slate-200 text-slate-600 font-semibold hover:bg-slate-50 transition-all"
            >
              Uang Pas
            </button>
          </div>
          <div class="flex items-center justify-between text-sm text-slate-600 mt-2">
            <span>Kembalian</span>
            <span class="font-semibold text-emerald-600">{{ formatCurrency(splitChangeAmount) }}</span>
          </div>
        </div>

        <div class="mb-4">
          <label class="block text-sm font-semibold text-slate-600 mb-2">Catatan (Opsional)</label>
          <textarea
            v-model="splitNote"
            class="w-full px-4 py-3 rounded-xl border-2 border-slate-200 focus:border-emerald-500 focus:outline-none"
            rows="2"
            placeholder="Catatan pembayaran..."
          ></textarea>
        </div>

        <button
          @click="processSplitPayment"
          :disabled="processingPayment || !selectedSplitPaymentMethod || splitItemsTotal <= 0 || splitTotalExceedsRemaining"
          class="w-full px-4 py-3 rounded-xl bg-gradient-to-r from-emerald-600 to-emerald-500 text-white font-semibold hover:shadow-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {{ processingPayment ? 'Memproses...' : 'Proses Pembayaran' }}
        </button>
      </div>
    </el-dialog>

    <el-dialog
      v-model="showVoidModal"
      title="Void Order"
      width="90%"
      style="max-width: 420px;"
      :close-on-click-modal="false"
    >
      <div v-if="currentOrder" class="flex flex-col gap-4">
        <div class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
          <div class="flex items-center justify-between">
            <div class="text-sm text-slate-500">Total Tagihan</div>
            <div class="text-lg font-bold text-slate-900">{{ formatCurrency(getOrderTotal(currentOrder.order)) }}</div>
          </div>
        </div>

        <div>
          <label class="block text-sm font-semibold text-slate-600 mb-2">PIN Manager</label>
          <input
            v-model="voidPin"
            type="text"
            inputmode="numeric"
            pattern="[0-9]{4}"
            maxlength="4"
            minlength="4"
            @input="handleVoidPinInput"
            class="w-full px-4 py-3 rounded-xl border-2 border-slate-200 focus:border-emerald-500 focus:outline-none"
            placeholder="Masukkan PIN 4 digit"
          />
        </div>

        <div>
          <label class="block text-sm font-semibold text-slate-600 mb-2">Alasan (Opsional)</label>
          <textarea
            v-model="voidReason"
            class="w-full px-4 py-3 rounded-xl border-2 border-slate-200 focus:border-emerald-500 focus:outline-none"
            rows="2"
            placeholder="Alasan void..."
          ></textarea>
        </div>

        <div class="flex flex-col sm:flex-row gap-2">
          <button
            @click="closeVoidModal"
            class="flex-1 px-4 py-3 rounded-xl border border-slate-200 text-slate-600 font-semibold hover:bg-slate-50 transition-all"
          >
            Batal
          </button>
          <button
            @click="submitVoidOrder"
            :disabled="voidProcessing || voidPin.length !== 4"
            class="flex-1 px-4 py-3 rounded-xl bg-red-600 text-white font-semibold hover:bg-red-700 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ voidProcessing ? 'Memproses...' : 'Void Order' }}
          </button>
        </div>
      </div>
    </el-dialog>

    <el-dialog
      v-model="showCancelTransactionModal"
      title="Batalkan Transaksi"
      width="90%"
      style="max-width: 420px;"
      :close-on-click-modal="false"
    >
      <div v-if="selectedTransaction" class="flex flex-col gap-4">
        <div class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
          <div class="flex items-center justify-between">
            <div class="text-sm text-slate-500">Total Transaksi</div>
            <div class="text-lg font-bold text-slate-900">{{ formatCurrency(selectedTransaction.total_amount) }}</div>
          </div>
        </div>

        <div>
          <label class="block text-sm font-semibold text-slate-600 mb-2">PIN Manager</label>
          <input
            v-model="cancelPin"
            type="text"
            inputmode="numeric"
            pattern="[0-9]{4}"
            maxlength="4"
            minlength="4"
            @input="handleCancelPinInput"
            class="w-full px-4 py-3 rounded-xl border-2 border-slate-200 focus:border-emerald-500 focus:outline-none"
            placeholder="Masukkan PIN 4 digit"
          />
        </div>

        <div>
          <label class="block text-sm font-semibold text-slate-600 mb-2">Alasan (Opsional)</label>
          <textarea
            v-model="cancelReason"
            class="w-full px-4 py-3 rounded-xl border-2 border-slate-200 focus:border-emerald-500 focus:outline-none"
            rows="2"
            placeholder="Alasan pembatalan..."
          ></textarea>
        </div>

        <div class="flex flex-col sm:flex-row gap-2">
          <button
            @click="closeCancelTransactionModal"
            class="flex-1 px-4 py-3 rounded-xl border border-slate-200 text-slate-600 font-semibold hover:bg-slate-50 transition-all"
          >
            Batal
          </button>
          <button
            @click="submitCancelTransaction"
            :disabled="cancelProcessing || cancelPin.length !== 4"
            class="flex-1 px-4 py-3 rounded-xl bg-red-600 text-white font-semibold hover:bg-red-700 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ cancelProcessing ? 'Memproses...' : 'Batalkan' }}
          </button>
        </div>
      </div>
    </el-dialog>

    <el-dialog
      v-model="showReceiptModal"
      title="Detail Struk"
      width="90%"
      style="max-width: 520px;"
      :close-on-click-modal="false"
    >
      <div v-if="receiptLoading" class="flex justify-center items-center py-12">
        <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-emerald-600"></div>
      </div>
      <div v-else-if="receiptOrder" class="space-y-4">
        <div class="flex justify-center">
          <div
            class="relative bg-white shadow-lg overflow-hidden border border-slate-200"
            :style="{ width: '302px' }"
          >
            <div class="absolute inset-0 opacity-5 pointer-events-none" style="background-image: repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(0,0,0,0.03) 2px, rgba(0,0,0,0.03) 4px);"></div>
            <div class="relative p-3 font-mono text-slate-900 text-[11px] leading-relaxed">
              <div class="text-center font-bold text-xs">
                {{ (outletConfig.outlet_name || 'Outlet').toUpperCase() }}
              </div>
              <div v-if="outletConfig.outlet_address" class="text-center text-slate-600 text-[10px]">
                {{ outletConfig.outlet_address }}
              </div>
              <div v-if="outletConfig.outlet_phone" class="text-center text-slate-600 text-[10px]">
                {{ outletConfig.outlet_phone }}
              </div>

              <div class="my-2 border-t border-dashed border-slate-400"></div>

              <div class="space-y-1">
                <div>No. Struk : TRX-{{ receiptOrder.order?.id || receiptTransaction?.order_id || receiptTransaction?.id }}</div>
                <div>Tanggal : {{ formatDateTime(receiptTransaction?.created_at || receiptOrder.order?.created_at) }}</div>
                <div v-if="receiptOrder.order?.table_number">Meja : #{{ receiptOrder.order.table_number }}</div>
                <div v-if="receiptOrder.order?.customer_name">Customer : {{ receiptOrder.order.customer_name }}</div>
                <div v-if="receiptOrder.order?.waiter_name">Waiter : {{ receiptOrder.order.waiter_name }}</div>
              </div>

              <div class="my-2 border-t border-dashed border-slate-400"></div>

              <div class="grid gap-1 font-semibold uppercase text-slate-600 text-[9px] grid-cols-[1fr,28px,60px,70px]">
                <span>ITEM</span>
                <span class="text-center">QTY</span>
                <span class="text-right">HARGA</span>
                <span class="text-right">TOTAL</span>
              </div>

              <div class="my-1 border-t border-dashed border-slate-400"></div>

              <div class="space-y-1">
                <div
                  v-for="item in receiptItems"
                  :key="item.id || item.product_id || item.product_name"
                  class="grid gap-1 grid-cols-[1fr,28px,60px,70px]"
                >
                  <span class="truncate">{{ item.product_name }}</span>
                  <span class="text-center">{{ item.qty }}</span>
                  <span class="text-right">{{ formatReceiptNumber(getReceiptItemPrice(item)) }}</span>
                  <span class="text-right">{{ formatReceiptNumber(getReceiptItemTotal(item)) }}</span>
                </div>
              </div>

              <div class="my-2 border-t border-dashed border-slate-400"></div>

              <div class="space-y-1">
                <div class="flex justify-between">
                  <span>Subtotal</span>
                  <span>{{ formatReceiptNumber(receiptSubtotal) }}</span>
                </div>
                <div v-if="receiptAdditionalCharges.length" class="space-y-1">
                  <div
                    v-for="charge in receiptAdditionalCharges"
                    :key="charge.name"
                    class="flex justify-between"
                  >
                    <span>{{ charge.name }}</span>
                    <span>{{ formatReceiptNumber(charge.amount) }}</span>
                  </div>
                </div>
                <div class="flex justify-between font-bold text-xs">
                  <span>TOTAL</span>
                  <span>{{ formatReceiptNumber(receiptTotal) }}</span>
                </div>
              </div>

              <div class="my-2 border-t border-dashed border-slate-400"></div>

              <div class="space-y-1">
                <div class="flex justify-between">
                  <span>Bayar</span>
                  <span>{{ formatReceiptNumber(receiptPaidAmount) }}</span>
                </div>
                <div class="flex justify-between">
                  <span>Kembalian</span>
                  <span>{{ formatReceiptNumber(receiptChangeAmount) }}</span>
                </div>
              </div>

              <div class="my-2 border-t border-dashed border-slate-400"></div>

              <div v-if="outletConfig.receipt_footer" class="text-center text-slate-600">
                {{ outletConfig.receipt_footer }}
              </div>
              <div v-if="outletConfig.social_media" class="text-center text-slate-600">
                {{ outletConfig.social_media }}
              </div>
            </div>
          </div>
        </div>
        <div v-if="receiptTransaction?.status === 'cancelled'" class="rounded-xl border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-700">
          Transaksi dibatalkan. Cetak ulang struk dinonaktifkan.
        </div>
        <div class="flex flex-col sm:flex-row gap-2">
          <button
            @click="closeReceiptModal"
            class="flex-1 px-4 py-3 rounded-xl border border-slate-200 text-slate-600 font-semibold hover:bg-slate-50 transition-all"
          >
            Tutup
          </button>
          <button
            @click="handleReprintReceipt"
            :disabled="receiptPrinting || receiptTransaction?.status === 'cancelled'"
            class="flex-1 px-4 py-3 rounded-xl bg-emerald-600 text-white font-semibold hover:bg-emerald-700 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ receiptPrinting ? 'Mencetak...' : 'Cetak Ulang' }}
          </button>
        </div>
      </div>
    </el-dialog>
  </div>
</template>

<script setup>
import DataTable from '../components/DataTable.vue'
import Pagination from '../components/Pagination.vue'
import { useCashierView } from '../composables/useCashierView'

const {
  loading,
  loadingHistory,
  loadingVoidedHistory,
  loadingOrderDetail,
  processingPayment,
  printingBill,
  activeTab,
  allTables,
  transactions,
  voidedOrders,
  currentOrder,
  todayRevenue,
  todayTransactions,
  tableSearchQuery,
  historyStartDate,
  historyEndDate,
  transactionPagination,
  voidPagination,
  shiftState,
  shiftLoading,
  cashierUsers,
  cashierUsersLoading,
  showOrderModal,
  showSplitPaymentModal,
  showVoidModal,
  showCancelTransactionModal,
  showReceiptModal,
  showItemsModal,
  loadingItemsModal,
  itemsModalOrder,
  itemsModalItems,
  itemUpdateLoading,
  showDiscountModal,
  discountType,
  discountValueDisplay,
  discountSubmitting,
  complimentSubmitting,
  showOpenShiftModal,
  showCloseShiftModal,
  showHandoverShiftModal,
  showHandoverPinModal,
  selectedPaymentMethod,
  selectedSplitPaymentMethod,
  splitNote,
  splitItemSelections,
  fullPaidAmount,
  fullPaidAmountDisplay,
  splitPaidAmount,
  splitPaidAmountDisplay,
  voidPin,
  voidReason,
  voidProcessing,
  selectedTransaction,
  cancelPin,
  cancelReason,
  cancelProcessing,
  receiptLoading,
  receiptPrinting,
  receiptTransaction,
  receiptOrder,
  outletConfig,
  openingCash,
  openingCashDisplay,
  selectedHandoverCashier,
  handoverCurrentPin,
  handoverNextPin,
  showCashMovementModal,
  cashMovementType,
  cashMovementName,
  cashMovementNote,
  cashMovementAmount,
  cashMovementAmountDisplay,
  cashMovementSubmitting,
  showCashMovementHistoryModal,
  cashMovementHistoryType,
  cashMovementHistorySource,
  paymentMethods,
  transactionColumns,
  voidColumns,
  avgTransaction,
  pendingTables,
  filteredPendingTables,
  orderItems,
  manualAdjustments,
  splitSelectedItems,
  splitItemsTotal,
  splitTotalExceedsRemaining,
  remainingAmount,
  fullChangeAmount,
  splitChangeAmount,
  splitPayments,
  receiptItems,
  receiptPayments,
  receiptAdditionalCharges,
  receiptSubtotal,
  receiptTotal,
  receiptPaidAmount,
  receiptChangeAmount,
  historyLoading,
  historyStartMax,
  historyEndMax,
  totalPaidAmount,
  totalVoidAmount,
  isShiftOpen,
  currentShift,
  lastClosedShift,
  shiftSalesSummary,
  shiftVoidSummary,
  shiftCancelledSummary,
  shiftNetSalesTotal,
  lastClosedCashMovements,
  currentCashMovements,
  closeShiftCashInTotal,
  closeShiftCashOutTotal,
  closeShiftGrandTotal,
  displayCashMovements,
  cashMovementHistoryData,
  cashMovementHistoryItems,
  cashMovementHistoryTotal,
  currentUserId,
  currentUserName,
  cashierOptions,
  handoverCandidates,
  selectedHandoverCashierName,
  showShiftClosedAlert,
  requireShiftOpen,
  formatCurrency,
  formatReceiptNumber,
  formatRupiahInput,
  parseRupiahInput,
  getReceiptItemPrice,
  getReceiptItemTotal,
  handleOpeningCashInput,
  resetCashMovementForm,
  openCashMovementModal,
  closeCashMovementModal,
  openCashMovementHistoryModal,
  closeCashMovementHistoryModal,
  handleCashMovementAmountInput,
  submitCashMovement,
  handleFullPaidAmountInput,
  setFullExactAmount,
  handleSplitPaidAmountInput,
  setSplitExactAmount,
  openDiscountModal,
  closeDiscountModal,
  handleDiscountValueInput,
  submitDiscount,
  submitCompliment,
  formatPinInput,
  formatTime,
  formatDateTime,
  formatDateInput,
  addMonths,
  getSplitItemQty,
  setSplitItemQty,
  adjustSplitItemQty,
  handleSplitItemQtyInput,
  openOpenShiftModal,
  openCloseShiftModal,
  openHandoverShiftModal,
  openHandoverPinModal,
  closeHandoverPinModal,
  getPaymentMethodClass,
  getPaymentMethodText,
  getTransactionStatusText,
  getTransactionStatusClass,
  getOrderStatusText,
  getOrderStatusClass,
  getPaymentStatusText,
  getPaymentStatusClass,
  getPaymentMethodButtonClass,
  getPaymentNote,
  getOrderTotal,
  getRemainingAmount,
  buildPaginationFallback,
  fetchOccupiedTables,
  fetchTodayStats,
  fetchShiftState,
  fetchCashierUsers,
  submitOpenShift,
  submitCloseShift,
  submitHandoverShift,
  fetchTransactions,
  fetchVoidedOrders,
  applyHistoryFilter,
  resetHistoryFilter,
  goToTransactionPage,
  goToVoidPage,
  viewOrder,
  getItemStatusText,
  itemStatusClass,
  canEditItem,
  isItemUpdating,
  fetchItemsModalData,
  openItemsModal,
  adjustItemQty,
  processPayment,
  printBill,
  processSplitPayment,
  openVoidModal,
  openSplitPaymentModal,
  closeVoidModal,
  handleVoidPinInput,
  submitVoidOrder,
  openCancelTransactionModal,
  closeCancelTransactionModal,
  handleCancelPinInput,
  openReceiptDetail,
  closeReceiptModal,
  handleReprintReceipt,
  handleHandoverCurrentPinInput,
  handleHandoverNextPinInput,
  submitCancelTransaction,
  refreshData
} = useCashierView()
</script>
