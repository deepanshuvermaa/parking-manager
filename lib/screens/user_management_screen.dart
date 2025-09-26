import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/simplified_auth_provider.dart';
import '../services/user_management_service.dart';
import '../config/app_config.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _businessInfo;
  bool _isLoading = true;
  String? _error;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Check if feature is enabled
      if (!AppConfig.enableUserManagement) {
        setState(() {
          _error = 'User management feature is not enabled for your account';
          _isLoading = false;
        });
        return;
      }

      // Load business info first to get user's role
      final businessInfo = await UserManagementService.getBusinessInfo();
      _businessInfo = businessInfo;
      _userRole = businessInfo['userRole'];

      // Load users
      final users = await UserManagementService.getBusinessUsers();

      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showInviteDialog() {
    if (_userRole != 'owner' && _userRole != 'manager') {
      Helpers.showSnackBar(context, 'Only owners and managers can invite staff');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _InviteUserDialog(
        onInvite: (email, fullName, role) async {
          try {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const Center(
                child: CircularProgressIndicator(),
              ),
            );

            final result = await UserManagementService.inviteStaffMember(
              email: email,
              fullName: fullName,
              role: role,
            );

            Navigator.pop(context); // Close loading
            Navigator.pop(context); // Close dialog

            // Show success with temporary password
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Staff Member Added'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${result['user']['full_name']} has been added successfully.'),
                    const SizedBox(height: 16),
                    const Text('Temporary Credentials:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SelectableText('Email: ${result['user']['username']}'),
                    SelectableText('Password: ${result['temporaryPassword']}'),
                    const SizedBox(height: 16),
                    const Text(
                      'Please share these credentials with the staff member. They should change their password after first login.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _loadData(); // Refresh list
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          } catch (e) {
            Navigator.pop(context); // Close loading
            Helpers.showSnackBar(context, e.toString());
          }
        },
      ),
    );
  }

  void _updateUserRole(Map<String, dynamic> user) {
    if (_userRole != 'owner') {
      Helpers.showSnackBar(context, 'Only owners can update staff roles');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update ${user['full_name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Manager'),
              leading: Radio<String>(
                value: 'manager',
                groupValue: user['role'],
                onChanged: (value) async {
                  Navigator.pop(context);
                  await _performUpdate(user['id'], role: value);
                },
              ),
            ),
            ListTile(
              title: const Text('Operator'),
              leading: Radio<String>(
                value: 'operator',
                groupValue: user['role'],
                onChanged: (value) async {
                  Navigator.pop(context);
                  await _performUpdate(user['id'], role: value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performUpdate(String userId, {String? role, bool? isActive}) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      await UserManagementService.updateStaffMember(
        userId: userId,
        role: role,
        isActive: isActive,
      );

      Navigator.pop(context);
      _loadData();
      Helpers.showSnackBar(context, 'User updated successfully');
    } catch (e) {
      Navigator.pop(context);
      Helpers.showSnackBar(context, e.toString());
    }
  }

  void _toggleUserStatus(Map<String, dynamic> user) async {
    if (_userRole != 'owner') {
      Helpers.showSnackBar(context, 'Only owners can change staff status');
      return;
    }

    final newStatus = !(user['is_active'] ?? true);
    final action = newStatus ? 'activate' : 'deactivate';

    final confirmed = await Helpers.showConfirmDialog(
      context,
      title: 'Confirm Action',
      content: 'Are you sure you want to $action ${user['full_name']}?',
    );

    if (confirmed == true) {
      await _performUpdate(user['id'], isActive: newStatus);
    }
  }

  void _removeUser(Map<String, dynamic> user) async {
    if (_userRole != 'owner') {
      Helpers.showSnackBar(context, 'Only owners can remove staff');
      return;
    }

    final confirmed = await Helpers.showConfirmDialog(
      context,
      title: 'Remove Staff Member',
      content: 'Are you sure you want to remove ${user['full_name']}? They will no longer have access to the system.',
    );

    if (confirmed == true) {
      try {
        showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

        final success = await UserManagementService.removeStaffMember(user['id']);

        Navigator.pop(context);

        if (success) {
          _loadData();
          Helpers.showSnackBar(context, 'Staff member removed successfully');
        } else {
          Helpers.showSnackBar(context, 'Failed to remove staff member');
        }
      } catch (e) {
        Navigator.pop(context);
        Helpers.showSnackBar(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<SimplifiedAuthProvider>(context, listen: false);

    if (!AppConfig.enableUserManagement) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('User Management'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'User Management',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'This feature is coming soon!',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              if (authProvider.currentUser?['username'] == 'deepanshuverma966@gmail.com')
                ElevatedButton(
                  onPressed: () async {
                    await AppConfig.setUserManagement(true);
                    setState(() {});
                    _loadData();
                  },
                  child: const Text('Enable Beta Feature'),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('User Management'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_userRole == 'owner' || _userRole == 'manager')
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: _showInviteDialog,
              tooltip: 'Invite Staff',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error Loading Users',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Staff Members',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Invite staff members to help manage parking',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (_userRole == 'owner' || _userRole == 'manager') ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _showInviteDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('Invite First Staff'),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_businessInfo != null)
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.primary.withOpacity(0.1),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Role: ${UserManagementService.getRoleDisplayName(_userRole ?? '')}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Business ID: ${_businessInfo!['businessId']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_businessInfo!['stats']['total_users']} Users',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_businessInfo!['stats']['total_vehicles'] ?? 0} Vehicles',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              final isActive = user['is_active'] ?? true;
              final role = user['role'] ?? 'operator';
              final isCurrentUser = user['id'] == Provider.of<SimplifiedAuthProvider>(context, listen: false).userId;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(UserManagementService.getRoleColor(role)),
                    child: Text(
                      (user['full_name'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          user['full_name'] ?? 'Unknown User',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration: !isActive ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(UserManagementService.getRoleColor(role)).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          UserManagementService.getRoleDisplayName(role),
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(UserManagementService.getRoleColor(role)),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user['username'] ?? ''),
                      if (!isActive)
                        const Text(
                          'Inactive',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      if (user['last_login_at'] != null)
                        Text(
                          'Last login: ${_formatDate(user['last_login_at'])}',
                          style: const TextStyle(fontSize: 11),
                        ),
                    ],
                  ),
                  trailing: isCurrentUser
                      ? const Chip(
                          label: Text('You', style: TextStyle(fontSize: 12)),
                        )
                      : PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'role':
                                _updateUserRole(user);
                                break;
                              case 'status':
                                _toggleUserStatus(user);
                                break;
                              case 'remove':
                                _removeUser(user);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            if (_userRole == 'owner' && role != 'owner')
                              const PopupMenuItem(
                                value: 'role',
                                child: Text('Change Role'),
                              ),
                            if (_userRole == 'owner')
                              PopupMenuItem(
                                value: 'status',
                                child: Text(isActive ? 'Deactivate' : 'Activate'),
                              ),
                            if (_userRole == 'owner' && role != 'owner')
                              const PopupMenuItem(
                                value: 'remove',
                                child: Text('Remove', style: TextStyle(color: Colors.red)),
                              ),
                          ],
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Never';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 0) {
        return '${diff.inDays} days ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours} hours ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes} minutes ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateStr;
    }
  }
}

// Dialog for inviting new users
class _InviteUserDialog extends StatefulWidget {
  final Function(String email, String fullName, String role) onInvite;

  const _InviteUserDialog({required this.onInvite});

  @override
  State<_InviteUserDialog> createState() => _InviteUserDialogState();
}

class _InviteUserDialogState extends State<_InviteUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  String _selectedRole = 'operator';

  @override
  void dispose() {
    _emailController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite Staff Member'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'Enter staff member name',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter full name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Enter email address',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'manager',
                  child: Text('Manager - Can manage settings and view reports'),
                ),
                DropdownMenuItem(
                  value: 'operator',
                  child: Text('Operator - Can manage vehicle entries/exits'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedRole = value!;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onInvite(
                _emailController.text,
                _fullNameController.text,
                _selectedRole,
              );
            }
          },
          child: const Text('Send Invitation'),
        ),
      ],
    );
  }
}