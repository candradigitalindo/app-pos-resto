import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/login',
      name: 'Login',
      component: () => import('../views/LoginViewNew.vue'),
      meta: { requiresAuth: false }
    },
    {
      path: '/',
      name: 'Dashboard',
      component: () => import('../views/DashboardViewNew.vue'),
      meta: { requiresAuth: true, roles: ['admin', 'manager'] }
    },
    {
      path: '/cashier',
      name: 'Cashier',
      component: () => import('../views/CashierView.vue'),
      meta: { requiresAuth: true, roles: ['admin', 'cashier'] }
    },
    {
      path: '/waiter',
      name: 'Waiter',
      component: () => import('../views/WaiterView.vue'),
      meta: { requiresAuth: true, roles: ['admin', 'waiter'] }
    },
    {
      path: '/kitchen',
      name: 'Kitchen',
      component: () => import('../views/KitchenView.vue'),
      meta: { requiresAuth: true, roles: ['admin', 'kitchen', 'bar'] }
    },
    {
      path: '/settings',
      name: 'Settings',
      component: () => import('../views/SettingsViewNew.vue'),
      meta: { requiresAuth: true, roles: ['admin', 'manager'] }
    },
    {
      path: '/products',
      name: 'Products',
      component: () => import('../views/ProductView.vue'),
      meta: { requiresAuth: true, roles: ['admin', 'manager'] }
    },
    {
      path: '/tables',
      name: 'Tables',
      component: () => import('../views/TableManagementView.vue'),
      meta: { requiresAuth: true, roles: ['admin', 'manager'] }
    },
    {
      path: '/users',
      name: 'Users',
      component: () => import('../views/UsersView.vue'),
      meta: { requiresAuth: true, roles: ['admin', 'manager'] }
    }
  ]
})

// Navigation guard
const resolveDefaultRoute = (role) => {
  const mapping = {
    admin: '/',
    manager: '/',
    waiter: '/waiter',
    cashier: '/cashier',
    kitchen: '/kitchen',
    bar: '/kitchen'
  }
  return mapping[role] || '/'
}

router.beforeEach(async (to, from, next) => {
  const authStore = useAuthStore()
  
  if (to.meta.requiresAuth && !authStore.isAuthenticated) {
    next('/login')
  } else if (to.path === '/login' && authStore.isAuthenticated) {
    next(resolveDefaultRoute(authStore.user?.role))
  } else {
    if (to.meta.roles?.length) {
      if (!authStore.user && authStore.token) {
        await authStore.fetchProfile()
      }
      const role = authStore.user?.role
      if (!role || !to.meta.roles.includes(role)) {
        next(resolveDefaultRoute(role))
        return
      }
    }
    next()
  }
})

export default router
