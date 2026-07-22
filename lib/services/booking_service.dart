import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/booking.dart';
import '../config/api_config.dart';
import 'local_database_service.dart';

/// Offline-first Bookings service.
/// Mirrors SimpleVehicleService: save locally first, then fire-and-forget
/// sync to backend. Fully separate from parking/vehicles/GST logic.
class BookingService {
  static String get baseUrl => ApiConfig.baseUrl.replaceAll('/api', '');
  static List<Booking> _cachedBookings = [];
  static bool _isInitialized = false;
  static DateTime? _lastSyncTime;
  static bool _isSyncing = false;

  /// Generate a collision-safe local ID (UUID v4 style)
  static String _generateLocalId() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'local_${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static String _generateBookingNumber() {
    final now = DateTime.now();
    final ymd = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final rand = Random().nextInt(9000) + 1000;
    return 'BK$ymd$rand';
  }

  // ============================================
  // INIT & SYNC
  // ============================================

  static Future<void> initialize(String token) async {
    if (_isInitialized) return;
    await _loadFromLocal();
    _isInitialized = true;
    if (token.isEmpty || token == 'offline_local_token') return;
    await _fullSync(token);
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

  /// Push any locally-created bookings that have not synced yet
  static Future<void> _pushUnsynced(String token) async {
    if (token.isEmpty || token == 'offline_local_token') return;
    final unsynced = await LocalDatabaseService.getUnsyncedBookings();
    for (final b in unsynced) {
      await _syncSingleBooking(token, b);
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
    final paid = advance < 0 ? 0.0 : advance;
    final booking = Booking(
      id: _generateLocalId(),
      bookingNumber: _generateBookingNumber(),
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

    // 1. Save locally first
    try {
      await LocalDatabaseService.updateBooking(booking, synced: false);
      await LocalDatabaseService.insertBookingPayment(
        id: _generateLocalId(),
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

    // 2. Fire-and-forget backend sync (skip if booking still has a local id)
    if (token.isNotEmpty && token != 'offline_local_token' && !bookingId.startsWith('local_')) {
      _syncPaymentToBackend(token, bookingId, amount, note);
    }

    return booking;
  }

  static Future<void> _syncPaymentToBackend(String token, String bookingId, double amount, String? note) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/bookings/$bookingId/payments'),
        headers: ApiConfig.authHeaders(token),
        body: jsonEncode({'amount': amount, 'note': note}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        await LocalDatabaseService.markBookingSynced(bookingId);
      }
    } catch (e) {
      print('⚠️ Payment sync will retry: $e');
    }
  }
}
