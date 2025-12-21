import 'package:shared_preferences/shared_preferences.dart';
import '../models/simple_vehicle.dart';
import '../utils/helpers.dart';

class ReceiptService {
  // ESC/POS Commands for formatting
  static const String ESC_BOLD_ON = '\x1B\x45\x01';
  static const String ESC_BOLD_OFF = '\x1B\x45\x00';

  // Size commands - ALL OPTIONS for complete customization
  static const String ESC_SIZE_NORMAL = '\x1D\x21\x00';           // 1x (normal)
  static const String ESC_SIZE_1_2X = '\x1D\x21\x10';            // 1.2x width only
  static const String ESC_SIZE_1_25X = '\x1D\x21\x01';           // 1.25x height only
  static const String ESC_SIZE_1_5X = '\x1D\x21\x11';            // 1.5x (width + height)
  static const String ESC_SIZE_2X = '\x1D\x21\x22';              // 2x (double size)

  // Combined size + bold commands
  static const String ESC_SIZE_NORMAL_BOLD = '\x1D\x21\x00\x1B\x45\x01';
  static const String ESC_SIZE_1_2X_BOLD = '\x1D\x21\x10\x1B\x45\x01';
  static const String ESC_SIZE_1_25X_BOLD = '\x1D\x21\x01\x1B\x45\x01';
  static const String ESC_SIZE_1_5X_BOLD = '\x1D\x21\x11\x1B\x45\x01';
  static const String ESC_SIZE_2X_BOLD = '\x1D\x21\x22\x1B\x45\x01';
  static const String ESC_NORMAL = '\x1D\x21\x00\x1B\x45\x00';   // Reset to normal

  /// Get ESC/POS command based on size and bold settings
  static String getSizeCommand(double size, bool bold) {
    if (size >= 2.0) {
      return bold ? ESC_SIZE_2X_BOLD : ESC_SIZE_2X;
    } else if (size >= 1.5) {
      return bold ? ESC_SIZE_1_5X_BOLD : ESC_SIZE_1_5X;
    } else if (size >= 1.25) {
      return bold ? ESC_SIZE_1_25X_BOLD : ESC_SIZE_1_25X;
    } else if (size >= 1.2) {
      return bold ? ESC_SIZE_1_2X_BOLD : ESC_SIZE_1_2X;
    } else {
      return bold ? ESC_SIZE_NORMAL_BOLD : ESC_SIZE_NORMAL;
    }
  }

  /// Helper function to make text bold
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

    // Get receipt customization settings
    final businessNameBold = prefs.getBool('receipt_business_name_bold') ?? true;
    final businessNameSize = prefs.getDouble('receipt_business_name_size') ?? 1.0;
    final businessAddressBold = prefs.getBool('receipt_business_address_bold') ?? false;
    final businessAddressSize = prefs.getDouble('receipt_business_address_size') ?? 1.0;
    final businessPhoneBold = prefs.getBool('receipt_business_phone_bold') ?? false;
    final businessPhoneSize = prefs.getDouble('receipt_business_phone_size') ?? 1.0;

    final ticketIdBold = prefs.getBool('receipt_ticket_id_bold') ?? true;
    final ticketIdSize = prefs.getDouble('receipt_ticket_id_size') ?? 1.5;

    final vehicleNumberBold = prefs.getBool('receipt_vehicle_number_bold') ?? true;
    final vehicleNumberSize = prefs.getDouble('receipt_vehicle_number_size') ?? 1.5;
    final vehicleTypeBold = prefs.getBool('receipt_vehicle_type_bold') ?? true;
    final vehicleTypeSize = prefs.getDouble('receipt_vehicle_type_size') ?? 1.0;

    final travelHeaderBold = prefs.getBool('receipt_travel_header_bold') ?? true;
    final travelHeaderSize = prefs.getDouble('receipt_travel_header_size') ?? 1.25;
    final travelFromBold = prefs.getBool('receipt_travel_from_bold') ?? false;
    final travelFromSize = prefs.getDouble('receipt_travel_from_size') ?? 1.0;
    final travelToBold = prefs.getBool('receipt_travel_to_bold') ?? false;
    final travelToSize = prefs.getDouble('receipt_travel_to_size') ?? 1.0;

    final amountBold = prefs.getBool('receipt_amount_bold') ?? true;
    final amountSize = prefs.getDouble('receipt_amount_size') ?? 1.5;

    // Get rate info
    final hourlyRate = vehicle.hourlyRate ?? 0;
    final minimumRate = vehicle.minimumRate ?? 0;

