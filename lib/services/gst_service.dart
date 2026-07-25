import 'package:shared_preferences/shared_preferences.dart';

/// Single source of truth for GST. Every exit flow (dashboard, exit screen) and
/// every receipt (entry/exit/taxi) computes GST here — never inline — so the
/// on-screen total and the printed total can never drift apart again.
class GstService {
  /// Compute the GST breakdown for a charge.
  /// [isBooking] = true when the charge is a fixed booking fare, false for hourly parking.
  static Future<GstBreakdown> compute({
    required double amount,
    required bool isBooking,
    bool interState = false,
  }) async {
    final p = await SharedPreferences.getInstance();
    final enabled = p.getBool('enable_gst') ?? false;
    final onParking = p.getBool('gst_on_parking') ?? true;
    final onBooking = p.getBool('gst_on_booking') ?? true;
    final rate = _d(p, 'gst_rate', 18.0);
    final gstin = p.getString('gstin_number') ?? '';

    final applies = enabled && amount > 0 && (isBooking ? onBooking : onParking);
    final gstAmount = applies ? amount * rate / 100 : 0.0;

    // CGST/SGST/IGST split. Total tax (gstAmount) is identical either way:
    //   inter-state -> single IGST at full rate
    //   intra-state -> CGST + SGST, each at half the rate
    final igst = interState ? gstAmount : 0.0;
    final cgst = interState ? 0.0 : gstAmount / 2;
    final sgst = interState ? 0.0 : gstAmount / 2;

    return GstBreakdown(
      applies: applies,
      rate: rate,
      subtotal: amount,
      gstAmount: gstAmount,
      total: amount + gstAmount,
      gstin: gstin,
      interState: interState,
      cgst: cgst,
      sgst: sgst,
      igst: igst,
      halfRate: rate / 2,
    );
  }

  // ---------------------------------------------------------------------------
  // Cached booking GST config for SYNCHRONOUS balance math in models & UI.
  // Booking.balance / isPaid getters and the on-screen summaries must all return
  // ONE consistent GST-inclusive number without doing async prefs reads inside a
  // getter. [refreshBookingGst] is called whenever bookings are loaded/created so
  // these stay current.
  // ---------------------------------------------------------------------------
  static bool bookingGstApplies = false;
  static double bookingGstRate = 18.0;

  /// Refresh the cached booking-GST config from prefs. Call before using
  /// Booking.grandTotal / balance / isPaid so they reflect current settings.
  static Future<void> refreshBookingGst() async {
    final p = await SharedPreferences.getInstance();
    final enabled = p.getBool('enable_gst') ?? false;
    final onBooking = p.getBool('gst_on_booking') ?? true;
    bookingGstApplies = enabled && onBooking;
    bookingGstRate = _d(p, 'gst_rate', 18.0);
  }

  /// Read a double safely — legacy prefs may hold an int for a numeric key,
  /// and getDouble() throws a type-cast error on those.
  static double _d(SharedPreferences p, String key, double fallback) {
    final v = p.get(key);
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return fallback;
  }
}

class GstBreakdown {
  final bool applies;
  final double rate;
  final double subtotal;
  final double gstAmount;
  final double total;
  final String gstin;

  /// When true the charge is billed as a single IGST line (inter-state supply).
  /// When false it is split into CGST + SGST (intra-state supply).
  final bool interState;
  final double cgst;
  final double sgst;
  final double igst;

  /// Half of [rate] — the per-component rate used for CGST and SGST.
  final double halfRate;

  const GstBreakdown({
    required this.applies,
    required this.rate,
    required this.subtotal,
    required this.gstAmount,
    required this.total,
    required this.gstin,
    this.interState = false,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
    this.halfRate = 0,
  });

  /// "18" or "18.5" — no trailing .0 on whole rates.
  String get rateLabel => _label(rate);

  /// "9" or "2.5" — the CGST/SGST per-component rate, no trailing .0.
  String get halfRateLabel => _label(halfRate);

  static String _label(double r) => r.toStringAsFixed(r == r.roundToDouble() ? 0 : 1);
}
