/**
 * Trial Period Validation Middleware
 * Checks if user's trial has expired before allowing API access
 */

async function checkTrialExpiry(req, res, next) {
  // Skip check if pool is not available
  if (!req.pool) {
    console.warn('⚠️ Database pool not available in request');
    return next();
  }

  try {
    // Get user from database
    const userResult = await req.pool.query(
      'SELECT user_type, trial_expires_at, is_active FROM users WHERE id = $1',
      [req.userId]
    );

    if (userResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'User not found',
        code: 'USER_NOT_FOUND'
      });
    }

    const user = userResult.rows[0];

    // Check if user is active
    if (!user.is_active) {
      return res.status(403).json({
        success: false,
        error: 'Account has been deactivated',
        code: 'ACCOUNT_DEACTIVATED'
      });
    }

    // Only check trial expiry for guest users
    if (user.user_type === 'guest') {
      const now = new Date();
      const trialExpiry = new Date(user.trial_expires_at);

      // Check if trial has expired
      if (now > trialExpiry) {
        // Calculate days expired
        const daysExpired = Math.floor((now - trialExpiry) / (1000 * 60 * 60 * 24));

        return res.status(403).json({
          success: false,
          error: 'Your 3-day free trial has expired. Please contact support to upgrade.',
          code: 'TRIAL_EXPIRED',
          data: {
            trialExpiresAt: user.trial_expires_at,
            daysExpired: daysExpired
          }
        });
      }

      // Check if trial is expiring soon (within 1 day)
      const hoursRemaining = (trialExpiry - now) / (1000 * 60 * 60);
      if (hoursRemaining < 24 && hoursRemaining > 0) {
        // Add warning to response (but still allow access)
        req.trialWarning = {
          message: 'Your trial expires in less than 24 hours',
          hoursRemaining: Math.floor(hoursRemaining),
          expiresAt: user.trial_expires_at
        };
      }
    }

    // Premium and admin users - no trial check needed
    next();

  } catch (error) {
    console.error('❌ Trial check error:', error);
    // On error, allow request to proceed (fail open)
    next();
  }
}

/**
 * Initialize trial check middleware with database pool
 */
function initializeTrialCheck(pool) {
  return (req, res, next) => {
    req.pool = pool;
    checkTrialExpiry(req, res, next);
  };
}

module.exports = {
  checkTrialExpiry,
  initializeTrialCheck
};
