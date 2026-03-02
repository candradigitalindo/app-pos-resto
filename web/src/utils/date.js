/**
 * Date/time formatting utilities
 */

/**
 * Format ISO date string to Indonesian locale datetime
 * @param {string} dateStr - ISO date string
 * @param {object} options - Intl.DateTimeFormat options
 * @returns {string}
 */
export function formatDateTime(dateStr, options = {}) {
  if (!dateStr) return '-'
  try {
    const date = new Date(dateStr)
    if (isNaN(date.getTime())) return '-'
    return new Intl.DateTimeFormat('id-ID', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      ...options
    }).format(date)
  } catch {
    return '-'
  }
}

/**
 * Format ISO date string to date only
 * @param {string} dateStr
 * @returns {string}
 */
export function formatDate(dateStr) {
  return formatDateTime(dateStr, {
    hour: undefined,
    minute: undefined
  })
}

/**
 * Format ISO date string to time only (HH:mm)
 * @param {string} dateStr
 * @returns {string}
 */
export function formatTime(dateStr) {
  return formatDateTime(dateStr, {
    day: undefined,
    month: undefined,
    year: undefined
  })
}

/**
 * Get relative time string (e.g., "5 menit lalu")
 * @param {string} dateStr
 * @returns {string}
 */
export function timeAgo(dateStr) {
  if (!dateStr) return '-'
  const now = new Date()
  const date = new Date(dateStr)
  const diffMs = now - date
  const diffMin = Math.floor(diffMs / 60000)

  if (diffMin < 1) return 'Baru saja'
  if (diffMin < 60) return `${diffMin} menit lalu`

  const diffHours = Math.floor(diffMin / 60)
  if (diffHours < 24) return `${diffHours} jam lalu`

  const diffDays = Math.floor(diffHours / 24)
  if (diffDays < 7) return `${diffDays} hari lalu`

  return formatDate(dateStr)
}
