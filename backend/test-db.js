const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:aOXJC83xN7YXovPHCCqaLdCeSHdJnhrq@junction.proxy.rlwy.net:58325/railway',
  ssl: { rejectUnauthorized: false }
});

async function checkUsers() {
  try {
    const result = await pool.query(`
      SELECT id, username, device_id, user_type,
             password_hash IS NOT NULL as has_password,
             created_at
      FROM users
      ORDER BY created_at DESC
    `);

    console.log('Users in database:');
    console.log('==================');
    result.rows.forEach(user => {
      console.log(`Username: ${user.username}`);
      console.log(`  Type: ${user.user_type}`);
      console.log(`  Has Password: ${user.has_password}`);
      console.log(`  Device ID: ${user.device_id || 'NULL'}`);
      console.log(`  Created: ${user.created_at}`);
      console.log('---');
    });

    pool.end();
  } catch (err) {
    console.error('Error:', err);
    pool.end();
  }
}

checkUsers();