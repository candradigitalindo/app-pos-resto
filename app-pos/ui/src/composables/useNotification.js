import { ref } from 'vue'

const notification = ref(null)
const confirmCallback = ref(null)

export function useNotification() {
  const showNotification = (message, type = 'success', duration = 2500) => {
    notification.value = {
      message,
      type,
      show: true,
      isConfirm: false
    }

    if (duration > 0) {
      setTimeout(() => {
        notification.value = null
      }, duration)
    }
  }

  const hideNotification = () => {
    notification.value = null
    confirmCallback.value = null
  }

  const confirm = (message, onConfirm) => {
    notification.value = {
      message,
      type: 'confirm',
      show: true,
      isConfirm: true
    }
    confirmCallback.value = onConfirm
  }

  const handleConfirm = () => {
    if (confirmCallback.value) {
      confirmCallback.value()
    }
    hideNotification()
  }

  const handleCancel = () => {
    hideNotification()
  }

  const success = (message, duration = 2500) => {
    showNotification(message, 'success', duration)
  }

  const created = (message, duration = 2500) => {
    showNotification(message, 'created', duration)
  }

  const updated = (message, duration = 2500) => {
    showNotification(message, 'updated', duration)
  }

  const deleted = (message, duration = 2500) => {
    showNotification(message, 'deleted', duration)
  }

  const error = (message, duration = 3000) => {
    showNotification(message, 'error', duration)
  }

  const warning = (message, duration = 2500) => {
    showNotification(message, 'warning', duration)
  }

  return {
    notification,
    showNotification,
    hideNotification,
    confirm,
    handleConfirm,
    handleCancel,
    success,
    created,
    updated,
    deleted,
    error,
    warning
  }
}
