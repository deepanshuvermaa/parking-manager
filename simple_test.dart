import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('Testing Flutter App Issues...\n');

  // Test 1: Backend connectivity
  print('1. Testing backend health...');
  var response = await http.get(
    Uri.parse('https://parkease-production-6679.up.railway.app/health'),
  );
  print('Health check: ${response.statusCode} - ${response.body}');

  // Test 2: Create a test user
  print('\n2. Creating test user...');
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  response = await http.post(
    Uri.parse('https://parkease-production-6679.up.railway.app/api/auth/signup'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': 'fluttertest$timestamp@test.com',
      'password': 'test123',
      'fullName': 'Flutter Test',
      'deviceId': 'flutter-device-$timestamp',
    }),
  );

  if (response.statusCode == 201 || response.statusCode == 200) {
    final data = jsonDecode(response.body);
    print('User created successfully!');
    print('Response structure:');
    print('  - success: ${data['success']}');
    print('  - data.user keys: ${data['data']['user'].keys.toList()}');
    print('  - user.userType: ${data['data']['user']['userType']}');
    print('  - user.trialExpiresAt: ${data['data']['user']['trialExpiresAt']}');

    // Check what fields exist
    print('\nChecking for expected fields:');
    print('  - Has "role"? ${data['data']['user'].containsKey('role')}');
    print('  - Has "userType"? ${data['data']['user'].containsKey('userType')}');
    print('  - Has "createdAt"? ${data['data']['user'].containsKey('createdAt')}');
    print('  - Has "trialEndDate"? ${data['data']['user'].containsKey('trialEndDate')}');
    print('  - Has "trialExpiresAt"? ${data['data']['user'].containsKey('trialExpiresAt')}');
  }
}