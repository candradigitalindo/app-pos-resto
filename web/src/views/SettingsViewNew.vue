<template>
  <div class="page-shell">
    <div class="page-container space-y-4 sm:space-y-6 pb-24 sm:pb-6">
      <!-- Header -->
      <div class="card">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-4">
            <button @click="goBack" class="flex h-10 w-10 items-center justify-center rounded-xl bg-slate-100 text-slate-600 transition hover:bg-slate-200">
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
              </svg>
            </button>
            <div>
              <h1 class="text-xl sm:text-2xl font-bold text-slate-900">Pengaturan Outlet</h1>
              <p class="hidden sm:block text-sm text-slate-500">Kelola informasi, sinkronisasi, dan perangkat</p>
            </div>
          </div>
          <div class="flex items-center gap-3">
            <div class="flex h-11 w-11 items-center justify-center rounded-xl bg-gradient-to-br from-emerald-500 to-emerald-600 text-lg font-bold text-white shadow-lg">
              {{ user?.full_name?.charAt(0) || 'U' }}
            </div>
            <div class="hidden sm:block">
              <div class="text-sm font-semibold text-slate-900">{{ user?.full_name }}</div>
              <div class="text-xs text-slate-500 capitalize">{{ user?.role }}</div>
            </div>
          </div>
        </div>
      </div>

      <!-- Notifications -->
      <div v-if="successMessage" class="flex items-center gap-3 rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-emerald-700">
        <svg class="h-5 w-5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
        </svg>
        <span>{{ successMessage }}</span>
      </div>
      <div v-if="errorMessage" class="flex items-center gap-3 rounded-xl border border-red-200 bg-red-50 p-4 text-red-600">
        <svg class="h-5 w-5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
        </svg>
        <span>{{ errorMessage }}</span>
      </div>

      <!-- Loading -->
      <div v-if="isLoading" class="card flex items-center justify-center gap-3 py-12 text-slate-500">
        <div class="h-6 w-6 animate-spin rounded-full border-2 border-slate-300 border-t-emerald-600"></div>
        <p>Memuat konfigurasi...</p>
      </div>

      <div v-else class="grid gap-6 lg:grid-cols-[260px,1fr]">
        <div class="card h-fit">
          <div class="text-xs font-semibold text-slate-500">Menu Pengaturan</div>
          <div class="mt-3 space-y-2">
            <button
              @click="activeSection = 'outlet'"
              class="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-semibold transition"
              :class="activeSection === 'outlet' ? 'bg-emerald-600 text-white shadow-sm' : 'text-slate-600 hover:bg-slate-50'"
            >
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
              </svg>
              Informasi Outlet
            </button>
            <button
              @click="activeSection = 'cloud'"
              class="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-semibold transition"
              :class="activeSection === 'cloud' ? 'bg-emerald-600 text-white shadow-sm' : 'text-slate-600 hover:bg-slate-50'"
            >
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 15a4 4 0 004 4h9a5 5 0 10-.1-9.999 5.002 5.002 0 10-9.78 2.096A4.001 4.001 0 003 15z" />
              </svg>
              Sinkronisasi Cloud
            </button>
            <button
              @click="activeSection = 'additional_charges'"
              class="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-semibold transition"
              :class="activeSection === 'additional_charges' ? 'bg-emerald-600 text-white shadow-sm' : 'text-slate-600 hover:bg-slate-50'"
            >
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7a2 2 0 012-2h14a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2V7z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M8 12h2m4 0h2" />
              </svg>
              Biaya Tambahan
            </button>
            <button
              @click="activeSection = 'printer'"
              class="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-semibold transition"
              :class="activeSection === 'printer' ? 'bg-emerald-600 text-white shadow-sm' : 'text-slate-600 hover:bg-slate-50'"
            >
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z" />
              </svg>
              Printer
            </button>
            <button
              @click="activeSection = 'print_logs'"
              class="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-semibold transition"
              :class="activeSection === 'print_logs' ? 'bg-emerald-600 text-white shadow-sm' : 'text-slate-600 hover:bg-slate-50'"
            >
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
              Log Cetak Gagal
            </button>
          </div>
        </div>

        <div class="space-y-6">
          <div v-if="activeSection === 'outlet'" class="card space-y-4">
            <div class="flex items-start justify-between">
              <div class="flex items-center gap-3">
                <div class="flex h-12 w-12 items-center justify-center rounded-xl bg-blue-100">
                  <svg class="h-6 w-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                  </svg>
                </div>
                <div>
                  <h2 class="text-base sm:text-lg font-semibold text-slate-900">Informasi Outlet</h2>
                  <p class="hidden sm:block text-sm text-slate-500">Data untuk struk dan tampilan</p>
                </div>
              </div>
            </div>
            <div class="space-y-4">
            <div>
              <label class="mb-2 flex items-center gap-2 text-sm font-semibold text-slate-700">
                <svg class="h-4 w-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
                </svg>
                Nama Outlet
              </label>
              <input v-model="config.outlet_name" type="text" class="input" placeholder="Warung Makan Sederhana" :disabled="!isEditingOutlet" />
            </div>
            <div>
              <label class="mb-2 flex items-center gap-2 text-sm font-semibold text-slate-700">
                <svg class="h-4 w-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
                Alamat
              </label>
              <textarea v-model="config.outlet_address" rows="2" class="input" placeholder="Jl. Raya No. 123, Kota" :disabled="!isEditingOutlet"></textarea>
            </div>
            <div class="grid gap-4 sm:grid-cols-2">
              <div>
                <label class="mb-2 flex items-center gap-2 text-sm font-semibold text-slate-700">
                  <svg class="h-4 w-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
                  </svg>
                  No. Kontak
                </label>
                <input v-model="config.outlet_phone" type="tel" class="input" placeholder="08123456789" :disabled="!isEditingOutlet" />
              </div>
              <div>
                <label class="mb-2 flex items-center gap-2 text-sm font-semibold text-slate-700">
                  <svg class="h-4 w-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z" />
                  </svg>
                  Media Sosial
                </label>
                <input v-model="config.social_media" type="text" class="input" placeholder="@namaoutlet" :disabled="!isEditingOutlet" />
              </div>
            </div>
            <div>
              <label class="mb-2 flex items-center gap-2 text-sm font-semibold text-slate-700">
                <svg class="h-4 w-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                Salam Penutup Struk
              </label>
              <input v-model="config.receipt_footer" type="text" class="input" placeholder="Terima kasih atas kunjungan Anda!" :disabled="!isEditingOutlet" />
              <p class="mt-1.5 text-xs text-slate-500">Akan ditampilkan di bagian bawah struk pembayaran</p>
            </div>
            <div>
              <label class="mb-2 flex items-center gap-2 text-sm font-semibold text-slate-700">
                <svg class="h-4 w-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 1.119-3 2.5 0 1.172.96 2.126 2.25 2.415L12 13l.75-.085C14.04 12.626 15 11.672 15 10.5 15 9.119 13.657 8 12 8zm0 8c-2.206 0-4-1.79-4-4 0-1.657 1.343-3 3-3h2c1.657 0 3 1.343 3 3 0 2.21-1.794 4-4 4z" />
                </svg>
                Target Spend per Pax
              </label>
              <input v-model.number="config.target_spend_per_pax" type="number" min="0" class="input" placeholder="75000" :disabled="!isEditingOutlet" />
              <p class="mt-1.5 text-xs text-slate-500">Target rata-rata rupiah per orang untuk upselling</p>
            </div>
          </div>

          <div v-if="config.outlet_name" class="rounded-xl bg-slate-50 p-3">
            <div class="flex items-center gap-2 text-xs text-slate-500">
              <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <span>Terakhir diperbarui: {{ config.updated_at ? formatDateTime(config.updated_at) : '-' }}</span>
            </div>
          </div>

          <div class="flex flex-col sm:flex-row items-stretch sm:items-center justify-end gap-2 pt-2">
            <button v-if="!isEditingOutlet" @click="startEditOutlet" class="btn-secondary flex items-center justify-center gap-2">
              <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
              </svg>
              Edit Informasi
            </button>
            <template v-else>
              <button @click="cancelEditOutlet" class="btn-secondary">Batal</button>
              <button @click="saveOutletConfig" class="btn-primary flex items-center gap-2" :disabled="isSavingOutlet">
                <svg v-if="isSavingOutlet" class="h-4 w-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                </svg>
                <svg v-else class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
                {{ isSavingOutlet ? 'Menyimpan...' : 'Simpan Perubahan' }}
              </button>
            </template>
          </div>
          </div>

          <div v-if="activeSection === 'cloud'" class="space-y-6">
            <div class="card space-y-4">
              <div class="flex items-start justify-between">
                <div class="flex items-center gap-3">
                  <div class="flex h-12 w-12 items-center justify-center rounded-xl bg-indigo-100">
                    <svg class="h-6 w-6 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 15a4 4 0 004 4h9a5 5 0 10-.1-9.999 5.002 5.002 0 10-9.78 2.096A4.001 4.001 0 003 15z" />
                    </svg>
                  </div>
                  <div>
                    <h2 class="text-base sm:text-lg font-semibold text-slate-900">Sinkronisasi Cloud</h2>
                    <p class="hidden sm:block text-sm text-slate-500">Hubungkan ke server pusat (opsional)</p>
                  </div>
                </div>
              </div>

          <!-- Sync Toggle -->
          <div class="rounded-xl border-2" :class="syncStatus.sync_enabled ? 'border-emerald-200 bg-emerald-50/50' : 'border-slate-200 bg-slate-50'">
            <div class="flex items-center justify-between p-4">
              <div class="flex items-center gap-3">
                <div class="flex h-10 w-10 items-center justify-center rounded-lg" :class="syncStatus.sync_enabled ? 'bg-emerald-100' : 'bg-slate-200'">
                  <svg class="h-5 w-5" :class="syncStatus.sync_enabled ? 'text-emerald-600' : 'text-slate-500'" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                  </svg>
                </div>
                <div>
                  <p class="text-sm font-semibold" :class="syncStatus.sync_enabled ? 'text-emerald-900' : 'text-slate-900'">
                    {{ syncStatus.sync_enabled ? 'Sinkronisasi Aktif' : 'Sinkronisasi Nonaktif' }}
                  </p>
                  <p class="text-xs" :class="syncStatus.sync_enabled ? 'text-emerald-700' : 'text-slate-500'">
                    {{ syncStatus.sync_enabled ? 'Data otomatis disinkronkan' : 'Mode offline - data lokal saja' }}
                  </p>
                </div>
              </div>
              <label class="relative inline-flex cursor-pointer items-center">
                <input
                  type="checkbox"
                  class="peer sr-only"
                  v-model="syncStatus.sync_enabled"
                  @change="toggleSync"
                  :disabled="isTogglingSync || !syncStatus.cloud_configured"
                />
                <div class="peer h-6 w-11 rounded-full bg-slate-300 after:absolute after:left-[2px] after:top-[2px] after:h-5 after:w-5 after:rounded-full after:bg-white after:transition-all after:content-[''] peer-checked:bg-emerald-600 peer-checked:after:translate-x-full peer-disabled:opacity-50"></div>
              </label>
            </div>
          </div>

          <!-- Warning -->
          <div v-if="!syncStatus.cloud_configured" class="flex items-start gap-3 rounded-xl border border-amber-200 bg-amber-50 p-4">
            <svg class="h-5 w-5 flex-shrink-0 text-amber-600" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
            </svg>
            <div class="text-sm text-amber-800">
              <p class="font-semibold">Konfigurasi Belum Lengkap</p>
              <p class="mt-1">Isi URL API dan API Key untuk mengaktifkan sinkronisasi cloud</p>
            </div>
          </div>

          <!-- Worker Status -->
          <div v-if="syncStatus.worker_status" class="space-y-3 rounded-xl border border-slate-200 bg-white p-4">
            <div class="flex items-center justify-between">
              <span class="flex items-center gap-2 text-sm font-medium text-slate-600">
                <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                Status Worker
              </span>
              <span class="rounded-full px-3 py-1 text-xs font-semibold" :class="syncStatus.worker_status.running ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-600'">
                {{ syncStatus.worker_status.running ? 'Running' : 'Stopped' }}
              </span>
            </div>
            <div v-if="syncStatus.last_sync_at" class="flex items-center justify-between">
              <span class="flex items-center gap-2 text-sm text-slate-600">
                <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                Terakhir Sync
              </span>
              <span class="text-sm font-medium text-slate-900">{{ formatDateTime(syncStatus.last_sync_at) }}</span>
            </div>
            <div v-if="syncStatus.sync_interval_minutes" class="flex items-center justify-between">
              <span class="flex items-center gap-2 text-sm text-slate-600">
                <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                </svg>
                Interval
              </span>
              <span class="text-sm font-medium text-slate-900">Setiap {{ syncStatus.sync_interval_minutes }} menit</span>
            </div>
          </div>

          <!-- Config Fields -->
          <div class="space-y-4">
            <div>
              <label class="mb-2 flex items-center gap-2 text-sm font-semibold text-slate-700">
                <svg class="h-4 w-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9" />
                </svg>
                URL API Cloud
              </label>
              <input v-model="config.cloud_api_url" type="url" class="input" placeholder="https://api.yourcloud.com/v1" :disabled="!isEditingCloud" />
            </div>
            <div>
              <label class="mb-2 flex items-center gap-2 text-sm font-semibold text-slate-700">
                <svg class="h-4 w-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z" />
                </svg>
                API Key
              </label>
              <div class="relative">
                <input
                  v-model="config.cloud_api_key"
                  :type="showApiKey ? 'text' : 'password'"
                  class="input pr-20"
                  :placeholder="isEditingCloud ? 'Masukkan API key baru' : '••••••••••••'"
                  :disabled="!isEditingCloud"
                />
                <button type="button" class="absolute right-3 top-1/2 -translate-y-1/2 flex items-center gap-1 text-xs font-semibold text-slate-500 hover:text-slate-700" @click="showApiKey = !showApiKey">
                  <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path v-if="showApiKey" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                    <path v-else stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    <path v-if="!showApiKey" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                  </svg>
                </button>
              </div>
            </div>
            <div>
              <label class="mb-2 flex items-center gap-2 text-sm font-semibold text-slate-700">
                <svg class="h-4 w-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                Interval Sinkronisasi
              </label>
              <div class="flex items-center gap-2 sm:gap-3">
                <input v-model.number="config.sync_interval_minutes" type="number" min="1" max="60" class="input w-20 sm:w-24" :disabled="!isEditingCloud" />
                <span class="text-sm text-slate-500">menit</span>
                <span class="hidden sm:inline text-xs text-slate-400">(1-60 menit)</span>
              </div>
            </div>
          </div>

          <div class="flex flex-col sm:flex-row items-stretch sm:items-center justify-end gap-2 pt-2">
            <button v-if="!isEditingCloud" @click="startEditCloud" class="btn-secondary flex items-center justify-center gap-2">
              <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
              </svg>
              Edit Konfigurasi
            </button>
            <template v-else>
              <button @click="cancelEditCloud" class="btn-secondary">Batal</button>
              <button @click="saveCloudConfig" class="btn-primary flex items-center gap-2" :disabled="isSavingCloud">
                <svg v-if="isSavingCloud" class="h-4 w-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                </svg>
                <svg v-else class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
                {{ isSavingCloud ? 'Menyimpan...' : 'Simpan Perubahan' }}
              </button>
            </template>
          </div>
            </div>

            <div v-if="!isLoading && config.sync_enabled && !isEditingCloud" class="card">
              <div class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
                <div class="flex items-center gap-3">
                  <div class="flex h-12 w-12 items-center justify-center rounded-xl bg-emerald-100">
                    <svg class="h-6 w-6 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                    </svg>
                  </div>
                  <div>
                    <h3 class="text-base font-semibold text-slate-900">Sinkronisasi Manual</h3>
                    <p class="text-xs sm:text-sm text-slate-500">Paksakan upload data ke cloud sekarang</p>
                  </div>
                </div>
                <button @click="triggerManualSync" class="btn-primary flex items-center justify-center gap-2 w-full sm:w-auto" :disabled="isSyncing">
                  <svg class="h-5 w-5" :class="isSyncing ? 'animate-spin' : ''" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                  </svg>
                  {{ isSyncing ? 'Sedang Sync...' : 'Sync Sekarang' }}
                </button>
              </div>
            </div>
          </div>

          <div v-if="activeSection === 'additional_charges'" class="space-y-6">
            <div class="card space-y-4">
              <div class="flex items-start justify-between">
                <div class="flex items-center gap-3">
                  <div class="flex h-12 w-12 items-center justify-center rounded-xl bg-amber-100">
                    <svg class="h-6 w-6 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7a2 2 0 012-2h14a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2V7z" />
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M8 12h2m4 0h2" />
                    </svg>
                  </div>
                  <div>
                    <h2 class="text-base sm:text-lg font-semibold text-slate-900">Biaya Tambahan</h2>
                    <p class="hidden sm:block text-sm text-slate-500">Tambahkan pajak, service, atau biaya lainnya</p>
                  </div>
                </div>
                <button v-if="!isEditingCharge" @click="startAddCharge" class="btn-primary">Tambah Biaya</button>
              </div>

              <div v-if="isEditingCharge" class="space-y-4 rounded-xl border border-slate-200 bg-slate-50 p-4">
                <div class="grid gap-4 sm:grid-cols-2">
                  <div>
                    <label class="mb-2 block text-sm font-semibold text-slate-700">Nama</label>
                    <input v-model="chargeForm.name" type="text" class="input" placeholder="Pajak, Service, dll" />
                  </div>
                  <div>
                    <label class="mb-2 block text-sm font-semibold text-slate-700">Tipe</label>
                    <select v-model="chargeForm.charge_type" class="input">
                      <option value="percentage">Persentase</option>
                      <option value="fixed">Rupiah</option>
                    </select>
                  </div>
                </div>
                <div class="grid gap-4 sm:grid-cols-2">
                  <div>
                    <label class="mb-2 block text-sm font-semibold text-slate-700">Nilai</label>
                    <input v-model.number="chargeForm.value" type="number" min="0" class="input" :placeholder="chargeForm.charge_type === 'percentage' ? '10' : '20000'" />
                    <p class="mt-1 text-xs text-slate-500">
                      {{ chargeForm.charge_type === 'percentage' ? 'Masukkan 0-100' : 'Masukkan dalam rupiah' }}
                    </p>
                  </div>
                  <div class="flex items-center gap-3 pt-6">
                    <input id="chargeActive" v-model="chargeForm.is_active" type="checkbox" class="h-4 w-4 rounded border-slate-300 text-emerald-600 focus:ring-emerald-500" />
                    <label for="chargeActive" class="text-sm text-slate-700">Aktif</label>
                  </div>
                </div>
                <div class="flex flex-col sm:flex-row items-stretch sm:items-center justify-end gap-2">
                  <button @click="cancelChargeEdit" class="btn-secondary">Batal</button>
                  <button @click="saveCharge" class="btn-primary" :disabled="isSavingCharge">
                    {{ isSavingCharge ? 'Menyimpan...' : 'Simpan' }}
                  </button>
                </div>
              </div>

              <div v-if="isLoadingCharges" class="flex items-center gap-3 text-slate-500">
                <div class="h-5 w-5 animate-spin rounded-full border-2 border-slate-300 border-t-emerald-600"></div>
                <span>Memuat biaya tambahan...</span>
              </div>

              <div v-else>
                <div v-if="!additionalCharges.length" class="rounded-xl border border-dashed border-slate-200 p-6 text-center text-sm text-slate-500">
                  Belum ada biaya tambahan. Tambahkan pajak atau service untuk ditampilkan di tagihan.
                </div>
                <div v-else class="overflow-x-auto">
                  <DataTable :columns="additionalChargeColumns" :data="additionalCharges">
                    <template #cell-name="{ item }">
                      <span class="font-semibold text-slate-800">{{ item.name }}</span>
                    </template>
                    <template #cell-charge_type="{ item }">
                      <span class="text-slate-600">{{ item.charge_type === 'percentage' ? 'Persentase' : 'Rupiah' }}</span>
                    </template>
                    <template #cell-value="{ item }">
                      <span class="text-slate-700">{{ formatChargeValue(item) }}</span>
                    </template>
                    <template #cell-status="{ item }">
                      <div class="flex justify-center">
                        <label class="relative inline-flex cursor-pointer items-center">
                          <input
                            type="checkbox"
                            class="peer sr-only"
                            :checked="item.is_active"
                            :disabled="togglingCharges[item.id]"
                            @change="toggleChargeStatus(item, $event.target.checked)"
                          />
                          <div class="peer h-5 w-9 rounded-full bg-slate-300 after:absolute after:left-[2px] after:top-[2px] after:h-4 after:w-4 after:rounded-full after:bg-white after:transition-all after:content-[''] peer-checked:bg-emerald-600 peer-checked:after:translate-x-full peer-disabled:opacity-50"></div>
                        </label>
                      </div>
                    </template>
                    <template #cell-actions="{ item }">
                      <div class="flex items-center justify-end gap-2">
                        <button @click="startEditCharge(item)" class="btn-secondary px-3">Edit</button>
                        <button @click="deleteCharge(item)" class="btn-secondary px-3 hover:bg-red-50 hover:text-red-600">Hapus</button>
                      </div>
                    </template>
                  </DataTable>
                </div>
              </div>
            </div>
          </div>

          <div v-if="activeSection === 'printer'">
            <PrinterManagement :show-printers="true" :show-failed-logs="false" @success="handlePrinterSuccess" @error="handlePrinterError" />
          </div>

          <div v-if="activeSection === 'print_logs'">
            <PrinterManagement :show-printers="false" :show-failed-logs="true" @success="handlePrinterSuccess" @error="handlePrinterError" />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import api from '../services/api'
