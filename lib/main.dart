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
    statusBarIconBrightness: Brightness.light,
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
            themeMode: ThemeMode.system,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: MediaQuery.of(context).padding,
                ),
                child: SafeArea(
                  top: false,
                  bottom: true,
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const MainNavScreen(),
              '/slots': (context) => const SlotManagementScreen(),
              '/subscribe': (context) => const SubscriptionScreen(),
              '/settings': (context) => SimpleSettingsScreen(
                    token: auth.token ?? ''),
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
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    VehicleEntryScreen(),
    VehicleExitScreen(),
    ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Go2Colors.primary,
          unselectedItemColor: Go2Colors.textHint,
          elevation: 0,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.add_circle_rounded,
                size: 32,
                color: _currentIndex == 1
                    ? Go2Colors.primary
                    : Go2Colors.textHint,
              ),
              label: 'Entry',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.exit_to_app_rounded),
              label: 'Exit',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),
              label: 'Reports',
            ),
          ],
        ),
      ),
    );
  }
}
