/**
 * src/router/index.js — Client-side routing
 *
 * Route structure:
 *   /login                       → Login page (public)
 *   /                            → DashboardLayout wrapper
 *     /dashboard                 → Overview stats
 *     /outlets                   → Outlet list
 *     /outlets/:id               → Outlet detail (orders, txn, products, etc.)
 *     /outlets/:id/transactions  → Outlet transactions
 *     /outlets/:id/orders        → Outlet orders
 *     /outlets/:id/products      → Outlet products
 *     /outlets/:id/categories    → Outlet categories
 *     /outlets/:id/printers      → Outlet printers
 *     /outlets/:id/sync-logs     → Outlet sync logs
 *     /outlets/:id/conflicts     → Outlet conflicts
 *     /admins                    → Admin user management
 *
 * Navigation guard:
 *   - Routes with `meta.requiresAuth: true` redirect to /login if no token.
 *   - /login redirects to /dashboard if already authenticated.
 *
 * AI NOTE: To add a new protected page:
 *   1. Create the .vue file in src/pages/
 *   2. Add the route object below with `meta: { requiresAuth: true }`
 *   3. Add a nav link in src/layouts/DashboardLayout.vue
 */

import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth.js'

// ── Lazy-loaded page components ─────────────────────────────
// Each import() creates a separate JS chunk → better initial load time
const Login          = () => import('@/pages/Login.vue')
const Dashboard      = () => import('@/pages/Dashboard.vue')
const Outlets        = () => import('@/pages/Outlets.vue')
const OutletDetail   = () => import('@/pages/OutletDetail.vue')
const Transactions   = () => import('@/pages/outlet/Transactions.vue')
const Orders         = () => import('@/pages/outlet/Orders.vue')
const Products       = () => import('@/pages/outlet/Products.vue')
const Categories     = () => import('@/pages/outlet/Categories.vue')
const Printers       = () => import('@/pages/outlet/Printers.vue')
const SyncLogs       = () => import('@/pages/outlet/SyncLogs.vue')
const Conflicts      = () => import('@/pages/outlet/Conflicts.vue')
const OutletInfo     = () => import('@/pages/outlet/OutletInfo.vue')
const ProductsAdmin  = () => import('@/pages/Products.vue')
const Admins         = () => import('@/pages/Admins.vue')
const DashboardLayout = () => import('@/layouts/DashboardLayout.vue')
const AuthLayout     = () => import('@/layouts/AuthLayout.vue')

// ── Route definitions ────────────────────────────────────────
const routes = [
  // ── Auth layout (no sidebar) ────────────────────────────
  {
    path: '/login',
    component: AuthLayout,
    children: [
      {
        path: '',
        name: 'Login',
        component: Login,
        meta: { title: 'Login — Cloud POS' },
      },
    ],
  },

  // ── Admin layout (with sidebar) ─────────────────────────
  {
    path: '/',
    component: DashboardLayout,
    meta: { requiresAuth: true },
    children: [
      {
        path: '',
        name: 'Dashboard',
        component: Dashboard,
        meta: { title: 'Dashboard — Cloud POS', requiresAuth: true },
      },
      {
        path: 'outlets',
        name: 'Outlets',
        component: Outlets,
        meta: { title: 'Outlets — Cloud POS', requiresAuth: true },
      },
      {
        path: 'outlets/:id',
        component: OutletDetail,
        meta: { title: 'Detail Outlet — Cloud POS', requiresAuth: true },
        // Outlet sub-pages are CHILDREN so OutletDetail's <RouterView> renders them.
        children: [
          { path: '',             redirect: 'info' },
          {
            path: 'info',
            name: 'OutletInfo',
            component: OutletInfo,
            meta: { title: 'Info Outlet — Cloud POS', requiresAuth: true },
          },
          {
            path: 'transactions',
            name: 'Transactions',
            component: Transactions,
            meta: { title: 'Transaksi — Cloud POS', requiresAuth: true },
          },
          {
            path: 'orders',
            name: 'Orders',
            component: Orders,
            meta: { title: 'Pesanan — Cloud POS', requiresAuth: true },
          },
          {
            path: 'products',
            name: 'Products',
            component: Products,
            meta: { title: 'Produk — Cloud POS', requiresAuth: true },
          },
          {
            path: 'categories',
            name: 'Categories',
            component: Categories,
            meta: { title: 'Kategori — Cloud POS', requiresAuth: true },
          },
          {
            path: 'printers',
            name: 'Printers',
            component: Printers,
            meta: { title: 'Printer — Cloud POS', requiresAuth: true },
          },
          {
            path: 'sync-logs',
            name: 'SyncLogs',
            component: SyncLogs,
            meta: { title: 'Sync Logs — Cloud POS', requiresAuth: true },
          },
          {
            path: 'conflicts',
            name: 'Conflicts',
            component: Conflicts,
            meta: { title: 'Konflik Sync — Cloud POS', requiresAuth: true },
          },
        ],
      },
      {
        path: 'admins',
        name: 'Admins',
        component: Admins,
        meta: { title: 'Admin Users — Cloud POS', requiresAuth: true },
      },
      {
        path: 'products',
        name: 'ProductsAdmin',
        component: ProductsAdmin,
        meta: { title: 'Produk & Kategori — Cloud POS', requiresAuth: true },
      },
    ],
  },

  // ── 404 fallback ─────────────────────────────────────────
  {
    path: '/:pathMatch(.*)*',
    redirect: '/dashboard',
  },
]

// ── Router instance ──────────────────────────────────────────
const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior: () => ({ top: 0 }), // always scroll to top on navigation
})

// ── Navigation guards ────────────────────────────────────────
router.beforeEach((to) => {
  // Update page title
  if (to.meta.title) {
    document.title = to.meta.title
  }

  const auth = useAuthStore()

  // Redirect to dashboard if already logged in
  if (to.name === 'Login' && auth.isAuthenticated) {
    return { name: 'Dashboard' }
  }

  // Redirect to login if route requires auth but user is not authenticated
  if (to.meta.requiresAuth && !auth.isAuthenticated) {
    return { name: 'Login', query: { redirect: to.fullPath } }
  }
})

export default router
