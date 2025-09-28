import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class UserManagementService {
  static String get baseUrl => ApiConfig.baseUrl;

  // Get stored tokens
  static Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception('No authentication token found');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Get all users in the business
  static Future<List<Map<String, dynamic>>> getBusinessUsers() async {
    try {
      // Temporarily return current user until backend endpoints are implemented
      print('⚠️ Business endpoints not yet implemented, returning current user only');

      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user_data');

      if (userData != null) {
        final user = json.decode(userData);
        return [
          {
            'id': user['id'],
            'username': user['username'] ?? user['email'],
            'email': user['email'],
            'fullName': user['fullName'],
            'role': user['role'] ?? 'owner',
            'isActive': true,
            'createdAt': DateTime.now().toIso8601String(),
          }
        ];
      }

      return [];
    } catch (e) {
      print('Error fetching business users: $e');
      // Return empty list instead of throwing
      return [];
    }
  }

  /// Invite a new staff member
  static Future<Map<String, dynamic>> inviteStaffMember({
    required String email,
    required String fullName,
    required String role,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/business/users/invite'),
        headers: headers,
        body: json.encode({
          'email': email,
          'fullName': fullName,
          'role': role,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }

      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to invite user');
    } catch (e) {
      print('Error inviting staff member: $e');
      throw e;
    }
  }

  /// Update staff member role or status
  static Future<Map<String, dynamic>> updateStaffMember({
    required String userId,
    String? role,
    bool? isActive,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final body = <String, dynamic>{};

      if (role != null) body['role'] = role;
      if (isActive != null) body['is_active'] = isActive;

      final response = await http.put(
        Uri.parse('$baseUrl/business/users/$userId'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }

      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to update user');
    } catch (e) {
      print('Error updating staff member: $e');
      throw e;
    }
  }

  /// Remove staff member
  static Future<bool> removeStaffMember(String userId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/business/users/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }

      return false;
    } catch (e) {
      print('Error removing staff member: $e');
      return false;
    }
  }

  /// Get business info and stats
  static Future<Map<String, dynamic>> getBusinessInfo() async {
    try {
      // Temporarily return mock data until backend endpoints are implemented
      print('⚠️ Business endpoints not yet implemented, returning mock data');

      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user_data');

      if (userData != null) {
        final user = json.decode(userData);
        return {
          'businessName': 'ParkEase Parking',
          'totalUsers': 1,
          'totalVehicles': 0,
          'activeSubscriptions': 0,
          'owner': user['fullName'] ?? 'Business Owner',
          'createdAt': DateTime.now().toIso8601String(),
        };
      }

      return {
        'businessName': 'ParkEase Parking',
        'totalUsers': 1,
        'totalVehicles': 0,
        'activeSubscriptions': 0,
        'owner': 'Business Owner',
        'createdAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error fetching business info: $e');
      // Return default data instead of throwing
      return {
        'businessName': 'ParkEase Parking',
        'totalUsers': 1,
        'totalVehicles': 0,
        'activeSubscriptions': 0,
        'owner': 'Business Owner',
        'createdAt': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Get all vehicles for the business (not just user)
  static Future<List<Map<String, dynamic>>> getBusinessVehicles() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/business/vehicles'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data'] ?? []);
        }
      }

      throw Exception('Failed to fetch business vehicles');
    } catch (e) {
      print('Error fetching business vehicles: $e');
      throw e;
    }
  }

  /// Check if user has permission for an action
  static bool hasPermission(String role, String action) {
    final permissions = {
      'owner': [
        'invite_staff',
        'update_staff',
        'remove_staff',
        'view_all_data',
        'manage_settings',
        'export_reports',
      ],
      'manager': [
        'invite_staff',
        'view_all_data',
        'manage_settings',
        'export_reports',
      ],
      'operator': [
        'view_own_data',
        'create_entries',
        'update_entries',
      ],
    };

    return permissions[role]?.contains(action) ?? false;
  }

  /// Get role display name
  static String getRoleDisplayName(String role) {
    switch (role) {
      case 'owner':
        return 'Owner';
      case 'manager':
        return 'Manager';
      case 'operator':
        return 'Operator';
      default:
        return role;
    }
  }

  /// Get role color
  static int getRoleColor(String role) {
    switch (role) {
      case 'owner':
        return 0xFF4CAF50; // Green
      case 'manager':
        return 0xFF2196F3; // Blue
      case 'operator':
        return 0xFFFF9800; // Orange
      default:
        return 0xFF9E9E9E; // Grey
    }
  }
}