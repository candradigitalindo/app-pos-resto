<template>
  <div class="login-page min-h-screen flex items-center justify-center relative overflow-hidden">
    <!-- Animated background -->
    <div class="absolute inset-0 bg-gradient-to-br from-slate-950 via-emerald-950 to-slate-900"></div>
    <div class="absolute inset-0 overflow-hidden pointer-events-none">
      <!-- Floating orbs -->
      <div class="orb orb-1"></div>
      <div class="orb orb-2"></div>
      <div class="orb orb-3"></div>
      <!-- Grid pattern overlay -->
      <div class="absolute inset-0 opacity-[0.03]" style="background-image: url('data:image/svg+xml,%3Csvg width=&quot;60&quot; height=&quot;60&quot; viewBox=&quot;0 0 60 60&quot; xmlns=&quot;http://www.w3.org/2000/svg&quot;%3E%3Cg fill=&quot;none&quot; fill-rule=&quot;evenodd&quot;%3E%3Cg fill=&quot;%23ffffff&quot; fill-opacity=&quot;1&quot;%3E%3Cpath d=&quot;M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z&quot;/%3E%3C/g%3E%3C/g%3E%3C/svg%3E');"></div>
    </div>

    <div class="relative z-10 w-full max-w-5xl mx-auto px-4 sm:px-6 py-8 grid lg:grid-cols-2 gap-8 lg:gap-16 items-center">
      <!-- Left: Branding -->
      <div class="hidden lg:flex flex-col gap-8">
        <!-- Logo -->
        <div class="flex items-center gap-4">
          <div class="w-14 h-14 bg-gradient-to-br from-emerald-400 to-emerald-600 rounded-2xl flex items-center justify-center shadow-lg shadow-emerald-500/25 ring-1 ring-white/10">
            <svg class="w-7 h-7 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <rect x="2" y="3" width="20" height="14" rx="3"/><path d="M2 10H22"/><circle cx="7" cy="14" r="1.5" fill="currentColor"/>
              <path d="M8 21H16"/><path d="M12 17V21"/>
            </svg>
          </div>
          <div>
            <h1 class="text-2xl font-bold text-white tracking-tight">Nusantara POS</h1>
            <p class="text-sm text-emerald-400/70">Point of Sale System</p>
          </div>
        </div>

        <!-- Tagline -->
        <div>
          <h2 class="text-4xl lg:text-5xl font-extrabold text-white leading-tight">
            Kelola bisnis
            <span class="text-transparent bg-clip-text bg-gradient-to-r from-emerald-400 to-teal-300">lebih cerdas.</span>
          </h2>
          <p class="mt-4 text-base text-slate-400 leading-relaxed max-w-md">
            Sistem point of sale modern yang membantu Anda mengelola restoran dengan efisien, dari meja hingga dapur.
          </p>
        </div>

        <!-- Features -->
        <div class="space-y-3">
          <div class="flex items-center gap-3 text-sm text-slate-300">
            <div class="w-8 h-8 rounded-lg bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center flex-shrink-0">
              <svg class="w-4 h-4 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/></svg>
            </div>
            <span>Real-time sync antar perangkat</span>
          </div>
          <div class="flex items-center gap-3 text-sm text-slate-300">
            <div class="w-8 h-8 rounded-lg bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center flex-shrink-0">
              <svg class="w-4 h-4 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"/></svg>
            </div>
            <span>Bisa dipakai offline tanpa internet</span>
          </div>
          <div class="flex items-center gap-3 text-sm text-slate-300">
            <div class="w-8 h-8 rounded-lg bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center flex-shrink-0">
              <svg class="w-4 h-4 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2z"/></svg>
            </div>
            <span>Cetak struk langsung ke printer</span>
          </div>
        </div>

        <!-- QR & Order Buttons -->
        <div class="flex items-center gap-3">
          <button
            type="button"
            @click="openQrModal"
            class="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-white/5 border border-white/10 text-slate-300 font-medium text-sm hover:bg-white/10 hover:border-white/20 hover:text-white transition-all duration-300"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v1m6 11h2m-6 0h-2v4m0-11v3m0 0h.01M12 12h4.01M16 20h4M4 12h4m12 0h.01M5 8h2a1 1 0 001-1V5a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1zm12 0h2a1 1 0 001-1V5a1 1 0 00-1-1h-2a1 1 0 00-1 1v2a1 1 0 001 1zM5 20h2a1 1 0 001-1v-2a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1z"/></svg>
            QR Code Server
          </button>
          <button
            type="button"
            @click="showPinPad = true"
            class="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-gradient-to-r from-emerald-500 to-emerald-600 text-white font-semibold text-sm shadow-lg shadow-emerald-500/25 hover:shadow-xl hover:from-emerald-400 hover:to-emerald-500 active:scale-[0.98] transition-all duration-300"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"/></svg>
            Order
          </button>
        </div>
      </div>

      <!-- Right: Login Card -->
      <div class="w-full max-w-[420px] mx-auto lg:mx-0">
        <div class="login-card relative bg-white/[0.07] backdrop-blur-2xl rounded-3xl border border-white/[0.08] shadow-2xl shadow-black/20 p-7 sm:p-9">
          <!-- Subtle glow effect -->
          <div class="absolute -top-px left-1/2 -translate-x-1/2 w-1/2 h-px bg-gradient-to-r from-transparent via-emerald-400/50 to-transparent"></div>

          <!-- Mobile branding -->
          <div class="flex items-center justify-center gap-3 mb-7 lg:hidden">
            <div class="w-11 h-11 bg-gradient-to-br from-emerald-400 to-emerald-600 rounded-xl flex items-center justify-center shadow-lg shadow-emerald-500/25">
              <svg class="w-5.5 h-5.5 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <rect x="2" y="3" width="20" height="14" rx="3"/><path d="M2 10H22"/><circle cx="7" cy="14" r="1.5" fill="currentColor"/>
                <path d="M8 21H16"/><path d="M12 17V21"/>
              </svg>
            </div>
            <div>
              <h1 class="text-xl font-bold text-white">Nusantara POS</h1>
              <p class="text-xs text-emerald-400/60">Point of Sale</p>
            </div>
          </div>

          <!-- Header -->
          <div class="mb-7">
            <h2 class="text-xl sm:text-2xl font-bold text-white">Selamat datang</h2>
            <p class="text-sm text-slate-400 mt-1">Masuk untuk mulai mengelola bisnis Anda</p>
          </div>

          <!-- Form -->
          <form @submit.prevent="handleLogin" class="space-y-5">
            <!-- Username -->
            <div class="space-y-2">
              <label class="text-sm font-medium text-slate-300">Username</label>
              <div class="relative group">
                <div class="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-500 group-focus-within:text-emerald-400 transition-colors">
                  <svg class="w-[18px] h-[18px]" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/></svg>
                </div>
                <input
                  v-model="username"
                  type="text"
                  class="w-full pl-11 pr-4 py-3 rounded-xl bg-white/[0.06] border border-white/[0.08] text-white placeholder-slate-500 focus:bg-white/[0.1] focus:border-emerald-500/50 focus:ring-2 focus:ring-emerald-500/20 transition-all duration-300 outline-none text-sm"
                  placeholder="Masukkan username"
                  autocomplete="username"
                  required
                />
              </div>
            </div>

            <!-- PIN -->
            <div class="space-y-2">
              <label class="text-sm font-medium text-slate-300">PIN</label>
              <div class="relative group">
                <div class="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-500 group-focus-within:text-emerald-400 transition-colors">
                  <svg class="w-[18px] h-[18px]" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/></svg>
                </div>
                <input
                  v-model="password"
                  :type="showPin ? 'text' : 'password'"
                  inputmode="numeric"
                  pattern="[0-9]{4}"
                  maxlength="4"
                  minlength="4"
                  class="w-full pl-11 pr-11 py-3 rounded-xl bg-white/[0.06] border border-white/[0.08] text-white text-center text-sm font-semibold tracking-[0.5em] font-mono placeholder-slate-500 focus:bg-white/[0.1] focus:border-emerald-500/50 focus:ring-2 focus:ring-emerald-500/20 transition-all duration-300 outline-none"
                  placeholder="• • • •"
                  autocomplete="off"
                  required
                  @input="validatePin"
                />
                <button
                  type="button"
                  @click="showPin = !showPin"
                  class="absolute right-3.5 top-1/2 -translate-y-1/2 text-slate-500 hover:text-slate-300 transition-colors"
                  tabindex="-1"
                >
                  <!-- Eye open -->
                  <svg v-if="!showPin" class="w-[18px] h-[18px]" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/></svg>
                  <!-- Eye closed -->
                  <svg v-else class="w-[18px] h-[18px]" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"/></svg>
                </button>
              </div>
              <p class="text-xs text-slate-500">Masukkan 4 digit PIN Anda</p>
            </div>

            <!-- Submit -->
            <button
              type="submit"
              class="w-full py-3.5 rounded-xl bg-gradient-to-r from-emerald-500 to-emerald-600 text-white font-semibold text-sm shadow-lg shadow-emerald-500/25 hover:shadow-xl hover:shadow-emerald-500/30 hover:from-emerald-400 hover:to-emerald-500 active:scale-[0.98] transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:shadow-lg flex items-center justify-center gap-2"
              :disabled="loading"
            >
              <template v-if="!loading">
                Masuk
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M13 7l5 5m0 0l-5 5m5-5H6"/></svg>
              </template>
              <template v-else>
                <svg class="w-5 h-5 animate-spin" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" opacity="0.25"/><path fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" opacity="0.75"/></svg>
                Memproses...
              </template>
            </button>
          </form>

          <!-- Mobile buttons -->
          <div class="lg:hidden flex gap-2 mt-4">
            <button
              type="button"
              @click="openQrModal"
              class="flex-1 py-2.5 rounded-xl bg-white/[0.04] border border-white/[0.08] text-slate-400 font-medium text-sm hover:bg-white/[0.08] hover:text-slate-300 transition-all duration-300 flex items-center justify-center gap-2"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v1m6 11h2m-6 0h-2v4m0-11v3m0 0h.01M12 12h4.01M16 20h4M4 12h4m12 0h.01M5 8h2a1 1 0 001-1V5a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1zm12 0h2a1 1 0 001-1V5a1 1 0 00-1-1h-2a1 1 0 00-1 1v2a1 1 0 001 1zM5 20h2a1 1 0 001-1v-2a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1z"/></svg>
              QR Server
            </button>
            <button
              type="button"
              @click="showPinPad = true"
              class="flex-1 py-2.5 rounded-xl bg-gradient-to-r from-emerald-500 to-emerald-600 text-white font-semibold text-sm shadow-lg shadow-emerald-500/25 active:scale-[0.98] transition-all duration-300 flex items-center justify-center gap-2"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"/></svg>
              Order
            </button>
          </div>

          <!-- Footer -->
          <div class="flex items-center justify-between mt-6 pt-5 border-t border-white/[0.06] text-xs text-slate-500">
            <div class="flex items-center gap-1.5">
              <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span>
              Koneksi aman
            </div>
            <span>v1.0.0</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Error Modal -->
    <transition name="modal">
      <div v-if="error" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm" @click="error = ''">
        <div class="bg-slate-900 border border-white/10 rounded-2xl p-8 max-w-sm w-full text-center shadow-2xl" @click.stop>
          <div class="w-16 h-16 mx-auto mb-4 rounded-2xl bg-red-500/10 border border-red-500/20 flex items-center justify-center">
            <svg class="w-8 h-8 text-red-400" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/></svg>
          </div>
          <h3 class="text-xl font-bold text-white mb-2">Login Gagal</h3>
          <p class="text-slate-400 mb-6 text-sm">{{ error }}</p>
          <button @click="error = ''" class="px-6 py-2.5 bg-white/10 border border-white/10 text-white rounded-xl font-semibold text-sm hover:bg-white/15 transition-all">Tutup</button>
        </div>
      </div>
    </transition>

    <!-- QR Modal -->
    <transition name="modal">
      <div v-if="showQrModal" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm" @click="showQrModal = false">
        <div class="bg-slate-900 border border-white/10 rounded-2xl p-8 max-w-sm w-full text-center shadow-2xl" @click.stop>
          <h3 class="text-xl font-bold text-white mb-1">QR Code Server</h3>
          <p class="text-slate-400 text-sm mb-5">Scan untuk koneksi perangkat lain</p>
          <div class="flex items-center justify-center p-5 bg-white rounded-2xl mx-auto w-fit">
            <div v-if="qrLoading" class="text-sm text-slate-400 py-10 px-6">Memuat QR...</div>
            <img v-else-if="serverQr" class="w-44 h-44" :src="`data:image/png;base64,${serverQr}`" alt="QR Server" />
            <div v-else class="text-sm text-slate-400 py-10 px-6">{{ qrError || 'QR tidak tersedia' }}</div>
          </div>
          <div v-if="serverUrl" class="text-xs text-slate-500 mt-3 break-all font-mono bg-white/5 rounded-lg px-3 py-2">{{ serverUrl }}</div>
          <button @click="showQrModal = false" class="mt-5 px-6 py-2.5 bg-white/10 border border-white/10 text-white rounded-xl font-semibold text-sm hover:bg-white/15 transition-all">Tutup</button>
        </div>
      </div>
    </transition>

    <!-- PIN Pad Modal (Quick Waiter Login) -->
    <transition name="modal">
      <div v-if="showPinPad" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm" @click="closePinPad">
        <div class="bg-slate-900 border border-white/10 rounded-3xl p-6 sm:p-8 max-w-[340px] w-full shadow-2xl" @click.stop>
          <!-- Header -->
          <div class="text-center mb-6">
            <div class="w-14 h-14 mx-auto mb-3 rounded-2xl bg-gradient-to-br from-emerald-400 to-emerald-600 flex items-center justify-center shadow-lg shadow-emerald-500/25">
              <svg class="w-7 h-7 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/></svg>
            </div>
            <h3 class="text-xl font-bold text-white">Masuk Waiter</h3>
            <p class="text-sm text-slate-400 mt-1">Masukkan PIN 4 digit Anda</p>
          </div>

          <!-- PIN Dots -->
          <div class="flex justify-center gap-4 mb-6">
            <div v-for="i in 4" :key="i" :class="['w-4 h-4 rounded-full transition-all duration-200', pinCode.length >= i ? 'bg-emerald-400 scale-110 shadow-lg shadow-emerald-400/50' : 'bg-white/10 border border-white/20']"></div>
          </div>

          <!-- Error -->
          <div v-if="pinError" class="text-center mb-4 text-sm text-red-400 font-semibold animate-shake">{{ pinError }}</div>

          <!-- Loading -->
          <div v-if="pinLoading" class="flex justify-center mb-4">
            <svg class="w-8 h-8 animate-spin text-emerald-400" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" opacity="0.25"/><path fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" opacity="0.75"/></svg>
          </div>

          <!-- Number Pad -->
          <div v-if="!pinLoading" class="grid grid-cols-3 gap-2.5">
            <button v-for="n in [1,2,3,4,5,6,7,8,9]" :key="n" type="button" @click="tapPin(n)" class="h-14 rounded-xl bg-white/[0.06] border border-white/[0.08] text-white text-xl font-bold hover:bg-white/[0.12] active:scale-90 transition-all duration-150">
              {{ n }}
            </button>
            <button type="button" @click="closePinPad" class="h-14 rounded-xl bg-white/[0.04] border border-white/[0.06] text-slate-400 text-sm font-semibold hover:bg-white/[0.08] active:scale-90 transition-all duration-150">
              Batal
            </button>
            <button type="button" @click="tapPin(0)" class="h-14 rounded-xl bg-white/[0.06] border border-white/[0.08] text-white text-xl font-bold hover:bg-white/[0.12] active:scale-90 transition-all duration-150">
              0
            </button>
            <button type="button" @click="pinCode = pinCode.slice(0, -1); pinError = ''" class="h-14 rounded-xl bg-white/[0.04] border border-white/[0.06] text-slate-400 hover:bg-white/[0.08] active:scale-90 transition-all duration-150 flex items-center justify-center">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2M3 12l6.414-6.414A2 2 0 0110.828 5H19a2 2 0 012 2v10a2 2 0 01-2 2h-8.172a2 2 0 01-1.414-.586L3 12z"/></svg>
            </button>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import api from '../services/api'

