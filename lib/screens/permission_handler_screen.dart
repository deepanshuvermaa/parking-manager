import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/constants.dart';

class PermissionHandlerScreen extends StatefulWidget {
  final Widget child;

  const PermissionHandlerScreen({super.key, required this.child});

  @override
  State<PermissionHandlerScreen> createState() => _PermissionHandlerScreenState();
}

class _PermissionHandlerScreenState extends State<PermissionHandlerScreen> {
  bool _isCheckingPermissions = true;
  Map<Permission, PermissionStatus> _permissionStatuses = {};

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    // List of permissions needed
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];

    // Check current status
    for (var permission in permissions) {
      final status = await permission.status;
      _permissionStatuses[permission] = status;
    }

    // Request permissions that are not granted
    bool allGranted = true;
    for (var entry in _permissionStatuses.entries) {
      if (!entry.value.isGranted && !entry.value.isPermanentlyDenied) {
        final status = await entry.key.request();
        _permissionStatuses[entry.key] = status;
      }
      if (!_permissionStatuses[entry.key]!.isGranted) {
        allGranted = false;
      }
    }

    setState(() {
      _isCheckingPermissions = false;
    });

    // If all permissions are granted, proceed to the app
    if (allGranted) {
      // Permissions are granted, the app will show normally
    }
  }

  String _getPermissionName(Permission permission) {
    switch (permission.toString()) {
      case 'Permission.bluetooth':
        return 'Bluetooth';
      case 'Permission.bluetoothScan':
        return 'Bluetooth Scan';
      case 'Permission.bluetoothConnect':
        return 'Bluetooth Connect';
      case 'Permission.locationWhenInUse':
        return 'Location';
      default:
        return permission.toString();
    }
  }

  String _getPermissionDescription(Permission permission) {
    switch (permission.toString()) {
      case 'Permission.bluetooth':
        return 'Required to enable Bluetooth functionality';
      case 'Permission.bluetoothScan':
        return 'Required to scan for nearby Bluetooth printers';
      case 'Permission.bluetoothConnect':
        return 'Required to connect to thermal printers for receipt printing';
      case 'Permission.locationWhenInUse':
        return 'Required for Bluetooth scanning on Android 11 and below (Android requirement, not used for tracking)';
      default:
        return 'Required for app functionality';
    }
  }

  Widget _buildPermissionTile(Permission permission, PermissionStatus status) {
    IconData icon;
    Color color;
    String subtitle;

    if (status.isGranted) {
      icon = Icons.check_circle;
      color = Colors.green;
      subtitle = 'Permission granted';
    } else if (status.isPermanentlyDenied) {
      icon = Icons.block;
      color = Colors.red;
      subtitle = 'Permission permanently denied - tap to open settings';
    } else if (status.isDenied) {
      icon = Icons.warning;
      color = Colors.orange;
      subtitle = 'Permission denied - tap to request';
    } else {
      icon = Icons.help_outline;
      color = Colors.grey;
      subtitle = 'Permission status unknown';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(
          _getPermissionName(permission),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: TextStyle(color: color, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              _getPermissionDescription(permission),
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
        trailing: !status.isGranted
            ? ElevatedButton(
                onPressed: () async {
                  if (status.isPermanentlyDenied) {
                    await openAppSettings();
                  } else {
                    final newStatus = await permission.request();
                    setState(() {
                      _permissionStatuses[permission] = newStatus;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(status.isPermanentlyDenied ? 'Settings' : 'Allow'),
              )
            : const Icon(Icons.check_circle, color: Colors.green, size: 28),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if all permissions are granted
    bool allGranted = _permissionStatuses.values.every((status) => status.isGranted);

    if (_isCheckingPermissions) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.7),
              ],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                SizedBox(height: 20),
                Text(
                  'Checking permissions...',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // If all permissions are granted, show the main app
    if (allGranted) {
      return widget.child;
    }

    // Otherwise show permission request screen
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Permissions'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              children: [
                Icon(
                  Icons.security,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Permissions Required',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ParkEase needs these permissions to work properly',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Required Permissions:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ..._permissionStatuses.entries.map((entry) =>
                    _buildPermissionTile(entry.key, entry.value)),
                const SizedBox(height: 24),
                if (!allGranted)
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _checkAndRequestPermissions();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry Permissions'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await openAppSettings();
                        },
                        icon: const Icon(Icons.settings),
                        label: const Text('Open App Settings'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          // Force navigate to app even without permissions
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => widget.child),
                          );
                        },
                        child: const Text('Continue without permissions (limited functionality)'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}