<!--
  AuthLayout.vue — Natural + Informative split layout (Tahoe glass aesthetic)
  ─────────────────────────────────────────────────────────────────────────────
  Desktop: two-column — left info panel + right login card
  Mobile:  single column, info panel collapses to header strip
-->
<template>
  <div class="scene">

    <!-- ── Atmospheric layer ── -->
    <div class="atmo" aria-hidden="true">
      <div class="orb o1" /><div class="orb o2" /><div class="orb o3" />
      <!-- Topographic SVG rings -->
      <svg class="topo" viewBox="0 0 800 800" fill="none" preserveAspectRatio="xMidYMid slice">
        <g stroke="rgba(126,184,154,.07)" stroke-width="1" fill="none">
          <ellipse cx="400" cy="400" rx="80"  ry="50"  />
          <ellipse cx="400" cy="400" rx="140" ry="90"  />
          <ellipse cx="400" cy="400" rx="210" ry="140" />
          <ellipse cx="400" cy="400" rx="285" ry="196" />
          <ellipse cx="400" cy="400" rx="365" ry="258" />
          <ellipse cx="400" cy="400" rx="450" ry="325" />
          <ellipse cx="400" cy="400" rx="540" ry="398" />
          <ellipse cx="400" cy="400" rx="636" ry="476" />
        </g>
      </svg>
      <!-- Leaf vein lines top-left decoration -->
      <svg class="leaf-vein" viewBox="0 0 320 420" fill="none">
        <path d="M10 400 C 60 280, 160 200, 160 10" stroke="rgba(126,184,154,.12)" stroke-width="1.2" />
        <path d="M160 10 C 200 80,  260 140, 310 180" stroke="rgba(126,184,154,.08)" stroke-width="1" />
        <path d="M160 10 C 120 60,   60 100,  10 130" stroke="rgba(126,184,154,.08)" stroke-width="1" />
        <path d="M10 400 C 90 320, 220 280, 310 300" stroke="rgba(126,184,154,.06)" stroke-width="1" />
        <path d="M100 330 C 130 240, 170 180, 200 100" stroke="rgba(126,184,154,.06)" stroke-width=".8" />
        <path d="M50 370  C 100 300, 150 250, 220 200" stroke="rgba(126,184,154,.05)" stroke-width=".8" />
      </svg>
    </div>

    <!-- ── Two-column stage ── -->
    <div class="stage">

      <!-- LEFT: Info panel -->
      <aside class="info-panel">
        <!-- Logo mark -->
        <div class="brand-mark">
          <svg viewBox="0 0 36 36" fill="none" class="w-9 h-9">
            <rect x="2"  y="2"  width="15" height="15" rx="4" fill="rgba(126,184,154,.9)" />
            <rect x="19" y="2"  width="15" height="15" rx="4" fill="rgba(126,184,154,.5)" />
            <rect x="2"  y="19" width="15" height="15" rx="4" fill="rgba(126,184,154,.5)" />
            <rect x="19" y="19" width="15" height="15" rx="4" fill="rgba(126,184,154,.72)" />
          </svg>
          <span class="brand-name">Nusantara POS</span>
        </div>

        <!-- Headline -->
        <div class="headline">
          <h1>Cloud Management<br/><span class="hl-accent">Dashboard</span></h1>
          <p class="tagline">
            Kelola semua outlet, transaksi, dan sinkronisasi<br/>
            data real-time dari satu panel terpusat.
          </p>
        </div>

        <!-- Feature chips -->
        <ul class="feature-list">
          <li v-for="f in features" :key="f.label" class="feature-item">
            <span class="f-icon-wrap" v-html="f.icon" />
            <div>
              <div class="f-label">{{ f.label }}</div>
              <div class="f-desc">{{ f.desc }}</div>
            </div>
          </li>
        </ul>

        <!-- Version badge -->
        <div class="version-badge">
          <span class="v-dot" />
          Cloud Edition &nbsp;·&nbsp; v2.0.0
        </div>
      </aside>

      <!-- RIGHT: Login card slot -->
      <main class="card-slot">
        <RouterView />
      </main>
    </div>
  </div>
</template>

<script setup>
const features = [
  {
    label: 'Multi-Outlet Real-time Sync',
    desc:  'Data transaksi & produk selalu sinkron otomatis',
    icon:  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" class="w-4 h-4"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.6" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/></svg>',
  },
  {
    label: 'Manajemen Produk & Kategori',
    desc:  'Atur menu dan printer per kategori dengan mudah',
    icon:  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" class="w-4 h-4"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.6" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/></svg>',
  },
  {
    label: 'Laporan Transaksi Lengkap',
    desc:  'Riwayat order, pembayaran, dan shift kasir',
    icon:  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" class="w-4 h-4"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.6" d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/></svg>',
  },
  {
    label: 'Conflict Resolution Otomatis',
    desc:  'Deteksi & selesaikan konflik data antar perangkat',
    icon:  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" class="w-4 h-4"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.6" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"/></svg>',
  },
]

</script>

