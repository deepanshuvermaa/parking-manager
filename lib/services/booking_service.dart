import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/booking.dart';
import '../config/api_config.dart';
import 'local_database_service.dart';
import 'ticket_id_service.dart';
import 'gst_service.dart';

/// Offline-first Bookings service.
/// Mirrors SimpleVehicleService: save locally first, then fire-and-forget
/// sync to backend. Fully separate from parking/vehicles/GST logic.
class BookingService {
  static String get baseUrl => ApiConfig.baseUrl.replaceAll('/api', '');
  static List<Booking> _cachedBookings = [];
  static bool _isInitialized = false;
  static DateTime? _lastSyncTime;
  static bool _isSyncing = false;
  static Timer? _syncTimer;

  /// Generate a collision-safe local ID (UUID v4 style)
  static String _generateLocalId() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'local_${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static const String _bnPrefixKey = 'booking_number_prefix';
  static const String _bnSerialKey = 'booking_number_serial';

  /// Serializes concurrent booking-number generation so the read-modify-write
  /// of the serial is atomic under rapid successive bookings.
  static Future<String> _bnChain = Future<String>.value('');

  /// Generate a monotonic, collision-safe booking number.
  /// Format: BK{YYYYMMDD}{deviceSuffix}{serial}  e.g. BK20260723A7001
  ///  - Monotonic per (day, device); serial resets each day (intended).
  ///  - Device suffix (shared with the ticket service) prevents two offline
  ///    devices on the same account from minting the same number.
  ///  - Re-seeded from the highest booking number already in the local DB so a
  ///    reinstall / clearAllData can never reset it to 1 and duplicate.
  ///  - Serialized to guarantee atomic increment.
  static Future<String> _generateBookingNumber() {
    final result = _bnChain.then((_) => _generateBookingNumberImpl());
    _bnChain = result.catchError((_) => '');
    return result;
  }

  static Future<String> _generateBookingNumberImpl() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final ymd = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final datePrefix = 'BK$ymd';
    final deviceSuffix = await TicketIdService.getDeviceSuffix();
    final fullPrefix = '$datePrefix$deviceSuffix';

    final storedPrefix = prefs.getString(_bnPrefixKey);
    int serial = prefs.getInt(_bnSerialKey) ?? 0;

    if (storedPrefix != datePrefix) {
      serial = 0; // new day
      await prefs.setString(_bnPrefixKey, datePrefix);
    }

    // Resume from the local DB if prefs were lost or a same-day booking exists
    // beyond the prefs value. Gap-safe — never regresses.
    try {
      final dbMax = await LocalDatabaseService.getMaxBookingSerial(fullPrefix);
      if (dbMax > serial) serial = dbMax;
    } catch (_) {}

    serial++;
    await prefs.setInt(_bnSerialKey, serial);

