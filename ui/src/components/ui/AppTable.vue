<!--
  AppTable.vue — Responsive data table with loading and empty states
  ───────────────────────────────────────────────────────────────
  Props:
    columns     : Array<{ key: string, label: string, class?: string }>
    rows        : Array<object>
    loading     : boolean   — shows skeleton rows when true
    emptyText   : string    — message when rows is empty (default 'Tidak ada data')

  Slots:
    cell-{key}  — custom cell renderer. Receives { row, value }
                  e.g. <template #cell-status="{ row }"><AppBadge :status="row.status" /></template>
    actions     — prepend slot name 'actions' column (already declared in columns)

  Usage:
    <AppTable :columns="cols" :rows="data" :loading="loading">
      <template #cell-status="{ row }">
        <AppBadge :status="row.status" />
      </template>
      <template #cell-actions="{ row }">
        <AppButton size="sm" variant="ghost" @click="edit(row)">Edit</AppButton>
      </template>
    </AppTable>

  AI NOTE: To add sortable headers, add a @click emitter on <th> and pass sort state as props.
-->
<template>
  <div class="overflow-x-auto rounded-lg border border-gray-200">
    <table class="min-w-full text-sm divide-y divide-gray-200">
      <!-- Head -->
      <thead class="bg-gray-50">
        <tr>
          <th
            v-for="col in columns"
            :key="col.key"
            scope="col"
            :class="[
              'px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide',
              col.class ?? '',
            ]"
          >
            {{ col.label }}
          </th>
        </tr>
      </thead>

      <!-- Body -->
      <tbody class="bg-white divide-y divide-gray-100">

        <!-- Skeleton rows while loading -->
        <template v-if="loading">
          <tr v-for="i in 5" :key="`skeleton-${i}`">
            <td
              v-for="col in columns"
              :key="col.key"
              class="px-4 py-3"
            >
              <div class="h-4 bg-gray-200 rounded animate-pulse" />
            </td>
          </tr>
        </template>

        <!-- Empty state -->
        <tr v-else-if="!rows.length">
          <td :colspan="columns.length" class="px-4 py-12 text-center text-gray-400">
            {{ emptyText }}
          </td>
        </tr>

        <!-- Data rows -->
        <template v-else>
          <tr
            v-for="(row, idx) in rows"
            :key="row.id ?? idx"
            class="hover:bg-gray-50 transition-colors"
          >
            <td
              v-for="col in columns"
              :key="col.key"
              :class="['px-4 py-3 text-gray-700 align-middle', col.class ?? '']"
            >
              <!-- Named slot override: #cell-{key} -->
              <slot
                v-if="$slots[`cell-${col.key}`]"
                :name="`cell-${col.key}`"
                :row="row"
                :value="row[col.key]"
              />
              <!-- Default: display raw value -->
              <span v-else>{{ row[col.key] ?? '—' }}</span>
            </td>
          </tr>
        </template>
      </tbody>
    </table>
  </div>
</template>

<script setup>
defineProps({
  columns:   { type: Array,   required: true },
  rows:      { type: Array,   default: () => [] },
  loading:   { type: Boolean, default: false },
  emptyText: { type: String,  default: 'Tidak ada data.' },
})
</script>