const router = useRouter()
const authStore = useAuthStore()

const username = ref('')
const password = ref('')
const showPin = ref(false)
const error = ref('')
const loading = ref(false)
const serverQr = ref('')
const serverUrl = ref('')
const qrLoading = ref(false)
const qrError = ref('')
const showQrModal = ref(false)

// PIN Pad state
const showPinPad = ref(false)
const pinCode = ref('')
const pinError = ref('')
const pinLoading = ref(false)

const validatePin = () => {
  password.value = password.value.replace(/[^0-9]/g, '').slice(0, 4)
}

const handleEscape = (e) => {
  if (e.key === 'Escape') {
    showQrModal.value = false
    error.value = ''
  }
}

const fetchServerQRCode = async () => {
  qrLoading.value = true
  qrError.value = ''
  try {
    const response = await api.get('/server/qr')
    if (response.data?.success) {
      serverQr.value = response.data.data?.qr_code || ''
      serverUrl.value = response.data.data?.server_url || ''
      return
    }
    qrError.value = response.data?.message || 'QR tidak tersedia'
  } catch (err) {
    qrError.value = err.message || 'QR tidak tersedia'
  } finally {
    qrLoading.value = false
  }
}

const openQrModal = async () => {
  showQrModal.value = true
  if (!serverQr.value && !qrLoading.value) {
    await fetchServerQRCode()
  }
}

