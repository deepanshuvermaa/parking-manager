/**
 * Central configuration file for ParkEase Backend
 * Single source of truth for all configuration
 */

require('dotenv').config();

// Browser origins allowed to call this API. ADMIN_PANEL_URL is folded in so the
// admin console keeps working without having to repeat itself in CORS_ORIGINS.
// Trailing slashes are stripped: browsers send the Origin header without one,
// and the comparison is exact.
const corsOrigins = [
  process.env.CORS_ORIGINS,
  process.env.FRONTEND_URL,
  process.env.ADMIN_PANEL_URL,
  'http://localhost:3000',
]
  .filter(Boolean)
  .join(',')
  .split(',')
  .map((origin) => origin.trim().replace(/\/+$/, ''))
  .filter(Boolean);

const jwtSecret = process.env.JWT_SECRET;
if (process.env.NODE_ENV === 'production' && !jwtSecret) {
  throw new Error('JWT_SECRET must be set when NODE_ENV=production');
}

const config = {
  // Environment
  env: process.env.NODE_ENV || 'development',
  isDevelopment: process.env.NODE_ENV !== 'production',
  isProduction: process.env.NODE_ENV === 'production',

  // Server
  port: process.env.PORT || 5000,

  // Database
  database: {
    url: process.env.DATABASE_URL,
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  },

  // JWT
  jwt: {
    // Development may use a local-only value; production must provide JWT_SECRET.
    secret: jwtSecret || 'development-only-secret-change-me',
    expiresIn: '7d',
    refreshExpiresIn: '30d',
  },

  // CORS
  cors: {
    origin(origin, callback) {
      // Allow non-browser clients without an Origin header, but restrict browsers.
      if (!origin || corsOrigins.includes(origin.replace(/\/+$/, ''))) {
        return callback(null, true);
      }
      // Deny without throwing. Passing an Error here makes the cors middleware
      // hand it to Express, which answers 500 and logs "Unhandled error" for
      // what is a routine rejection. Returning false omits the
      // Access-Control-Allow-Origin header instead: the browser still blocks
      // the call, but the server stays quiet and returns a normal response.
      return callback(null, false);
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept', 'X-Admin-Key'],
    exposedHeaders: ['Content-Range', 'X-Content-Range'],
  },

  // Features
  features: {
    userManagement: process.env.ENABLE_USER_MANAGEMENT !== 'false',
    deviceSync: process.env.ENABLE_DEVICE_SYNC !== 'false',
    adminPanel: process.env.ENABLE_ADMIN_PANEL !== 'false',
  },

  // API URLs (for documentation/reference)
  api: {
    baseUrl: process.env.NODE_ENV === 'production'
      ? 'https://parkease-production-6679.up.railway.app/api'
      : `http://localhost:${process.env.PORT || 5000}/api`,
  },

  // Rate limiting
  rateLimit: {
    windowMs: 1 * 60 * 1000, // 1 minute
    max: 100, // 100 requests per minute
    enabled: process.env.NODE_ENV === 'production',
  },
};

module.exports = config;