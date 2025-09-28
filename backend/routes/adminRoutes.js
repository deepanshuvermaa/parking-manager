/**
 * Admin management endpoints
 * Handles admin status, deletion validation, and password checks
 */

const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');

// Default admin password (should be in environment variable in production)
const ADMIN_PASSWORD_HASH = '$2a$10$YourHashedPasswordHere';

/**
 * Check admin status
 * GET /api/admin/check-status
 */
router.get('/check-status', async (req, res) => {
  try {
    const { userId } = req.query;

    // For now, check if user is the original admin
    // In production, check against admin table
    const isAdmin = userId === 'deepanshuverma966@gmail.com' ||
                   userId?.includes('admin');

    res.json({
      success: true,
      data: {
        isAdmin,
        isSuperAdmin: userId === 'deepanshuverma966@gmail.com',
        userId
      }
    });
  } catch (error) {
    console.error('Admin status check error:', error);
    res.status(500).json({ success: false, error: 'Failed to check admin status' });
  }
});

/**
 * Validate deletion code
 * POST /api/admin/validate-deletion
 */
router.post('/validate-deletion', async (req, res) => {
  try {
    const { code, itemType, itemId } = req.body;

    // Default deletion code
    const DELETION_CODE = process.env.DELETION_CODE || 'DELETE123';

    if (code === DELETION_CODE) {
      res.json({
        success: true,
        message: 'Deletion authorized',
        itemType,
        itemId
      });
    } else {
      res.status(403).json({
        success: false,
        error: 'Invalid deletion code'
      });
    }
  } catch (error) {
    console.error('Deletion validation error:', error);
    res.status(500).json({ success: false, error: 'Failed to validate deletion' });
  }
});

/**
 * Validate admin password
 * POST /api/admin/validate-password
 */
router.post('/validate-password', async (req, res) => {
  try {
    const { password, action } = req.body;

    // For development, accept the hardcoded password
    const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'Dv12062001@';

    if (password === ADMIN_PASSWORD) {
      res.json({
        success: true,
        message: 'Password validated',
        action
      });
    } else {
      res.status(403).json({
        success: false,
        error: 'Invalid admin password'
      });
    }
  } catch (error) {
    console.error('Password validation error:', error);
    res.status(500).json({ success: false, error: 'Failed to validate password' });
  }
});

module.exports = router;