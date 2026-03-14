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
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
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
