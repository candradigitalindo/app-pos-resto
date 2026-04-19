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
              <h1 class="text-xl sm:text-2xl font-bold text-white">{{ authStore.user?.full_name || 'Waiter' }}</h1>
              <p class="text-xs sm:text-sm text-emerald-100">Kelola Meja & Pesanan</p>
            </div>
          </div>
          <div class="flex items-center gap-2">
            <button @click="refreshData" class="flex items-center justify-center gap-2 rounded-xl bg-white px-4 py-2.5 font-semibold text-emerald-600 shadow-lg transition-all hover:scale-105 active:scale-95" :disabled="loading">
              <svg class="h-5 w-5" :class="loading ? 'animate-spin' : ''" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
              <span class="hidden sm:inline">{{ loading ? 'Memuat...' : 'Refresh' }}</span>
            </button>
            <button @click="switchWaiter" class="flex items-center justify-center gap-2 rounded-xl bg-white/20 px-4 py-2.5 font-semibold text-white shadow-lg transition-all hover:bg-white/30 active:scale-95">
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
              </svg>
              <span class="hidden sm:inline">Ganti</span>
            </button>
          </div>
        </div>
      </div>

      <!-- Stats -->
      <div v-if="authStore.user?.role !== 'waiter'" class="grid gap-3 sm:gap-4 grid-cols-3">
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
      <div v-if="authStore.user?.role !== 'waiter'" class="overflow-hidden rounded-2xl bg-white p-3 sm:p-4 shadow-lg">
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
      <div v-else class="grid gap-2 sm:gap-3 grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 2xl:grid-cols-6">
        <button
          v-for="table in filteredTables"
          :key="table.id"
          @click="selectTable(table)"
          :class="[
            'group relative overflow-hidden rounded-xl border-2 p-3 sm:p-3.5 shadow-md transition-all active:scale-95 text-left',
            table.status === 'available' 
              ? 'border-emerald-300 bg-gradient-to-br from-emerald-50 to-emerald-100 hover:shadow-xl hover:scale-105' 
              : table.status === 'occupied'
              ? 'border-red-300 bg-gradient-to-br from-red-50 to-red-100 hover:shadow-xl hover:scale-105'
              : 'border-amber-300 bg-gradient-to-br from-amber-50 to-amber-100 hover:shadow-xl hover:scale-105'
          ]"
        >
          <!-- Status Badge -->
          <div class="absolute top-2 right-2 flex flex-col items-end gap-1">
            <span :class="[
              'inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-bold shadow-sm',
              table.status === 'available' ? 'bg-emerald-600 text-white' :
              table.status === 'occupied' ? 'bg-red-600 text-white' :
              'bg-amber-600 text-white'
            ]">
              <span class="inline-block h-1 w-1 rounded-full bg-white"></span>
              {{ getStatusText(table.status) }}
            </span>
            <span
              v-if="table.active_order?.is_merged"
              class="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-bold shadow-sm bg-amber-100 text-amber-700"
            >
              Gabung ke {{ table.active_order?.merged_from_table_number || '-' }}
            </span>
          </div>

          <!-- Table Info -->
          <div class="mt-1">
            <div class="text-2xl sm:text-3xl font-black" :class="table.status === 'available' ? 'text-emerald-700' : table.status === 'occupied' ? 'text-red-700' : 'text-amber-700'">
              {{ table.table_number }}
            </div>
            <div class="mt-1 flex items-center gap-1.5 text-[11px] sm:text-xs text-slate-600">
              <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
              <span class="font-semibold">{{ table.capacity }} orang</span>
            </div>
            
            <!-- Active Order Info -->
            <div v-if="table.active_order" class="mt-2 space-y-1 text-[11px]">
              <div class="flex items-center gap-1.5 text-slate-700">
                <svg class="h-3.5 w-3.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                </svg>
                <span class="font-semibold truncate">{{ table.active_order.customer_name || 'Tamu' }}</span>
              </div>
              <div v-if="table.active_order.waiter_name" class="flex items-center gap-1.5 text-emerald-600">
                <svg class="h-3.5 w-3.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5.121 17.804A13.937 13.937 0 0112 16c2.5 0 4.847.655 6.879 1.804M15 10a3 3 0 11-6 0 3 3 0 016 0zm6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <span class="font-semibold truncate">{{ table.active_order.waiter_name }}</span>
              </div>
              <div class="flex items-center gap-1.5 text-slate-700">
                <svg class="h-3.5 w-3.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                </svg>
                <span class="font-semibold">{{ table.active_order.pax }} pax</span>
              </div>
              <div class="flex items-center gap-1.5 text-emerald-700 bg-emerald-50 rounded-md px-1.5 py-0.5 -mx-0.5">
                <span class="font-bold">Rp {{ formatCurrency(table.active_order.total_amount) }}</span>
              </div>
              <div v-if="targetSpendPerPax > 0" class="mt-0.5 space-y-0.5">
                <div class="flex items-center justify-between text-[11px] text-slate-600">
                  <span class="font-semibold">SPP</span>
                  <span class="font-bold">Rp {{ formatCurrency(getSpendPerPax(table.active_order)) }}/pax</span>
                </div>
                <div class="flex items-center justify-between rounded-md px-1.5 py-0.5 -mx-0.5" :class="getGapClass(table.active_order)">
                  <span class="font-semibold" v-if="getSpendGap(table.active_order) > 0">Kurang</span>
                  <span class="font-semibold" v-else>Target</span>
                  <span class="font-bold" v-if="getSpendGap(table.active_order) > 0">Rp {{ formatCurrency(getGapValue(table.active_order)) }}/pax</span>
                  <span class="font-bold" v-else>Tercapai</span>
                </div>
              </div>
            </div>
            <div v-else-if="table.status === 'occupied'" class="mt-1.5 flex items-center gap-1 text-[11px] text-red-600">
              <svg class="h-3.5 w-3.5" fill="currentColor" viewBox="0 0 20 20">
                <path d="M10 2a6 6 0 00-6 6v3.586l-.707.707A1 1 0 004 14h12a1 1 0 00.707-1.707L16 11.586V8a6 6 0 00-6-6zM10 18a3 3 0 01-3-3h6a3 3 0 01-3 3z" />
              </svg>
              <span class="font-semibold">Ada pesanan aktif</span>
            </div>
          </div>

          <!-- Action Button -->
          <div class="mt-2.5">
            <div
              v-if="table.status === 'available'"
              class="flex items-center justify-center gap-1.5 rounded-lg bg-emerald-600 px-2 py-1.5 sm:py-2 font-bold text-white shadow-sm transition-all group-hover:bg-emerald-700"
            >
              <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
              <span class="text-xs sm:text-sm">Buat Order</span>
            </div>
            <div
              v-else-if="table.status === 'occupied'"
              class="flex items-center justify-center gap-1.5 rounded-lg bg-red-600 px-2 py-1.5 sm:py-2 font-bold text-white shadow-sm transition-all group-hover:bg-red-700"
            >
              <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
              </svg>
              <span class="text-xs sm:text-sm">Lihat Order</span>
            </div>
          </div>
        </button>
      </div>
    </div>

    <!-- ==================== CREATE ORDER MODAL (Full-screen menu) ==================== -->
    <div v-if="showOrderModal" class="fixed inset-0 z-50 flex flex-col bg-white">
      <!-- Top Bar -->
      <div class="flex items-center justify-between border-b border-slate-200 px-4 py-3 bg-gradient-to-r from-emerald-600 to-emerald-500">
        <div class="flex items-center gap-3">
          <button @click="closeOrderModal" class="flex h-9 w-9 items-center justify-center rounded-lg bg-white/20 text-white transition hover:bg-white/30">
            <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
          </button>
          <div>
            <h2 class="text-base font-bold text-white">Buat Order — Meja {{ selectedTable?.table_number }}</h2>
            <p class="text-xs text-emerald-100">Waiter: {{ authStore.user?.full_name || '-' }}</p>
          </div>
        </div>
        <button @click="showCustomerPanel = !showCustomerPanel" :class="['flex items-center gap-1.5 rounded-lg px-3 py-2 text-xs font-semibold transition', showCustomerPanel ? 'bg-white text-emerald-600' : 'bg-white/20 text-white hover:bg-white/30']">
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
          </svg>
          Pelanggan
        </button>
      </div>

      <!-- Customer Panel (collapsible) -->
      <div v-if="showCustomerPanel" class="border-b border-slate-200 bg-indigo-50 px-4 py-3 space-y-2">
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-2">
          <div class="relative">
            <input v-model="orderForm.customer_phone" @input="searchCustomerByPhone" type="tel" class="input text-sm pr-8" placeholder="No. HP (08xxx)" />
            <div class="absolute right-2 top-1/2 -translate-y-1/2">
              <svg v-if="searchingCustomer" class="h-4 w-4 animate-spin text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" /></svg>
              <svg v-else-if="customerFound" class="h-4 w-4 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
            </div>
          </div>
          <input v-model="orderForm.customer_name" type="text" class="input text-sm" placeholder="Nama (opsional)" :disabled="customerFound" />
          <div class="flex items-center gap-2">
            <span class="text-xs font-semibold text-slate-600 whitespace-nowrap">Pax:</span>
            <button type="button" @click="orderForm.pax = Math.max(1, orderForm.pax - 1)" class="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-red-100 text-red-600 active:scale-95 font-bold text-lg">−</button>
            <div class="text-lg font-black text-slate-900 w-8 text-center">{{ orderForm.pax }}</div>
            <button type="button" @click="orderForm.pax++" class="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-emerald-600 text-white active:scale-95 font-bold text-lg">+</button>
          </div>
        </div>
        <p v-if="customerFound" class="text-xs text-emerald-600 font-semibold">Pelanggan ditemukan: {{ orderForm.customer_name }}</p>
      </div>

      <!-- Category Tabs -->
      <div class="border-b border-slate-200 bg-white">
        <div class="flex overflow-x-auto gap-1 px-3 py-2 no-scrollbar">
          <button
            @click="menuCategory = 'all'"
            :class="['whitespace-nowrap rounded-full px-4 py-2 text-sm font-bold transition-all shrink-0', menuCategory === 'all' ? 'bg-emerald-600 text-white shadow-md' : 'bg-slate-100 text-slate-600 hover:bg-slate-200']"
          >Semua</button>
          <button
            v-for="cat in categories"
            :key="cat"
            @click="menuCategory = cat"
            :class="['whitespace-nowrap rounded-full px-4 py-2 text-sm font-bold transition-all shrink-0', menuCategory === cat ? 'bg-emerald-600 text-white shadow-md' : 'bg-slate-100 text-slate-600 hover:bg-slate-200']"
          >{{ cat }}</button>
        </div>
      </div>

      <!-- Menu Grid + Cart -->
      <div class="flex-1 flex flex-col lg:flex-row overflow-hidden">
        <!-- Product Grid -->
        <div class="flex-1 overflow-y-auto p-3 pb-20 lg:pb-3">
          <!-- Quick search -->
          <div class="relative mb-3">
            <input v-model="menuSearchQuery" type="text" placeholder="Cari menu cepat..." class="w-full h-10 pl-9 pr-8 rounded-xl border border-slate-200 bg-slate-50 text-sm focus:outline-none focus:border-emerald-400 focus:ring-2 focus:ring-emerald-100" />
            <svg class="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
            <button v-if="menuSearchQuery" @click="menuSearchQuery = ''" class="absolute right-2 top-1/2 -translate-y-1/2 p-1 rounded-full hover:bg-slate-200"><svg class="h-3.5 w-3.5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg></button>
          </div>

          <div v-if="menuFilteredProducts.length === 0" class="flex flex-col items-center justify-center py-12 text-slate-400">
            <svg class="h-12 w-12 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
            <p class="text-sm font-semibold">Menu tidak ditemukan</p>
          </div>
          <div v-else class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-3 xl:grid-cols-4 gap-2">
            <button
              v-for="product in menuFilteredProducts"
              :key="product.id"
              type="button"
              @click="tapProduct(product)"
              :class="['relative rounded-xl border-2 p-3 text-left transition-all active:scale-95', getCartQty(product.id) > 0 ? 'border-emerald-400 bg-emerald-50 shadow-md' : 'border-slate-200 bg-white hover:border-emerald-300 hover:shadow']"
            >
              <div class="text-sm font-bold text-slate-900 leading-tight line-clamp-2">{{ product.name }}</div>
              <div class="mt-1 text-xs text-slate-500">{{ product.category_name }}</div>
              <div class="mt-2 text-sm font-bold text-emerald-600">{{ formatCurrency(product.price) }}</div>
              <div v-if="getCartQty(product.id) > 0" class="absolute -top-2 -right-2 flex h-7 w-7 items-center justify-center rounded-full bg-emerald-600 text-xs font-bold text-white shadow-lg">
                {{ getCartQty(product.id) }}
              </div>
            </button>
          </div>
        </div>

        <!-- Desktop Cart Sidebar (lg+) -->
        <div class="hidden lg:flex lg:w-80 xl:w-96 border-l border-slate-200 bg-slate-50 flex-col">
          <div class="px-4 py-3 border-b border-slate-200 bg-white">
            <div class="flex items-center justify-between">
              <h3 class="text-sm font-bold text-slate-700">Keranjang</h3>
              <span class="rounded-full bg-emerald-100 px-2.5 py-0.5 text-xs font-bold text-emerald-700">{{ cartItems.length }} item</span>
            </div>
          </div>
          <div class="flex-1 overflow-y-auto p-3 space-y-2">
            <div v-if="cartItems.length === 0" class="flex flex-col items-center justify-center py-8 text-slate-400">
              <svg class="h-10 w-10 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 100 4 2 2 0 000-4z" /></svg>
              <p class="text-xs font-semibold">Tap menu untuk menambahkan</p>
            </div>
            <div v-for="item in cartItems" :key="item.product_id" class="rounded-xl bg-white p-2.5 border border-slate-200">
              <div class="flex items-center gap-2">
                <div class="flex-1 min-w-0">
                  <div class="text-sm font-semibold text-slate-900 truncate">{{ item.product_name }}</div>
                  <div class="text-xs text-emerald-600 font-bold">{{ formatCurrency(getItemTotal(item)) }}</div>
                  <div v-if="item.addons?.length" class="flex flex-wrap gap-1 mt-0.5">
                    <span v-for="a in item.addons" :key="a.name" class="text-[10px] text-emerald-600 bg-emerald-50 rounded px-1">+{{ a.name }}</span>
                  </div>
                </div>
                <div class="flex items-center gap-1.5 shrink-0">
                  <button type="button" @click="cartDecrement(item.product_id)" class="flex h-8 w-8 items-center justify-center rounded-lg bg-red-100 text-red-600 active:scale-90 font-bold">−</button>
                  <div class="w-7 text-center text-sm font-black">{{ item.qty }}</div>
                  <button type="button" @click="cartIncrement(item.product_id)" class="flex h-8 w-8 items-center justify-center rounded-lg bg-emerald-600 text-white active:scale-90 font-bold">+</button>
                </div>
              </div>
              <!-- Addons toggle -->
              <div v-if="productAddonsCache[item.product_id]?.length" class="mt-1.5">
                <button type="button" @click="toggleAddonPanel(item.product_id)" class="text-xs text-slate-400 hover:text-emerald-600 flex items-center gap-1">
                  <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" /></svg>
                  Tambahan
                </button>
                <div v-if="activeAddonItem === item.product_id" class="mt-1 flex flex-wrap gap-1">
                  <button v-for="addon in productAddonsCache[item.product_id]" :key="addon.id" type="button" @click="toggleAddon(item.product_id, addon)" :class="['rounded-full border px-2.5 py-0.5 text-xs active:scale-95 transition-colors', hasAddon(item.product_id, addon.name) ? 'bg-emerald-600 border-emerald-600 text-white' : 'bg-white border-slate-300 text-slate-600 hover:border-emerald-400']">
                    {{ addon.name }} +{{ formatCurrency(addon.price) }}
                  </button>
                </div>
              </div>
              <!-- Notes toggle -->
              <div class="mt-1">
                <button type="button" @click="toggleNoteInput(item.product_id)" class="text-xs text-slate-400 hover:text-emerald-600 flex items-center gap-1">
                  <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" /></svg>
                  {{ item.notes ? item.notes : 'Catatan...' }}
                </button>
                <div v-if="activeNoteItem === item.product_id" class="mt-1.5 space-y-1.5">
                  <input v-model="item.notes" type="text" placeholder="Tulis catatan khusus..." class="w-full h-8 px-2.5 rounded-lg border border-slate-200 bg-slate-50 text-xs focus:outline-none focus:border-emerald-400" />
                  <div v-if="productNotesCache[item.product_id]?.length" class="flex flex-wrap gap-1">
                    <button v-for="note in productNotesCache[item.product_id]" :key="note.note_text" type="button" @click="appendNote(item.product_id, note.note_text)" class="rounded-full bg-emerald-50 border border-emerald-200 px-2.5 py-0.5 text-xs text-emerald-700 hover:bg-emerald-100 active:scale-95">{{ note.note_text }}</button>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div class="border-t border-slate-200 bg-white p-3 space-y-2">
            <div class="flex items-center justify-between">
              <span class="text-sm font-semibold text-slate-600">Total</span>
              <span class="text-lg font-bold text-emerald-600">Rp {{ formatCurrency(cartTotal) }}</span>
            </div>
            <button type="button" @click="submitOrder" :disabled="cartItems.length === 0 || submitting" class="w-full rounded-xl bg-emerald-600 py-3 font-bold text-white shadow-lg transition-all hover:bg-emerald-700 active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2">
              <div v-if="submitting" class="h-5 w-5 animate-spin rounded-full border-2 border-white border-t-transparent"></div>
              <svg v-else class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" /></svg>
              {{ submitting ? 'Memproses...' : 'Buat Order' }}
            </button>
          </div>
        </div>
      </div>

      <!-- Mobile Cart Bottom Bar (< lg) -->
      <div class="lg:hidden fixed bottom-0 left-0 right-0 z-10 bg-white border-t border-slate-200 shadow-[0_-4px_12px_rgba(0,0,0,0.08)]">
        <!-- Expanded cart items -->
        <div v-if="mobileCartExpanded && cartItems.length > 0" class="max-h-[50vh] overflow-y-auto p-3 space-y-2 border-b border-slate-200 bg-slate-50">
          <div v-for="item in cartItems" :key="item.product_id" class="rounded-xl bg-white p-2.5 border border-slate-200">
            <div class="flex items-center gap-2">
              <div class="flex-1 min-w-0">
                <div class="text-sm font-semibold text-slate-900 truncate">{{ item.product_name }}</div>
                <div class="text-xs text-emerald-600 font-bold">{{ formatCurrency(getItemTotal(item)) }}</div>
                <div v-if="item.addons?.length" class="flex flex-wrap gap-1 mt-0.5">
                  <span v-for="a in item.addons" :key="a.name" class="text-[10px] text-emerald-600 bg-emerald-50 rounded px-1">+{{ a.name }}</span>
                </div>
              </div>
              <div class="flex items-center gap-1.5 shrink-0">
                <button type="button" @click="cartDecrement(item.product_id)" class="flex h-8 w-8 items-center justify-center rounded-lg bg-red-100 text-red-600 active:scale-90 font-bold">−</button>
                <div class="w-7 text-center text-sm font-black">{{ item.qty }}</div>
                <button type="button" @click="cartIncrement(item.product_id)" class="flex h-8 w-8 items-center justify-center rounded-lg bg-emerald-600 text-white active:scale-90 font-bold">+</button>
              </div>
            </div>
            <div v-if="productAddonsCache[item.product_id]?.length" class="mt-1.5">
              <button type="button" @click="toggleAddonPanel(item.product_id)" class="text-xs text-slate-400 hover:text-emerald-600 flex items-center gap-1">
                <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" /></svg>
                Tambahan
              </button>
              <div v-if="activeAddonItem === item.product_id" class="mt-1 flex flex-wrap gap-1">
                <button v-for="addon in productAddonsCache[item.product_id]" :key="addon.id" type="button" @click="toggleAddon(item.product_id, addon)" :class="['rounded-full border px-2.5 py-0.5 text-xs active:scale-95 transition-colors', hasAddon(item.product_id, addon.name) ? 'bg-emerald-600 border-emerald-600 text-white' : 'bg-white border-slate-300 text-slate-600 hover:border-emerald-400']">
                  {{ addon.name }} +{{ formatCurrency(addon.price) }}
                </button>
              </div>
            </div>
            <div class="mt-1">
              <button type="button" @click="toggleNoteInput(item.product_id)" class="text-xs text-slate-400 hover:text-emerald-600 flex items-center gap-1">
                <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" /></svg>
                {{ item.notes ? item.notes : 'Catatan...' }}
              </button>
              <div v-if="activeNoteItem === item.product_id" class="mt-1.5 space-y-1.5">
                <input v-model="item.notes" type="text" placeholder="Tulis catatan khusus..." class="w-full h-8 px-2.5 rounded-lg border border-slate-200 bg-slate-50 text-xs focus:outline-none focus:border-emerald-400" />
                <div v-if="productNotesCache[item.product_id]?.length" class="flex flex-wrap gap-1">
                  <button v-for="note in productNotesCache[item.product_id]" :key="note.note_text" type="button" @click="appendNote(item.product_id, note.note_text)" class="rounded-full bg-emerald-50 border border-emerald-200 px-2.5 py-0.5 text-xs text-emerald-700 hover:bg-emerald-100 active:scale-95">{{ note.note_text }}</button>
                </div>
              </div>
            </div>
          </div>
        </div>
        <!-- Summary bar -->
        <div class="flex items-center gap-2 px-3 py-2">
          <button v-if="cartItems.length > 0" type="button" @click="mobileCartExpanded = !mobileCartExpanded" class="flex items-center gap-2 flex-1 min-w-0 py-1">
            <span class="flex h-7 w-7 items-center justify-center rounded-full bg-emerald-600 text-xs font-bold text-white shrink-0">{{ cartItems.length }}</span>
            <span class="text-sm font-bold text-slate-700 truncate">Rp {{ formatCurrency(cartTotal) }}</span>
            <svg :class="['h-4 w-4 text-slate-400 shrink-0 transition-transform', mobileCartExpanded ? 'rotate-180' : '']" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" /></svg>
          </button>
          <div v-else class="flex-1 text-sm text-slate-400 py-1">Tap menu untuk menambahkan</div>
          <button type="button" @click="submitOrder" :disabled="cartItems.length === 0 || submitting" class="shrink-0 rounded-xl bg-emerald-600 px-5 py-2.5 text-sm font-bold text-white shadow-lg transition-all hover:bg-emerald-700 active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2">
            <div v-if="submitting" class="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent"></div>
            <svg v-else class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" /></svg>
            {{ submitting ? '...' : 'Buat Order' }}
          </button>
        </div>
      </div>
    </div>

    <!-- ==================== VIEW ORDER MODAL ==================== -->
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
                  @click="openMoveTableModal"
                  :disabled="moveTableCandidates.length === 0 || currentOrder.order.is_merged"
                  class="btn-secondary flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
                  </svg>
                  Pindah Meja
                </button>
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
                      <div v-if="item.waiter_name" class="mt-1 flex items-center gap-1.5 text-xs text-slate-400">
                        <svg class="h-3.5 w-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                        </svg>
                        <span>{{ item.waiter_name }}</span>
                      </div>
                    </div>
                    <div class="text-right">
                      <div class="font-bold text-slate-900">{{ formatCurrency(item.price * item.qty) }}</div>
                      <div class="mt-1 flex items-center justify-end gap-1.5 flex-wrap">
                        <span v-if="item.is_additional" class="rounded-full px-2 py-0.5 text-xs font-semibold bg-amber-100 text-amber-700">Tambahan</span>
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

  <!-- ==================== MERGE MODAL ==================== -->
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

  <!-- ==================== MOVE TABLE MODAL ==================== -->
  <div v-if="showMoveTableModal" class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-slate-900/60 sm:px-4" @click="closeMoveTableModal">
    <div class="w-full max-w-2xl rounded-t-3xl sm:rounded-3xl bg-white shadow-soft max-h-[90vh] overflow-hidden flex flex-col" @click.stop>
      <div class="flex items-center justify-between border-b border-slate-100 px-4 sm:px-6 py-3 sm:py-4 sticky top-0 bg-white z-10">
        <div class="flex items-center gap-3">
          <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-blue-100">
            <svg class="h-6 w-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
            </svg>
          </div>
          <div>
            <h2 class="text-base sm:text-lg font-bold text-slate-900">Pindah Meja</h2>
            <p class="text-xs sm:text-sm text-slate-500">Dari: Meja {{ selectedTable?.table_number }}</p>
          </div>
        </div>
        <button @click="closeMoveTableModal" class="flex h-9 w-9 items-center justify-center rounded-lg bg-slate-100 text-slate-600 transition hover:bg-slate-200">
          <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <div class="overflow-y-auto flex-1 p-4 sm:p-6">
        <div class="space-y-3">
          <div class="rounded-2xl border-2 border-slate-200 bg-slate-50/60 p-3 sm:p-4">
            <div class="text-xs font-semibold text-slate-500">Pilih meja tujuan</div>
            <div class="text-sm font-bold text-slate-900">Pilih 1 meja kosong untuk memindahkan order</div>
          </div>

          <div v-if="moveTableCandidates.length === 0" class="rounded-2xl border-2 border-slate-200 p-6 text-center text-sm text-slate-500">
            Tidak ada meja kosong yang tersedia
          </div>

          <div v-else class="grid grid-cols-3 sm:grid-cols-4 gap-2">
            <button
              v-for="table in moveTableCandidates"
              :key="table.id"
              type="button"
              @click="moveTargetTable = table"
              :class="[
                'rounded-2xl border-2 p-3 sm:p-4 text-center transition',
                moveTargetTable?.id === table.id
                  ? 'border-blue-500 bg-blue-50 ring-2 ring-blue-200'
                  : 'border-slate-200 hover:border-blue-300 hover:bg-blue-50/50'
              ]"
            >
              <div class="text-lg sm:text-xl font-bold" :class="moveTargetTable?.id === table.id ? 'text-blue-600' : 'text-slate-700'">{{ table.table_number }}</div>
              <div class="text-xs text-slate-500 mt-1">Kapasitas {{ table.capacity }}</div>
            </button>
          </div>
        </div>
      </div>

      <div class="border-t border-slate-100 p-4 sm:p-6">
        <div v-if="moveTargetTable" class="mb-3 rounded-xl bg-blue-50 p-3 text-center">
          <span class="text-sm text-blue-700">Meja <strong>{{ selectedTable?.table_number }}</strong> → Meja <strong>{{ moveTargetTable.table_number }}</strong></span>
        </div>
        <div class="flex flex-col sm:flex-row gap-2 sm:justify-end">
          <button type="button" @click="closeMoveTableModal" class="btn-secondary">Batal</button>
          <button
            type="button"
            @click="submitMoveTable"
            :disabled="!moveTargetTable || movingTable"
            class="btn-primary flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <div v-if="movingTable" class="h-5 w-5 animate-spin rounded-full border-2 border-white border-t-transparent"></div>
            {{ movingTable ? 'Memproses...' : 'Pindahkan Meja' }}
          </button>
        </div>
      </div>
    </div>
  </div>

  <!-- ==================== ADD ITEMS MODAL (Full-screen menu, same pattern) ==================== -->
  <div v-if="showAddItemsModal" class="fixed inset-0 z-50 flex flex-col bg-white">
    <!-- Top Bar -->
    <div class="flex items-center justify-between border-b border-slate-200 px-4 py-3 bg-gradient-to-r from-indigo-600 to-indigo-500">
      <div class="flex items-center gap-3">
        <button @click="closeAddItemsModal(true)" class="flex h-9 w-9 items-center justify-center rounded-lg bg-white/20 text-white transition hover:bg-white/30">
          <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <div>
          <h2 class="text-base font-bold text-white">Tambah Pesanan — Meja {{ selectedTable?.table_number }}</h2>
          <p class="text-xs text-indigo-100">{{ currentOrder?.order?.customer_name || 'Tamu' }}</p>
        </div>
      </div>
    </div>

    <!-- Category Tabs -->
    <div class="border-b border-slate-200 bg-white">
      <div class="flex overflow-x-auto gap-1 px-3 py-2 no-scrollbar">
        <button
          @click="addMenuCategory = 'all'"
          :class="['whitespace-nowrap rounded-full px-4 py-2 text-sm font-bold transition-all shrink-0', addMenuCategory === 'all' ? 'bg-indigo-600 text-white shadow-md' : 'bg-slate-100 text-slate-600 hover:bg-slate-200']"
        >Semua</button>
        <button
          v-for="cat in categories"
          :key="cat"
          @click="addMenuCategory = cat"
          :class="['whitespace-nowrap rounded-full px-4 py-2 text-sm font-bold transition-all shrink-0', addMenuCategory === cat ? 'bg-indigo-600 text-white shadow-md' : 'bg-slate-100 text-slate-600 hover:bg-slate-200']"
        >{{ cat }}</button>
      </div>
    </div>

    <!-- Menu Grid + Cart -->
    <div class="flex-1 flex flex-col lg:flex-row overflow-hidden">
      <!-- Product Grid -->
      <div class="flex-1 overflow-y-auto p-3 pb-20 lg:pb-3">
        <div class="relative mb-3">
          <input v-model="addMenuSearchQuery" type="text" placeholder="Cari menu cepat..." class="w-full h-10 pl-9 pr-8 rounded-xl border border-slate-200 bg-slate-50 text-sm focus:outline-none focus:border-indigo-400 focus:ring-2 focus:ring-indigo-100" />
          <svg class="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
          <button v-if="addMenuSearchQuery" @click="addMenuSearchQuery = ''" class="absolute right-2 top-1/2 -translate-y-1/2 p-1 rounded-full hover:bg-slate-200"><svg class="h-3.5 w-3.5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg></button>
        </div>

        <div v-if="addMenuFilteredProducts.length === 0" class="flex flex-col items-center justify-center py-12 text-slate-400">
          <svg class="h-12 w-12 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
          <p class="text-sm font-semibold">Menu tidak ditemukan</p>
        </div>
        <div v-else class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-3 xl:grid-cols-4 gap-2">
          <button
            v-for="product in addMenuFilteredProducts"
            :key="product.id"
            type="button"
            @click="tapAddProduct(product)"
            :class="['relative rounded-xl border-2 p-3 text-left transition-all active:scale-95', getAddCartQty(product.id) > 0 ? 'border-indigo-400 bg-indigo-50 shadow-md' : 'border-slate-200 bg-white hover:border-indigo-300 hover:shadow']"
          >
            <div class="text-sm font-bold text-slate-900 leading-tight line-clamp-2">{{ product.name }}</div>
            <div class="mt-1 text-xs text-slate-500">{{ product.category_name }}</div>
            <div class="mt-2 text-sm font-bold text-indigo-600">{{ formatCurrency(product.price) }}</div>
            <div v-if="getAddCartQty(product.id) > 0" class="absolute -top-2 -right-2 flex h-7 w-7 items-center justify-center rounded-full bg-indigo-600 text-xs font-bold text-white shadow-lg">
              {{ getAddCartQty(product.id) }}
            </div>
          </button>
        </div>
      </div>

      <!-- Desktop Add Cart Sidebar (lg+) -->
      <div class="hidden lg:flex lg:w-80 xl:w-96 border-l border-slate-200 bg-slate-50 flex-col">
        <div class="px-4 py-3 border-b border-slate-200 bg-white">
          <div class="flex items-center justify-between">
            <h3 class="text-sm font-bold text-slate-700">Tambahan</h3>
            <span class="rounded-full bg-indigo-100 px-2.5 py-0.5 text-xs font-bold text-indigo-700">{{ addCartItems.length }} item</span>
          </div>
        </div>
        <div class="flex-1 overflow-y-auto p-3 space-y-2">
          <div v-if="addCartItems.length === 0" class="flex flex-col items-center justify-center py-8 text-slate-400">
            <svg class="h-10 w-10 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 100 4 2 2 0 000-4z" /></svg>
            <p class="text-xs font-semibold">Tap menu untuk menambahkan</p>
          </div>
          <div v-for="item in addCartItems" :key="item.product_id" class="rounded-xl bg-white p-2.5 border border-slate-200">
            <div class="flex items-center gap-2">
              <div class="flex-1 min-w-0">
                <div class="text-sm font-semibold text-slate-900 truncate">{{ item.product_name }}</div>
                <div class="text-xs text-indigo-600 font-bold">{{ formatCurrency(getItemTotal(item)) }}</div>
                <div v-if="item.addons?.length" class="flex flex-wrap gap-1 mt-0.5">
                  <span v-for="a in item.addons" :key="a.name" class="text-[10px] text-indigo-600 bg-indigo-50 rounded px-1">+{{ a.name }}</span>
                </div>
              </div>
              <div class="flex items-center gap-1.5 shrink-0">
                <button type="button" @click="addCartDecrement(item.product_id)" class="flex h-8 w-8 items-center justify-center rounded-lg bg-red-100 text-red-600 active:scale-90 font-bold">−</button>
                <div class="w-7 text-center text-sm font-black">{{ item.qty }}</div>
                <button type="button" @click="addCartIncrement(item.product_id)" class="flex h-8 w-8 items-center justify-center rounded-lg bg-indigo-600 text-white active:scale-90 font-bold">+</button>
              </div>
            </div>
            <div v-if="productAddonsCache[item.product_id]?.length" class="mt-1.5">
              <button type="button" @click="toggleAddonPanel(item.product_id, true)" class="text-xs text-slate-400 hover:text-indigo-600 flex items-center gap-1">
                <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" /></svg>
                Tambahan
              </button>
              <div v-if="activeAddAddonItem === item.product_id" class="mt-1 flex flex-wrap gap-1">
                <button v-for="addon in productAddonsCache[item.product_id]" :key="addon.id" type="button" @click="toggleAddon(item.product_id, addon, true)" :class="['rounded-full border px-2.5 py-0.5 text-xs active:scale-95 transition-colors', hasAddon(item.product_id, addon.name, true) ? 'bg-indigo-600 border-indigo-600 text-white' : 'bg-white border-slate-300 text-slate-600 hover:border-indigo-400']">
                  {{ addon.name }} +{{ formatCurrency(addon.price) }}
                </button>
              </div>
            </div>
            <div class="mt-1">
              <button type="button" @click="toggleNoteInput(item.product_id, true)" class="text-xs text-slate-400 hover:text-indigo-600 flex items-center gap-1">
                <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" /></svg>
                {{ item.notes ? item.notes : 'Catatan...' }}
              </button>
              <div v-if="activeAddNoteItem === item.product_id" class="mt-1.5 space-y-1.5">
                <input v-model="item.notes" type="text" placeholder="Tulis catatan khusus..." class="w-full h-8 px-2.5 rounded-lg border border-slate-200 bg-slate-50 text-xs focus:outline-none focus:border-indigo-400" />
                <div v-if="productNotesCache[item.product_id]?.length" class="flex flex-wrap gap-1">
                  <button v-for="note in productNotesCache[item.product_id]" :key="note.note_text" type="button" @click="appendNote(item.product_id, note.note_text, true)" class="rounded-full bg-indigo-50 border border-indigo-200 px-2.5 py-0.5 text-xs text-indigo-700 hover:bg-indigo-100 active:scale-95">{{ note.note_text }}</button>
                </div>
              </div>
            </div>
          </div>
        </div>
        <div class="border-t border-slate-200 bg-white p-3 space-y-2">
          <div class="flex items-center justify-between">
            <span class="text-sm font-semibold text-slate-600">Total Tambahan</span>
            <span class="text-lg font-bold text-indigo-600">Rp {{ formatCurrency(addCartTotal) }}</span>
          </div>
          <button type="button" @click="submitAddItems" :disabled="addCartItems.length === 0 || addingItems" class="w-full rounded-xl bg-indigo-600 py-3 font-bold text-white shadow-lg transition-all hover:bg-indigo-700 active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2">
            <div v-if="addingItems" class="h-5 w-5 animate-spin rounded-full border-2 border-white border-t-transparent"></div>
            <svg v-else class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" /></svg>
            {{ addingItems ? 'Memproses...' : 'Tambah Pesanan' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Mobile Add Cart Bottom Bar (< lg) -->
    <div class="lg:hidden fixed bottom-0 left-0 right-0 z-10 bg-white border-t border-slate-200 shadow-[0_-4px_12px_rgba(0,0,0,0.08)]">
      <div v-if="mobileAddCartExpanded && addCartItems.length > 0" class="max-h-[50vh] overflow-y-auto p-3 space-y-2 border-b border-slate-200 bg-slate-50">
        <div v-for="item in addCartItems" :key="item.product_id" class="rounded-xl bg-white p-2.5 border border-slate-200">
          <div class="flex items-center gap-2">
            <div class="flex-1 min-w-0">
              <div class="text-sm font-semibold text-slate-900 truncate">{{ item.product_name }}</div>
              <div class="text-xs text-indigo-600 font-bold">{{ formatCurrency(getItemTotal(item)) }}</div>
              <div v-if="item.addons?.length" class="flex flex-wrap gap-1 mt-0.5">
                <span v-for="a in item.addons" :key="a.name" class="text-[10px] text-indigo-600 bg-indigo-50 rounded px-1">+{{ a.name }}</span>
              </div>
            </div>
            <div class="flex items-center gap-1.5 shrink-0">
              <button type="button" @click="addCartDecrement(item.product_id)" class="flex h-8 w-8 items-center justify-center rounded-lg bg-red-100 text-red-600 active:scale-90 font-bold">−</button>
              <div class="w-7 text-center text-sm font-black">{{ item.qty }}</div>
              <button type="button" @click="addCartIncrement(item.product_id)" class="flex h-8 w-8 items-center justify-center rounded-lg bg-indigo-600 text-white active:scale-90 font-bold">+</button>
            </div>
          </div>
          <div v-if="productAddonsCache[item.product_id]?.length" class="mt-1.5">
            <button type="button" @click="toggleAddonPanel(item.product_id, true)" class="text-xs text-slate-400 hover:text-indigo-600 flex items-center gap-1">
              <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" /></svg>
              Tambahan
            </button>
            <div v-if="activeAddAddonItem === item.product_id" class="mt-1 flex flex-wrap gap-1">
              <button v-for="addon in productAddonsCache[item.product_id]" :key="addon.id" type="button" @click="toggleAddon(item.product_id, addon, true)" :class="['rounded-full border px-2.5 py-0.5 text-xs active:scale-95 transition-colors', hasAddon(item.product_id, addon.name, true) ? 'bg-indigo-600 border-indigo-600 text-white' : 'bg-white border-slate-300 text-slate-600 hover:border-indigo-400']">
                {{ addon.name }} +{{ formatCurrency(addon.price) }}
              </button>
            </div>
          </div>
          <div class="mt-1">
            <button type="button" @click="toggleNoteInput(item.product_id, true)" class="text-xs text-slate-400 hover:text-indigo-600 flex items-center gap-1">
              <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" /></svg>
              {{ item.notes ? item.notes : 'Catatan...' }}
            </button>
            <div v-if="activeAddNoteItem === item.product_id" class="mt-1.5 space-y-1.5">
              <input v-model="item.notes" type="text" placeholder="Tulis catatan khusus..." class="w-full h-8 px-2.5 rounded-lg border border-slate-200 bg-slate-50 text-xs focus:outline-none focus:border-indigo-400" />
              <div v-if="productNotesCache[item.product_id]?.length" class="flex flex-wrap gap-1">
                <button v-for="note in productNotesCache[item.product_id]" :key="note.note_text" type="button" @click="appendNote(item.product_id, note.note_text, true)" class="rounded-full bg-indigo-50 border border-indigo-200 px-2.5 py-0.5 text-xs text-indigo-700 hover:bg-indigo-100 active:scale-95">{{ note.note_text }}</button>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div class="flex items-center gap-2 px-3 py-2">
        <button v-if="addCartItems.length > 0" type="button" @click="mobileAddCartExpanded = !mobileAddCartExpanded" class="flex items-center gap-2 flex-1 min-w-0 py-1">
          <span class="flex h-7 w-7 items-center justify-center rounded-full bg-indigo-600 text-xs font-bold text-white shrink-0">{{ addCartItems.length }}</span>
          <span class="text-sm font-bold text-slate-700 truncate">Rp {{ formatCurrency(addCartTotal) }}</span>
          <svg :class="['h-4 w-4 text-slate-400 shrink-0 transition-transform', mobileAddCartExpanded ? 'rotate-180' : '']" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" /></svg>
        </button>
        <div v-else class="flex-1 text-sm text-slate-400 py-1">Tap menu untuk menambahkan</div>
        <button type="button" @click="submitAddItems" :disabled="addCartItems.length === 0 || addingItems" class="shrink-0 rounded-xl bg-indigo-600 px-5 py-2.5 text-sm font-bold text-white shadow-lg transition-all hover:bg-indigo-700 active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2">
          <div v-if="addingItems" class="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent"></div>
          <svg v-else class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" /></svg>
          {{ addingItems ? '...' : 'Tambah' }}
        </button>
      </div>
    </div>
  </div>

  <!-- ==================== IDLE COUNTDOWN OVERLAY ==================== -->
  <div v-if="showIdleCountdown" class="fixed inset-0 z-[100] flex items-center justify-center bg-slate-900/70" @click="dismissCountdown">
    <div class="text-center" @click.stop>
      <div class="relative mx-auto mb-6 flex h-32 w-32 items-center justify-center">
        <svg class="absolute inset-0 h-32 w-32 -rotate-90" viewBox="0 0 128 128">
          <circle cx="64" cy="64" r="58" fill="none" stroke="#334155" stroke-width="8" />
          <circle cx="64" cy="64" r="58" fill="none" stroke="#ef4444" stroke-width="8"
            stroke-linecap="round"
            :stroke-dasharray="364.4"
            :stroke-dashoffset="364.4 * (1 - idleCountdown / 10)"
            class="transition-all duration-1000 ease-linear" />
        </svg>
        <span class="text-5xl font-black text-white">{{ idleCountdown }}</span>
      </div>
      <p class="text-lg font-bold text-white">Sesi akan berakhir</p>
      <p class="mt-1 text-sm text-slate-300">Tap layar untuk tetap login</p>
      <button @click="dismissCountdown" class="mt-6 rounded-xl bg-emerald-600 px-8 py-3 font-bold text-white shadow-lg transition hover:bg-emerald-700 active:scale-95">
        Tetap Login
      </button>
    </div>
  </div>
</template>
<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import api, { subscribeRealtime } from '../services/api'
import { useNotification } from '../composables/useNotification'
import { useAuthStore } from '../stores/auth'
import { formatNumber } from '../utils/currency'
import { getOrderStatusText, getItemStatusText, orderStatusClass, itemStatusClass, destinationClass } from '../utils/status'

const router = useRouter()
const authStore = useAuthStore()
const { success: showSuccess, error: showError } = useNotification()

// === Core state ===
const loading = ref(false)
const allTables = ref([])
const availableTables = ref([])
const occupiedTables = ref([])
const activeOrders = ref(0)
const products = ref([])
const searchingCustomer = ref(false)
const customerFound = ref(false)
const customerSearchTimer = ref(null)
const tableSearchQuery = ref('')
const filterStatus = ref('all')
const selectedTable = ref(null)
const showOrderModal = ref(false)
const showViewOrderModal = ref(false)
const showAddItemsModal = ref(false)
const showMergeModal = ref(false)
const showMoveTableModal = ref(false)
const submitting = ref(false)
const addingItems = ref(false)
const merging = ref(false)
const movingTable = ref(false)
const moveTargetTable = ref(null)
const loadingOrder = ref(false)
const currentOrder = ref(null)
const mergeSelections = ref([])
const targetSpendPerPax = ref(0)
let realtimeUnsubscribe = null

// === Create Order: customer + cart ===
const showCustomerPanel = ref(true)
const menuCategory = ref('all')
const menuSearchQuery = ref('')
const orderForm = ref({
  customer_name: '',
  customer_phone: '',
  pax: 1
})
// Cart: array of { product_id, product_name, price, qty, notes }
const cartItems = ref([])
const mobileCartExpanded = ref(false)

// === Add Items: cart ===
const addMenuCategory = ref('all')
const addMenuSearchQuery = ref('')
const addCartItems = ref([])
const mobileAddCartExpanded = ref(false)

// === Notes (special requests) ===
const productNotesCache = ref({}) // { productId: [{ note_text, usage_count }] }
const activeNoteItem = ref(null) // product_id of currently editing notes
const activeAddNoteItem = ref(null)

// === Addons (additional items with prices) ===
const productAddonsCache = ref({}) // { productId: [{ id, name, price }] }
const activeAddonItem = ref(null)
const activeAddAddonItem = ref(null)

// === Derived: categories from products ===
const categories = computed(() => {
  const cats = new Set()
  products.value.forEach(p => {
    if (p.category_name) cats.add(p.category_name)
  })
  return Array.from(cats).sort()
})

// === Menu filtering for Create Order ===
const menuFilteredProducts = computed(() => {
  let list = products.value
  if (menuCategory.value !== 'all') {
    list = list.filter(p => p.category_name === menuCategory.value)
  }
  if (menuSearchQuery.value.trim()) {
    const q = menuSearchQuery.value.toLowerCase().trim()
    list = list.filter(p =>
      p.name.toLowerCase().includes(q) ||
      (p.code && p.code.toLowerCase().includes(q))
    )
  }
  return list
})

// === Menu filtering for Add Items ===
const addMenuFilteredProducts = computed(() => {
  let list = products.value
  if (addMenuCategory.value !== 'all') {
    list = list.filter(p => p.category_name === addMenuCategory.value)
  }
  if (addMenuSearchQuery.value.trim()) {
    const q = addMenuSearchQuery.value.toLowerCase().trim()
    list = list.filter(p =>
      p.name.toLowerCase().includes(q) ||
      (p.code && p.code.toLowerCase().includes(q))
    )
  }
  return list
})

// === Cart helpers for Create Order ===
const getCartQty = (productId) => {
  const item = cartItems.value.find(i => i.product_id === productId)
  return item ? item.qty : 0
}

const tapProduct = (product) => {
  const existing = cartItems.value.find(i => i.product_id === product.id)
  if (existing) {
    existing.qty++
  } else {
    cartItems.value.push({
      product_id: product.id,
      product_name: product.name,
      price: product.price,
      qty: 1,
      notes: '',
      addons: []
    })
    fetchProductNotes(product.id)
    fetchProductAddons(product.id)
  }
}

const cartIncrement = (productId) => {
  const item = cartItems.value.find(i => i.product_id === productId)
  if (item) item.qty++
}

const cartDecrement = (productId) => {
  const idx = cartItems.value.findIndex(i => i.product_id === productId)
  if (idx === -1) return
  if (cartItems.value[idx].qty > 1) {
    cartItems.value[idx].qty--
  } else {
    cartItems.value.splice(idx, 1)
  }
}

const cartTotal = computed(() => {
  return cartItems.value.reduce((sum, i) => {
    const addonTotal = (i.addons || []).reduce((s, a) => s + a.price, 0)
    return sum + (i.price + addonTotal) * i.qty
  }, 0)
})

// === Cart helpers for Add Items ===
const getAddCartQty = (productId) => {
  const item = addCartItems.value.find(i => i.product_id === productId)
  return item ? item.qty : 0
}

const tapAddProduct = (product) => {
  const existing = addCartItems.value.find(i => i.product_id === product.id)
  if (existing) {
    existing.qty++
  } else {
    addCartItems.value.push({
      product_id: product.id,
      product_name: product.name,
      price: product.price,
      qty: 1,
      notes: '',
      addons: []
    })
    fetchProductNotes(product.id)
    fetchProductAddons(product.id)
  }
}

const addCartIncrement = (productId) => {
  const item = addCartItems.value.find(i => i.product_id === productId)
  if (item) item.qty++
}

const addCartDecrement = (productId) => {
  const idx = addCartItems.value.findIndex(i => i.product_id === productId)
  if (idx === -1) return
  if (addCartItems.value[idx].qty > 1) {
    addCartItems.value[idx].qty--
  } else {
    addCartItems.value.splice(idx, 1)
  }
}

const addCartTotal = computed(() => {
  return addCartItems.value.reduce((sum, i) => {
    const addonTotal = (i.addons || []).reduce((s, a) => s + a.price, 0)
    return sum + (i.price + addonTotal) * i.qty
  }, 0)
})

// === Product notes (special requests) ===
const fetchProductNotes = async (productId) => {
  if (productNotesCache.value[productId]) return
  try {
    const response = await api.get(`/products/${productId}/notes`)
    productNotesCache.value[productId] = response.data.data || []
  } catch {
    productNotesCache.value[productId] = []
  }
}

const toggleNoteInput = (productId, isAdd = false) => {
  if (isAdd) {
    activeAddNoteItem.value = activeAddNoteItem.value === productId ? null : productId
  } else {
    activeNoteItem.value = activeNoteItem.value === productId ? null : productId
  }
  fetchProductNotes(productId)
}

const appendNote = (productId, noteText, isAdd = false) => {
  const items = isAdd ? addCartItems.value : cartItems.value
  const item = items.find(i => i.product_id === productId)
  if (!item) return
  if (item.notes) {
    // Don't duplicate
    const existing = item.notes.split(',').map(s => s.trim().toLowerCase())
    if (existing.includes(noteText.toLowerCase())) return
    item.notes += ', ' + noteText
  } else {
    item.notes = noteText
  }
}

// === Product addons (additional items with prices) ===
const fetchProductAddons = async (productId) => {
  if (productAddonsCache.value[productId]) return
  try {
    const response = await api.get(`/products/${productId}/addons`)
    productAddonsCache.value[productId] = response.data.data || []
  } catch {
    productAddonsCache.value[productId] = []
  }
}

const toggleAddonPanel = (productId, isAdd = false) => {
  if (isAdd) {
    activeAddAddonItem.value = activeAddAddonItem.value === productId ? null : productId
  } else {
    activeAddonItem.value = activeAddonItem.value === productId ? null : productId
  }
  fetchProductAddons(productId)
}

const toggleAddon = (productId, addon, isAdd = false) => {
  const items = isAdd ? addCartItems.value : cartItems.value
  const item = items.find(i => i.product_id === productId)
  if (!item) return
  if (!item.addons) item.addons = []
  const idx = item.addons.findIndex(a => a.name === addon.name)
  if (idx >= 0) {
    item.addons.splice(idx, 1)
  } else {
    item.addons.push({ name: addon.name, price: addon.price })
  }
}

const hasAddon = (productId, addonName, isAdd = false) => {
  const items = isAdd ? addCartItems.value : cartItems.value
  const item = items.find(i => i.product_id === productId)
  if (!item || !item.addons) return false
  return item.addons.some(a => a.name === addonName)
}

const getItemTotal = (item) => {
  const addonTotal = (item.addons || []).reduce((s, a) => s + a.price, 0)
  return (item.price + addonTotal) * item.qty
}

// === Table filtering ===
const filteredTables = computed(() => {
  let tables = []
  if (filterStatus.value === 'all') tables = allTables.value
  else if (filterStatus.value === 'available') tables = availableTables.value
  else if (filterStatus.value === 'occupied') tables = occupiedTables.value
  else tables = allTables.value

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

const moveTableCandidates = computed(() => {
  return availableTables.value.filter(table => table.status === 'available')
})

// === Data fetching ===
const refreshData = async (showLoading = true) => {
  if (showLoading) loading.value = true
  try {
    await Promise.all([fetchAllTables(), fetchProducts(), fetchOutletConfig()])
  } finally {
    if (showLoading) loading.value = false
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
  if (customerSearchTimer.value) clearTimeout(customerSearchTimer.value)

  if (!orderForm.value.customer_phone || orderForm.value.customer_phone.length < 10) {
    customerFound.value = false
    orderForm.value.customer_name = ''
    return
  }

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
      if (error.response?.status === 404) {
        customerFound.value = false
      } else {
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
      if (hasActiveOrder) return { ...table, status: 'occupied' }
      if (table.status === 'reserved') return table
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

// === Table selection / modals ===
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
  menuCategory.value = 'all'
  menuSearchQuery.value = ''
  showCustomerPanel.value = true
  mobileCartExpanded.value = false
  orderForm.value = { customer_name: '', customer_phone: '', pax: 1 }
  cartItems.value = []
  activeNoteItem.value = null
  activeAddonItem.value = null
}

const switchWaiter = async () => {
  await authStore.logout()
  router.push('/login')
}

// === Idle auto-logout with countdown (waiter role only) ===
const IDLE_TIMEOUT = 10 * 1000
const COUNTDOWN_SECONDS = 10
const showIdleCountdown = ref(false)
const idleCountdown = ref(COUNTDOWN_SECONDS)
let lastActivity = Date.now()
let idleCheckInterval = null
let countdownInterval = null

const onUserActivity = () => {
  lastActivity = Date.now()
  if (showIdleCountdown.value) {
    dismissCountdown()
  }
}

const startCountdown = () => {
  showIdleCountdown.value = true
  idleCountdown.value = COUNTDOWN_SECONDS
  countdownInterval = setInterval(async () => {
    idleCountdown.value--
    if (idleCountdown.value <= 0) {
      clearInterval(countdownInterval)
      countdownInterval = null
      showIdleCountdown.value = false
      await authStore.logout()
      router.push('/login')
    }
  }, 1000)
}

const dismissCountdown = () => {
  showIdleCountdown.value = false
  if (countdownInterval) {
    clearInterval(countdownInterval)
    countdownInterval = null
  }
  lastActivity = Date.now()
}

const startIdleWatch = () => {
  if (authStore.user?.role !== 'waiter') return
  const events = ['touchstart', 'pointerdown', 'keydown']
  events.forEach(e => document.addEventListener(e, onUserActivity, { passive: true }))
  lastActivity = Date.now()
  idleCheckInterval = setInterval(() => {
    if (showIdleCountdown.value) return
    if (Date.now() - lastActivity >= IDLE_TIMEOUT) {
      startCountdown()
    }
  }, 1000)
}

const stopIdleWatch = () => {
  if (idleCheckInterval) clearInterval(idleCheckInterval)
  if (countdownInterval) clearInterval(countdownInterval)
  const events = ['touchstart', 'pointerdown', 'keydown']
  events.forEach(e => document.removeEventListener(e, onUserActivity))
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

const openMoveTableModal = () => {
  moveTargetTable.value = null
  showMoveTableModal.value = true
}

const closeMoveTableModal = () => {
  showMoveTableModal.value = false
  moveTargetTable.value = null
}

const openAddItemsModal = () => {
  showViewOrderModal.value = false
  showAddItemsModal.value = true
  addMenuCategory.value = 'all'
  addMenuSearchQuery.value = ''
  addCartItems.value = []
  mobileAddCartExpanded.value = false
}

const closeAddItemsModal = (reopen) => {
  showAddItemsModal.value = false
  mobileAddCartExpanded.value = false
  activeAddNoteItem.value = null
  activeAddAddonItem.value = null
  if (reopen && currentOrder.value) {
    showViewOrderModal.value = true
  } else if (!reopen) {
    selectedTable.value = null
    currentOrder.value = null
  }
}

// === Submit Order (cart-based) ===
const submitOrder = async () => {
  submitting.value = true
  try {
    if (cartItems.value.length === 0) {
      showError('Tambahkan minimal 1 menu')
      submitting.value = false
      return
    }

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
      waiter_name: authStore.user?.full_name || '',
      items: cartItems.value.map(item => ({
        product_id: item.product_id,
        qty: item.qty,
        notes: item.notes || '',
        addons: (item.addons || []).map(a => ({ name: a.name, price: a.price }))
      }))
    }

    await api.post('/orders', payload)
    showSuccess('Order berhasil dibuat!')
    closeOrderModal()
    await refreshData()
  } catch (error) {
    console.error('Submit error:', error)
    showError('Gagal membuat order: ' + (error.response?.data?.message || error.message))
  } finally {
    submitting.value = false
  }
}

// === Submit Add Items (cart-based) ===
const submitAddItems = async () => {
  addingItems.value = true
  try {
    if (addCartItems.value.length === 0) {
      showError('Tambahkan minimal 1 menu')
      addingItems.value = false
      return
    }

    if (!selectedTable.value || !selectedTable.value.id) {
      showError('Meja belum dipilih atau data meja tidak valid')
      addingItems.value = false
      return
    }

    const payload = {
      waiter_name: authStore.user?.full_name || '',
      items: addCartItems.value.map(item => ({
        product_id: item.product_id,
        qty: item.qty,
        notes: item.notes || '',
        addons: (item.addons || []).map(a => ({ name: a.name, price: a.price }))
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

const submitMoveTable = async () => {
  if (!currentOrder.value?.order?.id) {
    showError('Data order tidak valid')
    return
  }
  if (!moveTargetTable.value) {
    showError('Pilih meja tujuan')
    return
  }

  movingTable.value = true
  try {
    await api.put(`/orders/${currentOrder.value.order.id}/move-table`, {
      new_table_number: String(moveTargetTable.value.table_number)
    })
    showSuccess(`Berhasil pindah ke Meja ${moveTargetTable.value.table_number}`)
    closeMoveTableModal()
    showViewOrderModal.value = false
    selectedTable.value = null
    currentOrder.value = null
    await refreshData()
  } catch (error) {
    showError('Gagal pindah meja: ' + (error.response?.data?.message || error.message))
  } finally {
    movingTable.value = false
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

// === Utilities ===
const getStatusText = (status) => {
  const map = { available: 'Tersedia', occupied: 'Terisi', reserved: 'Reservasi' }
  return map[status] || status
}

const formatCurrency = formatNumber

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

// === Realtime ===
const handleRealtimeEvent = async (event) => {
  if (!event?.type) return
  if (
    event.type === 'order_created' ||
    event.type === 'order_items_updated' ||
    event.type === 'orders_merged' ||
    event.type === 'table_moved' ||
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
  startIdleWatch()
})

onUnmounted(() => {
  if (realtimeUnsubscribe) realtimeUnsubscribe()
  stopIdleWatch()
})
</script>