import DataTable from '../components/DataTable.vue'
import PrinterManagement from '../components/PrinterManagement.vue'

const router = useRouter()
const authStore = useAuthStore()

const user = computed(() => authStore.user)
const activeSection = ref('outlet')

const isLoading = ref(false)
const isSavingOutlet = ref(false)
const isSavingCloud = ref(false)
const isSyncing = ref(false)
const isTogglingSync = ref(false)
const isEditingOutlet = ref(false)
const isEditingCloud = ref(false)
const isLoadingCharges = ref(false)
const isSavingCharge = ref(false)
const isEditingCharge = ref(false)
const showApiKey = ref(false)
const successMessage = ref('')
const errorMessage = ref('')
const togglingCharges = ref({})
const additionalChargeColumns = [
  { key: 'name', label: 'Nama' },
  { key: 'charge_type', label: 'Tipe' },
  { key: 'value', label: 'Nilai', align: 'text-right' },
  { key: 'status', label: 'Status', align: 'text-center' },
  { key: 'actions', label: 'Aksi', align: 'text-right' }
]

const syncStatus = ref({
  sync_enabled: false,
  sync_interval_minutes: 5,
  cloud_configured: false,
  worker_status: null,
  last_sync_at: null
})

const originalOutletConfig = ref(null)
const originalCloudConfig = ref(null)

