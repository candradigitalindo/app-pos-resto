/**
 * Currency formatting utilities for Indonesian Rupiah
 */

const formatter = new Intl.NumberFormat('id-ID', {
  style: 'currency',
  currency: 'IDR',
  minimumFractionDigits: 0,
  maximumFractionDigits: 0
})

const numberFormatter = new Intl.NumberFormat('id-ID', {
  minimumFractionDigits: 0,
  maximumFractionDigits: 0
})

/**
 * Format number as Indonesian Rupiah (Rp 10.000)
 * @param {number} amount
 * @returns {string}
 */
export function formatRupiah(amount) {
  if (amount == null || isNaN(amount)) return 'Rp 0'
  return formatter.format(amount)
}

/**
 * Format number with Indonesian thousand separator (10.000)
 * @param {number} amount
 * @returns {string}
 */
export function formatNumber(amount) {
  if (amount == null || isNaN(amount)) return '0'
  return numberFormatter.format(amount)
}

/**
 * Format currency shorthand — alias for formatRupiah
 */
export const formatCurrency = formatRupiah
