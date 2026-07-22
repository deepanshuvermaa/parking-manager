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
  }) async {
    final p = await SharedPreferences.getInstance();
    final enabled = p.getBool('enable_gst') ?? false;
    final onParking = p.getBool('gst_on_parking') ?? true;
    final onBooking = p.getBool('gst_on_booking') ?? true;
    final rate = _d(p, 'gst_rate', 18.0);
    final gstin = p.getString('gstin_number') ?? '';

    final applies = enabled && amount > 0 && (isBooking ? onBooking : onParking);
    final gstAmount = applies ? amount * rate / 100 : 0.0;

    return GstBreakdown(
      applies: applies,
      rate: rate,
      subtotal: amount,
      gstAmount: gstAmount,
      total: amount + gstAmount,
      gstin: gstin,
    );
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

  const GstBreakdown({
    required this.applies,
    required this.rate,
    required this.subtotal,
    required this.gstAmount,
    required this.total,
    required this.gstin,
  });

  /// "18" or "18.5" — no trailing .0 on whole rates.
  String get rateLabel => rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 1);
}