const config = ref({
  id: null,
  outlet_id: '',
  outlet_name: '',
  outlet_code: '',
  outlet_address: '',
  outlet_phone: '',
  receipt_footer: '',
  social_media: '',
  target_spend_per_pax: 0,
  cloud_api_url: '',
  cloud_api_key: '',
  cloud_api_key_masked: '',
  is_active: true,
  sync_enabled: false,
  sync_interval_minutes: 5,
  last_sync_at: null,
  created_at: null,
  updated_at: null
})

const additionalCharges = ref([])
const chargeForm = ref({
  id: null,
  name: '',
  charge_type: 'percentage',
  value: 0,
  is_active: true
})

const fetchConfig = async () => {
  try {
    isLoading.value = true
    errorMessage.value = ''

    const response = await api.get('/config/outlet')

    if (response.data.success && response.data.data) {
      const data = response.data.data
      config.value = {
        id: data.id,
        outlet_id: data.outlet_id || '',
        outlet_name: data.outlet_name || '',
        outlet_code: data.outlet_code || '',
        outlet_address: data.outlet_address || '',
        outlet_phone: data.outlet_phone || '',
        receipt_footer: data.receipt_footer ?? '',
        social_media: data.social_media || '',
        target_spend_per_pax: data.target_spend_per_pax || 0,
        cloud_api_url: data.cloud_api_url || '',
        cloud_api_key: '',
        cloud_api_key_masked: data.cloud_api_key_masked || '',
        is_active: data.is_active,
        sync_enabled: data.sync_enabled,
        sync_interval_minutes: data.sync_interval_minutes || 5,
        last_sync_at: data.last_sync_at,
        created_at: data.created_at,
        updated_at: data.updated_at
      }
    }

    await fetchSyncStatus()
  } catch (error) {
    if (error.response?.status === 404) {
      errorMessage.value = 'Konfigurasi belum dibuat. Silakan isi form dan simpan.'
      isEditingOutlet.value = true
    } else {
      errorMessage.value = 'Gagal memuat konfigurasi: ' + (error.response?.data?.error || error.message)
    }
  } finally {
    isLoading.value = false
  }
}

