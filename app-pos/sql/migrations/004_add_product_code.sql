-- Add code column to products table
ALTER TABLE products ADD COLUMN code TEXT;

-- Create unique index on code
CREATE UNIQUE INDEX idx_products_code ON products(code);
