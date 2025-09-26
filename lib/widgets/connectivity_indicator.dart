import 'package:flutter/material.dart';

class ConnectivityIndicator extends StatelessWidget {
  const ConnectivityIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    // Simplified - always show as online since we're using direct API calls
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'Online',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Simplified - no banner needed
    return const SizedBox.shrink();
  }
}