import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('Testing Authentication Flow...\n');

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final baseUrl = 'https://parkease-production-6679.up.railway.app';

  // Test 1: Signup with email/password
  print('1. Testing signup...');
  var response = await http.post(
    Uri.parse('$baseUrl/api/auth/signup'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': 'test$timestamp@test.com',
      'password': 'test123',
      'fullName': 'Test User $timestamp',
      'deviceId': 'test-device-$timestamp',
    }),
  );

  print('Signup status: ${response.statusCode}');
  if (response.statusCode == 201 || response.statusCode == 200) {
    final data = jsonDecode(response.body);
    print('✅ Signup successful');
    print('   User ID: ${data['data']['user']['id']}');
    print('   Username: ${data['data']['user']['username']}');

    // Test 2: Login with created user
    print('\n2. Testing login with created user...');
    response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': 'test$timestamp@test.com',
        'password': 'test123',
        'deviceId': 'different-device',  // Should work for premium users
      }),
    );

    print('Login status: ${response.statusCode}');
    if (response.statusCode == 200) {
      print('✅ Login successful from different device');
    } else {
      print('❌ Login failed: ${response.body}');
    }
  } else {
    print('❌ Signup failed: ${response.body}');
  }

  // Test 3: Guest signup
  print('\n3. Testing guest signup...');
  response = await http.post(
    Uri.parse('$baseUrl/api/auth/guest-signup'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'username': 'guest$timestamp',
      'fullName': 'Guest User $timestamp',
      'deviceId': 'guest-device-$timestamp',
    }),
  );

  print('Guest signup status: ${response.statusCode}');
  if (response.statusCode == 201 || response.statusCode == 200) {
    final data = jsonDecode(response.body);
    print('✅ Guest signup successful');
    print('   User ID: ${data['data']['user']['id']}');

    // Test 4: Guest login from same device
    print('\n4. Testing guest login (same device)...');
    response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': 'guest$timestamp',
        'password': '',
        'deviceId': 'guest-device-$timestamp',  // Same device
      }),
    );

    print('Guest login (same device) status: ${response.statusCode}');
    if (response.statusCode == 200) {
      print('✅ Guest login successful from same device');
    } else {
      print('❌ Guest login failed: ${response.body}');
    }

    // Test 5: Guest login from different device (should fail)
    print('\n5. Testing guest login (different device)...');
    response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': 'guest$timestamp',
        'password': '',
        'deviceId': 'different-device',  // Different device
      }),
    );

    print('Guest login (different device) status: ${response.statusCode}');
    if (response.statusCode != 200) {
      print('✅ Guest login correctly blocked from different device');
    } else {
      print('❌ Security issue: Guest login allowed from different device!');
    }
  } else {
    print('❌ Guest signup failed: ${response.body}');
  }

  print('\n✅ All authentication tests completed!');
}