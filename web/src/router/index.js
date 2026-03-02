import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = createRouter({
  history: createWebHistory(),
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) {
      return savedPosition
    }
    return { top: 0 }
  },
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
    },
    {
      path: '/:pathMatch(.*)*',
      name: 'NotFound',
      redirect: '/'
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

  // Not authenticated -> go to login
  if (to.meta.requiresAuth && !authStore.isAuthenticated) {
    return next('/login')
  }

  // Already logged in -> redirect away from login
  if (to.path === '/login' && authStore.isAuthenticated) {
    return next(resolveDefaultRoute(authStore.user?.role))
  }

  // Role-based access control
  if (to.meta.roles?.length) {
    // Ensure user profile is loaded
    if (!authStore.user && authStore.token) {
      try {
        await authStore.fetchProfile()
      } catch {
        // Profile fetch failed -> force re-login
        authStore.logout()
        return next('/login')
      }
    }

    const role = authStore.user?.role
    if (!role) {
      // No role available -> force re-login
      authStore.logout()
      return next('/login')
    }

    if (!to.meta.roles.includes(role)) {
      // Prevent redirect loop: only redirect if target differs from current
      const defaultPath = resolveDefaultRoute(role)
      if (defaultPath !== to.path) {
        return next(defaultPath)
      }
    }
  }

  next()
})

export default router
