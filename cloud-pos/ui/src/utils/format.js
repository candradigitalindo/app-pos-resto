/**
 * src/utils/format.js — Display formatting helpers
 *
 * All functions are pure (no side effects) and return strings.
 *
 * AI NOTE: To add a new format function, simply export a new function here.
 * All components import from this module — changes propagate everywhere.
 */

/**
 * Format a number as Indonesian Rupiah currency.
 * @param {number|string} value
 * @returns {string}  e.g. "Rp 1.500.000"
 */
export function formatRupiah(value) {
  const num = Number(value) || 0
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(num)
}

/**
 * Format an ISO date string or Date to a human-readable local datetime.
 * @param {string|Date} value
 * @returns {string}  e.g. "04 Mar 2026, 14:30"
 */
export function formatDateTime(value) {
  if (!value) return '—'
  return new Intl.DateTimeFormat('id-ID', {
    year: 'numeric',
    month: 'short',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value))
}

/**
 * Format an ISO date string to date only.
 * @param {string|Date} value
 * @returns {string}  e.g. "04 Mar 2026"
 */
export function formatDate(value) {
  if (!value) return '—'
  return new Intl.DateTimeFormat('id-ID', {
    year: 'numeric',
    month: 'short',
    day: '2-digit',
  }).format(new Date(value))
}

/**
 * Truncate a string to `max` characters and append "…" if needed.
 * @param {string} str
 * @param {number} max
 * @returns {string}
 */
export function truncate(str, max = 40) {
  if (!str) return ''
  return str.length <= max ? str : str.slice(0, max) + '…'
}

/**
 * Capitalise the first letter of each word.
 * @param {string} str
 * @returns {string}
 */
export function titleCase(str) {
  if (!str) return ''
  return str.replace(/\b\w/g, c => c.toUpperCase())
}

/**
 * Return a short relative time string.
 * @param {string|Date} value
 * @returns {string}  e.g. "3 menit lalu"
 */
export function timeAgo(value) {
  if (!value) return '—'
  const diff = (Date.now() - new Date(value).getTime()) / 1000
  if (diff < 60)   return 'baru saja'
  if (diff < 3600) return `${Math.floor(diff / 60)} menit lalu`
  if (diff < 86400) return `${Math.floor(diff / 3600)} jam lalu`
  return `${Math.floor(diff / 86400)} hari lalu`
}
