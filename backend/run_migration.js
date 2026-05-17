// Run database migration script
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

const DATABASE_URL = 'postgresql://postgres:mbJCfWapOtACXuksbLwCoKyYrYVwIAjV@shortline.proxy.rlwy.net:46992/railway';

async function runMigration() {
  const pool = new Pool({
    connectionString: DATABASE_URL,
    ssl: {
      rejectUnauthorized: false
    }
  });

  try {
    console.log('🔌 Connecting to database...');

    // Read the migration SQL file
    const migrationPath = path.join(__dirname, 'migrations', 'add_destination_fields.sql');
    const sql = fs.readFileSync(migrationPath, 'utf8');

    console.log('📄 Running migration: add_destination_fields.sql');
    console.log('SQL:\n', sql);

    // Execute the migration
    const result = await pool.query(sql);

    console.log('✅ Migration completed successfully!');
    console.log('Result:', result);

    // Verify columns were added
    const verifyResult = await pool.query(`
      SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_name = 'vehicles'
      AND column_name IN ('from_location', 'to_location')
    `);

    console.log('\n✅ Verification - Columns added:');
    verifyResult.rows.forEach(row => {
      console.log(`  - ${row.column_name}: ${row.data_type}`);
    });

  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    console.error('Full error:', error);
    process.exit(1);
  } finally {
    await pool.end();
    console.log('\n🔌 Database connection closed');
  }
}

runMigration();
