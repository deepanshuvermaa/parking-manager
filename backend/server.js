const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

// Version: 4.3.1 - Taxi Service Release

// Import centralized config and middleware
const config = require('./config');
const { transformRequest, transformResponse } = require('./middleware/dataTransform');
const { verifyToken, initializeSessionMiddleware } = require('./middleware/session');
const { initializeTrialCheck } = require('./middleware/trialCheck');
const AuthController = require('./controllers/authController');

const app = express();
const PORT = config.port;

// Trust proxy for Railway deployment
app.set('trust proxy', true);

// Database connection using config
const pool = new Pool({
  connectionString: config.database.url,
  ssl: config.database.ssl
});

// Middleware
// CORS configuration from config
app.use(cors(config.cors));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Add data transformation middleware
app.use(transformRequest);
app.use(transformResponse);

// Rate limiting - temporarily disabled for debugging
// const limiter = rateLimit({
//   windowMs: 15 * 60 * 1000, // 15 minutes
//   max: 100, // limit each IP to 100 requests per windowMs
//   message: 'Too many requests from this IP, please try again later.',
//   trustProxy: true
// });
// app.use('/api/', limiter);

// Initialize session middleware with database pool
initializeSessionMiddleware(pool);

// Initialize trial check middleware
const checkTrialExpiry = initializeTrialCheck(pool);

// Initialize auth controller
const authController = new AuthController(pool);

// OLD JWT code removed - using session middleware now

