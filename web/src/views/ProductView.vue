<template>
  <div class="min-h-screen pb-20 lg:pb-6">
    <div class="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
      <!-- Header Card -->
      <div class="mb-6 overflow-hidden rounded-2xl bg-gradient-to-r from-emerald-600 to-emerald-500 p-6 shadow-xl">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div class="flex items-center gap-4">
            <button @click="goBack" class="flex h-10 w-10 items-center justify-center rounded-xl bg-white/20 text-white backdrop-blur-sm transition-all hover:bg-white/30 hover:scale-105 active:scale-95">
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
              </svg>
            </button>
            <div>
              <h1 class="text-2xl font-bold text-white">Kelola Produk</h1>
              <p class="mt-1 text-sm text-emerald-100">Manage produk dan kategori</p>
            </div>
          </div>
          <div class="flex w-full flex-col gap-2 sm:w-auto sm:flex-row sm:items-center">
            <button
              v-if="selectedProducts.length > 0"
              @click="bulkDeleteProducts"
              class="flex items-center justify-center gap-2 rounded-xl bg-red-600 px-4 py-2.5 font-semibold text-white shadow-lg transition-all hover:bg-red-700 hover:scale-105 active:scale-95"
            >
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
              </svg>
              Hapus {{ selectedProducts.length }} Produk
            </button>
            <button @click="openCategoryModal" class="flex items-center justify-center gap-2 rounded-xl bg-white/20 px-4 py-2.5 font-semibold text-white backdrop-blur-sm transition-all hover:bg-white/30 hover:scale-105 active:scale-95">
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"/>
              </svg>
              Kelola Kategori
            </button>
            <button @click="openProductForm()" class="flex items-center justify-center gap-2 rounded-xl bg-white px-4 py-2.5 font-semibold text-emerald-600 shadow-lg transition-all hover:shadow-xl hover:scale-105 active:scale-95">
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
              </svg>
              Tambah Produk
            </button>
          </div>
        </div>
      </div>

      <!-- Filter Card -->
      <div class="mb-6 overflow-hidden rounded-2xl bg-white p-4 shadow-lg">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div class="relative flex-1">
            <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
              <svg class="h-5 w-5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
              </svg>
            </div>
            <input
              v-model="searchQuery"
              type="text"
              class="w-full rounded-xl border-2 border-slate-200 py-2.5 pl-10 pr-4 transition-all focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-200"
              placeholder="Cari nama atau kode produk..."
            />
          </div>
          <div class="relative sm:w-64">
            <select v-model="selectedCategory" class="w-full appearance-none rounded-xl border-2 border-slate-200 bg-white py-2.5 pl-4 pr-10 transition-all focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-200">
              <option :value="null">Semua Kategori</option>
              <option v-for="category in categories" :key="category.id" :value="category.id">
                {{ category.name }}
              </option>
            </select>
            <div class="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-3">
              <svg class="h-5 w-5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
              </svg>
            </div>
          </div>
        </div>
      </div>

      <!-- Loading State -->
      <div v-if="loading" class="flex items-center justify-center rounded-2xl bg-white p-12 shadow-lg">
        <div class="flex items-center gap-3 text-slate-600">
          <div class="h-8 w-8 animate-spin rounded-full border-4 border-slate-200 border-t-emerald-600"></div>
          <p class="text-lg font-medium">Memuat produk...</p>
        </div>
      </div>

      <!-- Empty State - No Products at All -->
      <div v-else-if="products.length === 0 && !hasSearched" class="overflow-hidden rounded-2xl bg-white p-12 shadow-lg">
        <div class="flex flex-col items-center gap-6 text-center">
          <div class="flex h-24 w-24 items-center justify-center rounded-full bg-gradient-to-br from-emerald-100 to-emerald-200">
            <svg class="h-12 w-12 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
            </svg>
          </div>
          <div>
            <h3 class="text-xl font-bold text-slate-900">Belum Ada Produk</h3>
            <p class="mt-2 text-slate-500">Mulai tambahkan produk pertama Anda untuk memulai penjualan</p>
          </div>
          <button @click="openProductForm()" class="flex items-center gap-2 rounded-xl bg-gradient-to-r from-emerald-600 to-emerald-500 px-6 py-3 font-semibold text-white shadow-lg transition-all hover:shadow-xl hover:scale-105 active:scale-95">
            <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
            </svg>
            Tambah Produk Pertama
          </button>
        </div>
      </div>

      <!-- Not Found State - Search/Filter Result Empty -->
      <div v-else-if="products.length === 0" class="overflow-hidden rounded-2xl bg-white p-12 shadow-lg">
        <div class="flex flex-col items-center gap-6 text-center">
          <div class="relative">
            <div class="flex h-24 w-24 items-center justify-center rounded-full bg-gradient-to-br from-amber-100 to-amber-200 animate-pulse">
              <svg class="h-12 w-12 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
              </svg>
            </div>
            <div class="absolute -right-1 -top-1 flex h-8 w-8 items-center justify-center rounded-full bg-red-500 shadow-lg">
              <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </div>
          </div>
          <div class="max-w-md">
            <h3 class="text-2xl font-bold text-slate-900">Produk Tidak Ditemukan</h3>
            <p class="mt-2 text-slate-500">Tidak ada produk yang cocok dengan pencarian</p>
            <div v-if="searchQuery" class="mt-4 inline-flex items-center gap-2 rounded-xl bg-slate-100 px-4 py-2">
              <svg class="h-4 w-4 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
              </svg>
              <span class="text-sm font-semibold text-slate-700">{{ searchQuery }}</span>
            </div>
          </div>
          <div class="flex flex-wrap items-center justify-center gap-3">
            <button @click="clearFilters" class="flex items-center gap-2 rounded-xl bg-gradient-to-r from-slate-600 to-slate-700 px-5 py-3 font-semibold text-white shadow-lg transition-all hover:from-slate-700 hover:to-slate-800 hover:scale-105 active:scale-95">
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
              </svg>
              Reset Pencarian
            </button>
            <button @click="openProductForm()" class="flex items-center gap-2 rounded-xl bg-gradient-to-r from-emerald-600 to-emerald-500 px-5 py-3 font-semibold text-white shadow-lg transition-all hover:shadow-xl hover:scale-105 active:scale-95">
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
              </svg>
              Tambah Produk Baru
            </button>
          </div>
        </div>
      </div>

      <!-- Product Table -->
      <DataTable v-else :columns="tableColumns" :data="products">
        <template #header-checkbox>
          <input
            type="checkbox"
            v-model="allSelected"
            :disabled="products.length === 0"
            class="h-4 w-4 rounded border-slate-300 text-emerald-600 focus:ring-emerald-500 focus:ring-2 transition-all cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
            title="Pilih semua produk di halaman ini"
          />
        </template>
        
        <template #cell-checkbox="{ item }">
          <input
            type="checkbox"
            v-model="selectedProducts"
            :value="item.id"
            class="h-4 w-4 rounded border-slate-300 text-emerald-600 focus:ring-emerald-500 focus:ring-2 transition-all cursor-pointer"
          />
        </template>
        
        <template #cell-name="{ value }">
          <div class="font-semibold text-slate-900">{{ value }}</div>
        </template>
        
        <template #cell-code="{ value }">
          <span class="inline-flex items-center rounded-lg bg-gradient-to-r from-amber-100 to-amber-200 px-2.5 py-1 text-xs font-mono font-bold text-amber-800">
            {{ value || '-' }}
          </span>
        </template>
        
        <template #cell-category_id="{ value }">
          <span class="inline-flex items-center gap-1.5 rounded-full bg-gradient-to-r from-slate-100 to-slate-200 px-3 py-1 text-xs font-semibold text-slate-700">
            <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"/>
            </svg>
            {{ getCategoryName(value) }}
          </span>
        </template>
        
        <template #cell-price="{ value }">
          <div class="accounting-price">
            <span class="currency-symbol">Rp</span>
            <span class="amount">{{ formatRupiah(value) }}</span>
          </div>
        </template>
        
        <template #cell-description="{ value }">
          <div class="max-w-xs truncate text-sm text-slate-500">{{ value || '-' }}</div>
        </template>
        
        <template #cell-actions="{ item }">
          <div class="flex items-center justify-center gap-2">
            <button @click="openProductForm(item)" class="flex h-9 w-9 items-center justify-center rounded-lg bg-blue-50 text-blue-600 transition-all hover:bg-blue-100 hover:scale-110 active:scale-95">
              <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
              </svg>
            </button>
            <button @click="deleteProduct(item)" class="flex h-9 w-9 items-center justify-center rounded-lg bg-red-50 text-red-600 transition-all hover:bg-red-100 hover:scale-110 active:scale-95">
              <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
              </svg>
            </button>
          </div>
        </template>
      </DataTable>

      <!-- Pagination -->
      <Pagination
        v-if="!loading && products.length > 0 && pagination.total_pages > 1"
        class="mt-4"
        :current-page="pagination.current_page"
        :total-pages="pagination.total_pages"
        :total-items="pagination.total_items"
        @page-change="changePage"
      />
    </div>

    <!-- Product Form Modal -->
    <div v-if="showProductForm" class="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 backdrop-blur-sm px-4" @click.self="closeProductForm">
      <div class="w-full max-w-2xl overflow-hidden rounded-2xl bg-white shadow-2xl">
        <div class="bg-gradient-to-r from-emerald-600 to-emerald-500 p-6">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-3">
              <div class="flex h-12 w-12 items-center justify-center rounded-xl bg-white/20 backdrop-blur-sm">
                <svg class="h-6 w-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
                </svg>
              </div>
              <div>
                <h2 class="text-xl font-bold text-white">{{ editingProduct ? 'Edit Produk' : 'Tambah Produk' }}</h2>
                <p class="text-sm text-emerald-100">{{ editingProduct ? 'Update informasi produk' : 'Tambahkan produk baru' }}</p>
              </div>
            </div>
            <button @click="closeProductForm" class="flex h-10 w-10 items-center justify-center rounded-xl bg-white/20 text-white backdrop-blur-sm transition-all hover:bg-white/30 hover:rotate-90">
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>
        <div class="max-h-[60vh] overflow-y-auto p-6">
          <div class="space-y-5">
            <div>
              <label class="mb-2 flex items-center gap-2 text-sm font-bold text-slate-700">
                <svg class="h-4 w-4 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"/>
                </svg>
                Nama Produk
              </label>
              <input v-model="productForm.name" type="text" placeholder="Contoh: Teh Manis" class="w-full rounded-xl border-2 border-slate-200 px-4 py-2.5 transition-all focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-200" />
            </div>
            <div>
              <label class="mb-2 flex items-center gap-2 text-sm font-bold text-slate-700">
                <svg class="h-4 w-4 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"/>
                </svg>
                Kategori <span class="text-red-500">*</span>
              </label>
              <div class="relative category-dropdown-container">
                <button
                  type="button"
                  @click="toggleCategoryDropdown"
                  class="w-full rounded-xl border-2 border-slate-200 bg-white px-4 py-2.5 text-left transition-all focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-200"
                  :class="{ 'border-emerald-500 ring-2 ring-emerald-200': categoryDropdownOpen }"
                >
                  <div class="flex items-center justify-between">
                    <span :class="selectedCategoryName ? 'text-slate-900' : 'text-slate-400'">
                      {{ selectedCategoryName || 'Pilih kategori' }}
                    </span>
                    <svg
                      class="h-5 w-5 text-slate-400 transition-transform"
                      :class="{ 'rotate-180': categoryDropdownOpen }"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
                    </svg>
                  </div>
                </button>

                <!-- Dropdown Menu -->
                <div
                  v-if="categoryDropdownOpen"
                  class="absolute z-50 mt-2 w-full overflow-hidden rounded-xl border-2 border-slate-200 bg-white shadow-xl"
                >
                  <!-- Search Input -->
                  <div class="border-b border-slate-200 p-3">
                    <div class="relative">
                      <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
                        <svg class="h-4 w-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                        </svg>
                      </div>
                      <input
                        v-model="categorySearchQuery"
                        type="text"
                        placeholder="Cari kategori..."
                        class="w-full rounded-lg border border-slate-200 py-2 pl-9 pr-3 text-sm transition-all focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-200"
                        @click.stop
                      />
                    </div>
                  </div>

                  <!-- Options List -->
                  <div class="max-h-60 overflow-y-auto">
                    <div
                      v-if="filteredCategories.length === 0"
                      class="px-4 py-3 text-center text-sm text-slate-500"
                    >
                      Kategori tidak ditemukan
                    </div>
                    <div
                      v-for="category in filteredCategories"
                      :key="category.id"
                      @click="selectCategory(category)"
                      class="flex cursor-pointer items-center justify-between px-4 py-2.5 text-sm transition-colors hover:bg-emerald-50"
                      :class="productForm.category_id === category.id ? 'bg-emerald-50 text-emerald-700 font-medium' : 'text-slate-700'"
                    >
                      <span>{{ category.name }}</span>
                      <svg v-if="productForm.category_id === category.id" class="h-5 w-5 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                      </svg>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <div>
              <label class="mb-2 flex items-center gap-2 text-sm font-bold text-slate-700">
                <svg class="h-4 w-4 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
                Harga
              </label>
              <input
                v-model="priceDisplay"
                type="text"
                class="w-full rounded-xl border-2 border-slate-200 px-4 py-2.5 transition-all focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-200"
                placeholder="Rp 0"
                @input="formatPriceInput"
                @blur="formatPriceOnBlur"
              />
            </div>
            <div>
              <label class="mb-2 flex items-center gap-2 text-sm font-bold text-slate-700">
                <svg class="h-4 w-4 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h7"/>
                </svg>
                Deskripsi
              </label>
              <textarea v-model="productForm.description" rows="3" class="w-full rounded-xl border-2 border-slate-200 px-4 py-2.5 transition-all focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-200" placeholder="Deskripsi produk (opsional)"></textarea>
            </div>
          </div>
        </div>
        <div class="flex items-center justify-end gap-3 border-t border-slate-100 bg-slate-50 p-6">
          <button @click="closeProductForm" class="rounded-xl bg-slate-200 px-6 py-2.5 font-semibold text-slate-700 transition-all hover:bg-slate-300 hover:scale-105 active:scale-95">
            Batal
          </button>
          <button @click="saveProduct" class="flex items-center gap-2 rounded-xl bg-gradient-to-r from-emerald-600 to-emerald-500 px-6 py-2.5 font-semibold text-white shadow-lg transition-all hover:shadow-xl hover:scale-105 active:scale-95">
            <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
            </svg>
            {{ editingProduct ? 'Update' : 'Simpan' }}
          </button>
        </div>
      </div>
    </div>

    <CategoryModal :isOpen="showCategoryModal" @close="closeCategoryModal" @updated="fetchCategories" />
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue'
import { useRouter } from 'vue-router'
import api from '../services/api'
import CategoryModal from '../components/CategoryModal.vue'
import DataTable from '../components/DataTable.vue'
import Pagination from '../components/Pagination.vue'
import { useNotification } from '../composables/useNotification'

