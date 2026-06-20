<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between flex-wrap gap-3">
      <h1 class="text-xl font-bold text-gray-900">Bahan Baku</h1>
      <div class="flex items-center gap-2">
        <AppButton @click="openCategories">
          <svg class="h-4 w-4 mr-1.5 -ml-0.5 inline-block" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"/>
          </svg>
          Kategori
        </AppButton>
        <AppButton v-if="isCentral" @click="openCreate">+ Tambah Bahan</AppButton>
      </div>
    </div>

    <!-- Warehouse context selector -->
    <div class="flex items-center gap-3 flex-wrap rounded-xl bg-white ring-1 ring-gray-100 px-4 py-3 shadow-sm">
      <div class="flex items-center gap-2">
        <span :class="isCentral ? 'bg-blue-100 text-blue-700' : 'bg-amber-100 text-amber-700'" class="text-[10px] font-bold uppercase tracking-tight px-2 py-0.5 rounded">
          {{ isCentral ? 'Gudang Induk' : 'Gudang Outlet' }}
        </span>
        <label class="text-sm font-medium text-gray-600">Kelola stok untuk gudang:</label>
      </div>
      <div class="min-w-[240px]">
        <SearchSelect
          v-model="selectedWarehouseId"
          :options="warehouseOptions"
          placeholder="Pilih gudang…"
          searchPlaceholder="Cari gudang…"
          labelKey="label" valueKey="value"
        />
      </div>
      <p class="text-xs text-gray-400 flex-1 min-w-[200px]">
        {{ isCentral
          ? 'Definisi bahan (satuan, distribusi) diatur di sini. Stok minimal & saldo awal berlaku untuk gudang ini.'
          : 'Definisi bahan diwarisi dari Gudang Induk (hanya-baca). Atur stok minimal & saldo khusus outlet ini.' }}
      </p>
    </div>

    <AppAlert type="error" :message="errorMsg" />

    <AppCard :padding="false">
      <div class="flex items-center gap-3 px-4 py-3 border-b border-gray-100">
        <input v-model="search" @input="debouncedLoad" placeholder="Cari nama / kode..."
          class="flex-1 text-sm border border-gray-200 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-emerald-400" />
        <label class="flex items-center gap-2 text-sm text-gray-600 cursor-pointer select-none">
          <input type="checkbox" v-model="activeOnly" @change="load" class="rounded text-emerald-600" />
          Aktif saja
        </label>
      </div>
      <AppTable :columns="COLUMNS" :rows="items" :loading="loading" emptyText="Belum ada bahan baku.">
        <template #cell-code="{ row }">
          <button @click="openStockDetail(row)" class="font-mono text-xs bg-gray-100 px-2 py-0.5 rounded hover:bg-emerald-100 transition-colors">
            {{ row.code }}
          </button>
        </template>
        <template #cell-name="{ row }">
          <button @click="openStockDetail(row)" class="font-medium text-gray-900 hover:text-emerald-600 hover:underline text-left">
            {{ row.name }}
          </button>
        </template>
        <template #cell-unit="{ row }">
          <div class="text-xs leading-tight">
            <span class="font-medium">{{ row.base_unit }}</span>
            <span v-if="row.dist_unit !== row.base_unit" class="text-gray-400">
              → {{ row.dist_unit_label || row.dist_unit }}
              <span class="text-gray-300">(×{{ row.dist_ratio }})</span>
            </span>
          </div>
        </template>
        <template #cell-warehouse_qty="{ row }">
          <span v-if="row.in_warehouse" :class="['font-semibold', row.warehouse_qty < row.warehouse_min_stock && row.warehouse_min_stock > 0 ? 'text-red-600' : 'text-gray-800']">
            {{ row.warehouse_qty.toFixed(2) }}
          </span>
          <span v-else class="text-gray-300 italic text-sm">belum ada</span>
          <span v-if="row.in_warehouse" class="text-[10px] text-gray-400 ml-1">{{ row.base_unit }}</span>
        </template>
        <template #cell-warehouse_min_stock="{ row }">
          {{ row.warehouse_min_stock > 0 ? `${row.warehouse_min_stock} ${row.base_unit}` : '—' }}
        </template>
        <template #cell-warehouse_avg_cost="{ row }">
          <span class="text-sm">{{ row.warehouse_avg_cost > 0 ? `${formatRupiah(row.warehouse_avg_cost)}/${row.base_unit}` : '—' }}</span>
        </template>
        <template #cell-total_stock="{ row }">
          <span class="text-sm text-gray-500">{{ row.total_stock.toFixed(2) }}</span>
          <span class="text-[10px] text-gray-400 ml-1">{{ row.base_unit }}</span>
        </template>
        <template #cell-is_active="{ row }">
          <span :class="row.is_active ? 'bg-emerald-100 text-emerald-700' : 'bg-gray-100 text-gray-500'"
            class="text-xs font-medium px-2 py-0.5 rounded-full">
            {{ row.is_active ? 'Aktif' : 'Nonaktif' }}
          </span>
        </template>
        <template #cell-actions="{ row }">
          <div class="flex items-center gap-0.5">
            <!-- Recipe (SFG) -->
            <button @click="openRecipe(row)" title="Atur Resep (Bahan Setengah Jadi)"
              class="p-1.5 rounded text-indigo-600 hover:text-indigo-800 hover:bg-indigo-50 transition-colors">
              <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                  d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z"/>
              </svg>
            </button>
            <!-- Edit -->
            <button @click="openEdit(row)" title="Edit"
              class="p-1.5 rounded text-emerald-600 hover:text-emerald-800 hover:bg-emerald-50 transition-colors">
              <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                  d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
              </svg>
            </button>
            <!-- Toggle aktif -->
            <button @click="toggleActive(row)" :title="row.is_active ? 'Nonaktifkan' : 'Aktifkan'"
              class="p-1.5 rounded transition-colors"
              :class="row.is_active ? 'text-amber-500 hover:text-amber-700 hover:bg-amber-50' : 'text-gray-400 hover:text-gray-600 hover:bg-gray-50'">
              <svg v-if="row.is_active" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                  d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636"/>
              </svg>
              <svg v-else class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                  d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
            </button>
            <!-- Hapus -->
            <button @click="confirmDelete(row)" title="Hapus"
              class="p-1.5 rounded text-red-500 hover:text-red-700 hover:bg-red-50 transition-colors">
              <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                  d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
              </svg>
            </button>
          </div>
        </template>
      </AppTable>
      <AppPagination v-model="page" :total="total" :perPage="limit" class="px-4 py-3 border-t border-gray-100" />
    </AppCard>

    <!-- Create / Edit Modal -->
    <AppModal v-model="showForm" :title="editTarget ? 'Edit Bahan Baku' : 'Tambah Bahan'" size="2xl">
      <div class="space-y-5">

        <!-- Live preview strip -->
        <div class="flex items-center gap-3 rounded-xl bg-gradient-to-r from-emerald-50 to-teal-50/60 px-4 py-3 ring-1 ring-emerald-100">
          <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-emerald-500 text-white shadow-sm">
            <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8"
                d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
            </svg>
          </div>
          <div class="min-w-0 flex-1 flex flex-wrap items-center gap-x-3 gap-y-0.5">
            <span class="font-semibold text-gray-900 truncate">{{ form.name || 'Nama bahan baku…' }}</span>
            <span v-if="form.category" class="text-xs text-gray-400">· {{ form.category }}</span>
            <template v-if="form.base_unit">
              <span class="text-gray-300 text-xs">·</span>
              <span class="text-xs font-medium text-gray-500">{{ form.base_unit }}</span>
              <template v-if="form.dist_unit && Number(form.dist_ratio) > 0">
                <svg class="h-3 w-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>
                <span class="font-mono text-xs font-semibold text-emerald-600">1 {{ form.dist_unit_label || form.dist_unit }} = {{ form.dist_ratio }} {{ form.base_unit }}</span>
              </template>
            </template>
          </div>
        </div>

        <!-- Read-only catalog notice for outlet warehouses -->
        <div v-if="!isCentral" class="flex items-start gap-2 rounded-lg bg-amber-50 ring-1 ring-amber-100 px-3 py-2 text-xs text-amber-700">
          <svg class="h-4 w-4 mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
          <span>Definisi bahan (nama, satuan, distribusi) diwarisi dari <b>Gudang Induk</b> dan tidak dapat diubah dari sini. Anda hanya mengatur stok minimal &amp; saldo untuk outlet ini.</span>
        </div>

        <!-- Catalog fields (editable only at central) -->
        <div>
          <p class="text-xs font-semibold uppercase tracking-wide text-gray-400 mb-2">Definisi Bahan {{ isCentral ? '' : '(hanya-baca)' }}</p>
          <div class="grid grid-cols-2 gap-x-5 gap-y-4">
            <AppInput v-model="form.name" label="Nama Bahan" placeholder="Udang Segar" :disabled="!isCentral" />
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Kategori</label>
              <SearchSelect
                v-model="form.category"
                :options="categoryOptions"
                placeholder="Pilih kategori..."
                searchPlaceholder="Cari kategori..."
                labelKey="label" valueKey="value"
                :disabled="!isCentral"
              />
            </div>
            <AppInput v-model="form.base_unit" label="Satuan Dasar (Beli)" placeholder="kg / liter / pcs" :disabled="!isCentral" />
            <AppInput v-model="form.dist_unit" label="Satuan Distribusi (Kirim)" placeholder="kemasan / bungkus" :disabled="!isCentral" />
            <AppInput v-model.number="form.dist_ratio" label="Isi per Kemasan" type="number" step="0.0001" placeholder="1" :disabled="!isCentral" />
            <AppInput v-model="form.dist_unit_label" label="Label Kemasan" placeholder="Kemasan 500gr" :disabled="!isCentral" />
            <AppInput v-model="form.notes" label="Keterangan" placeholder="Catatan opsional…" :disabled="!isCentral" class="col-span-2" />
          </div>
        </div>

        <!-- Per-warehouse section -->
        <div class="rounded-xl ring-1 ring-gray-100 bg-gray-50/60 p-4">
          <div class="flex items-center gap-2 mb-3">
            <span :class="isCentral ? 'bg-blue-100 text-blue-700' : 'bg-amber-100 text-amber-700'" class="text-[10px] font-bold uppercase tracking-tight px-2 py-0.5 rounded">
              {{ isCentral ? 'Gudang Induk' : 'Gudang Outlet' }}
            </span>
            <p class="text-sm font-semibold text-gray-700">{{ selectedWarehouse?.name }}</p>
          </div>
          <div class="grid grid-cols-2 gap-x-5 gap-y-4">
            <AppInput v-model.number="form.warehouse_min_stock" label="Stok Minimal (gudang ini)" type="number" step="0.001" placeholder="0" />

            <!-- Create: opening stock -->
            <AppInput v-if="!editTarget" v-model.number="form.opening_stock" label="Stok Awal (opsional)" type="number" step="0.001" placeholder="0" />
            <!-- Edit: set/adjust stock to target -->
            <div v-else>
              <label class="block text-sm font-medium text-gray-700 mb-1">Sesuaikan Stok ke</label>
              <input v-model="form.set_stock" type="number" step="0.001"
                :placeholder="`Saat ini: ${Number(form.warehouse_qty || 0).toFixed(2)} ${form.base_unit}`"
                class="w-full text-sm border border-gray-200 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-emerald-400" />
              <p class="text-[11px] text-gray-400 mt-1">Kosongkan jika tidak mengubah stok.</p>
            </div>

            <!-- Cost (relevant when adding stock) -->
            <AppInput v-if="!editTarget ? form.opening_stock > 0 : (form.set_stock !== '' && form.set_stock != null)"
              v-model.number="form.opening_cost" label="HPP per Satuan Dasar" type="number" step="0.01" placeholder="0" />

            <!-- Current avg cost display -->
            <div v-if="editTarget" class="flex flex-col">
              <label class="block text-sm font-medium text-gray-700 mb-1">HPP Rata-rata (gudang ini)</label>
              <div class="text-sm font-semibold text-gray-800 px-3 py-2 bg-white rounded-lg ring-1 ring-gray-100">
                {{ form.warehouse_avg_cost > 0 ? `${formatRupiah(form.warehouse_avg_cost)}/${form.base_unit}` : '—' }}
              </div>
            </div>
          </div>
        </div>
      </div>
      <template #footer>
        <AppButton variant="secondary" @click="showForm = false">Batal</AppButton>
        <AppButton :loading="saving" @click="submitForm">Simpan</AppButton>
      </template>
    </AppModal>

    <!-- Delete confirm -->
    <AppModal v-model="showDelete" title="Hapus Bahan Baku" size="sm">
      <p class="text-sm text-gray-600">Hapus <strong>{{ deleteTarget?.name }}</strong>? Tindakan ini tidak dapat dibatalkan.</p>
      <template #footer>
        <AppButton variant="secondary" @click="showDelete = false">Batal</AppButton>
        <AppButton variant="danger" :loading="saving" @click="submitDelete">Hapus</AppButton>
      </template>
    </AppModal>

    <!-- Categories Modal -->
    <AppModal v-model="showCategories" title="Manajemen Kategori Bahan Baku" size="2xl">
      <div class="grid md:grid-cols-2 gap-6 min-h-[340px]">

        <!-- Left: Add / Edit form -->
        <div class="space-y-4">
          <p class="text-xs font-semibold uppercase tracking-wider text-gray-400">
            {{ catEditTarget ? 'Edit Kategori' : 'Tambah Kategori' }}
          </p>
          <AppInput v-model="catForm.name" label="Nama Kategori" placeholder="Seafood, Daging, Bumbu…" />
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Keterangan <span class="text-gray-400 font-normal">(opsional)</span></label>
            <textarea
              v-model="catForm.notes"
              rows="3"
              placeholder="Deskripsi singkat kategori ini…"
              class="w-full text-sm border border-gray-200 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-emerald-400 resize-none"
            ></textarea>
          </div>
          <div class="flex gap-2 pt-1">
            <AppButton v-if="catEditTarget" variant="secondary" @click="resetCatForm">Batal Edit</AppButton>
            <AppButton :loading="catSaving" @click="submitCatForm" class="flex-1">
              {{ catEditTarget ? 'Perbarui' : 'Simpan Kategori' }}
            </AppButton>
          </div>
        </div>

        <!-- Right: Category list -->
        <div class="flex flex-col gap-3">
          <p class="text-xs font-semibold uppercase tracking-wider text-gray-400">Daftar Kategori</p>

          <!-- table -->
          <div class="overflow-hidden rounded-xl border border-gray-100">
            <table class="min-w-full text-sm">
              <thead class="bg-gray-50 text-xs text-gray-500">
                <tr>
                  <th class="px-3 py-2 text-left font-medium w-8">#</th>
                  <th class="px-3 py-2 text-left font-medium">Nama</th>
                  <th class="px-3 py-2 text-left font-medium">Keterangan</th>
                  <th class="px-3 py-2 text-center font-medium w-24">Aksi</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-50">
                <tr v-if="catLoading">
                  <td colspan="4" class="px-3 py-6 text-center text-gray-400">Memuat…</td>
                </tr>
                <tr v-else-if="catPagedRows.length === 0">
                  <td colspan="4" class="px-3 py-6 text-center text-gray-400 italic">Belum ada kategori.</td>
                </tr>
                <tr v-for="(cat, idx) in catPagedRows" :key="cat.id" class="hover:bg-gray-50 transition-colors">
                  <td class="px-3 py-2 text-gray-400 text-xs">{{ (catPage - 1) * catPageSize + idx + 1 }}</td>
                  <td class="px-3 py-2 font-semibold text-gray-800">{{ cat.name }}</td>
                  <td class="px-3 py-2 text-gray-400 text-xs truncate max-w-[140px]">{{ cat.notes || '—' }}</td>
                  <td class="px-3 py-2 text-center">
                    <div class="flex items-center justify-center gap-1">
                      <button @click="openEditCategory(cat)" title="Edit"
                        class="p-1.5 rounded text-emerald-600 hover:text-emerald-800 hover:bg-emerald-50 transition-colors">
                        <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                            d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                        </svg>
                      </button>
                      <button @click="deleteCategoryItem(cat)" title="Hapus"
                        class="p-1.5 rounded text-red-500 hover:text-red-700 hover:bg-red-50 transition-colors">
                        <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                            d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                        </svg>
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <!-- info card when empty -->
          <div v-if="!catLoading && categories.length === 0"
            class="flex items-start gap-3 rounded-xl border border-amber-100 bg-amber-50 px-4 py-3">
            <svg class="h-4 w-4 mt-0.5 shrink-0 text-amber-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
            <div class="text-xs text-amber-700 leading-relaxed">
              <p class="font-semibold mb-0.5">Belum ada kategori</p>
              <p class="text-amber-600">Tambahkan kategori di form sebelah kiri. Kategori membantu mengelompokkan bahan baku seperti <em>Seafood</em>, <em>Daging</em>, <em>Bumbu</em>, dll.</p>
            </div>
          </div>

          <!-- pagination -->
          <div v-if="catTotalPages > 1" class="flex items-center justify-between text-xs text-gray-500">
            <span>{{ categories.length }} kategori · hal. {{ catPage }}/{{ catTotalPages }}</span>
            <div class="flex items-center gap-1">
              <button
                :disabled="catPage <= 1"
                @click="catPage--"
                class="px-2 py-1 rounded border border-gray-200 hover:bg-gray-100 disabled:opacity-40 disabled:cursor-not-allowed"
              >&lsaquo;</button>
              <button
                :disabled="catPage >= catTotalPages"
                @click="catPage++"
                class="px-2 py-1 rounded border border-gray-200 hover:bg-gray-100 disabled:opacity-40 disabled:cursor-not-allowed"
              >&rsaquo;</button>
            </div>
          </div>
        </div>

      </div>
      <template #footer>
        <AppButton variant="secondary" @click="showCategories = false">Tutup</AppButton>
      </template>
    </AppModal>

    <!-- Stock Detail Modal -->
    <AppModal v-model="showStockDetail" :title="`Detail Stok: ${stockDetailTarget?.name || ''}`" size="md">
      <div v-if="detailLoading" class="py-8 text-center text-gray-400">Memuat data stok...</div>
      <div v-else class="space-y-4">
        <div class="grid grid-cols-2 gap-4">
          <div class="p-3 bg-gray-50 rounded-lg">
            <div class="text-[10px] uppercase font-bold text-gray-400 tracking-wider">Stok Global</div>
            <div class="text-xl font-bold text-gray-900">{{ stockDetailTarget?.total_stock?.toFixed(2) }} {{ stockDetailTarget?.base_unit }}</div>
          </div>
          <div class="p-3 bg-gray-50 rounded-lg">
            <div class="text-[10px] uppercase font-bold text-gray-400 tracking-wider">HPP Rata-rata</div>
            <div class="text-xl font-bold text-gray-900">{{ formatRupiah(stockDetailTarget?.avg_cost) }}</div>
          </div>
        </div>

        <div class="overflow-hidden border border-gray-100 rounded-xl">
          <table class="min-w-full text-sm">
            <thead class="bg-gray-50 text-xs text-gray-500">
              <tr>
                <th class="px-3 py-2 text-left font-medium">Gudang</th>
                <th class="px-3 py-2 text-left font-medium">Tipe</th>
                <th class="px-3 py-2 text-right font-medium">Stok</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-50">
              <tr v-if="stockBreakdown.length === 0">
                <td colspan="3" class="px-3 py-4 text-center text-gray-400 italic">Belum ada stok di gudang manapun.</td>
              </tr>
              <tr v-for="b in stockBreakdown" :key="b.warehouse_id" class="hover:bg-gray-50">
                <td class="px-3 py-2 font-medium">{{ getWarehouseLabel(b) }}</td>
                <td class="px-3 py-2">
                  <span :class="b.warehouse_type === 'central' ? 'text-blue-600' : 'text-amber-600'" class="text-[10px] uppercase font-bold tracking-tighter">
                    {{ b.warehouse_type === 'central' ? 'Induk' : 'Outlet' }}
                  </span>
                </td>
                <td class="px-3 py-2 text-right font-mono font-bold">{{ b.qty_base.toFixed(2) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
      <template #footer>
        <AppButton variant="secondary" @click="showStockDetail = false">Tutup</AppButton>
      </template>
    </AppModal>

    <!-- SFG Recipe Modal -->
    <AppModal v-model="showRecipeModal" title="Resep Bahan Setengah Jadi" size="lg">
      <div class="space-y-4">
        <div class="p-3 bg-indigo-50 rounded-lg border border-indigo-100 flex items-center justify-between">
          <div>
            <div class="text-[10px] uppercase font-bold text-indigo-400">Bahan yang Dibuat</div>
            <div class="text-lg font-bold text-indigo-900">{{ recipeTarget?.name }}</div>
          </div>
          <div class="text-right">
            <div class="text-[10px] uppercase font-bold text-indigo-400">Satuan Produksi</div>
            <div class="text-lg font-bold text-indigo-900">1 {{ recipeTarget?.base_unit }}</div>
          </div>
        </div>

        <div class="p-3 bg-gray-50 rounded-xl border border-gray-100 flex items-center justify-between">
          <label class="text-sm font-bold text-gray-700">Visibilitas Resep:</label>
          <div class="flex gap-2">
            <button 
              v-for="v in [{v:'public', l:'Public (Semua Outlet)'}, {v:'secret', l:'Rahasia (Hanya Saya)'}]" :key="v.v"
              @click="recipeVisibility = v.v"
              :class="['px-3 py-1.5 rounded-lg text-xs font-bold transition-all border', 
                recipeVisibility === v.v ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white text-gray-500 border-gray-200']"
            >
              {{ v.l }}
            </button>
          </div>
        </div>

        <div class="space-y-2">
          <label class="text-xs font-bold text-gray-500 uppercase">Komponen Bahan Baku</label>
          <div class="border rounded-xl overflow-hidden">
            <table class="min-w-full text-sm">
              <thead class="bg-gray-50 text-gray-500 uppercase text-[10px]">
                <tr>
                  <th class="px-3 py-2 text-left">Bahan Baku</th>
                  <th class="px-3 py-2 text-left w-32">Jumlah</th>
                  <th class="px-3 py-2 text-left w-20">Satuan</th>
                  <th class="px-3 py-2 w-10"></th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                <tr v-for="(it, idx) in recipeItems" :key="idx">
                  <td class="px-3 py-2">
                    <SearchSelect
                      v-model="it.item_id"
                      :options="stockItemOptions"
                      placeholder="Pilih bahan..."
                      searchPlaceholder="Cari..."
                      @change="onRecipeItemChange(idx)"
                    />
                  </td>
                  <td class="px-3 py-2">
                    <input v-model.number="it.qty_base" type="number" step="0.001" class="w-full text-sm border-gray-200 rounded-lg" placeholder="0" />
                  </td>
                  <td class="px-3 py-2 text-xs text-gray-500 font-medium">
                    {{ it.unit || '—' }}
                  </td>
                  <td class="px-3 py-2 text-center">
                    <button @click="recipeItems.splice(idx, 1)" class="text-red-400 hover:text-red-600">
                      <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/></svg>
                    </button>
                  </td>
                </tr>
                <tr v-if="recipeItems.length === 0">
                  <td colspan="4" class="px-3 py-6 text-center text-gray-400 italic">Belum ada komponen resep.</td>
                </tr>
              </tbody>
            </table>
          </div>
          <button @click="addRecipeItem" class="text-xs font-bold text-indigo-600 hover:text-indigo-800">+ Tambah Komponen</button>
        </div>
      </div>
      <template #footer>
        <AppButton variant="secondary" @click="showRecipeModal = false">Batal</AppButton>
        <AppButton :loading="savingRecipe" @click="submitRecipe">Simpan Resep</AppButton>
      </template>
    </AppModal>
  </div>
</template>

<script setup>
import { computed, ref, watch, onMounted } from 'vue'
import { stockItemsApi, stockLedgerApi, warehousesApi, stockItemCategoriesApi, stockItemRecipesApi } from '@/api/warehouse.js'
import { useToastStore } from '@/stores/toast.js'
import AppButton     from '@/components/ui/AppButton.vue'
import AppCard       from '@/components/ui/AppCard.vue'
import AppTable      from '@/components/ui/AppTable.vue'
import AppModal      from '@/components/ui/AppModal.vue'
import AppInput      from '@/components/ui/AppInput.vue'
import AppAlert      from '@/components/ui/AppAlert.vue'
import AppPagination from '@/components/ui/AppPagination.vue'
import SearchSelect  from '@/components/ui/SearchSelect.vue'
import { formatWarehouseOptionLabel } from '@/utils/warehouse.js'

const toast = useToastStore()
const loading = ref(false)
const saving = ref(false)
const errorMsg = ref('')
const items = ref([])
const total = ref(0)
const page = ref(1)
const limit = 20
const search = ref('')
const activeOnly = ref(false)
const totalPages = ref(1)

const showForm = ref(false)
const showDelete = ref(false)
const editTarget = ref(null)
const deleteTarget = ref(null)

// Stock Detail
const showStockDetail = ref(false)
const stockDetailTarget = ref(null)
const stockBreakdown = ref([])
const detailLoading = ref(false)
const warehouseList = ref([])

// SFG Recipe State
const showRecipeModal = ref(false)
const recipeTarget = ref(null)
const recipeItems = ref([])
const recipeVisibility = ref('secret')
const savingRecipe = ref(false)
const allStockItems = ref([]) // For recipe selection

const stockItemOptions = computed(() =>
  allStockItems.value
    .filter(i => i.id !== recipeTarget.value?.id) // Prevent self-reference
    .map(i => ({ value: i.id, label: `${i.name} (${i.code})` }))
)

async function openRecipe(row) {
  recipeTarget.value = row
  recipeItems.value = []
  recipeVisibility.value = 'secret'
  showRecipeModal.value = true
  
  // Load all items for selection if not loaded
  if (allStockItems.value.length === 0) {
    try {
      const res = await stockItemsApi.list({ limit: 500, active_only: true })
      allStockItems.value = res.data || []
    } catch (e) {}
  }

  try {
    const data = await stockItemRecipesApi.get(row.id)
    recipeItems.value = (data.data || []).map(r => ({
      item_id: r.child_item_id,
      qty_base: r.qty_base,
      unit: r.unit,
    }))
    if (data.data?.length > 0) {
      recipeVisibility.value = data.data[0].visibility || 'secret'
    }
  } catch (e) {
    recipeItems.value = []
  }
}

function addRecipeItem() {
  recipeItems.value.push({ item_id: '', qty_base: 1, unit: '' })
}

function onRecipeItemChange(idx) {
  const it = recipeItems.value[idx]
  const found = allStockItems.value.find(i => i.id === it.item_id)
  if (found) {
    it.unit = found.base_unit
  }
}

async function submitRecipe() {
  const items = recipeItems.value.filter(it => it.item_id && it.qty_base > 0)
  savingRecipe.value = true
  try {
    await stockItemRecipesApi.save(recipeTarget.value.id, items, recipeVisibility.value)
    toast.success('Resep bahan baku disimpan')
    showRecipeModal.value = false
  } catch (e) {
    toast.error(e?.message || 'Gagal menyimpan resep')
  } finally {
    savingRecipe.value = false
  }
}

// Categories
const showCategories = ref(false)
const categories = ref([])
const catLoading = ref(false)
const catSaving = ref(false)
const catEditTarget = ref(null)
const EMPTY_CAT_FORM = () => ({ name: '', notes: '' })
const catForm = ref(EMPTY_CAT_FORM())
const catPage = ref(1)
const catPageSize = 8
const catTotalPages = computed(() => Math.max(1, Math.ceil(categories.value.length / catPageSize)))
const catPagedRows = computed(() => {
  const start = (catPage.value - 1) * catPageSize
  return categories.value.slice(start, start + catPageSize)
})

const EMPTY_FORM = () => ({
  code: '', name: '', category: '',
  base_unit: '', dist_unit: '', dist_ratio: 1,
  dist_unit_label: '', notes: '',
  // per-warehouse
  warehouse_min_stock: 0, opening_stock: 0, opening_cost: 0,
  set_stock: '', warehouse_qty: 0, warehouse_avg_cost: 0,
})
const form = ref(EMPTY_FORM())

const COLUMNS = [
  { key: 'code',                label: 'Kode',          sortable: false },
  { key: 'name',                label: 'Nama',          sortable: false },
  { key: 'category',            label: 'Kategori',      sortable: false },
  { key: 'unit',                label: 'Satuan',        sortable: false },
  { key: 'warehouse_qty',       label: 'Stok di Gudang', sortable: false },
  { key: 'warehouse_min_stock', label: 'Stok Min',      sortable: false },
  { key: 'warehouse_avg_cost',  label: 'HPP Gudang',    sortable: false },
  { key: 'total_stock',         label: 'Stok Global',   sortable: false },
  { key: 'is_active',           label: 'Status',        sortable: false },
  { key: 'actions',             label: '',              sortable: false },
]

const warehouseMap = computed(() => Object.fromEntries(warehouseList.value.map(w => [w.id, w])))

// ── Warehouse context ─────────────────────────────────────────
const selectedWarehouseId = ref('')
const centralWarehouses = computed(() => warehouseList.value.filter(w => w.type === 'central'))
const outletWarehouses  = computed(() => warehouseList.value.filter(w => w.type === 'outlet'))
const selectedWarehouse = computed(() => warehouseMap.value[selectedWarehouseId.value] || null)
const isCentral = computed(() => selectedWarehouse.value?.type === 'central')
const warehouseOptions = computed(() => [
  ...centralWarehouses.value.map(w => ({ value: w.id, label: `Induk · ${w.name}` })),
  ...outletWarehouses.value.map(w => ({ value: w.id, label: `Outlet · ${w.name}${w.outlet_name ? ` — ${w.outlet_name}` : ''}` })),
])

const categoryOptions = computed(() => [
  { label: '— Tanpa Kategori —', value: '' },
  ...categories.value.map(c => ({ label: c.name, value: c.name })),
])

function formatRupiah(v) {
  return 'Rp ' + Number(v || 0).toLocaleString('id-ID')
}

let debounceTimer = null
function debouncedLoad() {
  clearTimeout(debounceTimer)
  debounceTimer = setTimeout(() => { page.value = 1; load() }, 400)
}

async function load() {
  loading.value = true
  errorMsg.value = ''
  try {
    const data = await stockItemsApi.list({
      page: page.value, limit,
      search: search.value,
      active_only: activeOnly.value ? 'true' : '',
      warehouse_id: selectedWarehouseId.value || '',
    })
    items.value = data.data || []
    total.value = data.total || 0
    totalPages.value = data.total_pages || 1
  } catch (e) {
    errorMsg.value = e?.message || 'Gagal memuat data'
  } finally {
    loading.value = false
  }
}

watch(selectedWarehouseId, () => { page.value = 1; load() })

function getWarehouseLabel(row) {
  return formatWarehouseOptionLabel(warehouseMap.value[row.warehouse_id] || row)
}

async function loadWarehouses() {
  try {
    const data = await warehousesApi.list({ limit: 200 })
    warehouseList.value = data.data || []
    // Default to the first central (induk) warehouse.
    if (!selectedWarehouseId.value && warehouseList.value.length) {
      const central = warehouseList.value.find(w => w.type === 'central')
      selectedWarehouseId.value = (central || warehouseList.value[0]).id
    }
  } catch (e) {
    toast.error(e?.message || 'Gagal memuat daftar gudang')
  }
}

watch(page, load)
onMounted(() => { loadWarehouses().then(() => { if (!selectedWarehouseId.value) load() }) })

async function openStockDetail(row) {
  stockDetailTarget.value = row
  showStockDetail.value = true
  detailLoading.value = true
  try {
    const data = await stockLedgerApi.list({ item_id: row.id, limit: 100 })
    stockBreakdown.value = data.data || []
  } catch (e) {
    toast.error(e?.message || 'Gagal memuat detail stok')
  } finally {
    detailLoading.value = false
  }
}

function openCreate() {
  editTarget.value = null
  form.value = EMPTY_FORM()
  showForm.value = true
  if (categories.value.length === 0) loadCategories()
}
function openEdit(row) {
  editTarget.value = row
  form.value = {
    code: row.code, name: row.name, category: row.category,
    base_unit: row.base_unit, dist_unit: row.dist_unit,
    dist_ratio: row.dist_ratio, dist_unit_label: row.dist_unit_label,
    notes: row.notes,
    // per-warehouse context for the selected warehouse
    warehouse_min_stock: row.warehouse_min_stock || 0,
    warehouse_qty: row.warehouse_qty || 0,
    warehouse_avg_cost: row.warehouse_avg_cost || 0,
    opening_stock: 0, opening_cost: row.warehouse_avg_cost || 0, set_stock: '',
  }
  showForm.value = true
  if (categories.value.length === 0) loadCategories()
}
function confirmDelete(row) {
  deleteTarget.value = row
  showDelete.value = true
}

async function submitForm() {
  saving.value = true
  try {
    const f = form.value
    const payload = {
      code: f.code, name: f.name, category: f.category,
      base_unit: f.base_unit, dist_unit: f.dist_unit,
      dist_ratio: f.dist_ratio, dist_unit_label: f.dist_unit_label, notes: f.notes,
      warehouse_id: selectedWarehouseId.value,
      warehouse_min_stock: Number(f.warehouse_min_stock) || 0,
      opening_cost: Number(f.opening_cost) || 0,
      // mirror the catalog default min-stock from the central context
      min_stock: isCentral.value ? (Number(f.warehouse_min_stock) || 0) : undefined,
    }
    if (editTarget.value) {
      // Only send set_stock when the user typed a target value.
      payload.set_stock = (f.set_stock === '' || f.set_stock == null) ? null : Number(f.set_stock)
      await stockItemsApi.update(editTarget.value.id, payload)
      toast.success('Bahan baku diperbarui')
    } else {
      payload.opening_stock = Number(f.opening_stock) || 0
      await stockItemsApi.create(payload)
      toast.success('Bahan baku ditambahkan')
    }
    showForm.value = false
    load()
  } catch (e) {
    toast.error(e?.message || 'Gagal menyimpan')
  } finally {
    saving.value = false
  }
}

async function toggleActive(row) {
  try {
    await stockItemsApi.toggle(row.id)
    load()
  } catch (e) {
    toast.error(e?.message || 'Gagal mengubah status')
  }
}

async function submitDelete() {
  saving.value = true
  try {
    await stockItemsApi.delete(deleteTarget.value.id)
    toast.success('Bahan baku dihapus')
    showDelete.value = false
    load()
  } catch (e) {
    toast.error(e?.message || 'Gagal menghapus')
  } finally {
    saving.value = false
  }
}

// ── Categories ────────────────────────────────────────────────

async function loadCategories() {
  catLoading.value = true
  try {
    categories.value = await stockItemCategoriesApi.list()
    catPage.value = 1
  } catch (e) {
    toast.error(e?.message || 'Gagal memuat kategori')
  } finally {
    catLoading.value = false
  }
}

function openCategories() {
  resetCatForm()
  showCategories.value = true
  loadCategories()
}

function resetCatForm() {
  catEditTarget.value = null
  catForm.value = EMPTY_CAT_FORM()
}

function openEditCategory(cat) {
  catEditTarget.value = cat
  catForm.value = { name: cat.name, notes: cat.notes }
}

async function submitCatForm() {
  catSaving.value = true
  try {
    if (catEditTarget.value) {
      await stockItemCategoriesApi.update(catEditTarget.value.id, catForm.value)
      toast.success('Kategori diperbarui')
    } else {
      await stockItemCategoriesApi.create(catForm.value)
      toast.success('Kategori ditambahkan')
    }
    resetCatForm()
    await loadCategories()
  } catch (e) {
    toast.error(e?.message || 'Gagal menyimpan kategori')
  } finally {
    catSaving.value = false
  }
}

async function deleteCategoryItem(cat) {
  if (!confirm(`Hapus kategori "${cat.name}"?`)) return
  try {
    await stockItemCategoriesApi.delete(cat.id)
    toast.success('Kategori dihapus')
    await loadCategories()
  } catch (e) {
    toast.error(e?.message || 'Gagal menghapus kategori')
  }
}
</script>
