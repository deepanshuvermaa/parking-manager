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
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: Go2Spacing.xl,
          right: Go2Spacing.xl,
          top: Go2Spacing.xl,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + Go2Spacing.xl,
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Start Free Trial',
                    style: Theme.of(ctx).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text('7 days free. No credit card required.',
                    style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: Go2Spacing.xl),
                TextFormField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Your Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: Go2Spacing.lg),
                TextFormField(
                  controller: parkingCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Parking Business Name',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: Go2Spacing.lg),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: Go2Spacing.lg),
                TextFormField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Create Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 6) return 'Min 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: Go2Spacing.xl),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(ctx);
                    final auth = context.read<AuthProvider>();
                    final result = await auth.guestSignup(
                      name: nameCtrl.text.trim(),
                      parkingName: parkingCtrl.text.trim(),
                      password: passCtrl.text,
                      phone: phoneCtrl.text.trim(),
                    );
                    if (!mounted) return;
                    if (result == null) {
                      Navigator.pushReplacementNamed(context, '/home');
                    } else {
                      setState(() => _error = result);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Go2Colors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Start 7-Day Free Trial'),
                ),
                const SizedBox(height: Go2Spacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading =
        context.watch<AuthProvider>().status == AuthStatus.loading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Go2Spacing.xl),
            child: ConstrainedBox(
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
                        color: Go2Colors.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Go2Colors.primary.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_parking_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: Go2Spacing.xl),
                    Text(
                      'Go2-Parking',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: Go2Spacing.sm),
                    Text(
                      'Sign in to manage your parking',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Go2Colors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: Go2Spacing.xxxl),

                    // Error
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(Go2Spacing.md),
                        decoration: BoxDecoration(
                          color: Go2Colors.errorLight,
                          borderRadius: BorderRadius.circular(Go2Radius.md),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Go2Colors.error, size: 20),
                            const SizedBox(width: Go2Spacing.sm),
                            Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(
                                      color: Go2Colors.error, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Go2Spacing.xl),
                    ],

                    // Username
                    TextFormField(
                      controller: _emailController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Enter your username' : null,
                    ),
                    const SizedBox(height: Go2Spacing.lg),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleLogin(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Enter your password' : null,
                    ),
                    const SizedBox(height: Go2Spacing.xxl),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _handleLogin,
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Sign In'),
                      ),
                    ),
                    const SizedBox(height: Go2Spacing.lg),

                    // Divider
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: Go2Spacing.lg),
                          child: Text('or',
                              style: Theme.of(context).textTheme.bodySmall),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: Go2Spacing.lg),

                    // Guest signup
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isLoading ? null : _showGuestSignup,
                        icon: const Icon(Icons.rocket_launch_outlined),
                        label: const Text('Start Free Trial'),
                      ),
                    ),
                    const SizedBox(height: Go2Spacing.lg),

                    // Offline mode
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: isLoading ? null : _startOffline,
                        icon: const Icon(Icons.wifi_off_rounded, size: 18),
                        label: const Text('Use Offline (No Internet)'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
