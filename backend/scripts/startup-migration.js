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

    // Add more migrations here in the future
    // Example:
    // if (!(await checkMigration('add_feature_x'))) {
    //   await runMigration('add_feature_x', async () => {
    //     // Migration SQL here
    //   });
    // }

  } catch (error) {
    console.error('❌ Migration error:', error);
    // Don't crash the server if migration fails
    // The app should still work without the new features
    console.error('⚠️ Server will continue without new features');
  }
}

module.exports = runStartupMigrations;