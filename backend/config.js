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
    origin: true, // Allow all origins
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