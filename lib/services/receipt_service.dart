import 'package:shared_preferences/shared_preferences.dart';
import '../models/simple_vehicle.dart';
import '../utils/helpers.dart';

class ReceiptService {
  // ESC/POS Commands for formatting
  static const String ESC_BOLD_ON = '\x1B\x45\x01';
  static const String ESC_BOLD_OFF = '\x1B\x45\x00';

  /// Helper function to make text bold (Option A: Just bold, not bigger)
  static String boldText(String text) {
    return '$ESC_BOLD_ON$text$ESC_BOLD_OFF';
  }

  // Generate entry receipt
  static Future<String> generateEntryReceipt(SimpleVehicle vehicle) async {
    final prefs = await SharedPreferences.getInstance();

    // Get business details
    final businessName = prefs.getString('business_name') ?? 'ParkEase Parking';
    final businessAddress = prefs.getString('business_address') ?? '';
    final businessPhone = prefs.getString('business_phone') ?? '';
    final receiptHeader = prefs.getString('receipt_header') ?? 'Welcome to our parking';
    final receiptFooter = prefs.getString('receipt_footer') ?? 'Thank you for parking with us!';
    final paperWidth = prefs.getInt('paper_width') ?? 32; // Default 2" paper

    // Get bill format settings
    final showBusinessName = prefs.getBool('bill_show_business_name') ?? true;
    final showBusinessAddress = prefs.getBool('bill_show_business_address') ?? true;
    final showBusinessPhone = prefs.getBool('bill_show_business_phone') ?? true;
    final showReceiptHeader = prefs.getBool('bill_show_receipt_header') ?? true;
    final showReceiptFooter = prefs.getBool('bill_show_receipt_footer') ?? true;
    final showRateInfo = prefs.getBool('bill_show_rate_info') ?? true;
    final showNotes = prefs.getBool('bill_show_notes') ?? true;

    // Get rate info
    final hourlyRate = vehicle.hourlyRate ?? 0;
    final minimumRate = vehicle.minimumRate ?? 0;

    // Build receipt
    final receipt = StringBuffer();
    final divider = '=' * paperWidth;

    // Header
    receipt.writeln(divider);
    if (showBusinessName) {
      receipt.writeln(centerText(businessName, paperWidth));
    }
    if (showBusinessAddress && businessAddress.isNotEmpty) {
      receipt.writeln(centerText(businessAddress, paperWidth));
    }
    if (showBusinessPhone && businessPhone.isNotEmpty) {
      receipt.writeln(centerText(businessPhone, paperWidth));
    }
    receipt.writeln(divider);
    receipt.writeln(centerText('PARKING RECEIPT', paperWidth));
    receipt.writeln(divider);

    // Receipt header message
    if (showReceiptHeader && receiptHeader.isNotEmpty) {
      receipt.writeln(wrapText(receiptHeader, paperWidth));
      receipt.writeln('-' * paperWidth);
    }

    // Ticket details - Ticket ID on separate line (bold, no wrapping)
    receipt.writeln('Ticket ID:');
    receipt.writeln(boldText(vehicle.ticketId ?? 'N/A'));
    receipt.writeln('Date: ${Helpers.formatDate(vehicle.entryTime)}');
    receipt.writeln('Entry Time: ${Helpers.formatTime(vehicle.entryTime)}');
    receipt.writeln('-' * paperWidth);

    // Vehicle details - Vehicle Number on separate line (bold, no wrapping)
    receipt.writeln('Vehicle No:');
    receipt.writeln(boldText(vehicle.vehicleNumber));
    receipt.writeln('Vehicle Type: ${vehicle.vehicleType}');
    receipt.writeln('-' * paperWidth);

    // Rate information
    if (showRateInfo) {
      receipt.writeln('Rate Information:');
      receipt.writeln('Hourly Rate: Rs. ${hourlyRate.toStringAsFixed(2)}');
      receipt.writeln('Minimum Charge: Rs. ${minimumRate.toStringAsFixed(2)}');
      receipt.writeln('-' * paperWidth);
    }

    // Notes if any
    if (showNotes && vehicle.notes != null && vehicle.notes!.isNotEmpty) {
      receipt.writeln('Notes: ${vehicle.notes}');
      receipt.writeln('-' * paperWidth);
    }

    // Footer message
    if (showReceiptFooter && receiptFooter.isNotEmpty) {
      receipt.writeln(wrapText(receiptFooter, paperWidth));
      receipt.writeln('-' * paperWidth);
    }
    receipt.writeln(divider);
    receipt.writeln(centerText('KEEP THIS RECEIPT SAFE', paperWidth));
    receipt.writeln(divider);

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
    final paperWidth = prefs.getInt('paper_width') ?? 32; // Default 2" paper

    // Get bill format settings
    final showBusinessName = prefs.getBool('bill_show_business_name') ?? true;
    final showBusinessAddress = prefs.getBool('bill_show_business_address') ?? true;
    final showBusinessPhone = prefs.getBool('bill_show_business_phone') ?? true;
    final showGstNumber = prefs.getBool('bill_show_gst_number') ?? true;
    final showReceiptFooter = prefs.getBool('bill_show_receipt_footer') ?? true;
    final showNotes = prefs.getBool('bill_show_notes') ?? true;

    // Calculate duration string
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final durationStr = hours > 0
        ? '$hours hr ${minutes} min'
        : '$minutes minutes';

    // Build receipt
    final receipt = StringBuffer();
    final divider = '=' * paperWidth;
    final dashLine = '-' * paperWidth;

    // Header
    receipt.writeln(divider);
    if (showBusinessName) {
      receipt.writeln(centerText(businessName, paperWidth));
    }
    if (showBusinessAddress && businessAddress.isNotEmpty) {
      receipt.writeln(centerText(businessAddress, paperWidth));
    }
    if (showBusinessPhone && businessPhone.isNotEmpty) {
      receipt.writeln(centerText(businessPhone, paperWidth));
    }
    receipt.writeln(divider);
    receipt.writeln(centerText('EXIT RECEIPT', paperWidth));
    receipt.writeln(divider);

    // Ticket details - Ticket ID on separate line (bold, no wrapping)
    receipt.writeln('Ticket ID:');
    receipt.writeln(boldText(vehicle.ticketId ?? 'N/A'));
    receipt.writeln('Date: ${Helpers.formatDate(DateTime.now())}');
    receipt.writeln(dashLine);

    // Vehicle details - Vehicle Number on separate line (bold, no wrapping)
    receipt.writeln('Vehicle No:');
    receipt.writeln(boldText(vehicle.vehicleNumber));
    receipt.writeln('Vehicle Type: ${vehicle.vehicleType}');
    receipt.writeln(dashLine);

    // Time details
    receipt.writeln('Entry: ${Helpers.formatDateTime(vehicle.entryTime)}');
    receipt.writeln('Exit: ${Helpers.formatDateTime(vehicle.exitTime ?? DateTime.now())}');
    receipt.writeln('Duration: $durationStr');
    receipt.writeln(dashLine);

    // Amount details
    receipt.writeln('');
    final amountPadding = paperWidth > 32 ? 28 : 20;
    receipt.writeln(padRight('Total Amount:', amountPadding) + padLeft('Rs. ${amount.toStringAsFixed(2)}', paperWidth - amountPadding));
    receipt.writeln('');
    receipt.writeln(divider);

    // GST if available
    if (showGstNumber && gstNumber.isNotEmpty) {
      receipt.writeln('GST No: $gstNumber');
      receipt.writeln(dashLine);
    }

    // Footer
    receipt.writeln(centerText('PAID', paperWidth));
    receipt.writeln(dashLine);
    if (showReceiptFooter && receiptFooter.isNotEmpty) {
      receipt.writeln(wrapText(receiptFooter, paperWidth));
      receipt.writeln(dashLine);
    }
    receipt.writeln(divider);
    receipt.writeln(centerText('THANK YOU! VISIT AGAIN', paperWidth));
    receipt.writeln(divider);

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