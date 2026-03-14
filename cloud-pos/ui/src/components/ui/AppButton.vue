<!--
  AppButton.vue — Base button component
  ───────────────────────────────────────────────────────────────
  Props:
    variant  : 'primary' | 'secondary' | 'danger' | 'ghost'   default 'primary'
    size     : 'sm' | 'md' | 'lg'                             default 'md'
    loading  : boolean — shows spinner, disables interaction   default false
    type     : 'button' | 'submit' | 'reset'                  default 'button'
    disabled : boolean                                         default false

  Usage:
    <AppButton variant="primary" :loading="saving" @click="save">Save</AppButton>
    <AppButton variant="danger" size="sm">Delete</AppButton>

  AI NOTE: To add a new variant add a key to `VARIANTS` and a Tailwind class string.
-->
<template>
  <button
    :type="type"
    :disabled="disabled || loading"
    :class="[baseClasses, VARIANTS[variant], SIZES[size], { 'opacity-60 cursor-not-allowed': disabled || loading }]"
    v-bind="$attrs"
  >
    <!-- Loading spinner -->
    <svg
      v-if="loading"
      class="animate-spin -ml-1 mr-2 h-4 w-4"
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      aria-hidden="true"
    >
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8z" />
    </svg>

    <slot />
  </button>
</template>

<script setup>
// No reactive state needed — pure presentational component.

defineProps({
  variant:  { type: String,  default: 'primary' },
  size:     { type: String,  default: 'md' },
  loading:  { type: Boolean, default: false },
  type:     { type: String,  default: 'button' },
  disabled: { type: Boolean, default: false },
})

const baseClasses = 'inline-flex items-center justify-center font-medium rounded-lg transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2'

const VARIANTS = {
  primary:   'bg-brand-600 text-white hover:bg-brand-700 focus:ring-brand-500',
  secondary: 'bg-white text-gray-700 border border-gray-300 hover:bg-gray-50 focus:ring-brand-500',
  danger:    'bg-red-600 text-white hover:bg-red-700 focus:ring-red-500',
  ghost:     'text-gray-600 hover:bg-gray-100 focus:ring-gray-400',
}

const SIZES = {
  sm: 'px-3 py-1.5 text-sm',
  md: 'px-4 py-2 text-sm',
  lg: 'px-6 py-3 text-base',
}
</script>
