/**
 * Session Management Middleware
 * Handles token validation and session tracking
 */

const jwt = require('jsonwebtoken');

// In-memory session store (use Redis in production)
const sessions = new Map();

// JWT configuration
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';
const ACCESS_TOKEN_EXPIRY = '7d';
const REFRESH_TOKEN_EXPIRY = '30d';

/**
 * Generate access and refresh tokens
 */
function generateTokens(userId, deviceId) {
  const sessionId = `${userId}_${deviceId || 'default'}`;

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

  // Store session
  sessions.set(sessionId, {
    userId,
    deviceId,
    accessToken,
    refreshToken,
    createdAt: new Date(),
    lastActivity: new Date(),
    isValid: true
  });

  return { accessToken, refreshToken, sessionId };
}

/**
 * Verify and validate token
 */
function verifyToken(req, res, next) {
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

    // Check session validity - if session not found, create a new one for valid JWTs
    let session = sessions.get(decoded.sessionId);

    if (!session || !session.isValid) {
      // If JWT is valid but session is missing (server restart), recreate session
      if (decoded.userId) {
        console.log('Recreating session for valid JWT after server restart');
        session = {
          userId: decoded.userId,
          deviceId: decoded.deviceId,
          accessToken: token,
          refreshToken: null,
          createdAt: new Date(),
          lastActivity: new Date(),
          isValid: true
        };
        sessions.set(decoded.sessionId, session);
      } else {
        return res.status(401).json({
          success: false,
          error: 'Session expired or invalid',
          code: 'SESSION_INVALID'
        });
      }
    }

    // Update last activity
    session.lastActivity = new Date();
    sessions.set(decoded.sessionId, session);

    // Attach user info to request
    req.userId = decoded.userId;
    req.deviceId = decoded.deviceId;
    req.sessionId = decoded.sessionId;

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
 * Invalidate session (for logout)
 */
function invalidateSession(sessionId) {
  const session = sessions.get(sessionId);
  if (session) {
    session.isValid = false;
    sessions.set(sessionId, session);
    return true;
  }
  return false;
}

/**
 * Invalidate all sessions for a user
 */
function invalidateUserSessions(userId) {
  let count = 0;
  for (const [sessionId, session] of sessions) {
    if (session.userId === userId) {
      session.isValid = false;
      sessions.set(sessionId, session);
      count++;
    }
  }
  return count;
}

/**
 * Clean up expired sessions
 */
function cleanupSessions() {
  const now = new Date();
  const maxAge = 30 * 24 * 60 * 60 * 1000; // 30 days

  for (const [sessionId, session] of sessions) {
    if (now - session.createdAt > maxAge) {
      sessions.delete(sessionId);
    }
  }
}

// Run cleanup every hour
setInterval(cleanupSessions, 60 * 60 * 1000);

module.exports = {
  generateTokens,
  verifyToken,
  invalidateSession,
  invalidateUserSessions,
  sessions
};