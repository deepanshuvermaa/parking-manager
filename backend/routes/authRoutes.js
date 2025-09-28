/**
 * Authentication routes
 * Handles login, logout, refresh token, and guest signup
 */

const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

// Store active sessions (in production, use Redis or database)
const activeSessions = new Map();

/**
 * Generate tokens
 */
function generateTokens(userId, deviceId) {
  const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

  const accessToken = jwt.sign(
    { userId, deviceId },
    JWT_SECRET,
    { expiresIn: '7d' }
  );

  const refreshToken = jwt.sign(
    { userId, deviceId, type: 'refresh' },
    JWT_SECRET,
    { expiresIn: '30d' }
  );

  // Store session
  const sessionKey = `${userId}:${deviceId}`;
  activeSessions.set(sessionKey, {
    accessToken,
    refreshToken,
    createdAt: new Date(),
    lastActivity: new Date()
  });

  return { accessToken, refreshToken };
}

/**
 * Login
 * POST /api/auth/login
 */
router.post('/login', async (req, res) => {
  try {
    const { username, password, deviceId } = req.body;
    const pool = req.app.locals.pool || require('../db').pool;

    // Query user from database
    const userQuery = await pool.query(
      'SELECT * FROM users WHERE username = $1 AND is_active = true',
      [username]
    );

    if (userQuery.rows.length === 0) {
      return res.status(401).json({
        success: false,
        error: 'Invalid credentials'
      });
    }

    const user = userQuery.rows[0];

    // For guest users or users without password, allow login
    let passwordValid = true;
    if (user.password_hash) {
      passwordValid = await bcrypt.compare(password, user.password_hash);
    }

    if (!passwordValid) {
      return res.status(401).json({
        success: false,
        error: 'Invalid credentials'
      });
    }

    // Update last login
    await pool.query(
      'UPDATE users SET last_login_at = NOW() WHERE id = $1',
      [user.id]
    );

    // Generate tokens
    const tokens = generateTokens(user.id, deviceId || 'default');

    res.json({
      success: true,
      data: {
        user: {
          id: user.id,
          username: user.username,
          fullName: user.full_name,
          email: user.username, // Username is email
          userType: user.user_type,
          role: user.role || 'owner',
          businessId: user.business_id,
          trialStartsAt: user.trial_starts_at,
          trialExpiresAt: user.trial_expires_at
        },
        ...tokens
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      success: false,
      error: 'Login failed'
    });
  }
});

/**
 * Logout
 * POST /api/auth/logout
 */
router.post('/logout', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader?.split(' ')[1];

    if (token) {
      // Decode token to get userId and deviceId
      const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

      try {
        const decoded = jwt.verify(token, JWT_SECRET);
        const sessionKey = `${decoded.userId}:${decoded.deviceId}`;

        // Remove session
        activeSessions.delete(sessionKey);
      } catch (err) {
        // Token might be invalid, but we still return success
        console.log('Token decode error during logout:', err.message);
      }
    }

    res.json({
      success: true,
      message: 'Logged out successfully'
    });
  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({
      success: false,
      error: 'Logout failed'
    });
  }
});

/**
 * Guest Signup
 * POST /api/auth/guest-signup
 */
router.post('/guest-signup', async (req, res) => {
  try {
    const { fullName, parkingName, deviceId } = req.body;
    const pool = req.app.locals.pool || require('../db').pool;

    // Generate unique username for guest
    const username = `guest_${Date.now()}@parkease.local`;

    // Create guest user
    const userQuery = await pool.query(
      `INSERT INTO users (
        username, full_name, device_id, user_type,
        trial_starts_at, trial_expires_at, is_active,
        business_id, role
      ) VALUES ($1, $2, $3, 'guest', NOW(), NOW() + INTERVAL '3 days', true, $4, 'owner')
      RETURNING id, username, full_name, user_type, trial_starts_at, trial_expires_at, business_id`,
      [username, fullName || parkingName, deviceId, 'biz_' + Date.now()]
    );

    const user = userQuery.rows[0];

    // Generate tokens
    const tokens = generateTokens(user.id, deviceId || 'default');

    res.json({
      success: true,
      data: {
        user: {
          id: user.id,
          username: user.username,
          fullName: user.full_name,
          userType: user.user_type,
          role: 'owner',
          businessId: user.business_id,
          trialStartsAt: user.trial_starts_at,
          trialExpiresAt: user.trial_expires_at
        },
        ...tokens
      }
    });
  } catch (error) {
    console.error('Guest signup error:', error);
    res.status(500).json({
      success: false,
      error: 'Guest signup failed'
    });
  }
});

/**
 * Refresh Token
 * POST /api/auth/refresh
 */
router.post('/refresh', async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(401).json({
        success: false,
        error: 'Refresh token required'
      });
    }

    const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

    // Verify refresh token
    const decoded = jwt.verify(refreshToken, JWT_SECRET);

    if (decoded.type !== 'refresh') {
      return res.status(401).json({
        success: false,
        error: 'Invalid refresh token'
      });
    }

    // Generate new tokens
    const tokens = generateTokens(decoded.userId, decoded.deviceId);

    res.json({
      success: true,
      data: tokens
    });
  } catch (error) {
    console.error('Refresh token error:', error);
    res.status(401).json({
      success: false,
      error: 'Invalid refresh token'
    });
  }
});

/**
 * Verify token middleware
 */
router.verifyToken = (req, res, next) => {
  const authHeader = req.headers.authorization;
  const token = authHeader?.split(' ')[1];

  if (!token) {
    return res.status(401).json({
      success: false,
      error: 'No token provided'
    });
  }

  const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

  try {
    const decoded = jwt.verify(token, JWT_SECRET);

    // Check if session exists
    const sessionKey = `${decoded.userId}:${decoded.deviceId}`;
    if (!activeSessions.has(sessionKey)) {
      // Session doesn't exist, but token is valid
      // This can happen after server restart
      // Recreate session
      activeSessions.set(sessionKey, {
        accessToken: token,
        lastActivity: new Date()
      });
    } else {
      // Update last activity
      const session = activeSessions.get(sessionKey);
      session.lastActivity = new Date();
    }

    req.userId = decoded.userId;
    req.deviceId = decoded.deviceId;
    next();
  } catch (error) {
    return res.status(401).json({
      success: false,
      error: 'Invalid token'
    });
  }
};

module.exports = router;