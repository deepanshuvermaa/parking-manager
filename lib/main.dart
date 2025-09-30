import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MaterialApp(
    home: AllInOneTestApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class AllInOneTestApp extends StatefulWidget {
  @override
  State<AllInOneTestApp> createState() => _AllInOneTestAppState();
}

class _AllInOneTestAppState extends State<AllInOneTestApp> {
  final _usernameController = TextEditingController(text: 'deepanshuverma966@gmail.com');
  final _passwordController = TextEditingController(text: 'Dv12062001@');

  bool _isLoading = false;
  String _statusMessage = 'VERSION 3.2 - ALL IN ONE';
  Color _statusColor = Colors.blue;
  String _apiResponse = 'No API call yet';

  Future<void> _testLogin() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Calling API...';
      _statusColor = Colors.orange;
      _apiResponse = 'Waiting...';
    });

    try {
      final response = await http.post(
        Uri.parse('https://parkease-production-6679.up.railway.app/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameController.text,
          'password': _passwordController.text,
        }),
      ).timeout(Duration(seconds: 10));

      final data = jsonDecode(response.body);

      setState(() {
        _apiResponse = 'Status: ${response.statusCode}\n${response.body.substring(0, 200)}...';

        if (response.statusCode == 200 && data['success'] == true) {
          _statusMessage = '✅ SUCCESS!';
          _statusColor = Colors.green;
        } else {
          _statusMessage = '❌ FAILED';
          _statusColor = Colors.red;
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ ERROR';
        _statusColor = Colors.red;
        _apiResponse = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testHealth() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Testing health...';
      _apiResponse = 'Calling health endpoint...';
    });

    try {
      final response = await http.get(
        Uri.parse('https://parkease-production-6679.up.railway.app/health'),
      ).timeout(Duration(seconds: 5));

      setState(() {
        _apiResponse = 'Health Status: ${response.statusCode}\n${response.body}';
        _statusMessage = response.statusCode == 200 ? '✅ API ONLINE' : '❌ API OFFLINE';
        _statusColor = response.statusCode == 200 ? Colors.green : Colors.red;
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ NETWORK ERROR';
        _statusColor = Colors.red;
        _apiResponse = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              // Version banner
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _statusColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Built: ${DateTime.now().toString().substring(0, 19)}',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Login form card
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LOGIN TEST',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),

                      // Username field
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      SizedBox(height: 12),

                      // Password field
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      SizedBox(height: 16),

                      // Buttons row
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _testLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: _isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text('TEST LOGIN'),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _testHealth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: Text('TEST API'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Response card
              Card(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'API RESPONSE:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _apiResponse,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Info card
              Card(
                color: Colors.yellow[100],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📱 WHAT TO TEST:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text('1. Press "TEST API" - Should show "healthy"'),
                      Text('2. Press "TEST LOGIN" - Should show success/error'),
                      Text('3. Check API RESPONSE box for details'),
                      SizedBox(height: 8),
                      Text(
                        'No providers, no navigation, just API calls.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}