<style scoped>
/* ── Root canvas ─────────────────────────────────────────── */
.scene {
  position: relative;
  min-height: 100svh;
  overflow: hidden;
  background:
    radial-gradient(ellipse 110% 70% at 20% 100%, #253f2d 0%, transparent 55%),
    radial-gradient(ellipse 90%  60% at 85% 0%,   #1e3427 0%, transparent 55%),
    radial-gradient(ellipse 70%  50% at 50% 50%,  #1e3228 0%, transparent 60%),
    #182b20;
}

/* ── Atmosphere ──────────────────────────────────────────── */
.atmo {
  position: absolute;
  inset: 0;
  pointer-events: none;
}

.orb {
  position: absolute;
  border-radius: 50%;
  filter: blur(80px);
}
.o1 {
  width: 560px; height: 480px;
  top: -120px; left: -80px;
  background: radial-gradient(circle at 40% 40%, rgba(74,130,100,.16), rgba(50,100,78,.04));
  animation: fa 20s ease-in-out infinite alternate;
}
.o2 {
  width: 420px; height: 420px;
  bottom: -100px; right: -60px;
  background: radial-gradient(circle at 60% 60%, rgba(126,184,154,.13), rgba(50,100,78,.03));
  animation: fb 25s ease-in-out infinite alternate;
}
.o3 {
  width: 280px; height: 280px;
  top: 40%; left: 40%;
  background: radial-gradient(circle, rgba(120,175,145,.09), transparent 70%);
  animation: fc 16s ease-in-out infinite alternate;
}
@keyframes fa { to { transform: translate(30px, 20px) scale(1.06); } }
@keyframes fb { to { transform: translate(-25px,-30px) scale(1.08); } }
@keyframes fc { to { transform: translate(-18px, 22px) scale(.92);  } }

/* Topographic rings — centered */
.topo {
  position: absolute;
  width: 620px; height: 620px;
  top: 50%; left: 32%;
  transform: translate(-50%, -50%);
  opacity: .7;
  animation: topo-spin 120s linear infinite;
}
@keyframes topo-spin { to { transform: translate(-50%,-50%) rotate(360deg); } }

/* Leaf vein — top-left corner accent */
.leaf-vein {
  position: absolute;
  top: 0; left: 0;
  width: 260px; height: 340px;
  opacity: .9;
}

/* ── Layout stage ─────────────────────────────────────────── */
.stage {
  position: relative;
  z-index: 10;
  min-height: 100svh;
  display: grid;
  grid-template-columns: 1fr 440px;
  align-items: center;
  gap: 0;
  padding: 2rem 3rem 2rem 4rem;
}

@media (max-width: 900px) {
  .stage {
    grid-template-columns: 1fr;
    padding: 2rem 1.5rem;
    gap: 2rem;
  }
  .info-panel {
    padding: 0 !important;
    align-items: center;
    text-align: center;
  }
  .feature-list  { display: none !important; }
  .headline h1   { font-size: 1.6rem !important; }
}

/* ── Info panel ───────────────────────────────────────────── */
.info-panel {
  display: flex;
  flex-direction: column;
  gap: 2rem;
  padding-right: 2rem;
  max-width: 520px;
}

.brand-mark {
  display: flex;
  align-items: center;
  gap: .75rem;
}
.brand-name {
  font-size: 1rem;
  font-weight: 700;
  color: rgba(255,255,255,.75);
  letter-spacing: .02em;
}

.headline h1 {
  font-size: 2.4rem;
  font-weight: 800;
  line-height: 1.18;
  color: rgba(255,255,255,.9);
  letter-spacing: -.035em;
}
.hl-accent {
  background: linear-gradient(120deg, #7eb89a, #a8cbbf, #7eb89a);
  background-size: 200%;
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  animation: shimmer 4s linear infinite;
}
@keyframes shimmer { to { background-position: 200% center; } }

.tagline {
  margin-top: .75rem;
  font-size: .9rem;
  line-height: 1.65;
  color: rgba(255,255,255,.38);
}

/* Feature list */
.feature-list {
  list-style: none;
  padding: 0; margin: 0;
  display: flex;
  flex-direction: column;
  gap: .875rem;
}
.feature-item {
  display: flex;
  align-items: flex-start;
  gap: .875rem;
  padding: .875rem 1rem;
  border-radius: 1rem;
  border: 1px solid rgba(255,255,255,.06);
  background: rgba(255,255,255,.03);
  backdrop-filter: blur(6px);
  transition: border-color .2s, background .2s;
}
.feature-item:hover {
  border-color: rgba(126,184,154,.2);
  background: rgba(126,184,154,.04);
}
.f-icon-wrap {
  flex-shrink: 0;
  width: 2rem; height: 2rem;
  border-radius: .625rem;
  background: rgba(126,184,154,.12);
  border: 1px solid rgba(126,184,154,.18);
  display: flex; align-items: center; justify-content: center;
  color: #a8cbbf;
}
.f-label {
  font-size: .82rem;
  font-weight: 600;
  color: rgba(255,255,255,.78);
}
.f-desc {
  font-size: .75rem;
  color: rgba(255,255,255,.32);
  margin-top: .15rem;
}



/* Version badge */
.version-badge {
  display: inline-flex;
  align-items: center;
  gap: .45rem;
  font-size: .7rem;
  color: rgba(255,255,255,.22);
  letter-spacing: .06em;
  text-transform: uppercase;
}
.v-dot {
  width: 6px; height: 6px;
  border-radius: 50%;
  background: #7eb89a;
  box-shadow: 0 0 6px #7eb89a;
  animation: blink 2.4s ease-in-out infinite;
}
@keyframes blink {
  0%, 100% { opacity: 1; }
  50%       { opacity: .25; }
}

/* ── Card slot ────────────────────────────────────────────── */
.card-slot {
  display: flex;
  align-items: center;
  justify-content: center;
}
</style>