    // Build receipt
    final receipt = StringBuffer();
    final divider = '=' * paperWidth;

    // Header
    receipt.writeln(divider);
    if (showBusinessName) {
      receipt.write(getSizeCommand(businessNameSize, businessNameBold));
      receipt.writeln(centerText(businessName, paperWidth));
      receipt.write(ESC_NORMAL);
    }
    if (showBusinessAddress && businessAddress.isNotEmpty) {
      receipt.write(getSizeCommand(businessAddressSize, businessAddressBold));
      receipt.writeln(centerText(businessAddress, paperWidth));
      receipt.write(ESC_NORMAL);
    }
    if (showBusinessPhone && businessPhone.isNotEmpty) {
      receipt.write(getSizeCommand(businessPhoneSize, businessPhoneBold));
      receipt.writeln(centerText(businessPhone, paperWidth));
      receipt.write(ESC_NORMAL);
    }
    receipt.writeln(divider);
    receipt.writeln(centerText('PARKING RECEIPT', paperWidth));
    receipt.writeln(divider);

    // Receipt header message
    if (showReceiptHeader && receiptHeader.isNotEmpty) {
      receipt.writeln(wrapText(receiptHeader, paperWidth));
      receipt.writeln('-' * paperWidth);
    }

    // Ticket details - Ticket ID on separate line
    receipt.writeln('Ticket ID:');
    receipt.write(getSizeCommand(ticketIdSize, ticketIdBold));
    receipt.writeln(vehicle.ticketId ?? 'N/A');
    receipt.write(ESC_NORMAL);
    receipt.writeln('Date: ${Helpers.formatDate(vehicle.entryTime)}');
    receipt.writeln('Entry Time: ${Helpers.formatTime(vehicle.entryTime)}');
    receipt.writeln('-' * paperWidth);

    // Vehicle details - Vehicle Number on separate line
    receipt.writeln('Vehicle No:');
    receipt.write(getSizeCommand(vehicleNumberSize, vehicleNumberBold));
    receipt.writeln(vehicle.vehicleNumber);
    receipt.write(ESC_NORMAL);
    receipt.write(getSizeCommand(vehicleTypeSize, vehicleTypeBold));
    receipt.writeln('Vehicle Type: ${vehicle.vehicleType}');
    receipt.write(ESC_NORMAL);
    receipt.writeln('-' * paperWidth);

    // Travel Details (if provided)
    if (vehicle.fromLocation != null && vehicle.fromLocation!.isNotEmpty ||
        vehicle.toLocation != null && vehicle.toLocation!.isNotEmpty) {
      receipt.write(getSizeCommand(travelHeaderSize, travelHeaderBold));
      receipt.writeln('TRAVEL DETAILS:');
      receipt.write(ESC_NORMAL);
      if (vehicle.fromLocation != null && vehicle.fromLocation!.isNotEmpty) {
        receipt.write(getSizeCommand(travelFromSize, travelFromBold));
        receipt.writeln('From: ${vehicle.fromLocation}');
        receipt.write(ESC_NORMAL);
      }
      if (vehicle.toLocation != null && vehicle.toLocation!.isNotEmpty) {
        receipt.write(getSizeCommand(travelToSize, travelToBold));
        receipt.writeln('To:   ${vehicle.toLocation}');
        receipt.write(ESC_NORMAL);
      }
      receipt.writeln('-' * paperWidth);
    }

    // Rate information
    if (showRateInfo) {
      receipt.writeln('Rate Information:');
      receipt.writeln('Hourly Rate: Rs. ${hourlyRate.toStringAsFixed(2)}');
      receipt.writeln('Minimum Charge: Rs. ${minimumRate.toStringAsFixed(2)}');
      receipt.writeln('-' * paperWidth);
    }

