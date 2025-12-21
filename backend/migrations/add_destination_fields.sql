-- Migration: Add destination fields for tour/travel businesses
-- Date: 2025-12-10
-- Description: Adds from_location and to_location columns to vehicles table

-- Add destination columns
ALTER TABLE vehicles
ADD COLUMN IF NOT EXISTS from_location VARCHAR(255),
ADD COLUMN IF NOT EXISTS to_location VARCHAR(255);

-- Add index for searching by destination
CREATE INDEX IF NOT EXISTS idx_vehicles_destinations
ON vehicles(from_location, to_location);

-- Verify migration
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'vehicles'
AND column_name IN ('from_location', 'to_location');
