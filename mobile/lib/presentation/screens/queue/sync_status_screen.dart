import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pashumauli/domain/entities/entities.dart';
import 'package:pashumauli/presentation/widgets/common/common_widgets.dart';
import 'package:pashumauli/services/connectivity_service.dart';
import 'package:pashumauli/services/sync_engine.dart';

/// Screen 15 — Sync Status
/// Real-time engine monitoring, pending/synced/failed counters, and manual triggers.
class SyncStatusScreen extends ConsumerWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectStatus = ref.watch(currentConnectivityProvider);
    final syncState = ref.watch(syncStateNotifierProvider);
    final isOnline = connectStatus == ConnectivityStatus.online;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Status'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'View Queue Items',
            onPressed: () => context.push('/home/queue'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const ConnectivityBadge(),
                  const SizedBox(height: 12),
                  Text(
                    isOnline
                        ? (syncState.isSyncing
                            ? 'Syncing local records with server…'
                            : 'Connected to server')
                        : 'Working offline — sync paused',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isOnline
                          ? (syncState.isSyncing
                              ? Colors.blue.shade700
                              : Colors.green.shade700)
                          : Colors.orange.shade700,
                    ),
                  ),
                  if (syncState.lastSyncTime != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Last synced: ${_formatTime(syncState.lastSyncTime!)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                  if (syncState.lastError != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        'Last error: ${syncState.lastError}',
                        style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                      ),
                    ),
                  ],
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
                  count: syncState.pendingCount,
                  color: Colors.orange,
                  icon: Icons.hourglass_empty,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Synced',
                  count: syncState.syncedCount,
                  color: Colors.green,
                  icon: Icons.cloud_done,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Failed',
                  count: syncState.failedCount,
                  color: Colors.red,
                  icon: Icons.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          PrimaryActionButton(
            label: syncState.isSyncing ? 'Syncing Now…' : 'Sync Now',
            icon: Icons.sync,
            isLoading: syncState.isSyncing,
            onTap: (syncState.isSyncing || !isOnline)
                ? null
                : () async {
                    await ref.read(syncStateNotifierProvider.notifier).sync();
                  },
          ),
          if (syncState.failedCount > 0) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, color: Colors.red),
              label: const Text('Retry Failed Items', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: syncState.isSyncing
                  ? null
                  : () async {
                      await ref.read(syncStateNotifierProvider.notifier).retryFailed();
                    },
            ),
          ],
          const SizedBox(height: 16),
          Card(
            color: Colors.green.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.green.shade200),
            ),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.verified, color: Color(0xFF2E7D32), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Phase 4 Sync Engine: Local mutations are committed atomically and replay automatically when network is restored.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1B5E20)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