const router = useRouter()
const { created, updated, deleted, error, confirm } = useNotification()

const products = ref([])
const categories = ref([])
const loading = ref(false)
const searchQuery = ref('')
const selectedCategory = ref(null)
const showProductForm = ref(false)
const showCategoryModal = ref(false)
const editingProduct = ref(null)
const priceDisplay = ref('')
const searchTimeout = ref(null)
const hasSearched = ref(false)
const categoryDropdownOpen = ref(false)
const categorySearchQuery = ref('')
const selectedProducts = ref([])

const pagination = ref({
  current_page: 1,
  total_pages: 1,
  total_items: 0,
  page_size: 12
})

// Computed for select all
const allSelected = computed({
  get() {
    return products.value.length > 0 && selectedProducts.value.length === products.value.length
  },
  set(value) {
    if (value) {
      selectedProducts.value = products.value.map(p => p.id)
    } else {
      selectedProducts.value = []
    }
  }
})

const filteredCategories = computed(() => {
  if (!categorySearchQuery.value) return categories.value
  const query = categorySearchQuery.value.toLowerCase()
  return categories.value.filter(c => c.name.toLowerCase().includes(query))
})

const selectedCategoryName = computed(() => {
  if (!productForm.value.category_id) return ''
  const category = categories.value.find(c => c.id === productForm.value.category_id)
  return category ? category.name : ''
})

