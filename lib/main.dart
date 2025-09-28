import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/app_state_provider.dart';
import 'providers/simplified_bluetooth_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'utils/constants.dart';

void main() async {
  print('===== APP STARTING =====');
  print('[MAIN] Starting ParkEase app...');

  try {
    WidgetsFlutterBinding.ensureInitialized();
    print('[MAIN] Flutter binding initialized');

    runApp(const ParkEaseApp());
    print('[MAIN] App launched');
  } catch (e, stack) {
    print('[MAIN] FATAL ERROR: $e');
    print('[MAIN] Stack: $stack');
  }
}

class ParkEaseApp extends StatelessWidget {
  const ParkEaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('[ParkEaseApp] Building app...');
    return MultiProvider(
      providers: [
        // Root provider that manages everything
        ChangeNotifierProvider(
          create: (_) {
            print('[ParkEaseApp] Creating AppStateProvider...');
            return AppStateProvider();
          },
        ),
        // Bluetooth provider (independent)
        ChangeNotifierProvider(
          create: (_) {
            print('[ParkEaseApp] Creating BluetoothProvider...');
            return SimplifiedBluetoothProvider();
          },
        ),
      ],
      child: MaterialApp(
        title: 'ParkEase Manager',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(context),
        home: const AppRoot(),
      ),
    );
  }

  ThemeData _buildTheme(BuildContext context) {
    return ThemeData(
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        error: AppColors.error,
      ),
      textTheme: GoogleFonts.interTextTheme(
        Theme.of(context).textTheme,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}

/// App root that handles initialization and navigation
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    print('[AppRoot] initState called');

    try {
      WidgetsBinding.instance.addObserver(this);
      print('[AppRoot] Added lifecycle observer');

      // Initialize app
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('[AppRoot] Post frame callback triggered');
        _initializeApp();
      });
    } catch (e) {
      print('[AppRoot] initState ERROR: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeApp() async {
    print('[AppRoot] _initializeApp started');
    try {
      final appProvider = context.read<AppStateProvider>();
      print('[AppRoot] Got AppStateProvider instance');

      await appProvider.initialize();
      print('[AppRoot] AppStateProvider.initialize() completed');
    } catch (e, stack) {
      print('[AppRoot] _initializeApp ERROR: $e');
      print('[AppRoot] Stack: $stack');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final appProvider = context.read<AppStateProvider>();

    switch (state) {
      case AppLifecycleState.resumed:
        appProvider.onAppResume();
        break;
      case AppLifecycleState.paused:
        appProvider.onAppPause();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[AppRoot] build called');
    return Consumer<AppStateProvider>(
      builder: (context, appProvider, _) {
        print('[AppRoot] Consumer builder - isInitialized: ${appProvider.isInitialized}');

        // Show loading while initializing
        if (!appProvider.isInitialized) {
          print('[AppRoot] Showing loading screen');
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Initializing...'),
                  const SizedBox(height: 8),
                  Text(
                    'v2.0.1 - ${DateTime.now().toString().substring(0, 19)}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  Text(
                    'Debug: isInit=${appProvider.isInitialized}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  if (appProvider.authProvider.lastError != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Error: ${appProvider.authProvider.lastError}',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        // Show login or dashboard based on auth state
        print('[AppRoot] Checking authentication: ${appProvider.authProvider.isAuthenticated}');
        if (appProvider.authProvider.isAuthenticated) {
          print('[AppRoot] User authenticated, showing Dashboard');
          return const DashboardScreen();
        }

        print('[AppRoot] User not authenticated, showing Login');
        return const LoginScreen();
      },
    );
  }
}