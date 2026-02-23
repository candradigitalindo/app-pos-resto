-- ============================================
-- OUTLET INFO EXTENDED SCHEMA
-- Informasi outlet untuk struk dan tampilan
-- ============================================

-- Tambah kolom informasi outlet
ALTER TABLE outlet_config ADD COLUMN outlet_address TEXT DEFAULT '';
ALTER TABLE outlet_config ADD COLUMN outlet_phone TEXT DEFAULT '';
ALTER TABLE outlet_config ADD COLUMN receipt_footer TEXT DEFAULT 'Terima kasih atas kunjungan Anda!';
ALTER TABLE outlet_config ADD COLUMN social_media TEXT DEFAULT '';
ALTER TABLE outlet_config ADD COLUMN target_spend_per_pax INTEGER DEFAULT 0;

-- Kolom cloud sync menjadi opsional (sudah ada, update default)
-- cloud_api_url dan cloud_api_key boleh kosong jika tidak pakai cloud sync
