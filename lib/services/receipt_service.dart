import 'package:shared_preferences/shared_preferences.dart';
import '../models/simple_vehicle.dart';
import '../utils/helpers.dart';

class ReceiptService {
  // Generate entry receipt
  static Future<String> generateEntryReceipt(SimpleVehicle vehicle) async {
    final prefs = await SharedPreferences.getInstance();

    // Get business details
    final businessName = prefs.getString('business_name') ?? 'ParkEase Parking';
    final businessAddress = prefs.getString('business_address') ?? '';
    final businessPhone = prefs.getString('business_phone') ?? '';
    final receiptHeader = prefs.getString('receipt_header') ?? 'Welcome to our parking';
    final receiptFooter = prefs.getString('receipt_footer') ?? 'Thank you for parking with us!';

    // Get rate info
    final hourlyRate = vehicle.hourlyRate ?? 0;
    final minimumRate = vehicle.minimumRate ?? 0;

    // Build receipt
    final receipt = StringBuffer();

    // Header
    receipt.writeln('================================');
    receipt.writeln(centerText(businessName, 32));
    if (businessAddress.isNotEmpty) {
      receipt.writeln(centerText(businessAddress, 32));
    }
    if (businessPhone.isNotEmpty) {
      receipt.writeln(centerText(businessPhone, 32));
    }
    receipt.writeln('================================');
    receipt.writeln(centerText('PARKING RECEIPT', 32));
    receipt.writeln('================================');

    // Receipt header message
    if (receiptHeader.isNotEmpty) {
      receipt.writeln(wrapText(receiptHeader, 32));
      receipt.writeln('--------------------------------');
    }

    // Ticket details
    receipt.writeln('Ticket ID: ${vehicle.ticketId ?? 'N/A'}');
    receipt.writeln('Date: ${Helpers.formatDate(vehicle.entryTime)}');
    receipt.writeln('Entry Time: ${Helpers.formatTime(vehicle.entryTime)}');
    receipt.writeln('--------------------------------');

    // Vehicle details
    receipt.writeln('Vehicle No: ${vehicle.vehicleNumber}');
    receipt.writeln('Vehicle Type: ${vehicle.vehicleType}');
    receipt.writeln('--------------------------------');

    // Rate information
    receipt.writeln('Rate Information:');
    receipt.writeln('Hourly Rate: Rs. ${hourlyRate.toStringAsFixed(2)}');
    receipt.writeln('Minimum Charge: Rs. ${minimumRate.toStringAsFixed(2)}');
    receipt.writeln('--------------------------------');

    // Notes if any
    if (vehicle.notes != null && vehicle.notes!.isNotEmpty) {
      receipt.writeln('Notes: ${vehicle.notes}');
      receipt.writeln('--------------------------------');
    }

    // Footer message
    receipt.writeln(wrapText(receiptFooter, 32));
    receipt.writeln('================================');
    receipt.writeln(centerText('KEEP THIS RECEIPT SAFE', 32));
    receipt.writeln('================================');

    return receipt.toString();
  }

  // Generate exit receipt
  static Future<String> generateExitReceipt(
    SimpleVehicle vehicle,
    double amount,
    Duration duration,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Get business details
    final businessName = prefs.getString('business_name') ?? 'ParkEase Parking';
    final businessAddress = prefs.getString('business_address') ?? '';
    final businessPhone = prefs.getString('business_phone') ?? '';
    final gstNumber = prefs.getString('gst_number') ?? '';
    final receiptFooter = prefs.getString('receipt_footer') ?? 'Thank you for parking with us!';

    // Calculate duration string
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final durationStr = hours > 0
        ? '$hours hr ${minutes} min'
        : '$minutes minutes';

    // Build receipt
    final receipt = StringBuffer();

    // Header
    receipt.writeln('================================');
    receipt.writeln(centerText(businessName, 32));
    if (businessAddress.isNotEmpty) {
      receipt.writeln(centerText(businessAddress, 32));
    }
    if (businessPhone.isNotEmpty) {
      receipt.writeln(centerText(businessPhone, 32));
    }
    receipt.writeln('================================');
    receipt.writeln(centerText('EXIT RECEIPT', 32));
    receipt.writeln('================================');

    // Ticket details
    receipt.writeln('Ticket ID: ${vehicle.ticketId ?? 'N/A'}');
    receipt.writeln('Date: ${Helpers.formatDate(DateTime.now())}');
    receipt.writeln('--------------------------------');

    // Vehicle details
    receipt.writeln('Vehicle No: ${vehicle.vehicleNumber}');
    receipt.writeln('Vehicle Type: ${vehicle.vehicleType}');
    receipt.writeln('--------------------------------');

    // Time details
    receipt.writeln('Entry: ${Helpers.formatDateTime(vehicle.entryTime)}');
    receipt.writeln('Exit: ${Helpers.formatDateTime(vehicle.exitTime ?? DateTime.now())}');
    receipt.writeln('Duration: $durationStr');
    receipt.writeln('--------------------------------');

    // Amount details
    receipt.writeln('');
    receipt.writeln(padRight('Total Amount:', 20) + padLeft('Rs. ${amount.toStringAsFixed(2)}', 12));
    receipt.writeln('');
    receipt.writeln('================================');

    // GST if available
    if (gstNumber.isNotEmpty) {
      receipt.writeln('GST No: $gstNumber');
      receipt.writeln('--------------------------------');
    }

    // Footer
    receipt.writeln(centerText('PAID', 32));
    receipt.writeln('--------------------------------');
    receipt.writeln(wrapText(receiptFooter, 32));
    receipt.writeln('================================');
    receipt.writeln(centerText('THANK YOU! VISIT AGAIN', 32));
    receipt.writeln('================================');

    return receipt.toString();
  }

  // Helper function to center text
  static String centerText(String text, int width) {
    if (text.length >= width) return text;
    final padding = (width - text.length) ~/ 2;
    return ' ' * padding + text;
  }

  // Helper function to wrap text
  static String wrapText(String text, int width) {
    if (text.length <= width) return text;

    final words = text.split(' ');
    final lines = <String>[];
    var currentLine = '';

    for (final word in words) {
      if ((currentLine + word).length <= width) {
        currentLine += (currentLine.isEmpty ? '' : ' ') + word;
      } else {
        if (currentLine.isNotEmpty) {
          lines.add(currentLine);
        }
        currentLine = word;
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }

    return lines.join('\n');
  }

  // Helper function to pad text
  static String padRight(String text, int width) {
    if (text.length >= width) return text;
    return text + ' ' * (width - text.length);
  }

  static String padLeft(String text, int width) {
    if (text.length >= width) return text;
    return ' ' * (width - text.length) + text;
  }

  // Generate test receipt
  static String generateTestReceipt() {
    final receipt = StringBuffer();

    receipt.writeln('================================');
    receipt.writeln(centerText('PRINTER TEST', 32));
    receipt.writeln('================================');
    receipt.writeln('Date: ${Helpers.formatDateTime(DateTime.now())}');
    receipt.writeln('--------------------------------');
    receipt.writeln('This is a test receipt to check');
    receipt.writeln('if your printer is working');
    receipt.writeln('correctly.');
    receipt.writeln('--------------------------------');
    receipt.writeln('Characters: ABCDEFGHIJKLMNOPQR');
    receipt.writeln('Numbers: 0123456789');
    receipt.writeln('Symbols: !@#\$%^&*()_+-=[]{}');
    receipt.writeln('================================');
    receipt.writeln(centerText('TEST SUCCESSFUL', 32));
    receipt.writeln('================================');

    return receipt.toString();
  }
}