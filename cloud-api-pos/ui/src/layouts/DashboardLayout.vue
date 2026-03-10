<!--
  DashboardLayout.vue — Modern Glassmorphism App Shell 2026
  Sidebar: deep emerald liquid glass + specular edges + accent-bar nav
  Topbar:  frosted white glass with backdrop-filter
-->
<template>
  <div class="app-shell">

    <!-- ── Mobile overlay ── -->
    <Transition name="fade-overlay">
      <div
        v-if="sidebarOpen"
        class="fixed inset-0 z-20 lg:hidden bg-overlay"
        @click="sidebarOpen = false"
      />
    </Transition>

    <!-- ── Sidebar ── -->
    <aside :class="['sidebar', sidebarOpen ? 'translate-x-0' : '-translate-x-full', 'lg:static lg:translate-x-0']">

      <!-- Specular edges -->
      <div class="sb-edge-right" aria-hidden="true" />
      <div class="sb-edge-top"   aria-hidden="true" />

      <!-- Brand -->
      <div class="sb-brand">
        <div class="brand-mark">
          <svg viewBox="0 0 32 32" fill="none">
            <rect x="3"  y="3"  width="12" height="12" rx="3.5" fill="white" fill-opacity=".9"/>
            <rect x="17" y="3"  width="12" height="12" rx="3.5" fill="white" fill-opacity=".4"/>
            <rect x="3"  y="17" width="12" height="12" rx="3.5" fill="white" fill-opacity=".55"/>
            <rect x="17" y="17" width="12" height="12" rx="3.5" fill="white" fill-opacity=".75"/>
          </svg>
        </div>
        <div class="brand-text">
          <span class="brand-name">Cloud POS</span>
          <span class="brand-sub">Nusantara</span>
        </div>
        <span class="version-badge">v2</span>
      </div>

      <!-- Nav -->
      <div class="sb-nav-wrap">
        <p class="sb-section-lbl">Navigation</p>
        <nav class="sb-nav">
          <RouterLink
            v-for="item in NAV_ITEMS"
            :key="item.to"
            :to="item.to"
            :class="['nav-item', isActive(item.to) ? 'nav-item--active' : '']"
            @click="sidebarOpen = false"
          >
            <span class="nav-accent" />
            <span class="nav-icon-wrap" v-html="item.icon" />
            <span class="nav-label">{{ item.label }}</span>
            <span v-if="isActive(item.to)" class="nav-active-dot" />
          </RouterLink>
        </nav>
      </div>

      <div class="sb-spacer" />
      <div class="sb-separator" />

      <!-- User block -->
      <div class="sb-user">
        <div class="user-avatar-lg">{{ adminInitial }}</div>
        <div class="user-meta">
          <span class="user-name">{{ authStore.admin?.username }}</span>
          <span class="user-role capitalize">{{ authStore.admin?.role }}</span>
        </div>
        <button class="logout-icon-btn" @click="logout" title="Logout">
          <svg fill="none" viewBox="0 0 20 20" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8"
              d="M13 4.5l3.5 3.5L13 11.5M16.5 8H7M10 3H5a1 1 0 00-1 1v12a1 1 0 001 1h5"/>
          </svg>
        </button>
      </div>
    </aside>

    <!-- ── Main column ── -->
    <div class="main-col">

      <!-- Topbar -->
      <header class="topbar">
        <div class="tb-shimmer" aria-hidden="true" />

        <!-- Hamburger (mobile) -->
        <button class="hamburger lg:hidden" @click="sidebarOpen = true" aria-label="Open menu">
          <svg fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h7"/>
          </svg>
        </button>

        <!-- Breadcrumb -->
        <div class="tb-crumb">
          <svg class="crumb-home" fill="none" viewBox="0 0 20 20" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8"
              d="M3 9.5L10 3l7 6.5V17a1 1 0 01-1 1H6a1 1 0 01-1-1v-4.5"/>
          </svg>
          <svg class="crumb-sep" fill="none" viewBox="0 0 12 20" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8" d="M4 4l6 6-6 6"/>
          </svg>
          <span class="crumb-active">{{ currentPageTitle }}</span>
        </div>

        <div class="flex-1" />

        <!-- Right actions -->
        <div class="tb-actions">
          <button class="tb-action-btn" title="Notifikasi">
            <svg fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8"
                d="M15 17H9m3-14a7 7 0 017 7c0 3.87-.5 5.5-1 6H6c-.5-.5-1-2.13-1-6a7 7 0 017-7z"/>
            </svg>
          </button>
          <span class="tb-vdivider" />
          <span class="role-chip capitalize">{{ authStore.admin?.role }}</span>
          <div class="tb-avatar">{{ adminInitial }}</div>
        </div>
      </header>

      <!-- Content -->
      <main class="content-area">
        <RouterView />
      </main>
    </div>

    <ToastContainer />
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth.js'
import ToastContainer from '@/components/ToastContainer.vue'

