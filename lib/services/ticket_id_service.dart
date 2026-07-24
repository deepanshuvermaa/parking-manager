import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'local_database_service.dart';

/// Service to generate sequential ticket IDs in format: PT{DDMM}{deviceSuffix}{serial}
/// Example: PT0910A7001, PT0910A7002, PT0910K3001 (different device)
/// Serial resets to 001 when the date changes.
/// The device suffix ensures no collisions across multiple offline devices.
///
/// Safety guarantees:
///  - Monotonic per (date, device): the serial only ever moves forward.
///  - Reinstall/clear-safe: the counter is re-seeded from the highest ticket
///    already present in the local DB, so wiping SharedPreferences can never
///    reset it to 1 and silently overwrite an existing ticket (the vehicles
///    table has a UNIQUE ticket_id index + REPLACE conflict policy).
///  - Race-safe: concurrent calls are serialized so a rapid double-entry can
///    never read the same serial twice.
class TicketIdService {
  static const String _prefixKey = 'ticket_id_prefix';
  static const String _serialKey = 'ticket_id_serial';
  static const String _deviceSuffixKey = 'ticket_device_suffix';

  /// Serializes concurrent generateNextTicketId() calls so the read-modify-write
  /// of the serial is atomic even under rapid successive entries.
  static Future<String> _chain = Future<String>.value('');

  /// Get or generate a stable 2-char device suffix (e.g. 'A7', 'K3').
  /// 36^2 = 1296 combinations → negligible collision probability between the
  /// handful of devices that share one business account. Persisted once.
  static Future<String> getDeviceSuffix() async {
    final prefs = await SharedPreferences.getInstance();
    var suffix = prefs.getString(_deviceSuffixKey);
    if (suffix == null || suffix.isEmpty) {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final rng = Random.secure();
      suffix = '${chars[rng.nextInt(chars.length)]}${chars[rng.nextInt(chars.length)]}';
      await prefs.setString(_deviceSuffixKey, suffix);
    }
    return suffix;
  }

  /// Generate next ticket ID in format PT{DDMM}{deviceSuffix}{serial}.
  /// Serialized to guarantee atomic increment.
  static Future<String> generateNextTicketId() {
    final result = _chain.then((_) => _generate());
    // Keep the chain alive even if a generation throws.
    _chain = result.catchError((_) => '');
    return result;
  }

  static Future<String> _generate() async {
    final prefs = await SharedPreferences.getInstance();

    final now = DateTime.now();
    final currentDatePrefix = 'PT${DateFormat('ddMM').format(now)}';
    final deviceSuffix = await getDeviceSuffix();
    final fullPrefix = '$currentDatePrefix$deviceSuffix';

    final storedPrefix = prefs.getString(_prefixKey);
    int currentSerial = prefs.getInt(_serialKey) ?? 0;

    // New day → reset the SharedPreferences serial baseline.
    if (storedPrefix != currentDatePrefix) {
      currentSerial = 0;
      await prefs.setString(_prefixKey, currentDatePrefix);
    }

    // Resume from the local DB in case prefs were lost (reinstall / clearAllData)
    // or a same-day ticket exists beyond the prefs value. Gap-safe: never
    // regresses, so it can never re-issue an existing ticket ID.
    try {
      final dbMax = await LocalDatabaseService.getMaxTicketSerial(fullPrefix);
      if (dbMax > currentSerial) currentSerial = dbMax;
    } catch (_) {
      // DB unavailable — fall back to the prefs value.
    }

    currentSerial++;
    await prefs.setInt(_serialKey, currentSerial);

    final serialFormatted = currentSerial.toString().padLeft(3, '0');
    return '$fullPrefix$serialFormatted';
  }

  /// Get current serial number (for debugging/display purposes)
  static Future<int> getCurrentSerial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_serialKey) ?? 0;
  }

  /// Reset serial number (for testing or manual reset)
  static Future<void> resetSerial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_serialKey, 0);
  }
}
