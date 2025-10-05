/**
 * Session Management Middleware
 * Handles token validation and session tracking with DATABASE PERSISTENCE
 */

const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

// JWT configuration
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';
const ACCESS_TOKEN_EXPIRY = '7d';
const REFRESH_TOKEN_EXPIRY = '30d';

// Database pool will be injected
let dbPool = null;

/**
 * Initialize session middleware with database connection
 */
function initializeSessionMiddleware(pool) {
  dbPool = pool;
  console.log('✅ Session middleware initialized with database');
}

/**
 * Generate access and refresh tokens and store in DATABASE
 */
async function generateTokens(userId, deviceId, req = null) {
  const sessionId = `${userId}_${deviceId || 'default'}_${Date.now()}`;

  const accessToken = jwt.sign(
    {
      userId,
      deviceId,
      sessionId,
      type: 'access'
    },
    JWT_SECRET,
    { expiresIn: ACCESS_TOKEN_EXPIRY }
  );

  const refreshToken = jwt.sign(
    {
      userId,
      deviceId,
      sessionId,
      type: 'refresh'
    },
    JWT_SECRET,
    { expiresIn: REFRESH_TOKEN_EXPIRY }
  );

  // Hash tokens before storing (security best practice)
  const accessTokenHash = bcrypt.hashSync(accessToken, 10);
  const refreshTokenHash = bcrypt.hashSync(refreshToken, 10);

  // Calculate expiry times
  const accessExpiry = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days
  const refreshExpiry = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days

  // Store session in DATABASE
  if (dbPool) {
    try {
      await dbPool.query(
        `INSERT INTO sessions (
          user_id, device_id, session_id, access_token_hash, refresh_token_hash,
          is_valid, expires_at, ip_address, user_agent
        ) VALUES ($1, $2, $3, $4, $5, true, $6, $7, $8)`,
        [
          userId,
          deviceId,
          sessionId,
          accessTokenHash,
          refreshTokenHash,
          accessExpiry,
          req?.ip || null,
          req?.get('User-Agent') || null
        ]
      );
      console.log(`✅ Session stored in database: ${sessionId}`);
    } catch (error) {
      console.error('❌ Failed to store session in database:', error);
    }
  }

  return { accessToken, refreshToken, sessionId };
}

/**
 * Verify and validate token from DATABASE
 */
async function verifyToken(req, res, next) {
  const authHeader = req.headers.authorization;
  const token = authHeader?.split(' ')[1];

  if (!token) {
    return res.status(401).json({
      success: false,
      error: 'No token provided',
      code: 'NO_TOKEN'
    });
  }

  try {
    // Verify JWT
    const decoded = jwt.verify(token, JWT_SECRET);

    // Check if it's an access token
    if (decoded.type === 'refresh') {
      return res.status(401).json({
        success: false,
        error: 'Invalid token type',
        code: 'INVALID_TOKEN_TYPE'
      });
    }

    // Check session validity in DATABASE
    if (dbPool) {
      const sessionResult = await dbPool.query(
        `SELECT * FROM sessions WHERE session_id = $1 AND is_valid = true AND expires_at > NOW()`,
        [decoded.sessionId]
      );

      if (sessionResult.rows.length === 0) {
        return res.status(401).json({
          success: false,
          error: 'Session expired or invalid',
          code: 'SESSION_INVALID'
        });
      }

      const session = sessionResult.rows[0];

      // Update last activity in database
      await dbPool.query(
        `UPDATE sessions SET last_activity = NOW() WHERE session_id = $1`,
        [decoded.sessionId]
      );

      // Attach user info to request
      req.userId = decoded.userId;
      req.deviceId = decoded.deviceId;
      req.sessionId = decoded.sessionId;
    } else {
      // Fallback if DB not available (shouldn't happen)
      req.userId = decoded.userId;
      req.deviceId = decoded.deviceId;
      req.sessionId = decoded.sessionId;
    }

    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        error: 'Token expired',
        code: 'TOKEN_EXPIRED'
      });
    }

    return res.status(401).json({
      success: false,
      error: 'Invalid token',
      code: 'INVALID_TOKEN'
    });
  }
}

/**
 * Invalidate session (for logout) in DATABASE
 */
async function invalidateSession(sessionId) {
  if (dbPool) {
    try {
      const result = await dbPool.query(
        `UPDATE sessions SET is_valid = false WHERE session_id = $1 RETURNING id`,
        [sessionId]
      );
      return result.rows.length > 0;
    } catch (error) {
      console.error('Error invalidating session:', error);
      return false;
    }
  }
  return false;
}

/**
 * Invalidate all sessions for a user in DATABASE
 */
async function invalidateUserSessions(userId) {
  if (dbPool) {
    try {
      const result = await dbPool.query(
        `UPDATE sessions SET is_valid = false WHERE user_id = $1 RETURNING id`,
        [userId]
      );
      return result.rows.length;
    } catch (error) {
      console.error('Error invalidating user sessions:', error);
      return 0;
    }
  }
  return 0;
}

/**
 * Invalidate all sessions except current one (for "logout other devices")
 */
async function invalidateOtherSessions(userId, currentSessionId) {
  if (dbPool) {
    try {
      const result = await dbPool.query(
        `UPDATE sessions SET is_valid = false
         WHERE user_id = $1 AND session_id != $2
         RETURNING id`,
        [userId, currentSessionId]
      );
      console.log(`✅ Invalidated ${result.rows.length} other sessions for user ${userId}`);
      return result.rows.length;
    } catch (error) {
      console.error('Error invalidating other sessions:', error);
      return 0;
    }
  }
  return 0;
}

/**
 * Clean up expired sessions from DATABASE
 */
async function cleanupExpiredSessions() {
  if (dbPool) {
    try {
      const result = await dbPool.query(
        `DELETE FROM sessions WHERE expires_at < NOW() OR (is_valid = false AND created_at < NOW() - INTERVAL '7 days')`
      );
      if (result.rowCount > 0) {
        console.log(`🧹 Cleaned up ${result.rowCount} expired sessions`);
      }
    } catch (error) {
      console.error('Error cleaning up sessions:', error);
    }
  }
}

// Run cleanup every hour
setInterval(cleanupExpiredSessions, 60 * 60 * 1000);

module.exports = {
  initializeSessionMiddleware,
  generateTokens,
  verifyToken,
  invalidateSession,
  invalidateUserSessions,
  invalidateOtherSessions,
  cleanupExpiredSessions
};