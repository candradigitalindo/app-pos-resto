<!--
  AppPagination.vue — Numbered pagination bar
  ───────────────────────────────────────────────────────────────
  Props:
    modelValue  : number   — current page (1-based)
    total       : number   — total items
    perPage     : number   — items per page              default 20

  Emits:
    update:modelValue  — new page number

  Usage:
    <AppPagination v-model="page" :total="total" :perPage="perPage" />

  AI NOTE: This component does NOT fetch data — the parent page is responsible for
  watching `page` and calling the API.
-->
<template>
  <div v-if="totalPages > 1" class="flex items-center justify-between text-sm text-gray-600 mt-4">
    <!-- Info -->
    <span>
      Halaman {{ modelValue }} dari {{ totalPages }}
      <span class="text-gray-400">({{ total }} data)</span>
    </span>

    <!-- Buttons -->
    <div class="flex items-center gap-1">
      <button
        :disabled="modelValue <= 1"
        class="px-3 py-1.5 rounded-lg border border-gray-300 hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
        @click="go(modelValue - 1)"
      >
        ‹ Prev
      </button>

      <button
        v-for="p in visiblePages"
        :key="p"
        :class="[
          'w-9 h-8 rounded-lg border transition-colors',
          p === modelValue
            ? 'bg-brand-600 border-brand-600 text-white font-semibold'
            : 'border-gray-300 hover:bg-gray-50',
        ]"
        @click="go(p)"
      >
        {{ p }}
      </button>

      <button
        :disabled="modelValue >= totalPages"
        class="px-3 py-1.5 rounded-lg border border-gray-300 hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
        @click="go(modelValue + 1)"
      >
        Next ›
      </button>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  modelValue: { type: Number, required: true },
  total:      { type: Number, default: 0 },
  perPage:    { type: Number, default: 20 },
})

const emit = defineEmits(['update:modelValue'])

const totalPages = computed(() => Math.max(1, Math.ceil(props.total / props.perPage)))

/** Show at most 7 page buttons centred around current page */
const visiblePages = computed(() => {
  const cur   = props.modelValue
  const total = totalPages.value
  const window = 3
  const start = Math.max(1, cur - window)
  const end   = Math.min(total, cur + window)
  const pages = []
  for (let i = start; i <= end; i++) pages.push(i)
  return pages
})

function go(p) {
  if (p >= 1 && p <= totalPages.value) emit('update:modelValue', p)
}
</script>
