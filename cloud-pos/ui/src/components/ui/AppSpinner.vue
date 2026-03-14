<!--
  AppSpinner.vue — Animated loading indicator
  ───────────────────────────────────────────────────────────────
  Props:
    size  : 'sm' | 'md' | 'lg'   default 'md'

  Usage:
    <AppSpinner />
    <AppSpinner size="lg" />
    <div v-if="loading" class="flex justify-center py-12"><AppSpinner /></div>
-->
<template>
  <svg
    :class="['animate-spin text-brand-600', SIZES[size]]"
    xmlns="http://www.w3.org/2000/svg"
    fill="none"
    viewBox="0 0 24 24"
    aria-label="Loading"
    role="status"
  >
    <circle
      class="opacity-25"
      cx="12" cy="12" r="10"
      stroke="currentColor" stroke-width="4"
    />
    <path
      class="opacity-75"
      fill="currentColor"
      d="M4 12a8 8 0 018-8v8z"
    />
  </svg>
</template>

<script setup>
defineProps({
  size: { type: String, default: 'md' },
})

const SIZES = {
  sm: 'w-4 h-4',
  md: 'w-6 h-6',
  lg: 'w-10 h-10',
}
</script>
