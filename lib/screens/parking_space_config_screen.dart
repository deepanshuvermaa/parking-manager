import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/parking_provider.dart';
import '../theme/app_theme.dart';

class ParkingSpaceConfigScreen extends StatefulWidget {
  const ParkingSpaceConfigScreen({super.key});

  @override
  State<ParkingSpaceConfigScreen> createState() => _ParkingSpaceConfigScreenState();
}

class _ParkingSpaceConfigScreenState extends State<ParkingSpaceConfigScreen> {
  @override
  Widget build(BuildContext context) {
    final parking = context.watch<ParkingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parking Space'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Zone',
            onPressed: () => _showAddZoneDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Go2Colors.skyWash,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: Go2Colors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Optional: Set your parking capacity to track available slots. Leave empty for unlimited.',
                style: TextStyle(fontSize: 12, color: Go2Colors.textSecondary),
              )),
            ]),
          ),
          const SizedBox(height: 20),

          // Summary
          if (parking.totalCapacity > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Go2Colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Go2Colors.divider, width: 0.5),
              ),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _StatChip(label: 'Total', value: '${parking.totalCapacity}', color: Go2Colors.primary),
                  _StatChip(label: 'Occupied', value: '${parking.totalOccupied}', color: Go2Colors.error),
                  _StatChip(label: 'Available', value: '${parking.totalAvailable}', color: Go2Colors.success),
                ]),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: parking.occupancyPercent / 100,
                    minHeight: 8,
                    backgroundColor: Go2Colors.success.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation(
                      parking.occupancyPercent > 90 ? Go2Colors.error
                          : parking.occupancyPercent > 70 ? Go2Colors.warning
                          : Go2Colors.success,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  parking.isFull ? 'PARKING FULL' : '${parking.occupancyPercent.toStringAsFixed(0)}% occupied',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: parking.isFull ? Go2Colors.error : Go2Colors.textSecondary,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
          ],

          // Zones list
          Text('Zones / Sections', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),

          if (parking.zones.isEmpty || (parking.zones.length == 1 && parking.zones.first.id == 'default' && parking.zones.first.totalSlots == 50))
            _buildEmptyState()
          else
            ...parking.zones.map((zone) => _ZoneTile(
              zone: zone,
              onEdit: () => _showEditDialog(zone),
              onDelete: () => _confirmDelete(zone),
            )),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(children: [
        Icon(Icons.grid_view_rounded, size: 48, color: Go2Colors.textHint.withOpacity(0.3)),
        const SizedBox(height: 12),
        const Text('No parking zones configured', style: TextStyle(fontSize: 14, color: Go2Colors.textSecondary)),
        const SizedBox(height: 4),
        const Text('Tap + to add zones (e.g., Ground Floor, Section A)', style: TextStyle(fontSize: 12, color: Go2Colors.textHint)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _showAddZoneDialog(context),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Zone'),
        ),
      ]),
    );
  }

  void _showAddZoneDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final slotsCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Parking Zone'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Zone Name', hintText: 'e.g., Ground Floor'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: slotsCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Total Slots (optional)',
                hintText: 'e.g., 50',
                helperText: 'Leave empty for unlimited',
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final slots = int.tryParse(slotsCtrl.text.trim()) ?? 0;
                context.read<ParkingProvider>().addZone(nameCtrl.text.trim(), slots > 0 ? slots : 9999);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(ParkingZone zone) {
    final nameCtrl = TextEditingController(text: zone.name);
    final slotsCtrl = TextEditingController(text: zone.totalSlots == 9999 ? '' : zone.totalSlots.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Zone'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Zone Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: slotsCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Total Slots (optional)', helperText: 'Leave empty for unlimited'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final slots = int.tryParse(slotsCtrl.text.trim()) ?? 0;
              context.read<ParkingProvider>().updateZone(
                zone.id,
                name: nameCtrl.text.trim(),
                totalSlots: slots > 0 ? slots : 9999,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(ParkingZone zone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Zone'),
        content: Text('Remove "${zone.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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

class _ZoneTile extends StatelessWidget {
  final ParkingZone zone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ZoneTile({required this.zone, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final percent = zone.totalSlots == 9999 ? 0.0 : zone.occupancyPercent;
    final isUnlimited = zone.totalSlots == 9999;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(zone.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          isUnlimited
              ? '${zone.occupiedSlots} parked • Unlimited capacity'
              : '${zone.occupiedSlots}/${zone.totalSlots} occupied • ${zone.availableSlots} free',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        leading: CircleAvatar(
          backgroundColor: zone.isFull && !isUnlimited ? Go2Colors.error.withOpacity(0.1) : Go2Colors.skyWash,
          child: Text(
            isUnlimited ? '∞' : '${percent.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: zone.isFull && !isUnlimited ? Go2Colors.error : Go2Colors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 11, color: Go2Colors.textHint)),
    ]);
  }
}
