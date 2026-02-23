import { ref, onMounted, onUnmounted, computed, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import api, { subscribeRealtime } from '../services/api'
import { useAuthStore } from '../stores/auth'
import { useNotification } from './useNotification'

export function useCashierView() {
  const loading = ref(false)
  const loadingHistory = ref(false)
  const loadingVoidedHistory = ref(false)
  const loadingOrderDetail = ref(false)
  const processingPayment = ref(false)
  const printingBill = ref(false)
  const activeTab = ref('orders')
  const authStore = useAuthStore()
  const { warning: showWarning } = useNotification()

  const allTables = ref([])
  const transactions = ref([])
  const voidedOrders = ref([])
  const currentOrder = ref(null)
  const todayRevenue = ref(0)
  const todayTransactions = ref(0)
  const tableSearchQuery = ref('')
  const historyStartDate = ref('')
  const historyEndDate = ref('')
  const transactionPagination = ref({
    current_page: 1,
    total_pages: 1,
    total_items: 0,
    page_size: 50
  })
  const voidPagination = ref({
    current_page: 1,
    total_pages: 1,
    total_items: 0,
    page_size: 50
  })
  const shiftState = ref({ open_shift: null, last_closed_shift: null })
  const shiftLoading = ref(false)
  const cashierUsers = ref([])
  const cashierUsersLoading = ref(false)

  const showOrderModal = ref(false)
  const showSplitPaymentModal = ref(false)
  const showVoidModal = ref(false)
  const showCancelTransactionModal = ref(false)
  const showReceiptModal = ref(false)
  const showItemsModal = ref(false)
  const loadingItemsModal = ref(false)
  const itemsModalOrder = ref(null)
  const itemsModalItems = ref([])
  const itemUpdateLoading = ref({})
  const showDiscountModal = ref(false)
  const discountType = ref('percentage')
  const discountValue = ref(0)
  const discountValueDisplay = ref('')
  const discountSubmitting = ref(false)
  const complimentSubmitting = ref(false)
  const showOpenShiftModal = ref(false)
  const showCloseShiftModal = ref(false)
  const showHandoverShiftModal = ref(false)
  const showHandoverPinModal = ref(false)

  const selectedPaymentMethod = ref('cash')
  const selectedSplitPaymentMethod = ref('cash')
  const splitNote = ref('')
  const splitItemSelections = ref({})
  const fullPaidAmount = ref(0)
  const fullPaidAmountDisplay = ref('')
  const splitPaidAmount = ref(0)
  const splitPaidAmountDisplay = ref('')
  const voidPin = ref('')
  const voidReason = ref('')
  const voidProcessing = ref(false)
  const selectedTransaction = ref(null)
  const cancelPin = ref('')
  const cancelReason = ref('')
  const cancelProcessing = ref(false)
  const receiptLoading = ref(false)
  const receiptPrinting = ref(false)
  const receiptTransaction = ref(null)
  const receiptOrder = ref(null)
  const outletConfig = ref({
    outlet_name: 'Outlet',
    outlet_address: '',
    outlet_phone: '',
    receipt_footer: 'Terima kasih atas kunjungan Anda!',
    social_media: ''
  })
  const openingCash = ref(null)
  const openingCashDisplay = ref('')
  const selectedHandoverCashier = ref('')
  const handoverCurrentPin = ref('')
  const handoverNextPin = ref('')
  const showCashMovementModal = ref(false)
  const cashMovementType = ref('in')
  const cashMovementName = ref('')
  const cashMovementNote = ref('')
  const cashMovementAmount = ref(0)
  const cashMovementAmountDisplay = ref('')
  const cashMovementSubmitting = ref(false)
  const showCashMovementHistoryModal = ref(false)
  const cashMovementHistoryType = ref('in')
  const cashMovementHistorySource = ref('current')

  const paymentMethods = [
    { value: 'cash', label: 'Tunai' },
    { value: 'card', label: 'Kartu' },
    { value: 'qris', label: 'QRIS' },
    { value: 'transfer', label: 'Transfer' }
  ]

  const transactionColumns = [
    { key: 'time', label: 'Waktu' },
    { key: 'id', label: 'Nomor Pesanan' },
    { key: 'payment_method', label: 'Metode' },
    { key: 'total_amount', label: 'Total', align: 'text-right' },
    { key: 'status', label: 'Status', align: 'text-center' },
    { key: 'actions', label: 'Aksi', align: 'text-center' }
  ]

  const voidColumns = [
    { key: 'voided_at', label: 'Waktu Void' },
    { key: 'id', label: 'Nomor Pesanan' },
    { key: 'table_number', label: 'Meja' },
    { key: 'total_amount', label: 'Total', align: 'text-right' },
    { key: 'voided_by', label: 'Dibatalkan Oleh' },
    { key: 'void_reason', label: 'Alasan' }
  ]

  const avgTransaction = computed(() => {
    if (todayTransactions.value === 0) return 0
    return todayRevenue.value / todayTransactions.value
  })

  const pendingTables = computed(() => {
    return allTables.value.filter((table) =>
      table.active_order &&
      table.active_order.payment_status !== 'paid' &&
      !table.active_order.is_merged
    )
  })

  const filteredPendingTables = computed(() => {
    if (!tableSearchQuery.value.trim()) return pendingTables.value
    const query = tableSearchQuery.value.trim().toLowerCase()
    return pendingTables.value.filter((table) =>
      table.table_number?.toString().toLowerCase().includes(query)
    )
  })

  const orderItems = computed(() => {
    return currentOrder.value?.items || []
  })

  const manualAdjustments = computed(() => {
    return currentOrder.value?.adjustments || []
  })

  const splitSelectedItems = computed(() => {
    return orderItems.value
      .map((item) => ({
        ...item,
        splitQty: splitItemSelections.value[item.id] || 0
      }))
      .filter((item) => item.splitQty > 0)
  })

  const splitItemsTotal = computed(() => {
    return splitSelectedItems.value.reduce((sum, item) => sum + item.splitQty * item.price, 0)
  })

  const splitTotalExceedsRemaining = computed(() => {
    if (!currentOrder.value?.order) return false
    const remaining = getRemainingAmount(currentOrder.value.order)
    return splitItemsTotal.value > remaining
  })

  const remainingAmount = computed(() => {
    if (!currentOrder.value?.order) return 0
    return getRemainingAmount(currentOrder.value.order)
  })

  const fullChangeAmount = computed(() => {
    return Math.max(fullPaidAmount.value - remainingAmount.value, 0)
  })

  const splitChangeAmount = computed(() => {
    return Math.max(splitPaidAmount.value - splitItemsTotal.value, 0)
  })

  const splitPayments = computed(() => {
    return currentOrder.value?.payments || []
  })

  const receiptItems = computed(() => {
    return receiptOrder.value?.items || []
  })

  const receiptPayments = computed(() => {
    return receiptOrder.value?.payments || []
  })

  const receiptAdditionalCharges = computed(() => {
    const charges = receiptOrder.value?.additional_charges
    if (Array.isArray(charges) && charges.length) {
      return charges.filter((charge) => (charge?.amount || 0) !== 0)
    }
    const adjustments = receiptOrder.value?.adjustments || []
    return adjustments
      .map((item) => ({
        name: item.name,
        amount: item.applied_amount
      }))
      .filter((item) => (item?.amount || 0) !== 0)
  })

  const receiptSubtotal = computed(() => {
    return receiptItems.value.reduce((sum, item) => sum + getReceiptItemTotal(item), 0)
  })

  const receiptTotal = computed(() => {
    return (
      receiptOrder.value?.order?.original_total_amount ||
      receiptOrder.value?.order?.total_amount ||
      receiptTransaction.value?.total_amount ||
      receiptSubtotal.value
    )
  })

  const receiptPaidAmount = computed(() => {
    if (receiptPayments.value.length) {
      return receiptPayments.value.reduce((sum, payment) => sum + (payment.amount || 0), 0)
    }
    if (receiptTransaction.value?.paid_amount != null) {
      return receiptTransaction.value.paid_amount
    }
    return receiptTotal.value
  })

  const receiptChangeAmount = computed(() => {
    const method = receiptPayments.value[0]?.payment_method || receiptTransaction.value?.payment_method
    if (method !== 'cash') return 0
    return Math.max(receiptPaidAmount.value - receiptTotal.value, 0)
  })

  const historyLoading = computed(() => {
    return loadingHistory.value || loadingVoidedHistory.value
  })

  const historyStartMax = computed(() => {
    const today = new Date()
    return formatDateInput(today)
  })

  const historyEndMax = computed(() => {
    if (!historyStartDate.value) return historyStartMax.value
    const maxEnd = addMonths(new Date(historyStartDate.value), 3)
    const today = new Date()
    return formatDateInput(maxEnd > today ? today : maxEnd)
  })

  const totalPaidAmount = computed(() => {
    return transactions.value
      .filter((item) => item.status !== 'cancelled')
      .reduce((sum, item) => sum + (item.total_amount || 0), 0)
  })

  const totalVoidAmount = computed(() => {
    return voidedOrders.value.reduce((sum, item) => sum + (item.total_amount || 0), 0)
  })

  const isShiftOpen = computed(() => !!shiftState.value?.open_shift)
  const currentShift = computed(() => shiftState.value?.open_shift || null)
  const lastClosedShift = computed(() => shiftState.value?.last_closed_shift || null)
  const showShiftClosedAlert = () => {
    showWarning('Shift kasir belum dibuka. Buka shift untuk melanjutkan.')
  }
  const requireShiftOpen = () => {
    if (isShiftOpen.value) return true
    showShiftClosedAlert()
    return false
  }
  const shiftSalesSummary = computed(() => {
    const summary = currentShift.value?.sales_summary
    if (!summary) {
      return { cash: 0, card: 0, qris: 0, transfer: 0, total: 0 }
    }
    return summary
  })
  const shiftVoidSummary = computed(() => {
    return currentShift.value?.void_summary || { count: 0, total: 0 }
  })
  const shiftCancelledSummary = computed(() => {
    return currentShift.value?.cancelled_summary || { count: 0, total: 0 }
  })
  const shiftNetSalesTotal = computed(() => {
    const summary = shiftSalesSummary.value
    return (summary.cash || 0) + (summary.card || 0) + (summary.qris || 0) + (summary.transfer || 0)
  })
  const lastClosedCashMovements = computed(() => {
    return lastClosedShift.value?.cash_movements || { cash_in: [], cash_out: [], total_in: 0, total_out: 0 }
  })
  const currentCashMovements = computed(() => {
    return currentShift.value?.cash_movements || { cash_in: [], cash_out: [], total_in: 0, total_out: 0 }
  })
  const closeShiftCashInTotal = computed(() => currentCashMovements.value.total_in || 0)
  const closeShiftCashOutTotal = computed(() => currentCashMovements.value.total_out || 0)
  const closeShiftGrandTotal = computed(() => {
    const salesTotal = shiftNetSalesTotal.value || 0
    return salesTotal + closeShiftCashInTotal.value - closeShiftCashOutTotal.value
  })
  const displayCashMovements = computed(() => {
    return isShiftOpen.value ? currentCashMovements.value : lastClosedCashMovements.value
  })
  const cashMovementHistoryData = computed(() => {
    const source = cashMovementHistorySource.value
    return source === 'last' ? lastClosedCashMovements.value : currentCashMovements.value
  })
  const cashMovementHistoryItems = computed(() => {
    return cashMovementHistoryType.value === 'out'
      ? cashMovementHistoryData.value.cash_out || []
      : cashMovementHistoryData.value.cash_in || []
  })
  const cashMovementHistoryTotal = computed(() => {
    return cashMovementHistoryType.value === 'out'
      ? cashMovementHistoryData.value.total_out || 0
      : cashMovementHistoryData.value.total_in || 0
  })
  const currentUserId = computed(() => {
    return authStore.user?.id || currentShift.value?.opened_by || ''
  })
  const currentUserName = computed(() => {
    return authStore.user?.full_name || authStore.user?.username || currentShift.value?.opened_by_name || 'Kasir'
  })
  const cashierOptions = computed(() => {
    const currentId = currentUserId.value
    return (cashierUsers.value || []).map((user) => {
      const isCurrent = user.id === currentId
      return {
        ...user,
        isCurrent,
        label: isCurrent ? `${user.full_name} (Kasir saat ini)` : user.full_name
      }
    })
  })
  const handoverCandidates = computed(() => {
    return cashierOptions.value.filter((user) => !user.isCurrent)
  })
  const selectedHandoverCashierName = computed(() => {
    const selectedId = selectedHandoverCashier.value
    const user = cashierOptions.value.find((item) => item.id === selectedId)
    return user?.full_name || 'Kasir'
  })

  const formatCurrency = (value) => {
    return new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      minimumFractionDigits: 0
    }).format(value || 0)
  }

  const formatReceiptNumber = (value) => {
    return new Intl.NumberFormat('id-ID', {
      minimumFractionDigits: 0
    }).format(value || 0)
  }

  const getReceiptItemPrice = (item) => {
    return Math.round(item?.price || 0)
  }

  const getReceiptItemTotal = (item) => {
    return getReceiptItemPrice(item) * (item?.qty || 0)
  }

  const formatRupiahInput = (value) => {
    const digits = String(value ?? '').replace(/[^\d]/g, '')
    if (!digits) return ''
    const formatted = new Intl.NumberFormat('id-ID').format(Number(digits))
    return `Rp ${formatted}`
  }

  const parseRupiahInput = (value) => {
    const digits = String(value || '').replace(/[^\d]/g, '')
    if (!digits) return 0
    return Number.parseInt(digits, 10)
  }

  const handleOpeningCashInput = (event) => {
    const digits = String(event.target.value ?? '').replace(/[^\d]/g, '')
    if (!digits) {
      openingCash.value = null
      openingCashDisplay.value = ''
      return
    }
    const amount = Number.parseInt(digits, 10)
    openingCash.value = amount
    openingCashDisplay.value = formatRupiahInput(amount)
  }

  const resetCashMovementForm = () => {
    cashMovementType.value = 'in'
    cashMovementName.value = ''
    cashMovementNote.value = ''
    cashMovementAmount.value = 0
    cashMovementAmountDisplay.value = ''
  }

  const openCashMovementModal = (type) => {
    cashMovementType.value = type === 'out' ? 'out' : 'in'
    cashMovementName.value = ''
    cashMovementNote.value = ''
    cashMovementAmount.value = 0
    cashMovementAmountDisplay.value = ''
    showCashMovementModal.value = true
  }

  const closeCashMovementModal = () => {
    showCashMovementModal.value = false
    resetCashMovementForm()
  }

  const openCashMovementHistoryModal = (type, source) => {
    cashMovementHistoryType.value = type === 'out' ? 'out' : 'in'
    cashMovementHistorySource.value = source === 'last' ? 'last' : 'current'
    showCashMovementHistoryModal.value = true
  }

  const closeCashMovementHistoryModal = () => {
    showCashMovementHistoryModal.value = false
  }

  const handleCashMovementAmountInput = (event) => {
    const amount = parseRupiahInput(event.target.value)
    cashMovementAmount.value = amount
    cashMovementAmountDisplay.value = amount ? formatRupiahInput(amount) : ''
  }

  const submitCashMovement = async () => {
    const name = cashMovementName.value.trim()
    const note = cashMovementNote.value.trim()
    const amount = Number(cashMovementAmount.value || 0)
    if (!name) {
      ElMessage.warning('Nama harus diisi')
      return
    }
    if (cashMovementType.value === 'out' && !note) {
      ElMessage.warning('Keterangan harus diisi')
      return
    }
    if (amount <= 0) {
      ElMessage.warning('Nominal harus diisi')
      return
    }
    try {
      cashMovementSubmitting.value = true
      await api.post('/cashier/shifts/movements', {
        type: cashMovementType.value,
        name,
        note,
        amount
      })
      ElMessage.success('Uang masuk/keluar tersimpan')
      showCashMovementModal.value = false
      resetCashMovementForm()
      await fetchShiftState()
    } catch (error) {
      console.error('Failed to save cash movement:', error)
      ElMessage.error(error.response?.data?.message || 'Gagal menyimpan uang masuk/keluar')
    } finally {
      cashMovementSubmitting.value = false
    }
  }

  const handleFullPaidAmountInput = (event) => {
    const amount = parseRupiahInput(event.target.value)
    fullPaidAmount.value = amount
    fullPaidAmountDisplay.value = amount ? formatRupiahInput(amount) : ''
  }

  const setFullExactAmount = () => {
    const amount = remainingAmount.value
    fullPaidAmount.value = amount
    fullPaidAmountDisplay.value = amount ? formatRupiahInput(amount) : ''
  }

  const handleSplitPaidAmountInput = (event) => {
    const amount = parseRupiahInput(event.target.value)
    splitPaidAmount.value = amount
    splitPaidAmountDisplay.value = amount ? formatRupiahInput(amount) : ''
  }

  const setSplitExactAmount = () => {
    const amount = splitItemsTotal.value
    splitPaidAmount.value = amount
    splitPaidAmountDisplay.value = amount ? formatRupiahInput(amount) : ''
  }

  const openDiscountModal = () => {
    if (!requireShiftOpen()) return
    if (!currentOrder.value?.order?.id) {
      ElMessage.error('Order tidak ditemukan')
      return
    }
    discountType.value = 'percentage'
    discountValue.value = 0
    discountValueDisplay.value = ''
    showDiscountModal.value = true
  }

  const closeDiscountModal = () => {
    showDiscountModal.value = false
    discountType.value = 'percentage'
    discountValue.value = 0
    discountValueDisplay.value = ''
  }

  const handleDiscountValueInput = (event) => {
    if (discountType.value === 'fixed') {
      const amount = parseRupiahInput(event.target.value)
      discountValue.value = amount
      discountValueDisplay.value = amount ? formatRupiahInput(amount) : ''
      return
    }
    const digits = String(event.target.value ?? '').replace(/[^\d]/g, '')
    if (!digits) {
      discountValue.value = 0
      discountValueDisplay.value = ''
      return
    }
    const percent = Math.min(Number.parseInt(digits, 10), 100)
    discountValue.value = percent
    discountValueDisplay.value = String(percent)
  }

  const submitDiscount = async () => {
    if (!requireShiftOpen()) return
    if (!currentOrder.value?.order?.id) {
      ElMessage.error('Order tidak ditemukan')
      return
    }
    if (discountValue.value <= 0) {
      ElMessage.warning('Nilai diskon harus lebih dari 0')
      return
    }
    if (discountType.value === 'percentage' && discountValue.value > 100) {
      ElMessage.warning('Diskon maksimum 100%')
      return
    }
    try {
      discountSubmitting.value = true
      const orderId = currentOrder.value.order.id
      await api.post(`/orders/${orderId}/discount`, {
        charge_type: discountType.value,
        value: discountValue.value
      })
      const response = await api.get(`/orders/${orderId}`)
      const data = response.data.data || {}
      currentOrder.value = {
        ...data,
        items: data.items || []
      }
      const remaining = currentOrder.value?.order ? getRemainingAmount(currentOrder.value.order) : 0
      fullPaidAmount.value = remaining
      fullPaidAmountDisplay.value = remaining ? formatRupiahInput(remaining) : ''
      ElMessage.success('Diskon berhasil diterapkan')
      closeDiscountModal()
      await refreshData()
    } catch (error) {
      console.error('Failed to apply discount:', error)
      ElMessage.error(error.response?.data?.message || 'Gagal menerapkan diskon')
    } finally {
      discountSubmitting.value = false
    }
  }

  const submitCompliment = async () => {
    if (!requireShiftOpen()) return
    if (!currentOrder.value?.order?.id) {
      ElMessage.error('Order tidak ditemukan')
      return
    }
    try {
      await ElMessageBox.confirm(
        `Kompliment order meja ${currentOrder.value.order.table_number}?`,
        'Konfirmasi Kompliment',
        {
          confirmButtonText: 'Ya, Kompliment',
          cancelButtonText: 'Batal',
          type: 'warning'
        }
      )
      complimentSubmitting.value = true
      await api.post(`/orders/${currentOrder.value.order.id}/compliment`)
      ElMessage.success('Order berhasil dikompliment')
      showOrderModal.value = false
      currentOrder.value = null
      await refreshData()
    } catch (error) {
      if (error !== 'cancel') {
        console.error('Failed to apply compliment:', error)
        ElMessage.error(error.response?.data?.message || 'Gagal melakukan kompliment')
      }
    } finally {
      complimentSubmitting.value = false
    }
  }

  const formatPinInput = (value) => {
    const digits = String(value || '').replace(/[^\d]/g, '')
    return digits.slice(0, 4)
  }

  const formatTime = (dateString) => {
    if (!dateString) return '-'
    const date = new Date(dateString)
    return date.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })
  }

  const formatDateTime = (dateString) => {
    if (!dateString) return '-'
    const date = new Date(dateString)
    return date.toLocaleString('id-ID', {
      day: '2-digit',
      month: 'short',
      hour: '2-digit',
      minute: '2-digit'
    })
  }

  const formatDateInput = (date) => {
    const target = new Date(date)
    const year = target.getFullYear()
    const month = String(target.getMonth() + 1).padStart(2, '0')
    const day = String(target.getDate()).padStart(2, '0')
    return `${year}-${month}-${day}`
  }

  const addMonths = (date, months) => {
    const next = new Date(date)
    next.setMonth(next.getMonth() + months)
    return next
  }

  const getSplitItemQty = (itemId) => {
    return splitItemSelections.value[itemId] || 0
  }

  const setSplitItemQty = (item, qty) => {
    const maxQty = item.qty || 0
    let nextQty = Number(qty)
    if (!Number.isFinite(nextQty)) {
      nextQty = 0
    }
    nextQty = Math.max(0, Math.min(maxQty, Math.floor(nextQty)))
    const updated = { ...splitItemSelections.value }
    if (nextQty > 0) {
      updated[item.id] = nextQty
    } else {
      delete updated[item.id]
    }
    splitItemSelections.value = updated
  }

  const adjustSplitItemQty = (item, delta) => {
    const currentQty = getSplitItemQty(item.id)
    setSplitItemQty(item, currentQty + delta)
  }

  const handleSplitItemQtyInput = (item, event) => {
    setSplitItemQty(item, event.target.value)
  }

  const openOpenShiftModal = () => {
    const defaultCash = lastClosedShift.value?.carry_over_cash || 0
    openingCash.value = defaultCash
    openingCashDisplay.value = defaultCash ? formatRupiahInput(defaultCash) : ''
    showOpenShiftModal.value = true
  }

  const openCloseShiftModal = () => {
    showCloseShiftModal.value = true
  }

  const openHandoverShiftModal = async () => {
    selectedHandoverCashier.value = ''
    handoverCurrentPin.value = ''
    handoverNextPin.value = ''
    showHandoverPinModal.value = false
    await fetchShiftState()
    if (!currentShift.value) {
      ElMessage.warning('Tidak ada shift kasir yang terbuka')
      return
    }
    await fetchCashierUsers()
    showHandoverShiftModal.value = true
  }

  const openHandoverPinModal = () => {
    if (!selectedHandoverCashier.value) {
      ElMessage.warning('Pilih kasir tujuan')
      return
    }
    handoverCurrentPin.value = ''
    handoverNextPin.value = ''
    showHandoverShiftModal.value = false
    showHandoverPinModal.value = true
  }

  const closeHandoverPinModal = () => {
    showHandoverPinModal.value = false
    showHandoverShiftModal.value = true
    handoverCurrentPin.value = ''
    handoverNextPin.value = ''
  }

  const getPaymentMethodClass = (method) => {
    const classes = {
      cash: 'bg-emerald-100 text-emerald-800',
      card: 'bg-blue-100 text-blue-800',
      qris: 'bg-purple-100 text-purple-800',
      transfer: 'bg-amber-100 text-amber-800'
    }
    return classes[method] || 'bg-slate-100 text-slate-800'
  }

  const getPaymentMethodText = (method) => {
    const texts = {
      cash: 'Tunai',
      card: 'Kartu',
      qris: 'QRIS',
      transfer: 'Transfer'
    }
    return texts[method] || method
  }

  const getTransactionStatusText = (status) => {
    if (status === 'cancelled') return 'BATAL'
    return 'PAID'
  }

  const getTransactionStatusClass = (status) => {
    if (status === 'cancelled') return 'bg-red-100 text-red-700'
    return 'bg-emerald-100 text-emerald-800'
  }

  const getOrderStatusText = (status) => {
    const texts = {
      pending: 'Menunggu',
      cooking: 'Diproses',
      ready: 'Siap',
      served: 'Tersaji',
      cancelled: 'Batal'
    }
    return texts[status] || status || '-'
  }

  const getOrderStatusClass = (status) => {
    const classes = {
      pending: 'bg-amber-100 text-amber-700',
      cooking: 'bg-blue-100 text-blue-700',
      ready: 'bg-emerald-100 text-emerald-700',
      served: 'bg-slate-100 text-slate-600',
      cancelled: 'bg-red-100 text-red-700'
    }
    return classes[status] || 'bg-slate-100 text-slate-600'
  }

  const getPaymentStatusText = (status) => {
    const texts = {
      unpaid: 'Belum Lunas',
      partial: 'Sebagian',
      paid: 'Lunas',
      cancelled: 'Batal'
    }
    return texts[status] || status || '-'
  }

  const getPaymentStatusClass = (status) => {
    const classes = {
      unpaid: 'bg-amber-100 text-amber-700',
      partial: 'bg-blue-100 text-blue-700',
      paid: 'bg-emerald-100 text-emerald-700',
      cancelled: 'bg-red-100 text-red-700'
    }
    return classes[status] || 'bg-slate-100 text-slate-600'
  }

  const getPaymentMethodButtonClass = (method, isSelected) => {
    const base = 'px-4 py-3 rounded-xl border-2 text-sm font-semibold transition-all'
    return `${base} ${
      isSelected
        ? 'border-emerald-500 bg-emerald-50 text-emerald-700'
        : 'border-slate-200 bg-white text-slate-600 hover:border-slate-300'
    }`
  }

  const getPaymentNote = (note) => {
    if (!note) return ''
    if (typeof note === 'string') return note
    if (typeof note === 'object' && typeof note.String === 'string') return note.String
    return ''
  }

  const getOrderTotal = (order) => {
    if (!order) return 0
    if (order.original_total_amount != null) return order.original_total_amount
    if (order.total_amount != null) return order.total_amount
    return 0
  }

  const getRemainingAmount = (order) => {
    if (!order) return 0
    if (order.remaining_amount != null) return Math.max(order.remaining_amount, 0)
    const total = getOrderTotal(order)
    const paid = order.paid_amount || 0
    const remaining = total - paid
    return remaining > 0 ? remaining : 0
  }

  const buildPaginationFallback = (items, paginationState) => {
    const pageSize = paginationState.page_size > 0 ? paginationState.page_size : 1
    const totalItems = items.length
    const totalPages = totalItems === 0 ? 0 : Math.ceil(totalItems / pageSize)
    const safePage = Math.min(paginationState.current_page, totalPages || 1)
    const start = (safePage - 1) * pageSize
    const pagedItems = totalPages > 0 ? items.slice(start, start + pageSize) : []
    return {
      items: pagedItems,
      pagination: {
        ...paginationState,
        current_page: safePage,
        total_items: totalItems,
        total_pages: totalPages
      }
    }
  }

  const fetchOccupiedTables = async () => {
    try {
      const response = await api.get('/tables', { params: { page_size: 1000 } })
      allTables.value = response.data.data || []
    } catch (error) {
      console.error('Failed to fetch occupied tables:', error)
    }
  }

  const fetchTodayStats = async () => {
    try {
      const today = new Date()
      const startDate = formatDateInput(today)
      const response = await api.get('/orders/analytics', {
        params: { start_date: startDate, end_date: startDate }
      })
      
      if (response.data.success) {
        const payload = response.data.data || {}
        const analytics = payload.analytics || payload
        const totalRevenue = analytics.total_revenue || 0
        const voidTotal = analytics.void_total || 0
        const cancelledTotal = analytics.cancelled_total || 0
        todayRevenue.value = totalRevenue - voidTotal - cancelledTotal
        todayTransactions.value = analytics.total_orders || 0
      }
    } catch (error) {
      console.error('Failed to fetch today stats:', error)
    }
  }

  const fetchShiftState = async () => {
    shiftLoading.value = true
    try {
      const response = await api.get('/cashier/shifts/state')
      if (response.data.success) {
        shiftState.value = response.data.data || { open_shift: null, last_closed_shift: null }
      }
    } catch (error) {
      console.error('Failed to fetch shift state:', error)
      ElMessage.error('Gagal memuat data shift kasir')
    } finally {
      shiftLoading.value = false
    }
  }

  const fetchCashierUsers = async () => {
    cashierUsersLoading.value = true
    try {
      const response = await api.get('/cashier/users')
      if (response.data.success) {
        cashierUsers.value = response.data.data || []
      }
    } catch (error) {
      console.error('Failed to fetch cashier users:', error)
      ElMessage.error('Gagal memuat daftar kasir')
    } finally {
      cashierUsersLoading.value = false
    }
  }

  const submitOpenShift = async () => {
    try {
      shiftLoading.value = true
      await api.post('/cashier/shifts/open', {
        opening_cash: openingCash.value == null ? null : Number(openingCash.value)
      })
      ElMessage.success('Shift kasir dibuka')
      showOpenShiftModal.value = false
      await fetchShiftState()
    } catch (error) {
      console.error('Failed to open shift:', error)
      ElMessage.error(error.response?.data?.message || 'Gagal membuka shift kasir')
    } finally {
      shiftLoading.value = false
    }
  }

  const submitCloseShift = async () => {
    try {
      shiftLoading.value = true
      const summary = shiftSalesSummary.value
      await api.post('/cashier/shifts/close', {
        closing_cash: parseFloat(summary.cash || 0),
        closing_card: parseFloat(summary.card || 0),
        closing_qris: parseFloat(summary.qris || 0),
        closing_transfer: parseFloat(summary.transfer || 0)
      })
      ElMessage.success('Shift kasir ditutup')
      showCloseShiftModal.value = false
      await fetchShiftState()
    } catch (error) {
      console.error('Failed to close shift:', error)
      ElMessage.error(error.response?.data?.message || 'Gagal menutup shift kasir')
    } finally {
      shiftLoading.value = false
    }
  }

  const submitHandoverShift = async () => {
    if (!currentShift.value) {
      ElMessage.warning('Tidak ada shift kasir yang terbuka')
      return
    }
    if (!selectedHandoverCashier.value) {
      ElMessage.warning('Pilih kasir tujuan')
      return
    }
    if (selectedHandoverCashier.value === currentUserId.value) {
      ElMessage.warning('Kasir tujuan harus berbeda')
      return
    }
    if (handoverCurrentPin.value.length !== 4 || handoverNextPin.value.length !== 4) {
      ElMessage.warning('PIN harus 4 digit')
      return
    }
    try {
      shiftLoading.value = true
      const summary = shiftSalesSummary.value
      const response = await api.post('/cashier/shifts/handover', {
        next_cashier_id: selectedHandoverCashier.value,
        current_cashier_pin: handoverCurrentPin.value,
        next_cashier_pin: handoverNextPin.value,
        closing_cash: parseFloat(summary.cash || 0),
        closing_card: parseFloat(summary.card || 0),
        closing_qris: parseFloat(summary.qris || 0),
        closing_transfer: parseFloat(summary.transfer || 0)
      })
      const authData = response.data?.data?.auth
      if (authData?.token && authData?.user) {
        authStore.setSession(authData.token, authData.user)
      }
      ElMessage.success('Serah terima kasir berhasil')
      showHandoverShiftModal.value = false
      showHandoverPinModal.value = false
      handoverCurrentPin.value = ''
      handoverNextPin.value = ''
      await fetchShiftState()
    } catch (error) {
      console.error('Failed to handover shift:', error)
      const message = error.response?.data?.message || 'Gagal melakukan serah terima kasir'
      if (error.response?.status === 401) {
        if (message.toLowerCase().includes('kasir saat ini')) {
          handoverCurrentPin.value = ''
        }
        if (message.toLowerCase().includes('kasir tujuan')) {
          handoverNextPin.value = ''
        }
        ElMessage.warning(message)
        return
      }
      ElMessage.error(message)
    } finally {
      shiftLoading.value = false
    }
  }

  const fetchTransactions = async () => {
    loadingHistory.value = true
    try {
      const response = await api.get('/transactions', {
        params: {
          page: transactionPagination.value.current_page,
          page_size: transactionPagination.value.page_size,
          start_date: historyStartDate.value,
          end_date: historyEndDate.value
        }
      })
      const items = response.data.data || []
      if (response.data.pagination) {
        transactions.value = items
        transactionPagination.value = {
          ...transactionPagination.value,
          ...response.data.pagination
        }
      } else {
        const fallback = buildPaginationFallback(items, transactionPagination.value)
        transactions.value = fallback.items
        transactionPagination.value = fallback.pagination
      }
    } catch (error) {
      console.error('Failed to fetch transactions:', error)
      ElMessage.error('Gagal memuat riwayat transaksi')
    } finally {
      loadingHistory.value = false
    }
  }

  const fetchVoidedOrders = async () => {
    loadingVoidedHistory.value = true
    try {
      const response = await api.get('/orders/voided', {
        params: {
          page: voidPagination.value.current_page,
          page_size: voidPagination.value.page_size,
          start_date: historyStartDate.value,
          end_date: historyEndDate.value
        }
      })
      const items = response.data.data || []
      if (response.data.pagination) {
        voidedOrders.value = items
        voidPagination.value = {
          ...voidPagination.value,
          ...response.data.pagination
        }
      } else {
        const fallback = buildPaginationFallback(items, voidPagination.value)
        voidedOrders.value = fallback.items
        voidPagination.value = fallback.pagination
      }
    } catch (error) {
      console.error('Failed to fetch voided orders:', error)
      ElMessage.error('Gagal memuat histori void')
    } finally {
      loadingVoidedHistory.value = false
    }
  }

  const applyHistoryFilter = async () => {
    if (!historyStartDate.value || !historyEndDate.value) {
      ElMessage.warning('Pilih tanggal mulai dan akhir')
      return
    }

    if (historyEndDate.value < historyStartDate.value) {
      ElMessage.warning('Tanggal akhir harus sama atau setelah tanggal mulai')
      return
    }

    const maxEnd = addMonths(new Date(historyStartDate.value), 3)
    const selectedEnd = new Date(historyEndDate.value)
    if (selectedEnd > maxEnd) {
      ElMessage.warning('Rentang tanggal maksimal 3 bulan')
      return
    }

    transactionPagination.value.current_page = 1
    voidPagination.value.current_page = 1
    await Promise.all([fetchTransactions(), fetchVoidedOrders()])
  }

  const resetHistoryFilter = async () => {
    const today = formatDateInput(new Date())
    historyStartDate.value = today
    historyEndDate.value = today
    await applyHistoryFilter()
  }

  const goToTransactionPage = async (page) => {
    transactionPagination.value.current_page = page
    await fetchTransactions()
  }

  const goToVoidPage = async (page) => {
    voidPagination.value.current_page = page
    await fetchVoidedOrders()
  }

  const viewOrder = async (table) => {
    if (!requireShiftOpen()) return
    loadingOrderDetail.value = true
    showOrderModal.value = true
    selectedPaymentMethod.value = 'cash'
    
    try {
      const orderId = table.order_id || table.active_order?.order_id
      if (!orderId) {
        throw new Error('Order tidak ditemukan')
      }
      const response = await api.get(`/orders/${orderId}`)
      const data = response.data.data || {}
      currentOrder.value = {
        ...data,
        items: data.items || []
      }
      const remaining = currentOrder.value?.order ? getRemainingAmount(currentOrder.value.order) : 0
      fullPaidAmount.value = remaining
      fullPaidAmountDisplay.value = remaining ? formatRupiahInput(remaining) : ''
    } catch (error) {
      console.error('Failed to fetch order details:', error)
      ElMessage.error('Gagal memuat detail order')
      showOrderModal.value = false
    } finally {
      loadingOrderDetail.value = false
    }
  }

  const getItemStatusText = (status) => {
    const map = {
      pending: 'Pending',
      cooking: 'Diproses',
      ready: 'Siap',
      served: 'Disajikan'
    }
    return map[status] || status
  }

  const itemStatusClass = (status) => {
    const classes = {
      pending: 'bg-amber-100 text-amber-700',
      cooking: 'bg-blue-100 text-blue-700',
      ready: 'bg-emerald-100 text-emerald-700',
      served: 'bg-slate-100 text-slate-600'
    }
    return classes[status] || 'bg-slate-100 text-slate-600'
  }

  const canEditItem = (item) => item.item_status === 'pending'

  const isItemUpdating = (itemId) => !!itemUpdateLoading.value[itemId]

  const fetchItemsModalData = async (orderId) => {
    const response = await api.get(`/orders/${orderId}`)
    const data = response.data.data || {}
    itemsModalOrder.value = data.order || null
    itemsModalItems.value = data.items || []
  }

  const openItemsModal = async (table) => {
    if (!requireShiftOpen()) return
    loadingItemsModal.value = true
    showItemsModal.value = true
    itemsModalOrder.value = null
    itemsModalItems.value = []

    try {
      const orderId = table.order_id || table.active_order?.order_id
      if (!orderId) {
        throw new Error('Order tidak ditemukan')
      }
      await fetchItemsModalData(orderId)
    } catch (error) {
      console.error('Failed to fetch order items:', error)
      ElMessage.error('Gagal memuat item order')
      showItemsModal.value = false
    } finally {
      loadingItemsModal.value = false
    }
  }

  const adjustItemQty = async (item, delta) => {
    if (!requireShiftOpen()) return
    if (!itemsModalOrder.value?.id) return
    if (!canEditItem(item)) {
      ElMessage.warning('Item sudah diproses kitchen')
      return
    }

    const nextQty = item.qty + delta
    if (nextQty < 0 || nextQty === item.qty) return

    if (nextQty === 0) {
      try {
        await ElMessageBox.confirm(
          `Hapus ${item.product_name} dari pesanan?`,
          'Konfirmasi Hapus Item',
          {
            confirmButtonText: 'Ya, Hapus',
            cancelButtonText: 'Batal',
            type: 'warning'
          }
        )
      } catch {
        return
      }
    }

    itemUpdateLoading.value = { ...itemUpdateLoading.value, [item.id]: true }
    try {
      await api.put(`/orders/items/${item.id}/qty`, { qty: nextQty })
      await fetchItemsModalData(itemsModalOrder.value.id)
      await fetchOccupiedTables()
    } catch (error) {
      console.error('Failed to update item qty:', error)
      ElMessage.error(error.response?.data?.message || 'Gagal mengubah jumlah item')
    } finally {
      itemUpdateLoading.value = { ...itemUpdateLoading.value, [item.id]: false }
    }
  }

  const processPayment = async (orderId, amount) => {
    if (!requireShiftOpen()) return
    if (!selectedPaymentMethod.value) {
      ElMessage.warning('Pilih metode pembayaran terlebih dahulu')
      return
    }

    try {
      if (!amount || amount <= 0) {
        ElMessage.warning('Tagihan sudah lunas')
        return
      }
      const paidAmount = fullPaidAmount.value > 0 ? fullPaidAmount.value : amount
      if (paidAmount < amount) {
        ElMessage.warning('Jumlah bayar kurang dari total tagihan')
        return
      }
      await ElMessageBox.confirm(
        `Proses pembayaran ${formatCurrency(amount)} dengan ${getPaymentMethodText(selectedPaymentMethod.value)}?`,
        'Konfirmasi Pembayaran',
        {
          confirmButtonText: 'Ya, Proses',
          cancelButtonText: 'Batal',
          type: 'warning'
        }
      )

      processingPayment.value = true

      await api.post(`/orders/${orderId}/payment`, {
        payment_method: selectedPaymentMethod.value,
        paid_amount: paidAmount
      })

      ElMessage.success('Pembayaran berhasil diproses')
      showOrderModal.value = false
      currentOrder.value = null
      await refreshData()
    } catch (error) {
      if (error !== 'cancel') {
        console.error('Payment failed:', error)
        ElMessage.error(error.response?.data?.message || 'Gagal memproses pembayaran')
      }
    } finally {
      processingPayment.value = false
    }
  }

  const printBill = async () => {
    if (!requireShiftOpen()) return
    if (!currentOrder.value?.order?.id) {
      ElMessage.error('Order tidak ditemukan')
      return
    }

    const tableNumber = currentOrder.value?.order?.table_number || '-'
    try {
      await ElMessageBox.confirm(
        `Cetak bill untuk meja ${tableNumber}?`,
        'Konfirmasi Cetak Bill',
        {
          confirmButtonText: 'Ya, Cetak',
          cancelButtonText: 'Batal',
          type: 'warning'
        }
      )

      printingBill.value = true
      await api.post(`/print/bill/${currentOrder.value.order.id}`)
      ElMessage.success('Bill berhasil dikirim ke printer')
    } catch (error) {
      if (error !== 'cancel') {
        console.error('Print bill failed:', error)
        ElMessage.error(error.response?.data?.message || 'Gagal cetak bill')
      }
    } finally {
      printingBill.value = false
    }
  }

  const processSplitPayment = async () => {
    if (!requireShiftOpen()) return
    if (!selectedSplitPaymentMethod.value) {
      ElMessage.warning('Pilih metode pembayaran terlebih dahulu')
      return
    }

    if (!splitItemsTotal.value || splitItemsTotal.value <= 0) {
      ElMessage.warning('Pilih item yang akan dibayar')
      return
    }

    const remaining = getRemainingAmount(currentOrder.value.order)
    if (splitItemsTotal.value > remaining) {
      ElMessage.warning('Jumlah pembayaran melebihi sisa tagihan')
      return
    }

    const splitAmount = splitItemsTotal.value
    const paidAmount = splitPaidAmount.value > 0 ? splitPaidAmount.value : splitAmount
    if (paidAmount < splitAmount) {
      ElMessage.warning('Jumlah bayar kurang dari total split')
      return
    }

    try {
      processingPayment.value = true
      const orderId = currentOrder.value?.order?.id
      if (!orderId) {
        ElMessage.error('Order tidak ditemukan')
        processingPayment.value = false
        return
      }

      await api.post(`/orders/${orderId}/split-payment`, {
        items: splitSelectedItems.value.map((item) => ({
          item_id: item.id,
          qty: item.splitQty
        })),
        amount: splitAmount,
        payment_method: selectedSplitPaymentMethod.value,
        note: splitNote.value,
        paid_amount: paidAmount
      })

      ElMessage.success('Pembayaran sebagian berhasil diproses')
      showSplitPaymentModal.value = false
      showOrderModal.value = false
      splitNote.value = ''
      splitItemSelections.value = {}
      currentOrder.value = null
      await refreshData()
    } catch (error) {
      console.error('Split payment failed:', error)
      ElMessage.error(error.response?.data?.message || 'Gagal memproses pembayaran')
    } finally {
      processingPayment.value = false
    }
  }

  const openVoidModal = () => {
    if (!requireShiftOpen()) return
    if (!currentOrder.value?.order?.id) {
      ElMessage.error('Order tidak ditemukan')
      return
    }
    voidPin.value = ''
    voidReason.value = ''
    showVoidModal.value = true
  }

  const openSplitPaymentModal = () => {
    if (!requireShiftOpen()) return
    showSplitPaymentModal.value = true
  }

  const closeVoidModal = () => {
    showVoidModal.value = false
    voidPin.value = ''
    voidReason.value = ''
  }

  const handleVoidPinInput = (event) => {
    const value = event?.target?.value ?? voidPin.value
    voidPin.value = formatPinInput(value)
  }

  const submitVoidOrder = async () => {
    if (!requireShiftOpen()) return
    if (!currentOrder.value?.order?.id) {
      ElMessage.error('Order tidak ditemukan')
      return
    }

    if (voidPin.value.length !== 4) {
      ElMessage.warning('PIN harus 4 digit')
      return
    }

    try {
      await ElMessageBox.confirm(
        `Void order ${currentOrder.value.order.table_number}?`,
        'Konfirmasi Void Order',
        {
          confirmButtonText: 'Ya, Void',
          cancelButtonText: 'Batal',
          type: 'warning'
        }
      )
    } catch {
      return
    }

    try {
      voidProcessing.value = true
      await api.post(`/orders/${currentOrder.value.order.id}/void`, {
        manager_pin: voidPin.value,
        reason: voidReason.value
      })
      ElMessage.success('Order berhasil di-void')
      closeVoidModal()
      showOrderModal.value = false
      currentOrder.value = null
      await refreshData()
    } catch (error) {
      console.error('Void order failed:', error)
      ElMessage.error(error.response?.data?.message || 'Gagal void order')
    } finally {
      voidProcessing.value = false
    }
  }

  const openCancelTransactionModal = (transaction) => {
    if (!requireShiftOpen()) return
    if (!transaction?.id) {
      ElMessage.error('Transaksi tidak ditemukan')
      return
    }
    selectedTransaction.value = transaction
    cancelPin.value = ''
    cancelReason.value = ''
    showCancelTransactionModal.value = true
  }

  const closeCancelTransactionModal = () => {
    showCancelTransactionModal.value = false
    selectedTransaction.value = null
    cancelPin.value = ''
    cancelReason.value = ''
  }

  const handleCancelPinInput = (event) => {
    const value = event?.target?.value ?? cancelPin.value
    cancelPin.value = formatPinInput(value)
  }

  const openReceiptDetail = async (transaction) => {
    if (!transaction?.id) {
      ElMessage.error('Transaksi tidak ditemukan')
      return
    }
    receiptTransaction.value = transaction
    receiptOrder.value = null
    receiptLoading.value = true
    showReceiptModal.value = true
    const orderId = transaction.order_id || transaction.id
    try {
      const [orderResponse, outletResponse] = await Promise.all([
        api.get(`/orders/${orderId}`),
        api.get('/config/outlet').catch(() => null)
      ])
      const data = orderResponse.data.data || {}
      receiptOrder.value = {
        ...data,
        items: data.items || [],
        payments: data.payments || []
      }
      if (outletResponse?.data?.data) {
        outletConfig.value = {
          outlet_name: outletResponse.data.data.outlet_name || outletConfig.value.outlet_name,
          outlet_address: outletResponse.data.data.outlet_address || '',
          outlet_phone: outletResponse.data.data.outlet_phone || '',
          receipt_footer: outletResponse.data.data.receipt_footer ?? outletConfig.value.receipt_footer,
          social_media: outletResponse.data.data.social_media || ''
        }
      }
    } catch (error) {
      console.error('Failed to fetch receipt detail:', error)
      ElMessage.error('Gagal memuat detail struk')
      showReceiptModal.value = false
    } finally {
      receiptLoading.value = false
    }
  }

  const closeReceiptModal = () => {
    showReceiptModal.value = false
    receiptTransaction.value = null
    receiptOrder.value = null
  }

  const handleReprintReceipt = async () => {
    if (!receiptTransaction.value) return
    const orderId = receiptTransaction.value.order_id || receiptTransaction.value.id
    try {
      receiptPrinting.value = true
      await api.post(`/print/reprint/${orderId}`)
      ElMessage.success('Struk dimasukkan ke antrean cetak')
    } catch (error) {
      console.error('Failed to reprint receipt:', error)
      ElMessage.error(error.response?.data?.message || 'Gagal mencetak ulang struk')
    } finally {
      receiptPrinting.value = false
    }
  }

  const handleHandoverCurrentPinInput = (event) => {
    const value = event?.target?.value ?? handoverCurrentPin.value
    handoverCurrentPin.value = formatPinInput(value)
  }

  const handleHandoverNextPinInput = (event) => {
    const value = event?.target?.value ?? handoverNextPin.value
    handoverNextPin.value = formatPinInput(value)
  }

  const submitCancelTransaction = async () => {
    if (!requireShiftOpen()) return
    if (!selectedTransaction.value?.id) {
      ElMessage.error('Transaksi tidak ditemukan')
      return
    }
    if (cancelPin.value.length !== 4) {
      ElMessage.warning('PIN harus 4 digit')
      return
    }

    try {
      const orderNumber = selectedTransaction.value.order_id || selectedTransaction.value.id
      const totalAmount = selectedTransaction.value.total_amount || 0
      await ElMessageBox.confirm(
        `Batalkan transaksi nomor ${orderNumber} dengan nominal ${formatCurrency(totalAmount)}?`,
        'Konfirmasi Pembatalan',
        {
          confirmButtonText: 'Ya, Batalkan',
          cancelButtonText: 'Batal',
          type: 'warning'
        }
      )
    } catch {
      return
    }

    try {
      cancelProcessing.value = true
      await api.post(`/transactions/${selectedTransaction.value.id}/cancel`, {
        manager_pin: cancelPin.value,
        reason: cancelReason.value
      })
      ElMessage.success('Transaksi berhasil dibatalkan')
      closeCancelTransactionModal()
      await fetchTransactions()
    } catch (error) {
      console.error('Cancel transaction failed:', error)
      ElMessage.error(error.response?.data?.message || 'Gagal membatalkan transaksi')
    } finally {
      cancelProcessing.value = false
    }
  }

  const refreshData = async () => {
    loading.value = true
    try {
      await Promise.all([
        fetchOccupiedTables(),
        fetchTodayStats(),
        fetchShiftState(),
        activeTab.value === 'history'
          ? applyHistoryFilter()
          : Promise.resolve()
      ])
    } finally {
      loading.value = false
    }
  }

  let realtimeUnsubscribe = null

  const handleRealtimeEvent = async (event) => {
    if (!event?.type) return
    if (
      event.type === 'order_created' ||
      event.type === 'order_items_updated' ||
      event.type === 'item_status_updated' ||
      event.type === 'payment_completed' ||
      event.type === 'order_voided' ||
      event.type === 'table_status_updated'
    ) {
      await refreshData()
      if (showOrderModal.value && currentOrder.value?.order?.id) {
        const response = await api.get(`/orders/${currentOrder.value.order.id}`)
        const data = response.data.data || {}
        currentOrder.value = {
          ...data,
          items: data.items || []
        }
      }
    }
  }

  onMounted(async () => {
    const today = formatDateInput(new Date())
    historyStartDate.value = today
    historyEndDate.value = today
    await refreshData()
    realtimeUnsubscribe = subscribeRealtime(handleRealtimeEvent)
  })

  onUnmounted(() => {
    if (realtimeUnsubscribe) realtimeUnsubscribe()
  })

  watch(activeTab, (newTab) => {
    if (newTab === 'history') {
      applyHistoryFilter()
    }
  })

  watch(showSplitPaymentModal, (isOpen) => {
    if (isOpen) {
      splitItemSelections.value = {}
      splitNote.value = ''
      splitPaidAmount.value = 0
      splitPaidAmountDisplay.value = ''
    }
  })

  watch(currentOrder, () => {
    if (showSplitPaymentModal.value) {
      splitItemSelections.value = {}
    }
  })

  watch(splitItemsTotal, (total) => {
    if (!showSplitPaymentModal.value) return
    if (splitPaidAmount.value < total) {
      splitPaidAmount.value = total
      splitPaidAmountDisplay.value = total ? formatRupiahInput(total) : ''
    }
  })

  return {
    loading,
    loadingHistory,
    loadingVoidedHistory,
    loadingOrderDetail,
    processingPayment,
    printingBill,
    activeTab,
    allTables,
    transactions,
    voidedOrders,
    currentOrder,
    todayRevenue,
    todayTransactions,
    tableSearchQuery,
    historyStartDate,
    historyEndDate,
    transactionPagination,
    voidPagination,
    shiftState,
    shiftLoading,
    cashierUsers,
    cashierUsersLoading,
    showOrderModal,
    showSplitPaymentModal,
    showVoidModal,
    showCancelTransactionModal,
    showReceiptModal,
    showItemsModal,
    loadingItemsModal,
    itemsModalOrder,
    itemsModalItems,
    itemUpdateLoading,
    showDiscountModal,
    discountType,
    discountValue,
    discountValueDisplay,
    discountSubmitting,
    complimentSubmitting,
    showOpenShiftModal,
    showCloseShiftModal,
    showHandoverShiftModal,
    showHandoverPinModal,
    selectedPaymentMethod,
    selectedSplitPaymentMethod,
    splitNote,
    splitItemSelections,
    fullPaidAmount,
    fullPaidAmountDisplay,
    splitPaidAmount,
    splitPaidAmountDisplay,
    voidPin,
    voidReason,
    voidProcessing,
    selectedTransaction,
    cancelPin,
    cancelReason,
    cancelProcessing,
    receiptLoading,
    receiptPrinting,
    receiptTransaction,
    receiptOrder,
    outletConfig,
    openingCash,
    openingCashDisplay,
    selectedHandoverCashier,
    handoverCurrentPin,
    handoverNextPin,
    showCashMovementModal,
    cashMovementType,
    cashMovementName,
    cashMovementNote,
    cashMovementAmount,
    cashMovementAmountDisplay,
    cashMovementSubmitting,
    showCashMovementHistoryModal,
    cashMovementHistoryType,
    cashMovementHistorySource,
    paymentMethods,
    transactionColumns,
    voidColumns,
    avgTransaction,
    pendingTables,
    filteredPendingTables,
    orderItems,
    manualAdjustments,
    splitSelectedItems,
    splitItemsTotal,
    splitTotalExceedsRemaining,
    remainingAmount,
    fullChangeAmount,
    splitChangeAmount,
    splitPayments,
    receiptItems,
    receiptPayments,
    receiptAdditionalCharges,
    receiptSubtotal,
    receiptTotal,
    receiptPaidAmount,
    receiptChangeAmount,
    historyLoading,
    historyStartMax,
    historyEndMax,
    totalPaidAmount,
    totalVoidAmount,
    isShiftOpen,
    currentShift,
    lastClosedShift,
    shiftSalesSummary,
    shiftVoidSummary,
    shiftCancelledSummary,
    shiftNetSalesTotal,
    lastClosedCashMovements,
    currentCashMovements,
    closeShiftCashInTotal,
    closeShiftCashOutTotal,
    closeShiftGrandTotal,
    displayCashMovements,
    cashMovementHistoryData,
    cashMovementHistoryItems,
    cashMovementHistoryTotal,
    currentUserId,
    currentUserName,
    cashierOptions,
    handoverCandidates,
    selectedHandoverCashierName,
    showShiftClosedAlert,
    requireShiftOpen,
    formatCurrency,
    formatReceiptNumber,
    formatRupiahInput,
    parseRupiahInput,
    getReceiptItemPrice,
    getReceiptItemTotal,
    handleOpeningCashInput,
    resetCashMovementForm,
    openCashMovementModal,
    closeCashMovementModal,
    openCashMovementHistoryModal,
    closeCashMovementHistoryModal,
    handleCashMovementAmountInput,
    submitCashMovement,
    handleFullPaidAmountInput,
    setFullExactAmount,
    handleSplitPaidAmountInput,
    setSplitExactAmount,
    openDiscountModal,
    closeDiscountModal,
    handleDiscountValueInput,
    submitDiscount,
    submitCompliment,
    formatPinInput,
    formatTime,
    formatDateTime,
    formatDateInput,
    addMonths,
    getSplitItemQty,
    setSplitItemQty,
    adjustSplitItemQty,
    handleSplitItemQtyInput,
    openOpenShiftModal,
    openCloseShiftModal,
    openHandoverShiftModal,
    openHandoverPinModal,
    closeHandoverPinModal,
    getPaymentMethodClass,
    getPaymentMethodText,
    getTransactionStatusText,
    getTransactionStatusClass,
    getOrderStatusText,
    getOrderStatusClass,
    getPaymentStatusText,
    getPaymentStatusClass,
    getPaymentMethodButtonClass,
    getPaymentNote,
    getOrderTotal,
    getRemainingAmount,
    buildPaginationFallback,
    fetchOccupiedTables,
    fetchTodayStats,
    fetchShiftState,
    fetchCashierUsers,
    submitOpenShift,
    submitCloseShift,
    submitHandoverShift,
    fetchTransactions,
    fetchVoidedOrders,
    applyHistoryFilter,
    resetHistoryFilter,
    goToTransactionPage,
    goToVoidPage,
    viewOrder,
    getItemStatusText,
    itemStatusClass,
    canEditItem,
    isItemUpdating,
    fetchItemsModalData,
    openItemsModal,
    adjustItemQty,
    processPayment,
    printBill,
    processSplitPayment,
    openVoidModal,
    openSplitPaymentModal,
    closeVoidModal,
    handleVoidPinInput,
    submitVoidOrder,
    openCancelTransactionModal,
    closeCancelTransactionModal,
    handleCancelPinInput,
    openReceiptDetail,
    closeReceiptModal,
    handleReprintReceipt,
    handleHandoverCurrentPinInput,
    handleHandoverNextPinInput,
    submitCancelTransaction,
    refreshData
  }
}
