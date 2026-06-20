import { apiClient } from './client.js'

export const salesApi = {
  getReport: (params) =>
    apiClient.get('/admin/sales-report', { params }),

  getProductSalesReport: (params) =>
    apiClient.get('/admin/product-sales-report', { params }),

  getTaxReport: (params) =>
    apiClient.get('/admin/tax-report', { params }),

  getCashFlowReport: (params) =>
    apiClient.get('/admin/cash-flow-report', { params }),

  getBalanceReport: (params) =>
    apiClient.get('/admin/balance-report', { params }),

  getProfitLossReport: (params) =>
    apiClient.get('/admin/profit-loss-report', { params }),

  getGeneralLedger: (params) =>
    apiClient.get('/admin/general-ledger', { params }),
}
