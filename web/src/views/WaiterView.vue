<template>
  <div class="min-h-screen bg-slate-50 pb-24 lg:pb-6">
    <div class="mx-auto max-w-7xl px-3 sm:px-4 lg:px-8 py-4 sm:py-6 space-y-4 sm:space-y-6">
      <!-- Header -->
      <div class="overflow-hidden rounded-2xl bg-gradient-to-r from-emerald-600 to-emerald-500 p-4 sm:p-6 shadow-xl">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div class="flex items-center gap-3">
            <div class="flex h-12 w-12 sm:h-14 sm:w-14 items-center justify-center rounded-xl bg-white/20 backdrop-blur-sm">
              <svg class="h-6 w-6 sm:h-7 sm:w-7 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
              </svg>
            </div>
            <div>
              <h1 class="text-xl sm:text-2xl font-bold text-white">Waiter Dashboard</h1>
              <p class="text-xs sm:text-sm text-emerald-100">Kelola Meja & Pesanan</p>
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

      <!-- Stats -->
      <div class="grid gap-3 sm:gap-4 grid-cols-3">
        <div class="overflow-hidden rounded-2xl bg-white p-3 sm:p-4 shadow-lg">
          <div class="flex flex-col sm:flex-row items-center gap-2 sm:gap-3">
            <div class="flex h-10 w-10 sm:h-12 sm:w-12 items-center justify-center rounded-xl bg-emerald-100">
              <svg class="h-5 w-5 sm:h-6 sm:w-6 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div class="text-center sm:text-left">
              <div class="text-xl sm:text-2xl font-bold text-slate-900">{{ availableTables.length }}</div>
              <div class="text-xs text-slate-500">Tersedia</div>
            </div>
          </div>
        </div>
        <div class="overflow-hidden rounded-2xl bg-white p-3 sm:p-4 shadow-lg">
          <div class="flex flex-col sm:flex-row items-center gap-2 sm:gap-3">
            <div class="flex h-10 w-10 sm:h-12 sm:w-12 items-center justify-center rounded-xl bg-red-100">
              <svg class="h-5 w-5 sm:h-6 sm:w-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div class="text-center sm:text-left">
              <div class="text-xl sm:text-2xl font-bold text-slate-900">{{ occupiedTables.length }}</div>
              <div class="text-xs text-slate-500">Terisi</div>
            </div>
          </div>
        </div>
        <div class="overflow-hidden rounded-2xl bg-white p-3 sm:p-4 shadow-lg">
          <div class="flex flex-col sm:flex-row items-center gap-2 sm:gap-3">
            <div class="flex h-10 w-10 sm:h-12 sm:w-12 items-center justify-center rounded-xl bg-indigo-100">
              <svg class="h-5 w-5 sm:h-6 sm:w-6 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
            </div>
            <div class="text-center sm:text-left">
              <div class="text-xl sm:text-2xl font-bold text-slate-900">{{ activeOrders }}</div>
              <div class="text-xs text-slate-500">Order</div>
            </div>
          </div>
        </div>
      </div>

      <!-- Filter -->
      <div class="overflow-hidden rounded-2xl bg-white p-3 sm:p-4 shadow-lg">
        <div class="grid grid-cols-3 gap-2">
          <button
            @click="filterStatus = 'all'"
            :class="[
              'rounded-xl px-3 py-2.5 sm:py-3 text-sm sm:text-base font-bold transition-all',
              filterStatus === 'all' 
                ? 'bg-gradient-to-r from-emerald-600 to-emerald-500 text-white shadow-lg scale-105' 
                : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
            ]"
          >
            Semua
          </button>
          <button
            @click="filterStatus = 'available'"
            :class="[
              'rounded-xl px-3 py-2.5 sm:py-3 text-sm sm:text-base font-bold transition-all',
              filterStatus === 'available' 
                ? 'bg-gradient-to-r from-emerald-600 to-emerald-500 text-white shadow-lg scale-105' 
                : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
            ]"
          >
            Tersedia
          </button>
          <button
            @click="filterStatus = 'occupied'"
            :class="[
              'rounded-xl px-3 py-2.5 sm:py-3 text-sm sm:text-base font-bold transition-all',
              filterStatus === 'occupied' 
                ? 'bg-gradient-to-r from-emerald-600 to-emerald-500 text-white shadow-lg scale-105' 
                : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
            ]"
          >
            Terisi
          </button>
        </div>
      </div>

      <!-- Search Bar -->
      <div class="overflow-hidden rounded-2xl bg-white p-3 sm:p-4 shadow-lg">
        <div class="relative">
          <input 
            v-model="tableSearchQuery" 
            type="text" 
            placeholder="Cari meja (nama atau nomor)..."
            class="w-full h-11 pl-11 pr-10 rounded-xl border-2 border-slate-200 bg-slate-50 text-sm sm:text-base font-medium placeholder-slate-400 focus:outline-none focus:border-emerald-500 focus:bg-white focus:ring-4 focus:ring-emerald-100 transition-all"
          />
          <svg class="absolute left-3.5 top-1/2 -translate-y-1/2 h-5 w-5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
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

      <!-- Loading -->
      <div v-if="loading" class="overflow-hidden rounded-2xl bg-white p-12 shadow-lg">
        <div class="flex flex-col items-center gap-4 text-slate-500">
          <div class="h-12 w-12 animate-spin rounded-full border-4 border-slate-200 border-t-emerald-600"></div>
          <p class="font-semibold">Memuat data meja...</p>
        </div>
      </div>

      <!-- Empty State -->
      <div v-else-if="filteredTables.length === 0" class="overflow-hidden rounded-2xl bg-white p-12 shadow-lg">
        <div class="flex flex-col items-center gap-4 text-center">
          <div class="flex h-20 w-20 items-center justify-center rounded-full bg-slate-100">
            <svg class="h-10 w-10 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M3 14h18m-9-4v8m-7 0h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
            </svg>
          </div>
          <div>
            <h3 class="text-lg font-bold text-slate-900">Tidak Ada Meja</h3>
            <p class="mt-1 text-sm text-slate-500">
              Tidak ada meja {{ filterStatus === 'available' ? 'tersedia' : filterStatus === 'occupied' ? 'terisi' : '' }}
            </p>
          </div>
        </div>
      </div>

      <!-- Tables Grid -->
      <div v-else class="grid gap-3 sm:gap-4 grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        <button
          v-for="table in filteredTables"
          :key="table.id"
          @click="selectTable(table)"
          :class="[
            'group relative overflow-hidden rounded-2xl border-3 p-4 sm:p-5 shadow-lg transition-all active:scale-95 text-left',
            table.status === 'available' 
              ? 'border-emerald-300 bg-gradient-to-br from-emerald-50 to-emerald-100 hover:shadow-xl hover:scale-105' 
              : table.status === 'occupied'
              ? 'border-red-300 bg-gradient-to-br from-red-50 to-red-100 hover:shadow-xl hover:scale-105'
              : 'border-amber-300 bg-gradient-to-br from-amber-50 to-amber-100 hover:shadow-xl hover:scale-105'
          ]"
        >
          <!-- Status Badge -->
          <div class="absolute top-3 right-3 flex flex-col items-end gap-1">
            <span :class="[
              'inline-flex items-center gap-1.5 rounded-full px-2.5 sm:px-3 py-1 text-xs font-bold shadow-md',
              table.status === 'available' ? 'bg-emerald-600 text-white' :
              table.status === 'occupied' ? 'bg-red-600 text-white' :
              'bg-amber-600 text-white'
            ]">
              <span class="inline-block h-1.5 w-1.5 rounded-full bg-white"></span>
              {{ getStatusText(table.status) }}
            </span>
            <span
              v-if="table.active_order?.is_merged"
              class="inline-flex items-center gap-1.5 rounded-full px-2.5 sm:px-3 py-1 text-xs font-bold shadow-md bg-amber-100 text-amber-700"
            >
              Gabung ke {{ table.active_order?.merged_from_table_number || '-' }}
            </span>
          </div>

          <!-- Table Info -->
          <div class="mt-2">
            <div class="text-3xl sm:text-4xl font-black" :class="table.status === 'available' ? 'text-emerald-700' : table.status === 'occupied' ? 'text-red-700' : 'text-amber-700'">
              {{ table.table_number }}
            </div>
            <div class="mt-2 sm:mt-3 flex items-center gap-2 text-xs sm:text-sm text-slate-600">
              <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
              <span class="font-semibold">{{ table.capacity }} orang</span>
            </div>
            
            <!-- Active Order Info -->
            <div v-if="table.active_order" class="mt-3 space-y-1.5 text-xs">
              <div class="flex items-center gap-1.5 text-slate-700">
                <svg class="h-3.5 w-3.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                </svg>
                <span class="font-semibold truncate">{{ table.active_order.customer_name || 'Tamu' }}</span>
              </div>
              <div class="flex items-center gap-1.5 text-slate-700">
                <svg class="h-3.5 w-3.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                </svg>
                <span class="font-semibold">{{ table.active_order.pax }} pax</span>
              </div>
              <div class="flex items-center gap-1.5 text-emerald-700 bg-emerald-50 rounded-lg px-2 py-1 -mx-1">
                <span class="font-bold">Rp {{ formatCurrency(table.active_order.total_amount) }}</span>
              </div>
              <div v-if="targetSpendPerPax > 0" class="mt-1 space-y-1">
                <div class="flex items-center justify-between text-xs text-slate-600">
                  <span class="font-semibold">SPP</span>
                  <span class="font-bold">Rp {{ formatCurrency(getSpendPerPax(table.active_order)) }}/pax</span>
                </div>
                <div class="flex items-center justify-between rounded-lg px-2 py-1 -mx-1" :class="getGapClass(table.active_order)">
                  <span class="font-semibold" v-if="getSpendGap(table.active_order) > 0">Kurang</span>
                  <span class="font-semibold" v-else>Target</span>
                  <span class="font-bold" v-if="getSpendGap(table.active_order) > 0">Rp {{ formatCurrency(getGapValue(table.active_order)) }}/pax</span>
                  <span class="font-bold" v-else>Tercapai</span>
                </div>
              </div>
            </div>
            <div v-else-if="table.status === 'occupied'" class="mt-2 flex items-center gap-1.5 text-xs text-red-600">
              <svg class="h-3.5 w-3.5" fill="currentColor" viewBox="0 0 20 20">
                <path d="M10 2a6 6 0 00-6 6v3.586l-.707.707A1 1 0 004 14h12a1 1 0 00.707-1.707L16 11.586V8a6 6 0 00-6-6zM10 18a3 3 0 01-3-3h6a3 3 0 01-3 3z" />
              </svg>
              <span class="font-semibold">Ada pesanan aktif</span>
            </div>
          </div>

          <!-- Action Button -->
          <div class="mt-4">
            <div
              v-if="table.status === 'available'"
              class="flex items-center justify-center gap-2 rounded-xl bg-emerald-600 px-3 py-2.5 sm:py-3 font-bold text-white shadow-md transition-all group-hover:bg-emerald-700"
            >
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
              <span class="text-sm sm:text-base">Buat Order</span>
            </div>
            <div
              v-else-if="table.status === 'occupied'"
              class="flex items-center justify-center gap-2 rounded-xl bg-red-600 px-3 py-2.5 sm:py-3 font-bold text-white shadow-md transition-all group-hover:bg-red-700"
            >
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
              </svg>
              <span class="text-sm sm:text-base">Lihat Order</span>
            </div>
          </div>
        </button>
      </div>
    </div>

    <!-- Create Order Modal -->
    <div v-if="showOrderModal" class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-slate-900/60 sm:px-4" @click="closeOrderModal">
      <div class="w-full max-w-3xl rounded-t-3xl sm:rounded-3xl bg-white shadow-soft max-h-[90vh] overflow-hidden flex flex-col" @click.stop>
        <!-- Header -->
        <div class="flex items-center justify-between border-b border-slate-100 px-4 sm:px-6 py-3 sm:py-4 sticky top-0 bg-white z-10">
          <div class="flex items-center gap-3">
            <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-100">
              <svg class="h-6 w-6 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
            </div>
            <div>
              <h2 class="text-base sm:text-lg font-bold text-slate-900">Buat Order Baru</h2>
              <p class="text-xs sm:text-sm text-slate-500">Meja {{ selectedTable?.table_number }}</p>
            </div>
          </div>
          <button @click="closeOrderModal" class="flex h-9 w-9 items-center justify-center rounded-lg bg-slate-100 text-slate-600 transition hover:bg-slate-200">
            <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <!-- Content -->
        <div class="overflow-y-auto flex-1 p-4 sm:p-6">
          <form @submit.prevent="submitOrder" class="space-y-4">
            <!-- Customer Search -->
            <div class="rounded-2xl border-2 border-indigo-200 bg-indigo-50/30 p-3 sm:p-4 space-y-3">
              <div class="flex items-center gap-2 text-sm font-bold text-indigo-700">
                <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                </svg>
                Data Pelanggan
              </div>
              
              <div>
                <label class="block text-xs font-semibold text-slate-600 mb-1.5">Nomor HP</label>
                <div class="relative">
                  <input 
                    v-model="orderForm.customer_phone" 
                    @input="searchCustomerByPhone"
                    type="tel" 
                    class="input text-base font-semibold pr-10" 
                    placeholder="08xxxxxxxxxx" 
                  />
                  <div class="absolute right-3 top-1/2 -translate-y-1/2">
                    <svg v-if="searchingCustomer" class="h-5 w-5 animate-spin text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                    </svg>
                    <svg v-else-if="customerFound" class="h-5 w-5 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <svg v-else class="h-5 w-5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 3l-6 6m0 0V4m0 5h5M5 3a2 2 0 00-2 2v1c0 8.284 6.716 15 15 15h1a2 2 0 002-2v-3.28a1 1 0 00-.684-.948l-4.493-1.498a1 1 0 00-1.21.502l-1.13 2.257a11.042 11.042 0 01-5.516-5.517l2.257-1.128a1 1 0 00.502-1.21L9.228 3.683A1 1 0 008.279 3H5z" />
                    </svg>
                  </div>
                </div>
                <p v-if="customerFound" class="mt-1.5 text-xs text-emerald-600 font-semibold flex items-center gap-1">
                  <svg class="h-3.5 w-3.5" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                  </svg>
                  Pelanggan ditemukan
                </p>
                <p v-else-if="orderForm.customer_phone && orderForm.customer_phone.length >= 8" class="mt-1.5 text-xs text-amber-600 font-semibold flex items-center gap-1">
                  <svg class="h-3.5 w-3.5" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                  </svg>
                  Pelanggan baru - isi nama di bawah
                </p>
              </div>

              <div>
                <label class="block text-xs font-semibold text-slate-600 mb-1.5">Nama Pelanggan</label>
                <input 
                  v-model="orderForm.customer_name" 
                  type="text" 
                  class="input text-base" 
                  placeholder="Opsional" 
                  :disabled="customerFound"
                />
              </div>
            </div>

            <div class="grid gap-4">
              <div>
                <label class="text-sm font-semibold text-slate-700">Jumlah Tamu *</label>
                <input v-model.number="orderForm.pax" type="number" min="1" required class="input mt-2" placeholder="Berapa orang?" />
              </div>
            </div>

            <div class="space-y-3">
              <label class="text-sm font-semibold text-slate-700">Item Pesanan *</label>
              <div class="space-y-3">
                <div v-for="(item, index) in orderForm.items" :key="index" class="rounded-2xl border-2 border-emerald-200 bg-emerald-50/30 p-3 sm:p-4 space-y-3">
                  <!-- Menu Search -->
                  <div class="relative">
                    <label class="block text-xs font-semibold text-slate-600 mb-1.5">Cari Menu</label>
                    <div class="relative">
                      <input 
                        v-model="item.searchQuery" 
                        @focus="onSearchFocus(index)"
                        @blur="onSearchBlur(index)"
                        type="text" 
                        placeholder="Ketik nama atau kode menu..." 
                        class="input text-base font-semibold pr-10"
                      />
                      <div class="absolute right-3 top-1/2 -translate-y-1/2">
                        <svg class="h-5 w-5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                        </svg>
                      </div>
                    </div>
                    
                    <!-- Search Results Dropdown -->
                    <div 
                      v-if="item.showResults && item.searchQuery.length > 0" 
                      class="absolute z-10 mt-1 w-full max-h-60 overflow-y-auto rounded-xl border-2 border-emerald-200 bg-white shadow-xl"
                    >
                      <div v-if="getFilteredProducts(item.searchQuery).length === 0" class="p-4 text-center text-sm text-slate-500">
                        Tidak ada menu ditemukan
                      </div>
                      <button
                        v-for="product in getFilteredProducts(item.searchQuery)"
                        :key="product.id"
                        type="button"
                        @click="selectProduct(index, product)"
                        class="w-full p-3 text-left transition hover:bg-emerald-50 border-b border-slate-100 last:border-b-0"
                      >
                        <div class="flex items-center justify-between">
                          <div class="flex-1">
                            <div class="font-semibold text-slate-900">{{ product.name }}</div>
                            <div class="text-xs text-slate-500 mt-0.5">{{ product.code || 'Tanpa Kode' }} • {{ product.category_name }}</div>
                          </div>
                          <div class="text-sm font-bold text-emerald-600 ml-3">{{ formatCurrency(product.price) }}</div>
                        </div>
                      </button>
                    </div>
                  </div>

                  <!-- Selected Menu Display -->
                  <div v-if="item.product_id" class="rounded-xl bg-white p-3 border border-emerald-200">
                    <div class="flex items-center justify-between">
                      <div>
                        <div class="text-sm font-bold text-slate-900">{{ item.product_name }}</div>
                        <div class="text-xs text-slate-500 mt-0.5">{{ formatCurrency(item.price) }} / porsi</div>
                      </div>
                      <button
                        type="button"
                        @click="item.product_id = null; item.searchQuery = ''; item.price = 0"
                        class="flex h-8 w-8 items-center justify-center rounded-lg bg-slate-100 text-slate-600 hover:bg-slate-200"
                      >
                        <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                        </svg>
                      </button>
                    </div>
                  </div>

                  <!-- Quantity Control -->
                  <div>
                    <label class="block text-xs font-semibold text-slate-600 mb-1.5">Jumlah</label>
                    <div class="flex items-center gap-3">
                      <button
                        type="button"
                        @click="decrementQty(index)"
                        class="flex h-14 w-14 items-center justify-center rounded-xl bg-red-100 text-red-600 transition-all hover:bg-red-200 active:scale-95"
                      >
                        <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M20 12H4" />
                        </svg>
                      </button>
                      <div class="flex-1 text-center">
                        <div class="text-4xl font-black text-slate-900">{{ item.qty }}</div>
                      </div>
                      <button
                        type="button"
                        @click="incrementQty(index)"
                        class="flex h-14 w-14 items-center justify-center rounded-xl bg-emerald-600 text-white transition-all hover:bg-emerald-700 active:scale-95"
                      >
                        <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M12 4v16m8-8H4" />
                        </svg>
                      </button>
                    </div>
                  </div>

                  <!-- Price Display -->
                  <div v-if="item.price > 0" class="rounded-xl bg-white p-3 border border-emerald-200">
                    <div class="text-xs text-slate-500 mb-1">Total Harga</div>
                    <div class="text-2xl font-bold text-emerald-600">{{ formatCurrency(item.price * item.qty) }}</div>
                  </div>

                  <!-- Remove Button -->
                  <button
                    v-if="orderForm.items.length > 1"
                    type="button"
                    @click="removeItem(index)"
                    class="w-full flex items-center justify-center gap-2 rounded-xl bg-red-100 px-4 py-2.5 font-semibold text-red-600 transition hover:bg-red-200"
                  >
                    <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                    Hapus Item
                  </button>
                </div>
              </div>
              <button type="button" @click="addItem" class="btn-secondary w-full flex items-center justify-center gap-2">
                <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                </svg>
                Tambah Menu Lain
              </button>
            </div>

            <div class="flex flex-col sm:flex-row items-stretch sm:items-center gap-2 pt-4">
              <div class="flex items-center justify-between rounded-xl border border-emerald-200 bg-white px-4 py-3 sm:flex-1">
                <span class="text-sm font-semibold text-slate-600">Total Nominal</span>
                <span class="text-lg font-bold text-emerald-600">{{ formatCurrency(orderFormTotal) }}</span>
              </div>
              <button type="button" @click="closeOrderModal" class="btn-secondary sm:whitespace-nowrap">Batal</button>
              <button type="submit" class="btn-primary flex items-center justify-center gap-2 sm:whitespace-nowrap" :disabled="submitting">
                <svg v-if="!submitting" class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
                <div v-else class="h-5 w-5 animate-spin rounded-full border-2 border-white border-t-transparent"></div>
                {{ submitting ? 'Memproses...' : 'Buat Order' }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>

    <!-- View Order Modal -->
    <div v-if="showViewOrderModal" class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-slate-900/60 sm:px-4" @click="closeViewOrderModal">
      <div class="w-full max-w-4xl rounded-t-3xl sm:rounded-3xl bg-white shadow-soft max-h-[90vh] overflow-hidden flex flex-col min-h-0" @click.stop>
        <!-- Header -->
        <div class="flex items-center justify-between border-b border-slate-100 px-4 sm:px-6 py-3 sm:py-4 sticky top-0 bg-white z-10">
          <div class="flex items-center gap-3">
            <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-indigo-100">
              <svg class="h-6 w-6 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
            </div>
            <div>
              <h2 class="text-base sm:text-lg font-bold text-slate-900">Detail Order</h2>
              <p class="text-xs sm:text-sm text-slate-500">Meja {{ selectedTable?.table_number }}</p>
            </div>
          </div>
          <button @click="closeViewOrderModal" class="flex h-9 w-9 items-center justify-center rounded-lg bg-slate-100 text-slate-600 transition hover:bg-slate-200">
            <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <!-- Content -->
        <div class="overflow-y-auto flex-1 p-4 sm:p-6 min-h-0">
          <div v-if="loadingOrder" class="flex items-center justify-center gap-3 py-12 text-slate-500">
            <div class="h-8 w-8 animate-spin rounded-full border-3 border-slate-200 border-t-emerald-600"></div>
            <p class="font-semibold">Memuat order...</p>
          </div>
          <div v-else-if="currentOrder" class="space-y-4">
            <!-- Order Info -->
            <div class="grid gap-3 rounded-2xl border-2 border-slate-200 p-4 sm:grid-cols-2">
              <div class="text-sm text-slate-500">Nomor Pesanan</div>
              <div class="text-sm font-semibold text-slate-900">{{ currentOrder.order.id }}</div>
              <div class="text-sm text-slate-500">Pelanggan</div>
              <div class="text-sm font-semibold text-slate-900">{{ currentOrder.order.customer_name || '-' }}</div>
              <div class="text-sm text-slate-500">Jumlah Tamu</div>
              <div class="text-sm font-semibold text-slate-900">{{ currentOrder.order.pax }} orang</div>
              <div class="text-sm text-slate-500">Total</div>
              <div class="text-lg font-bold text-emerald-600">{{ formatCurrency(currentOrder.order.total_amount) }}</div>
              <div class="text-sm text-slate-500">Status</div>
              <div>
                <span :class="['rounded-full px-3 py-1 text-xs font-semibold', orderStatusClass(currentOrder.order.order_status)]">
                  {{ getOrderStatusText(currentOrder.order.order_status) }}
                </span>
              </div>
              <div v-if="currentOrder.order.is_merged" class="text-sm text-slate-500">Gabungan</div>
              <div v-if="currentOrder.order.is_merged" class="text-sm font-semibold text-amber-700">
                Digabung ke Meja {{ currentOrder.order.merged_from_table_number || '-' }}
              </div>
            </div>

            <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <h3 class="text-sm font-bold text-slate-700">Item Pesanan</h3>
              <div class="flex flex-col sm:flex-row gap-2">
                <button
                  type="button"
                  @click="openMergeModal"
                  :disabled="mergeCandidates.length === 0 || currentOrder.order.is_merged"
                  class="btn-secondary flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h10M7 12h10M7 17h10" />
                  </svg>
                  Gabung Meja
                </button>
                <button
                  type="button"
                  @click="openAddItemsModal"
                  class="btn-primary flex items-center justify-center gap-2"
                >
                  <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                  </svg>
                  Tambah Pesanan
                </button>
              </div>
            </div>
            <div class="space-y-3">
              <div class="space-y-2">
                <div v-for="item in currentOrder.items" :key="item.id" class="rounded-2xl border border-slate-200 p-3 sm:p-4">
                  <div class="flex items-start justify-between">
                    <div class="flex-1">
                      <div class="font-semibold text-slate-900">{{ item.product_name }}</div>
                      <div class="mt-1 flex items-center gap-2 text-xs sm:text-sm text-slate-500">
                        <span>{{ item.qty }}x</span>
                        <span>{{ formatCurrency(item.price) }}</span>
                      </div>
                    </div>
                    <div class="text-right">
                      <div class="font-bold text-slate-900">{{ formatCurrency(item.price * item.qty) }}</div>
                      <div class="mt-1 flex items-center justify-end gap-2">
                        <span :class="['rounded-full px-2 py-0.5 text-xs font-semibold', destinationClass(item.destination)]">
                          {{ item.destination === 'kitchen' ? 'Kitchen' : 'Bar' }}
                        </span>
                        <span :class="['rounded-full px-2 py-0.5 text-xs font-semibold', itemStatusClass(item.item_status)]">
                          {{ getItemStatusText(item.item_status) }}
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
  <div v-if="showMergeModal" class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-slate-900/60 sm:px-4" @click="closeMergeModal">
    <div class="w-full max-w-2xl rounded-t-3xl sm:rounded-3xl bg-white shadow-soft max-h-[90vh] overflow-hidden flex flex-col" @click.stop>
      <div class="flex items-center justify-between border-b border-slate-100 px-4 sm:px-6 py-3 sm:py-4 sticky top-0 bg-white z-10">
        <div class="flex items-center gap-3">
          <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-amber-100">
            <svg class="h-6 w-6 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h10M7 12h10M7 17h10" />
            </svg>
          </div>
          <div>
            <h2 class="text-base sm:text-lg font-bold text-slate-900">Gabung Meja</h2>
            <p class="text-xs sm:text-sm text-slate-500">Target: Meja {{ selectedTable?.table_number }}</p>
          </div>
        </div>
        <button @click="closeMergeModal" class="flex h-9 w-9 items-center justify-center rounded-lg bg-slate-100 text-slate-600 transition hover:bg-slate-200">
          <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <div class="overflow-y-auto flex-1 p-4 sm:p-6">
        <div class="space-y-3">
          <div class="rounded-2xl border-2 border-slate-200 bg-slate-50/60 p-3 sm:p-4">
            <div class="text-xs font-semibold text-slate-500">Pilih meja untuk digabung</div>
            <div class="text-sm font-bold text-slate-900">Minimal 1 meja terisi lain</div>
          </div>

          <div v-if="mergeCandidates.length === 0" class="rounded-2xl border-2 border-slate-200 p-6 text-center text-sm text-slate-500">
            Tidak ada meja terisi lain yang bisa digabung
          </div>

          <div v-else class="space-y-2">
            <label
              v-for="table in mergeCandidates"
              :key="table.id"
              class="flex items-center justify-between rounded-2xl border border-slate-200 p-3 transition hover:bg-slate-50"
            >
              <div class="flex items-center gap-3">
                <input
                  type="checkbox"
                  class="h-4 w-4 text-emerald-600"
                  :value="table.id"
                  v-model="mergeSelections"
                />
                <div>
                  <div class="text-sm font-semibold text-slate-900">Meja {{ table.table_number }}</div>
                  <div class="text-xs text-slate-500">Order {{ table.active_order?.order_id }}</div>
                </div>
              </div>
              <div class="text-sm font-bold text-emerald-600">{{ formatCurrency(table.active_order?.total_amount || 0) }}</div>
            </label>
          </div>
        </div>
      </div>

      <div class="border-t border-slate-100 p-4 sm:p-6">
        <div class="flex flex-col sm:flex-row gap-2 sm:justify-end">
          <button type="button" @click="closeMergeModal" class="btn-secondary">Batal</button>
          <button
            type="button"
            @click="submitMerge"
            :disabled="mergeSelections.length === 0 || merging"
            class="btn-primary flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <div v-if="merging" class="h-5 w-5 animate-spin rounded-full border-2 border-white border-t-transparent"></div>
            {{ merging ? 'Memproses...' : 'Gabungkan Meja' }}
          </button>
        </div>
      </div>
    </div>
  </div>
  <!-- Add Items Modal -->
  <div v-if="showAddItemsModal" class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-slate-900/60 sm:px-4" @click="closeAddItemsModal(true)">
    <div class="w-full max-w-3xl rounded-t-3xl sm:rounded-3xl bg-white shadow-soft max-h-[90vh] overflow-hidden flex flex-col" @click.stop>
      <div class="flex items-center justify-between border-b border-slate-100 px-4 sm:px-6 py-3 sm:py-4 sticky top-0 bg-white z-10">
        <div class="flex items-center gap-3">
          <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-100">
            <svg class="h-6 w-6 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
            </svg>
          </div>
          <div>
            <h2 class="text-base sm:text-lg font-bold text-slate-900">Tambah Pesanan</h2>
            <p class="text-xs sm:text-sm text-slate-500">Meja {{ selectedTable?.table_number }}</p>
          </div>
        </div>
        <button @click="closeAddItemsModal(true)" class="flex h-9 w-9 items-center justify-center rounded-lg bg-slate-100 text-slate-600 transition hover:bg-slate-200">
          <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <div class="overflow-y-auto flex-1 p-4 sm:p-6">
        <form @submit.prevent="submitAddItems" class="space-y-4">
          <div class="rounded-2xl border-2 border-slate-200 bg-slate-50/60 p-3 sm:p-4">
            <div class="text-xs font-semibold text-slate-500">Pelanggan</div>
            <div class="text-sm font-bold text-slate-900">{{ currentOrder?.order?.customer_name || 'Tamu' }}</div>
          </div>
          <div class="space-y-3">
            <label class="text-sm font-semibold text-slate-700">Item Pesanan *</label>
            <div class="space-y-3">
              <div v-for="(item, index) in addItemsForm.items" :key="index" class="rounded-2xl border-2 border-emerald-200 bg-emerald-50/30 p-3 sm:p-4 space-y-3">
                <div class="relative">
                  <label class="block text-xs font-semibold text-slate-600 mb-1.5">Cari Menu</label>
                  <div class="relative">
                    <input
                      v-model="item.searchQuery"
                      @focus="onAddSearchFocus(index)"
                      @blur="onAddSearchBlur(index)"
                      type="text"
                      placeholder="Ketik nama atau kode menu..."
                      class="input text-base font-semibold pr-10"
                    />
                    <div class="absolute right-3 top-1/2 -translate-y-1/2">
                      <svg class="h-5 w-5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                      </svg>
                    </div>
                  </div>

                  <div
                    v-if="item.showResults && item.searchQuery.length > 0"
                    class="absolute z-10 mt-1 w-full max-h-60 overflow-y-auto rounded-xl border-2 border-emerald-200 bg-white shadow-xl"
                  >
                    <div v-if="getFilteredProducts(item.searchQuery).length === 0" class="p-4 text-center text-sm text-slate-500">
                      Tidak ada menu ditemukan
                    </div>
                    <button
                      v-for="product in getFilteredProducts(item.searchQuery)"
                      :key="product.id"
                      type="button"
                      @click="selectProductAdd(index, product)"
                      class="w-full p-3 text-left transition hover:bg-emerald-50 border-b border-slate-100 last:border-b-0"
                    >
                      <div class="flex items-center justify-between">
                        <div class="flex-1">
                          <div class="font-semibold text-slate-900">{{ product.name }}</div>
                          <div class="text-xs text-slate-500 mt-0.5">{{ product.code || 'Tanpa Kode' }} • {{ product.category_name }}</div>
                        </div>
                        <div class="text-sm font-bold text-emerald-600 ml-3">{{ formatCurrency(product.price) }}</div>
                      </div>
                    </button>
                  </div>
                </div>

                <div v-if="item.product_id" class="rounded-xl bg-white p-3 border border-emerald-200">
                  <div class="flex items-center justify-between">
                    <div>
                      <div class="text-sm font-bold text-slate-900">{{ item.product_name }}</div>
                      <div class="text-xs text-slate-500 mt-0.5">{{ formatCurrency(item.price) }} / porsi</div>
                    </div>
                    <button
                      type="button"
                      @click="item.product_id = null; item.searchQuery = ''; item.price = 0"
                      class="flex h-8 w-8 items-center justify-center rounded-lg bg-slate-100 text-slate-600 hover:bg-slate-200"
                    >
                      <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  </div>
                </div>

                <div>
                  <label class="block text-xs font-semibold text-slate-600 mb-1.5">Jumlah</label>
                  <div class="flex items-center gap-3">
                    <button
                      type="button"
                      @click="decrementAddQty(index)"
                      class="flex h-14 w-14 items-center justify-center rounded-xl bg-red-100 text-red-600 transition-all hover:bg-red-200 active:scale-95"
                    >
                      <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M20 12H4" />
                      </svg>
                    </button>
                    <div class="flex-1 text-center">
                      <div class="text-4xl font-black text-slate-900">{{ item.qty }}</div>
                    </div>
                    <button
                      type="button"
                      @click="incrementAddQty(index)"
                      class="flex h-14 w-14 items-center justify-center rounded-xl bg-emerald-600 text-white transition-all hover:bg-emerald-700 active:scale-95"
                    >
                      <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M12 4v16m8-8H4" />
                      </svg>
                    </button>
                  </div>
                </div>

                <div v-if="item.price > 0" class="rounded-xl bg-white p-3 border border-emerald-200">
                  <div class="text-xs text-slate-500 mb-1">Total Harga</div>
                  <div class="text-2xl font-bold text-emerald-600">{{ formatCurrency(item.price * item.qty) }}</div>
                </div>

                <button
                  v-if="addItemsForm.items.length > 1"
                  type="button"
                  @click="removeAddItem(index)"
                  class="w-full flex items-center justify-center gap-2 rounded-xl bg-red-100 px-4 py-2.5 font-semibold text-red-600 transition hover:bg-red-200"
                >
                  <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                  </svg>
                  Hapus Item
                </button>
              </div>
            </div>
            <button type="button" @click="addAddItem" class="btn-secondary w-full flex items-center justify-center gap-2">
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
              Tambah Menu Lain
            </button>
          </div>

          <div class="flex flex-col sm:flex-row items-stretch sm:items-center gap-2 pt-4">
            <button type="button" @click="closeAddItemsModal(true)" class="btn-secondary">Batal</button>
            <button type="submit" class="btn-primary flex items-center justify-center gap-2" :disabled="addingItems">
              <svg v-if="!addingItems" class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
              </svg>
              <div v-else class="h-5 w-5 animate-spin rounded-full border-2 border-white border-t-transparent"></div>
              {{ addingItems ? 'Memproses...' : 'Tambah Pesanan' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>
<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import api, { subscribeRealtime } from '../services/api'
import { useNotification } from '../composables/useNotification'

const { success: showSuccess, error: showError } = useNotification()

const loading = ref(false)
const allTables = ref([])
const availableTables = ref([])
const occupiedTables = ref([])
const activeOrders = ref(0)
const products = ref([])
const searchingCustomer = ref(false)
const customerFound = ref(false)
const customerSearchTimer = ref(null)
const searchQuery = ref('')
const tableSearchQuery = ref('')
const filterStatus = ref('all')
const selectedTable = ref(null)
const showOrderModal = ref(false)
const showViewOrderModal = ref(false)
const showAddItemsModal = ref(false)
const showMergeModal = ref(false)
const submitting = ref(false)
const addingItems = ref(false)
const merging = ref(false)
const loadingOrder = ref(false)
const currentOrder = ref(null)
const mergeSelections = ref([])
const targetSpendPerPax = ref(0)
let realtimeUnsubscribe = null

const orderForm = ref({
  customer_name: '',
  customer_phone: '',
  pax: 1,
  items: [
    {
      product_id: null,
      product_name: '',
      price: 0,
      qty: 1,
      searchQuery: '',
      showResults: false
    }
  ]
})

const addItemsForm = ref({
  items: [
    {
      product_id: null,
      product_name: '',
      qty: 1,
      price: 0,
      searchQuery: '',
      showResults: false
    }
  ]
})

const filteredTables = computed(() => {
  let tables = []
  if (filterStatus.value === 'all') tables = allTables.value
  else if (filterStatus.value === 'available') tables = availableTables.value
  else if (filterStatus.value === 'occupied') tables = occupiedTables.value
  else tables = allTables.value

  // Apply table search filter
  if (tableSearchQuery.value.trim()) {
    const query = tableSearchQuery.value.toLowerCase().trim()
    tables = tables.filter(table => 
      (table.name && table.name.toLowerCase().includes(query)) || 
      (table.table_number && table.table_number.toString().includes(query))
    )
  }

  return tables
})

const mergeCandidates = computed(() => {
  const targetId = selectedTable.value?.id
  return occupiedTables.value.filter(table =>
    table.id !== targetId &&
    table.active_order &&
    table.active_order.payment_status !== 'paid' &&
    !table.active_order.is_merged
  )
})

const orderFormTotal = computed(() => {
  return orderForm.value.items.reduce((total, item) => {
    return total + (item.price || 0) * (item.qty || 0)
  }, 0)
})

const getFilteredProducts = (searchQuery) => {
  if (!searchQuery || searchQuery.length < 1) return []
  const query = searchQuery.toLowerCase()
  return products.value.filter(p => 
    p.name.toLowerCase().includes(query) || 
    (p.code && p.code.toLowerCase().includes(query))
  ).slice(0, 10)
}

const refreshData = async (showLoading = true) => {
  if (showLoading) {
    loading.value = true
  }
  try {
    await Promise.all([fetchAllTables(), fetchProducts(), fetchOutletConfig()])
  } finally {
    if (showLoading) {
      loading.value = false
    }
  }
}

const fetchProducts = async () => {
  try {
    const response = await api.get('/products', { params: { page_size: 1000 } })
    products.value = response.data.data || []
  } catch (error) {
    showError('Gagal memuat data produk')
  }
}

const fetchOutletConfig = async () => {
  try {
    const response = await api.get('/config/outlet')
    if (response.data.success && response.data.data) {
      targetSpendPerPax.value = response.data.data.target_spend_per_pax || 0
    }
  } catch (error) {
    targetSpendPerPax.value = 0
  }
}

const searchCustomerByPhone = async () => {
  // Clear previous timer
  if (customerSearchTimer.value) {
    clearTimeout(customerSearchTimer.value)
  }

  // Reset state if phone is too short
  if (!orderForm.value.customer_phone || orderForm.value.customer_phone.length < 10) {
    customerFound.value = false
    orderForm.value.customer_name = ''
    return
  }

  // Debounce - wait 500ms after user stops typing
  customerSearchTimer.value = setTimeout(async () => {
    searchingCustomer.value = true
    try {
      const response = await api.get(`/customers/phone/${orderForm.value.customer_phone}`)
      if (response.data.success && response.data.data) {
        orderForm.value.customer_name = response.data.data.name
        customerFound.value = true
        showSuccess('Pelanggan ditemukan: ' + response.data.data.name)
      }
    } catch (error) {
      // Silently handle 404 - customer not found is expected
      if (error.response?.status === 404) {
        customerFound.value = false
        // Don't clear name - let user type new customer name
      } else {
        // Only show error for real errors (500, network, etc)
        console.error('Customer search error:', error)
      }
    } finally {
      searchingCustomer.value = false
    }
  }, 500)
}

const fetchAllTables = async () => {
  try {
    const response = await api.get('/tables', { params: { page_size: 100 } })
    const tables = response.data.data || []
    const normalizedTables = tables.map(table => {
      const hasActiveOrder = !!table.active_order
      if (hasActiveOrder) {
        return { ...table, status: 'occupied' }
      }
      if (table.status === 'reserved') {
        return table
      }
      return { ...table, status: 'available' }
    })
    allTables.value = normalizedTables
    availableTables.value = normalizedTables.filter(table => table.status === 'available')
    occupiedTables.value = normalizedTables.filter(table => table.status === 'occupied')
    activeOrders.value = occupiedTables.value.length
  } catch (error) {
    showError('Gagal memuat data meja')
  }
}

const selectTable = (table) => {
  selectedTable.value = table
  if (table.status === 'available') {
    showOrderModal.value = true
  } else if (table.status === 'occupied') {
    viewTableOrder(table)
  }
}

const closeOrderModal = () => {
  showOrderModal.value = false
  selectedTable.value = null
  customerFound.value = false
  orderForm.value = {
    customer_name: '',
    customer_phone: '',
    pax: 1,
    items: [{ product_id: null, product_name: '', price: 0, qty: 1, searchQuery: '', showResults: false }]
  }
}

const closeViewOrderModal = () => {
  showViewOrderModal.value = false
  selectedTable.value = null
  currentOrder.value = null
}

const openMergeModal = () => {
  mergeSelections.value = []
  showMergeModal.value = true
}

const closeMergeModal = () => {
  showMergeModal.value = false
}

const openAddItemsModal = () => {
  showViewOrderModal.value = false
  showAddItemsModal.value = true
  addItemsForm.value = {
    items: [
      {
        product_id: null,
        product_name: '',
        qty: 1,
        price: 0,
        searchQuery: '',
        showResults: false
      }
    ]
  }
}

const closeAddItemsModal = (reopen) => {
  showAddItemsModal.value = false
  if (reopen && currentOrder.value) {
    showViewOrderModal.value = true
  } else if (!reopen) {
    selectedTable.value = null
    currentOrder.value = null
  }
}

const addItem = () => {
  orderForm.value.items.push({
    product_id: null,
    product_name: '',
    price: 0,
    qty: 1,
    searchQuery: '',
    showResults: false
  })
}

const addAddItem = () => {
  addItemsForm.value.items.push({
    product_id: null,
    product_name: '',
    qty: 1,
    price: 0,
    searchQuery: '',
    showResults: false
  })
}

const removeItem = (index) => {
  orderForm.value.items.splice(index, 1)
}

const removeAddItem = (index) => {
  addItemsForm.value.items.splice(index, 1)
}

const incrementQty = (index) => {
  orderForm.value.items[index].qty++
}

const incrementAddQty = (index) => {
  addItemsForm.value.items[index].qty++
}

const decrementQty = (index) => {
  if (orderForm.value.items[index].qty > 1) {
    orderForm.value.items[index].qty--
  }
}

const decrementAddQty = (index) => {
  if (addItemsForm.value.items[index].qty > 1) {
    addItemsForm.value.items[index].qty--
  }
}

const selectProduct = (index, product) => {
  const items = orderForm.value.items
  const existingIndex = items.findIndex((item, i) => i !== index && item.product_id === product.id)
  if (existingIndex !== -1) {
    const addedQty = items[index]?.qty || 1
    items[existingIndex].qty += addedQty
    items.splice(index, 1)
    return
  }
  items[index].product_id = product.id
  items[index].product_name = product.name
  items[index].price = product.price
  items[index].searchQuery = product.name
  items[index].showResults = false
}

const selectProductAdd = (index, product) => {
  const items = addItemsForm.value.items
  const existingIndex = items.findIndex((item, i) => i !== index && item.product_id === product.id)
  if (existingIndex !== -1) {
    const addedQty = items[index]?.qty || 1
    items[existingIndex].qty += addedQty
    items.splice(index, 1)
    return
  }
  items[index].product_id = product.id
  items[index].product_name = product.name
  items[index].price = product.price
  items[index].searchQuery = product.name
  items[index].showResults = false
}

const onSearchFocus = (index) => {
  orderForm.value.items[index].showResults = true
}

const onAddSearchFocus = (index) => {
  addItemsForm.value.items[index].showResults = true
}

const onSearchBlur = (index) => {
  setTimeout(() => {
    orderForm.value.items[index].showResults = false
  }, 200)
}

const onAddSearchBlur = (index) => {
  setTimeout(() => {
    addItemsForm.value.items[index].showResults = false
  }, 200)
}

const submitOrder = async () => {
  submitting.value = true
  try {
    // Validate items before submit
    const hasInvalidItems = orderForm.value.items.some(item => 
      !item.product_id || item.qty <= 0
    )
    
    if (hasInvalidItems) {
      showError('Pastikan semua menu sudah dipilih dan lengkap')
      submitting.value = false
      return
    }

    // Ensure table is selected
    if (!selectedTable.value || !selectedTable.value.table_number) {
      showError('Meja belum dipilih atau data meja tidak valid')
      submitting.value = false
      return
    }

    const payload = {
      table_number: String(selectedTable.value.table_number),
      customer_name: orderForm.value.customer_name || '',
      customer_phone: orderForm.value.customer_phone || '',
      pax: orderForm.value.pax,
      items: orderForm.value.items.map(item => ({
        product_id: item.product_id,
        qty: item.qty
      }))
    }
    

    await api.post('/orders', payload)
    showSuccess('Order berhasil dibuat!')
    closeOrderModal()
    await refreshData()
  } catch (error) {
    console.error('Submit error:', error)
    console.error('Error response:', error.response?.data)
    showError('Gagal membuat order: ' + (error.response?.data?.message || error.message))
  } finally {
    submitting.value = false
  }
}

const submitAddItems = async () => {
  addingItems.value = true
  try {
    const hasInvalidItems = addItemsForm.value.items.some(item =>
      !item.product_id || item.qty <= 0
    )

    if (hasInvalidItems) {
      showError('Pastikan semua menu sudah dipilih dan lengkap')
      addingItems.value = false
      return
    }

    if (!selectedTable.value || !selectedTable.value.id) {
      showError('Meja belum dipilih atau data meja tidak valid')
      addingItems.value = false
      return
    }

    const payload = {
      items: addItemsForm.value.items.map(item => ({
        product_id: item.product_id,
        qty: item.qty
      }))
    }

    await api.post(`/orders/table/${selectedTable.value.id}/items`, payload)
    showSuccess('Item berhasil ditambahkan')
    showAddItemsModal.value = false
    await refreshData()
    await viewTableOrder(selectedTable.value)
  } catch (error) {
    console.error('Add items error:', error)
    showError('Gagal menambah item: ' + (error.response?.data?.message || error.message))
  } finally {
    addingItems.value = false
  }
}

const submitMerge = async () => {
  if (!selectedTable.value || !currentOrder.value?.order?.id) {
    showError('Data meja atau order tidak valid')
    return
  }

  if (mergeSelections.value.length === 0) {
    showError('Pilih minimal 1 meja untuk digabung')
    return
  }

  merging.value = true
  try {
    const selectedTables = mergeCandidates.value.filter(table => mergeSelections.value.includes(table.id))
    const sourceOrderIDs = [
      currentOrder.value.order.id,
      ...selectedTables.map(table => table.active_order?.order_id).filter(Boolean)
    ]

    const payload = {
      source_order_ids: sourceOrderIDs,
      target_table_number: String(selectedTable.value.table_number)
    }

    await api.post('/orders/merge', payload)
    showSuccess('Meja berhasil digabung')
    closeMergeModal()
    await refreshData()
    await viewTableOrder(selectedTable.value)
  } catch (error) {
    showError('Gagal menggabung meja: ' + (error.response?.data?.message || error.message))
  } finally {
    merging.value = false
  }
}

const viewTableOrder = async (table) => {
  loadingOrder.value = true
  showViewOrderModal.value = true
  try {
    const response = await api.get(`/orders/table/${table.id}`)
    currentOrder.value = response.data.data
  } catch (error) {
    showError('Gagal memuat detail order')
    closeViewOrderModal()
  } finally {
    loadingOrder.value = false
  }
}

const getStatusText = (status) => {
  const map = {
    available: 'Tersedia',
    occupied: 'Terisi',
    reserved: 'Reservasi'
  }
  return map[status] || status
}

const formatCurrency = (value) => {
  if (!value) return '0'
  return new Intl.NumberFormat('id-ID').format(value)
}

const getSpendPerPax = (order) => {
  const pax = order?.pax || 0
  if (pax <= 0) return 0
  return Math.round((order?.total_amount || 0) / pax)
}

const getSpendGap = (order) => {
  return (targetSpendPerPax.value || 0) - getSpendPerPax(order)
}

const getGapValue = (order) => {
  return Math.max(0, getSpendGap(order))
}

const getGapClass = (order) => {
  return getSpendGap(order) > 0 ? 'text-red-600 bg-red-50' : 'text-emerald-700 bg-emerald-50'
}

const getOrderStatusText = (status) => {
  const map = {
    pending: 'Pending',
    confirmed: 'Dikonfirmasi',
    completed: 'Selesai',
    cancelled: 'Dibatalkan'
  }
  return map[status] || status
}

const getItemStatusText = (status) => {
  const map = {
    pending: 'Pending',
    preparing: 'Diproses',
    ready: 'Siap',
    served: 'Disajikan'
  }
  return map[status] || status
}

const orderStatusClass = (status) => {
  const classes = {
    pending: 'bg-amber-100 text-amber-700',
    confirmed: 'bg-blue-100 text-blue-700',
    completed: 'bg-emerald-100 text-emerald-700',
    cancelled: 'bg-red-100 text-red-700'
  }
  return classes[status] || 'bg-slate-100 text-slate-600'
}

const itemStatusClass = (status) => {
  const classes = {
    pending: 'bg-amber-100 text-amber-700',
    preparing: 'bg-blue-100 text-blue-700',
    ready: 'bg-emerald-100 text-emerald-700',
    served: 'bg-slate-100 text-slate-600'
  }
  return classes[status] || 'bg-slate-100 text-slate-600'
}

const destinationClass = (destination) => {
  return destination === 'kitchen' ? 'bg-orange-100 text-orange-700' : 'bg-purple-100 text-purple-700'
}

const handleRealtimeEvent = async (event) => {
  if (!event?.type) return
  if (
    event.type === 'order_created' ||
    event.type === 'order_items_updated' ||
    event.type === 'orders_merged' ||
    event.type === 'item_status_updated' ||
    event.type === 'payment_completed' ||
    event.type === 'table_status_updated'
  ) {
    await refreshData(false)
    if (showViewOrderModal.value && selectedTable.value) {
      await viewTableOrder(selectedTable.value)
    }
  }
}

onMounted(() => {
  refreshData()
  realtimeUnsubscribe = subscribeRealtime(handleRealtimeEvent)
})

onUnmounted(() => {
  if (realtimeUnsubscribe) realtimeUnsubscribe()
})
</script>