const productForm = ref({
  name: '',
  description: '',
  price: 0,
  category_id: ''
})

// Table columns configuration
const tableColumns = [
  {
    key: 'checkbox',
    label: '',
    align: 'text-center'
  },
  {
    key: 'name',
    label: 'Nama Produk',
    align: 'text-left',
    icon: 'M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4'
  },
  {
    key: 'code',
    label: 'Code Produk',
    align: 'text-center'
  },
  {
    key: 'category_id',
    label: 'Kategori',
    align: 'text-center'
  },
  {
    key: 'price',
    label: 'Harga',
    align: 'text-center'
  },
  {
    key: 'description',
    label: 'Deskripsi',
    align: 'text-center'
  },
  {
    key: 'actions',
    label: 'Aksi',
    align: 'text-center'
  }
]

const fetchProducts = async () => {
  loading.value = true
  try {
    const params = {
      page: pagination.value.current_page,
      page_size: pagination.value.page_size
    }

    if (searchQuery.value) {
      params.search = searchQuery.value
      hasSearched.value = true
    }

    if (selectedCategory.value !== null) {
      params.category_id = selectedCategory.value
      hasSearched.value = true
    }

    const response = await api.get('/products', { params })
    if (response.data.success) {
      products.value = response.data.data || []
      if (response.data.pagination) {
        pagination.value = response.data.pagination
      }
    }
  } catch (error) {
    // Error handled silently
  } finally {
    loading.value = false
  }
}

