/**
 * Shared status text and class helpers for orders, payments, and item statuses.
 * Used across CashierView, WaiterView, KitchenView, etc.
 */

/**
 * Get human-readable order status text
 * @param {string} status
 * @returns {string}
 */
export function getOrderStatusText(status) {
  const map = {
    pending: 'Menunggu',
    confirmed: 'Dikonfirmasi',
    preparing: 'Diproses',
    cooking: 'Diproses',
    ready: 'Siap',
    served: 'Disajikan',
    completed: 'Selesai',
    cancelled: 'Dibatalkan',
    voided: 'Void'
  }
  return map[status] || status || '-'
}

/**
 * Get human-readable payment method text
 * @param {string} method
 * @returns {string}
 */
export function getPaymentMethodText(method) {
  const map = {
    cash: 'Tunai',
    debit: 'Debit',
    credit: 'Kartu Kredit',
    qris: 'QRIS',
    transfer: 'Transfer',
    ewallet: 'E-Wallet',
    compliment: 'Compliment'
  }
  return map[method] || method || '-'
}

/**
 * Get human-readable payment status text
 * @param {string} status
 * @returns {string}
 */
export function getPaymentStatusText(status) {
  const map = {
    unpaid: 'Belum Bayar',
    paid: 'Lunas',
    partial: 'Sebagian',
    refunded: 'Refund',
    compliment: 'Compliment'
  }
  return map[status] || status || '-'
}

/**
 * Get human-readable item status text
 * @param {string} status
 * @returns {string}
 */
export function getItemStatusText(status) {
  const map = {
    pending: 'Antrian',
    preparing: 'Diproses',
    cooking: 'Diproses',
    ready: 'Siap',
    served: 'Disajikan',
    cancelled: 'Batal'
  }
  return map[status] || status || '-'
}

/**
 * Get Tailwind CSS classes for order status badge
 * @param {string} status
 * @returns {string}
 */
export function orderStatusClass(status) {
  const map = {
    pending: 'bg-amber-50 text-amber-700 ring-1 ring-amber-200',
    confirmed: 'bg-blue-50 text-blue-700 ring-1 ring-blue-200',
    preparing: 'bg-orange-50 text-orange-700 ring-1 ring-orange-200',
    cooking: 'bg-blue-50 text-blue-700 ring-1 ring-blue-200',
    ready: 'bg-emerald-50 text-emerald-700 ring-1 ring-emerald-200',
    served: 'bg-teal-50 text-teal-700 ring-1 ring-teal-200',
    completed: 'bg-green-50 text-green-700 ring-1 ring-green-200',
    cancelled: 'bg-red-50 text-red-700 ring-1 ring-red-200',
    voided: 'bg-slate-100 text-slate-500 ring-1 ring-slate-200'
  }
  return map[status] || 'bg-slate-50 text-slate-600 ring-1 ring-slate-200'
}

/**
 * Get Tailwind CSS classes for item status badge
 * @param {string} status
 * @returns {string}
 */
export function itemStatusClass(status) {
  const map = {
    pending: 'bg-amber-50 text-amber-700',
    preparing: 'bg-orange-50 text-orange-700',
    cooking: 'bg-blue-50 text-blue-700',
    ready: 'bg-emerald-50 text-emerald-700',
    served: 'bg-teal-50 text-teal-700',
    cancelled: 'bg-red-50 text-red-700'
  }
  return map[status] || 'bg-slate-50 text-slate-600'
}

/**
 * Get Tailwind CSS classes for destination badge (kitchen/bar)
 * @param {string} dest
 * @returns {string}
 */
export function destinationClass(dest) {
  const map = {
    kitchen: 'bg-orange-50 text-orange-700 ring-1 ring-orange-200',
    bar: 'bg-purple-50 text-purple-700 ring-1 ring-purple-200'
  }
  return map[dest] || 'bg-slate-50 text-slate-600 ring-1 ring-slate-200'
}
