/**
 * Device management endpoints
 * Handles device registration, permissions, and sync
 */

const express = require('express');
const router = express.Router();
const { invalidateOtherSessions } = require('../middleware/session');

// Get database pool from app.locals
const getPool = (req) => req.app.locals.pool;

/**
 * Register a new device
 * POST /api/devices/register
 */
router.post('/register', async (req, res) => {
  try {
    const { deviceId, deviceName, platform, userId } = req.body;
    const pool = getPool(req);

    if (!deviceId || !userId) {
      return res.status(400).json({
        success: false,
        error: 'Device ID and User ID are required'
      });
    }

    // Check if device already exists
    const existingDevice = await pool.query(
      'SELECT * FROM devices WHERE device_id = $1',
      [deviceId]
    );

    if (existingDevice.rows.length > 0) {
      // Update existing device
      await pool.query(
        `UPDATE devices
         SET user_id = $1, device_name = $2, platform = $3,
             is_active = true, last_active_at = NOW(), updated_at = NOW()
         WHERE device_id = $4`,
        [userId, deviceName || 'Unknown Device', platform || 'Unknown', deviceId]
      );

      return res.json({
        success: true,
        data: {
          deviceId,
          deviceName,
          platform,
          userId,
          status: 'updated',
          registeredAt: existingDevice.rows[0].created_at
        }
      });
    }

    // Check user's device limit
    const user = await pool.query(
      'SELECT multi_device_enabled, max_devices FROM users WHERE id = $1',
      [userId]
    );

    if (user.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    const { multi_device_enabled, max_devices } = user.rows[0];

    // Count active devices
    const activeDevices = await pool.query(
      'SELECT COUNT(*) as count FROM devices WHERE user_id = $1 AND is_active = true',
      [userId]
    );

    const activeCount = parseInt(activeDevices.rows[0].count);

    if (activeCount >= (max_devices || 1) && !multi_device_enabled) {
      return res.status(403).json({
        success: false,
        error: 'Device limit reached',
        code: 'DEVICE_LIMIT_REACHED'
      });
    }

    // Register new device
    const result = await pool.query(
      `INSERT INTO devices (user_id, device_id, device_name, platform, is_active, is_primary)
       VALUES ($1, $2, $3, $4, true, $5)
       RETURNING *`,
      [userId, deviceId, deviceName || 'Unknown Device', platform || 'Unknown', activeCount === 0]
    );

    res.json({
      success: true,
      data: {
        deviceId: result.rows[0].device_id,
        deviceName: result.rows[0].device_name,
        platform: result.rows[0].platform,
        userId: result.rows[0].user_id,
        status: 'registered',
        registeredAt: result.rows[0].created_at
      }
    });
  } catch (error) {
    console.error('Device registration error:', error);
    res.status(500).json({ success: false, error: 'Failed to register device' });
  }
});

/**
 * Check device permission
 * GET /api/devices/check-permission
 */
router.get('/check-permission', async (req, res) => {
  try {
    const { userId, deviceId } = req.query;
    const pool = getPool(req);

    if (!userId || !deviceId) {
      return res.status(400).json({
        success: false,
        error: 'User ID and Device ID are required'
      });
    }

    // Check if device is registered and active for this user
    const deviceResult = await pool.query(
      `SELECT * FROM devices
       WHERE user_id = $1 AND device_id = $2 AND is_active = true`,
      [userId, deviceId]
    );

    const hasPermission = deviceResult.rows.length > 0;

    res.json({
      success: true,
      data: {
        hasPermission,
        deviceId,
        userId,
        device: hasPermission ? deviceResult.rows[0] : null
      }
    });
  } catch (error) {
    console.error('Device permission check error:', error);
    res.status(500).json({ success: false, error: 'Failed to check permission' });
  }
});

/**
 * Sync device data
 * POST /api/devices/sync
 */
router.post('/sync', async (req, res) => {
  try {
    const { deviceId, data } = req.body;

    // For now, just acknowledge sync
    // In production, process sync data
    res.json({
      success: true,
      message: 'Data synced successfully',
      syncedAt: new Date().toISOString()
    });
  } catch (error) {
    console.error('Device sync error:', error);
    res.status(500).json({ success: false, error: 'Failed to sync data' });
  }
});

/**
 * Logout other devices
 * POST /api/devices/logout-others
 */
router.post('/logout-others', async (req, res) => {
  try {
    const { userId, deviceId, currentSessionId } = req.body;
    const pool = getPool(req);

    if (!userId || !deviceId) {
      return res.status(400).json({
        success: false,
        error: 'User ID and Device ID are required'
      });
    }

    // Deactivate all other devices
    const result = await pool.query(
      `UPDATE devices
       SET is_active = false, updated_at = NOW()
       WHERE user_id = $1 AND device_id != $2
       RETURNING device_id, device_name`,
      [userId, deviceId]
    );

    // Invalidate all other sessions
    const sessionsInvalidated = await invalidateOtherSessions(userId, currentSessionId);

    res.json({
      success: true,
      message: 'Other devices logged out successfully',
      data: {
        currentDevice: deviceId,
        devicesLoggedOut: result.rows.length,
        sessionsInvalidated,
        loggedOutDevices: result.rows
      }
    });
  } catch (error) {
    console.error('Logout others error:', error);
    res.status(500).json({ success: false, error: 'Failed to logout other devices' });
  }
});

/**
 * Get device status
 * GET /api/devices/status
 */
router.get('/status', async (req, res) => {
  try {
    const { userId } = req.query;
    const pool = getPool(req);

    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'User ID is required'
      });
    }

    // Get user's device settings
    const user = await pool.query(
      'SELECT multi_device_enabled, max_devices FROM users WHERE id = $1',
      [userId]
    );

    if (user.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    // Get all devices for user
    const devices = await pool.query(
      `SELECT device_id, device_name, platform, is_active, is_primary, last_active_at, created_at
       FROM devices
       WHERE user_id = $1
       ORDER BY is_primary DESC, last_active_at DESC`,
      [userId]
    );

    const activeCount = devices.rows.filter(d => d.is_active).length;

    res.json({
      success: true,
      data: {
        devices: devices.rows,
        activeDevices: activeCount,
        maxDevices: user.rows[0].max_devices || 1,
        multiDeviceEnabled: user.rows[0].multi_device_enabled || false,
        canAddMore: activeCount < (user.rows[0].max_devices || 1) || user.rows[0].multi_device_enabled
      }
    });
  } catch (error) {
    console.error('Device status error:', error);
    res.status(500).json({ success: false, error: 'Failed to get device status' });
  }
});

/**
 * Enable/Disable multi-device access (Admin only)
 * PUT /api/devices/multi-device-settings
 */
router.put('/multi-device-settings', async (req, res) => {
  try {
    const { userId, multiDeviceEnabled, maxDevices } = req.body;
    const pool = getPool(req);

    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'User ID is required'
      });
    }

    await pool.query(
      `UPDATE users
       SET multi_device_enabled = $1, max_devices = $2
       WHERE id = $3`,
      [multiDeviceEnabled, maxDevices || 1, userId]
    );

    res.json({
      success: true,
      message: 'Multi-device settings updated',
      data: {
        multiDeviceEnabled,
        maxDevices: maxDevices || 1
      }
    });
  } catch (error) {
    console.error('Update multi-device settings error:', error);
    res.status(500).json({ success: false, error: 'Failed to update settings' });
  }
});

module.exports = router;