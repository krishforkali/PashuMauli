import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pashumauli/data/repositories/local_repositories.dart';
import 'package:pashumauli/domain/entities/entities.dart';
import 'package:pashumauli/presentation/widgets/common/common_widgets.dart';

final vaccinationsProvider =
    FutureProvider.family<List<LocalVaccination>, String>(
        (ref, animalId) async {
  return VaccinationLocalRepository().getByAnimal(animalId);
});

/// Screen 9 — Vaccination History
class VaccinationHistoryScreen extends ConsumerWidget {
  final String animalId;
  const VaccinationHistoryScreen({super.key, required this.animalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaccsAsync = ref.watch(vaccinationsProvider(animalId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vaccination History'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: vaccsAsync.when(
        data: (vaccs) {
          if (vaccs.isEmpty) {
            return const EmptyState(
              message: 'No vaccination records found',
              icon: Icons.vaccines,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vaccs.length,
            itemBuilder: (_, i) => _VaccinationCard(vacc: vaccs[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorBanner(message: e.toString()),
      ),
    );
  }
}

class _VaccinationCard extends StatelessWidget {
  final LocalVaccination vacc;
  const _VaccinationCard({required this.vacc});

  @override
  Widget build(BuildContext context) {
    final administered = vacc.administeredAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.vaccines, color: Colors.blue.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vacc.vaccine,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      if (vacc.dose != null)
                        Text('Dose: ${vacc.dose}',
                            style:
                                TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                SyncStatusBadge(synced: vacc.synced),
              ],
            ),
            const Divider(height: 20),
            _InfoRow(Icons.calendar_today,
                '${administered.day}/${administered.month}/${administered.year}'),
            if (vacc.nextDueAt != null)
              _InfoRow(Icons.update,
                  'Next due: ${vacc.nextDueAt!.day}/${vacc.nextDueAt!.month}/${vacc.nextDueAt!.year}'),
            if (vacc.administeredBy != null)
              _InfoRow(Icons.person, 'By: ${vacc.administeredBy}'),
            if (vacc.batchNumber != null)
              _InfoRow(Icons.numbers, 'Batch: ${vacc.batchNumber}'),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}