const resetChargeForm = () => {
  chargeForm.value = {
    id: null,
    name: '',
    charge_type: 'percentage',
    value: 0,
    is_active: true
  }
}

const fetchAdditionalCharges = async () => {
  try {
    isLoadingCharges.value = true
    const response = await api.get('/config/additional-charges')
    if (response.data.success) {
      additionalCharges.value = response.data.data || []
    }
  } catch (error) {
    errorMessage.value = 'Gagal memuat biaya tambahan: ' + (error.response?.data?.error || error.message)
  } finally {
    isLoadingCharges.value = false
  }
}

const fetchSyncStatus = async () => {
  try {
    const response = await api.get('/config/sync')
    if (response.data.success && response.data.data) {
      syncStatus.value = response.data.data
    }
  } catch (error) {
    // Silently handle sync status fetch error
  }
}

const startAddCharge = () => {
  resetChargeForm()
  isEditingCharge.value = true
  errorMessage.value = ''
  successMessage.value = ''
}

const startEditCharge = (charge) => {
  chargeForm.value = {
    id: charge.id,
    name: charge.name,
    charge_type: charge.charge_type,
    value: charge.value,
    is_active: charge.is_active
  }
  isEditingCharge.value = true
  errorMessage.value = ''
  successMessage.value = ''
}

