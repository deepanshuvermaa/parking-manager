import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('Testing ParkEase Backend Connection...\n');

  // Test health endpoint
  print('1. Testing health endpoint...');
  var response = await http.get(
    Uri.parse('https://parkease-production-6679.up.railway.app/health'),
  );
  print('Health status: ${response.statusCode}');
  print('Health response: ${response.body}\n');

  // Test signup
  print('2. Testing signup endpoint...');
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  response = await http.post(
    Uri.parse('https://parkease-production-6679.up.railway.app/api/auth/signup'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': 'testuser$timestamp@test.com',
      'password': 'test123',
      'fullName': 'Test User $timestamp',
      'deviceId': 'test-device-$timestamp',
    }),
  );
  print('Signup status: ${response.statusCode}');
  print('Signup response: ${response.body}\n');

  if (response.statusCode == 201 || response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final token = data['data']['token'];

    // Test login
    print('3. Testing login endpoint...');
    response = await http.post(
      Uri.parse('https://parkease-production-6679.up.railway.app/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': 'testuser$timestamp@test.com',
        'password': 'test123',
        'deviceId': 'another-device', // Different device should work for premium users
      }),
    );
    print('Login status: ${response.statusCode}');
    print('Login response: ${response.body}\n');
  }

  // Test guest signup
  print('4. Testing guest signup endpoint...');
  response = await http.post(
    Uri.parse('https://parkease-production-6679.up.railway.app/api/auth/guest-signup'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'username': 'guest$timestamp',
      'fullName': 'Guest User $timestamp',
      'deviceId': 'guest-device-$timestamp',
    }),
  );
  print('Guest signup status: ${response.statusCode}');
  print('Guest signup response: ${response.body}\n');

  print('✅ All tests completed!');
}