const fetchCategories = async () => {
  try {
    const response = await api.get('/categories')
    if (response.data.success) {
      categories.value = response.data.data || []
    }
  } catch (error) {
    // Error handled silently
  }
}

const getCategoryName = (categoryId) => {
  const category = categories.value.find((c) => c.id === categoryId)
  return category ? category.name : 'Tanpa Kategori'
}

const formatRupiah = (amount) => {
  return new Intl.NumberFormat('id-ID', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 0
  }).format(amount)
}

const formatPriceInput = (event) => {
  let value = event.target.value.replace(/[^\d]/g, '')

  if (value === '') {
    priceDisplay.value = ''
    productForm.value.price = 0
    return
  }

  const numericValue = parseInt(value, 10)
  productForm.value.price = numericValue
  priceDisplay.value = 'Rp ' + numericValue.toLocaleString('id-ID')
}

const formatPriceOnBlur = () => {
  if (productForm.value.price === 0 || !productForm.value.price) {
    priceDisplay.value = ''
  }
}

const openProductForm = (product = null) => {
  if (product) {
    editingProduct.value = product
    productForm.value = {
      name: product.name,
      description: product.description || '',
      price: product.price,
      category_id: product.category_id
    }
    priceDisplay.value = product.price > 0 ? 'Rp ' + product.price.toLocaleString('id-ID') : ''
  } else {
    editingProduct.value = null
    productForm.value = {
      name: '',
      description: '',
      price: 0,
      category_id: ''
    }
    priceDisplay.value = ''
  }
  showProductForm.value = true
}

