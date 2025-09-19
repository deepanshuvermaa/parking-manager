const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');

// Load environment variables
require('dotenv').config();

async function setupDatabase() {
  console.log('🚀 Setting up ParkEase database schema...');

  // Database connection configuration
  const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
  });

  try {
    // Read the schema file
    const schemaPath = path.join(__dirname, '../../database/schema.sql');
    const schemaSQL = fs.readFileSync(schemaPath, 'utf8');

    console.log('📋 Executing database schema...');

    // Execute the schema
    await pool.query(schemaSQL);

    console.log('✅ Database schema created successfully!');
    console.log('📊 Tables created:');
    console.log('   - users (authentication & user management)');
    console.log('   - settings (user-specific configuration)');
    console.log('   - vehicles (parking records)');
    console.log('   - sessions (active user sessions)');
    console.log('   - audit_logs (action tracking)');
    console.log('');
    console.log('👤 Default admin user created:');
    console.log('   Username: admin');
    console.log('   Password: password');
    console.log('   Email: admin@parkease.com');

  } catch (error) {
    console.error('❌ Error setting up database:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

// Run if called directly
if (require.main === module) {
  setupDatabase();
}

module.exports = { setupDatabase };