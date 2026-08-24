/// Vehicle-number handling shared by entry, duplicate detection and search.
///
/// Operators type the same plate inconsistently — `UP32AB1234`, `UP 32 AB 1234`,
/// `up-32-ab-1234` are one car. Matching used to be exact string equality, so
/// those were three different vehicles: the "already parked" warning missed
/// them, and exit search could not find a car that had been entered with
/// spaces. Comparisons go through [normalizePlate] to fix that.
///
/// Deliberately NOT used to rewrite what gets stored. Receipts and reports keep
/// exactly what the operator typed; only comparison is normalised. That keeps
/// this safe to apply to the rows already in the database, which were written
/// in whatever form they were entered.
library;

import 'package:flutter/services.dart';

/// Everything except letters and digits, folded to upper case.
final RegExp _nonAlphanumeric = RegExp(r'[^A-Z0-9]');

/// Canonical form used for comparing two vehicle numbers.
///
/// Strips spaces, hyphens, dots and any other separator, then upper-cases.
/// `' up-32 ab 1234 '` and `'UP32AB1234'` both become `'UP32AB1234'`.
String normalizePlate(String raw) =>
    raw.toUpperCase().replaceAll(_nonAlphanumeric, '');

/// True when [a] and [b] denote the same vehicle regardless of spacing or case.
bool isSamePlate(String a, String b) => normalizePlate(a) == normalizePlate(b);

/// True when [haystack] contains [needle], both normalised.
///
/// Lets a search for `UP32AB1234` find a vehicle stored as `UP 32 AB 1234`.
bool plateContains(String haystack, String needle) {
  final n = normalizePlate(needle);
  if (n.isEmpty) return true;
  return normalizePlate(haystack).contains(n);
}

/// Shortest accepted vehicle number, after normalising.
///
/// Kept deliberately loose. Indian registrations vary widely — BH-series,
/// temporary numbers, dealer plates — and lots also record informal
/// identifiers. Rejecting anything more specific would block legitimate
/// entries, so this only catches a plate that is too short to be real, which
/// in practice means a mis-tap or a half-finished entry.
const int minPlateLength = 4;

/// Null when acceptable, otherwise the reason to show the operator.
String? validatePlate(String raw) {
  final normalized = normalizePlate(raw);
  if (normalized.isEmpty) return 'Enter a vehicle number';
  if (normalized.length < minPlateLength) {
    return 'Vehicle number looks too short';
  }
  return null;
}

/// Forces a vehicle-number field to upper case as the operator types.
///
/// Lives here rather than in one screen so every field that captures a plate —
/// parking entry and taxi booking alike — behaves identically. Plates are
/// conventionally upper case, and a lower-case entry reads as a different
/// string everywhere the raw value is displayed.
class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    // Unchanged text must return the value untouched, otherwise the selection
    // is rebuilt on every keystroke and the caret can jump.
    if (upper == newValue.text) return newValue;
    return TextEditingValue(text: upper, selection: newValue.selection);
  }
}
