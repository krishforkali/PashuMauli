import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pashumauli/data/repositories/local_repositories.dart';
import 'package:pashumauli/domain/entities/entities.dart';
import 'package:pashumauli/presentation/widgets/common/common_widgets.dart';
import 'package:pashumauli/routing/app_router.dart';

final animalDetailProvider =
    FutureProvider.family<LocalAnimal?, String>((ref, id) async {
  return AnimalLocalRepository().getById(id);
});

/// Screen 8 — Animal Profile
class AnimalProfileScreen extends ConsumerWidget {
  final String animalId;
  const AnimalProfileScreen({super.key, required this.animalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animalAsync = ref.watch(animalDetailProvider(animalId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Animal Profile'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.vaccines),
            onPressed: () =>
                context.push(AppRoutes.vaccinationHistoryPath(animalId)),
            tooltip: 'Vaccination History',
          ),
        ],
      ),
      body: animalAsync.when(
        data: (animal) {
          if (animal == null) {
            return const EmptyState(
              message: 'Animal not found',
              icon: Icons.pets,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AnimalHeaderCard(animal: animal),
              const SizedBox(height: 16),
              _AnimalDetailCard(animal: animal),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.vaccinationHistoryPath(animalId)),
                  icon: const Icon(Icons.vaccines),
                  label: const Text('View Vaccination History'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/home/cases/report'),
                  icon: const Icon(Icons.medical_services),
                  label: const Text('Report Health Issue'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
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

class _AnimalHeaderCard extends StatelessWidget {
  final LocalAnimal animal;
  const _AnimalHeaderCard({required this.animal});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.pets,
                  size: 48, color: Color(0xFF2E7D32)),
            ),
            const SizedBox(height: 12),
            Text(
              animal.earTagId,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${animal.species.name.toUpperCase()} • ${animal.status}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            SyncStatusBadge(synced: animal.synced),
          ],
        ),
      ),
    );
  }
}

class _AnimalDetailCard extends StatelessWidget {
  final LocalAnimal animal;
  const _AnimalDetailCard({required this.animal});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Details',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            _Row('Species', animal.species.name),
            if (animal.breed != null) _Row('Breed', animal.breed!),
            if (animal.sex != null) _Row('Sex', animal.sex!.name),
            if (animal.dateOfBirth != null)
              _Row('Date of Birth',
                  '${animal.dateOfBirth!.day}/${animal.dateOfBirth!.month}/${animal.dateOfBirth!.year}'),
            if (animal.latitude != null)
              _Row('Location',
                  '${animal.latitude!.toStringAsFixed(4)}, ${animal.longitude!.toStringAsFixed(4)}'),
            _Row('Created',
                '${animal.createdAt.day}/${animal.createdAt.month}/${animal.createdAt.year}'),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
