import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pashumauli/domain/entities/entities.dart';
import 'package:pashumauli/presentation/screens/queue/offline_queue_screen.dart';
import 'package:pashumauli/presentation/widgets/common/common_widgets.dart';
import 'package:pashumauli/services/connectivity_service.dart';

/// Screen 15 — Sync Status
class SyncStatusScreen extends ConsumerWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectStatus = ref.watch(currentConnectivityProvider);
    final queueAsync = ref.watch(syncQueueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Status'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: queueAsync.when(
        data: (items) {
          final pending = items
              .where((i) => i.status == SyncStatus.pending)
              .length;
          final failed =
              items.where((i) => i.status == SyncStatus.failed).length;
          final synced =
              items.where((i) => i.status == SyncStatus.synced).length;
          final isOnline = connectStatus == ConnectivityStatus.online;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const ConnectivityBadge(),
                      const SizedBox(height: 16),
                      Text(
                        isOnline
                            ? 'Connected to server'
                            : 'Working offline — sync paused',
                        style: TextStyle(
                            color: isOnline
                                ? Colors.green.shade700
                                : Colors.orange.shade700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                        label: 'Pending',
                        count: pending,
                        color: Colors.orange,
                        icon: Icons.hourglass_empty),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                        label: 'Synced',
                        count: synced,
                        color: Colors.green,
                        icon: Icons.cloud_done),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                        label: 'Failed',
                        count: failed,
                        color: Colors.red,
                        icon: Icons.error),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Text(
                  'Phase 4 will enable automatic background sync when connectivity is restored.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorBanner(message: e.toString()),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _StatCard(
      {required this.label,
      required this.count,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color),
            ),
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
