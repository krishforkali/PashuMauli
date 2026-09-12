import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pashumauli/presentation/widgets/common/common_widgets.dart';

/// Screen 16 — Notifications
/// Phase 3: empty state placeholder. Phase 4 populates from WebSocket/FCM.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: const EmptyState(
        message: 'No notifications yet.\nEmergency broadcasts and alerts will appear here.',
        icon: Icons.notifications_none,
      ),
    );
  }
}