const closeProductForm = () => {
  showProductForm.value = false
  editingProduct.value = null
  priceDisplay.value = ''
  productForm.value = {
    name: '',
    description: '',
    price: 0,
    category_id: ''
  }
}

const saveProduct = async () => {
  if (!productForm.value.category_id) {
    error('Kategori wajib dipilih')
    return
  }

  try {
    if (editingProduct.value) {
      const response = await api.put(`/products/${editingProduct.value.id}`, productForm.value)
      if (response.data.success) {
        await fetchProducts()
        closeProductForm()
        updated('Produk berhasil diupdate')
      }
    } else {
      const response = await api.post('/products', productForm.value)
      if (response.data.success) {
        await fetchProducts()
        closeProductForm()
        created('Produk berhasil ditambahkan')
      }
    }
  } catch (err) {
    const errorMsg = err.response?.data?.message || 'Gagal menyimpan produk'
    error(errorMsg)
  }
}

const deleteProduct = (product) => {
  confirm(`Apakah Anda yakin ingin menghapus produk "${product.name}"?`, async () => {
    try {
      const response = await api.delete(`/products/${product.id}`)
      if (response.data.success) {
        await fetchProducts()
        deleted('Produk berhasil dihapus')
      }
    } catch (err) {
      error('Gagal menghapus produk')
    }
  })
}

