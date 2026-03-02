<template>
  <div v-if="authStore.isAuthenticated && $route.path !== '/login'">
    <!-- Desktop: Top Navigation Bar -->
    <nav class="hidden lg:block bg-gradient-to-r from-emerald-600 via-emerald-500 to-teal-500 sticky top-0 z-50 shadow-lg">
      <div class="max-w-7xl mx-auto px-6 h-16">
        <div class="flex items-center justify-between h-full">
          <!-- Logo & Status -->
          <div class="flex items-center gap-3">
            <div class="flex items-center gap-2.5 px-3 py-1.5 bg-white/10 rounded-xl border border-white/20">
              <div class="w-7 h-7 bg-white/20 rounded-lg flex items-center justify-center">
                <svg class="w-4 h-4 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                  <rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8M12 17v4"/>
                </svg>
              </div>
              <span class="text-lg font-bold text-white tracking-tight">Nusantara POS</span>
              <span :class="['w-2 h-2 rounded-full', isOnline ? 'bg-green-300 animate-pulse' : 'bg-red-400']" :title="isOnline ? 'Online' : 'Offline'"></span>
            </div>
          </div>

          <!-- Nav Items -->
          <div class="flex items-center gap-1 flex-nowrap overflow-x-auto scrollbar-hide">
            <button
              v-for="item in visibleNavItems"
              :key="item.path"
              @click="navigateTo(item.path)"
              :class="['nav-link group', isActive(item.path) && 'nav-link-active']"
              :aria-label="item.label"
            >
              <component :is="item.icon" class="w-[18px] h-[18px] transition-transform group-hover:scale-110" />
              <span class="text-[13px]">{{ item.label }}</span>
            </button>

            <!-- Logout -->
            <button @click="handleLogout" class="ml-2 flex items-center gap-1.5 px-3 py-2 rounded-xl text-white/80 hover:text-white hover:bg-red-500/30 transition-all text-[13px] font-medium" aria-label="Keluar">
              <IconLogout class="w-[18px] h-[18px]" />
              <span>Keluar</span>
            </button>
          </div>
        </div>
      </div>
    </nav>

    <!-- Mobile: Bottom Navigation -->
    <nav class="lg:hidden fixed bottom-0 left-0 right-0 z-50 bg-white/95 backdrop-blur-lg border-t border-slate-200/60 shadow-[0_-4px_20px_rgba(0,0,0,0.08)]">
      <div class="flex items-center justify-around px-1 pt-2 pb-[max(0.5rem,env(safe-area-inset-bottom))]">
        <button
          v-for="item in mobileNavItems"
          :key="item.path"
          @click="navigateTo(item.path)"
          :class="['mobile-nav-item', isActive(item.path) && 'mobile-nav-active']"
          :aria-label="item.label"
        >
          <component :is="item.icon" class="w-5 h-5" />
          <span class="text-[10px] font-medium mt-0.5">{{ item.label }}</span>
        </button>

        <!-- More button (mobile) - only show when there are extra menu items or logout -->
        <button
          v-if="moreMenuItems.length > 0"
          @click="toggleMobileMenu"
          :class="['mobile-nav-item', isMobileMenuOpen && 'mobile-nav-active']"
          aria-label="Menu lainnya"
        >
          <IconMore class="w-5 h-5" />
          <span class="text-[10px] font-medium mt-0.5">Lainnya</span>
        </button>

        <!-- Logout button (mobile) - show when no extra menu items -->
        <button
          v-else
          @click="handleLogout"
          :class="['mobile-nav-item', 'text-red-500']"
          aria-label="Keluar"
        >
          <IconLogout class="w-5 h-5" />
          <span class="text-[10px] font-medium mt-0.5">Keluar</span>
        </button>
      </div>
    </nav>

    <!-- Mobile: Bottom Sheet Menu -->
    <Teleport to="body">
      <transition name="overlay">
        <div v-if="isMobileMenuOpen" class="lg:hidden fixed inset-0 z-[60] bg-black/40 backdrop-blur-sm" @click="toggleMobileMenu"></div>
      </transition>
      <transition name="sheet">
        <div v-if="isMobileMenuOpen" class="lg:hidden fixed bottom-0 left-0 right-0 z-[61] bg-white rounded-t-2xl shadow-2xl max-h-[70vh] overflow-y-auto">
          <div class="p-5 pb-[max(1.5rem,env(safe-area-inset-bottom))]">
            <!-- Handle bar -->
            <div class="w-10 h-1 bg-slate-200 rounded-full mx-auto mb-5"></div>

            <!-- User info -->
            <div class="flex items-center gap-3 mb-5 p-3 bg-slate-50 rounded-xl">
              <div class="w-10 h-10 bg-gradient-to-br from-emerald-400 to-emerald-600 rounded-xl flex items-center justify-center text-white font-bold text-sm">
                {{ userInitial }}
              </div>
              <div class="flex-1 min-w-0">
                <p class="font-semibold text-slate-800 text-sm truncate">{{ user?.full_name || user?.username }}</p>
                <p class="text-xs text-slate-500 capitalize">{{ user?.role }}</p>
              </div>
              <span :class="['px-2 py-0.5 rounded-full text-[10px] font-semibold', isOnline ? 'bg-emerald-100 text-emerald-700' : 'bg-red-100 text-red-700']">
                {{ isOnline ? 'Online' : 'Offline' }}
              </span>
            </div>

            <!-- Menu items -->
            <div class="space-y-1.5">
              <button
                v-for="item in moreMenuItems"
                :key="item.path"
                @click="navigateTo(item.path); toggleMobileMenu()"
                class="w-full flex items-center gap-3 p-3 rounded-xl hover:bg-slate-50 transition-colors text-left"
              >
                <div :class="['w-9 h-9 rounded-lg flex items-center justify-center', item.iconBg]">
                  <component :is="item.icon" class="w-5 h-5 text-white" />
                </div>
                <div class="flex-1">
                  <p class="text-sm font-semibold text-slate-800">{{ item.label }}</p>
                  <p class="text-xs text-slate-400">{{ item.desc }}</p>
                </div>
                <svg class="w-4 h-4 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>
              </button>
            </div>

            <!-- Logout -->
            <button @click="handleLogout" class="w-full flex items-center gap-3 p-3 mt-3 rounded-xl bg-red-50 hover:bg-red-100 transition-colors text-left border border-red-100">
              <div class="w-9 h-9 rounded-lg flex items-center justify-center bg-red-500">
                <IconLogout class="w-5 h-5 text-white" />
              </div>
              <div class="flex-1">
                <p class="text-sm font-semibold text-red-700">Keluar</p>
                <p class="text-xs text-red-400">Logout dari sistem</p>
              </div>
            </button>
          </div>
        </div>
      </transition>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, h } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()
