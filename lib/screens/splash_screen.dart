import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _carController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<double> _carPosition;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _carController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0, 0.5)),
    );
    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.4, 1.0)),
    );
    _carPosition = Tween<double>(begin: -1.5, end: 0.0).animate(
      CurvedAnimation(parent: _carController, curve: Curves.easeOutCubic),
    );

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 300), () => _carController.forward());
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final auth = context.read<AuthProvider>();
    await auth.initialize();
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    if (auth.status == AuthStatus.authenticated) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _carController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Go2Colors.canvas,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated logo
            AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) => Opacity(
                opacity: _logoOpacity.value,
                child: Transform.scale(scale: _logoScale.value, child: child),
              ),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Go2Colors.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Text('P', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Brand text
            AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) => Opacity(opacity: _textOpacity.value, child: child),
              child: Column(
                children: [
                  Text('Go2-Parking', style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w600, color: Go2Colors.textPrimary, letterSpacing: -0.5,
                  )),
                  const SizedBox(height: 4),
                  Text('Smart Parking Management', style: TextStyle(
                    fontSize: 13, color: Go2Colors.textSecondary,
                  )),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Animated car driving across
            SizedBox(
              height: 40,
              width: 200,
              child: AnimatedBuilder(
                animation: _carController,
                builder: (context, child) => FractionalTranslation(
                  translation: Offset(_carPosition.value, 0),
                  child: child,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_car_rounded, size: 32, color: Go2Colors.primary),
                    const SizedBox(width: 4),
                    // Motion lines
                    ...List.generate(3, (i) => Container(
                      width: 12 - (i * 3).toDouble(),
                      height: 2,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        color: Go2Colors.primary.withValues(alpha: 0.3 - (i * 0.1)),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