const route       = useRoute()
const router      = useRouter()
const authStore   = useAuthStore()
const sidebarOpen = ref(false)

const adminInitial     = computed(() => (authStore.admin?.username ?? 'A').charAt(0).toUpperCase())
const currentPageTitle = computed(() => route.meta?.title?.replace(' — Cloud POS', '') ?? 'Dashboard')

function isActive(to) {
  if (to === '/') return route.path === '/'
  return route.path.startsWith(to)
}

async function logout() {
  await authStore.logout()
  router.push('/login')
}

const NAV_ITEMS = [
  {
    to: '/',
    label: 'Dashboard',
    icon: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.6"
        d="M4 5a1 1 0 011-1h4a1 1 0 011 1v5a1 1 0 01-1 1H5a1 1 0 01-1-1V5z"/>
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.6"
        d="M14 5a1 1 0 011-1h4a1 1 0 011 1v2a1 1 0 01-1 1h-4a1 1 0 01-1-1V5z"/>
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.6"
        d="M4 15a1 1 0 011-1h4a1 1 0 011 1v4a1 1 0 01-1 1H5a1 1 0 01-1-1v-4z"/>
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.6"
        d="M14 13a1 1 0 011-1h4a1 1 0 011 1v6a1 1 0 01-1 1h-4a1 1 0 01-1-1v-6z"/>
    </svg>`,
  },
  {
    to: '/outlets',
    label: 'Outlet',
    icon: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.6"
        d="M3 9.5l9-7 9 7V20a1 1 0 01-1 1H4a1 1 0 01-1-1V9.5z"/>
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.6"
        d="M9 21V12h6v9"/>
    </svg>`,
  },
  {
    to: '/products',
    label: 'Produk',
    icon: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.6"
        d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10"/>
    </svg>`,
  },
  {
    to: '/admins',
    label: 'Admin',
    icon: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.6"
        d="M16 7a4 4 0 11-8 0 4 4 0 018 0z"/>
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.6"
        d="M12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
    </svg>`,
  },
]
</script>

<style scoped>
/* ══════════════════════════════ SHELL ══════════════════════════════ */
.app-shell {
  display: flex; height: 100svh; overflow: hidden; background: #eef2ee;
}
.bg-overlay { background: rgba(0,0,0,.4); backdrop-filter: blur(8px); -webkit-backdrop-filter: blur(8px); }
.fade-overlay-enter-active, .fade-overlay-leave-active { transition: opacity .25s; }
.fade-overlay-enter-from,   .fade-overlay-leave-to     { opacity: 0; }

