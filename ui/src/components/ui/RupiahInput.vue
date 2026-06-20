<template>
  <div class="relative">
    <span class="absolute left-2 top-1/2 -translate-y-1/2 text-xs text-gray-400 pointer-events-none select-none">Rp</span>
    <input
      ref="inputEl"
      type="text"
      inputmode="numeric"
      :value="display"
      :placeholder="placeholder"
      class="w-full rounded-lg border border-gray-300 pl-7 pr-2.5 py-1.5 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500"
      @focus="onFocus"
      @blur="onBlur"
      @input="onInput"
    />
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue'

const props = defineProps({
  modelValue: { type: Number, default: 0 },
  placeholder: { type: String, default: '0' },
})

const emit = defineEmits(['update:modelValue'])

const focused = ref(false)
const inputEl = ref(null)

function formatNumber(val) {
  const num = Number(val) || 0
  if (num === 0) return ''
  return num.toLocaleString('id-ID')
}

function parseRupiah(str) {
  const cleaned = String(str).replace(/[^\d]/g, '')
  return Number(cleaned) || 0
}

const display = computed(() => {
  if (focused.value) return rawText.value
  return formatNumber(props.modelValue)
})

const rawText = ref('')

function onFocus() {
  focused.value = true
  rawText.value = props.modelValue ? formatNumber(props.modelValue) : ''
}

function onBlur() {
  focused.value = false
}

function onInput(e) {
  const val = e.target.value
  const num = parseRupiah(val)
  rawText.value = num ? num.toLocaleString('id-ID') : ''
  emit('update:modelValue', num)
  // Set cursor position after Vue re-renders
  const el = e.target
  const cursorPos = rawText.value.length
  requestAnimationFrame(() => {
    el.value = rawText.value
    el.setSelectionRange(cursorPos, cursorPos)
  })
}

watch(() => props.modelValue, (newVal) => {
  if (focused.value) {
    rawText.value = newVal ? formatNumber(newVal) : ''
  }
})
</script>
