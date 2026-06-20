/**
 * src/stores/toast.js — Global notification (toast) store
 *
 * Usage:
 *   const toast = useToastStore()
 *   toast.success('Data saved')
 *   toast.error('Something went wrong')
 *   toast.info('New sync detected')
 *
 * Toasts auto-dismiss after `duration` ms.
 *
 * AI NOTE: To add a persistent toast (no auto-dismiss), pass duration: 0.
 * To add more severity types, add a new helper function below.
 */

import { defineStore } from 'pinia'
import { ref } from 'vue'

let _nextId = 0

export const useToastStore = defineStore('toast', () => {
  /** @type {import('vue').Ref<Array<{id:number,type:string,message:string}>>} */
  const toasts = ref([])

  /**
   * Add a toast notification.
   * @param {'success'|'error'|'warning'|'info'} type
   * @param {string} message
   * @param {number} duration  — ms before auto-dismiss (default 4000, 0 = never)
   */
  function add(type, message, duration = 4000) {
    const id = ++_nextId
    toasts.value.push({ id, type, message })
    if (duration > 0) {
      setTimeout(() => dismiss(id), duration)
    }
    return id
  }

  /** Remove a specific toast by id */
  function dismiss(id) {
    const idx = toasts.value.findIndex(t => t.id === id)
    if (idx !== -1) toasts.value.splice(idx, 1)
  }

  // ── Convenience helpers ──────────────────────────────────
  const success = (msg, dur)  => add('success', msg, dur)
  const error   = (msg, dur)  => add('error',   msg, dur)
  const warning = (msg, dur)  => add('warning',  msg, dur)
  const info    = (msg, dur)  => add('info',     msg, dur)

  return { toasts, add, dismiss, success, error, warning, info }
})
