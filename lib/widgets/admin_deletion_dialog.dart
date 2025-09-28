import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/clean_auth_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class AdminDeletionDialog extends StatefulWidget {
  final String itemType;
  final String itemId;
  final String itemName;
  final Function() onConfirmed;

  const AdminDeletionDialog({
    super.key,
    required this.itemType,
    required this.itemId,
    required this.itemName,
    required this.onConfirmed,
  });

  @override
  State<AdminDeletionDialog> createState() => _AdminDeletionDialogState();
}

class _AdminDeletionDialogState extends State<AdminDeletionDialog> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _useAdminPassword = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<CleanAuthProvider>();

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning, color: AppColors.error, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Delete Confirmation Required',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to delete:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Text(
                '${widget.itemType}: ${widget.itemName}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Toggle between deletion code and admin password
            Row(
              children: [
                Checkbox(
                  value: _useAdminPassword,
                  onChanged: (value) {
                    setState(() {
                      _useAdminPassword = value ?? false;
                      _errorMessage = null;
                    });
                  },
                ),
                const Expanded(
                  child: Text(
                    'I forgot my deletion code, use admin password',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Input field
            if (!_useAdminPassword) ...[
              Text(
                'Enter your deletion code:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _codeController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Deletion Code',
                  prefixIcon: const Icon(Icons.security),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorText: _errorMessage,
                ),
              ),
            ] else ...[
              Text(
                'Enter admin password (Dv12062001@):',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Admin Password',
                  prefixIcon: const Icon(Icons.admin_panel_settings),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorText: _errorMessage,
                ),
              ),
            ],

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Text(
                '⚠️ Warning: This action cannot be undone. Make sure you want to permanently delete this item.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleDelete,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Delete'),
        ),
      ],
    );
  }

  Future<void> _handleDelete() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      bool isValid = false;

      if (_useAdminPassword) {
        // Validate admin password
        final password = _passwordController.text.trim();
        if (password.isEmpty) {
          setState(() {
            _errorMessage = 'Please enter the admin password';
            _isLoading = false;
          });
          return;
        }

        // Check if it's the correct admin password
        if (password == 'Dv12062001@') {
          isValid = true;
        } else {
          // Also check with backend for security
          final response = await ApiService.validateAdminPassword(password);
          isValid = response != null && response['success'] == true;
        }

        if (!isValid) {
          setState(() {
            _errorMessage = 'Invalid admin password';
            _isLoading = false;
          });
          return;
        }
      } else {
        // Validate deletion code
        final code = _codeController.text.trim();
        if (code.isEmpty) {
          setState(() {
            _errorMessage = 'Please enter the deletion code';
            _isLoading = false;
          });
          return;
        }

        final response = await ApiService.validateDeletionCode(
          code,
          widget.itemType,
          widget.itemId,
        );

        isValid = response != null && response['success'] == true;

        if (!isValid) {
          setState(() {
            _errorMessage = 'Invalid deletion code';
            _isLoading = false;
          });
          return;
        }
      }

      // If validation passed, proceed with deletion
      if (isValid) {
        Navigator.of(context).pop(); // Close dialog
        widget.onConfirmed(); // Execute deletion
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Validation failed: $e';
        _isLoading = false;
      });
    }
  }

  /// Static method to show the dialog
  static Future<void> show(
    BuildContext context, {
    required String itemType,
    required String itemId,
    required String itemName,
    required Function() onConfirmed,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdminDeletionDialog(
        itemType: itemType,
        itemId: itemId,
        itemName: itemName,
        onConfirmed: onConfirmed,
      ),
    );
  }
}