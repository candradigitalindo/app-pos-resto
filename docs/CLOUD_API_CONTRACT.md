# Cloud API Contract
# Format data yang dikirim/diterima dengan cloud server

## 📤 Push Data ke Cloud (Local → Cloud)

### 1. Push Order
**Endpoint:** `POST /api/v1/outlets/{outlet_id}/orders`

**Request:**
```json
{
  "local_id": "ORD-20260127-001",
  "outlet_id": "550e8400-e29b-41d4-a716-446655440000",
  "outlet_code": "JKT-001",
  "table_number": "A-05",
  "customer_name": "John Doe",
  "pax": 4,
  "total_amount": 150000,
  "status": "paid",
  "items": [
    {
      "product_name": "Nasi Goreng",
      "category": "Food",
      "qty": 2,
      "price": 35000,
      "subtotal": 70000,
      "destination": "kitchen",
      "status": "served"
    }
  ],
  "payment_info": {
    "method": "cash",
    "amount": 150000,
    "paid_at": "2026-01-27T10:30:00Z"
  },
  "version": 1,
  "created_at": "2026-01-27T10:00:00Z",
  "updated_at": "2026-01-27T10:30:00Z"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "cloud_id": "cloud-order-uuid",
    "local_id": "ORD-20260127-001",
    "version": 1,
    "synced_at": "2026-01-27T10:31:00Z"
  }
}
```

### 2. Push Transaction
**Endpoint:** `POST /api/v1/outlets/{outlet_id}/transactions`

**Request:**
```json
{
  "local_id": "tx-123",
  "outlet_id": "550e8400-e29b-41d4-a716-446655440000",
  "outlet_code": "JKT-001",
  "order_id": "ORD-20260127-001",
  "total_amount": 150000,
  "payment_method": "cash",
  "cash_amount": 200000,
  "change_amount": 50000,
  "cashier_name": "Admin User",
  "version": 1,
  "created_at": "2026-01-27T10:30:00Z"
}
```

### 3. Push Product Update
**Endpoint:** `POST /api/v1/outlets/{outlet_id}/products`

**Request:**
```json
{
  "local_id": "prod-123",
  "outlet_id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Nasi Goreng",
  "category_id": "cat-1",
  "category_name": "Food",
  "price": 35000,
  "stock": 50,
  "destination": "kitchen",
  "version": 2,
  "updated_at": "2026-01-27T10:00:00Z"
}
```

### 4. Batch Push (Multiple Entities)
**Endpoint:** `POST /api/v1/outlets/{outlet_id}/sync/batch`

**Request:**
```json
{
  "outlet_id": "550e8400-e29b-41d4-a716-446655440000",
  "outlet_code": "JKT-001",
  "sync_timestamp": "2026-01-27T10:35:00Z",
  "items": [
    {
      "entity_type": "order",
      "operation": "create",
      "data": { /* order data */ }
    },
    {
      "entity_type": "transaction",
      "operation": "create",
      "data": { /* transaction data */ }
    },
    {
      "entity_type": "product",
      "operation": "update",
      "data": { /* product data */ }
    }
  ]
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "processed": 15,
    "success": 14,
    "failed": 1,
    "results": [
      {
        "entity_type": "order",
        "local_id": "ORD-001",
        "cloud_id": "cloud-uuid-1",
        "status": "success"
      },
      {
        "entity_type": "product",
        "local_id": "prod-123",
        "status": "failed",
        "error": "Product already exists with different data"
      }
    ],
    "synced_at": "2026-01-27T10:35:05Z"
  }
}
```

## 📥 Pull Data dari Cloud (Cloud → Local)

### 1. Get Updates Since
**Endpoint:** `GET /api/v1/outlets/{outlet_id}/updates?since=2026-01-27T10:00:00Z`

**Response:**
```json
{
  "success": true,
  "data": {
    "products": [
      {
        "cloud_id": "cloud-prod-1",
        "local_id": "prod-123",
        "name": "Nasi Goreng Special",
        "price": 40000,
        "version": 3,
        "updated_at": "2026-01-27T11:00:00Z",
        "action": "update"
      }
    ],
    "categories": [
      {
        "cloud_id": "cloud-cat-1",
        "name": "Beverages",
        "version": 1,
        "updated_at": "2026-01-27T11:05:00Z",
        "action": "create"
      }
    ],
    "deleted": [
      {
        "entity_type": "product",
        "local_id": "prod-456",
        "cloud_id": "cloud-prod-456",
        "deleted_at": "2026-01-27T11:10:00Z"
      }
    ],
    "sync_checkpoint": "2026-01-27T11:15:00Z"
  }
}
```

