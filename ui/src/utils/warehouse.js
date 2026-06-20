export function formatWarehouseOptionLabel(warehouse) {
  if (!warehouse) return ''

  const name = warehouse.name ?? warehouse.warehouse_name ?? ''
  const type = warehouse.type ?? warehouse.warehouse_type ?? ''
  const outletName = warehouse.outlet_name ?? warehouse.outletName ?? ''
  const code = warehouse.code ?? warehouse.warehouse_code ?? ''

  if (type === 'central') {
    return name ? `${name} · Gudang Induk${code ? ` · ${code}` : ''}` : 'Gudang Induk'
  }

  if (outletName) {
    return `${name} · Outlet ${outletName}${code ? ` · ${code}` : ''}`
  }

  return name ? `${name} · Gudang Outlet${code ? ` · ${code}` : ''}` : 'Gudang Outlet'
}

export function describeWarehouse(warehouse) {
  if (!warehouse) return 'Pilih gudang untuk melihat konteks outlet dan tipenya.'

  const type = warehouse.type ?? warehouse.warehouse_type ?? ''
  const code = warehouse.code ?? warehouse.warehouse_code ?? ''
  const outletName = warehouse.outlet_name ?? warehouse.outletName ?? ''

  if (type === 'central') {
    return `Tipe: Gudang Induk${code ? ` · Kode: ${code}` : ''}`
  }

  const outletInfo = outletName ? `Outlet: ${outletName}` : 'Gudang outlet tanpa outlet terkait'
  return `Tipe: Gudang Outlet · ${outletInfo}${code ? ` · Kode: ${code}` : ''}`
}