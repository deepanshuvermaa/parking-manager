const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Trust proxy for Railway deployment
app.set('trust proxy', true);

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

// Middleware
// CORS configuration - Allow mobile apps and localhost
app.use(cors({
  origin: function(origin, callback) {
    // Allow requests with no origin (mobile apps)
    if (!origin) {
      return callback(null, true);
    }

    // Allow any localhost port for development
    if (origin.startsWith('http://localhost:') ||
        origin.startsWith('https://deepanshuvermaa.github.io')) {
      return callback(null, true);
    }

    // Allow all origins for now (can be restricted later)
    return callback(null, true);
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Rate limiting - temporarily disabled for debugging
// const limiter = rateLimit({
//   windowMs: 15 * 60 * 1000, // 15 minutes
//   max: 100, // limit each IP to 100 requests per windowMs
//   message: 'Too many requests from this IP, please try again later.',
//   trustProxy: true
// });
// app.use('/api/', limiter);

// JWT Secret
const JWT_SECRET = process.env.JWT_SECRET || 'parkease-super-secret-key-2024';
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'parkease-refresh-secret-key-2024';

// Utility functions
const generateTokens = (userId) => {
  const token = jwt.sign({ userId }, JWT_SECRET, { expiresIn: '1h' });
  const refreshToken = jwt.sign({ userId }, JWT_REFRESH_SECRET, { expiresIn: '7d' });
  return { token, refreshToken };
};

const verifyToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ success: false, error: 'Access token required' });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ success: false, error: 'Invalid or expired token' });
    }
    req.userId = user.userId;
    next();
  });
};

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

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// ================================
// AUTHENTICATION ENDPOINTS
// ================================

