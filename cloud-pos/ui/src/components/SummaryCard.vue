<template>
  <div class="summary-card">
    <div class="flex items-center gap-2 mb-2">
      <div class="sc-icon" v-html="ICONS[icon]" />
      <span class="text-xs font-medium text-gray-500 uppercase tracking-wide">{{ label }}</span>
    </div>
    <div v-if="value != null" class="text-xl font-bold text-gray-800">{{ value }}</div>
    <slot />
  </div>
</template>

<script setup>
defineProps({
  label: { type: String, required: true },
  value: { type: [String, Number], default: null },
  icon:  { type: String, default: 'receipt' },
})

const ICONS = {
  receipt: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor" class="w-5 h-5 text-emerald-600">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8" d="M9 14l6-6m-5.5.5h.01m4.99 5h.01M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16l3.5-2 3.5 2 3.5-2 3.5 2z"/>
  </svg>`,
  revenue: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor" class="w-5 h-5 text-emerald-600">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8" d="M2.25 18.75a60.07 60.07 0 0115.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 013 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 00-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 01-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 003 15h-.75M15 10.5a3 3 0 11-6 0 3 3 0 016 0zm3 0h.008v.008H18V10.5zm-12 0h.008v.008H6V10.5z"/>
  </svg>`,
  avg: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor" class="w-5 h-5 text-emerald-600">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
  </svg>`,
  payment: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor" class="w-5 h-5 text-emerald-600">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"/>
  </svg>`,
}
</script>

<style scoped>
.summary-card {
  border-radius: 1rem;
  background: rgba(255,255,255,.78);
  backdrop-filter: blur(22px) saturate(170%);
  -webkit-backdrop-filter: blur(22px) saturate(170%);
  border: 1px solid rgba(255,255,255,.68);
  box-shadow: 0 2px 16px rgba(0,0,0,.07), 0 1px 0 rgba(255,255,255,.92) inset;
  padding: 1.25rem;
}
</style>