// Audit logging function
const logAudit = async (userId, action, entityType, entityId, oldValues, newValues, req) => {
  try {
    const changes = {};
    if (oldValues && newValues) {
      Object.keys(newValues).forEach(key => {
        if (oldValues[key] !== newValues[key]) {
          changes[key] = { old: oldValues[key], new: newValues[key] };
        }
      });
    }

    await pool.query(
      `INSERT INTO audit_logs (user_id, action, entity_type, entity_id, old_values, new_values, changes, ip_address, user_agent)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
      [
        userId,
        action,
        entityType,
        entityId,
        JSON.stringify(oldValues),
        JSON.stringify(newValues),
        JSON.stringify(changes),
        req.ip,
        req.get('User-Agent')
      ]
    );
  } catch (error) {
    console.error('Audit logging error:', error);
  }
};

const path = require('path');

// Serve landing page static files
app.use(express.static(path.join(__dirname, 'public')));
app.use('/downloads', express.static(path.join(__dirname, 'downloads')));

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// ================================
// AUTHENTICATION ENDPOINTS
// ================================
// AUTH ROUTES - Using proper controller with session management
// ================================
app.post('/api/auth/guest-signup', (req, res) => authController.guestSignup(req, res));
app.post('/api/auth/login', (req, res) => authController.login(req, res));
app.post('/api/auth/logout', verifyToken, (req, res) => authController.logout(req, res));
app.post('/api/auth/refresh', (req, res) => authController.refreshToken(req, res));
app.get('/api/auth/validate', verifyToken, (req, res) => authController.validateToken(req, res));

// ================================
// OLD AUTH ROUTES - COMMENTED OUT
// ================================
/*
app.post('/api/auth/guest-signup-old', async (req, res) => {
  try {
    const { username, fullName, deviceId } = req.body;

    if (!username || !fullName || !deviceId) {
      return res.status(400).json({
        success: false,
        error: 'Username, full name, and device ID are required'
      });
    }

    // Check if username already exists
    const existingUser = await pool.query(
      'SELECT id FROM users WHERE username = $1 OR device_id = $2',
      [username, deviceId]
    );

    if (existingUser.rows.length > 0) {
      return res.status(409).json({
        success: false,
        error: 'Username or device already registered'
      });
    }

    // Create new guest user
    const userResult = await pool.query(
      `INSERT INTO users (username, full_name, device_id, user_type, trial_starts_at, trial_expires_at)
       VALUES ($1, $2, $3, 'guest', NOW(), NOW() + INTERVAL '3 days')
       RETURNING id, username, full_name, user_type, trial_expires_at`,
      [username, fullName, deviceId]
    );

    const user = userResult.rows[0];

    // Create default settings for the user
    await pool.query(
      `INSERT INTO settings (user_id, business_name, vehicle_types_json)
       VALUES ($1, $2, $3)`,
      [
        user.id,
        `${fullName}'s Parking`,
        JSON.stringify([
          {"name": "Car", "hourlyRate": 20, "dailyRate": 200, "monthlyRate": 5000, "minimumCharge": 20, "freeMinutes": 15},
          {"name": "Bike", "hourlyRate": 10, "dailyRate": 100, "monthlyRate": 2500, "minimumCharge": 10, "freeMinutes": 10},
          {"name": "Scooter", "hourlyRate": 10, "dailyRate": 100, "monthlyRate": 2500, "minimumCharge": 10, "freeMinutes": 10},
          {"name": "SUV", "hourlyRate": 30, "dailyRate": 300, "monthlyRate": 7500, "minimumCharge": 30, "freeMinutes": 15}
        ])
      ]
    );

    // Generate tokens
    const { token, refreshToken } = generateTokens(user.id);

    // Create session
    await pool.query(
      `INSERT INTO sessions (user_id, token_hash, refresh_token_hash, device_id, expires_at, ip_address, user_agent)
       VALUES ($1, $2, $3, $4, NOW() + INTERVAL '1 hour', $5, $6)`,
      [
        user.id,
        bcrypt.hashSync(token, 10),
        bcrypt.hashSync(refreshToken, 10),
        deviceId,
        req.ip,
        req.get('User-Agent')
      ]
    );

    // Log audit
    await logAudit(user.id, 'user_signup', 'user', user.id, null, user, req);

    res.status(201).json({
      success: true,
      data: {
        user: {
          id: user.id,
          username: user.username,
          fullName: user.full_name,
          userType: user.user_type,
          trialExpiresAt: user.trial_expires_at
        },
        token,
        refreshToken
      },
      message: 'Account created successfully'
    });

  } catch (error) {
    console.error('Signup error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});
*/

// Signup endpoint removed - using authController

// Login endpoint removed - using authController

// Token refresh endpoint removed - using authController

// Validate Session
app.get('/api/auth/validate', verifyToken, async (req, res) => {
  try {
    const userResult = await pool.query(
      'SELECT id, username, full_name, user_type, trial_expires_at FROM users WHERE id = $1 AND is_active = true',
      [req.userId]
    );

    if (userResult.rows.length === 0) {
      return res.status(401).json({ success: false, error: 'User not found' });
    }

    res.json({
      success: true,
      data: { user: userResult.rows[0] },
      message: 'Session valid'
    });

  } catch (error) {
    console.error('Session validation error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// Logout endpoint removed - using authController

// ================================
// VEHICLE MANAGEMENT ENDPOINTS
// ================================

// Get Vehicles (with trial check)
app.get('/api/vehicles', verifyToken, checkTrialExpiry, async (req, res) => {
  try {
    const { status, limit = 100, offset = 0 } = req.query;

    let query = 'SELECT * FROM vehicles WHERE user_id = $1';
    const params = [req.userId];

    if (status) {
      query += ' AND status = $2';
      params.push(status);
    }

    query += ' ORDER BY entry_time DESC LIMIT $' + (params.length + 1) + ' OFFSET $' + (params.length + 2);
    params.push(limit, offset);

    const result = await pool.query(query, params);

    res.json({
      success: true,
      data: { vehicles: result.rows },
      message: 'Vehicles retrieved successfully'
    });

  } catch (error) {
    console.error('Get vehicles error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// Add Vehicle
app.post('/api/vehicles', verifyToken, subscriptionCheck, checkTrialExpiry, async (req, res) => {
  try {
    // Accept both camelCase and snake_case for compatibility
    const {
      vehicleNumber, vehicle_number,
      vehicleType, vehicle_type,
      entryTime, entry_time,
      hourlyRate, hourly_rate,
      minimumRate, minimum_rate,
      ticketId, ticket_id,
      notes
    } = req.body;

    // Normalize fields
    const normalizedData = {
      vehicleNumber: vehicleNumber || vehicle_number,
      vehicleType: vehicleType || vehicle_type,
      entryTime: entryTime || entry_time,
      hourlyRate: hourlyRate || hourly_rate,
      minimumRate: minimumRate || minimum_rate,
      ticketId: ticketId || ticket_id,
      notes
    };

    if (!normalizedData.vehicleNumber || !normalizedData.vehicleType) {
      return res.status(400).json({
        success: false,
        error: 'Vehicle number and type are required'
      });
    }

    console.log('Adding vehicle with normalized data:', normalizedData);

    const result = await pool.query(
      `INSERT INTO vehicles (user_id, vehicle_number, vehicle_type, entry_time, hourly_rate, minimum_rate, ticket_id, notes, from_location, to_location)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       RETURNING *`,
      [
        req.userId,
        normalizedData.vehicleNumber,
        normalizedData.vehicleType,
        normalizedData.entryTime || new Date(),
        normalizedData.hourlyRate,
        normalizedData.minimumRate,
        normalizedData.ticketId,
        normalizedData.notes,
        normalizedData.fromLocation || null,
        normalizedData.toLocation || null
      ]
    );

    const vehicle = result.rows[0];

    await logAudit(req.userId, 'vehicle_entry', 'vehicle', vehicle.id, null, vehicle, req);

    res.status(201).json({
      success: true,
      data: { vehicle },
      message: 'Vehicle added successfully'
    });

  } catch (error) {
    console.error('Add vehicle error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// Exit Vehicle
app.put('/api/vehicles/:id/exit', verifyToken, checkTrialExpiry, async (req, res) => {
  try {
    const { id } = req.params;
    const { exitTime, amount, notes } = req.body;

    // Get current vehicle data (handle both UUID and string IDs like "local_1759730204667")
    const currentResult = await pool.query(
      'SELECT * FROM vehicles WHERE (CAST(id AS TEXT) = $1 OR ticket_id = $1) AND user_id = $2',
      [id, req.userId]
    );

    if (currentResult.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Vehicle not found' });
    }

    const currentVehicle = currentResult.rows[0];

    // Calculate duration
    const exit = new Date(exitTime || new Date());
    const entry = new Date(currentVehicle.entry_time);
    const durationMinutes = Math.floor((exit - entry) / (1000 * 60));

    // Update vehicle (handle both UUID and string IDs)
    const result = await pool.query(
      `UPDATE vehicles
       SET exit_time = $1, amount = $2, status = 'exited', duration_minutes = $3, notes = $4, updated_at = NOW()
       WHERE (CAST(id AS TEXT) = $5 OR ticket_id = $5) AND user_id = $6
       RETURNING *`,
      [exit, amount, durationMinutes, notes, id, req.userId]
    );

    const updatedVehicle = result.rows[0];

    await logAudit(req.userId, 'vehicle_exit', 'vehicle', id, currentVehicle, updatedVehicle, req);

    res.json({
      success: true,
      data: { vehicle: updatedVehicle },
      message: 'Vehicle exited successfully'
    });

  } catch (error) {
    console.error('Exit vehicle error:', {
      vehicleId: id,
      error: error.message,
      code: error.code,
      stack: error.stack
    });
    res.status(500).json({
      success: false,
      error: 'Exit failed',
      details: error.message
    });
  }
});

// Update Vehicle
app.put('/api/vehicles/:id', verifyToken, checkTrialExpiry, async (req, res) => {
  try {
    const { id } = req.params;
    const updateFields = req.body;

    // Get current vehicle data
    const currentResult = await pool.query(
      'SELECT * FROM vehicles WHERE id = $1 AND user_id = $2',
      [id, req.userId]
    );

    if (currentResult.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Vehicle not found' });
    }

    const currentVehicle = currentResult.rows[0];

    // Build dynamic update query
    const setFields = [];
    const values = [];
    let paramCount = 1;

    Object.keys(updateFields).forEach(field => {
      if (updateFields[field] !== undefined) {
        setFields.push(`${field} = $${paramCount}`);
        values.push(updateFields[field]);
        paramCount++;
      }
    });

    if (setFields.length === 0) {
      return res.status(400).json({ success: false, error: 'No fields to update' });
    }

    setFields.push(`updated_at = NOW()`);
    values.push(id, req.userId);

    const query = `UPDATE vehicles SET ${setFields.join(', ')} WHERE id = $${paramCount} AND user_id = $${paramCount + 1} RETURNING *`;

    const result = await pool.query(query, values);
    const updatedVehicle = result.rows[0];

    await logAudit(req.userId, 'vehicle_update', 'vehicle', id, currentVehicle, updatedVehicle, req);

    res.json({
      success: true,
      data: { vehicle: updatedVehicle },
      message: 'Vehicle updated successfully'
    });

  } catch (error) {
    console.error('Update vehicle error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// Delete Vehicle
app.delete('/api/vehicles/:id', verifyToken, checkTrialExpiry, async (req, res) => {
  try {
    const { id } = req.params;

    const result = await pool.query(
      'DELETE FROM vehicles WHERE id = $1 AND user_id = $2 RETURNING *',
      [id, req.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Vehicle not found' });
    }

    await logAudit(req.userId, 'vehicle_delete', 'vehicle', id, result.rows[0], null, req);

    res.json({
      success: true,
      message: 'Vehicle deleted successfully'
    });

  } catch (error) {
    console.error('Delete vehicle error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// Sync Vehicles (Bulk Upload)
app.post('/api/vehicles/sync', verifyToken, checkTrialExpiry, async (req, res) => {
  try {
    const { vehicles } = req.body;

    if (!Array.isArray(vehicles)) {
      return res.status(400).json({ success: false, error: 'Vehicles must be an array' });
    }

    const client = await pool.connect();

    try {
      await client.query('BEGIN');

      const syncedVehicles = [];

      for (const vehicle of vehicles) {
        const {
          vehicleNumber,
          vehicleType,
          entryTime,
          exitTime,
          amount,
          status,
          ticketId,
          hourlyRate,
          minimumRate,
          notes
        } = vehicle;

        // Check if vehicle already exists by ticket_id or unique combination
        let existingVehicle = null;
        if (ticketId) {
          const existingResult = await client.query(
            'SELECT id FROM vehicles WHERE user_id = $1 AND ticket_id = $2',
            [req.userId, ticketId]
          );
          existingVehicle = existingResult.rows[0];
        }

        if (existingVehicle) {
          // Update existing vehicle
          const result = await client.query(
            `UPDATE vehicles
             SET vehicle_number = $1, vehicle_type = $2, entry_time = $3, exit_time = $4,
                 amount = $5, status = $6, hourly_rate = $7, minimum_rate = $8, notes = $9, updated_at = NOW()
             WHERE id = $10 AND user_id = $11
             RETURNING *`,
            [
              vehicleNumber, vehicleType, entryTime, exitTime, amount,
              status, hourlyRate, minimumRate, notes, existingVehicle.id, req.userId
            ]
          );
          syncedVehicles.push(result.rows[0]);
        } else {
          // Insert new vehicle
          const result = await client.query(
            `INSERT INTO vehicles (user_id, vehicle_number, vehicle_type, entry_time, exit_time, amount, status, ticket_id, hourly_rate, minimum_rate, notes)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
             RETURNING *`,
            [
              req.userId, vehicleNumber, vehicleType, entryTime, exitTime,
              amount, status, ticketId, hourlyRate, minimumRate, notes
            ]
          );
          syncedVehicles.push(result.rows[0]);
        }
      }

      await client.query('COMMIT');

      await logAudit(req.userId, 'vehicles_sync', 'vehicle', null, null, { count: syncedVehicles.length }, req);

      res.json({
        success: true,
        data: { vehicles: syncedVehicles, synced: syncedVehicles.length },
        message: `${syncedVehicles.length} vehicles synced successfully`
      });

    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }

  } catch (error) {
    console.error('Sync vehicles error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// ================================
// SETTINGS MANAGEMENT ENDPOINTS
// ================================

// Get Settings
app.get('/api/settings', verifyToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM settings WHERE user_id = $1',
      [req.userId]
    );

    if (result.rows.length === 0) {
      // Create default settings if none exist
      const defaultSettings = await pool.query(
        `INSERT INTO settings (user_id, business_name)
         VALUES ($1, 'My Parking Business')
         RETURNING *`,
        [req.userId]
      );

      res.json({
        success: true,
        data: defaultSettings.rows[0],
        message: 'Default settings created'
      });
    } else {
      res.json({
        success: true,
        data: result.rows[0],
        message: 'Settings retrieved successfully'
      });
    }

  } catch (error) {
    console.error('Get settings error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// Update Settings
app.put('/api/settings', verifyToken, async (req, res) => {
  try {
    const updateFields = req.body;

    // Get current settings
    const currentResult = await pool.query(
      'SELECT * FROM settings WHERE user_id = $1',
      [req.userId]
    );

    const currentSettings = currentResult.rows[0];

    // Build dynamic update query
    const setFields = [];
    const values = [];
    let paramCount = 1;

    Object.keys(updateFields).forEach(field => {
      if (updateFields[field] !== undefined) {
        setFields.push(`${field} = $${paramCount}`);
        values.push(updateFields[field]);
        paramCount++;
      }
    });

    if (setFields.length === 0) {
      return res.status(400).json({ success: false, error: 'No fields to update' });
    }

    setFields.push(`updated_at = NOW()`);
    values.push(req.userId);

    const query = `UPDATE settings SET ${setFields.join(', ')} WHERE user_id = $${paramCount} RETURNING *`;

    const result = await pool.query(query, values);

    if (result.rows.length === 0) {
      // Create settings if they don't exist
      const createResult = await pool.query(
        `INSERT INTO settings (user_id, ${Object.keys(updateFields).join(', ')})
         VALUES ($1, ${Object.keys(updateFields).map((_, i) => `$${i + 2}`).join(', ')})
         RETURNING *`,
        [req.userId, ...Object.values(updateFields)]
      );

      await logAudit(req.userId, 'settings_create', 'settings', createResult.rows[0].id, null, createResult.rows[0], req);

      res.json({
        success: true,
        data: createResult.rows[0],
        message: 'Settings created successfully'
      });
    } else {
      await logAudit(req.userId, 'settings_update', 'settings', result.rows[0].id, currentSettings, result.rows[0], req);

      res.json({
        success: true,
        data: result.rows[0],
        message: 'Settings updated successfully'
      });
    }

  } catch (error) {
    console.error('Update settings error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// ================================
// ANALYTICS ENDPOINTS
// ================================

// Dashboard Analytics
app.get('/api/analytics/dashboard', verifyToken, async (req, res) => {
  try {
    const { startDate, endDate } = req.query;

    // Get basic stats
    const statsResult = await pool.query(
      `SELECT
         COUNT(*) as total_vehicles,
         COUNT(*) FILTER (WHERE status = 'parked') as parked_count,
         COUNT(*) FILTER (WHERE status = 'exited') as exited_count,
         COALESCE(SUM(amount), 0) as total_revenue,
         COALESCE(AVG(amount), 0) as avg_revenue,
         COALESCE(AVG(duration_minutes), 0) as avg_duration
       FROM vehicles
       WHERE user_id = $1
       ${startDate ? 'AND entry_time >= $2' : ''}
       ${endDate ? `AND entry_time <= $${startDate ? '3' : '2'}` : ''}`,
      [req.userId, ...(startDate ? [startDate] : []), ...(endDate ? [endDate] : [])]
    );

    // Get hourly distribution
    const hourlyResult = await pool.query(
      `SELECT
         EXTRACT(HOUR FROM entry_time) as hour,
         COUNT(*) as count,
         COALESCE(SUM(amount), 0) as revenue
       FROM vehicles
       WHERE user_id = $1 AND entry_time >= NOW() - INTERVAL '7 days'
       GROUP BY EXTRACT(HOUR FROM entry_time)
       ORDER BY hour`,
      [req.userId]
    );

    // Get vehicle type breakdown
    const vehicleTypeResult = await pool.query(
      `SELECT
         vehicle_type,
         COUNT(*) as count,
         COALESCE(SUM(amount), 0) as revenue
       FROM vehicles
       WHERE user_id = $1 AND entry_time >= NOW() - INTERVAL '30 days'
       GROUP BY vehicle_type
       ORDER BY count DESC`,
      [req.userId]
    );

    res.json({
      success: true,
      data: {
        stats: statsResult.rows[0],
        hourlyDistribution: hourlyResult.rows,
        vehicleTypeBreakdown: vehicleTypeResult.rows
      },
      message: 'Analytics retrieved successfully'
    });

  } catch (error) {
    console.error('Analytics error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// ================================
// OPTIONAL: User Management Features
// ================================
// Mount new route handlers
// Make pool available to routes
app.locals.pool = pool;

// Device management routes - stub implementation
try {
  const deviceRoutes = require('./routes/deviceRoutes');
  app.use('/api/devices', deviceRoutes);
  console.log('📱 Device routes loaded');
} catch (error) {
  console.log('⚠️ Device routes not found');
}

// Admin management routes - stub implementation
try {
  const adminRoutes = require('./routes/adminRoutes');
  app.use('/api/admin', adminRoutes);
  console.log('🔐 Admin routes loaded');
} catch (error) {
  console.log('⚠️ Admin routes not found');
}

// Taxi booking routes - CRITICAL FEATURE v4.3
console.log('📍 Loading taxi routes...');
try {
  const taxiRoutes = require('./routes/taxiRoutes')(pool, verifyToken, checkTrialExpiry);
  app.use('/api/taxi-bookings', taxiRoutes);
  console.log('✅ 🚕 Taxi booking routes SUCCESSFULLY loaded at /api/taxi-bookings');
} catch (error) {
  console.error('❌ CRITICAL: Taxi booking routes failed to load!');
  console.error('Error message:', error.message);
  console.error('Stack trace:', error.stack);
}

// Test endpoint to verify deployment
app.get('/api/taxi-test', (req, res) => {
  res.json({
    success: true,
    message: 'Taxi service endpoint active',
    version: '4.3.1',
    timestamp: new Date().toISOString()
  });
});

// This is a safe addon that doesn't modify existing functionality
// Comment out the next line to disable user management features
try {
  const enableUserManagement = process.env.ENABLE_USER_MANAGEMENT !== 'false';
  if (enableUserManagement) {
    require('./user-management-addon')(app, pool, verifyToken);
    console.log('📥 User Management features loaded');
  }
} catch (error) {
  console.log('⚠️ User Management addon not found or disabled');
}

// ================================
// ERROR HANDLING - Must be AFTER all routes
// ================================

// 404 handler - catches all unmatched routes
app.use('*', (req, res) => {
  res.status(404).json({ success: false, error: 'Endpoint not found' });
});

// Global error handler
// ================================
// MIDDLEWARE: Admin Guard & Subscription Check
// ================================

// Admin-only guard for admin panel endpoints
// Accepts either: valid ParkEase admin token OR X-Admin-Key header
const ADMIN_API_KEY = process.env.JWT_SECRET; // Use JWT_SECRET as admin key
const adminGuard = async (req, res, next) => {
  try {
    // Check admin API key first (for cross-service admin panel calls)
    const apiKey = req.headers['x-admin-key'];
    if (apiKey && apiKey === ADMIN_API_KEY) return next();

    // Otherwise check if user is admin via token
    const user = await pool.query('SELECT user_type, role FROM users WHERE id = $1', [req.userId]);
    if (!user.rows[0] || user.rows[0].user_type !== 'admin') {
      return res.status(403).json({ success: false, error: 'Admin access required' });
    }
    next();
  } catch (e) { res.status(500).json({ success: false, error: e.message }); }
};

// Subscription check - blocks expired users from vehicle operations
const subscriptionCheck = async (req, res, next) => {
  try {
    const user = await pool.query('SELECT trial_expires_at, subscription_expires_at, is_active FROM users WHERE id = $1', [req.userId]);
    if (!user.rows[0] || !user.rows[0].is_active) {
      return res.status(403).json({ success: false, error: 'Account disabled', code: 'ACCOUNT_DISABLED' });
    }
    const { trial_expires_at, subscription_expires_at } = user.rows[0];
    const now = new Date();
    const trialValid = trial_expires_at && new Date(trial_expires_at) > now;
    const subValid = subscription_expires_at && new Date(subscription_expires_at) > now;
    if (!trialValid && !subValid) {
      return res.status(403).json({ success: false, error: 'Subscription expired', code: 'SUBSCRIPTION_EXPIRED' });
    }
    next();
  } catch (e) { next(); } // Don't block on DB errors
};

// ================================
// STAFF MANAGEMENT ENDPOINTS
// ================================

// List staff for a business (owner only)
app.get('/api/business/staff', verifyToken, async (req, res) => {
  try {
    const user = await pool.query('SELECT * FROM users WHERE id = $1', [req.userId]);
    if (!user.rows[0] || user.rows[0].role !== 'owner') {
      return res.status(403).json({ success: false, error: 'Owner access required' });
    }
    const businessId = user.rows[0].business_id;
    const staff = await pool.query(
      'SELECT id, username, full_name, role, is_active, last_login_at, created_at FROM users WHERE business_id = $1 AND id != $2 ORDER BY created_at DESC',
      [businessId, req.userId]
    );
    res.json({ success: true, data: { staff: staff.rows } });
  } catch (e) { res.status(500).json({ success: false, error: e.message }); }
});

// Create staff member (owner only)
app.post('/api/business/staff', verifyToken, async (req, res) => {
  try {
    const user = await pool.query('SELECT * FROM users WHERE id = $1', [req.userId]);
    if (!user.rows[0] || user.rows[0].role !== 'owner') {
      return res.status(403).json({ success: false, error: 'Owner access required' });
    }
    const { username, password, fullName, role } = req.body;
    if (!username || !password || !fullName) {
      return res.status(400).json({ success: false, error: 'username, password, fullName required' });
    }
    const validRoles = ['staff', 'manager'];
    const staffRole = validRoles.includes(role) ? role : 'staff';
    const hash = await bcrypt.hash(password, 10);
    const businessId = user.rows[0].business_id;
    const result = await pool.query(
      `INSERT INTO users (username, full_name, password_hash, user_type, role, business_id, parent_user_id, is_staff, is_active, max_devices, trial_expires_at)
       VALUES ($1, $2, $3, 'admin', $4, $5, $6, true, true, 2, NOW() + INTERVAL '365 days') RETURNING id, username, full_name, role`,
      [username, fullName, hash, staffRole, businessId, req.userId]
    );
    res.json({ success: true, data: { staff: result.rows[0] } });
  } catch (e) {
    if (e.code === '23505') return res.status(400).json({ success: false, error: 'Username already exists' });
    res.status(500).json({ success: false, error: e.message });
  }
});

// Update staff (owner only)
app.put('/api/business/staff/:staffId', verifyToken, async (req, res) => {
  try {
    const user = await pool.query('SELECT * FROM users WHERE id = $1', [req.userId]);
    if (!user.rows[0] || user.rows[0].role !== 'owner') {
      return res.status(403).json({ success: false, error: 'Owner access required' });
    }
    const { role, is_active } = req.body;
    const businessId = user.rows[0].business_id;
    await pool.query(
      'UPDATE users SET role = COALESCE($1, role), is_active = COALESCE($2, is_active) WHERE id = $3 AND business_id = $4',
      [role, is_active, req.params.staffId, businessId]
    );
    res.json({ success: true });
  } catch (e) { res.status(500).json({ success: false, error: e.message }); }
});

// Delete staff (owner only)
app.delete('/api/business/staff/:staffId', verifyToken, async (req, res) => {
  try {
    const user = await pool.query('SELECT * FROM users WHERE id = $1', [req.userId]);
    if (!user.rows[0] || user.rows[0].role !== 'owner') {
      return res.status(403).json({ success: false, error: 'Owner access required' });
    }
    const businessId = user.rows[0].business_id;
    await pool.query('DELETE FROM users WHERE id = $1 AND business_id = $2 AND is_staff = true', [req.params.staffId, businessId]);
    res.json({ success: true });
  } catch (e) { res.status(500).json({ success: false, error: e.message }); }
});

// Get user role/permissions (for app RBAC)
app.get('/api/auth/me', verifyToken, async (req, res) => {
  try {
    const result = await pool.query('SELECT id, username, full_name, role, is_staff, business_id, is_active FROM users WHERE id = $1', [req.userId]);
    if (!result.rows[0]) return res.status(404).json({ success: false, error: 'User not found' });
    res.json({ success: true, data: { user: result.rows[0] } });
  } catch (e) { res.status(500).json({ success: false, error: e.message }); }
});

// Get staff activity (manager/owner) - per-staff vehicle counts, revenue, last active
app.get('/api/business/staff/activity', verifyToken, async (req, res) => {
  try {
    const user = await pool.query('SELECT * FROM users WHERE id = $1', [req.userId]);
    if (!user.rows[0] || !['owner', 'manager'].includes(user.rows[0].role)) {
      return res.status(403).json({ success: false, error: 'Manager/Owner access required' });
    }
    const businessId = user.rows[0].business_id;
    const { period } = req.query; // today, week, month
    
    let dateFilter = "AND v.entry_time >= CURRENT_DATE";
    if (period === 'week') dateFilter = "AND v.entry_time >= CURRENT_DATE - INTERVAL '7 days'";
    if (period === 'month') dateFilter = "AND v.entry_time >= CURRENT_DATE - INTERVAL '30 days'";

    const result = await pool.query(`
      SELECT 
        u.id, u.username, u.full_name, u.role, u.last_login_at,
        COUNT(v.id) FILTER (WHERE v.status = 'parked') as vehicles_parked,
        COUNT(v.id) FILTER (WHERE v.status = 'exited') as vehicles_exited,
        COALESCE(SUM(v.amount) FILTER (WHERE v.status = 'exited'), 0) as revenue_collected
      FROM users u
      LEFT JOIN vehicles v ON v.user_id = u.id ${dateFilter}
      WHERE u.business_id = $1
      GROUP BY u.id, u.username, u.full_name, u.role, u.last_login_at
      ORDER BY revenue_collected DESC
    `, [businessId]);

    res.json({ success: true, data: { staff: result.rows } });
  } catch (e) { res.status(500).json({ success: false, error: e.message }); }
});

// ================================
// ADMIN PANEL ENDPOINTS (for ParkEase tab)
// ================================

app.get('/api/admin/parkease/stats', adminGuard, async (req, res) => {
  try {
    const users = await pool.query('SELECT COUNT(*) as count FROM users');
    const vehicles = await pool.query('SELECT COUNT(*) as count FROM vehicles');
    const parked = await pool.query("SELECT COUNT(*) as count FROM vehicles WHERE status = 'parked'");
    const revenue = await pool.query("SELECT COALESCE(SUM(amount), 0) as total FROM vehicles WHERE status = 'exited'");
    res.json({ success: true, data: { totalUsers: users.rows[0].count, totalVehicles: vehicles.rows[0].count, currentlyParked: parked.rows[0].count, totalRevenue: revenue.rows[0].total } });
  } catch (e) { res.status(500).json({ success: false, error: e.message }); }
});

app.get('/api/admin/parkease/users', adminGuard, async (req, res) => {
  try {
    const result = await pool.query('SELECT id, username, full_name, email, role, user_type, is_active, is_staff, business_id, last_login_at, created_at FROM users ORDER BY created_at DESC');
    res.json({ success: true, data: { users: result.rows } });
  } catch (e) { res.status(500).json({ success: false, error: e.message }); }
});

app.get('/api/admin/parkease/vehicles', adminGuard, async (req, res) => {
  try {
    const { status, limit } = req.query;
    let query = 'SELECT * FROM vehicles';
    const params = [];
    if (status) { query += ' WHERE status = $1'; params.push(status); }
    query += ' ORDER BY entry_time DESC LIMIT $' + (params.length + 1);
    params.push(parseInt(limit) || 100);
    const result = await pool.query(query, params);
    res.json({ success: true, data: { vehicles: result.rows } });
  } catch (e) { res.status(500).json({ success: false, error: e.message }); }
});

app.post('/api/admin/parkease/users/:userId/toggle', adminGuard, async (req, res) => {
  try {
    const { is_active } = req.body;
    await pool.query('UPDATE users SET is_active = $1 WHERE id = $2', [is_active, req.params.userId]);
    res.json({ success: true });
  } catch (e) { res.status(500).json({ success: false, error: e.message }); }
});

// Extend subscription
app.post('/api/admin/parkease/users/:userId/subscription', adminGuard, async (req, res) => {
  try {
    const { days, max_devices, multi_device_enabled } = req.body;
    const updates = [];
    const params = [];
    let idx = 1;
    if (days) { updates.push(`subscription_expires_at = NOW() + INTERVAL '${parseInt(days)} days'`); }
    if (max_devices !== undefined) { updates.push(`max_devices = $${idx}`); params.push(max_devices); idx++; }
    if (multi_device_enabled !== undefined) { updates.push(`multi_device_enabled = $${idx}`); params.push(multi_device_enabled); idx++; }
    if (updates.length === 0) return res.status(400).json({ success: false, error: 'No updates provided' });
    params.push(req.params.userId);
    await pool.query(`UPDATE users SET ${updates.join(', ')} WHERE id = $${idx}`, params);
    res.json({ success: true });
  } catch (e) { res.status(500).json({ success: false, error: e.message }); }
});

// Global error handler
app.use((error, req, res, next) => {
  console.error('Unhandled error:', error);
  res.status(500).json({ success: false, error: 'Internal server error' });
});

// Catch-all: serve landing page for non-API, non-file routes
app.use((req, res, next) => {
  if (req.path.startsWith('/api/')) {
    return res.status(404).json({ success: false, error: 'Endpoint not found' });
  }
  // If no static file matched, serve index.html for SPA routing
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Run database migrations on startup
const runStartupMigrations = require('./scripts/startup-migration');
(async () => {
  try {
    await runStartupMigrations(pool);
  } catch (error) {
    console.error('Migration error during startup:', error);
    // Continue running even if migrations fail
  }

  // Start server
  app.listen(PORT, () => {
    console.log(`🚀 ParkEase Backend Server running on port ${PORT}`);
    console.log(`📊 Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`🔗 Health check: http://localhost:${PORT}/health`);
  });
})();

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  pool.end(() => {
    console.log('Database pool closed');
    process.exit(0);
  });
});

module.exports = app;// Force redeploy Sun, Dec 21, 2025  1:24:22 PM