const cancelChargeEdit = () => {
  resetChargeForm()
  isEditingCharge.value = false
  errorMessage.value = ''
  successMessage.value = ''
}

const saveCharge = async () => {
  try {
    isSavingCharge.value = true
    errorMessage.value = ''
    successMessage.value = ''

    if (!chargeForm.value.name) {
      errorMessage.value = 'Nama biaya tambahan wajib diisi'
      return
    }

    if (chargeForm.value.value < 0) {
      errorMessage.value = 'Nilai biaya tambahan tidak boleh negatif'
      return
    }

    if (chargeForm.value.charge_type === 'percentage' && chargeForm.value.value > 100) {
      errorMessage.value = 'Nilai persentase harus antara 0 dan 100'
      return
    }

    const payload = {
      name: chargeForm.value.name,
      charge_type: chargeForm.value.charge_type,
      value: chargeForm.value.value,
      is_active: chargeForm.value.is_active
    }

    let response
    if (chargeForm.value.id) {
      response = await api.put(`/config/additional-charges/${chargeForm.value.id}`, payload)
    } else {
      response = await api.post('/config/additional-charges', payload)
    }

    if (response.data.success) {
      successMessage.value = chargeForm.value.id ? 'Biaya tambahan berhasil diperbarui' : 'Biaya tambahan berhasil ditambahkan'
      resetChargeForm()
      isEditingCharge.value = false
      await fetchAdditionalCharges()
      setTimeout(() => { successMessage.value = '' }, 3000)
    }
  } catch (error) {
    errorMessage.value = 'Gagal menyimpan biaya tambahan: ' + (error.response?.data?.error || error.message)
  } finally {
    isSavingCharge.value = false
  }
}

