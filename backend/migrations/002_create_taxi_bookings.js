/**
 * Migration: Create taxi_bookings table
 * Handles taxi/cab booking management separate from parking
 */

const createTaxiBookingsTable = async (pool) => {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Create taxi_bookings table
    await client.query(`
      CREATE TABLE IF NOT EXISTS taxi_bookings (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

        -- Booking Information
        ticket_number VARCHAR(50) UNIQUE NOT NULL,
        booking_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

        -- Customer Details
        customer_name VARCHAR(255) NOT NULL,
        customer_mobile VARCHAR(20) NOT NULL,

        -- Vehicle Details
        vehicle_name VARCHAR(255) NOT NULL,
        vehicle_number VARCHAR(50) NOT NULL,

        -- Trip Details
        from_location VARCHAR(500) NOT NULL,
        to_location VARCHAR(500) NOT NULL,
        fare_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
        start_time TIMESTAMP WITH TIME ZONE,
        end_time TIMESTAMP WITH TIME ZONE,

        -- Remarks (3 fields as per requirement)
        remarks_1 TEXT,
        remarks_2 TEXT,
        remarks_3 TEXT,

        -- Driver Details
        driver_name VARCHAR(255) NOT NULL,
        driver_mobile VARCHAR(20) NOT NULL,

        -- Status: 'booked', 'ongoing', 'completed', 'cancelled'
        status VARCHAR(20) DEFAULT 'booked',

        -- Audit fields
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

        -- Indexes for common queries
        CONSTRAINT valid_status CHECK (status IN ('booked', 'ongoing', 'completed', 'cancelled'))
      )
    `);

    // Create indexes for performance
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_taxi_bookings_user_id ON taxi_bookings(user_id);
      CREATE INDEX IF NOT EXISTS idx_taxi_bookings_status ON taxi_bookings(status);
      CREATE INDEX IF NOT EXISTS idx_taxi_bookings_booking_date ON taxi_bookings(booking_date);
      CREATE INDEX IF NOT EXISTS idx_taxi_bookings_ticket_number ON taxi_bookings(ticket_number);
    `);

    // Create trigger for updated_at
    await client.query(`
      CREATE OR REPLACE FUNCTION update_taxi_bookings_updated_at()
      RETURNS TRIGGER AS $$
      BEGIN
        NEW.updated_at = CURRENT_TIMESTAMP;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    `);

    await client.query(`
      DROP TRIGGER IF EXISTS trigger_update_taxi_bookings_updated_at ON taxi_bookings;
      CREATE TRIGGER trigger_update_taxi_bookings_updated_at
        BEFORE UPDATE ON taxi_bookings
        FOR EACH ROW
        EXECUTE FUNCTION update_taxi_bookings_updated_at();
    `);

    await client.query('COMMIT');
    console.log('✅ Migration: taxi_bookings table created successfully');
    return true;
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Migration error:', error);
    throw error;
  } finally {
    client.release();
  }
};

const rollback = async (pool) => {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');
    await client.query('DROP TRIGGER IF EXISTS trigger_update_taxi_bookings_updated_at ON taxi_bookings');
    await client.query('DROP FUNCTION IF EXISTS update_taxi_bookings_updated_at()');
    await client.query('DROP TABLE IF EXISTS taxi_bookings CASCADE');
    await client.query('COMMIT');
    console.log('✅ Rollback: taxi_bookings table dropped');
    return true;
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Rollback error:', error);
    throw error;
  } finally {
    client.release();
  }
};

module.exports = {
  up: createTaxiBookingsTable,
  down: rollback,
};
