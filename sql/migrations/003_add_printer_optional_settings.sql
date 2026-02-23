-- Migration: Add optional settings to printers table
-- Date: 2026-01-28

-- Add performance settings
ALTER TABLE printers ADD COLUMN connection_timeout INTEGER DEFAULT 3;
ALTER TABLE printers ADD COLUMN write_timeout INTEGER DEFAULT 5;
ALTER TABLE printers ADD COLUMN retry_attempts INTEGER DEFAULT 2;

-- Add print quality settings
ALTER TABLE printers ADD COLUMN print_density INTEGER DEFAULT 50 CHECK (print_density >= 0 AND print_density <= 100);
ALTER TABLE printers ADD COLUMN print_speed TEXT DEFAULT 'normal' CHECK (print_speed IN ('slow', 'normal', 'fast'));
ALTER TABLE printers ADD COLUMN cut_mode TEXT DEFAULT 'partial' CHECK (cut_mode IN ('full', 'partial', 'none'));

-- Add advanced settings
ALTER TABLE printers ADD COLUMN enable_beep INTEGER DEFAULT 1;
ALTER TABLE printers ADD COLUMN auto_cut INTEGER DEFAULT 1;
ALTER TABLE printers ADD COLUMN charset TEXT DEFAULT 'latin';
