import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/api_config.dart';
import '../theme/app_theme.dart';

class StaffOverviewScreen extends StatefulWidget {
  const StaffOverviewScreen({super.key});
  @override
  State<StaffOverviewScreen> createState() => _StaffOverviewScreenState();
}

class _StaffOverviewScreenState extends State<StaffOverviewScreen> {
  String _period = 'today';
  List<dynamic> _activity = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Map<String, String> get _headers {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/business/staff/activity?period=$_period'), headers: _headers);
      if (res.statusCode == 200) {
        setState(() => _activity = jsonDecode(res.body)['data'] ?? jsonDecode(res.body));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load activity (${res.statusCode})'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff Activity'), backgroundColor: Go2Colors.primary, foregroundColor: Colors.white),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: ['today', 'week', 'month'].map((p) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(p[0].toUpperCase() + p.substring(1)),
                selected: _period == p,
                selectedColor: Go2Colors.primary.withOpacity(0.2),
                onSelected: (_) { setState(() => _period = p); _fetch(); },
              ),
            )).toList(),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _activity.length,
                    itemBuilder: (_, i) {
                      final a = _activity[i];
                      return Card(
                        color: Go2Colors.surface,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text(a['full_name'] ?? a['username'] ?? '', style: TextStyle(color: Go2Colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Go2Colors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                child: Text(a['role'] ?? 'staff', style: TextStyle(color: Go2Colors.primary, fontSize: 12)),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              _stat(Icons.login, 'Parked', '${a['vehicles_parked'] ?? 0}', Go2Colors.primary),
                              _stat(Icons.logout, 'Exited', '${a['vehicles_exited'] ?? 0}', Go2Colors.success),
                              _stat(Icons.currency_rupee, 'Revenue', '₹${a['revenue'] ?? 0}', Go2Colors.textPrimary),
                            ]),
                            const SizedBox(height: 4),
                            Text('Last login: ${a['last_login'] ?? 'N/A'}', style: TextStyle(color: Go2Colors.textHint, fontSize: 12)),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _stat(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: Go2Colors.textHint)),
        ]),
      ]),
    );
  }
}
