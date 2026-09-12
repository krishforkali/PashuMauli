import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pashumauli/routing/app_router.dart';
import 'package:pashumauli/services/auth_notifier.dart';
import 'package:pashumauli/services/locale_notifier.dart';

/// Screen 17 — Settings
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final locale = ref.watch(localeNotifierProvider);

    final userName = authState is AuthAuthenticated ? authState.name : '';
    final userRole = authState is AuthAuthenticated
        ? authState.role.toApiString()
        : '';
    final userPhone = authState is AuthAuthenticated ? authState.phone : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          // Profile section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF2E7D32),
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(userPhone,
                            style: TextStyle(color: Colors.grey.shade600)),
                        Text(userRole,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Language section
          const _SectionLabel('Language'),
          ListTile(
            leading: const Icon(Icons.language, color: Color(0xFF2E7D32)),
            title: const Text('Display Language'),
            subtitle: Text(_localeName(locale.languageCode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.language),
          ),

          // Account section
          const _SectionLabel('Account'),
          ListTile(
            leading: const Icon(Icons.sync, color: Color(0xFF2E7D32)),
            title: const Text('Sync Status'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/home/sync'),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_queue, color: Color(0xFF2E7D32)),
            title: const Text('Offline Queue'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/home/queue'),
          ),

          // About section
          const _SectionLabel('About'),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Color(0xFF2E7D32)),
            title: const Text('App Version'),
            subtitle: const Text('1.0.0+1 (Phase 3)'),
          ),
          ListTile(
            leading: const Icon(Icons.security, color: Color(0xFF2E7D32)),
            title: const Text('SIH Problem Statement'),
            subtitle: const Text('26128 — Livestock Disease Surveillance'),
          ),

          // Logout
          const _SectionLabel(''),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(context, ref),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Logout',
                  style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade300),
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _localeName(String code) {
    switch (code) {
      case 'hi':
        return 'हिन्दी (Hindi)';
      case 'mr':
        return 'मराठी (Marathi)';
      default:
        return 'English';
    }
  }

  Future<void> _showLogoutDialog(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content:
            const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authNotifierProvider.notifier).logout();
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
