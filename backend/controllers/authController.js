/**
 * Authentication Controller
 * Handles all authentication logic with proper error handling
 */

const bcrypt = require('bcryptjs');
const { generateTokens, invalidateSession, invalidateUserSessions } = require('../middleware/session');

class AuthController {
  constructor(pool) {
    this.pool = pool;
  }

  /**
   * Login user with device management
   */
  async login(req, res) {
    // Support both camelCase and snake_case (due to transform middleware)
    const {
      username,
      password,
      deviceId, device_id,
      deviceName, device_name,
      platform
    } = req.body;

    // Use whichever format was provided
    const finalDeviceId = deviceId || device_id;
    const finalDeviceName = deviceName || device_name;

    try {
      // Validate input
      if (!username) {
        return res.status(400).json({
          success: false,
          error: 'Username is required'
        });
      }

      if (!finalDeviceId) {
        return res.status(400).json({
          success: false,
          error: 'Device ID is required'
        });
      }

      // Find user
      const userResult = await this.pool.query(
        'SELECT * FROM users WHERE username = $1 AND is_active = true',
        [username.toLowerCase()]
      );

      if (userResult.rows.length === 0) {
        return res.status(401).json({
          success: false,
          error: 'Invalid credentials'
        });
      }

      const user = userResult.rows[0];

      // Verify password for non-guest users
      if (user.user_type !== 'guest') {
        if (!password) {
          return res.status(400).json({
            success: false,
            error: 'Password is required'
          });
        }

        // Check if user has password
        if (!user.password_hash) {
          // Set a default password for old users
          const defaultPassword = 'password123';
          const hashedPassword = await bcrypt.hash(defaultPassword, 10);
          await this.pool.query(
            'UPDATE users SET password_hash = $1 WHERE id = $2',
            [hashedPassword, user.id]
          );
          user.password_hash = hashedPassword;
        }

        const isValidPassword = await bcrypt.compare(password, user.password_hash);
        if (!isValidPassword) {
          return res.status(401).json({
            success: false,
            error: 'Invalid credentials'
          });
        }
      } else {
        // Guest user - check device ID
        if (user.device_id && user.device_id !== finalDeviceId) {
          return res.status(401).json({
            success: false,
            error: 'Device not authorized'
          });
        }
      }

      // ========================================
      // DEVICE MANAGEMENT LOGIC
      // ========================================

      // Check if this device is already registered
      const existingDeviceResult = await this.pool.query(
        'SELECT * FROM devices WHERE device_id = $1',
        [finalDeviceId]
      );

      let deviceRecord = existingDeviceResult.rows[0];

      if (deviceRecord) {
        // Device exists - update its info and mark as active
        await this.pool.query(
          `UPDATE devices
           SET user_id = $1, device_name = $2, platform = $3,
               is_active = true, last_active_at = NOW(), updated_at = NOW()
           WHERE device_id = $4`,
          [user.id, finalDeviceName || 'Unknown Device', platform || 'Unknown', finalDeviceId]
        );
        console.log(`✅ Device ${finalDeviceId} reactivated for user ${user.id}`);
      } else {
        // New device - check if user has multi-device permission
        const activeDevicesResult = await this.pool.query(
          'SELECT COUNT(*) as count FROM devices WHERE user_id = $1 AND is_active = true',
          [user.id]
        );

        const activeDeviceCount = parseInt(activeDevicesResult.rows[0].count);
        const maxDevices = user.max_devices || 1;
        const multiDeviceEnabled = user.multi_device_enabled || false;

        if (activeDeviceCount >= maxDevices && !multiDeviceEnabled) {
          // User has reached device limit - offer to logout other devices
          const activeDevices = await this.pool.query(
            `SELECT device_id, device_name, platform, last_active_at
             FROM devices
             WHERE user_id = $1 AND is_active = true
             ORDER BY last_active_at DESC`,
            [user.id]
          );

          return res.status(403).json({
            success: false,
            error: 'Maximum device limit reached',
            code: 'DEVICE_LIMIT_REACHED',
            data: {
              maxDevices,
              currentDevices: activeDevices.rows,
              message: 'You can only login on one device at a time. Would you like to logout from other devices?'
            }
          });
        }

        // Register new device
        await this.pool.query(
          `INSERT INTO devices (user_id, device_id, device_name, platform, is_active, is_primary)
           VALUES ($1, $2, $3, $4, true, $5)`,
          [
            user.id,
            finalDeviceId,
            finalDeviceName || 'Unknown Device',
            platform || 'Unknown',
            activeDeviceCount === 0  // First device is primary
          ]
        );
        console.log(`✅ New device ${finalDeviceId} registered for user ${user.id}`);
      }

      // Generate tokens
      const tokens = await generateTokens(user.id, finalDeviceId, req);

      // Update last login
      await this.pool.query(
        'UPDATE users SET last_login_at = NOW() WHERE id = $1',
        [user.id]
      );

      // Ensure user has business_id
      if (!user.business_id) {
        const businessId = `biz_${user.id.replace(/-/g, '')}`;
        await this.pool.query(
          'UPDATE users SET business_id = $1, role = $2 WHERE id = $3',
          [businessId, 'owner', user.id]
        );
        user.business_id = businessId;
        user.role = 'owner';
      }

      // Return user data with tokens (Flutter expects 'token' not 'accessToken')
      res.json({
        success: true,
        data: {
          user: {
            id: user.id,
            username: user.username,
            fullName: user.full_name,
            email: user.username,
            userType: user.user_type,
            role: user.role || 'owner',
            businessId: user.business_id,
            trialStartsAt: user.trial_starts_at,
            trialExpiresAt: user.trial_expires_at,
            isActive: user.is_active,
            multiDeviceEnabled: user.multi_device_enabled || false,
            maxDevices: user.max_devices || 1
          },
          token: tokens.accessToken,
          refreshToken: tokens.refreshToken,
          sessionId: tokens.sessionId
        }
      });
    } catch (error) {
      console.error('Login error:', error);
      res.status(500).json({
        success: false,
        error: 'Login failed. Please try again.'
      });
    }
  }