const bulkDeleteProducts = async () => {
  if (selectedProducts.value.length === 0) return

  confirm(
    `Apakah Anda yakin ingin menghapus ${selectedProducts.value.length} produk yang dipilih?`,
    async () => {
      let successCount = 0
      let failedCount = 0

      for (const productId of selectedProducts.value) {
        try {
          const response = await api.delete(`/products/${productId}`)
          if (response.data.success) {
            successCount++
          } else {
            failedCount++
          }
        } catch (err) {
          failedCount++
        }
      }

      await fetchProducts()
      selectedProducts.value = []

      if (failedCount === 0) {
        deleted(`✓ ${successCount} produk berhasil dihapus!`)
      } else {
        error(`${successCount} produk berhasil dihapus, ${failedCount} gagal.`)
      }
    }
  )
}

const openCategoryModal = () => {
  showCategoryModal.value = true
}

const closeCategoryModal = () => {
  showCategoryModal.value = false
}

const clearFilters = () => {
  // Clear debounce timeout
  if (searchTimeout.value) {
    clearTimeout(searchTimeout.value)
  }
  
  searchQuery.value = ''
  selectedCategory.value = null
  pagination.value.current_page = 1
  hasSearched.value = false
  fetchProducts() // Instant fetch, no debounce
}

const goBack = () => {
  router.push('/')
}

const changePage = (page) => {
  if (page >= 1 && page <= pagination.value.total_pages) {
    pagination.value.current_page = page
    fetchProducts()
  }
}

const toggleCategoryDropdown = () => {
  categoryDropdownOpen.value = !categoryDropdownOpen.value
  if (categoryDropdownOpen.value) {
    categorySearchQuery.value = ''
  }
}

const selectCategory = (category) => {
  productForm.value.category_id = category.id
  categoryDropdownOpen.value = false
  categorySearchQuery.value = ''
}

const handleClickOutside = (event) => {
  const dropdown = event.target.closest('.category-dropdown-container')
  if (!dropdown && categoryDropdownOpen.value) {
    categoryDropdownOpen.value = false
    categorySearchQuery.value = ''
  }
}

// Watch for search and category changes with debounce
watch([searchQuery, selectedCategory], () => {
  if (searchTimeout.value) {
    clearTimeout(searchTimeout.value)
  }
  
  searchTimeout.value = setTimeout(() => {
    pagination.value.current_page = 1
    fetchProducts()
  }, 400)
})

onMounted(() => {
  fetchProducts()
  fetchCategories()
  document.addEventListener('click', handleClickOutside)
})

onBeforeUnmount(() => {
  // Cleanup debounce timeout
  if (searchTimeout.value) {
    clearTimeout(searchTimeout.value)
  }
  document.removeEventListener('click', handleClickOutside)
})
</script>

<style scoped>
.accounting-price {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  font-weight: 700;
  color: #10b981;
  font-variant-numeric: tabular-nums;
}

.currency-symbol {
  font-weight: 600;
  font-size: 0.875rem;
}

.amount {
  text-align: right;
  min-width: 100px;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
}
</style>
