<template>
  <div class="rounded-2xl bg-white p-4 shadow-lg">
    <!-- Mobile Pagination -->
    <div class="flex flex-col gap-3 md:hidden">
      <!-- Info -->
      <div class="flex items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-emerald-50 to-emerald-100 px-4 py-3 shadow-sm">
        <svg class="h-5 w-5 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
        </svg>
        <div class="flex flex-col items-center">
          <span class="text-lg font-bold text-emerald-800">{{ currentPage }} / {{ totalPages }}</span>
          <span class="text-xs text-emerald-600">Total {{ totalItems }} {{ itemName }}</span>
        </div>
      </div>
      <!-- Buttons -->
      <div class="grid grid-cols-2 gap-2">
        <button @click="handlePageChange(currentPage - 1)" :disabled="currentPage === 1" :class="['flex items-center justify-center gap-2 rounded-xl px-4 py-3 font-bold shadow-md transition-all', currentPage === 1 ? 'cursor-not-allowed bg-slate-100 text-slate-400' : 'bg-gradient-to-r from-emerald-500 to-emerald-600 text-white hover:from-emerald-600 hover:to-emerald-700 active:scale-95']">
          <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
          </svg>
          Previous
        </button>
        <button @click="handlePageChange(currentPage + 1)" :disabled="currentPage === totalPages" :class="['flex items-center justify-center gap-2 rounded-xl px-4 py-3 font-bold shadow-md transition-all', currentPage === totalPages ? 'cursor-not-allowed bg-slate-100 text-slate-400' : 'bg-gradient-to-r from-emerald-500 to-emerald-600 text-white hover:from-emerald-600 hover:to-emerald-700 active:scale-95']">
          Next
          <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
          </svg>
        </button>
      </div>
    </div>
    
    <!-- Desktop Pagination -->
    <div class="hidden md:flex flex-wrap items-center justify-center gap-3">
      <button @click="handlePageChange(currentPage - 1)" :disabled="currentPage === 1" :class="['flex items-center gap-2 rounded-lg px-4 py-2 font-semibold transition-all', currentPage === 1 ? 'cursor-not-allowed bg-slate-100 text-slate-400' : 'bg-emerald-100 text-emerald-700 hover:bg-emerald-200 hover:scale-105 active:scale-95']">
        <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
        </svg>
        Prev
      </button>
      <div class="flex items-center gap-2 rounded-lg bg-gradient-to-r from-emerald-100 to-emerald-200 px-4 py-2">
        <span class="text-sm font-bold text-emerald-800">
          Halaman {{ currentPage }} dari {{ totalPages }}
        </span>
        <span class="text-xs text-emerald-600">({{ totalItems }} {{ itemName }})</span>
      </div>
      <button @click="handlePageChange(currentPage + 1)" :disabled="currentPage === totalPages" :class="['flex items-center gap-2 rounded-lg px-4 py-2 font-semibold transition-all', currentPage === totalPages ? 'cursor-not-allowed bg-slate-100 text-slate-400' : 'bg-emerald-100 text-emerald-700 hover:bg-emerald-200 hover:scale-105 active:scale-95']">
        Next
        <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
        </svg>
      </button>
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  currentPage: {
    type: Number,
    required: true
  },
  totalPages: {
    type: Number,
    required: true
  },
  totalItems: {
    type: Number,
    required: true
  },
  itemName: {
    type: String,
    default: 'items'
  }
})

const emit = defineEmits(['page-change'])

const handlePageChange = (page) => {
  if (page >= 1 && page <= props.totalPages) {
    emit('page-change', page)
  }
}
</script>
