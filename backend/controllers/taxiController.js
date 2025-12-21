/**
 * Taxi Booking Controller
 * Handles all taxi booking operations - completely separate from parking
 */

class TaxiController {
  constructor(pool) {
    this.pool = pool;
  }

  /**
   * Generate unique ticket number
   * Format: TAXI-YYYYMMDD-XXXX
   */
  async generateTicketNumber() {
    const date = new Date();
    const dateStr = date.toISOString().split('T')[0].replace(/-/g, '');

    // Get count of bookings today
    const result = await this.pool.query(
      `SELECT COUNT(*) as count FROM taxi_bookings
       WHERE DATE(booking_date) = CURRENT_DATE`
    );

    const count = parseInt(result.rows[0].count) + 1;
    const ticketNum = `TAXI-${dateStr}-${String(count).padStart(4, '0')}`;

    return ticketNum;
  }

  /**
   * Create new taxi booking
   */
  async createBooking(req, res) {
    try {
      const userId = req.userId;
      // Extract from snake_case (transformed by middleware from camelCase)
      const {
        customer_name: customerName,
        customer_mobile: customerMobile,
        vehicle_name: vehicleName,
        vehicle_number: vehicleNumber,
        from_location: fromLocation,
        to_location: toLocation,
        fare_amount: fareAmount,
        start_time: startTime,
        remarks_1: remarks1,
        remarks_2: remarks2,
        remarks_3: remarks3,
        driver_name: driverName,
        driver_mobile: driverMobile,
      } = req.body;

      // Log received data for debugging
      console.log('📝 Creating taxi booking with data:', {
        customerName, customerMobile, vehicleName, vehicleNumber,
        fromLocation, toLocation, fareAmount, driverName, driverMobile
      });

      // Validate required fields (check for undefined/null/empty string)
      const missingFields = [];
      if (!customerName || customerName.trim() === '') missingFields.push('customerName');
      if (!customerMobile || customerMobile.trim() === '') missingFields.push('customerMobile');
      if (!vehicleName || vehicleName.trim() === '') missingFields.push('vehicleName');
      if (!vehicleNumber || vehicleNumber.trim() === '') missingFields.push('vehicleNumber');
      if (!fromLocation || fromLocation.trim() === '') missingFields.push('fromLocation');
      if (!toLocation || toLocation.trim() === '') missingFields.push('toLocation');
      if (fareAmount === undefined || fareAmount === null || fareAmount === '') missingFields.push('fareAmount');
      if (!driverName || driverName.trim() === '') missingFields.push('driverName');
      if (!driverMobile || driverMobile.trim() === '') missingFields.push('driverMobile');

      if (missingFields.length > 0) {
        console.error('❌ Missing fields:', missingFields);
        return res.status(400).json({
          success: false,
          error: `Missing required fields: ${missingFields.join(', ')}`
        });
      }

      // Generate ticket number
      const ticketNumber = await this.generateTicketNumber();

      // Insert booking
      const result = await this.pool.query(
        `INSERT INTO taxi_bookings (
          user_id, ticket_number, customer_name, customer_mobile,
          vehicle_name, vehicle_number, from_location, to_location,
          fare_amount, start_time, remarks_1, remarks_2, remarks_3,
          driver_name, driver_mobile, status
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
        RETURNING *`,
        [
          userId, ticketNumber, customerName, customerMobile,
          vehicleName, vehicleNumber, fromLocation, toLocation,
          fareAmount, startTime || null, remarks1 || null, remarks2 || null, remarks3 || null,
          driverName, driverMobile, 'booked'
        ]
      );

      // Audit log
      await this.pool.query(
        `INSERT INTO audit_logs (user_id, action, entity_type, entity_id, new_values, ip_address, user_agent)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [userId, 'taxi_booking_created', 'taxi_booking', result.rows[0].id,
         JSON.stringify(result.rows[0]), req.ip, req.get('User-Agent')]
      );

      res.status(201).json({
        success: true,
        data: { booking: result.rows[0] },
        message: 'Taxi booking created successfully'
      });
    } catch (error) {
      console.error('Create taxi booking error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to create taxi booking',
        details: error.message
      });
    }
  }

  /**
   * Get all bookings for user (with filtering)
   */
  async getBookings(req, res) {
    try {
      const userId = req.userId;
      const { status, startDate, endDate, limit = 100, offset = 0 } = req.query;

      let query = 'SELECT * FROM taxi_bookings WHERE user_id = $1';
      const params = [userId];
      let paramCount = 1;

      if (status) {
        paramCount++;
        query += ` AND status = $${paramCount}`;
        params.push(status);
      }

      if (startDate) {
        paramCount++;
        query += ` AND booking_date >= $${paramCount}`;
        params.push(startDate);
      }

      if (endDate) {
        paramCount++;
        query += ` AND booking_date <= $${paramCount}`;
        params.push(endDate);
      }

      query += ` ORDER BY booking_date DESC LIMIT $${paramCount + 1} OFFSET $${paramCount + 2}`;
      params.push(limit, offset);

      const result = await this.pool.query(query, params);

      // Get counts by status
      const countResult = await this.pool.query(
        `SELECT
          COUNT(*) FILTER (WHERE status = 'booked') as booked_count,
          COUNT(*) FILTER (WHERE status = 'ongoing') as ongoing_count,
          COUNT(*) FILTER (WHERE status = 'completed') as completed_count,
          COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled_count,
          COUNT(*) as total_count
         FROM taxi_bookings WHERE user_id = $1`,
        [userId]
      );

      res.json({
        success: true,
        data: {
          bookings: result.rows,
          counts: countResult.rows[0]
        },
        message: 'Bookings retrieved successfully'
      });
    } catch (error) {
      console.error('Get taxi bookings error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to retrieve bookings',
        details: error.message
      });
    }
  }

  /**
   * Get single booking by ID
   */
  async getBookingById(req, res) {
    try {
      const userId = req.userId;
      const { id } = req.params;

      const result = await this.pool.query(
        'SELECT * FROM taxi_bookings WHERE id = $1 AND user_id = $2',
        [id, userId]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: 'Booking not found'
        });
      }

      res.json({
        success: true,
        data: { booking: result.rows[0] },
        message: 'Booking retrieved successfully'
      });
    } catch (error) {
      console.error('Get taxi booking error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to retrieve booking',
        details: error.message
      });
    }
  }

  /**
   * Update booking
   */
  async updateBooking(req, res) {
    try {
      const userId = req.userId;
      const { id } = req.params;
      const updateFields = req.body;

      // Get current booking
      const currentResult = await this.pool.query(
        'SELECT * FROM taxi_bookings WHERE id = $1 AND user_id = $2',
        [id, userId]
      );

      if (currentResult.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: 'Booking not found'
        });
      }

      const currentBooking = currentResult.rows[0];

      // Build dynamic update query
      const setFields = [];
      const values = [];
      let paramCount = 1;

      const allowedFields = [
        'customer_name', 'customer_mobile', 'vehicle_name', 'vehicle_number',
        'from_location', 'to_location', 'fare_amount', 'start_time', 'end_time',
        'remarks_1', 'remarks_2', 'remarks_3', 'driver_name', 'driver_mobile', 'status'
      ];

      Object.keys(updateFields).forEach(field => {
        const snakeField = field.replace(/([A-Z])/g, '_$1').toLowerCase();
        if (allowedFields.includes(snakeField) && updateFields[field] !== undefined) {
          setFields.push(`${snakeField} = $${paramCount}`);
          values.push(updateFields[field]);
          paramCount++;
        }
      });

      if (setFields.length === 0) {
        return res.status(400).json({
          success: false,
          error: 'No valid fields to update'
        });
      }

      values.push(id, userId);
      const query = `UPDATE taxi_bookings SET ${setFields.join(', ')}, updated_at = CURRENT_TIMESTAMP
                     WHERE id = $${paramCount} AND user_id = $${paramCount + 1} RETURNING *`;

      const result = await this.pool.query(query, values);

      // Audit log
      await this.pool.query(
        `INSERT INTO audit_logs (user_id, action, entity_type, entity_id, old_values, new_values, ip_address, user_agent)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [userId, 'taxi_booking_updated', 'taxi_booking', id,
         JSON.stringify(currentBooking), JSON.stringify(result.rows[0]),
         req.ip, req.get('User-Agent')]
      );

      res.json({
        success: true,
        data: { booking: result.rows[0] },
        message: 'Booking updated successfully'
      });
    } catch (error) {
      console.error('Update taxi booking error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to update booking',
        details: error.message
      });
    }
  }

  /**
   * Mark trip as started (booked -> ongoing)
   */
  async startTrip(req, res) {
    try {
      const userId = req.userId;
      const { id } = req.params;
      const { startTime } = req.body;

      const result = await this.pool.query(
        `UPDATE taxi_bookings
         SET status = 'ongoing', start_time = $1, updated_at = CURRENT_TIMESTAMP
         WHERE id = $2 AND user_id = $3 AND status = 'booked'
         RETURNING *`,
        [startTime || new Date(), id, userId]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: 'Booking not found or already started'
        });
      }

      res.json({
        success: true,
        data: { booking: result.rows[0] },
        message: 'Trip started successfully'
      });
    } catch (error) {
      console.error('Start trip error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to start trip',
        details: error.message
      });
    }
  }

  /**
   * Mark trip as completed (ongoing -> completed)
   */
  async completeTrip(req, res) {
    try {
      const userId = req.userId;
      const { id } = req.params;
      const { endTime, fareAmount } = req.body;

      const result = await this.pool.query(
        `UPDATE taxi_bookings
         SET status = 'completed', end_time = $1, fare_amount = COALESCE($2, fare_amount), updated_at = CURRENT_TIMESTAMP
         WHERE id = $3 AND user_id = $4 AND status IN ('booked', 'ongoing')
         RETURNING *`,
        [endTime || new Date(), fareAmount, id, userId]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: 'Booking not found or already completed'
        });
      }

      // Audit log
      await this.pool.query(
        `INSERT INTO audit_logs (user_id, action, entity_type, entity_id, new_values, ip_address, user_agent)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [userId, 'taxi_trip_completed', 'taxi_booking', id,
         JSON.stringify(result.rows[0]), req.ip, req.get('User-Agent')]
      );

      res.json({
        success: true,
        data: { booking: result.rows[0] },
        message: 'Trip completed successfully'
      });
    } catch (error) {
      console.error('Complete trip error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to complete trip',
        details: error.message
      });
    }
  }

  /**
   * Cancel booking
   */
  async cancelBooking(req, res) {
    try {
      const userId = req.userId;
      const { id } = req.params;

      const result = await this.pool.query(
        `UPDATE taxi_bookings
         SET status = 'cancelled', updated_at = CURRENT_TIMESTAMP
         WHERE id = $1 AND user_id = $2 AND status IN ('booked', 'ongoing')
         RETURNING *`,
        [id, userId]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: 'Booking not found or cannot be cancelled'
        });
      }

      res.json({
        success: true,
        data: { booking: result.rows[0] },
        message: 'Booking cancelled successfully'
      });
    } catch (error) {
      console.error('Cancel booking error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to cancel booking',
        details: error.message
      });
    }
  }

  /**
   * Delete booking (hard delete)
   */
  async deleteBooking(req, res) {
    try {
      const userId = req.userId;
      const { id } = req.params;

      const result = await this.pool.query(
        'DELETE FROM taxi_bookings WHERE id = $1 AND user_id = $2 RETURNING *',
        [id, userId]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: 'Booking not found'
        });
      }

      // Audit log
      await this.pool.query(
        `INSERT INTO audit_logs (user_id, action, entity_type, entity_id, old_values, ip_address, user_agent)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [userId, 'taxi_booking_deleted', 'taxi_booking', id,
         JSON.stringify(result.rows[0]), req.ip, req.get('User-Agent')]
      );

      res.json({
        success: true,
        message: 'Booking deleted successfully'
      });
    } catch (error) {
      console.error('Delete booking error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to delete booking',
        details: error.message
      });
    }
  }

  /**
   * Get analytics for taxi bookings
   */
  async getAnalytics(req, res) {
    try {
      const userId = req.userId;
      const { startDate, endDate } = req.query;

      let dateFilter = '';
      const params = [userId];

      if (startDate && endDate) {
        dateFilter = 'AND booking_date BETWEEN $2 AND $3';
        params.push(startDate, endDate);
      }

      // Get summary statistics
      const statsResult = await this.pool.query(
        `SELECT
          COUNT(*) as total_bookings,
          COUNT(*) FILTER (WHERE status = 'completed') as completed_trips,
          COUNT(*) FILTER (WHERE status = 'ongoing') as ongoing_trips,
          COUNT(*) FILTER (WHERE status = 'booked') as pending_bookings,
          COALESCE(SUM(fare_amount) FILTER (WHERE status = 'completed'), 0) as total_revenue,
          COALESCE(AVG(fare_amount) FILTER (WHERE status = 'completed'), 0) as avg_fare
         FROM taxi_bookings
         WHERE user_id = $1 ${dateFilter}`,
        params
      );

      res.json({
        success: true,
        data: { analytics: statsResult.rows[0] },
        message: 'Analytics retrieved successfully'
      });
    } catch (error) {
      console.error('Get taxi analytics error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to retrieve analytics',
        details: error.message
      });
    }
  }
}

module.exports = TaxiController;
