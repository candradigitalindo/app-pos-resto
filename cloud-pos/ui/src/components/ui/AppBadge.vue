<!--
  AppBadge.vue — Inline status badge
  ───────────────────────────────────────────────────────────────
  Props:
    status   : string — key in STATUS_COLORS map or custom label
    custom   : string — override: full Tailwind classes (bg + text)

  Usage:
    <AppBadge status="success" />
    <AppBadge status="paid" />
    <AppBadge status="active" />
    <AppBadge :custom="'bg-purple-100 text-purple-800'" status="custom label" />

  AI NOTE: Colour mapping is in src/utils/constants.js → STATUS_COLORS.
  Adding a new status only requires a new entry there.
-->
<template>
  <span
    :class="[
      'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium capitalize',
      colorClasses,
    ]"
  >
    <slot>{{ status }}</slot>
  </span>
</template>

<script setup>
import { computed } from 'vue'
import { STATUS_COLORS } from '@/utils/constants.js'

const props = defineProps({
  status: { type: String, default: '' },
  custom: { type: String, default: '' },
})

const colorClasses = computed(() => {
  if (props.custom) return props.custom
  const c = STATUS_COLORS[props.status?.toLowerCase()]
  return c ? `${c.bg} ${c.text}` : 'bg-gray-100 text-gray-700'
})
</script>