    // Notes if any - Format Owner and Phone on separate lines
    if (showNotes && vehicle.notes != null && vehicle.notes!.isNotEmpty) {
      receipt.writeln('Notes:');

      // Check if notes contain "Owner:" and "Phone:" and split them
      if (vehicle.notes!.contains('Owner:') || vehicle.notes!.contains('Phone:')) {
        // Split by comma and trim each part
        final parts = vehicle.notes!.split(',');
        for (var part in parts) {
          final trimmed = part.trim();
          if (trimmed.isNotEmpty) {
            receipt.writeln(trimmed);
          }
        }
      } else {
        // If no structured format, just print the notes as-is
        receipt.writeln(vehicle.notes);
      }
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

    // Get receipt customization settings
    final businessNameBold = prefs.getBool('receipt_business_name_bold') ?? true;
    final businessNameSize = prefs.getDouble('receipt_business_name_size') ?? 1.0;
    final businessAddressBold = prefs.getBool('receipt_business_address_bold') ?? false;
    final businessAddressSize = prefs.getDouble('receipt_business_address_size') ?? 1.0;
    final businessPhoneBold = prefs.getBool('receipt_business_phone_bold') ?? false;
    final businessPhoneSize = prefs.getDouble('receipt_business_phone_size') ?? 1.0;

    final ticketIdBold = prefs.getBool('receipt_ticket_id_bold') ?? true;
    final ticketIdSize = prefs.getDouble('receipt_ticket_id_size') ?? 1.5;

    final vehicleNumberBold = prefs.getBool('receipt_vehicle_number_bold') ?? true;
    final vehicleNumberSize = prefs.getDouble('receipt_vehicle_number_size') ?? 1.5;
    final vehicleTypeBold = prefs.getBool('receipt_vehicle_type_bold') ?? true;
    final vehicleTypeSize = prefs.getDouble('receipt_vehicle_type_size') ?? 1.0;

    final travelHeaderBold = prefs.getBool('receipt_travel_header_bold') ?? true;
    final travelHeaderSize = prefs.getDouble('receipt_travel_header_size') ?? 1.25;
    final travelFromBold = prefs.getBool('receipt_travel_from_bold') ?? false;
    final travelFromSize = prefs.getDouble('receipt_travel_from_size') ?? 1.0;
    final travelToBold = prefs.getBool('receipt_travel_to_bold') ?? false;
    final travelToSize = prefs.getDouble('receipt_travel_to_size') ?? 1.0;

    final amountBold = prefs.getBool('receipt_amount_bold') ?? true;
    final amountSize = prefs.getDouble('receipt_amount_size') ?? 1.5;

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
      receipt.write(getSizeCommand(businessNameSize, businessNameBold));
      receipt.writeln(centerText(businessName, paperWidth));
      receipt.write(ESC_NORMAL);
    }
    if (showBusinessAddress && businessAddress.isNotEmpty) {
      receipt.write(getSizeCommand(businessAddressSize, businessAddressBold));
      receipt.writeln(centerText(businessAddress, paperWidth));
      receipt.write(ESC_NORMAL);
    }
    if (showBusinessPhone && businessPhone.isNotEmpty) {
      receipt.write(getSizeCommand(businessPhoneSize, businessPhoneBold));
      receipt.writeln(centerText(businessPhone, paperWidth));
      receipt.write(ESC_NORMAL);
    }
    receipt.writeln(divider);
    receipt.writeln(centerText('EXIT RECEIPT', paperWidth));
    receipt.writeln(divider);

    // Ticket details - Ticket ID on separate line
    receipt.writeln('Ticket ID:');
    receipt.write(getSizeCommand(ticketIdSize, ticketIdBold));
    receipt.writeln(vehicle.ticketId ?? 'N/A');
    receipt.write(ESC_NORMAL);
    receipt.writeln('Date: ${Helpers.formatDate(DateTime.now())}');
    receipt.writeln(dashLine);

    // Vehicle details - Vehicle Number on separate line
    receipt.writeln('Vehicle No:');
    receipt.write(getSizeCommand(vehicleNumberSize, vehicleNumberBold));
    receipt.writeln(vehicle.vehicleNumber);
    receipt.write(ESC_NORMAL);
    receipt.write(getSizeCommand(vehicleTypeSize, vehicleTypeBold));
    receipt.writeln('Vehicle Type: ${vehicle.vehicleType}');
    receipt.write(ESC_NORMAL);
    receipt.writeln(dashLine);

    // Travel Details (if provided)
    if (vehicle.fromLocation != null && vehicle.fromLocation!.isNotEmpty ||
        vehicle.toLocation != null && vehicle.toLocation!.isNotEmpty) {
      receipt.write(getSizeCommand(travelHeaderSize, travelHeaderBold));
      receipt.writeln('TRAVEL DETAILS:');
      receipt.write(ESC_NORMAL);
      if (vehicle.fromLocation != null && vehicle.fromLocation!.isNotEmpty) {
        receipt.write(getSizeCommand(travelFromSize, travelFromBold));
        receipt.writeln('From: ${vehicle.fromLocation}');
        receipt.write(ESC_NORMAL);
      }
      if (vehicle.toLocation != null && vehicle.toLocation!.isNotEmpty) {
        receipt.write(getSizeCommand(travelToSize, travelToBold));
        receipt.writeln('To:   ${vehicle.toLocation}');
        receipt.write(ESC_NORMAL);
      }
      receipt.writeln(dashLine);
    }

