import 'package:flutter/foundation.dart';
import 'lib/services/api_service.dart';
import 'lib/providers/hybrid_auth_provider.dart';

void main() async {
  print('Testing connectivity...\n');

  // Initialize API
  await ApiService.initialize();

  // Test 1: Check if backend is healthy
  print('1. Testing backend health...');
  final isHealthy = await ApiService.isBackendHealthy();
  print('Backend healthy: $isHealthy');

  // Test 2: Check kDebugMode
  print('\n2. Debug mode check...');
  print('kDebugMode: $kDebugMode');

  // Test 3: Create provider and check online status
  print('\n3. Creating auth provider...');
  final provider = HybridAuthProvider();
  await Future.delayed(Duration(seconds: 2)); // Wait for initialization
  print('Provider _isOnline: ${provider.isOnline}');

  // Test 4: Try to signup
  print('\n4. Testing signup...');
  try {
    final result = await ApiService.signup(
      'testflutter@test.com',
      'test123',
      'Flutter Test',
    );
    print('Signup result: $result');
  } catch (e) {
    print('Signup error: $e');
  }
}