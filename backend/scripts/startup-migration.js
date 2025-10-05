/**
 * Startup Migration Script
 * Runs database migrations automatically on server startup
 * Safe to run multiple times - checks if migrations already applied
 */

async function runStartupMigrations(pool) {
  console.log('🔄 Checking for database migrations...');

  try {
    // Check if migration tracking table exists
    await pool.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        id SERIAL PRIMARY KEY,
        migration_name VARCHAR(255) UNIQUE NOT NULL,
        applied_at TIMESTAMP DEFAULT NOW()
      )
    `);

    // Check if user management migration has been applied
    const migrationCheck = await pool.query(
      "SELECT * FROM schema_migrations WHERE migration_name = 'add_user_management'"
    );

    if (migrationCheck.rows.length === 0) {
      console.log('📦 Applying user management migration...');

      // Run the user management migration
      await pool.query(`
        -- Add new columns to users table (safe - won't error if they exist)
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS business_id VARCHAR(255),
        ADD COLUMN IF NOT EXISTS role VARCHAR(50) DEFAULT 'owner',
        ADD COLUMN IF NOT EXISTS parent_user_id UUID,
        ADD COLUMN IF NOT EXISTS is_staff BOOLEAN DEFAULT false,
        ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
        ADD COLUMN IF NOT EXISTS invited_by UUID,
        ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMP,
        ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();

        -- Add indexes for better query performance
        CREATE INDEX IF NOT EXISTS idx_users_business_id ON users(business_id);
        CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
        CREATE INDEX IF NOT EXISTS idx_users_parent_user_id ON users(parent_user_id);
        CREATE INDEX IF NOT EXISTS idx_users_is_active ON users(is_active);
      `);

      // Add business_id to vehicles table
      await pool.query(`
        ALTER TABLE vehicles
        ADD COLUMN IF NOT EXISTS business_id VARCHAR(255);

        CREATE INDEX IF NOT EXISTS idx_vehicles_business_id ON vehicles(business_id);
      `);

      // Add business_id to settings table
      await pool.query(`
        ALTER TABLE settings
        ADD COLUMN IF NOT EXISTS business_id VARCHAR(255);

        CREATE INDEX IF NOT EXISTS idx_settings_business_id ON settings(business_id);
      `);

      // Create staff invitations table
      await pool.query(`
        CREATE TABLE IF NOT EXISTS staff_invitations (
          id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
          business_id VARCHAR(255) NOT NULL,
          email VARCHAR(255) NOT NULL,
          role VARCHAR(50) NOT NULL,
          invited_by UUID NOT NULL,
          invitation_token VARCHAR(255) UNIQUE,
          status VARCHAR(50) DEFAULT 'pending',
          created_at TIMESTAMP DEFAULT NOW(),
          accepted_at TIMESTAMP,
          expires_at TIMESTAMP DEFAULT NOW() + INTERVAL '7 days',
          UNIQUE(business_id, email)
        );

        CREATE INDEX IF NOT EXISTS idx_invitations_business_id ON staff_invitations(business_id);
        CREATE INDEX IF NOT EXISTS idx_invitations_email ON staff_invitations(email);
        CREATE INDEX IF NOT EXISTS idx_invitations_token ON staff_invitations(invitation_token);
      `);

      // Backfill business_id for existing users
      await pool.query(`
        UPDATE users
        SET business_id = COALESCE(business_id, 'biz_' || REPLACE(id::text, '-', ''))
        WHERE business_id IS NULL;
      `);

      // Backfill business_id for existing vehicles
      await pool.query(`
        UPDATE vehicles v
        SET business_id = u.business_id
        FROM users u
        WHERE v.user_id = u.id
        AND v.business_id IS NULL
        AND u.business_id IS NOT NULL;
      `);

      // Backfill business_id for existing settings
      await pool.query(`
        UPDATE settings s
        SET business_id = u.business_id
        FROM users u
        WHERE s.user_id = u.id
        AND s.business_id IS NULL
        AND u.business_id IS NOT NULL;
      `);

      // Record that migration has been applied
      await pool.query(
        "INSERT INTO schema_migrations (migration_name) VALUES ('add_user_management')"
      );

      console.log('✅ User management migration applied successfully');
    } else {
      console.log('✅ User management migration already applied');
    }

    // ========================================
    // MIGRATION 2: Add Devices and Sessions Tables
    // ========================================
    const devicesSessionsMigrationCheck = await pool.query(
      "SELECT * FROM schema_migrations WHERE migration_name = 'add_devices_sessions'"
    );

    if (devicesSessionsMigrationCheck.rows.length === 0) {
      console.log('📦 Applying devices and sessions migration...');

      // Create devices table
      await pool.query(`
        CREATE TABLE IF NOT EXISTS devices (
          id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
          user_id UUID REFERENCES users(id) ON DELETE CASCADE,
          device_id VARCHAR(255) UNIQUE NOT NULL,
          device_name VARCHAR(255),
          platform VARCHAR(50),
          app_version VARCHAR(50),
          is_active BOOLEAN DEFAULT true,
          is_primary BOOLEAN DEFAULT false,
          last_active_at TIMESTAMP DEFAULT NOW(),
          ip_address VARCHAR(100),
          user_agent TEXT,
          created_at TIMESTAMP DEFAULT NOW(),
          updated_at TIMESTAMP DEFAULT NOW()
        )
      `);

      // Create indexes for devices table
      await pool.query(`
        CREATE INDEX IF NOT EXISTS idx_devices_user_id ON devices(user_id);
        CREATE INDEX IF NOT EXISTS idx_devices_device_id ON devices(device_id);
        CREATE INDEX IF NOT EXISTS idx_devices_is_active ON devices(is_active);
      `);

      // Create sessions table (persistent storage instead of in-memory)
      await pool.query(`
        CREATE TABLE IF NOT EXISTS sessions (
          id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
          user_id UUID REFERENCES users(id) ON DELETE CASCADE,
          device_id VARCHAR(255) NOT NULL,
          session_id VARCHAR(255) UNIQUE NOT NULL,
          access_token_hash VARCHAR(255) NOT NULL,
          refresh_token_hash VARCHAR(255),
          is_valid BOOLEAN DEFAULT true,
          expires_at TIMESTAMP NOT NULL,
          created_at TIMESTAMP DEFAULT NOW(),
          last_activity TIMESTAMP DEFAULT NOW(),
          ip_address VARCHAR(100),
          user_agent TEXT
        )
      `);

      // Create indexes for sessions table
      await pool.query(`
        CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
        CREATE INDEX IF NOT EXISTS idx_sessions_device_id ON sessions(device_id);
        CREATE INDEX IF NOT EXISTS idx_sessions_session_id ON sessions(session_id);
        CREATE INDEX IF NOT EXISTS idx_sessions_is_valid ON sessions(is_valid);
        CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON sessions(expires_at);
      `);

      // Create user_permissions table for granular access control
      await pool.query(`
        CREATE TABLE IF NOT EXISTS user_permissions (
          id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
          user_id UUID REFERENCES users(id) ON DELETE CASCADE,
          permission_type VARCHAR(100) NOT NULL,
          permission_value JSONB DEFAULT '{}',
          created_at TIMESTAMP DEFAULT NOW(),
          UNIQUE(user_id, permission_type)
        )
      `);

      // Create indexes for user_permissions table
      await pool.query(`
        CREATE INDEX IF NOT EXISTS idx_user_permissions_user_id ON user_permissions(user_id);
        CREATE INDEX IF NOT EXISTS idx_user_permissions_type ON user_permissions(permission_type);
      `);

      // Add multi_device_enabled column to users table
      await pool.query(`
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS multi_device_enabled BOOLEAN DEFAULT false,
        ADD COLUMN IF NOT EXISTS max_devices INTEGER DEFAULT 1
      `);

      // Record that migration has been applied
      await pool.query(
        "INSERT INTO schema_migrations (migration_name) VALUES ('add_devices_sessions')"
      );

      console.log('✅ Devices and sessions migration applied successfully');
    } else {
      console.log('✅ Devices and sessions migration already applied');
    }

  } catch (error) {
    console.error('❌ Migration error:', error);
    // Don't crash the server if migration fails
    // The app should still work without the new features
    console.error('⚠️ Server will continue without new features');
  }
}

module.exports = runStartupMigrations;