const isMobileMenuOpen = ref(false)
const isOnline = ref(navigator.onLine)

const user = computed(() => authStore.user)
const userInitial = computed(() => {
  const name = user.value?.full_name || user.value?.username || '?'
  return name.charAt(0).toUpperCase()
})

// --- Icon components (eliminates SVG duplication) ---
const icon = (paths, vb = '0 0 24 24') => ({
  render: () => h('svg', { viewBox: vb, fill: 'none', stroke: 'currentColor', 'stroke-width': '2', 'stroke-linecap': 'round', 'stroke-linejoin': 'round' },
    paths.map(d => h('path', { d })))
})

const IconHome = icon(['M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2V9z', 'M9 22V12h6v10'])
const IconProduct = icon(['M21 16V8a2 2 0 00-1-1.73l-7-4a2 2 0 00-2 0l-7 4A2 2 0 003 8v8a2 2 0 001 1.73l7 4a2 2 0 002 0l7-4A2 2 0 0021 16z', 'M3.27 6.96L12 12.01l8.73-5.05', 'M12 22.08V12'])
const IconTable = icon(['M12 2a10 10 0 100 20 10 10 0 000-20z', 'M12 6v6l4 2'])
const IconWaiter = icon(['M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2', 'M12 3a4 4 0 100 8 4 4 0 000-8z'])
const IconKitchen = icon(['M4 3h16v4a6 6 0 01-6 6H10a6 6 0 01-6-6V3z', 'M6 11v10h12V11', 'M9 15h6'])
const IconCashier = icon(['M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2', 'M9 11h12a2 2 0 012 2v4a2 2 0 01-2 2H9a2 2 0 01-2-2v-4a2 2 0 012-2z'])
const IconSettings = icon(['M12 15a3 3 0 100-6 3 3 0 000 6z', 'M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 010 2.83 2 2 0 01-2.83 0l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-4 0v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83 0 2 2 0 010-2.83l.06-.06A1.65 1.65 0 004.68 15a1.65 1.65 0 00-1.51-1H3a2 2 0 010-4h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 112.83-2.83l.06.06A1.65 1.65 0 009 4.6a1.65 1.65 0 001-1.51V3a2 2 0 014 0v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 2.83l-.06.06a1.65 1.65 0 00-.33 1.82V9a1.65 1.65 0 001.51 1H21a2 2 0 010 4h-.09a1.65 1.65 0 00-1.51 1z'])
const IconUsers = icon(['M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2', 'M9 3a4 4 0 100 8 4 4 0 000-8z', 'M23 21v-2a4 4 0 00-3-3.87', 'M16 3.13a4 4 0 010 7.75'])
const IconLogout = icon(['M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4', 'M16 17l5-5-5-5', 'M21 12H9'])
const IconMore = icon(['M12 13a1 1 0 100-2 1 1 0 000 2z', 'M12 6a1 1 0 100-2 1 1 0 000 2z', 'M12 20a1 1 0 100-2 1 1 0 000 2z'])

