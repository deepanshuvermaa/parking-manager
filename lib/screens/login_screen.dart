import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);

    final auth = context.read<AuthProvider>();
    final result = await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (result == null) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (result == 'DEVICE_LIMIT') {
      _showDeviceLimitDialog();
    } else {
      setState(() => _error = result);
    }
  }

  Future<void> _startOffline() async {
    final auth = context.read<AuthProvider>();
    await auth.loginOffline();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _showDeviceLimitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Device Limit Reached'),
        content: const Text(
          'You can only be logged in on one device at a time. Please logout from your other device first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showGuestSignup() {
    final nameCtrl = TextEditingController();
    final parkingCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                const Row(children: [
                  Icon(Icons.rocket_launch_rounded, color: Go2Colors.primary, size: 28),
                  SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Start Free Trial', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Go2Colors.textPrimary)),
                    Text('7 days free. No credit card required.', style: TextStyle(fontSize: 13, color: Go2Colors.textSecondary)),
                  ])),
                ]),
                const SizedBox(height: 24),
                TextFormField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Your Name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: parkingCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Parking Business Name',
                    prefixIcon: const Icon(Icons.business_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email (optional)',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Used for login. Leave empty for auto-generated.',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Create Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 6) return 'Min 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(ctx);
                      final auth = context.read<AuthProvider>();
                      final result = await auth.guestSignup(
                        name: nameCtrl.text.trim(),
                        parkingName: parkingCtrl.text.trim(),
                        password: passCtrl.text,
                        phone: phoneCtrl.text.trim(),
                        email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                      );
                      if (!mounted) return;
                      if (result == null) {
                        Navigator.pushReplacementNamed(context, '/home');
                      } else {
                        setState(() => _error = result);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Go2Colors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Start 7-Day Free Trial'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().status == AuthStatus.loading;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0F4FF), Color(0xFFE8EEFF), Color(0xFFF5F0FF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo with glow
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: Go2Colors.primary,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: Go2Colors.primary.withValues(alpha: 0.35), blurRadius: 28, offset: const Offset(0, 10)),
                          ],
                        ),
                        child: const Icon(Icons.local_parking_rounded, size: 48, color: Colors.white),
                      ),
                      const SizedBox(height: 24),
                      const Text('Go2-Parking', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Go2Colors.textPrimary, letterSpacing: -0.5)),
                      const SizedBox(height: 6),
                      Text('Smart Parking Management', style: TextStyle(fontSize: 14, color: Go2Colors.textSecondary, fontWeight: FontWeight.w400, letterSpacing: 0.2)),
                      const SizedBox(height: 36),

                      // Error
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Go2Colors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Go2Colors.error.withValues(alpha: 0.2)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.info_outline_rounded, color: Go2Colors.error, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_error!, style: const TextStyle(color: Go2Colors.error, fontSize: 13, height: 1.3))),
                          ]),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Username field
                      TextFormField(
                        controller: _emailController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Username or Email',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Enter your username' : null,
                      ),
                      const SizedBox(height: 16),

                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleLogin(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: Colors.white,
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Enter your password' : null,
                      ),
                      const SizedBox(height: 24),

                      // Sign In button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Go2Colors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            elevation: 2,
                          ),
                          child: isLoading
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                              : const Text('Sign In'),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Divider
                      Row(children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('or', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ]),
                      const SizedBox(height: 20),

                      // Free Trial button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: isLoading ? null : _showGuestSignup,
                          icon: const Icon(Icons.rocket_launch_outlined, size: 20),
                          label: const Text('Start 7-Day Free Trial', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Go2Colors.primary, width: 1.5),
                            foregroundColor: Go2Colors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Offline mode
                      TextButton.icon(
                        onPressed: isLoading ? null : _startOffline,
                        icon: Icon(Icons.wifi_off_rounded, size: 16, color: Colors.grey.shade500),
                        label: Text('Use Offline (No Internet)', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                      ),
                      const SizedBox(height: 8),
                    ],
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
