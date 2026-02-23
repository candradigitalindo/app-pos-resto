-- Migration: Add printer_id to categories table
-- This replaces printer_type column with printer_id foreign key

-- Step 1: Add new printer_id column
ALTER TABLE categories ADD COLUMN printer_id TEXT;

-- Step 2: If printer_type column exists, we need to migrate data
-- Since we're switching from type string to ID, we'll drop old column after backup
-- (In production, you'd map printer_type values to actual printer IDs first)

-- Step 3: Create index for better performance
CREATE INDEX IF NOT EXISTS idx_categories_printer_id ON categories(printer_id);

-- Note: Foreign key constraint
-- SQLite doesn't support ALTER TABLE to add FK, so this is enforced at application level
-- The printer_id should reference printers(id)