// --- Navigation items based on role ---
const allNavItems = [
  { path: '/', label: 'Dashboard', icon: IconHome, roles: ['admin', 'manager'], desc: 'Ringkasan bisnis', iconBg: 'bg-emerald-500' },
  { path: '/products', label: 'Produk', icon: IconProduct, roles: ['admin', 'manager'], desc: 'Kelola menu', iconBg: 'bg-blue-500' },
  { path: '/tables', label: 'Meja', icon: IconTable, roles: ['admin', 'manager'], desc: 'Manajemen meja', iconBg: 'bg-violet-500' },
  { path: '/waiter', label: 'Waiter', icon: IconWaiter, roles: ['admin', 'waiter'], desc: 'Layanan pesanan', iconBg: 'bg-amber-500' },
  { path: '/kitchen', label: 'Kitchen', icon: IconKitchen, roles: ['admin', 'kitchen', 'bar'], desc: 'Display dapur', iconBg: 'bg-orange-500' },
  { path: '/cashier', label: 'Kasir', icon: IconCashier, roles: ['admin', 'cashier'], desc: 'Pembayaran', iconBg: 'bg-teal-500' },
  { path: '/settings', label: 'Pengaturan', icon: IconSettings, roles: ['admin', 'manager'], desc: 'Konfigurasi', iconBg: 'bg-slate-500' },
  { path: '/users', label: 'User', icon: IconUsers, roles: ['admin', 'manager'], desc: 'Kelola akun', iconBg: 'bg-indigo-500' },
]

const userRole = computed(() => user.value?.role)
const visibleNavItems = computed(() => allNavItems.filter(i => i.roles.includes(userRole.value)))
const mobileNavItems = computed(() => visibleNavItems.value.slice(0, 4))
const moreMenuItems = computed(() => visibleNavItems.value.slice(4))

const isActive = (path) => route.path === path
const navigateTo = (path) => router.push(path)
const toggleMobileMenu = () => { isMobileMenuOpen.value = !isMobileMenuOpen.value }

const handleLogout = async () => {
  isMobileMenuOpen.value = false
  await authStore.logout()
  router.push('/login')
}

const updateOnlineStatus = () => { isOnline.value = navigator.onLine }

onMounted(() => {
  window.addEventListener('online', updateOnlineStatus)
  window.addEventListener('offline', updateOnlineStatus)
})
onUnmounted(() => {
  window.removeEventListener('online', updateOnlineStatus)
  window.removeEventListener('offline', updateOnlineStatus)
})
</script>

<style scoped>
/* Desktop nav link */
.nav-link {
  @apply flex items-center gap-1.5 px-3 py-2 rounded-xl text-white/80 font-medium transition-all duration-200 whitespace-nowrap;
}
.nav-link:hover {
  @apply text-white bg-white/15;
}
.nav-link-active {
  @apply text-white bg-white/20 shadow-sm;
  box-shadow: inset 0 -2px 0 #fbbf24;
}

/* Hide scrollbar for nav overflow */
.scrollbar-hide {
  -ms-overflow-style: none;
  scrollbar-width: none;
}
.scrollbar-hide::-webkit-scrollbar {
  display: none;
}

/* Mobile bottom nav */
.mobile-nav-item {
  @apply flex flex-col items-center justify-center py-1 px-2 rounded-lg text-slate-500 transition-colors min-w-[3rem];
}
.mobile-nav-item:active {
  @apply scale-95;
}
.mobile-nav-active {
  @apply text-emerald-600;
}

/* Sheet transitions */
.overlay-enter-active, .overlay-leave-active { transition: opacity 0.25s ease; }
.overlay-enter-from, .overlay-leave-to { opacity: 0; }

.sheet-enter-active { transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1); }
.sheet-leave-active { transition: transform 0.2s ease-in; }
.sheet-enter-from, .sheet-leave-to { transform: translateY(100%); }
</style>
