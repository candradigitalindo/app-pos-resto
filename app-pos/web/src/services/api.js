import axios from 'axios'
import io from 'socket.io-client'

const api = axios.create({
  baseURL: '/api/v1',
  headers: {
    'Content-Type': 'application/json'
  },
  timeout: 15000
})

const realtimeChannel = typeof BroadcastChannel !== 'undefined' ? new BroadcastChannel('pos-realtime') : null
let socketInstance = null
let socketToken = null

const realtimeEvents = [
  'order_created',
  'order_items_updated',
  'orders_merged',
  'item_status_updated',
  'payment_completed',
  'table_status_updated'
]

const getSocketUrl = () => {
  if (import.meta?.env?.DEV && window.location.port === '5173') {
    return `${window.location.protocol}//${window.location.hostname}:8080`
  }
  return window.location.origin
}

const getSocket = () => {
  const token = localStorage.getItem('token')
  if (!socketInstance) {
    socketInstance = io(getSocketUrl(), {
      path: '/socket.io/',
      transports: ['websocket', 'polling'],
      query: { token }
    })
    socketToken = token
    return socketInstance
  }

  if (token !== socketToken) {
    socketToken = token
    if (socketInstance.io?.opts) {
      socketInstance.io.opts.query = { token }
    }
    if (socketInstance.connected) {
      socketInstance.disconnect()
      socketInstance.connect()
    }
  }

  return socketInstance
}

const subscribeRealtime = (handler) => {
  const cleanup = []

  if (realtimeChannel) {
    const listener = (event) => handler(event?.data)
    realtimeChannel.addEventListener('message', listener)
    cleanup.push(() => realtimeChannel.removeEventListener('message', listener))
  }

  const socket = getSocket()
  realtimeEvents.forEach((eventName) => {
    const listener = (payload) => handler({ type: eventName, ...payload })
    socket.on(eventName, listener)
    cleanup.push(() => socket.off(eventName, listener))
  })

  return () => cleanup.forEach((fn) => fn())
}

// Request interceptor untuk menambahkan token
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token')
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  (error) => {
    return Promise.reject(error)
  }
)

// Response interceptor untuk handle errors
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      const isLoginRequest = error.config?.url?.includes('/auth/login')
      const isHandoverRequest = error.config?.url?.includes('/cashier/shifts/handover')
      if (!isLoginRequest && !isHandoverRequest) {
        localStorage.removeItem('token')
        window.location.href = '/login'
      }
    }
    return Promise.reject(error)
  }
)

export { subscribeRealtime }
export default api
