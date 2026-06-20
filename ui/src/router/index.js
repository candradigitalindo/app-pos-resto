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
const ProcurementDashboard = () => import('@/pages/outlet/ProcurementDashboard.vue')
const ProductsAdmin       = () => import('@/pages/Products.vue')
const SalesReport         = () => import('@/pages/SalesReport.vue')
const ProductSalesReport  = () => import('@/pages/ProductSalesReport.vue')
const TaxReport           = () => import('@/pages/TaxReport.vue')
const CashFlowReport      = () => import('@/pages/CashFlowReport.vue')
const BalanceReport       = () => import('@/pages/BalanceReport.vue')
const ProfitLossReport    = () => import('@/pages/ProfitLossReport.vue')
const GeneralLedger       = () => import('@/pages/GeneralLedger.vue')
const VoidReport          = () => import('@/pages/VoidReport.vue')
const PurchaseGoods       = () => import('@/pages/PurchaseGoods.vue')
const PurchaseServices    = () => import('@/pages/PurchaseServices.vue')
const ProcurementDashboardPage = () => import('@/pages/ProcurementDashboard.vue')
const ProcurementPayments     = () => import('@/pages/ProcurementPayments.vue')
const WorkUnits           = () => import('@/pages/WorkUnits.vue')
const Vendors             = () => import('@/pages/Vendors.vue')
const VendorDetail        = () => import('@/pages/VendorDetail.vue')
const Admins              = () => import('@/pages/Admins.vue')
const Roles          = () => import('@/pages/Roles.vue')
const AccessLogs     = () => import('@/pages/AccessLogs.vue')
const BankAccounts    = () => import('@/pages/BankAccounts.vue')
const ManagerDashboard = () => import('@/pages/ManagerDashboard.vue')
const CompanyIdentity     = () => import('@/pages/CompanyIdentity.vue')
const TimezoneSettings    = () => import('@/pages/TimezoneSettings.vue')
const TaxSettings         = () => import('@/pages/TaxSettings.vue')
const Warehouses          = () => import('@/pages/Warehouses.vue')
const WarehouseDashboard  = () => import('@/pages/WarehouseDashboard.vue')
const StockItems          = () => import('@/pages/StockItems.vue')
const StockWastes         = () => import('@/pages/StockWastes.vue')
const StockTransfers      = () => import('@/pages/StockTransfers.vue')
const StockLedger         = () => import('@/pages/StockLedger.vue')
const Recipes             = () => import('@/pages/Recipes.vue')
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
        component: ManagerDashboard,
        meta: { title: 'Dashboard — Cloud POS', requiresAuth: true },
      },
      // Alias lama → arahkan ke dashboard utama
      { path: 'manager-dashboard', redirect: '/' },
      {
        path: 'outlets',
        name: 'Outlets',
        component: Outlets,
        meta: { title: 'Outlets — Cloud POS', requiresAuth: true, permission: 'outlets.view' },
      },
      {
        path: 'outlets/:id',
        component: OutletDetail,
        meta: { title: 'Detail Outlet — Cloud POS', requiresAuth: true, permission: 'outlets.view' },
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
          {
            path: 'procurement',
            name: 'ProcurementDashboard',
            component: ProcurementDashboard,
            meta: { title: 'Pengadaan — Cloud POS', requiresAuth: true, permission: 'procurement.dashboard.view' },
          },
        ],
      },
      {
        path: 'admins',
        name: 'Admins',
        component: Admins,
        meta: { title: 'User — Cloud POS', requiresAuth: true, permission: 'users.view' },
      },
      {
        path: 'roles',
        name: 'Roles',
        component: Roles,
        meta: { title: 'Role — Cloud POS', requiresAuth: true, permission: 'roles.view' },
      },
      {
        path: 'access-logs',
        name: 'AccessLogs',
        component: AccessLogs,
        meta: { title: 'Log Akses — Cloud POS', requiresAuth: true, permission: 'access_logs.view' },
      },
      {
        path: 'products',
        name: 'ProductsAdmin',
        component: ProductsAdmin,
        meta: { title: 'Produk & Kategori — Cloud POS', requiresAuth: true, permission: 'products.view' },
      },
      {
        path: 'sales-report',
        name: 'SalesReport',
        component: SalesReport,
        meta: { title: 'Laporan Pendapatan — Cloud POS', requiresAuth: true, permission: 'reports.sales.view' },
      },
      {
        path: 'product-sales-report',
        name: 'ProductSalesReport',
        component: ProductSalesReport,
        meta: { title: 'Penjualan Produk — Cloud POS', requiresAuth: true, permission: 'reports.product_sales.view' },
      },
      {
        path: 'tax-report',
        name: 'TaxReport',
        component: TaxReport,
        meta: { title: 'Laporan Pajak — Cloud POS', requiresAuth: true, permission: 'reports.tax.view' },
      },
      {
        path: 'cash-flow-report',
        name: 'CashFlowReport',
        component: CashFlowReport,
        meta: { title: 'Pemasukan & Pengeluaran — Cloud POS', requiresAuth: true, permission: 'reports.cashflow.view' },
      },
      {
        path: 'balance-report',
        name: 'BalanceReport',
        component: BalanceReport,
        meta: { title: 'Laporan Neraca — Cloud POS', requiresAuth: true, permission: 'reports.balance.view' },
      },
      {
        path: 'profit-loss-report',
        name: 'ProfitLossReport',
        component: ProfitLossReport,
        meta: { title: 'Profit & Loss — Cloud POS', requiresAuth: true, permission: 'reports.pnl.view' },
      },
      {
        path: 'general-ledger',
        name: 'GeneralLedger',
        component: GeneralLedger,
        meta: { title: 'Buku Besar — Cloud POS', requiresAuth: true, permission: 'reports.ledger.view' },
      },
      {
        path: 'void-report',
        name: 'VoidReport',
        component: VoidReport,
        meta: { title: 'Laporan Void — Cloud POS', requiresAuth: true, permission: 'reports.void.view' },
      },
      {
        path: 'procurement-payments',
        name: 'ProcurementPayments',
        component: ProcurementPayments,
        meta: { title: 'Pembayaran — Cloud POS', requiresAuth: true, permission: 'finance.payments.view' },
      },
      {
        path: 'bank-accounts',
        name: 'BankAccounts',
        component: BankAccounts,
        meta: { title: 'Rekening — Cloud POS', requiresAuth: true, permission: 'finance.bank.view' },
      },
      {
        path: 'procurement-dashboard',
        name: 'ProcurementDashboardPage',
        component: ProcurementDashboardPage,
        meta: { title: 'Dashboard Pengadaan — Cloud POS', requiresAuth: true, permission: 'procurement.dashboard.view' },
      },
      {
        path: 'purchase-goods',
        name: 'PurchaseGoods',
        component: PurchaseGoods,
        meta: { title: 'Pengadaan Barang — Cloud POS', requiresAuth: true, permission: 'procurement.requests.view' },
      },
      {
        path: 'purchase-services',
        name: 'PurchaseServices',
        component: PurchaseServices,
        meta: { title: 'Pengadaan Jasa — Cloud POS', requiresAuth: true, permission: 'procurement.requests.view' },
      },
      {
        path: 'work-units',
        name: 'WorkUnits',
        component: WorkUnits,
        meta: { title: 'Unit Kerja — Cloud POS', requiresAuth: true, permission: 'workunits.view' },
      },
      {
        path: 'vendors',
        name: 'Vendors',
        component: Vendors,
        meta: { title: 'Vendor — Cloud POS', requiresAuth: true, permission: 'vendors.view' },
      },
      {
        path: 'vendors/:id',
        name: 'VendorDetail',
        component: VendorDetail,
        meta: { title: 'Detail Vendor — Cloud POS', requiresAuth: true, permission: 'vendors.view' },
      },
      {
        path: 'settings/company',
        name: 'CompanyIdentity',
        component: CompanyIdentity,
        meta: { title: 'Identitas Perusahaan — Cloud POS', requiresAuth: true, permission: 'settings.company.view' },
      },
      {
        path: 'settings/timezone',
        name: 'TimezoneSettings',
        component: TimezoneSettings,
        meta: { title: 'Zona Waktu — Cloud POS', requiresAuth: true, permission: 'settings.timezone.view' },
      },
      {
        path: 'settings/tax',
        name: 'TaxSettings',
        component: TaxSettings,
        meta: { title: 'Pengaturan Pajak — Cloud POS', requiresAuth: true, permission: 'settings.tax.view' },
      },
      // ── Warehouse / Gudang ──────────────────────────────
      {
        path: 'warehouse-dashboard',
        name: 'WarehouseDashboard',
        component: WarehouseDashboard,
        meta: { title: 'Dashboard Gudang — Cloud POS', requiresAuth: true, permission: 'warehouse_dashboard.view' },
      },
      {
        path: 'warehouses',
        name: 'Warehouses',
        component: Warehouses,
        meta: { title: 'Gudang — Cloud POS', requiresAuth: true, permission: 'warehouses.view' },
      },
      {
        path: 'stock-items',
        name: 'StockItems',
        component: StockItems,
        meta: { title: 'Item Stok — Cloud POS', requiresAuth: true, permission: 'stockitems.view' },
      },
      {
        path: 'stock-transfers',
        name: 'StockTransfers',
        component: StockTransfers,
        meta: { title: 'Transfer Stok — Cloud POS', requiresAuth: true, permission: 'stocktransfers.view' },
      },
      {
        path: 'stock-wastes',
        name: 'StockWastes',
        component: StockWastes,
        meta: { title: 'Stok Rusak/Hilang — Cloud POS', requiresAuth: true, permission: 'stockwastes.view' },
      },
      {
        path: 'stock-ledger',
        name: 'StockLedger',
        component: StockLedger,
        meta: { title: 'Buku Stok — Cloud POS', requiresAuth: true, permission: 'stockledger.view' },
      },
      {
        path: 'recipes',
        name: 'Recipes',
        component: Recipes,
        meta: { title: 'Resep — Cloud POS', requiresAuth: true, permission: 'recipes.view' },
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
router.beforeEach(async (to) => {
  // Update page title
  if (to.meta.title) {
    document.title = to.meta.title
  }

  const auth = useAuthStore()

  // Redirect to role's default page if already logged in
  if (to.name === 'Login' && auth.isAuthenticated) {
    return auth.redirectTo || '/'
  }

  // Redirect to login if route requires auth but user is not authenticated.
  // (Login always returns to the role's default page, so no redirect query needed.)
  if (to.meta.requiresAuth && !auth.isAuthenticated) {
    return { name: 'Login' }
  }

  // Always refresh permissions from API on first navigation after page load
  if (auth.isAuthenticated && !auth.permsSynced) {
    await auth.fetchPermissions()
  }

  // Superadmin-only routes
  if (to.meta.superadmin && auth.isAuthenticated && !auth.isSuperadmin) {
    return { name: 'Dashboard' }
  }

  // Check permission-based access
  if (to.meta.permission && auth.isAuthenticated && !auth.hasPermission(to.meta.permission)) {
    return { name: 'Dashboard' }
  }
})

export default router
