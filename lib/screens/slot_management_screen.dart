import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/parking_provider.dart';
import '../theme/app_theme.dart';

class SlotManagementScreen extends StatelessWidget {
  const SlotManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final parking = context.watch<ParkingProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Slot Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddZoneDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Go2Spacing.lg),
        children: [
          // Overall summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Go2Spacing.xl),
              child: Column(
                children: [
                  Text('Total Capacity', style: theme.textTheme.titleMedium),
                  const SizedBox(height: Go2Spacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _SummaryItem(
                        label: 'Total',
                        value: parking.totalCapacity.toString(),
                        color: Go2Colors.primary,
                      ),
                      _SummaryItem(
                        label: 'Occupied',
                        value: parking.totalOccupied.toString(),
                        color: Go2Colors.error,
                      ),
                      _SummaryItem(
                        label: 'Available',
                        value: parking.totalAvailable.toString(),
                        color: Go2Colors.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Go2Spacing.xl),

          Text('Zones', style: theme.textTheme.titleLarge),
          const SizedBox(height: Go2Spacing.md),

          if (parking.zones.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Go2Spacing.xxl),
                child: Column(
                  children: [
                    Icon(Icons.grid_view_rounded,
                        size: 48, color: Go2Colors.textHint),
                    const SizedBox(height: Go2Spacing.md),
                    Text('No zones configured',
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: Go2Spacing.sm),
                    Text('Add zones to track slot availability',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            )
          else
            ...parking.zones.map((zone) => _ZoneCard(zone: zone)),
        ],
      ),
    );
  }

  void _showAddZoneDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final slotsCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Zone'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Zone Name',
                  hintText: 'e.g., Ground Floor, Section A',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: Go2Spacing.lg),
              TextFormField(
                controller: slotsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total Slots',
                  hintText: 'e.g., 50',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = int.tryParse(v);
                  if (n == null || n <= 0) return 'Enter a valid number';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                context.read<ParkingProvider>().addZone(
                      nameCtrl.text.trim(),
                      int.parse(slotsCtrl.text.trim()),
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _ZoneCard extends StatelessWidget {
  final ParkingZone zone;
  const _ZoneCard({required this.zone});

  @override
  Widget build(BuildContext context) {
    final percent = zone.occupancyPercent;
    final color = percent > 90
        ? Go2Colors.error
        : percent > 70
            ? Go2Colors.warning
            : Go2Colors.success;

    return Card(
      margin: const EdgeInsets.only(bottom: Go2Spacing.md),
      child: Padding(
        padding: const EdgeInsets.all(Go2Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(zone.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'edit') {
                      _showEditDialog(context);
                    } else if (action == 'delete') {
                      _confirmDelete(context);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: Go2Spacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(Go2Radius.full),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 8,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: Go2Spacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${zone.occupiedSlots} / ${zone.totalSlots} occupied',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(Go2Radius.full),
                  ),
                  child: Text(
                    zone.isFull ? 'FULL' : '${zone.availableSlots} free',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: color),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: zone.name);
    final slotsCtrl = TextEditingController(text: zone.totalSlots.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Zone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Zone Name'),
            ),
            const SizedBox(height: Go2Spacing.lg),
            TextField(
              controller: slotsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Total Slots'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final slots = int.tryParse(slotsCtrl.text.trim());
              if (slots != null && slots > 0) {
                context.read<ParkingProvider>().updateZone(
                      zone.id,
                      name: nameCtrl.text.trim(),
                      totalSlots: slots,
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Zone'),
        content: Text('Remove "${zone.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ParkingProvider>().removeZone(zone.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Go2Colors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
