import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pashumauli/data/repositories/local_repositories.dart';
import 'package:pashumauli/domain/entities/entities.dart';
import 'package:pashumauli/presentation/widgets/common/common_widgets.dart';
import 'package:pashumauli/routing/app_router.dart';

final allAnimalsProvider = FutureProvider<List<LocalAnimal>>((ref) async {
  return AnimalLocalRepository().getAll();
});

/// Screen 6 — Animal List
class AnimalListScreen extends ConsumerStatefulWidget {
  const AnimalListScreen({super.key});

  @override
  ConsumerState<AnimalListScreen> createState() => _AnimalListScreenState();
}

class _AnimalListScreenState extends ConsumerState<AnimalListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final animalsAsync = ref.watch(allAnimalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Animal List'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/animals/add'),
        label: const Text('Add Animal'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by ear tag...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: animalsAsync.when(
              data: (animals) {
                final filtered = _searchQuery.isEmpty
                    ? animals
                    : animals
                        .where((a) => a.earTagId
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()))
                        .toList();
                if (filtered.isEmpty) {
                  return EmptyState(
                    message: _searchQuery.isEmpty
                        ? 'No animals registered yet'
                        : 'No animals matching "$_searchQuery"',
                    icon: Icons.pets,
                    actionLabel:
                        _searchQuery.isEmpty ? 'Add Animal' : null,
                    onAction: _searchQuery.isEmpty
                        ? () => context.push('/animals/add')
                        : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.refresh(allAnimalsProvider.future),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) =>
                        _AnimalListTile(animal: filtered[i]),
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorBanner(message: e.toString()),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimalListTile extends StatelessWidget {
  final LocalAnimal animal;
  const _AnimalListTile({required this.animal});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.pets, color: Color(0xFF2E7D32)),
        ),
        title: Text(
          animal.earTagId,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
            '${animal.species.name.toUpperCase()} • ${animal.breed ?? 'Unknown breed'} • ${animal.status}'),
        trailing: SyncStatusBadge(synced: animal.synced),
        onTap: () =>
            context.push(AppRoutes.animalProfilePath(animal.id)),
      ),
    );
  }
}
