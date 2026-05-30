import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/parking_provider.dart';
import 'services/platform_printer_service.dart';
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
            themeMode: ThemeMode.light,
            builder: (context, child) => child ?? const SizedBox.shrink(),
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

  @override
  void initState() {
    super.initState();
    PlatformPrinterService.autoConnect();
  }

  void switchToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().userRole;
    final isStaffOnly = role == 'staff';

    final maxIndex = isStaffOnly ? 2 : 3;
    final safeIndex = _currentIndex.clamp(0, maxIndex);

    // Only build the active screen - no IndexedStack
    Widget body;
    switch (safeIndex) {
      case 0:
        body = DashboardScreen(onTabSwitch: switchToTab);
        break;
      case 1:
        body = const VehicleEntryScreen();
        break;
      case 2:
        body = const VehicleExitScreen();
        break;
      case 3:
        body = const ReportsScreen();
        break;
      default:
        body = DashboardScreen(onTabSwitch: switchToTab);
    }

    final navItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.home_rounded, size: 22), label: 'Home'),
      const BottomNavigationBarItem(icon: Icon(Icons.add_circle_rounded, size: 28), label: 'Entry'),
      const BottomNavigationBarItem(icon: Icon(Icons.exit_to_app_rounded, size: 22), label: 'Exit'),
      if (!isStaffOnly) const BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded, size: 22), label: 'Reports'),
    ];

    return Scaffold(
      body: body,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Go2Colors.surface,
          border: Border(top: BorderSide(color: Go2Colors.divider, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: safeIndex,
          onTap: switchToTab,
          items: navItems,
        ),
      ),
    );
  }
}
