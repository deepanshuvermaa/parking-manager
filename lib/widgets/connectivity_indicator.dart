import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/hybrid_auth_provider.dart';

class ConnectivityIndicator extends StatelessWidget {
  const ConnectivityIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HybridAuthProvider>(
      builder: (context, auth, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: auth.isOnline ? Colors.green.shade100 : Colors.orange.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: auth.isOnline ? Colors.green : Colors.orange,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                auth.isOnline ? Icons.cloud_done : Icons.cloud_off,
                size: 16,
                color: auth.isOnline ? Colors.green.shade700 : Colors.orange.shade700,
              ),
              const SizedBox(width: 4),
              Text(
                auth.isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 12,
                  color: auth.isOnline ? Colors.green.shade700 : Colors.orange.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HybridAuthProvider>(
      builder: (context, auth, child) {
        if (auth.isOnline) return const SizedBox.shrink();
        
        return Container(
          width: double.infinity,
          color: Colors.orange.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Running in offline mode. Data will sync when connection is restored.',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await auth.refreshConnectivity();
                },
                child: Text(
                  'Retry',
                  style: TextStyle(color: Colors.orange.shade700),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}