import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pashumauli/data/repositories/local_repositories.dart';
import 'package:pashumauli/domain/entities/entities.dart';
import 'package:pashumauli/presentation/widgets/common/common_widgets.dart';
import 'package:pashumauli/services/sync_engine.dart';

final syncQueueProvider =
    FutureProvider<List<SyncQueueItem>>((ref) async {
  return SyncQueueRepository().getAll();
});

/// Screen 14 — Offline Queue
/// Shows all pending/synced/failed sync operations.
class OfflineQueueScreen extends ConsumerWidget {
  const OfflineQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(syncQueueProvider);
    final syncState = ref.watch(syncStateNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Queue'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: syncState.isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Sync Now',
            onPressed: syncState.isSyncing
                ? null
                : () async {
                    await ref.read(syncEngineProvider).sync();
                    ref.invalidate(syncQueueProvider);
                  },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh list',
            onPressed: () => ref.refresh(syncQueueProvider),
          ),
        ],
      ),
      body: queueAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              message: 'Offline queue is empty.\nAll data is synced!',
              icon: Icons.cloud_done,
            );
          }

          final pending =
              items.where((i) => i.status == SyncStatus.pending).toList();
          final synced =
              items.where((i) => i.status == SyncStatus.synced).toList();
          final failed =
              items.where((i) => i.status == SyncStatus.failed).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (pending.isNotEmpty) ...[
                _SectionHeader(
                    label: 'Pending (${pending.length})',
                    color: Colors.orange),
                ...pending.map((i) => _QueueTile(item: i)),
              ],
              if (failed.isNotEmpty) ...[
                const SizedBox(height: 8),
                _SectionHeader(
                    label: 'Failed (${failed.length})',
                    color: Colors.red),
                ...failed.map((i) => _QueueTile(
                      item: i,
                      onRetry: () async {
                        await ref
                            .read(syncStateNotifierProvider.notifier)
                            .retryItem(i.id);
                        ref.invalidate(syncQueueProvider);
                      },
                    )),
              ],
              if (synced.isNotEmpty) ...[
                const SizedBox(height: 8),
                _SectionHeader(
                    label: 'Synced (${synced.length})',
                    color: Colors.green),
                ...synced.map((i) => _QueueTile(item: i)),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorBanner(message: e.toString()),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color),
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  final SyncQueueItem item;
  final VoidCallback? onRetry;
  const _QueueTile({required this.item, this.onRetry});

  Color get _statusColor {
    switch (item.status) {
      case SyncStatus.pending:
        return Colors.orange;
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.synced:
        return Colors.green;
      case SyncStatus.failed:
        return Colors.red;
    }
  }

  IconData get _statusIcon {
    switch (item.status) {
      case SyncStatus.pending:
        return Icons.hourglass_empty;
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.synced:
        return Icons.cloud_done;
      case SyncStatus.failed:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_statusIcon, color: _statusColor),
        title: Text('${item.entityType} • ${item.operation}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${item.entityId.substring(0, item.entityId.length > 8 ? 8 : item.entityId.length)}…'),
            Text(
                '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year} • Attempts: ${item.attemptCount}'),
            if (item.lastError != null)
              Text('Error: ${item.lastError}',
                  style: const TextStyle(color: Colors.red, fontSize: 11)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.status == SyncStatus.failed && onRetry != null)
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.red),
                tooltip: 'Retry item',
                onPressed: onRetry,
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _statusColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                item.status.name.toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    color: _statusColor,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
