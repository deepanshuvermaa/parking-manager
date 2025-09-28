import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_state_provider.dart';
import '../services/admin_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  final _newCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureNewCode = true;
  bool _obscurePassword = true;
  String? _currentCode;
  List<Map<String, String>> _auditLog = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _newCodeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      _currentCode = await AdminService.getDeletionCode();
      _auditLog = await AdminService.getAuditLog();
    } catch (e) {
      print('Error loading admin data: $e');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthStateProvider>();

    // Only super admin can access this screen
    if (!authProvider.isSuperAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: AppColors.primary,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Super Admin Access Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Only Deepanshu Verma can access this screen',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Management'),
        backgroundColor: AppColors.primary,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome message
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${authProvider.userEmail}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Super Admin • Full Access',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Deletion Code Management
                    _buildDeletionCodeSection(),
                    const SizedBox(height: 24),

                    // Device Management Summary
                    _buildDeviceManagementSection(),
                    const SizedBox(height: 24),

                    // Audit Log
                    _buildAuditLogSection(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDeletionCodeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Deletion Code Management',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Current code display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Deletion Code:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _currentCode ?? 'Loading...',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _resetDeletionCode,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Reset to Default',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Change code form
            TextFormField(
              controller: _newCodeController,
              obscureText: _obscureNewCode,
              decoration: InputDecoration(
                labelText: 'New Deletion Code',
                hintText: 'Enter new code (min 6 characters)',
                prefixIcon: const Icon(Icons.vpn_key),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscureNewCode = !_obscureNewCode),
                  icon: Icon(_obscureNewCode ? Icons.visibility : Icons.visibility_off),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Admin Password',
                hintText: 'Enter your admin password',
                prefixIcon: const Icon(Icons.admin_panel_settings),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _updateDeletionCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Update Deletion Code'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceManagementSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device Management',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'As super admin, you can manage device limits for all users through the backend. '
              'Device sync and multi-device support is now active.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Multi-device sync is enabled and working properly',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditLogSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Admin Audit Log',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _clearAuditLog,
                  child: const Text('Clear Log'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_auditLog.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No admin actions logged yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _auditLog.length.clamp(0, 10), // Show last 10 entries
                itemBuilder: (context, index) {
                  final entry = _auditLog[_auditLog.length - 1 - index]; // Reverse order
                  final timestamp = DateTime.tryParse(entry['timestamp'] ?? '');

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Icon(
                        _getActionIcon(entry['action'] ?? ''),
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      '${entry['action']} ${entry['itemType']}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'ID: ${entry['itemId']}\n'
                      'Time: ${timestamp != null ? Helpers.formatDateTime(timestamp) : 'Unknown'}',
                    ),
                    isThreeLine: true,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  IconData _getActionIcon(String action) {
    switch (action.toUpperCase()) {
      case 'DELETE':
        return Icons.delete;
      case 'UPDATE':
        return Icons.edit;
      case 'CREATE':
        return Icons.add;
      default:
        return Icons.info;
    }
  }

  Future<void> _updateDeletionCode() async {
    final newCode = _newCodeController.text.trim();
    final password = _passwordController.text.trim();

    if (newCode.isEmpty) {
      Helpers.showSnackBar(context, 'Please enter a new deletion code', isError: true);
      return;
    }

    if (newCode.length < 6) {
      Helpers.showSnackBar(context, 'Deletion code must be at least 6 characters', isError: true);
      return;
    }

    if (password.isEmpty) {
      Helpers.showSnackBar(context, 'Please enter your admin password', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await AdminService.setDeletionCode(newCode, password);

      if (success) {
        _newCodeController.clear();
        _passwordController.clear();
        await _loadData(); // Refresh current code

        if (mounted) {
          Helpers.showSnackBar(context, 'Deletion code updated successfully');
        }
      } else {
        if (mounted) {
          Helpers.showSnackBar(context, 'Invalid admin password or code too short', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to update deletion code: $e', isError: true);
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _resetDeletionCode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Deletion Code'),
        content: const Text(
          'Are you sure you want to reset the deletion code to default? '
          'This will require your admin password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Ask for admin password
    final password = await _askForAdminPassword();
    if (password == null) return;

    setState(() => _isLoading = true);

    try {
      final success = await AdminService.resetDeletionCode(password);

      if (success) {
        await _loadData(); // Refresh current code

        if (mounted) {
          Helpers.showSnackBar(context, 'Deletion code reset to default');
        }
      } else {
        if (mounted) {
          Helpers.showSnackBar(context, 'Invalid admin password', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to reset deletion code: $e', isError: true);
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _clearAuditLog() async {
    final password = await _askForAdminPassword();
    if (password == null) return;

    setState(() => _isLoading = true);

    try {
      final success = await AdminService.clearAuditLog(password);

      if (success) {
        await _loadData(); // Refresh audit log

        if (mounted) {
          Helpers.showSnackBar(context, 'Audit log cleared');
        }
      } else {
        if (mounted) {
          Helpers.showSnackBar(context, 'Invalid admin password', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to clear audit log: $e', isError: true);
      }
    }

    setState(() => _isLoading = false);
  }

  Future<String?> _askForAdminPassword() async {
    final controller = TextEditingController();
    bool obscure = true;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Admin Password Required'),
          content: TextFormField(
            controller: controller,
            obscureText: obscure,
            decoration: InputDecoration(
              labelText: 'Admin Password',
              prefixIcon: const Icon(Icons.admin_panel_settings),
              suffixIcon: IconButton(
                onPressed: () => setDialogState(() => obscure = !obscure),
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    return result;
  }
}