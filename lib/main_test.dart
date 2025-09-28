import 'package:flutter/material.dart';

void main() {
  print('===== TEST APP STARTING =====');
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('[TestApp] Building...');
    return MaterialApp(
      title: 'ParkEase Test',
      home: Scaffold(
        backgroundColor: Colors.blue,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.local_parking,
                size: 80,
                color: Colors.white,
              ),
              SizedBox(height: 20),
              Text(
                'ParkEase Test App',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'If you see this, Flutter is working!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}