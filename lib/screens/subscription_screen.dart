import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

/// Subscription plans and pricing screen.
/// Replaces the old "contact developer" dead-end with a proper upgrade flow.
class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade Plan')),
      body: ListView(
        padding: const EdgeInsets.all(Go2Spacing.lg),
        children: [
          // Header
          Text('Choose Your Plan', style: theme.textTheme.displaySmall),
          const SizedBox(height: Go2Spacing.sm),
          Text(
            'Unlock all features and grow your parking business',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: Go2Colors.textSecondary),
          ),
          const SizedBox(height: Go2Spacing.xl),

          // Plans
          _PlanCard(
            name: 'Starter',
            price: '₹299',
            period: '/month',
            features: const [
              'Up to 50 slots',
              'Thermal printer support',
              'Basic reports',
              'Offline mode',
              '1 device',
            ],
            color: Go2Colors.primary,
            isPopular: false,
            onSelect: () => _handlePurchase(context, 'starter'),
          ),
          const SizedBox(height: Go2Spacing.lg),
          _PlanCard(
            name: 'Professional',
            price: '₹599',
            period: '/month',
            features: const [
              'Up to 200 slots',
              'Multi-zone management',
              'UPI QR payments',
              'Advanced reports & charts',
              'Staff management (2 devices)',
              'SMS notifications',
              'Priority support',
            ],
            color: Go2Colors.accent,
            isPopular: true,
            onSelect: () => _handlePurchase(context, 'professional'),
          ),
          const SizedBox(height: Go2Spacing.lg),
          _PlanCard(
            name: 'Enterprise',
            price: '₹1499',
            period: '/month',
            features: const [
              'Unlimited slots',
              'Multi-location support',
              'Unlimited devices',
              'Custom branding on receipts',
              'API access',
              'Dedicated support',
              'Monthly pass management',
              'Revenue forecasting',
            ],
            color: Color(0xFF7C4DFF),
            isPopular: false,
            onSelect: () => _handlePurchase(context, 'enterprise'),
          ),
          const SizedBox(height: Go2Spacing.xl),

          // Annual discount
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Go2Spacing.lg),
              child: Row(
                children: [
                  const Icon(Icons.savings_outlined, color: Go2Colors.success),
                  const SizedBox(width: Go2Spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Save 20% with annual billing',
                            style: theme.textTheme.titleSmall),
                        Text('Pay yearly and get 2 months free',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Go2Spacing.xl),

          // Contact for custom
          Center(
            child: TextButton(
              onPressed: () => _contactSupport(context),
              child: const Text('Need a custom plan? Contact us'),
            ),
          ),
          const SizedBox(height: Go2Spacing.xxl),
        ],
      ),
    );
  }

  void _handlePurchase(BuildContext context, String plan) {
    final planName = plan[0].toUpperCase() + plan.substring(1);
    final msg = Uri.encodeComponent('Hi, I want to subscribe to the $planName plan for Go2-Parking. Please share payment details.');
    _openWhatsApp(context, msg);
  }

  void _contactSupport(BuildContext context) {
    final msg = Uri.encodeComponent('Hi, I need help with Go2-Parking subscription.');
    _openWhatsApp(context, msg);
  }

  void _openWhatsApp(BuildContext context, String message) async {
    // Replace with your actual support WhatsApp number
    final url = Uri.parse('https://wa.me/917876483280?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp. Contact: +91 78764 83280'), backgroundColor: Go2Colors.error),
      );
    }
  }
}

class _PlanCard extends StatelessWidget {
  final String name;
  final String price;
  final String period;
  final List<String> features;
  final Color color;
  final bool isPopular;
  final VoidCallback onSelect;

  const _PlanCard({
    required this.name,
    required this.price,
    required this.period,
    required this.features,
    required this.color,
    required this.isPopular,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Go2Radius.lg),
        side: isPopular
            ? BorderSide(color: color, width: 2)
            : const BorderSide(color: Go2Colors.divider),
      ),
      child: Column(
        children: [
          if (isPopular)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: color,
              child: const Text(
                'MOST POPULAR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(Go2Spacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, color: color)),
                const SizedBox(height: Go2Spacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(price,
                        style: const TextStyle(
                            fontSize: 32, fontWeight: FontWeight.w800)),
                    Text(period,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: Go2Spacing.lg),
                ...features.map((f) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: color, size: 18),
                          const SizedBox(width: Go2Spacing.sm),
                          Expanded(
                              child: Text(f,
                                  style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    )),
                const SizedBox(height: Go2Spacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: isPopular
                      ? ElevatedButton(
                          onPressed: onSelect,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: color),
                          child: const Text('Get Started'),
                        )
                      : OutlinedButton(
                          onPressed: onSelect,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: color),
                            foregroundColor: color,
                          ),
                          child: const Text('Select Plan'),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