const deleteCharge = async (charge) => {
  const confirmed = window.confirm(`Hapus biaya tambahan ${charge.name}?`)
  if (!confirmed) {
    return
  }

  try {
    errorMessage.value = ''
    successMessage.value = ''
    const response = await api.delete(`/config/additional-charges/${charge.id}`)
    if (response.data.success) {
      successMessage.value = 'Biaya tambahan berhasil dihapus'
      await fetchAdditionalCharges()
      setTimeout(() => { successMessage.value = '' }, 3000)
    }
  } catch (error) {
    errorMessage.value = 'Gagal menghapus biaya tambahan: ' + (error.response?.data?.error || error.message)
  }
}

const toggleChargeStatus = async (charge, nextValue) => {
  if (togglingCharges.value[charge.id]) {
    return
  }
  const previousValue = charge.is_active
  charge.is_active = nextValue
  togglingCharges.value = { ...togglingCharges.value, [charge.id]: true }
  try {
    errorMessage.value = ''
    successMessage.value = ''
    const payload = {
      name: charge.name,
      charge_type: charge.charge_type,
      value: charge.value,
      is_active: charge.is_active
    }
    const response = await api.put(`/config/additional-charges/${charge.id}`, payload)
    if (response.data.success) {
      successMessage.value = 'Status biaya tambahan berhasil diperbarui'
      await fetchAdditionalCharges()
      setTimeout(() => { successMessage.value = '' }, 3000)
      return
    }
    charge.is_active = previousValue
  } catch (error) {
    charge.is_active = previousValue
    errorMessage.value = 'Gagal memperbarui status biaya tambahan: ' + (error.response?.data?.error || error.message)
  } finally {
    const { [charge.id]: _, ...rest } = togglingCharges.value
    togglingCharges.value = rest
  }
}

