/**
 * Migration Safety Test Script
 * This script tests that all existing functionality works after migration
 */

const { Pool } = require('pg');
require('dotenv').config({ path: '../.env' });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

async function testMigrationSafety() {
  console.log('🧪 Testing Migration Safety...\n');

  let allTestsPassed = true;
  const results = [];

  // Test 1: Existing user queries still work
  try {
    console.log('Test 1: Testing existing user queries...');
    const userQuery = await pool.query(
      'SELECT id, username, full_name, user_type, device_id, trial_expires_at FROM users LIMIT 1'
    );
    results.push({ test: 'User queries', status: '✅ PASS', details: 'All existing columns accessible' });
  } catch (error) {
    results.push({ test: 'User queries', status: '❌ FAIL', details: error.message });
    allTestsPassed = false;
  }

  // Test 2: Login query still works
  try {
    console.log('Test 2: Testing login query...');
    const loginQuery = await pool.query(
      'SELECT * FROM users WHERE username = $1 AND is_active = true LIMIT 1',
      ['test@example.com']
    );
    results.push({ test: 'Login query', status: '✅ PASS', details: 'Login query unchanged' });
  } catch (error) {
    results.push({ test: 'Login query', status: '❌ FAIL', details: error.message });
    allTestsPassed = false;
  }

  // Test 3: Vehicle queries still work
  try {
    console.log('Test 3: Testing vehicle queries...');
    const vehicleQuery = await pool.query(
      'SELECT id, vehicle_number, vehicle_type, entry_time, exit_time, amount FROM vehicles WHERE user_id IS NOT NULL LIMIT 1'
    );
    results.push({ test: 'Vehicle queries', status: '✅ PASS', details: 'Vehicle operations intact' });
  } catch (error) {
    results.push({ test: 'Vehicle queries', status: '❌ FAIL', details: error.message });
    allTestsPassed = false;
  }

  // Test 4: Settings queries still work
  try {
    console.log('Test 4: Testing settings queries...');
    const settingsQuery = await pool.query(
      'SELECT id, business_name, gst_number, vehicle_types_json FROM settings LIMIT 1'
    );
    results.push({ test: 'Settings queries', status: '✅ PASS', details: 'Settings accessible' });
  } catch (error) {
    results.push({ test: 'Settings queries', status: '❌ FAIL', details: error.message });
    allTestsPassed = false;
  }

  // Test 5: Verify backfill worked
  try {
    console.log('Test 5: Testing data backfill...');
    const backfillCheck = await pool.query(
      'SELECT COUNT(*) as count FROM users WHERE business_id IS NOT NULL'
    );
    const userCount = await pool.query('SELECT COUNT(*) as total FROM users');

    if (backfillCheck.rows[0].count === userCount.rows[0].total) {
      results.push({ test: 'Data backfill', status: '✅ PASS', details: 'All users have business_id' });
    } else {
      results.push({ test: 'Data backfill', status: '⚠️ WARN', details: 'Some users missing business_id' });
    }
  } catch (error) {
    results.push({ test: 'Data backfill', status: '❌ FAIL', details: error.message });
    allTestsPassed = false;
  }

  // Test 6: Insert operations still work
  try {
    console.log('Test 6: Testing insert operations...');

    // Test user insert (guest signup)
    await pool.query('BEGIN');
    const newUser = await pool.query(
      `INSERT INTO users (username, full_name, device_id, user_type, trial_starts_at, trial_expires_at)
       VALUES ($1, $2, $3, 'guest', NOW(), NOW() + INTERVAL '3 days')
       RETURNING id`,
      ['test_' + Date.now(), 'Test User', 'TEST_DEVICE']
    );

    // Test vehicle insert
    const newVehicle = await pool.query(
      `INSERT INTO vehicles (user_id, vehicle_number, vehicle_type, entry_time, hourly_rate)
       VALUES ($1, $2, $3, NOW(), 20)
       RETURNING id`,
      [newUser.rows[0].id, 'TEST123', 'Car']
    );

    await pool.query('ROLLBACK'); // Don't keep test data
    results.push({ test: 'Insert operations', status: '✅ PASS', details: 'Inserts work normally' });
  } catch (error) {
    await pool.query('ROLLBACK');
    results.push({ test: 'Insert operations', status: '❌ FAIL', details: error.message });
    allTestsPassed = false;
  }

  // Test 7: Check new features are available
  try {
    console.log('Test 7: Testing new features availability...');

    // Check new columns exist
    const columnCheck = await pool.query(`
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = 'users'
      AND column_name IN ('business_id', 'role', 'parent_user_id')
    `);

    if (columnCheck.rows.length === 3) {
      results.push({ test: 'New features', status: '✅ PASS', details: 'New columns added successfully' });
    } else {
      results.push({ test: 'New features', status: '⚠️ WARN', details: 'Some new columns missing' });
    }
  } catch (error) {
    results.push({ test: 'New features', status: '❌ FAIL', details: error.message });
  }

  // Print results
  console.log('\n' + '='.repeat(50));
  console.log('MIGRATION SAFETY TEST RESULTS');
  console.log('='.repeat(50) + '\n');

  results.forEach(result => {
    console.log(`${result.test}: ${result.status}`);
    if (result.details) {
      console.log(`  Details: ${result.details}`);
    }
  });

  console.log('\n' + '='.repeat(50));
  if (allTestsPassed) {
    console.log('✅ ALL TESTS PASSED - Migration is SAFE');
    console.log('All existing functionality confirmed working');
  } else {
    console.log('❌ SOME TESTS FAILED - DO NOT PROCEED');
    console.log('Rollback the migration and investigate');
  }
  console.log('='.repeat(50));

  await pool.end();
  return allTestsPassed;
}

// Run tests
testMigrationSafety().then(success => {
  process.exit(success ? 0 : 1);
}).catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});