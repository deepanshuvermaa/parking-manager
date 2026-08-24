import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../utils/debug_logger.dart';

/// Owns the access/refresh token pair and keeps the access token alive.
///
/// Access tokens expire after 7 days and refresh tokens after 30. Previously
/// the refresh token was stored but never spent, so a handheld left running
/// past the 7-day mark returned 401 on every sync and kept doing so until
/// somebody reinstalled or re-logged-in. Bills stayed queued locally and never
/// reached the backend.
///
/// The token lives here, not in AuthProvider, so the background sync services
/// can renew it without reaching into the widget tree. AuthProvider seeds this
/// on login/startup and reads back through it.
class AuthTokenService {
  static String? _accessToken;
  static String? _refreshToken;

  /// Set only when the *refresh* token itself is rejected. At that point no
  /// automatic recovery is possible and the operator must sign in again.
  static bool refreshRejected = false;

  /// De-duplicates concurrent renewals. Vehicle sync and booking sync run on
  /// the same 2-minute tick, so both can hit 401 at once; without this they
  /// would race, and the loser would persist a token the winner just rotated
  /// away — invalidating a perfectly good session.
  static Future<bool>? _inFlight;

  /// Renew this far ahead of expiry rather than waiting for a 401. Comfortably
  /// longer than the 2-minute sync tick so a token never dies mid-cycle.
  static const Duration renewWindow = Duration(hours: 12);

  static const String _kAccess = 'auth_token';
  static const String _kRefresh = 'refresh_token';

  static String get token => _accessToken ?? '';
  static bool get hasRefreshToken =>
      _refreshToken != null && _refreshToken!.isNotEmpty;

  /// True for the offline-only mode, where no backend calls should be made.
  static bool get isOfflineToken =>
      _accessToken == null ||
      _accessToken!.isEmpty ||
      _accessToken == 'offline_local_token';

  /// Adopt a token pair (login, or restore from disk at startup).
  static void seed({String? accessToken, String? refreshToken}) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    if (accessToken != null && accessToken.isNotEmpty) refreshRejected = false;
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    seed(
      accessToken: prefs.getString(_kAccess),
      refreshToken: prefs.getString(_kRefresh),
    );
  }

  static Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    refreshRejected = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
  }

  /// Seconds-since-epoch `exp` claim of a JWT, or null if unreadable.
  ///
  /// Parsed locally rather than asking the server, so the check costs nothing
  /// and works offline. A malformed token returns null and is treated as
  /// "expiry unknown", which callers handle by renewing on 401 instead.
  static DateTime? expiryOf(String? jwt) {
    if (jwt == null || jwt.isEmpty) return null;
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      // base64url without padding — restore it before decoding.
      final normalised = base64Url.normalize(payload);
      final map = jsonDecode(utf8.decode(base64Url.decode(normalised)));
      final exp = map['exp'];
      if (exp is! int) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    } catch (_) {
      return null;
    }
  }

  static DateTime? get accessTokenExpiry => expiryOf(_accessToken);

  /// True when the access token is gone, already expired, or inside
  /// [renewWindow] of expiring.
  static bool get needsRenewal {
    if (isOfflineToken) return false;
    final exp = accessTokenExpiry;
    if (exp == null) return false; // unknown expiry — renew reactively instead
    return DateTime.now().toUtc().add(renewWindow).isAfter(exp);
  }

  /// Renew if the token is close to expiring. Cheap to call often — it returns
  /// immediately unless renewal is actually due.
  static Future<bool> ensureFresh() async {
    if (!needsRenewal || refreshRejected) return !isOfflineToken;
    return await refresh();
  }

  /// Exchange the refresh token for a new pair.
  ///
  /// Returns true when a usable access token is in place afterwards. Safe to
  /// call concurrently: callers share one in-flight request.
  static Future<bool> refresh() {
    final existing = _inFlight;
    if (existing != null) return existing;

    final run = _performRefresh();
    _inFlight = run;
    // Clear the slot whether it succeeded or threw, so a later call retries.
    run.whenComplete(() => _inFlight = null);
    return run;
  }

  static Future<bool> _performRefresh() async {
    if (!hasRefreshToken || isOfflineToken) return false;

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.refreshTokenUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': _refreshToken}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final next = data['data'];
          _accessToken = next['accessToken'] ?? next['token'] ?? _accessToken;
          _refreshToken = next['refreshToken'] ?? _refreshToken;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kAccess, _accessToken ?? '');
          await prefs.setString(_kRefresh, _refreshToken ?? '');

          refreshRejected = false;
          DebugLogger.log('🔑 Access token renewed');
          return true;
        }
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        // The refresh token is spent too (30 days, or revoked server-side).
        // Nothing automatic can recover this — the operator must sign in.
        refreshRejected = true;
        DebugLogger.log('🔒 Refresh token rejected — sign-in required');
      }
      return false;
    } catch (e) {
      // A network failure is NOT an auth failure. Leave refreshRejected alone
      // so the UI keeps saying "offline" and we retry on the next tick.
      DebugLogger.log('⚠️ Token renewal failed (will retry): $e');
      return false;
    }
  }

  /// Call when a request comes back 401. Renews once and reports whether the
  /// caller should retry. Returns false if the session is genuinely dead.
  static Future<bool> handleUnauthorized() async {
    if (refreshRejected || isOfflineToken) return false;
    return await refresh();
  }
}
