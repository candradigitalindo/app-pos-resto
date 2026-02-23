<template>
  <div class="overflow-hidden rounded-2xl bg-white shadow-lg">
    <div class="overflow-x-auto">
      <table class="min-w-full">
        <thead class="bg-gradient-to-r from-slate-50 to-emerald-50">
          <tr class="text-xs font-bold uppercase tracking-wider text-slate-600">
            <th
              v-for="column in columns"
              :key="column.key"
              :class="['px-6 py-4', column.align || 'text-left']"
            >
              <slot :name="`header-${column.key}`">
                <div v-if="column.icon" class="flex items-center gap-2" :class="column.align === 'text-center' ? 'justify-center' : ''">
                  <svg v-if="column.icon" class="h-4 w-4 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" :d="column.icon"/>
                  </svg>
                  {{ column.label }}
                </div>
                <template v-else>{{ column.label }}</template>
              </slot>
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr v-for="(item, index) in data" :key="getItemKey(item, index)" class="transition-colors hover:bg-emerald-50/50">
            <td
              v-for="column in columns"
              :key="column.key"
              :class="['px-6 py-4', column.align || 'text-left']"
            >
              <slot :name="`cell-${column.key}`" :item="item" :value="item[column.key]">
                {{ item[column.key] }}
              </slot>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  columns: {
    type: Array,
    required: true
    // Format: [{ key: 'name', label: 'Nama', align: 'text-left', icon: 'path-d-value' }]
  },
  data: {
    type: Array,
    required: true
  },
  itemKey: {
    type: String,
    default: 'id'
  }
})

const getItemKey = (item, index) => {
  return item[props.itemKey] || index
}
</script>
