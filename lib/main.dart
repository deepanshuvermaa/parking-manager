import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/simple_dashboard_screen.dart';
import 'services/device_service.dart';
import 'services/simple_bluetooth_service.dart';
import 'services/simple_vehicle_service.dart';
import 'utils/constants.dart';
import 'utils/debug_logger.dart';
import 'config/api_config.dart';

void main() {
  runApp(const ParkEaseApp());
}

class ParkEaseApp extends StatelessWidget {
  const ParkEaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParkEase Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      ),
      home: const DebugOverlay(child: SimpleLoginScreen()),
    );
  }
}

class SimpleLoginScreen extends StatefulWidget {
  const SimpleLoginScreen({super.key});

  @override
  State<SimpleLoginScreen> createState() => _SimpleLoginScreenState();
}

class _SimpleLoginScreenState extends State<SimpleLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _rememberMe = false;
  String? _errorMessage;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userName = prefs.getString('user_name');
      final userEmail = prefs.getString('user_email');
      final userRole = prefs.getString('user_role');
      final trialExpires = prefs.getString('trial_expires');

      if (token != null && userName != null) {
        // ✅ VALIDATE TOKEN WITH BACKEND
        try {
          DebugLogger.log('Validating token with backend...');

          final response = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/auth/validate'),
            headers: {'Authorization': 'Bearer $token'},
          ).timeout(const Duration(seconds: 10));

          DebugLogger.log('Token validation response: ${response.statusCode}');

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['success'] == true) {
              // Token is valid - check trial expiry for guests
              if (userRole == 'guest' && trialExpires != null) {
                final expiryDate = DateTime.parse(trialExpires);
                if (DateTime.now().isAfter(expiryDate)) {
                  // Trial expired
                  if (mounted) {
                    _showTrialExpiredDialog();
                    setState(() => _isCheckingAuth = false);
                  }
                  return;
                }
              }

              // ✅ SYNC DATA FROM BACKEND
              DebugLogger.log('Syncing data from backend...');
              await SimpleVehicleService.initialize(token);

              // Auto-login
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SimpleDashboardScreen(
                      userName: userName,
                      userEmail: userEmail ?? '',
                      userRole: userRole ?? 'guest',
                      token: token,
                    ),
                  ),
                );
              }
              return;
            }
          }

          // Token invalid - clear and show login
          DebugLogger.log('Token validation failed, clearing stored credentials');
          await prefs.clear();
        } catch (e) {
          DebugLogger.log('Token validation error: $e');
          // On network error, try to load from local database and allow offline access
          await SimpleVehicleService.loadFromLocalDatabase();

          if (mounted) {
            // Show dialog asking if user wants to continue offline
            final continueOffline = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Connection Error'),
                content: const Text(
                  'Cannot connect to server. Would you like to continue in offline mode?\n\nYour data will sync when connection is restored.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Logout'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Continue Offline'),
                  ),
                ],
              ),
            );

            if (continueOffline == true) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => SimpleDashboardScreen(
                    userName: userName,
                    userEmail: userEmail ?? '',
                    userRole: userRole ?? 'guest',
                    token: token,
                  ),
                ),
              );
              return;
            } else {
              await prefs.clear();
            }
          }
        }
      }

      setState(() => _isCheckingAuth = false);
    } catch (e) {
      DebugLogger.log('Auto-login error: $e');
      setState(() => _isCheckingAuth = false);
    }
  }

  void _showTrialExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Trial Expired'),
          ],
        ),
        content: const Text(
          'Your 3-day free trial has ended. Please contact the developer to purchase the full version.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      DebugLogger.log('Starting login process...');

      final deviceId = await DeviceService.getDeviceId();
      final deviceInfo = await DeviceService.getDeviceInfo();
      DebugLogger.log('Device ID obtained: $deviceId');
      DebugLogger.log('Username: ${_usernameController.text.trim()}');

      final url = ApiConfig.loginUrl;
      DebugLogger.log('Login URL: $url');

      final requestBody = {
        'username': _usernameController.text.trim(),
        'password': _passwordController.text,
        'deviceId': deviceId,
        'deviceName': deviceInfo['deviceName'] ?? 'Unknown Device',
        'platform': deviceInfo['platform'] ?? 'Android',
      };
      DebugLogger.log('Request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));

      DebugLogger.log('Response Status: ${response.statusCode}');
      DebugLogger.log('Response Headers: ${response.headers}');
      DebugLogger.log('Response Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Store user data in memory (simplified)
        final userData = data['data']['user'];
        final token = data['data']['token'];
        final refreshToken = data['data']['refreshToken'];

        // Save login info if remember me is checked
        if (_rememberMe) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          await prefs.setString('refresh_token', refreshToken ?? '');
          await prefs.setString('user_name', userData['fullName'] ?? userData['username'] ?? '');
          await prefs.setString('user_email', userData['email'] ?? userData['username'] ?? '');
          await prefs.setString('user_role', userData['role'] ?? userData['userType'] ?? 'owner');
          await prefs.setString('user_id', userData['id'] ?? '');
          await prefs.setString('trial_expires', userData['trialExpiresAt'] ?? '');
        }

        // ✅ SYNC DATA FROM BACKEND
        DebugLogger.log('Syncing data from backend after login...');
        await SimpleVehicleService.initialize(token);

        // Navigate to dashboard with user data
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SimpleDashboardScreen(
                userName: userData['fullName'] ?? userData['username'] ?? '',
                userEmail: userData['email'] ?? userData['username'] ?? '',
                userRole: userData['role'] ?? userData['userType'] ?? 'owner',
                token: token,
              ),
            ),
          );
        }
      } else if (response.statusCode == 403 && data['code'] == 'DEVICE_LIMIT_REACHED') {
        // Device limit reached - show dialog to logout other devices
        if (mounted) {
          final shouldLogoutOthers = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Device Limit Reached'),
              content: Text(
                data['data']['message'] ?? 'You can only login on one device at a time.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Logout Other Devices'),
                ),
              ],
            ),
          );

          if (shouldLogoutOthers == true) {
            // Call logout-others endpoint and retry login
            // This would require additional implementation
            setState(() {
              _errorMessage = 'Please implement logout-others functionality';
            });
          }
        }
      } else {
        setState(() {
          _errorMessage = data['error'] ?? 'Login failed';
        });
      }
    } catch (e, stackTrace) {
      DebugLogger.log('Login failed', error: e.toString(), stackTrace: stackTrace);

      String errorMsg = 'Connection error. Please check your internet.';
      String detailedError = e.toString();

      if (e.toString().contains('SocketException')) {
        errorMsg = 'Cannot connect to server. Please check your internet connection.';
        DebugLogger.log('Socket Exception detected - Network issue');
      } else if (e.toString().contains('Failed host lookup')) {
        errorMsg = 'DNS Error: Server not reachable. ISP might be blocking the domain.';
        DebugLogger.log('DNS Lookup Failed - ISP blocking Railway domain');
      } else if (e.toString().contains('TimeoutException')) {
        errorMsg = 'Connection timeout. Server might be down.';
        DebugLogger.log('Timeout - Server not responding in 15 seconds');
      } else if (e.toString().contains('HandshakeException')) {
        errorMsg = 'SSL/TLS error. Certificate issue.';
        DebugLogger.log('SSL Handshake Failed');
      }

      setState(() {
        _errorMessage = '$errorMsg\n\nDetails: $detailedError';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGuestLogin() async {
    // Show dialog to get guest information
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final parkingNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final guestInfo = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Guest Registration'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Please provide your details for the 3-day free trial:'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name*',
                    hintText: 'e.g., John Doe',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'e.g., john@example.com',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'e.g., 9876543210',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                        return 'Please enter a valid 10-digit phone number';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: parkingNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Parking Business Name*',
                    hintText: 'e.g., City Center Parking',
                    prefixIcon: Icon(Icons.local_parking),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your parking business name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '3-day free trial. You can upgrade anytime.',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, {
                  'name': nameController.text.trim(),
                  'email': emailController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'parkingName': parkingNameController.text.trim(),
                });
              }
            },
            child: const Text('Start Free Trial'),
          ),
        ],
      ),
    );

    if (guestInfo == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get device info
      final deviceInfo = await DeviceService.getDeviceInfo();
      final deviceId = deviceInfo['device_id']!;

      // Generate a unique username if no email provided
      final email = guestInfo['email']!.isEmpty
          ? 'guest_${deviceId.substring(0, 8)}@parkease.temp'
          : guestInfo['email']!;

      print('Guest Registration Request:');
      print('Name: ${guestInfo['name']}');
      print('Email: $email');
      print('Phone: ${guestInfo['phone']}');
      print('Parking: ${guestInfo['parkingName']}');
      print('Device ID: $deviceId');

      final response = await http.post(
        Uri.parse(ApiConfig.guestSignupUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': guestInfo['name'],
          'email': email,
          'phone': guestInfo['phone'],
          'parkingName': guestInfo['parkingName'],
          'deviceId': deviceId,
          'deviceName': deviceInfo['deviceName'] ?? 'Unknown Device',
          'platform': deviceInfo['platform'] ?? 'Android',
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
        final userData = data['data']['user'];
        final token = data['data']['token'];
        final refreshToken = data['data']['refreshToken'];

        // Save login info for auto-login
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await prefs.setString('refresh_token', refreshToken ?? '');
        await prefs.setString('user_name', userData['fullName'] ?? guestInfo['name'] ?? '');
        await prefs.setString('user_email', userData['email'] ?? email);
        await prefs.setString('user_phone', userData['phone'] ?? guestInfo['phone'] ?? '');
        await prefs.setString('parking_name', userData['parkingName'] ?? guestInfo['parkingName'] ?? '');
        await prefs.setString('user_role', userData['userType'] ?? 'guest');
        await prefs.setString('user_id', userData['id'] ?? '');
        await prefs.setString('trial_expires', userData['trialExpiresAt'] ?? '');

        // ✅ INITIALIZE DATA SYNC
        DebugLogger.log('Initializing data sync for new guest user...');
        await SimpleVehicleService.initialize(token);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SimpleDashboardScreen(
                userName: userData['fullName'] ?? guestInfo['name'] ?? '',
                userEmail: userData['email'] ?? email,
                userRole: userData['userType'] ?? 'guest',
                token: token,
              ),
            ),
          );
        }
      } else {
        print('Guest Registration Failed:');
        print('Status: ${response.statusCode}');
        print('Response: ${response.body}');
        setState(() {
          _errorMessage = data['error'] ?? data['message'] ?? 'Failed to create guest account';
        });
      }
    } catch (e) {
      print('Guest Registration Error: $e');
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.7),
              ],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                SizedBox(height: 20),
                Text(
                  'Loading...',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primary.withOpacity(0.7),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.local_parking,
                            size: 48,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 24),

                        const Text(
                          'ParkEase Manager',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Version 4.0 - Working Build',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Error message
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red[300]!),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red[800]),
                            ),
                          ),

                        // Username field
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Remember me
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                              },
                            ),
                            const Text('Remember me'),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Login button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Guest login button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _handleGuestLogin,
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Continue as Guest',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}