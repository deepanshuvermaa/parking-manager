import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/parking_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/vehicle_entry_screen.dart';
import 'screens/vehicle_exit_screen.dart';
import 'screens/slot_management_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/subscription_screen.dart';
import 'screens/simple_settings_screen.dart';
import 'screens/simple_printer_settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const Go2ParkingApp());
}

class Go2ParkingApp extends StatelessWidget {
  const Go2ParkingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ParkingProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: 'Go2-Parking',
            debugShowCheckedModeBanner: false,
            theme: Go2Theme.light(),
            darkTheme: Go2Theme.dark(),
            themeMode: ThemeMode.light, // Force light mode
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const MainNavScreen(),
              '/slots': (context) => const SlotManagementScreen(),
              '/subscribe': (context) => const SubscriptionScreen(),
              '/settings': (context) => SimpleSettingsScreen(token: auth.token ?? ''),
              '/printer': (context) => const SimplePrinterSettingsScreen(),
            },
          );
        },
      ),
    );
  }
}

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => MainNavScreenState();
}

class MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

  void switchToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(onTabSwitch: switchToTab),
      const VehicleEntryScreen(),
      const VehicleExitScreen(),
      const ReportsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Go2Colors.divider, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: switchToTab,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded, size: 22), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.add_circle_rounded, size: 28), label: 'Entry'),
            BottomNavigationBarItem(icon: Icon(Icons.exit_to_app_rounded, size: 22), label: 'Exit'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded, size: 22), label: 'Reports'),
          ],
        ),
      ),
    );
  }
}
