import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

/// ESC/POS Formatter Service
/// Converts receipts to ESC/POS thermal printer format
/// Works with 58mm and 80mm thermal printers
class EscPosFormatterService {
  /// Generate ESC/POS receipt bytes
  /// paperSize: PaperSize.mm58 or PaperSize.mm80
  static Future<List<int>> formatReceipt({
    required String businessName,
    required String address,
    required List<ReceiptItem> items,
    required double total,
    String? phone,
    String? receiptNo,
    DateTime? dateTime,
    PaperSize paperSize = PaperSize.mm80,
    bool cutPaper = true,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);
    final bytes = <int>[];

    // Initialize printer
    bytes.addAll(generator.reset());

    // Header - Business name (bold, center, large)
    bytes.addAll(generator.text(
      businessName,
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    ));

    // Address (center, normal)
    if (address.isNotEmpty) {
      bytes.addAll(generator.text(
        address,
        styles: const PosStyles(align: PosAlign.center),
      ));
    }

    // Phone (center, normal)
    if (phone != null && phone.isNotEmpty) {
      bytes.addAll(generator.text(
        'Tel: $phone',
        styles: const PosStyles(align: PosAlign.center),
      ));
    }

    // Separator line
    bytes.addAll(generator.text('=' * (paperSize == PaperSize.mm80 ? 48 : 32)));

    // Receipt number and date/time
    if (receiptNo != null) {
      bytes.addAll(generator.text('Receipt No: $receiptNo'));
    }

    final dt = dateTime ?? DateTime.now();
    final dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    bytes.addAll(generator.text('Date: $dateStr $timeStr'));

    // Separator line
    bytes.addAll(generator.text('-' * (paperSize == PaperSize.mm80 ? 48 : 32)));

    // Items header
    bytes.addAll(generator.row([
      PosColumn(
        text: 'Item',
        width: paperSize == PaperSize.mm80 ? 6 : 4,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: 'Qty',
        width: paperSize == PaperSize.mm80 ? 2 : 2,
        styles: const PosStyles(bold: true, align: PosAlign.center),
      ),
      PosColumn(
        text: 'Price',
        width: paperSize == PaperSize.mm80 ? 4 : 3,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
    ]));

    bytes.addAll(generator.text('-' * (paperSize == PaperSize.mm80 ? 48 : 32)));

    // Items
    for (final item in items) {
      bytes.addAll(generator.row([
        PosColumn(
          text: item.name,
          width: paperSize == PaperSize.mm80 ? 6 : 4,
        ),
        PosColumn(
          text: item.quantity.toString(),
          width: paperSize == PaperSize.mm80 ? 2 : 2,
          styles: const PosStyles(align: PosAlign.center),
        ),
        PosColumn(
          text: item.price.toStringAsFixed(2),
          width: paperSize == PaperSize.mm80 ? 4 : 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }

    // Separator line
    bytes.addAll(generator.text('=' * (paperSize == PaperSize.mm80 ? 48 : 32)));

    // Total (bold, large)
    bytes.addAll(generator.row([
      PosColumn(
        text: 'TOTAL',
        width: paperSize == PaperSize.mm80 ? 8 : 6,
        styles: const PosStyles(
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
      PosColumn(
        text: total.toStringAsFixed(2),
        width: paperSize == PaperSize.mm80 ? 4 : 3,
        styles: const PosStyles(
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          align: PosAlign.right,
        ),
      ),
    ]));

    // Separator line
    bytes.addAll(generator.text('=' * (paperSize == PaperSize.mm80 ? 48 : 32)));

    // Footer - Thank you message
    bytes.addAll(generator.emptyLines(1));
    bytes.addAll(generator.text(
      'Thank You!',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
      ),
    ));

    bytes.addAll(generator.text(
      'Please Come Again',
      styles: const PosStyles(align: PosAlign.center),
    ));

    // Feed paper and cut
    bytes.addAll(generator.feed(2));

    if (cutPaper) {
      bytes.addAll(generator.cut());
    }

    return bytes;
  }

  /// Generate simple parking receipt
  static Future<List<int>> formatParkingReceipt({
    required String businessName,
    required String vehicleNumber,
    required DateTime entryTime,
    DateTime? exitTime,
    required double amount,
    String? receiptNo,
    String? parkingSlot,
    PaperSize paperSize = PaperSize.mm80,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);
    final bytes = <int>[];

    // Initialize
    bytes.addAll(generator.reset());

    // Business name
    bytes.addAll(generator.text(
      businessName,
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    ));

    bytes.addAll(generator.text(
      'PARKING RECEIPT',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    ));

    bytes.addAll(generator.text('=' * (paperSize == PaperSize.mm80 ? 48 : 32)));

    // Receipt details
    if (receiptNo != null) {
      bytes.addAll(generator.text('Receipt No: $receiptNo'));
    }

    bytes.addAll(generator.text('Vehicle No: $vehicleNumber',
        styles: const PosStyles(bold: true)));

    if (parkingSlot != null) {
      bytes.addAll(generator.text('Slot: $parkingSlot'));
    }

    bytes.addAll(generator.text('-' * (paperSize == PaperSize.mm80 ? 48 : 32)));

    // Entry time
    final entryStr =
        '${entryTime.day.toString().padLeft(2, '0')}/${entryTime.month.toString().padLeft(2, '0')}/${entryTime.year} ${entryTime.hour.toString().padLeft(2, '0')}:${entryTime.minute.toString().padLeft(2, '0')}';
    bytes.addAll(generator.text('Entry: $entryStr'));

    // Exit time (if provided)
    if (exitTime != null) {
      final exitStr =
          '${exitTime.day.toString().padLeft(2, '0')}/${exitTime.month.toString().padLeft(2, '0')}/${exitTime.year} ${exitTime.hour.toString().padLeft(2, '0')}:${exitTime.minute.toString().padLeft(2, '0')}';
      bytes.addAll(generator.text('Exit:  $exitStr'));

      // Duration
      final duration = exitTime.difference(entryTime);
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      bytes.addAll(generator.text('Duration: ${hours}h ${minutes}m'));
    }

    bytes.addAll(generator.text('=' * (paperSize == PaperSize.mm80 ? 48 : 32)));

    // Amount
    bytes.addAll(generator.text(
      'AMOUNT: ₹${amount.toStringAsFixed(2)}',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ));

    bytes.addAll(generator.text('=' * (paperSize == PaperSize.mm80 ? 48 : 32)));

    // Footer
    bytes.addAll(generator.emptyLines(1));
    bytes.addAll(generator.text(
      'Thank You!',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return bytes;
  }

  /// Generate test receipt
  static Future<List<int>> formatTestReceipt({
    String businessName = 'Test Business',
    PaperSize paperSize = PaperSize.mm80,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);
    final bytes = <int>[];

    bytes.addAll(generator.reset());

    bytes.addAll(generator.text(
      businessName,
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    ));

    bytes.addAll(generator.text(
      'PRINTER TEST',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));

    bytes.addAll(generator.text('=' * (paperSize == PaperSize.mm80 ? 48 : 32)));

    bytes.addAll(generator.text('This is a test print'));
    bytes.addAll(generator.text('If you can read this,'));
    bytes.addAll(generator.text('your printer is working!'));

    bytes.addAll(generator.text('=' * (paperSize == PaperSize.mm80 ? 48 : 32)));

    final now = DateTime.now();
    bytes.addAll(generator.text(
        'Date: ${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute}'));

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return bytes;
  }
}

/// Receipt item model
class ReceiptItem {
  final String name;
  final int quantity;
  final double price;

  ReceiptItem({
    required this.name,
    required this.quantity,
    required this.price,
  });
}
