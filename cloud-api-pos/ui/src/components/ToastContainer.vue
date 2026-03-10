<!--
  ToastContainer.vue — Global toast notification renderer
  ───────────────────────────────────────────────────────────────
  Place once in App.vue (or DashboardLayout.vue). Reads from useToastStore().

  AI NOTE: Each toast auto-removes itself via the store's `remove(id)` method.
  To show a toast from any component: import { useToastStore } from '@/stores/toast'
  then call toastStore.success('Message') / toastStore.error('Message') etc.
-->
<template>
  <Teleport to="body">
    <div
      aria-live="polite"
      aria-atomic="false"
      class="fixed bottom-4 right-4 z-[9999] flex flex-col gap-2 pointer-events-none"
    >
      <TransitionGroup
        tag="div"
        class="flex flex-col gap-2"
        enter-active-class="transition-all duration-300"
        leave-active-class="transition-all duration-200"
        enter-from-class="opacity-0 translate-y-4 scale-95"
        leave-to-class="opacity-0 scale-95"
      >
        <div
          v-for="t in toasts"
          :key="t.id"
          :class="[
            'pointer-events-auto flex items-start gap-3 px-4 py-3 rounded-xl shadow-lg min-w-[280px] max-w-sm border',
            STYLES[t.type] ?? STYLES.info,
          ]"
          role="alert"
        >
          <!-- Icon -->
          <span class="text-lg leading-none select-none">{{ ICONS[t.type] ?? ICONS.info }}</span>

          <!-- Message -->
          <span class="flex-1 text-sm font-medium">{{ t.message }}</span>

          <!-- Close -->
          <button
            class="text-current opacity-50 hover:opacity-100 transition-opacity ml-2"
            @click="store.remove(t.id)"
            aria-label="Tutup"
          >
            ✕
          </button>
        </div>
      </TransitionGroup>
    </div>
  </Teleport>
</template>

<script setup>
import { useToastStore } from '@/stores/toast.js'

const store  = useToastStore()
const toasts = store.toasts

const STYLES = {
  success: 'bg-green-600 text-white border-green-700',
  error:   'bg-red-600   text-white border-red-700',
  warning: 'bg-yellow-500 text-white border-yellow-600',
  info:    'bg-gray-800  text-white border-gray-900',
}

const ICONS = {
  success: '✓',
  error:   '✕',
  warning: '⚠',
  info:    'ℹ',
}
</script>
