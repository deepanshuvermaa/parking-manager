import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/taxi_booking.dart';
import '../config/api_config.dart';

/// Taxi Booking Service
/// Handles all API calls for taxi bookings - completely separate from parking
class TaxiBookingService {
  /// Get all bookings (with optional filters)
  static Future<Map<String, dynamic>> getBookings(
    String token, {
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

      final uri = Uri.parse(ApiConfig.taxiBookingsUrl).replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      final response = await http.get(
        uri,
        headers: ApiConfig.authHeaders(token),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final bookingsJson = data['data']['bookings'] as List;
          final bookings = bookingsJson
              .map((json) => TaxiBooking.fromJson(json))
              .toList();

          return {
            'bookings': bookings,
            'counts': data['data']['counts'],
          };
        }
      }

      throw Exception('Failed to load bookings: ${response.statusCode}');
    } catch (e) {
      print('Error fetching taxi bookings: $e');
      rethrow;
    }
  }

  /// Get single booking by ID
  static Future<TaxiBooking> getBookingById(String token, String id) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.taxiBookingsUrl}/$id'),
        headers: ApiConfig.authHeaders(token),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return TaxiBooking.fromJson(data['data']['booking']);
        }
      }

      throw Exception('Failed to load booking: ${response.statusCode}');
    } catch (e) {
      print('Error fetching taxi booking: $e');
      rethrow;
    }
  }

  /// Create new booking
  static Future<TaxiBooking> createBooking(
    String token,
    Map<String, dynamic> bookingData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.taxiBookingsUrl),
        headers: ApiConfig.authHeaders(token),
        body: jsonEncode(bookingData),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return TaxiBooking.fromJson(data['data']['booking']);
        }
      }

      // Handle error response
      if (response.statusCode >= 400) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to create booking');
      }

      throw Exception('Failed to create booking: ${response.statusCode}');
    } catch (e) {
      print('Error creating taxi booking: $e');
      rethrow;
    }
  }

  /// Update booking
  static Future<TaxiBooking> updateBooking(
    String token,
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.taxiBookingsUrl}/$id'),
        headers: ApiConfig.authHeaders(token),
        body: jsonEncode(updates),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return TaxiBooking.fromJson(data['data']['booking']);
        }
      }

      throw Exception('Failed to update booking: ${response.statusCode}');
    } catch (e) {
      print('Error updating taxi booking: $e');
      rethrow;
    }
  }

  /// Start trip (booked -> ongoing)
  static Future<TaxiBooking> startTrip(
    String token,
    String id, {
    DateTime? startTime,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.taxiBookingsUrl}/$id/start'),
        headers: ApiConfig.authHeaders(token),
        body: jsonEncode({
          'startTime': (startTime ?? DateTime.now()).toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return TaxiBooking.fromJson(data['data']['booking']);
        }
      }

      throw Exception('Failed to start trip: ${response.statusCode}');
    } catch (e) {
      print('Error starting trip: $e');
      rethrow;
    }
  }

  /// Complete trip (ongoing/booked -> completed)
  static Future<TaxiBooking> completeTrip(
    String token,
    String id, {
    DateTime? endTime,
    double? fareAmount,
  }) async {
    try {
      final body = <String, dynamic>{
        'endTime': (endTime ?? DateTime.now()).toIso8601String(),
      };
      if (fareAmount != null) {
        body['fareAmount'] = fareAmount;
      }

      final response = await http.put(
        Uri.parse('${ApiConfig.taxiBookingsUrl}/$id/complete'),
        headers: ApiConfig.authHeaders(token),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return TaxiBooking.fromJson(data['data']['booking']);
        }
      }

      throw Exception('Failed to complete trip: ${response.statusCode}');
    } catch (e) {
      print('Error completing trip: $e');
      rethrow;
    }
  }

  /// Cancel booking
  static Future<TaxiBooking> cancelBooking(String token, String id) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.taxiBookingsUrl}/$id/cancel'),
        headers: ApiConfig.authHeaders(token),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return TaxiBooking.fromJson(data['data']['booking']);
        }
      }

      throw Exception('Failed to cancel booking: ${response.statusCode}');
    } catch (e) {
      print('Error cancelling booking: $e');
      rethrow;
    }
  }

  /// Delete booking
  static Future<void> deleteBooking(String token, String id) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.taxiBookingsUrl}/$id'),
        headers: ApiConfig.authHeaders(token),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return;
        }
      }

      throw Exception('Failed to delete booking: ${response.statusCode}');
    } catch (e) {
      print('Error deleting booking: $e');
      rethrow;
    }
  }

  /// Get analytics
  static Future<Map<String, dynamic>> getAnalytics(
    String token, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

      final uri = Uri.parse('${ApiConfig.taxiBookingsUrl}/analytics/summary')
          .replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      final response = await http.get(
        uri,
        headers: ApiConfig.authHeaders(token),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data']['analytics'] as Map<String, dynamic>;
        }
      }

      throw Exception('Failed to load analytics: ${response.statusCode}');
    } catch (e) {
      print('Error fetching analytics: $e');
      rethrow;
    }
  }
}