const toggleSync = async () => {
  if (!syncStatus.value.cloud_configured) {
    errorMessage.value = 'Konfigurasi cloud belum lengkap. Isi URL API dan API Key terlebih dahulu.'
    syncStatus.value.sync_enabled = false
    return
  }

  try {
    isTogglingSync.value = true
    errorMessage.value = ''
    successMessage.value = ''

    const response = await api.post('/config/sync/toggle', {
      enabled: syncStatus.value.sync_enabled
    })

    if (response.data.success) {
      successMessage.value = syncStatus.value.sync_enabled ? '✅ Sync berhasil diaktifkan' : '⏸️ Sync berhasil dinonaktifkan'
      await fetchSyncStatus()
      await fetchConfig()
      setTimeout(() => { successMessage.value = '' }, 3000)
    }
  } catch (error) {
    errorMessage.value = 'Gagal mengubah status sync: ' + (error.response?.data?.message || error.message)
    syncStatus.value.sync_enabled = !syncStatus.value.sync_enabled
  } finally {
    isTogglingSync.value = false
  }
}

const startEditOutlet = () => {
  originalOutletConfig.value = {
    outlet_name: config.value.outlet_name,
    outlet_address: config.value.outlet_address,
    outlet_phone: config.value.outlet_phone,
    receipt_footer: config.value.receipt_footer,
    social_media: config.value.social_media,
    target_spend_per_pax: config.value.target_spend_per_pax
  }
  isEditingOutlet.value = true
  errorMessage.value = ''
  successMessage.value = ''
}

const cancelEditOutlet = () => {
  config.value.outlet_name = originalOutletConfig.value.outlet_name
  config.value.outlet_address = originalOutletConfig.value.outlet_address
  config.value.outlet_phone = originalOutletConfig.value.outlet_phone
  config.value.receipt_footer = originalOutletConfig.value.receipt_footer
  config.value.social_media = originalOutletConfig.value.social_media
  config.value.target_spend_per_pax = originalOutletConfig.value.target_spend_per_pax
  isEditingOutlet.value = false
  errorMessage.value = ''
  successMessage.value = ''
}

const startEditCloud = () => {
  originalCloudConfig.value = {
    sync_enabled: config.value.sync_enabled,
    cloud_api_url: config.value.cloud_api_url,
    cloud_api_key: config.value.cloud_api_key,
    sync_interval_minutes: config.value.sync_interval_minutes
  }
  isEditingCloud.value = true
  showApiKey.value = false
  errorMessage.value = ''
  successMessage.value = ''
}

const cancelEditCloud = () => {
  config.value.sync_enabled = originalCloudConfig.value.sync_enabled
  config.value.cloud_api_url = originalCloudConfig.value.cloud_api_url
  config.value.cloud_api_key = originalCloudConfig.value.cloud_api_key
  config.value.sync_interval_minutes = originalCloudConfig.value.sync_interval_minutes
  isEditingCloud.value = false
  showApiKey.value = false
  errorMessage.value = ''
  successMessage.value = ''
}

