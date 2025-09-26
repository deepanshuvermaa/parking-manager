-- =====================================================
-- SAFE USER MANAGEMENT MIGRATION SCRIPT
-- Date: 2025-09-24
-- Purpose: Add multi-user business support
-- Safety: ONLY ADDITIVE changes, no modifications/deletions
-- =====================================================

-- IMPORTANT: This script is SAFE because:
-- 1. Only ADDS columns with defaults (existing queries still work)
-- 2. Backfills data for existing users (no data loss)
-- 3. Can be rolled back without affecting current functionality

BEGIN TRANSACTION;

-- =====================================================
-- STEP 1: Add new columns to users table
-- =====================================================
-- All columns are optional with defaults so existing code continues working

ALTER TABLE users
ADD COLUMN IF NOT EXISTS business_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS parent_user_id UUID REFERENCES users(id),
ADD COLUMN IF NOT EXISTS role VARCHAR(50) DEFAULT 'owner' CHECK (role IN ('owner', 'manager', 'operator', 'viewer')),
ADD COLUMN IF NOT EXISTS invited_by UUID REFERENCES users(id),
ADD COLUMN IF NOT EXISTS permissions JSONB DEFAULT '{}',
ADD COLUMN IF NOT EXISTS is_staff BOOLEAN DEFAULT false;

-- =====================================================
-- STEP 2: Backfill existing users as business owners
-- =====================================================
-- This ensures all existing users become owners of their own business
-- They continue working exactly as before

UPDATE users
SET business_id = 'biz_' || REPLACE(id::text, '-', ''),
    role = 'owner',
    is_staff = false
WHERE business_id IS NULL;

-- =====================================================
-- STEP 3: Add business_id to vehicles table
-- =====================================================
-- This will be used for future data isolation
-- Existing queries still work as they don't reference this column

ALTER TABLE vehicles
ADD COLUMN IF NOT EXISTS business_id VARCHAR(255);

-- Backfill vehicles with their owner's business_id
UPDATE vehicles v
SET business_id = u.business_id
FROM users u
WHERE v.user_id = u.id
AND v.business_id IS NULL;

-- =====================================================
-- STEP 4: Add business_id to settings table
-- =====================================================

ALTER TABLE settings
ADD COLUMN IF NOT EXISTS business_id VARCHAR(255);

-- Backfill settings with their owner's business_id
UPDATE settings s
SET business_id = u.business_id
FROM users u
WHERE s.user_id = u.id
AND s.business_id IS NULL;

-- =====================================================
-- STEP 5: Create staff_invitations table (NEW table, no conflicts)
-- =====================================================

CREATE TABLE IF NOT EXISTS staff_invitations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id VARCHAR(255) NOT NULL,
    email VARCHAR(100) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'operator',
    invited_by UUID REFERENCES users(id),
    invitation_token VARCHAR(255) UNIQUE NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'expired', 'cancelled')),
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() + INTERVAL '7 days',
    accepted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- STEP 6: Create indexes for performance
-- =====================================================
-- These are new indexes, won't affect existing queries

CREATE INDEX IF NOT EXISTS idx_users_business_id ON users(business_id);
CREATE INDEX IF NOT EXISTS idx_users_parent_user_id ON users(parent_user_id);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_vehicles_business_id ON vehicles(business_id);
CREATE INDEX IF NOT EXISTS idx_settings_business_id ON settings(business_id);
CREATE INDEX IF NOT EXISTS idx_invitations_business_id ON staff_invitations(business_id);
CREATE INDEX IF NOT EXISTS idx_invitations_token ON staff_invitations(invitation_token);

-- =====================================================
-- STEP 7: Create helper view for business staff
-- =====================================================
-- This is a new view, doesn't affect existing functionality

CREATE OR REPLACE VIEW business_staff AS
SELECT
    u.id,
    u.username,
    u.full_name,
    u.role,
    u.business_id,
    u.is_active,
    u.last_login_at,
    u.created_at,
    owner.full_name as invited_by_name
FROM users u
LEFT JOIN users owner ON u.invited_by = owner.id
WHERE u.is_staff = true;

-- =====================================================
-- VERIFICATION QUERIES (Read-only, safe to run)
-- =====================================================

-- Check that all users have business_id
SELECT COUNT(*) as users_without_business
FROM users
WHERE business_id IS NULL;

-- Check that all vehicles have business_id
SELECT COUNT(*) as vehicles_without_business
FROM vehicles
WHERE business_id IS NULL;

-- List all business owners (should be all current users)
SELECT id, username, full_name, business_id, role
FROM users
WHERE role = 'owner'
LIMIT 5;

COMMIT;

-- =====================================================
-- ROLLBACK SCRIPT (Only if needed)
-- =====================================================
-- Uncomment and run these commands to rollback:

-- BEGIN TRANSACTION;
-- ALTER TABLE users DROP COLUMN IF EXISTS business_id CASCADE;
-- ALTER TABLE users DROP COLUMN IF EXISTS parent_user_id CASCADE;
-- ALTER TABLE users DROP COLUMN IF EXISTS role CASCADE;
-- ALTER TABLE users DROP COLUMN IF EXISTS invited_by CASCADE;
-- ALTER TABLE users DROP COLUMN IF EXISTS permissions CASCADE;
-- ALTER TABLE users DROP COLUMN IF EXISTS is_staff CASCADE;
-- ALTER TABLE vehicles DROP COLUMN IF EXISTS business_id CASCADE;
-- ALTER TABLE settings DROP COLUMN IF EXISTS business_id CASCADE;
-- DROP TABLE IF EXISTS staff_invitations CASCADE;
-- DROP VIEW IF EXISTS business_staff CASCADE;
-- COMMIT;

-- =====================================================
-- END OF MIGRATION
-- =====================================================