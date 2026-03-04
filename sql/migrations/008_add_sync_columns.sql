-- Add sync-related columns to categories and products for cloud sync support
ALTER TABLE categories ADD COLUMN cloud_id TEXT;
ALTER TABLE categories ADD COLUMN version INTEGER DEFAULT 1;
ALTER TABLE categories ADD COLUMN sync_status TEXT DEFAULT 'pending';
ALTER TABLE categories ADD COLUMN last_synced_at DATETIME;

ALTER TABLE products ADD COLUMN cloud_id TEXT;
ALTER TABLE products ADD COLUMN version INTEGER DEFAULT 1;
ALTER TABLE products ADD COLUMN sync_status TEXT DEFAULT 'pending';
ALTER TABLE products ADD COLUMN last_synced_at DATETIME;

CREATE INDEX IF NOT EXISTS idx_categories_cloud_id ON categories(cloud_id);
CREATE INDEX IF NOT EXISTS idx_products_cloud_id ON products(cloud_id);
