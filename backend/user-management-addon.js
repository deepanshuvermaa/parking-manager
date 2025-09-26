/**
 * USER MANAGEMENT ADD-ON MODULE
 * This is a SEPARATE module that adds user management features
 * WITHOUT modifying existing server.js functionality
 *
 * To integrate: require('./user-management-addon')(app, pool, verifyToken);
 */

const bcrypt = require('bcryptjs');
const crypto = require('crypto');

module.exports = function(app, pool, verifyToken) {

  // ========================================
  // ENHANCED MIDDLEWARE (Additive only)
  // ========================================

  /**
   * Enhanced token verification that adds business context
   * This WRAPS the existing verifyToken, doesn't replace it
   */
  const verifyTokenWithBusiness = (req, res, next) => {
    // First call the original verifyToken
    verifyToken(req, res, async () => {
      try {
        // Add business context to the request
        const userResult = await pool.query(
          'SELECT business_id, role, parent_user_id FROM users WHERE id = $1',
          [req.userId]
        );

        if (userResult.rows.length === 0) {
          return res.status(404).json({ success: false, error: 'User not found' });
        }

        const user = userResult.rows[0];

        // If user doesn't have business_id (old user), create one
        if (!user.business_id) {
          const businessId = 'biz_' + req.userId.replace(/-/g, '');
          await pool.query(
            'UPDATE users SET business_id = $1, role = $2 WHERE id = $3',
            ['biz_' + req.userId.replace(/-/g, ''), 'owner', req.userId]
          );
          req.businessId = businessId;
          req.userRole = 'owner';
        } else {
          req.businessId = user.business_id;
          req.userRole = user.role || 'owner';
          req.parentUserId = user.parent_user_id;
        }

        next();
      } catch (error) {
        console.error('Error in verifyTokenWithBusiness:', error);
        res.status(500).json({ success: false, error: 'Server error' });
      }
    });
  };

  // ========================================
  // NEW ENDPOINTS (Safe namespace /api/business/*)
  // ========================================

  /**
   * Get all users in the business
   * GET /api/business/users
   */
  app.get('/api/business/users', verifyTokenWithBusiness, async (req, res) => {
    try {
      const users = await pool.query(
        `SELECT
          u.id,
          u.username,
          u.full_name,
          u.role,
          u.is_active,
          u.last_login_at,
          u.created_at,
          inviter.full_name as invited_by_name
        FROM users u
        LEFT JOIN users inviter ON u.invited_by = inviter.id
        WHERE u.business_id = $1
        ORDER BY
          CASE u.role
            WHEN 'owner' THEN 1
            WHEN 'manager' THEN 2
            WHEN 'operator' THEN 3
            ELSE 4
          END,
          u.created_at DESC`,
        [req.businessId]
      );

      res.json({
        success: true,
        data: users.rows,
        businessId: req.businessId
      });
    } catch (error) {
      console.error('Error fetching business users:', error);
      res.status(500).json({ success: false, error: 'Failed to fetch users' });
    }
  });

  /**
   * Invite a new staff member
   * POST /api/business/users/invite
   */
  app.post('/api/business/users/invite', verifyTokenWithBusiness, async (req, res) => {
    try {
      // Only owners and managers can invite
      if (req.userRole !== 'owner' && req.userRole !== 'manager') {
        return res.status(403).json({
          success: false,
          error: 'Only owners and managers can invite staff'
        });
      }

      const { email, fullName, role } = req.body;

      // Validate input
      if (!email || !fullName || !role) {
        return res.status(400).json({
          success: false,
          error: 'Email, full name, and role are required'
        });
      }

      // Check if email already exists in this business
      const existingUser = await pool.query(
        'SELECT id FROM users WHERE username = $1 AND business_id = $2',
        [email, req.businessId]
      );

      if (existingUser.rows.length > 0) {
        return res.status(409).json({
          success: false,
          error: 'User with this email already exists in your business'
        });
      }

      // Generate invitation token
      const inviteToken = crypto.randomBytes(32).toString('hex');

      // Create invitation record
      const invitation = await pool.query(
        `INSERT INTO staff_invitations
        (business_id, email, role, invited_by, invitation_token, status)
        VALUES ($1, $2, $3, $4, $5, 'pending')
        RETURNING id, email, role, invitation_token, expires_at`,
        [req.businessId, email, role, req.userId, inviteToken]
      );

      // For now, auto-accept the invitation (since we don't have email service)
      // In production, you would send an email with the invitation link

      // Create the staff user immediately (simplified flow)
      const tempPassword = crypto.randomBytes(8).toString('hex');
      const hashedPassword = await bcrypt.hash(tempPassword, 10);

      const newUser = await pool.query(
        `INSERT INTO users
        (username, full_name, password_hash, user_type, business_id, role, parent_user_id, invited_by, is_staff)
        VALUES ($1, $2, $3, 'premium', $4, $5, $6, $7, true)
        RETURNING id, username, full_name, role`,
        [email, fullName, hashedPassword, req.businessId, role, req.userId, req.userId]
      );

      // Update invitation status
      await pool.query(
        'UPDATE staff_invitations SET status = $1, accepted_at = NOW() WHERE id = $2',
        ['accepted', invitation.rows[0].id]
      );

      res.json({
        success: true,
        data: {
          user: newUser.rows[0],
          temporaryPassword: tempPassword,
          message: 'Staff member added successfully. Share these credentials with them.'
        }
      });
    } catch (error) {
      console.error('Error inviting user:', error);
      res.status(500).json({ success: false, error: 'Failed to invite user' });
    }
  });

  /**
   * Update staff member role/permissions
   * PUT /api/business/users/:userId
   */
  app.put('/api/business/users/:userId', verifyTokenWithBusiness, async (req, res) => {
    try {
      // Only owners can update roles
      if (req.userRole !== 'owner') {
        return res.status(403).json({
          success: false,
          error: 'Only owners can update staff roles'
        });
      }

      const { userId } = req.params;
      const { role, is_active } = req.body;

      // Can't modify yourself
      if (userId === req.userId) {
        return res.status(400).json({
          success: false,
          error: 'Cannot modify your own account'
        });
      }

      // Verify user belongs to same business
      const userCheck = await pool.query(
        'SELECT id FROM users WHERE id = $1 AND business_id = $2',
        [userId, req.businessId]
      );

      if (userCheck.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: 'User not found in your business'
        });
      }

      // Update user
      const updateQuery = [];
      const updateValues = [];
      let paramCount = 1;

      if (role !== undefined) {
        updateQuery.push(`role = $${paramCount++}`);
        updateValues.push(role);
      }

      if (is_active !== undefined) {
        updateQuery.push(`is_active = $${paramCount++}`);
        updateValues.push(is_active);
      }

      updateValues.push(userId);

      const updated = await pool.query(
        `UPDATE users
        SET ${updateQuery.join(', ')}, updated_at = NOW()
        WHERE id = $${paramCount}
        RETURNING id, username, full_name, role, is_active`,
        updateValues
      );

      res.json({
        success: true,
        data: updated.rows[0]
      });
    } catch (error) {
      console.error('Error updating user:', error);
      res.status(500).json({ success: false, error: 'Failed to update user' });
    }
  });

  /**
   * Remove staff member
   * DELETE /api/business/users/:userId
   */
  app.delete('/api/business/users/:userId', verifyTokenWithBusiness, async (req, res) => {
    try {
      // Only owners can remove staff
      if (req.userRole !== 'owner') {
        return res.status(403).json({
          success: false,
          error: 'Only owners can remove staff'
        });
      }

      const { userId } = req.params;

      // Can't delete yourself
      if (userId === req.userId) {
        return res.status(400).json({
          success: false,
          error: 'Cannot remove your own account'
        });
      }

      // Verify user belongs to same business and is staff
      const userCheck = await pool.query(
        'SELECT id, role FROM users WHERE id = $1 AND business_id = $2 AND is_staff = true',
        [userId, req.businessId]
      );

      if (userCheck.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: 'Staff member not found'
        });
      }

      // Soft delete - just deactivate
      await pool.query(
        'UPDATE users SET is_active = false, updated_at = NOW() WHERE id = $1',
        [userId]
      );

      res.json({
        success: true,
        message: 'Staff member removed successfully'
      });
    } catch (error) {
      console.error('Error removing user:', error);
      res.status(500).json({ success: false, error: 'Failed to remove user' });
    }
  });

  /**
   * Get current user's business info
   * GET /api/business/info
   */
  app.get('/api/business/info', verifyTokenWithBusiness, async (req, res) => {
    try {
      const businessInfo = await pool.query(
        `SELECT
          COUNT(DISTINCT u.id) as total_users,
          COUNT(DISTINCT CASE WHEN u.role = 'owner' THEN u.id END) as owners,
          COUNT(DISTINCT CASE WHEN u.role = 'manager' THEN u.id END) as managers,
          COUNT(DISTINCT CASE WHEN u.role = 'operator' THEN u.id END) as operators,
          COUNT(DISTINCT v.id) as total_vehicles,
          MIN(u.created_at) as business_created
        FROM users u
        LEFT JOIN vehicles v ON v.business_id = u.business_id
        WHERE u.business_id = $1`,
        [req.businessId]
      );

      res.json({
        success: true,
        data: {
          businessId: req.businessId,
          userRole: req.userRole,
          stats: businessInfo.rows[0]
        }
      });
    } catch (error) {
      console.error('Error fetching business info:', error);
      res.status(500).json({ success: false, error: 'Failed to fetch business info' });
    }
  });

  // ========================================
  // MODIFIED QUERIES FOR DATA ISOLATION
  // ========================================
  // These are NEW endpoints that respect business boundaries

  /**
   * Get vehicles for business (not just user)
   * GET /api/business/vehicles
   */
  app.get('/api/business/vehicles', verifyTokenWithBusiness, async (req, res) => {
    try {
      // Get all vehicles for the business, not just the user
      const vehicles = await pool.query(
        `SELECT v.*, u.full_name as entered_by
        FROM vehicles v
        LEFT JOIN users u ON v.user_id = u.id
        WHERE v.business_id = $1 OR (v.business_id IS NULL AND v.user_id = $2)
        ORDER BY v.entry_time DESC`,
        [req.businessId, req.userId]
      );

      res.json({
        success: true,
        data: vehicles.rows
      });
    } catch (error) {
      console.error('Error fetching business vehicles:', error);
      res.status(500).json({ success: false, error: 'Failed to fetch vehicles' });
    }
  });

  console.log('✅ User Management addon loaded successfully');
  console.log('   New endpoints available:');
  console.log('   - GET    /api/business/users');
  console.log('   - POST   /api/business/users/invite');
  console.log('   - PUT    /api/business/users/:userId');
  console.log('   - DELETE /api/business/users/:userId');
  console.log('   - GET    /api/business/info');
  console.log('   - GET    /api/business/vehicles');
};