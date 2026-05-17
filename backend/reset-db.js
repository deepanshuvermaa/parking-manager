const { Pool } = require('pg');

const pool = new Pool({
  connectionString: 'postgresql://postgres:mbJCfWapOtACXuksbLwCoKyYrYVwIAjV@shortline.proxy.rlwy.net:46992/railway',
  ssl: { rejectUnauthorized: false }
});

async function resetDB() {
  const client = await pool.connect();
  try {
    console.log('🗑️  Dropping all tables...');
    await client.query(`
      DROP SCHEMA public CASCADE;
      CREATE SCHEMA public;
      GRANT ALL ON SCHEMA public TO postgres;
      GRANT ALL ON SCHEMA public TO public;
    `);
    console.log('✅ Schema reset complete');

    console.log('📦 Creating fresh schema...');
    await client.query(`CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`);

    // Users table
    await client.query(`
      CREATE TABLE users (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        username VARCHAR(50) UNIQUE NOT NULL,
        full_name VARCHAR(100) NOT NULL,
        email VARCHAR(100),
        password_hash VARCHAR(255),
        user_type VARCHAR(20) DEFAULT 'guest',
        role VARCHAR(50) DEFAULT 'owner',
        device_id VARCHAR(100),
        business_id VARCHAR(255),
        parent_user_id UUID,
        is_staff BOOLEAN DEFAULT false,
        is_active BOOLEAN DEFAULT true,
        multi_device_enabled BOOLEAN DEFAULT false,
        max_devices INTEGER DEFAULT 3,
        parking_name VARCHAR(200),
        phone VARCHAR(20),
        trial_starts_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        trial_expires_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() + INTERVAL '365 days',
        subscription_expires_at TIMESTAMP WITH TIME ZONE,
        last_login_at TIMESTAMP WITH TIME ZONE,
        login_count INTEGER DEFAULT 0,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      )
    `);

    // Settings table
    await client.query(`
      CREATE TABLE settings (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        business_id VARCHAR(255),
        business_name VARCHAR(100) DEFAULT 'My Parking',
        business_address TEXT,
        business_phone VARCHAR(20),
        business_email VARCHAR(100),
        gst_number VARCHAR(20),
        receipt_header TEXT,
        receipt_footer TEXT DEFAULT 'Thank you for parking!',
        printer_name VARCHAR(100),
        printer_type VARCHAR(20) DEFAULT 'thermal',
        auto_print BOOLEAN DEFAULT true,
        vehicle_types_json JSONB DEFAULT '[]'::jsonb,
        ticket_prefix VARCHAR(10) DEFAULT 'PT',
        ticket_counter INTEGER DEFAULT 1,
        grace_period_minutes INTEGER DEFAULT 15,
        paper_width INTEGER DEFAULT 32,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      )
    `);

    // Vehicles table
    await client.query(`
      CREATE TABLE vehicles (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        business_id VARCHAR(255),
        vehicle_number VARCHAR(20) NOT NULL,
        vehicle_type VARCHAR(50) NOT NULL,
        entry_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        exit_time TIMESTAMP WITH TIME ZONE,
        duration_minutes INTEGER,
        hourly_rate DECIMAL(10,2),
        minimum_rate DECIMAL(10,2),
        amount DECIMAL(10,2),
        status VARCHAR(20) DEFAULT 'parked',
        ticket_id VARCHAR(50),
        notes TEXT,
        from_location TEXT,
        to_location TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      )
    `);

    // Devices table
    await client.query(`
      CREATE TABLE devices (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        device_id VARCHAR(255) UNIQUE NOT NULL,
        device_name VARCHAR(255),
        platform VARCHAR(50),
        app_version VARCHAR(50),
        is_active BOOLEAN DEFAULT true,
        is_primary BOOLEAN DEFAULT false,
        last_active_at TIMESTAMP DEFAULT NOW(),
        ip_address VARCHAR(100),
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      )
    `);

    // Sessions table
    await client.query(`
      CREATE TABLE sessions (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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

    // Taxi bookings table
    await client.query(`
      CREATE TABLE taxi_bookings (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        business_id VARCHAR(255),
        booking_id VARCHAR(50) UNIQUE,
        customer_name VARCHAR(100),
        customer_phone VARCHAR(20),
        vehicle_number VARCHAR(20),
        vehicle_type VARCHAR(50) DEFAULT 'Car',
        from_location TEXT,
        to_location TEXT,
        distance_km DECIMAL(10,2),
        fare_amount DECIMAL(10,2),
        status VARCHAR(20) DEFAULT 'pending',
        driver_name VARCHAR(100),
        driver_phone VARCHAR(20),
        start_time TIMESTAMP WITH TIME ZONE,
        end_time TIMESTAMP WITH TIME ZONE,
        notes TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      )
    `);

    // Schema migrations tracking
    await client.query(`
      CREATE TABLE schema_migrations (
        id SERIAL PRIMARY KEY,
        migration_name VARCHAR(255) UNIQUE NOT NULL,
        applied_at TIMESTAMP DEFAULT NOW()
      )
    `);

    // Indexes
    await client.query(`
      CREATE INDEX idx_users_username ON users(username);
      CREATE INDEX idx_users_business_id ON users(business_id);
      CREATE INDEX idx_vehicles_user_id ON vehicles(user_id);
      CREATE INDEX idx_vehicles_status ON vehicles(status);
      CREATE INDEX idx_vehicles_entry_time ON vehicles(entry_time);
      CREATE INDEX idx_vehicles_business_id ON vehicles(business_id);
      CREATE INDEX idx_devices_user_id ON devices(user_id);
      CREATE INDEX idx_devices_device_id ON devices(device_id);
      CREATE INDEX idx_sessions_user_id ON sessions(user_id);
      CREATE INDEX idx_sessions_is_valid ON sessions(is_valid);
      CREATE INDEX idx_taxi_bookings_user_id ON taxi_bookings(user_id);
      CREATE INDEX idx_taxi_bookings_status ON taxi_bookings(status);
    `);

    // Insert admin user (password: 'password')
    const bcrypt = require('bcryptjs');
    const hash = await bcrypt.hash('password', 10);
    
    await client.query(`
      INSERT INTO users (username, full_name, email, password_hash, user_type, role, is_active, max_devices, parking_name, trial_expires_at, subscription_expires_at)
      VALUES ('admin', 'Administrator', 'admin@parkease.com', $1, 'admin', 'owner', true, 5, 'ParkEase Demo', NOW() + INTERVAL '365 days', NOW() + INTERVAL '365 days')
    `, [hash]);

    // Insert settings for admin
    await client.query(`
      INSERT INTO settings (user_id, business_name, business_address, receipt_header, receipt_footer)
      VALUES (
        (SELECT id FROM users WHERE username = 'admin'),
        'ParkEase Parking',
        'Demo Location',
        'Welcome to ParkEase',
        'Thank you! Visit again.'
      )
    `);

    // Mark all migrations as applied
    await client.query(`
      INSERT INTO schema_migrations (migration_name) VALUES 
        ('add_user_management'),
        ('add_devices_sessions'),
        ('add_taxi_bookings')
    `);

    console.log('✅ Fresh database created successfully!');
    console.log('👤 Admin: username=admin, password=password');
  } catch (e) {
    console.error('❌ Error:', e.message);
  } finally {
    client.release();
    await pool.end();
  }
}

resetDB();
