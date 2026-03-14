<!--
  AppInput.vue — Text input field with label and error support
  ───────────────────────────────────────────────────────────────
  Props:
    modelValue  : string | number       — v-model binding
    label       : string                — visible label above the input
    error       : string                — red error message below input
    placeholder : string
    type        : 'text' | 'password' | 'email' | 'number' | etc.
    disabled    : boolean

  Usage:
    <AppInput v-model="form.name" label="Nama Outlet" :error="errors.name" />
    <AppInput v-model="form.password" label="Password" type="password" />

  AI NOTE: To add prefix/suffix icon slots, add named slots around the inner <input>.
-->
<template>
  <div class="flex flex-col gap-1">
    <label v-if="label" :for="uid" class="text-sm font-medium text-gray-700">
      {{ label }}
    </label>

    <input
      :id="uid"
      :type="type"
      :value="modelValue"
      :placeholder="placeholder"
      :disabled="disabled"
      :class="[
        'w-full rounded-lg border px-3 py-2 text-sm shadow-sm transition-colors',
        'focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500',
        error
          ? 'border-red-400 bg-red-50'
          : 'border-gray-300 bg-white hover:border-gray-400',
        disabled ? 'opacity-60 cursor-not-allowed bg-gray-100' : '',
      ]"
      v-bind="$attrs"
      @input="$emit('update:modelValue', $event.target.value)"
    />

    <p v-if="error" class="text-xs text-red-600">{{ error }}</p>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  modelValue:  { type: [String, Number], default: '' },
  label:       { type: String,  default: '' },
  error:       { type: String,  default: '' },
  placeholder: { type: String,  default: '' },
  type:        { type: String,  default: 'text' },
  disabled:    { type: Boolean, default: false },
})

defineEmits(['update:modelValue'])

// Unique id so <label for="..."> works — avoids duplicate ids on same page.
const uid = computed(() => `input-${Math.random().toString(36).slice(2, 9)}`)
</script>