  /**
   * Logout user
   */
  async logout(req, res) {
    try {
      // Invalidate session
      if (req.sessionId) {
        invalidateSession(req.sessionId);
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
  }

  /**
   * Guest signup with device registration
   */
  async guestSignup(req, res) {
    // Support both camelCase and snake_case (due to transform middleware)
    const {
      fullName, full_name,
      parkingName, parking_name,
      deviceId, device_id,
      deviceName, device_name,
      platform
    } = req.body;

    // Use whichever format was provided
    const finalFullName = fullName || full_name;
    const finalParkingName = parkingName || parking_name;
    const finalDeviceId = deviceId || device_id;
    const finalDeviceName = deviceName || device_name;

    try {
      if (!finalDeviceId) {
        return res.status(400).json({
          success: false,
          error: 'Device ID is required'
        });
      }

      // Generate unique username
      const username = `guest_${Date.now()}@parkease.local`;
      const businessId = `biz_${Date.now()}`;

      // Create guest user
      const userResult = await this.pool.query(
        `INSERT INTO users (
          username, full_name, device_id, user_type,
          trial_starts_at, trial_expires_at, is_active,
          business_id, role
        ) VALUES ($1, $2, $3, 'guest', NOW(), NOW() + INTERVAL '3 days', true, $4, 'owner')
        RETURNING *`,
        [username, finalFullName || finalParkingName || 'Guest User', finalDeviceId, businessId]
      );

      const user = userResult.rows[0];

      // Register device
      await this.pool.query(
        `INSERT INTO devices (user_id, device_id, device_name, platform, is_active, is_primary)
         VALUES ($1, $2, $3, $4, true, true)`,
        [user.id, finalDeviceId, finalDeviceName || 'Mobile Device', platform || 'Android']
      );
      console.log(`✅ Device ${finalDeviceId} registered for guest user ${user.id}`);

      // Generate tokens
      const tokens = await generateTokens(user.id, finalDeviceId, req);

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
          token: tokens.accessToken,
          refreshToken: tokens.refreshToken,
          sessionId: tokens.sessionId
        }
      });
    } catch (error) {
      console.error('Guest signup error:', error);
      res.status(500).json({
        success: false,
        error: 'Signup failed'
      });
    }
  }

  /**
   * Refresh token
   */
  async refreshToken(req, res) {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({
        success: false,
        error: 'Refresh token required'
      });
    }

    try {
      const jwt = require('jsonwebtoken');
      const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

      // Verify refresh token
      const decoded = jwt.verify(refreshToken, JWT_SECRET);

      if (decoded.type !== 'refresh') {
        return res.status(401).json({
          success: false,
          error: 'Invalid token type'
        });
      }

      // Generate new tokens
      const tokens = generateTokens(decoded.userId, decoded.deviceId);

      res.json({
        success: true,
        data: {
          token: tokens.accessToken,
          refreshToken: tokens.refreshToken
        }
      });
    } catch (error) {
      console.error('Refresh token error:', error);
      res.status(401).json({
        success: false,
        error: 'Invalid refresh token'
      });
    }
  }

  /**
   * Validate token
   */
  async validateToken(req, res) {
    try {
      // Token is already validated by middleware
      // Get user details
      const userResult = await this.pool.query(
        'SELECT * FROM users WHERE id = $1',
        [req.userId]
      );

      if (userResult.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: 'User not found'
        });
      }

      const user = userResult.rows[0];

      res.json({
        success: true,
        data: {
          user: {
            id: user.id,
            username: user.username,
            fullName: user.full_name,
            userType: user.user_type,
            role: user.role || 'owner',
            businessId: user.business_id
          }
        }
      });
    } catch (error) {
      console.error('Validate token error:', error);
      res.status(500).json({
        success: false,
        error: 'Validation failed'
      });
    }
  }
}

module.exports = AuthController;