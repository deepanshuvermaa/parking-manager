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
                  top: false, // AppBar handles top
                  bottom: true,
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/login': (context) => const LoginScreen(),
              '/dashboard': (context) => const DashboardScreen(),
              '/entry': (context) => const VehicleEntryScreen(),
              '/exit': (context) => const VehicleExitScreen(),
              '/slots': (context) => const SlotManagementScreen(),
              '/reports': (context) => const ReportsScreen(),
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