const closePinPad = () => {
  showPinPad.value = false
  pinCode.value = ''
  pinError.value = ''
  pinLoading.value = false
}

const tapPin = async (digit) => {
  if (pinCode.value.length >= 4 || pinLoading.value) return
  pinError.value = ''
  pinCode.value += String(digit)

  if (pinCode.value.length === 4) {
    pinLoading.value = true
    try {
      const response = await api.post('/auth/passcode', { pin: pinCode.value })
      if (response.data.success) {
        authStore.setSession(response.data.data.token, response.data.data.user)
        closePinPad()
        await router.push('/waiter')
      } else {
        pinError.value = response.data.message || 'PIN salah'
        pinCode.value = ''
      }
    } catch (err) {
      pinError.value = err.response?.data?.message || 'PIN tidak ditemukan'
      pinCode.value = ''
    } finally {
      pinLoading.value = false
    }
  }
}

const handleLogin = async () => {
  error.value = ''
  loading.value = true
  try {
    const result = await authStore.login(username.value, password.value)
    if (!result.success) {
      error.value = result.message || 'Login gagal'
      return
    }
    await router.push('/')
  } catch (err) {
    error.value = err.message || 'Login gagal'
  } finally {
    loading.value = false
  }
}

onMounted(() => document.addEventListener('keydown', handleEscape))
onUnmounted(() => document.removeEventListener('keydown', handleEscape))
</script>