const saveOutletConfig = async () => {
  try {
    isSavingOutlet.value = true
    errorMessage.value = ''
    successMessage.value = ''

    if (!config.value.outlet_name) {
      errorMessage.value = 'Nama Outlet wajib diisi'
      return
    }

    const payload = {
      outlet_id: config.value.outlet_id,
      outlet_name: config.value.outlet_name,
      outlet_code: config.value.outlet_code,
      outlet_address: config.value.outlet_address,
      outlet_phone: config.value.outlet_phone,
      receipt_footer: config.value.receipt_footer,
      social_media: config.value.social_media,
      target_spend_per_pax: config.value.target_spend_per_pax,
      cloud_api_url: config.value.cloud_api_url,
      sync_enabled: config.value.sync_enabled,
      sync_interval_minutes: config.value.sync_interval_minutes
    }

    if (config.value.cloud_api_key && config.value.cloud_api_key.trim() !== '') {
      payload.cloud_api_key = config.value.cloud_api_key
    }

    let response
    if (config.value.id) {
      response = await api.put('/config/outlet', payload)
    } else {
      response = await api.post('/config/outlet', payload)
    }

    if (response.data.success) {
      successMessage.value = 'Informasi outlet berhasil disimpan'
      isEditingOutlet.value = false
      await fetchConfig()
      setTimeout(() => { successMessage.value = '' }, 3000)
    }
  } catch (error) {
    errorMessage.value = 'Gagal menyimpan informasi outlet: ' + (error.response?.data?.error || error.message)
  } finally {
    isSavingOutlet.value = false
  }
}

const saveCloudConfig = async () => {
  try {
    isSavingCloud.value = true
    errorMessage.value = ''
    successMessage.value = ''

    if (config.value.sync_enabled && !config.value.cloud_api_url) {
      errorMessage.value = 'URL API Cloud wajib diisi jika sinkronisasi diaktifkan'
      return
    }

    const payload = {
      outlet_id: config.value.outlet_id,
      outlet_name: config.value.outlet_name,
      outlet_code: config.value.outlet_code,
      outlet_address: config.value.outlet_address,
      outlet_phone: config.value.outlet_phone,
      receipt_footer: config.value.receipt_footer,
      social_media: config.value.social_media,
      cloud_api_url: config.value.cloud_api_url,
      sync_enabled: config.value.sync_enabled,
      sync_interval_minutes: config.value.sync_interval_minutes
    }

    if (config.value.cloud_api_key && config.value.cloud_api_key.trim() !== '') {
      payload.cloud_api_key = config.value.cloud_api_key
    }

    let response
    if (config.value.id) {
      response = await api.put('/config/outlet', payload)
    } else {
      response = await api.post('/config/outlet', payload)
    }

    if (response.data.success) {
      successMessage.value = 'Konfigurasi cloud berhasil disimpan'
      isEditingCloud.value = false
      await fetchConfig()
      setTimeout(() => { successMessage.value = '' }, 3000)
    }
  } catch (error) {
    errorMessage.value = 'Gagal menyimpan konfigurasi cloud: ' + (error.response?.data?.error || error.message)
  } finally {
    isSavingCloud.value = false
  }
}

const triggerManualSync = async () => {
  try {
    isSyncing.value = true
    errorMessage.value = ''
    successMessage.value = ''

    const response = await api.post('/sync/trigger')

    if (response.data.success) {
      successMessage.value = 'Sinkronisasi berhasil dimulai'
      setTimeout(() => {
        fetchConfig()
      }, 2000)
      setTimeout(() => {
        successMessage.value = ''
      }, 3000)
    }
  } catch (error) {
    errorMessage.value = 'Gagal memulai sinkronisasi: ' + (error.response?.data?.error || error.message)
  } finally {
    isSyncing.value = false
  }
}

const handlePrinterSuccess = (message) => {
  successMessage.value = message
  setTimeout(() => {
    successMessage.value = ''
  }, 3000)
}

const handlePrinterError = (message) => {
  errorMessage.value = message
  setTimeout(() => {
    errorMessage.value = ''
  }, 3000)
}

const formatDateTime = (dateString) => {
  if (!dateString) return '-'

  const date = new Date(dateString)
  return date.toLocaleDateString('id-ID', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}

const formatRupiah = (value) => {
  const amount = Number(value || 0)
  return new Intl.NumberFormat('id-ID').format(amount)
}

const formatChargeValue = (charge) => {
  if (charge.charge_type === 'percentage') {
    return `${charge.value}%`
  }
  return `Rp ${formatRupiah(charge.value)}`
}

const goBack = () => {
  router.push('/')
}

onMounted(() => {
  fetchConfig()
  fetchAdditionalCharges()
})
</script>
