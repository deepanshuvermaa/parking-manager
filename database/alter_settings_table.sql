-- Add missing columns to settings table to match Flutter app requirements

-- Add currency and timezone columns
ALTER TABLE settings ADD COLUMN IF NOT EXISTS currency VARCHAR(10) DEFAULT 'INR';
ALTER TABLE settings ADD COLUMN IF NOT EXISTS timezone VARCHAR(50) DEFAULT 'Asia/Kolkata';

-- Add grace period column
ALTER TABLE settings ADD COLUMN IF NOT EXISTS grace_period_minutes INTEGER DEFAULT 15;

-- Add GST related columns
ALTER TABLE settings ADD COLUMN IF NOT EXISTS enable_gst BOOLEAN DEFAULT false;
ALTER TABLE settings ADD COLUMN IF NOT EXISTS gst_percentage DECIMAL(5,2) DEFAULT 18.0;

-- Add ticket ID settings
ALTER TABLE settings ADD COLUMN IF NOT EXISTS ticket_id_prefix VARCHAR(10) DEFAULT 'PKE';
ALTER TABLE settings ADD COLUMN IF NOT EXISTS next_ticket_number INTEGER DEFAULT 1;

-- Add state prefix for regional settings
ALTER TABLE settings ADD COLUMN IF NOT EXISTS state_prefix VARCHAR(10) DEFAULT 'UP';

-- Add primary printer ID for printer management
ALTER TABLE settings ADD COLUMN IF NOT EXISTS primary_printer_id VARCHAR(100);

-- Update the ticket_prefix column name if it exists
ALTER TABLE settings RENAME COLUMN ticket_prefix TO ticket_id_prefix;

-- Update the ticket_counter column name if it exists
ALTER TABLE settings RENAME COLUMN ticket_counter TO next_ticket_number;