<style scoped>
.modal-enter-active, .modal-leave-active { transition: opacity 0.25s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }

/* Shake animation for error */
.animate-shake {
  animation: shake 0.4s ease-in-out;
}
@keyframes shake {
  0%, 100% { transform: translateX(0); }
  20%, 60% { transform: translateX(-6px); }
  40%, 80% { transform: translateX(6px); }
}

/* Floating orbs */
.orb {
  position: absolute;
  border-radius: 50%;
  filter: blur(80px);
  animation: float 20s ease-in-out infinite;
}
.orb-1 {
  width: 500px;
  height: 500px;
  background: radial-gradient(circle, rgba(16, 185, 129, 0.15), transparent 70%);
  top: -10%;
  right: -5%;
  animation-delay: 0s;
}
.orb-2 {
  width: 400px;
  height: 400px;
  background: radial-gradient(circle, rgba(20, 184, 166, 0.12), transparent 70%);
  bottom: -10%;
  left: -5%;
  animation-delay: -7s;
}
.orb-3 {
  width: 300px;
  height: 300px;
  background: radial-gradient(circle, rgba(52, 211, 153, 0.08), transparent 70%);
  top: 40%;
  left: 30%;
  animation-delay: -14s;
}

@keyframes float {
  0%, 100% { transform: translate(0, 0) scale(1); }
  25% { transform: translate(30px, -30px) scale(1.05); }
  50% { transform: translate(-20px, 20px) scale(0.95); }
  75% { transform: translate(15px, 10px) scale(1.02); }
}

/* Glassmorphism card shine */
.login-card::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: 1.5rem;
  padding: 1px;
  background: linear-gradient(135deg, rgba(255,255,255,0.1), transparent 40%, transparent 60%, rgba(255,255,255,0.05));
  mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
  mask-composite: exclude;
  -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
  -webkit-mask-composite: xor;
  pointer-events: none;
}
</style>
