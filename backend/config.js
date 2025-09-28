/**
 * Central configuration file for ParkEase Backend
 * Single source of truth for all configuration
 */

require('dotenv').config();

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
    secret: process.env.JWT_SECRET || 'your-secret-key-change-in-production',
    expiresIn: '7d',
    refreshExpiresIn: '30d',
  },

  // CORS
  cors: {
    origin: function (origin, callback) {
      // Allow requests with no origin (mobile apps, Postman, etc.)
      if (!origin) return callback(null, true);

      // Allowed origins
      const allowedOrigins = [
        'http://localhost:3000',
        'http://localhost:5000',
        'http://192.168.1.7:5000',
        'https://parkease-production-6679.up.railway.app',
        /^http:\/\/192\.168\.\d{1,3}\.\d{1,3}:\d+$/,  // Local network
        /^http:\/\/localhost:\d+$/,  // Any localhost port
      ];

      const isAllowed = allowedOrigins.some(allowed => {
        if (allowed instanceof RegExp) {
          return allowed.test(origin);
        }
        return allowed === origin;
      });

      if (isAllowed) {
        callback(null, true);
      } else {
        console.log('CORS blocked origin:', origin);
        callback(null, true); // Allow anyway in dev
      }
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept'],
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