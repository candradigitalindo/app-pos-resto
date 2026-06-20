/**
 * src/utils/constants.js — Application-wide constants
 *
 * Centralise all magic strings, enums, and config values here.
 * Importing from this file prevents typos in comparisons.
 *
 * AI NOTE: To add a new status type or role, add it to the relevant object.
 * The badge colours in BaseTable.vue / StatusBadge.vue use these values.
 */

// ── Order / transaction statuses ─────────────────────────────
export const ORDER_STATUS = {
  PENDING:   'pending',
  COOKING:   'cooking',
  READY:     'ready',
  SERVED:    'served',
  PAID:      'paid',
  CANCELLED: 'cancelled',
  VOIDED:    'voided',
}

// ── Payment methods ──────────────────────────────────────────
export const PAYMENT_METHOD = {
  CASH:     'cash',
  CARD:     'card',
  QRIS:     'qris',
  TRANSFER: 'transfer',
}

// ── Sync status ───────────────────────────────────────────────
export const SYNC_STATUS = {
  SUCCESS: 'success',
  FAILED:  'failed',
  PARTIAL: 'partial',
}

// ── Conflict resolution strategies ───────────────────────────
export const CONFLICT_STRATEGY = {
  CLOUD_WINS:   'cloud_wins',
  LOCAL_WINS:   'local_wins',
  NEWEST_WINS:  'newest_wins',
}

// ── Printer types ─────────────────────────────────────────────
export const PRINTER_TYPE = {
  KITCHEN:  'kitchen',
  BAR:      'bar',
  CASHIER:  'cashier',
  CHECKER:  'checker',
  STRUK:    'struk',
}

// ── Admin roles ───────────────────────────────────────────────
export const ADMIN_ROLE = {
  ADMIN:   'admin',
  MANAGER: 'manager',
}

// ── Pagination defaults ───────────────────────────────────────
export const PAGE_SIZE = 20

// ── Status → Tailwind colour mapping (used by StatusBadge component) ─
/** @type {Record<string, {bg:string, text:string}>} */
export const STATUS_COLORS = {
  // Sync statuses
  success:   { bg: 'bg-green-100',  text: 'text-green-800'  },
  failed:    { bg: 'bg-red-100',    text: 'text-red-800'    },
  partial:   { bg: 'bg-yellow-100', text: 'text-yellow-800' },
  // Order statuses
  pending:   { bg: 'bg-gray-100',   text: 'text-gray-700'   },
  cooking:   { bg: 'bg-orange-100', text: 'text-orange-800' },
  ready:     { bg: 'bg-blue-100',   text: 'text-blue-800'   },
  served:    { bg: 'bg-indigo-100', text: 'text-indigo-800' },
  paid:      { bg: 'bg-green-100',  text: 'text-green-800'  },
  cancelled: { bg: 'bg-red-100',    text: 'text-red-800'    },
  voided:    { bg: 'bg-red-100',    text: 'text-red-800'    },
  // General
  open:      { bg: 'bg-green-100',  text: 'text-green-800'  },
  closed:    { bg: 'bg-gray-100',   text: 'text-gray-700'   },
  active:    { bg: 'bg-green-100',  text: 'text-green-800'  },
  inactive:  { bg: 'bg-gray-100',   text: 'text-gray-700'   },
}