    return '$fullPrefix${serial.toString().padLeft(3, '0')}';
  }

  // ============================================
  // INIT & SYNC
  // ============================================

  static Future<void> initialize(String token) async {
    if (_isInitialized) return;
    await GstService.refreshBookingGst();
    await _loadFromLocal();
    _isInitialized = true;
    if (token.isEmpty || token == 'offline_local_token') return;
    await _fullSync(token);
    _startPeriodicSync(token);
  }

  /// Periodic background retry — mirrors SimpleVehicleService so offline
  /// bookings & payments eventually sync even if the user never revisits the
  /// bookings screen.
  static void _startPeriodicSync(String token) {
    _syncTimer?.cancel();
    if (token.isEmpty || token == 'offline_local_token') return;
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (!_isSyncing) _fullSync(token);
    });
  }

  static void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  static Future<void> _loadFromLocal() async {
    try {
      _cachedBookings = await LocalDatabaseService.getBookings();
    } catch (e) {
      print('❌ Error loading bookings from local DB: $e');
      _cachedBookings = [];
    }
  }

  static Future<void> _fullSync(String token) async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await _pushUnsynced(token);
      await _pullFromBackend(token);
      _lastSyncTime = DateTime.now();
    } catch (e) {
      print('❌ Booking sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  static Future<void> _pullFromBackend(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/bookings'),
      headers: ApiConfig.authHeaders(token),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        final list = (data['data']['bookings'] as List)
            .map((b) => Booking.fromJson(b))
            .toList();
        await LocalDatabaseService.batchSaveBookings(list, synced: true);
        await _loadFromLocal();
        return;
      }
    }
    throw Exception('Pull bookings failed: HTTP ${response.statusCode}');
  }

  /// Push any locally-created bookings/payments that have not synced yet.
  /// A booking with a `local_` id has never reached the backend → create it.
  /// A booking with a backend id but synced=0 was marked unsynced by an OFFLINE
  /// payment → replay only the unsynced payment rows (never re-create the
  /// booking, which would duplicate it on the backend).
  static Future<void> _pushUnsynced(String token) async {
    if (token.isEmpty || token == 'offline_local_token') return;
    final unsynced = await LocalDatabaseService.getUnsyncedBookings();
    for (final b in unsynced) {
      if (b.id.startsWith('local_')) {
        await _syncSingleBooking(token, b);
      } else {
        await _pushUnsyncedPayments(token, b.id);
      }
    }
  }

  /// Replay unsynced payment rows for an already-synced booking.
  static Future<void> _pushUnsyncedPayments(String token, String bookingId) async {
    final payments = await LocalDatabaseService.getUnsyncedPaymentsForBooking(bookingId);
    for (final p in payments) {
      final ok = await _postPayment(token, bookingId, (p['amount'] as num).toDouble(), p['note'] as String?);
      if (ok) {
        await LocalDatabaseService.markPaymentSynced(p['id'] as String);
      }
    }
    // If nothing is left unsynced for this booking, mark the booking synced too.
    final remaining = await LocalDatabaseService.getUnsyncedPaymentsForBooking(bookingId);
    if (remaining.isEmpty) {
      await LocalDatabaseService.markBookingSynced(bookingId);
    }
  }

  // ============================================
  // OPERATIONS
  // ============================================

  /// Get all bookings (from cache, triggers background sync if stale)
  static Future<List<Booking>> getBookings(String token) async {
    if (!_isInitialized) {
      await initialize(token);
    }
    await GstService.refreshBookingGst();
    if (token.isNotEmpty && token != 'offline_local_token') {
      final now = DateTime.now();
      if (_lastSyncTime == null || now.difference(_lastSyncTime!).inSeconds > 60) {
        _lastSyncTime = now;
        _fullSync(token); // fire-and-forget
      }
    }
    return _cachedBookings;
  }

  /// Create a booking — save locally first, then fire-and-forget backend sync.
  static Future<Booking?> createBooking({
    required String token,
    required String customerName,
    String? customerMobile,
    String? vehicleNumber,
    String? vehicleType,
    String? driverName,
    String? driverMobile,
    String? fromLocation,
    String? toLocation,
    required double totalFare,
    double advance = 0,
    String? remarks,
  }) async {
    await GstService.refreshBookingGst();
    final paid = advance < 0 ? 0.0 : advance;
    final bookingNumber = await _generateBookingNumber();
    final booking = Booking(
      id: _generateLocalId(),
      bookingNumber: bookingNumber,
      customerName: customerName.trim(),
      customerMobile: customerMobile?.trim().isNotEmpty == true ? customerMobile!.trim() : null,
      vehicleNumber: vehicleNumber?.trim().toUpperCase(),
      vehicleType: vehicleType,
      driverName: driverName?.trim().isNotEmpty == true ? driverName!.trim() : null,
      driverMobile: driverMobile?.trim().isNotEmpty == true ? driverMobile!.trim() : null,
      fromLocation: fromLocation?.trim().isNotEmpty == true ? fromLocation!.trim() : null,
      toLocation: toLocation?.trim().isNotEmpty == true ? toLocation!.trim() : null,
      totalFare: totalFare,
      amountPaid: paid,
      status: paid >= totalFare && totalFare > 0 ? 'paid' : 'partial',
      remarks: remarks?.trim().isNotEmpty == true ? remarks!.trim() : null,
      bookingDate: DateTime.now(),
    );

    // 1. Save locally first
    try {
      await LocalDatabaseService.saveBooking(booking, synced: false);
      if (paid > 0) {
        await LocalDatabaseService.insertBookingPayment(
          id: _generateLocalId(),
          bookingId: booking.id,
          amount: paid,
          note: 'Advance',
          synced: false,
        );
      }
      _cachedBookings.insert(0, booking);
    } catch (e) {
      print('❌ Failed to save booking locally: $e');
      return null;
    }

    // 2. Fire-and-forget backend sync
    if (token.isNotEmpty && token != 'offline_local_token') {
      _syncSingleBooking(token, booking);
    }

    return booking;
  }

  static Future<void> _syncSingleBooking(String token, Booking booking) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/bookings'),
        headers: ApiConfig.authHeaders(token),
        body: jsonEncode({
          'bookingNumber': booking.bookingNumber,
          'customerName': booking.customerName,
          'customerMobile': booking.customerMobile,
          'vehicleNumber': booking.vehicleNumber,
          'vehicleType': booking.vehicleType,
          'driverName': booking.driverName,
          'driverMobile': booking.driverMobile,
          'fromLocation': booking.fromLocation,
          'toLocation': booking.toLocation,
          'totalFare': booking.totalFare,
          'amountPaid': booking.amountPaid,
          'status': booking.status,
          'remarks': booking.remarks,
          'bookingDate': booking.bookingDate.toUtc().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data']?['booking'] != null) {
          final backend = Booking.fromJson(data['data']['booking']);
          // Swap local id → backend id
          final oldId = booking.id;
          await LocalDatabaseService.deleteBooking(oldId);
          await LocalDatabaseService.saveBooking(backend, synced: true);
          final idx = _cachedBookings.indexWhere((x) => x.id == oldId);
          if (idx != -1) _cachedBookings[idx] = backend;
          print('✅ Booking synced: ${booking.bookingNumber}');
        }
      }
    } catch (e) {
      print('⚠️ Booking sync will retry: $e');
    }
  }

  /// Record a payment against a booking (multi-payment supported).
  /// Increments amount_paid, inserts a booking_payments row, updates status.
  static Future<Booking?> addPayment(String token, String bookingId, double amount, String? note) async {
    if (amount <= 0) return null;
    final idx = _cachedBookings.indexWhere((b) => b.id == bookingId);
    if (idx == -1) {
      print('❌ Booking not found in cache: $bookingId');
      return null;
    }

    final booking = _cachedBookings[idx];
    booking.amountPaid = booking.amountPaid + amount;
    booking.status = booking.amountPaid >= booking.totalFare && booking.totalFare > 0 ? 'paid' : 'partial';
    final paymentId = _generateLocalId();

    // 1. Save locally first (booking marked unsynced until payment confirmed)
    try {
      await LocalDatabaseService.updateBooking(booking, synced: false);
      await LocalDatabaseService.insertBookingPayment(
        id: paymentId,
        bookingId: bookingId,
        amount: amount,
        note: note,
        synced: false,
      );
      _cachedBookings[idx] = booking;
    } catch (e) {
      print('❌ Failed to save payment locally: $e');
      return null;
    }

    // 2. Fire-and-forget backend sync (skip if booking still has a local id —
    // it will be replayed by _pushUnsynced once the booking itself syncs).
    if (token.isNotEmpty && token != 'offline_local_token' && !bookingId.startsWith('local_')) {
      _syncPaymentToBackend(token, bookingId, paymentId, amount, note);
    }

    return booking;
  }

  static Future<void> _syncPaymentToBackend(
      String token, String bookingId, String paymentId, double amount, String? note) async {
    final ok = await _postPayment(token, bookingId, amount, note);
    if (ok) {
      await LocalDatabaseService.markPaymentSynced(paymentId);
      // Mark the booking synced only if no other unsynced payments remain.
      final remaining = await LocalDatabaseService.getUnsyncedPaymentsForBooking(bookingId);
      if (remaining.isEmpty) {
        await LocalDatabaseService.markBookingSynced(bookingId);
      }
    }
  }

  /// POST a single payment to the backend. Returns true on success.
  static Future<bool> _postPayment(String token, String bookingId, double amount, String? note) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/bookings/$bookingId/payments'),
        headers: ApiConfig.authHeaders(token),
        body: jsonEncode({'amount': amount, 'note': note}),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('⚠️ Payment sync will retry: $e');
      return false;
    }
  }
}
