import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/api_config.dart';
import '../theme/app_theme.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});
  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  List<dynamic> _staff = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Map<String, String> get _headers {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
  }

  Future<void> _fetchStaff() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/business/staff'), headers: _headers);
      if (res.statusCode == 200) {
        setState(() => _staff = jsonDecode(res.body)['data'] ?? jsonDecode(res.body));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load staff (${res.statusCode})'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(dynamic staff) async {
    try {
      await http.put(
        Uri.parse('${ApiConfig.baseUrl}/business/staff/${staff['id']}'),
        headers: _headers,
        body: jsonEncode({'is_active': !(staff['is_active'] ?? true)}),
      );
      _fetchStaff();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteStaff(dynamic staff) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Staff'),
        content: Text('Remove ${staff['full_name'] ?? staff['username']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: TextStyle(color: Go2Colors.error))),
        ],
      ),
    );
    if (confirm == true) {
      await http.delete(Uri.parse('${ApiConfig.baseUrl}/business/staff/${staff['id']}'), headers: _headers);
      _fetchStaff();
    }
  }

  Future<void> _showAddDialog() async {
    final nameC = TextEditingController(), userC = TextEditingController(), passC = TextEditingController();
    String role = 'staff';
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add Staff'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Full Name')),
            TextField(controller: userC, decoration: const InputDecoration(labelText: 'Username')),
            TextField(controller: passC, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: role,
              items: const [DropdownMenuItem(value: 'staff', child: Text('Staff')), DropdownMenuItem(value: 'manager', child: Text('Manager'))],
              onChanged: (v) => setS(() => role = v!),
              decoration: const InputDecoration(labelText: 'Role'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await http.post(
                  Uri.parse('${ApiConfig.baseUrl}/business/staff'),
                  headers: _headers,
                  body: jsonEncode({'fullName': nameC.text, 'username': userC.text, 'password': passC.text, 'role': role}),
                );
                Navigator.pop(ctx);
                _fetchStaff();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Staff'), backgroundColor: Go2Colors.primary, foregroundColor: Colors.white),
      floatingActionButton: FloatingActionButton(onPressed: _showAddDialog, backgroundColor: Go2Colors.primary, child: const Icon(Icons.add, color: Colors.white)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchStaff,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _staff.length,
                itemBuilder: (_, i) {
                  final s = _staff[i];
                  final active = s['is_active'] ?? true;
                  return Dismissible(
                    key: Key(s['id'].toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), color: Go2Colors.error, child: const Icon(Icons.delete, color: Colors.white)),
                    onDismissed: (_) => _deleteStaff(s),
                    child: Card(
                      color: Go2Colors.surface,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(s['full_name'] ?? s['username'] ?? '', style: TextStyle(color: Go2Colors.textPrimary, fontWeight: FontWeight.w600)),
                        subtitle: Text('@${s['username'] ?? ''}', style: TextStyle(color: Go2Colors.textHint)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Go2Colors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: Text(s['role'] ?? 'staff', style: TextStyle(color: Go2Colors.primary, fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          Switch(value: active, activeColor: Go2Colors.success, onChanged: (_) => _toggleActive(s)),
                        ]),
                        onLongPress: () => _deleteStaff(s),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