/* ══════════════════════════════ SIDEBAR ═══════════════════════════ */
.sidebar {
  position: fixed; top: 0; bottom: 0; left: 0;
  z-index: 30; width: 230px;
  display: flex; flex-direction: column;
  background:
    linear-gradient(135deg, rgba(255,255,255,.10) 0%, rgba(255,255,255,.03) 40%, rgba(0,0,0,.06) 100%),
    linear-gradient(175deg, #0d3520 0%, #0f4226 55%, #0b2e1c 100%);
  backdrop-filter: blur(40px) saturate(180%) brightness(1.05);
  -webkit-backdrop-filter: blur(40px) saturate(180%) brightness(1.05);
  border-right: 1px solid rgba(255,255,255,.07);
  box-shadow: 6px 0 40px rgba(0,0,0,.35), 1px 0 0 rgba(255,255,255,.04) inset;
  transition: transform .22s cubic-bezier(.22,.68,0,1.15);
  overflow: hidden;
}
@media (min-width: 1024px) { .sidebar { position: static; flex-shrink: 0; } }

/* Specular edges */
.sb-edge-right {
  position: absolute; top: 10%; right: 0; bottom: 10%; width: 1px;
  background: linear-gradient(180deg, transparent, rgba(255,255,255,.2) 30%, rgba(255,255,255,.28) 55%, rgba(255,255,255,.2) 75%, transparent);
  pointer-events: none; z-index: 2;
}
.sb-edge-top {
  position: absolute; top: 0; left: 0; right: 0; height: 1px;
  background: linear-gradient(90deg, rgba(255,255,255,0), rgba(255,255,255,.27) 35%, rgba(255,255,255,.34) 55%, rgba(255,255,255,.27) 75%, rgba(255,255,255,0));
  pointer-events: none; z-index: 2;
}

/* Brand */
.sb-brand {
  position: relative; z-index: 1;
  display: flex; align-items: center; gap: .7rem;
  padding: 1.4rem 1.1rem 1.1rem;
}
.brand-mark {
  width: 38px; height: 38px; border-radius: 11px; flex-shrink: 0;
  background: linear-gradient(135deg, rgba(255,255,255,.2), rgba(255,255,255,.06));
  border: 1px solid rgba(255,255,255,.18);
  display: flex; align-items: center; justify-content: center;
  box-shadow: inset 0 1px 0 rgba(255,255,255,.28), 0 4px 16px rgba(0,0,0,.3);
}
.brand-mark svg { width: 22px; height: 22px; }
.brand-text { display: flex; flex-direction: column; flex: 1; min-width: 0; }
.brand-name { font-size: .875rem; font-weight: 700; color: #fff; letter-spacing: -.015em; line-height: 1.2; }
.brand-sub  { font-size: .6rem; color: rgba(255,255,255,.35); text-transform: uppercase; letter-spacing: .1em; margin-top: .12rem; }
.version-badge {
  font-size: .58rem; font-weight: 700; color: rgba(255,255,255,.5);
  background: rgba(255,255,255,.08); border: 1px solid rgba(255,255,255,.12);
  border-radius: 4px; padding: .1rem .32rem; align-self: flex-start; letter-spacing: .04em;
}

/* Nav */
.sb-nav-wrap { position: relative; z-index: 1; padding: 0 .65rem; }
.sb-section-lbl {
  font-size: .575rem; font-weight: 700; text-transform: uppercase;
  letter-spacing: .12em; color: rgba(255,255,255,.22);
  padding: .75rem .5rem .4rem; margin: 0;
}
.sb-nav { display: flex; flex-direction: column; gap: .18rem; }

.nav-item {
  position: relative;
  display: flex; align-items: center; gap: .65rem;
  padding: .625rem .75rem .625rem .9rem;
  border-radius: 10px; font-size: .82rem; font-weight: 500;
  color: rgba(255,255,255,.45); text-decoration: none;
  border: 1px solid transparent; overflow: hidden;
  transition: color .18s, background .18s, border-color .18s;
}
.nav-item:hover:not(.nav-item--active) {
  color: rgba(255,255,255,.78); background: rgba(255,255,255,.07); border-color: rgba(255,255,255,.06);
}
.nav-item--active {
  color: #fff; font-weight: 600;
  background: linear-gradient(135deg, rgba(255,255,255,.18) 0%, rgba(255,255,255,.08) 100%);
  border-color: rgba(255,255,255,.15);
  box-shadow: inset 0 1px 0 rgba(255,255,255,.2), 0 4px 16px rgba(0,0,0,.25);
}

/* Left accent bar */
.nav-accent {
  position: absolute; left: 0; top: 18%; bottom: 18%;
  width: 3px; border-radius: 0 3px 3px 0;
  background: transparent; transition: background .18s, box-shadow .18s;
}
.nav-item--active .nav-accent {
  background: linear-gradient(180deg, #6ee7a0, #34d371);
  box-shadow: 0 0 10px rgba(110,231,160,.55);
}

/* Icon */
.nav-icon-wrap {
  width: 1.15rem; height: 1.15rem; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
  opacity: .65; transition: opacity .18s;
}
.nav-item--active .nav-icon-wrap { opacity: 1; }
.nav-icon-wrap :deep(svg) { width: 100%; height: 100%; }
.nav-label { flex: 1; }
.nav-active-dot {
  width: 5px; height: 5px; border-radius: 50%; flex-shrink: 0;
  background: #6ee7a0;
  box-shadow: 0 0 6px #6ee7a0, 0 0 12px rgba(110,231,160,.4);
}

/* User block */
.sb-spacer { flex: 1; }
.sb-separator {
  height: 1px; margin: .5rem .8rem;
  background: linear-gradient(90deg, transparent, rgba(255,255,255,.09) 40%, rgba(255,255,255,.09) 60%, transparent);
}
.sb-user {
  display: flex; align-items: center; gap: .6rem;
  padding: .75rem .9rem;
  margin: 0 .65rem .7rem;
  border-radius: 12px;
  background: rgba(255,255,255,.06);
  border: 1px solid rgba(255,255,255,.09);
  box-shadow: inset 0 1px 0 rgba(255,255,255,.07);
  position: relative; z-index: 1;
}
.user-avatar-lg {
  width: 32px; height: 32px; border-radius: 50%; flex-shrink: 0;
  background: linear-gradient(135deg, rgba(110,231,160,.35), rgba(52,211,113,.15));
  border: 1.5px solid rgba(110,231,160,.3);
  display: flex; align-items: center; justify-content: center;
  font-size: .775rem; font-weight: 700; color: #a7f3c8;
}
.user-meta { display: flex; flex-direction: column; flex: 1; min-width: 0; }
.user-name { font-size: .78rem; font-weight: 600; color: rgba(255,255,255,.8); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.user-role { font-size: .62rem; color: rgba(255,255,255,.3); margin-top: .05rem; }
.logout-icon-btn {
  width: 28px; height: 28px; border-radius: 8px; flex-shrink: 0;
  background: rgba(255,255,255,.06); border: 1px solid rgba(255,255,255,.08);
  color: rgba(255,255,255,.35); cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  transition: background .15s, color .15s, border-color .15s;
}
.logout-icon-btn:hover { background: rgba(239,68,68,.22); color: #fca5a5; border-color: rgba(239,68,68,.3); }
.logout-icon-btn svg { width: 14px; height: 14px; display: block; }

/* ══════════════════════════════ TOPBAR ════════════════════════════ */
.topbar {
  position: relative; z-index: 10; flex-shrink: 0;
  height: 56px;
  display: flex; align-items: center; gap: .75rem;
  padding: 0 1.5rem;
  background: rgba(243,247,243,.82);
  backdrop-filter: blur(28px) saturate(180%);
  -webkit-backdrop-filter: blur(28px) saturate(180%);
  border-bottom: 1px solid rgba(0,0,0,.07);
  box-shadow: 0 1px 0 rgba(255,255,255,.85) inset, 0 2px 12px rgba(0,0,0,.07);
}
/* Green shimmer on bottom edge */
.tb-shimmer {
  position: absolute; bottom: -1px; left: 5%; right: 5%; height: 1px;
  background: linear-gradient(90deg, transparent, rgba(52,211,113,.25) 35%, rgba(110,231,160,.4) 55%, rgba(52,211,113,.25) 75%, transparent);
  pointer-events: none;
}

.hamburger {
  padding: .4rem; border-radius: 8px;
  color: #4b7a5e; background: none; border: none; cursor: pointer;
  transition: color .15s, background .15s;
}
.hamburger:hover { color: #14532d; background: rgba(0,0,0,.06); }
.hamburger svg { width: 20px; height: 20px; display: block; }

/* Breadcrumb */
.tb-crumb   { display: flex; align-items: center; gap: .4rem; }
.crumb-home { width: 15px; height: 15px; color: #86a893; flex-shrink: 0; }
.crumb-sep  { width: 8px; height: 12px; color: #b0c4b8; flex-shrink: 0; }
.crumb-active { font-size: .875rem; font-weight: 600; color: #1a4731; letter-spacing: -.015em; }

/* Right actions */
.tb-actions { display: flex; align-items: center; gap: .6rem; }
.tb-action-btn {
  width: 34px; height: 34px; border-radius: 9px;
  background: rgba(255,255,255,.55); border: 1px solid rgba(0,0,0,.07); color: #4b7a5e;
  cursor: pointer; display: flex; align-items: center; justify-content: center;
  box-shadow: 0 1px 3px rgba(0,0,0,.06), inset 0 1px 0 rgba(255,255,255,.8);
  transition: background .15s, box-shadow .15s;
}
.tb-action-btn:hover { background: rgba(255,255,255,.9); box-shadow: 0 2px 8px rgba(0,0,0,.1), inset 0 1px 0 rgba(255,255,255,.9); color: #14532d; }
.tb-action-btn svg { width: 16px; height: 16px; display: block; }
.tb-vdivider { width: 1px; height: 20px; background: rgba(0,0,0,.08); }
.role-chip {
  font-size: .68rem; font-weight: 600; letter-spacing: .04em;
  padding: .28rem .7rem; border-radius: 999px;
  background: rgba(255,255,255,.6); border: 1px solid rgba(0,0,0,.08); color: #1a4731;
  box-shadow: 0 1px 3px rgba(0,0,0,.06), inset 0 1px 0 rgba(255,255,255,.8);
}
.tb-avatar {
  width: 32px; height: 32px; border-radius: 50%;
  background: linear-gradient(135deg, #22c55e, #16a34a);
  border: 2px solid rgba(255,255,255,.7);
  display: flex; align-items: center; justify-content: center;
  font-size: .72rem; font-weight: 700; color: #fff;
  box-shadow: 0 0 0 2px rgba(34,197,94,.2), 0 2px 6px rgba(0,0,0,.15); cursor: pointer;
}

/* ══════════════════════════ MAIN + CONTENT ═════════════════════════ */
.main-col {
  flex: 1; display: flex; flex-direction: column;
  overflow: hidden; min-width: 0; background: #eef2ee;
}
.content-area {
  flex: 1; overflow-y: auto; padding: 1.5rem; background: #eef2ee;
  scrollbar-width: thin; scrollbar-color: rgba(0,0,0,.12) transparent;
}
.content-area::-webkit-scrollbar { width: 5px; }
.content-area::-webkit-scrollbar-thumb { background: rgba(0,0,0,.1); border-radius: 9999px; }
</style>
