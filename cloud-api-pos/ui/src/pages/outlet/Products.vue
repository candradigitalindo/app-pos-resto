<!--
  Products.vue — Product list for one outlet
  ───────────────────────────────────────────────────────────────
  Route: /outlets/:id/products   (child of OutletDetail)
-->
<template>
  <div class="space-y-4">
    <AppAlert type="error" :message="errorMsg" />
    <AppCard :padding="false">
      <AppTable :columns="COLUMNS" :rows="items" :loading="loading" emptyText="Belum ada produk.">
        <template #cell-price="{ row }">{{ formatRupiah(row.price) }}</template>
        <template #cell-is_available="{ row }">
          <AppBadge :status="row.is_available ? 'active' : 'inactive'" />
        </template>
      </AppTable>
      <div class="px-4 py-3 border-t border-gray-100">
        <AppPagination v-model="page" :total="total" :perPage="PAGE_SIZE" />
      </div>
    </AppCard>
  </div>
</template>

<script setup>
import { ref, watch, onMounted, computed } from 'vue'
import { useRoute } from 'vue-router'
import { outletsApi } from '@/api/outlets.js'
import { formatRupiah } from '@/utils/format.js'
import { PAGE_SIZE } from '@/utils/constants.js'
import AppCard from '@/components/ui/AppCard.vue'
import AppTable from '@/components/ui/AppTable.vue'
import AppBadge from '@/components/ui/AppBadge.vue'
import AppAlert from '@/components/ui/AppAlert.vue'
import AppPagination from '@/components/ui/AppPagination.vue'

const route    = useRoute()
const outletId = computed(() => route.params.id)

const COLUMNS = [
  { key: 'code',         label: 'Kode', class: 'font-mono text-xs' },
  { key: 'name',         label: 'Nama Produk' },
  { key: 'category_name',label: 'Kategori' },
  { key: 'price',        label: 'Harga' },
  { key: 'stock',        label: 'Stok' },
  { key: 'is_available', label: 'Status' },
]

const items = ref([]); const total = ref(0); const page = ref(1)
const loading = ref(false); const errorMsg = ref('')

onMounted(fetch); watch(page, fetch)

async function fetch() {
  loading.value = true; errorMsg.value = ''
  try {
    const res  = await outletsApi.products(outletId.value, { page: page.value, limit: PAGE_SIZE })
    const data = res.data?.data ?? res.data
    items.value = data.products ?? data ?? []
    total.value = data.total    ?? items.value.length
  } catch (err) {
    errorMsg.value = err?.response?.data?.message ?? 'Gagal memuat produk.'
  } finally { loading.value = false }
}
</script>
