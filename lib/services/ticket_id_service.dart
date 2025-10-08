import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Service to generate sequential ticket IDs in format: PT{DDMM}{serial}
/// Example: PT0910001, PT0910002, etc.
/// Serial resets to 001 when date changes
class TicketIdService {
  static const String _prefixKey = 'ticket_id_prefix'; // Stores current date prefix (e.g., "PT0910")
  static const String _serialKey = 'ticket_id_serial'; // Stores current serial number

  /// Generate next ticket ID in format PT{DDMM}{serial}
  static Future<String> generateNextTicketId() async {
    final prefs = await SharedPreferences.getInstance();

    // Get current date in DDMM format
    final now = DateTime.now();
    final dateFormat = DateFormat('ddMM');
    final currentDatePrefix = 'PT${dateFormat.format(now)}'; // e.g., "PT0910"

    // Get stored prefix and serial
    final storedPrefix = prefs.getString(_prefixKey);
    int currentSerial = prefs.getInt(_serialKey) ?? 0;

    // Check if date has changed (new day)
    if (storedPrefix != currentDatePrefix) {
      // Date changed - reset serial to 1
      currentSerial = 1;
      await prefs.setString(_prefixKey, currentDatePrefix);
    } else {
      // Same date - increment serial
      currentSerial++;
    }

    // Save updated serial
    await prefs.setInt(_serialKey, currentSerial);

    // Format serial as 3-digit number (001, 002, etc.)
    final serialFormatted = currentSerial.toString().padLeft(3, '0');

    // Generate final ticket ID
    final ticketId = '$currentDatePrefix$serialFormatted';

    print('✅ Generated Ticket ID: $ticketId (Serial: $currentSerial)');

    return ticketId;
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
    print('🔄 Serial number reset to 0');
  }
}
