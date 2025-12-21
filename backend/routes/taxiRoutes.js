/**
 * Taxi Booking Routes
 * All routes require authentication
 */

const express = require('express');
const router = express.Router();

module.exports = (pool, verifyToken, checkTrialExpiry) => {
  const TaxiController = require('../controllers/taxiController');
  const controller = new TaxiController(pool);

  // Get all bookings (with filtering)
  router.get('/',
    verifyToken,
    checkTrialExpiry,
    (req, res) => controller.getBookings(req, res)
  );

  // Get single booking by ID
  router.get('/:id',
    verifyToken,
    checkTrialExpiry,
    (req, res) => controller.getBookingById(req, res)
  );

  // Create new booking
  router.post('/',
    verifyToken,
    checkTrialExpiry,
    (req, res) => controller.createBooking(req, res)
  );

  // Update booking
  router.put('/:id',
    verifyToken,
    checkTrialExpiry,
    (req, res) => controller.updateBooking(req, res)
  );

  // Start trip (booked -> ongoing)
  router.put('/:id/start',
    verifyToken,
    checkTrialExpiry,
    (req, res) => controller.startTrip(req, res)
  );

  // Complete trip (ongoing -> completed)
  router.put('/:id/complete',
    verifyToken,
    checkTrialExpiry,
    (req, res) => controller.completeTrip(req, res)
  );

  // Cancel booking
  router.put('/:id/cancel',
    verifyToken,
    checkTrialExpiry,
    (req, res) => controller.cancelBooking(req, res)
  );

  // Delete booking
  router.delete('/:id',
    verifyToken,
    checkTrialExpiry,
    (req, res) => controller.deleteBooking(req, res)
  );

  // Get analytics
  router.get('/analytics/summary',
    verifyToken,
    checkTrialExpiry,
    (req, res) => controller.getAnalytics(req, res)
  );

  return router;
};
