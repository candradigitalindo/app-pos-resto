<template>
  <div class="space-y-6">
    <div v-if="showPrinters" class="card">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div class="flex items-center gap-3">
          <div class="flex h-12 w-12 items-center justify-center rounded-xl bg-purple-100">
            <svg class="h-6 w-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z" />
            </svg>
          </div>
          <div>
            <h2 class="text-lg font-semibold text-slate-900">Printer LAN</h2>
            <p class="text-sm text-slate-500">Kelola printer untuk kitchen, bar, dan cashier</p>
          </div>
        </div>
        <button @click="showAddModal = true" class="btn-primary flex items-center gap-2">
          <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          Tambah Printer
        </button>
      </div>

      <div v-if="loading" class="mt-6 flex items-center justify-center gap-3 py-8 text-slate-500">
        <div class="h-6 w-6 animate-spin rounded-full border-2 border-slate-300 border-t-purple-600"></div>
        <p>Memuat data printer...</p>
      </div>

      <div v-else-if="printers.length === 0" class="mt-6 rounded-2xl border-2 border-dashed border-slate-200 bg-slate-50 p-8 text-center">
        <svg class="mx-auto h-16 w-16 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z" />
        </svg>
        <h3 class="mt-4 text-base font-semibold text-slate-900">Belum Ada Printer</h3>
        <p class="mt-2 text-sm text-slate-500">Tambahkan printer LAN untuk sistem cetak otomatis ke kitchen, bar, atau cashier</p>
        <button @click="showAddModal = true" class="btn-primary mt-4 flex items-center gap-2 mx-auto">
          <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          Tambah Printer Pertama
        </button>
      </div>

      <div v-else class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <div v-for="printer in printers" :key="printer.id" class="group rounded-2xl border-2 border-slate-200 bg-white p-4 shadow-sm transition hover:border-purple-200 hover:shadow-md">
          <div class="flex items-center justify-between">
            <span class="flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-semibold" :class="getPrinterStatusClass(printer)">
              <svg class="h-3 w-3" fill="currentColor" viewBox="0 0 8 8">
                <circle cx="4" cy="4" r="3" />
              </svg>
              {{ getPrinterStatusLabel(printer) }}
            </span>
            <span class="rounded-full px-3 py-1 text-xs font-semibold" :class="printer.printer_type === 'kitchen' ? 'bg-emerald-100 text-emerald-700' : printer.printer_type === 'bar' ? 'bg-indigo-100 text-indigo-700' : 'bg-amber-100 text-amber-700'">
              {{ getPrinterTypeLabel(printer.printer_type) }}
            </span>
          </div>

          <h3 class="mt-3 text-base font-semibold text-slate-900">{{ printer.name }}</h3>

          <div class="mt-3 space-y-2">
            <div class="flex items-center gap-2 text-sm">
              <svg class="h-4 w-4 flex-shrink-0 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9" />
              </svg>
              <span class="text-slate-500">IP:</span>
              <span class="font-mono font-semibold text-slate-900">{{ printer.ip_address }}</span>
            </div>
            <div class="flex items-center gap-2 text-sm">
              <svg class="h-4 w-4 flex-shrink-0 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
              <span class="text-slate-500">Port:</span>
              <span class="font-mono font-semibold text-slate-900">{{ printer.port }}</span>
            </div>
            <div class="flex items-center gap-2 text-sm">
              <svg class="h-4 w-4 flex-shrink-0 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
              <span class="text-slate-500">Kertas:</span>
              <span class="font-semibold text-slate-900">{{ printer.paper_size || '80mm' }}</span>
            </div>
          </div>

          <div v-if="getPrinterIssue(printer.id)" class="mt-3 rounded-xl border border-amber-200 bg-amber-50 p-3 text-xs text-amber-800">
            <div class="font-semibold">Printer bermasalah</div>
            <div class="mt-1 text-amber-700">Terakhir gagal: {{ getPrinterIssueMessage(printer.id) }}</div>
            <div class="mt-1 text-amber-700">Waktu: {{ formatPrintQueueTime(getPrinterIssue(printer.id).created_at) }}</div>
            <div class="mt-2 text-amber-700">Saran: cek listrik, koneksi LAN/WiFi, IP/port, lalu coba Test Print.</div>
          </div>

          <div v-if="getFailedLogs(printer.id).length" class="mt-3 rounded-xl border border-slate-200 bg-slate-50 p-3 text-xs text-slate-700">
            <div class="flex items-center justify-between">
              <div class="font-semibold text-slate-800">Log cetak gagal</div>
              <div class="text-[11px] text-slate-500">Total: {{ getFailedLogs(printer.id).length }}</div>
            </div>
            <div class="mt-2 space-y-2">
              <div v-for="item in getFailedLogs(printer.id).slice(0, 3)" :key="item.id" class="flex items-start justify-between gap-2 rounded-lg border border-slate-200 bg-white px-2 py-1.5">
                <div>
                  <div class="text-slate-700">{{ normalizeIssueMessage(item.error_message) }}</div>
                  <div class="text-[11px] text-slate-500">Tujuan: {{ formatPrintTarget(item) }}</div>
                  <div class="text-[11px] text-slate-500">Konten: {{ formatPrintContent(item) }}</div>
                  <div class="text-[11px] text-slate-500">Percobaan: {{ item.retry_count }} • {{ formatPrintQueueTime(item.created_at) }}</div>
                </div>
                <button
                  @click="retryPrintQueue(item)"
                  class="btn-secondary px-2 py-1 text-[11px]"
                  :disabled="retryingQueueId === item.id"
                >
                  {{ retryingQueueId === item.id ? 'Mengulang...' : 'Cetak Ulang' }}
                </button>
              </div>
            </div>
          </div>

          <div class="mt-4 flex items-center gap-2">
            <button @click="editPrinter(printer)" class="btn-secondary flex-1 flex items-center justify-center gap-1.5 px-3" title="Edit">
              <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
              </svg>
            </button>
            <button @click="togglePrinter(printer)" class="btn-secondary px-3" :title="printer.is_active ? 'Nonaktifkan' : 'Aktifkan'">
              <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path v-if="printer.is_active" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                <path v-else stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" />
                <path v-if="!printer.is_active" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </button>
            <button
              @click="testPrint(printer)"
              class="btn-secondary px-3"
              :disabled="!printer.is_active || testingPrinter === printer.id"
              title="Test Print"
            >
              <svg class="h-4 w-4" :class="testingPrinter === printer.id ? 'animate-pulse' : ''" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z" />
              </svg>
            </button>
            <button @click="deletePrinter(printer)" class="btn-secondary px-3 hover:bg-red-50 hover:text-red-600" title="Hapus">
              <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
              </svg>
            </button>
          </div>
        </div>
      </div>
    </div>

    <div v-if="showFailedLogs" class="card">
      <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h3 class="text-base sm:text-lg font-semibold text-slate-900">Log Cetak Gagal</h3>
          <p class="text-xs sm:text-sm text-slate-500">Riwayat antrian cetak dengan status gagal</p>
        </div>
        <div class="flex items-center gap-2">
          <div class="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-600">
            Total: {{ printQueueTotal }}
          </div>
          <button @click="fetchPrintQueue" class="btn-secondary px-3 py-1 text-xs" :disabled="printQueueLoading">
            {{ printQueueLoading ? 'Memuat...' : 'Muat Ulang' }}
          </button>
        </div>
      </div>

      <div v-if="printQueueLoading" class="mt-4 flex items-center justify-center gap-3 py-6 text-slate-500">
        <div class="h-5 w-5 animate-spin rounded-full border-2 border-slate-300 border-t-purple-600"></div>
        <span>Memuat log cetak...</span>
      </div>

      <div v-else-if="printQueueError" class="mt-4 rounded-2xl border border-red-200 bg-red-50 p-4 text-sm text-red-600">
        {{ printQueueError }}
      </div>

      <div v-else-if="printQueueTotal === 0" class="mt-4 rounded-2xl border-2 border-dashed border-slate-200 bg-slate-50 p-6 text-center text-sm text-slate-500">
        Belum ada log cetak gagal
      </div>

      <div v-else class="mt-4 space-y-3">
        <div v-for="item in printQueuePaged" :key="item.id" class="flex flex-col gap-2 rounded-2xl border border-slate-200 bg-white p-4 sm:flex-row sm:items-center sm:justify-between">
          <div class="space-y-1">
            <div class="text-sm font-semibold text-slate-800">{{ item.printer_name || item.printer_id }}</div>
            <div class="text-sm text-slate-700">{{ normalizeIssueMessage(item.error_message) }}</div>
            <div class="text-xs text-slate-500">Tujuan: {{ formatPrintTarget(item) }}</div>
            <div class="text-xs text-slate-500">Konten: {{ formatPrintContent(item) }}</div>
            <div class="text-xs text-slate-500">Percobaan: {{ item.retry_count }} • {{ formatPrintQueueTime(item.created_at) }}</div>
          </div>
          <button
            @click="retryPrintQueue(item)"
            class="btn-secondary px-3 py-1.5 text-xs"
            :disabled="retryingQueueId === item.id"
          >
            {{ retryingQueueId === item.id ? 'Mengulang...' : 'Cetak Ulang' }}
          </button>
        </div>
        <Pagination
          v-if="printQueueTotalPages > 1"
          class="mt-4"
          :current-page="printQueuePage"
          :total-pages="printQueueTotalPages"
          :total-items="printQueueTotal"
          item-name="log"
          @page-change="changePrintQueuePage"
        />
      </div>
    </div>

    <div v-if="showPrinters && (showAddModal || showEditModal)" class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-slate-900/60 sm:px-4" @click="closeModal">
      <div class="w-full max-w-6xl rounded-t-3xl sm:rounded-3xl bg-white shadow-soft max-h-[90vh] sm:max-h-[85vh] overflow-hidden flex flex-col" @click.stop>
        <div class="flex items-center justify-between border-b border-slate-100 px-4 sm:px-6 py-3 sm:py-4 sticky top-0 bg-white z-10">
          <div class="flex items-center gap-2 sm:gap-3">
            <div class="flex h-8 w-8 sm:h-10 sm:w-10 items-center justify-center rounded-xl bg-purple-100">
              <svg class="h-5 w-5 sm:h-6 sm:w-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z" />
              </svg>
            </div>
            <h2 class="text-base sm:text-lg font-semibold text-slate-900">{{ showEditModal ? 'Edit Printer' : 'Tambah Printer Baru' }}</h2>
          </div>
          <button @click="closeModal" class="flex h-8 w-8 sm:h-9 sm:w-9 items-center justify-center rounded-lg bg-slate-100 text-slate-600 transition hover:bg-slate-200">
            <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div class="grid gap-4 sm:gap-6 p-4 sm:p-6 lg:grid-cols-[380px,1fr] overflow-y-auto flex-1">
          <form @submit.prevent="savePrinter" class="space-y-4">
            <div>
              <label class="text-sm font-semibold text-slate-700">Nama Printer *</label>
              <input v-model="form.name" type="text" class="input mt-2" placeholder="Printer Kitchen 1" required />
            </div>

            <div class="grid gap-4 sm:grid-cols-2">
              <div>
                <label class="text-sm font-semibold text-slate-700">IP Address / Hostname *</label>
                <input
                  v-model="form.ip_address"
                  type="text"
                  class="input mt-2"
                  placeholder="192.168.1.100 atau printer.local"
                  required
                />
              </div>
              <div>
                <label class="text-sm font-semibold text-slate-700">Port</label>
                <input v-model.number="form.port" type="number" class="input mt-2" placeholder="9100" min="1" max="65535" />
              </div>
            </div>

            <div>
              <label class="text-sm font-semibold text-slate-700">Tipe Printer *</label>
              <select v-model="form.printer_type" @change="applyPresetByType" class="input mt-2" required>
                <option value="">Pilih tipe printer</option>
                <option value="kitchen">Kitchen</option>
                <option value="bar">Bar</option>
                <option value="cashier">Cashier</option>
                <option value="checker">Checker</option>
                <option value="struk">Struk</option>
              </select>
            </div>

            <div>
              <label class="text-sm font-semibold text-slate-700">Ukuran Kertas *</label>
              <select v-model="form.paper_size" class="input mt-2" required>
                <option value="">Pilih ukuran kertas</option>
                <option value="58mm">58mm</option>
                <option value="80mm">80mm</option>
              </select>
            </div>

            <label class="mt-2 flex items-center gap-2 text-sm text-slate-600">
              <input type="checkbox" v-model="form.is_active_bool" class="h-4 w-4 accent-emerald-600" />
              Aktifkan printer
            </label>

            <div v-if="formError" class="rounded-2xl border border-red-200 bg-red-50 p-3 text-sm text-red-600">
              {{ formError }}
            </div>

            <div class="flex flex-col sm:flex-row items-stretch sm:items-center gap-2">
              <button type="button" @click="closeModal" class="btn-secondary">Batal</button>
              <button type="submit" class="btn-primary" :disabled="saving">
                {{ saving ? 'Menyimpan...' : 'Simpan' }}
              </button>
            </div>

            <div class="rounded-2xl border border-slate-200 bg-slate-50 p-4 text-xs text-slate-600">
              <strong class="text-slate-800">Pengaturan Outlet</strong>
              <p class="mt-1">Nama outlet, alamat, kontak, sosial media, dan ucapan diatur di <strong>General Settings → Outlet Configuration</strong></p>
            </div>
          </form>

          <div class="hidden lg:block relative space-y-4 pl-6 before:absolute before:left-0 before:top-0 before:bottom-0 before:w-px before:bg-gradient-to-b before:from-transparent before:via-slate-200 before:to-transparent">
            <h3 class="text-sm font-semibold text-slate-700">Preview Hasil Cetak</h3>
            
            <!-- Thermal Paper Preview Container -->
            <div class="flex justify-center">
              <div 
                class="relative bg-white shadow-lg overflow-hidden"
                :style="{
                  width: form.paper_size === '58mm' ? '218px' : '302px',
                  maxHeight: '600px',
                  overflowY: 'auto'
                }"
              >
                <!-- Paper texture effect -->
                <div class="absolute inset-0 opacity-5 pointer-events-none" style="background-image: repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(0,0,0,0.03) 2px, rgba(0,0,0,0.03) 4px);"></div>
                
                <!-- Receipt content -->
                <div 
                  class="relative p-3 font-mono text-slate-900"
                  :class="form.paper_size === '58mm' ? 'text-[9px] leading-tight' : 'text-[11px] leading-relaxed'"
                >
                  <div class="text-center font-bold" :class="form.paper_size === '58mm' ? 'text-[10px]' : 'text-xs'">
                    {{ outletConfig.outlet_name.toUpperCase() }}
                  </div>
                  <div class="text-center text-slate-600" :class="form.paper_size === '58mm' ? 'text-[8px]' : 'text-[10px]'">
                    {{ outletConfig.outlet_address }}
                  </div>
                  <div class="text-center text-slate-600" :class="form.paper_size === '58mm' ? 'text-[8px]' : 'text-[10px]'">
                    {{ outletConfig.outlet_phone }}
                  </div>
                  
                  <div class="my-2 border-t border-dashed border-slate-400"></div>
                  
                  <div :class="form.paper_size === '58mm' ? 'space-y-0.5' : 'space-y-1'">
                    <div>No. Struk : #TRX-001234</div>
                    <div>Tanggal : 28/01/2026 14:30</div>
                    <div>Meja : #5</div>
                    <div>Customer : Andi Wijaya</div>
                  </div>
                  
                  <div class="my-2 border-t border-dashed border-slate-400"></div>
                  
                  <!-- Table Header -->
                  <div 
                    class="grid gap-1 font-semibold uppercase text-slate-600"
                    :class="form.paper_size === '58mm' ? 'grid-cols-[1fr,24px,38px,42px] text-[8px]' : 'grid-cols-[1fr,28px,50px,60px] text-[9px]'"
                  >
                    <span>ITEM</span>
                    <span class="text-center">QTY</span>
                    <span class="text-right">HARGA</span>
                    <span class="text-right">TOTAL</span>
                  </div>
                  
                  <div class="my-1 border-t border-dashed border-slate-400"></div>
                  
                  <!-- Items -->
                  <div 
                    class="gap-1"
                    :class="form.paper_size === '58mm' ? 'space-y-1' : 'space-y-1.5'"
                  >
                    <div 
                      class="grid gap-1"
                      :class="form.paper_size === '58mm' ? 'grid-cols-[1fr,24px,38px,42px]' : 'grid-cols-[1fr,28px,50px,60px]'"
                    >
                      <span>Nasi Goreng Spesial</span>
                      <span class="text-center">2</span>
                      <span class="text-right">17.500</span>
                      <span class="text-right">35.000</span>
                    </div>
                    <div 
                      class="grid gap-1"
                      :class="form.paper_size === '58mm' ? 'grid-cols-[1fr,24px,38px,42px]' : 'grid-cols-[1fr,28px,50px,60px]'"
                    >
                      <span>Es Teh Manis</span>
                      <span class="text-center">2</span>
                      <span class="text-right">4.000</span>
                      <span class="text-right">8.000</span>
                    </div>
                    <div 
                      class="grid gap-1"
                      :class="form.paper_size === '58mm' ? 'grid-cols-[1fr,24px,38px,42px]' : 'grid-cols-[1fr,28px,50px,60px]'"
                    >
                      <span>Ayam Goreng Kremes</span>
                      <span class="text-center">1</span>
                      <span class="text-right">25.000</span>
                      <span class="text-right">25.000</span>
                    </div>
                  </div>
                  
                  <div class="my-2 border-t border-dashed border-slate-400"></div>
                  
                  <!-- Totals -->
                  <div :class="form.paper_size === '58mm' ? 'space-y-0.5' : 'space-y-1'">
                    <div class="flex justify-between">
                      <span>Subtotal</span>
                      <span>Rp 68.000</span>
                    </div>
                    <div class="flex justify-between">
                      <span>Pajak (10%)</span>
                      <span>Rp 6.800</span>
                    </div>
                    <div class="flex justify-between font-bold" :class="form.paper_size === '58mm' ? 'text-[10px]' : 'text-xs'">
                      <span>Total</span>
                      <span>Rp 74.800</span>
                    </div>
                  </div>
                  
                  <div class="my-2 border-t border-dashed border-slate-400"></div>
                  
                  <!-- Footer -->
                  <div v-if="outletConfig.receipt_footer" class="text-center text-slate-600">
                    {{ outletConfig.receipt_footer }}
                  </div>
                  <div v-if="outletConfig.social_media" class="text-center text-slate-600">
                    {{ outletConfig.social_media }}
                  </div>
                  
                  <!-- Bottom spacing for tear -->
                  <div class="h-8"></div>
                </div>
                
                <!-- Paper edge effect (tear line) -->
                <div class="absolute bottom-0 left-0 right-0 h-3 bg-gradient-to-b from-white to-slate-200 opacity-50"></div>
              </div>
            </div>

            <div class="rounded-xl border-2 p-4 text-xs" :class="form.paper_size === '58mm' ? 'border-indigo-200 bg-indigo-50 text-indigo-800' : 'border-amber-200 bg-amber-50 text-amber-800'">
              <div class="flex items-center gap-2">
                <svg class="h-4 w-4 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                </svg>
                <strong>{{ form.paper_size === '58mm' ? 'Printer Portable' : 'Printer Standard' }}</strong>
              </div>
              <p class="mt-2">
                {{ form.paper_size === '58mm' 
                  ? 'Ukuran standard kasir thermal. Text lebih besar dan mudah dibaca.' 
                  : 'Cocok untuk printer portable/mobile. Text lebih kecil dan padat.' 
                }}
              </p>
              <p class="mt-1.5 font-semibold">
                Ukuran saat ini: {{ form.paper_size === '58mm' ? '58mm (2")' : '80mm (3")' }}
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div v-if="showPrinters && showDeleteModal" class="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 px-4" @click="showDeleteModal = false">
      <div class="w-full max-w-md rounded-3xl bg-white p-6 shadow-soft" @click.stop>
        <h2 class="text-lg font-semibold text-slate-900">Hapus Printer?</h2>
        <p class="mt-2 text-sm text-slate-500">Yakin ingin menghapus printer <strong>{{ printerToDelete?.name }}</strong>?</p>
        <p class="mt-1 text-xs text-slate-400">Aksi ini tidak dapat dibatalkan.</p>
        <div class="mt-4 flex items-center gap-2">
          <button @click="showDeleteModal = false" class="btn-secondary">Batal</button>
          <button @click="confirmDelete" class="btn-primary" :disabled="saving">
            {{ saving ? 'Menghapus...' : 'Hapus' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, ref, onMounted, watch } from 'vue'
import api from '../services/api'
import Pagination from './Pagination.vue'

const printers = ref([])
const loading = ref(false)
const saving = ref(false)
const showAddModal = ref(false)
const showEditModal = ref(false)
const showDeleteModal = ref(false)
const printerToDelete = ref(null)
const formError = ref('')
const testingPrinter = ref(null)
const retryingQueueId = ref(null)
const printQueueFailed = ref([])
const printQueueLoading = ref(false)
const printQueueError = ref('')
const printQueuePage = ref(1)
const printQueuePageSize = ref(10)

const outletConfig = ref({
  outlet_name: 'Outlet',
  outlet_address: 'Alamat Outlet',
  outlet_phone: 'Telp: -',
  social_media: '',
  receipt_footer: 'Terima kasih atas kunjungan Anda!'
})

const form = ref({
  id: null,
  name: '',
  ip_address: '',
  port: 9100,
  printer_type: '',
  paper_size: '80mm',
  is_active_bool: true,
  connection_timeout: 3,
  write_timeout: 5,
  retry_attempts: 2,
  print_density: 50,
  print_speed: 'normal',
  cut_mode: 'partial',
  enable_beep: 1,
  auto_cut: 1,
  charset: 'latin'
})

const props = defineProps({
  showPrinters: {
    type: Boolean,
    default: true
  },
  showFailedLogs: {
    type: Boolean,
    default: true
  }
})

const emit = defineEmits(['success', 'error'])

const fetchPrinters = async () => {
  try {
    loading.value = true
    const response = await api.get('/printers')
    printers.value = response.data.data || []
  } catch (error) {
    console.error('Failed to fetch printers:', error)
    emit('error', 'Gagal memuat data printer')
  } finally {
    loading.value = false
  }
}

const fetchOutletConfig = async () => {
  try {
    const response = await api.get('/config/outlet')
    if (response.data.data) {
      outletConfig.value = response.data.data
    }
  } catch (error) {
    console.error('Failed to fetch outlet config:', error)
  }
}

const fetchPrintQueue = async () => {
  try {
    printQueueLoading.value = true
    printQueueError.value = ''
    const response = await api.get('/print/queue', { params: { status: 'failed' } })
    if (response.data?.success === false) {
      printQueueFailed.value = []
      printQueueError.value = response.data?.message || 'Gagal memuat log cetak'
      emit('error', printQueueError.value)
      return
    }
    const data = response.data?.data
    printQueueFailed.value = Array.isArray(data) ? data : []
  } catch (error) {
    console.error('Failed to fetch print queue:', error)
    printQueueFailed.value = []
    const message = error.response?.data?.message || error.response?.data?.error || 'Gagal memuat log cetak'
    printQueueError.value = message
    emit('error', message)
  } finally {
    printQueueLoading.value = false
  }
}

const printQueueTotal = computed(() => printQueueFailed.value.length)
const printQueueTotalPages = computed(() => {
  if (printQueueTotal.value === 0) return 1
  return Math.ceil(printQueueTotal.value / printQueuePageSize.value)
})

const printQueuePaged = computed(() => {
  const totalPages = printQueueTotalPages.value
  const safePage = Math.min(printQueuePage.value, totalPages)
  const start = (safePage - 1) * printQueuePageSize.value
  return printQueueFailed.value.slice(start, start + printQueuePageSize.value)
})

const changePrintQueuePage = (page) => {
  printQueuePage.value = page
}

watch([printQueueTotal, printQueuePageSize], () => {
  const totalPages = printQueueTotalPages.value
  if (printQueuePage.value > totalPages) {
    printQueuePage.value = totalPages
  }
})

const printerIssues = computed(() => {
  const issues = new Map()
  for (const item of printQueueFailed.value) {
    if (!item?.printer_id) continue
    const existing = issues.get(item.printer_id)
    if (!existing) {
      issues.set(item.printer_id, item)
      continue
    }
    const existingTime = new Date(existing.created_at).getTime()
    const currentTime = new Date(item.created_at).getTime()
    if (!Number.isNaN(currentTime) && (Number.isNaN(existingTime) || currentTime > existingTime)) {
      issues.set(item.printer_id, item)
    }
  }
  return issues
})

const getPrinterIssue = (printerId) => {
  return printerIssues.value.get(printerId) || null
}

const failedLogsByPrinter = computed(() => {
  const logs = new Map()
  for (const item of printQueueFailed.value) {
    if (!item?.printer_id) continue
    const list = logs.get(item.printer_id) || []
    list.push(item)
    logs.set(item.printer_id, list)
  }
  for (const list of logs.values()) {
    list.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
  }
  return logs
})

const getFailedLogs = (printerId) => {
  return failedLogsByPrinter.value.get(printerId) || []
}

const normalizeIssueMessage = (message) => {
  if (!message) return 'Gagal mencetak'
  const normalized = String(message).toLowerCase()
  if (normalized.includes('timeout')) return 'Koneksi ke printer timeout'
  if (normalized.includes('refused')) return 'Koneksi ditolak oleh printer'
  if (normalized.includes('no route to host') || normalized.includes('unreachable')) return 'Printer tidak terjangkau di jaringan'
  if (normalized.includes('connection')) return 'Koneksi ke printer bermasalah'
  return message
}

const getPrinterIssueMessage = (printerId) => {
  const issue = getPrinterIssue(printerId)
  if (!issue) return ''
  return normalizeIssueMessage(issue.error_message)
}

const formatPrintQueueTime = (value) => {
  if (!value) return '-'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value
  return new Intl.DateTimeFormat('id-ID', { dateStyle: 'medium', timeStyle: 'short' }).format(date)
}

const getPrinterTypeLabel = (type) => {
  const labels = {
    kitchen: 'Kitchen',
    bar: 'Bar',
    cashier: 'Kasir',
    checker: 'Checker',
    struk: 'Struk'
  }
  return labels[type] || type
}

const formatPrintTarget = (item) => {
  const parts = []
  const printerName = item?.printer_name || item?.printer_id
  if (printerName) {
    parts.push(printerName)
  }
  const typeLabel = item?.printer_type ? getPrinterTypeLabel(item.printer_type) : ''
  if (typeLabel && typeLabel !== printerName) {
    parts.push(typeLabel)
  }
  const address = item?.printer_ip
    ? item?.printer_port
      ? `${item.printer_ip}:${item.printer_port}`
      : item.printer_ip
    : ''
  if (address) {
    parts.push(address)
  }
  return parts.length ? parts.join(' • ') : '-'
}

const formatPrintContent = (item) => {
  if (item?.content_summary) return item.content_summary
  const parts = []
  if (item?.content_type) parts.push(item.content_type)
  if (item?.receipt_number) parts.push(item.receipt_number)
  if (item?.table_number && item.table_number !== '-') parts.push(`Meja ${item.table_number}`)
  if (item?.order_id) parts.push(`Order ${item.order_id}`)
  return parts.length ? parts.join(' • ') : '-'
}

const getPrinterStatusLabel = (printer) => {
  if (!printer?.is_active) return 'Nonaktif'
  if (getPrinterIssue(printer.id)) return 'Bermasalah'
  return 'Aktif (Konfigurasi)'
}

const getPrinterStatusClass = (printer) => {
  if (!printer?.is_active) return 'bg-slate-100 text-slate-600'
  if (getPrinterIssue(printer.id)) return 'bg-amber-100 text-amber-700'
  return 'bg-emerald-100 text-emerald-700'
}

const applyPresetByType = () => {
  if (form.value.printer_type === 'kitchen') {
    form.value.print_speed = 'normal'
    form.value.print_density = 55
  }
  if (form.value.printer_type === 'bar') {
    form.value.print_speed = 'fast'
    form.value.print_density = 45
  }
  if (form.value.printer_type === 'cashier') {
    form.value.print_speed = 'normal'
    form.value.print_density = 60
  }
}

const editPrinter = (printer) => {
  // Helper to extract value from SQL null types
  const extractValue = (val, defaultVal) => {
    if (val === null || val === undefined) return defaultVal
    if (typeof val === 'object' && 'Int64' in val) return val.Int64 || defaultVal
    if (typeof val === 'object' && 'String' in val) return val.String || defaultVal
    return val || defaultVal
  }

  form.value = {
    id: printer.id,
    name: printer.name,
    ip_address: printer.ip_address,
    port: printer.port,
    printer_type: printer.printer_type,
    paper_size: printer.paper_size || '80mm',
    is_active_bool: printer.is_active === 1,
    connection_timeout: extractValue(printer.connection_timeout, 3),
    write_timeout: extractValue(printer.write_timeout, 5),
    retry_attempts: extractValue(printer.retry_attempts, 2),
    print_density: extractValue(printer.print_density, 50),
    print_speed: extractValue(printer.print_speed, 'normal'),
    cut_mode: extractValue(printer.cut_mode, 'partial'),
    enable_beep: extractValue(printer.enable_beep, 1),
    auto_cut: extractValue(printer.auto_cut, 1),
    charset: extractValue(printer.charset, 'latin')
  }
  showEditModal.value = true
}

const resetForm = () => {
  form.value = {
    id: null,
    name: '',
    ip_address: '',
    port: 9100,
    printer_type: '',
    paper_size: '80mm',
    is_active_bool: true,
    connection_timeout: 3,
    write_timeout: 5,
    retry_attempts: 2,
    print_density: 50,
    print_speed: 'normal',
    cut_mode: 'partial',
    enable_beep: 1,
    auto_cut: 1,
    charset: 'latin'
  }
  formError.value = ''
}

const closeModal = () => {
  showAddModal.value = false
  showEditModal.value = false
  resetForm()
}

const savePrinter = async () => {
  try {
    saving.value = true
    formError.value = ''

    const payload = {
      name: form.value.name,
      ip_address: form.value.ip_address,
      port: form.value.port || 9100,
      printer_type: form.value.printer_type,
      paper_size: form.value.paper_size || '80mm',
      is_active: form.value.is_active_bool ? 1 : 0,
      connection_timeout: form.value.connection_timeout || 0,
      write_timeout: form.value.write_timeout || 0,
      retry_attempts: form.value.retry_attempts || 0,
      print_density: form.value.print_density || 0,
      print_speed: form.value.print_speed || '',
      cut_mode: form.value.cut_mode || '',
      enable_beep: form.value.enable_beep || 0,
      auto_cut: form.value.auto_cut || 0,
      charset: form.value.charset || ''
    }

    if (showEditModal.value) {
      await api.put(`/printers/${form.value.id}`, payload)
      emit('success', 'Printer berhasil diupdate')
    } else {
      await api.post('/printers', payload)
      emit('success', 'Printer berhasil ditambahkan')
    }

    closeModal()
    await fetchPrinters()
  } catch (error) {
    console.error('Failed to save printer:', error)
    console.error('Error response:', error.response?.data)
    formError.value = error.response?.data?.message || error.response?.data?.error || 'Gagal menyimpan printer'
  } finally {
    saving.value = false
  }
}

const togglePrinter = async (printer) => {
  try {
    const newStatus = printer.is_active === 1 ? 0 : 1
    await api.patch(`/printers/${printer.id}/toggle`, { is_active: newStatus })
    emit('success', `Printer ${newStatus === 1 ? 'diaktifkan' : 'dinonaktifkan'}`)
    await fetchPrinters()
  } catch (error) {
    console.error('Failed to toggle printer:', error)
    emit('error', 'Gagal mengubah status printer')
  }
}

const testPrint = async (printer) => {
  try {
    testingPrinter.value = printer.id
    await api.post(`/printers/${printer.id}/test`)
    emit('success', `Test print berhasil dikirim ke ${printer.name}`)
  } catch (error) {
    console.error('Failed to test print:', error)
    const message = error.response?.data?.message || error.response?.data?.error || 'Gagal mengirim test print'
    emit('error', message)
  } finally {
    testingPrinter.value = null
  }
}

const retryPrintQueue = async (item) => {
  if (!item?.id) return
  try {
    retryingQueueId.value = item.id
    await api.post(`/print/queue/${item.id}/retry`)
    emit('success', 'Cetak ulang dikirim ke antrian')
    await fetchPrintQueue()
  } catch (error) {
    console.error('Failed to retry print queue:', error)
    emit('error', 'Gagal cetak ulang')
  } finally {
    retryingQueueId.value = null
  }
}

const deletePrinter = (printer) => {
  printerToDelete.value = printer
  showDeleteModal.value = true
}

const confirmDelete = async () => {
  if (!printerToDelete.value) return
  try {
    saving.value = true
    await api.delete(`/printers/${printerToDelete.value.id}`)
    emit('success', 'Printer berhasil dihapus')
    showDeleteModal.value = false
    await fetchPrinters()
  } catch (error) {
    console.error('Failed to delete printer:', error)
    emit('error', 'Gagal menghapus printer')
  } finally {
    saving.value = false
    printerToDelete.value = null
  }
}

onMounted(() => {
  if (props.showPrinters) {
    fetchPrinters()
    fetchOutletConfig()
  }
  if (props.showFailedLogs) {
    fetchPrintQueue()
  }
})
</script>