### 2. Webhook: Cloud Push Update
**Endpoint di POS:** `POST /api/v1/webhooks/cloud/update`

**Headers:**
```
X-Cloud-Signature: hmac-sha256-signature
X-Outlet-ID: 550e8400-e29b-41d4-a716-446655440000
Content-Type: application/json
```

**Request:**
```json
{
  "event": "entity.updated",
  "timestamp": "2026-01-27T11:20:00Z",
  "entity_type": "product",
  "cloud_id": "cloud-prod-1",
  "local_id": "prod-123",
  "data": {
    "name": "Nasi Goreng Special",
    "price": 40000,
    "stock": 100,
    "version": 3
  },
  "version": 3,
  "updated_by": "central-system",
  "reason": "Price adjustment from headquarters"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Update applied successfully",
  "local_version": 3,
  "applied_at": "2026-01-27T11:20:05Z"
}
```

### 3. Conflict Notification
**Endpoint di POS:** `POST /api/v1/webhooks/cloud/conflict`

**Request:**
```json
{
  "event": "sync.conflict",
  "timestamp": "2026-01-27T11:25:00Z",
  "entity_type": "product",
  "cloud_id": "cloud-prod-1",
  "local_id": "prod-123",
  "conflict": {
    "field": "price",
    "cloud_value": 40000,
    "cloud_version": 4,
    "cloud_updated_at": "2026-01-27T11:20:00Z",
    "local_value": 38000,
    "local_version": 3,
    "local_updated_at": "2026-01-27T11:22:00Z"
  },
  "resolution_required": true
}
```

## 🔄 Conflict Resolution

### Auto Resolution Request
**Endpoint:** `POST /api/v1/outlets/{outlet_id}/conflicts/{conflict_id}/resolve`

**Request:**
```json
{
  "strategy": "cloud_wins",  // atau "local_wins", "newest_wins"
  "resolved_by": "admin-user",
  "notes": "Using cloud price as standard"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "resolved": true,
    "applied_value": 40000,
    "new_version": 4,
    "resolved_at": "2026-01-27T11:30:00Z"
  }
}
```

## 📊 Analytics & Reporting

### Push Daily Summary
**Endpoint:** `POST /api/v1/outlets/{outlet_id}/analytics/daily`

**Request:**
```json
{
  "outlet_id": "550e8400-e29b-41d4-a716-446655440000",
  "outlet_code": "JKT-001",
  "date": "2026-01-27",
  "summary": {
    "total_orders": 145,
    "total_revenue": 12500000,
    "total_transactions": 145,
    "payment_methods": {
      "cash": 85,
      "qris": 45,
      "card": 15
    },
    "top_products": [
      {
        "product_name": "Nasi Goreng",
        "qty_sold": 67,
        "revenue": 2345000
      }
    ],
    "hourly_breakdown": [
      { "hour": 10, "orders": 15, "revenue": 850000 },
      { "hour": 12, "orders": 45, "revenue": 3200000 }
    ]
  }
}
```

## 🔐 Authentication

Semua request ke cloud harus include:

**Headers:**
```
Authorization: Bearer {api_key}
X-Outlet-ID: {outlet_id}
X-Outlet-Code: {outlet_code}
Content-Type: application/json
```

## ⚡ Rate Limiting

Cloud API akan limit:
- 100 requests per minute per outlet
- 1000 batch items per request
- Max payload size: 10MB

**Rate Limit Response:**
```json
{
  "success": false,
  "error": "rate_limit_exceeded",
  "message": "Too many requests",
  "retry_after": 60
}
```

## 🔔 Webhooks yang Perlu Disiapkan di POS

1. `/api/v1/webhooks/cloud/update` - Terima update entity
2. `/api/v1/webhooks/cloud/delete` - Terima delete entity
3. `/api/v1/webhooks/cloud/conflict` - Notifikasi conflict
4. `/api/v1/webhooks/cloud/broadcast` - Broadcast message ke semua outlet
5. `/api/v1/webhooks/cloud/config` - Update konfigurasi outlet

## 🎯 Priority Data yang Perlu Di-sync

### High Priority (Real-time):
- Orders
- Transactions
- Table status updates

### Medium Priority (Hourly):
- Product stock updates
- Daily summaries

### Low Priority (Daily):
- Historical analytics
- Logs
- Reports
