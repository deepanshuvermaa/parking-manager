import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/hybrid_auth_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class SubscriptionScreen extends StatefulWidget {
  final bool isTrialExpired;
  
  const SubscriptionScreen({super.key, this.isTrialExpired = false});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  int _selectedPlanIndex = 1; // Default to monthly
  bool _isLoading = false;

  final List<Map<String, dynamic>> _plans = [
    {
      'name': 'Basic',
      'duration': 'Monthly',
      'price': 999,
      'originalPrice': 1299,
      'features': [
        'Unlimited Vehicle Entry/Exit',
        'Receipt Printing',
        'Daily Reports',
        'Bluetooth Printer Support',
        'Basic Customer Support',
      ],
      'popular': false,
    },
    {
      'name': 'Professional',
      'duration': 'Monthly',
      'price': 1499,
      'originalPrice': 1999,
      'features': [
        'Everything in Basic',
        'Monthly Reports & Analytics',
        'Vehicle Type Management',
        'GST Invoice Support',
        'Cloud Backup',
        'Priority Support',
      ],
      'popular': true,
    },
    {
      'name': 'Enterprise',
      'duration': 'Yearly',
      'price': 14999,
      'originalPrice': 19999,
      'features': [
        'Everything in Professional',
        'Multi-location Support',
        'Advanced Analytics',
        'Custom Branding',
        'API Access',
        'Dedicated Support Manager',
      ],
      'popular': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Subscription Plans'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: !widget.isTrialExpired,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.isTrialExpired) _buildTrialExpiredBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    _buildTrialStatus(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildPlansList(),
                  ],
                ),
              ),
            ),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildTrialExpiredBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.error.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(Icons.warning, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              'Your trial has expired. Please subscribe to continue using ParkEase.',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialStatus() {
    return Consumer<HybridAuthProvider>(
      builder: (context, authProvider, _) {
        if (!authProvider.isGuest) return const SizedBox.shrink();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trial Status',
                  style: TextStyle(
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      authProvider.canAccess ? Icons.access_time : Icons.lock,
                      color: authProvider.canAccess ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        authProvider.canAccess
                            ? '${authProvider.remainingTrialDays} days remaining in your free trial'
                            : 'Your free trial has expired',
                        style: TextStyle(
                          color: authProvider.canAccess ? AppColors.success : AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlansList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Your Plan',
          style: TextStyle(
            fontSize: AppFontSize.xl,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _plans.length,
          itemBuilder: (context, index) {
            final plan = _plans[index];
            final isSelected = _selectedPlanIndex == index;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPlanIndex = index;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.divider,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
                ),
                child: Stack(
                  children: [
                    if (plan['popular'])
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(AppRadius.md),
                              bottomLeft: Radius.circular(AppRadius.sm),
                            ),
                          ),
                          child: const Text(
                            'POPULAR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: AppFontSize.xs,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      plan['name'],
                                      style: const TextStyle(
                                        fontSize: AppFontSize.lg,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      plan['duration'],
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    Helpers.formatCurrency(plan['price'].toDouble()),
                                    style: const TextStyle(
                                      fontSize: AppFontSize.xl,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    Helpers.formatCurrency(plan['originalPrice'].toDouble()),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ...plan['features'].map<Widget>((feature) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: AppColors.success,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        feature,
                                        style: const TextStyle(fontSize: AppFontSize.sm),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    final selectedPlan = _plans[_selectedPlanIndex];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total:',
                style: TextStyle(
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                Helpers.formatCurrency(selectedPlan['price'].toDouble()),
                style: const TextStyle(
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _subscribeToPlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text('Subscribe to ${selectedPlan['name']}'),
            ),
          ),
          if (!widget.isTrialExpired) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue with Trial'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _subscribeToPlan() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate subscription process
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      Helpers.showSnackBar(
        context,
        'Subscription functionality not implemented yet. This would open payment gateway.',
      );
    }
  }
}