// User Registration (Guest Signup)
app.post('/api/auth/guest-signup', async (req, res) => {
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

// Full signup endpoint (with password)
app.post('/api/auth/signup', async (req, res) => {
  try {
    const { email, password, fullName, deviceId } = req.body;

    if (!email || !password || !fullName || !deviceId) {
      return res.status(400).json({
        success: false,
        error: 'Email, password, full name, and device ID are required'
      });
    }

    // Check if email already exists
    const existingUser = await pool.query(
      'SELECT id FROM users WHERE username = $1',
      [email]
    );

    if (existingUser.rows.length > 0) {
      return res.status(409).json({
        success: false,
        error: 'Email already registered'
      });
    }

    // Hash password
    const passwordHash = await bcrypt.hash(password, 10);

    // Create new user with password (premium = registered user with trial)
    const userResult = await pool.query(
      `INSERT INTO users (username, full_name, password_hash, device_id, user_type, trial_starts_at, trial_expires_at)
       VALUES ($1, $2, $3, $4, 'premium', NOW(), NOW() + INTERVAL '7 days')
       RETURNING id, username, full_name, user_type, trial_expires_at`,
      [email, fullName, passwordHash, deviceId]
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
          {"name": "SUV", "hourlyRate": 30, "dailyRate": 300, "monthlyRate": 7500, "minimumCharge": 30, "freeMinutes": 15},
          {"name": "Auto Rickshaw", "hourlyRate": 15, "dailyRate": 150, "monthlyRate": 3500, "minimumCharge": 15, "freeMinutes": 10},
          {"name": "E-Rickshaw", "hourlyRate": 12, "dailyRate": 120, "monthlyRate": 3000, "minimumCharge": 12, "freeMinutes": 10},
          {"name": "Cycle", "hourlyRate": 5, "dailyRate": 50, "monthlyRate": 1200, "minimumCharge": 5, "freeMinutes": 30},
          {"name": "E-Cycle", "hourlyRate": 8, "dailyRate": 80, "monthlyRate": 2000, "minimumCharge": 8, "freeMinutes": 20},
          {"name": "Tempo", "hourlyRate": 25, "dailyRate": 250, "monthlyRate": 6000, "minimumCharge": 25, "freeMinutes": 10},
          {"name": "Mini Truck", "hourlyRate": 35, "dailyRate": 350, "monthlyRate": 8000, "minimumCharge": 35, "freeMinutes": 10},
          {"name": "Van", "hourlyRate": 25, "dailyRate": 250, "monthlyRate": 6000, "minimumCharge": 25, "freeMinutes": 15},
          {"name": "Bus", "hourlyRate": 50, "dailyRate": 500, "monthlyRate": 12000, "minimumCharge": 50, "freeMinutes": 10},
          {"name": "Truck", "hourlyRate": 60, "dailyRate": 600, "monthlyRate": 15000, "minimumCharge": 60, "freeMinutes": 10}
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
          email: user.username,
          isGuest: false,
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

// User Login
app.post('/api/auth/login', async (req, res) => {
  try {
    const { username, password, deviceId } = req.body;

    if (!username || !deviceId) {
      return res.status(400).json({
        success: false,
        error: 'Username and device ID are required'
      });
    }

    // Find user
    const userResult = await pool.query(
      'SELECT * FROM users WHERE username = $1 AND is_active = true',
      [username]
    );

    if (userResult.rows.length === 0) {
      return res.status(401).json({ success: false, error: 'Invalid credentials' });
    }

    const user = userResult.rows[0];

    // Check authentication based on user type
    if (user.password_hash) {
      // User has a password - verify it
      if (!password) {
        return res.status(401).json({ success: false, error: 'Password required' });
      }
      const isPasswordValid = await bcrypt.compare(password, user.password_hash);
      if (!isPasswordValid) {
        return res.status(401).json({ success: false, error: 'Invalid credentials' });
      }
      // For users with passwords, we don't check device ID (allows login from any device)
    } else if (user.user_type === 'guest') {
      // Guest user - check device ID
      if (user.device_id !== deviceId) {
        return res.status(401).json({ success: false, error: 'Device not authorized for this account' });
      }
    } else {
      // User has no password and is not guest - this shouldn't happen
      console.error('User has no password but is not guest:', user);
      return res.status(401).json({ success: false, error: 'Account configuration error' });
    }

    // Update last login
    await pool.query(
      'UPDATE users SET last_login_at = NOW(), login_count = login_count + 1 WHERE id = $1',
      [user.id]
    );

    // Generate tokens
    const { token, refreshToken } = generateTokens(user.id);

    // Create new session
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
    await logAudit(user.id, 'user_login', 'user', user.id, null, { deviceId }, req);

    res.json({
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
      message: 'Login successful'
    });

  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// Token Refresh
app.post('/api/auth/refresh', async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(401).json({ success: false, error: 'Refresh token required' });
    }

    jwt.verify(refreshToken, JWT_REFRESH_SECRET, async (err, decoded) => {
      if (err) {
        return res.status(403).json({ success: false, error: 'Invalid refresh token' });
      }

      // Generate new tokens
      const { token, refreshToken: newRefreshToken } = generateTokens(decoded.userId);

      res.json({
        success: true,
        data: { token, refreshToken: newRefreshToken },
        message: 'Token refreshed'
      });
    });

  } catch (error) {
    console.error('Token refresh error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

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

// Logout
app.post('/api/auth/logout', verifyToken, async (req, res) => {
  try {
    // Deactivate all sessions for this user
    await pool.query(
      'UPDATE sessions SET is_active = false WHERE user_id = $1',
      [req.userId]
    );

    await logAudit(req.userId, 'user_logout', 'user', req.userId, null, null, req);

    res.json({ success: true, message: 'Logged out successfully' });

  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// ================================
// VEHICLE MANAGEMENT ENDPOINTS
// ================================

// Get Vehicles
app.get('/api/vehicles', verifyToken, async (req, res) => {
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
app.post('/api/vehicles', verifyToken, async (req, res) => {
  try {
    const {
      vehicleNumber,
      vehicleType,
      entryTime,
      hourlyRate,
      minimumRate,
      ticketId,
      notes
    } = req.body;

    if (!vehicleNumber || !vehicleType) {
      return res.status(400).json({
        success: false,
        error: 'Vehicle number and type are required'
      });
    }

    const result = await pool.query(
      `INSERT INTO vehicles (user_id, vehicle_number, vehicle_type, entry_time, hourly_rate, minimum_rate, ticket_id, notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [
        req.userId,
        vehicleNumber,
        vehicleType,
        entryTime || new Date(),
        hourlyRate,
        minimumRate,
        ticketId,
        notes
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
app.put('/api/vehicles/:id/exit', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { exitTime, amount, notes } = req.body;

    // Get current vehicle data
    const currentResult = await pool.query(
      'SELECT * FROM vehicles WHERE id = $1 AND user_id = $2',
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

    // Update vehicle
    const result = await pool.query(
      `UPDATE vehicles
       SET exit_time = $1, amount = $2, status = 'exited', duration_minutes = $3, notes = $4, updated_at = NOW()
       WHERE id = $5 AND user_id = $6
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
    console.error('Exit vehicle error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// Update Vehicle
app.put('/api/vehicles/:id', verifyToken, async (req, res) => {
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
app.delete('/api/vehicles/:id', verifyToken, async (req, res) => {
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
app.post('/api/vehicles/sync', verifyToken, async (req, res) => {
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
        data: { settings: defaultSettings.rows[0] },
        message: 'Default settings created'
      });
    } else {
      res.json({
        success: true,
        data: { settings: result.rows[0] },
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
        data: { settings: createResult.rows[0] },
        message: 'Settings created successfully'
      });
    } else {
      await logAudit(req.userId, 'settings_update', 'settings', result.rows[0].id, currentSettings, result.rows[0], req);

      res.json({
        success: true,
        data: { settings: result.rows[0] },
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
// ERROR HANDLING
// ================================

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ success: false, error: 'Endpoint not found' });
});

// Global error handler
app.use((error, req, res, next) => {
  console.error('Unhandled error:', error);
  res.status(500).json({ success: false, error: 'Internal server error' });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 ParkEase Backend Server running on port ${PORT}`);
  console.log(`📊 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🔗 Health check: http://localhost:${PORT}/health`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  pool.end(() => {
    console.log('Database pool closed');
    process.exit(0);
  });
});

module.exports = app;