    // Time details
    receipt.writeln('Entry: ${Helpers.formatDateTime(vehicle.entryTime)}');
    receipt.writeln('Exit: ${Helpers.formatDateTime(vehicle.exitTime ?? DateTime.now())}');
    receipt.writeln('Duration: $durationStr');
    receipt.writeln(dashLine);

    // Amount details
    receipt.writeln('');
    receipt.writeln('Total Amount:');
    receipt.write(getSizeCommand(amountSize, amountBold));
    receipt.writeln('Rs. ${amount.toStringAsFixed(2)}');
    receipt.write(ESC_NORMAL);
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

  // Generate taxi booking receipt
  static Future<String> generateTaxiReceipt(dynamic booking) async {
    final prefs = await SharedPreferences.getInstance();

    // Get business details
    final businessName = prefs.getString('business_name') ?? 'Go2 Parking';
    final businessPhone = prefs.getString('business_phone') ?? '';
    final paperWidth = prefs.getInt('paper_width') ?? 32;

    final receipt = StringBuffer();
    final divider = '=' * paperWidth;

    // Header
    receipt.writeln(divider);
    receipt.writeln(centerText(ESC_SIZE_1_5X_BOLD + businessName + ESC_NORMAL, paperWidth));
    if (businessPhone.isNotEmpty) {
      receipt.writeln(centerText('Tel: $businessPhone', paperWidth));
    }
    receipt.writeln(centerText('${ESC_SIZE_1_2X_BOLD}TAXI BOOKING$ESC_NORMAL', paperWidth));
    receipt.writeln(divider);

    // Ticket number
    receipt.writeln('${ESC_SIZE_1_5X_BOLD}Ticket: ${booking.ticketNumber}$ESC_NORMAL');
    receipt.writeln('Date: ${Helpers.formatDateTime(booking.bookingDate)}');
    receipt.writeln(divider);

    // Customer info
    receipt.writeln('${ESC_BOLD_ON}CUSTOMER:$ESC_BOLD_OFF');
    receipt.writeln('Name: ${booking.customerName}');
    receipt.writeln('Phone: ${booking.customerMobile}');
    receipt.writeln('');

    // Trip details
    receipt.writeln('${ESC_BOLD_ON}TRIP DETAILS:$ESC_BOLD_OFF');
    receipt.writeln('From: ${booking.fromLocation}');
    receipt.writeln('To: ${booking.toLocation}');
    receipt.writeln('');

    // Vehicle info
    receipt.writeln('${ESC_BOLD_ON}VEHICLE:$ESC_BOLD_OFF');
    receipt.writeln('${booking.vehicleName}');
    receipt.writeln('${ESC_SIZE_1_5X_BOLD}${booking.vehicleNumber}$ESC_NORMAL');
    receipt.writeln('');

    // Driver info
    receipt.writeln('${ESC_BOLD_ON}DRIVER:$ESC_BOLD_OFF');
    receipt.writeln('Name: ${booking.driverName}');
    receipt.writeln('Phone: ${booking.driverMobile}');
    receipt.writeln('');

    // Fare
    receipt.writeln(divider);
    receipt.writeln('${ESC_SIZE_2X_BOLD}FARE: ${Helpers.formatCurrency(booking.fareAmount)}$ESC_NORMAL');
    receipt.writeln(divider);

    // Status and time
    if (booking.startTime != null) {
      receipt.writeln('Start: ${Helpers.formatDateTime(booking.startTime)}');
    }
    if (booking.endTime != null) {
      receipt.writeln('End: ${Helpers.formatDateTime(booking.endTime)}');
    }
    receipt.writeln('Status: ${booking.statusDisplay}');

    // Remarks if any
    if (booking.remarks1?.isNotEmpty == true ||
        booking.remarks2?.isNotEmpty == true ||
        booking.remarks3?.isNotEmpty == true) {
      receipt.writeln('');
      receipt.writeln('${ESC_BOLD_ON}REMARKS:$ESC_BOLD_OFF');
      if (booking.remarks1?.isNotEmpty == true) receipt.writeln(booking.remarks1);
      if (booking.remarks2?.isNotEmpty == true) receipt.writeln(booking.remarks2);
      if (booking.remarks3?.isNotEmpty == true) receipt.writeln(booking.remarks3);
    }

    // Footer
    receipt.writeln(divider);
    receipt.writeln(centerText('Thank you!', paperWidth));
    receipt.writeln(centerText('Have a safe journey', paperWidth));
    receipt.writeln(divider);
    receipt.writeln('\n\n\n');

    return receipt.toString();
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