import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pashumauli/data/repositories/local_repositories.dart';
import 'package:pashumauli/domain/entities/entities.dart';
import 'package:pashumauli/presentation/widgets/common/common_widgets.dart';
import 'package:pashumauli/routing/app_router.dart';
import 'package:pashumauli/services/sync_engine.dart';

final farmerProvider =
    FutureProvider.family<LocalFarmer?, String>((ref, id) async {
  return FarmerLocalRepository().getById(id);
});

final farmerAnimalsProvider =
    FutureProvider.family<List<LocalAnimal>, String>((ref, farmerId) async {
  return AnimalLocalRepository().getByFarmer(farmerId);
});

/// Screen 5 — Farmer Profile
class FarmerProfileScreen extends ConsumerWidget {
  final String farmerId;
  const FarmerProfileScreen({super.key, required this.farmerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // "new" farmerId means add new farmer flow
    if (farmerId == 'new') {
      return const _AddFarmerScreen();
    }

    final farmerAsync = ref.watch(farmerProvider(farmerId));
    final animalsAsync = ref.watch(farmerAnimalsProvider(farmerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmer Profile'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: farmerAsync.when(
        data: (farmer) {
          if (farmer == null) {
            return const EmptyState(
              message: 'Farmer not found',
              icon: Icons.person_off,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _FarmerCard(farmer: farmer),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Animals',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: () => context.push('/animals/add'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
              animalsAsync.when(
                data: (animals) {
                  if (animals.isEmpty) {
                    return const EmptyState(
                      message: 'No animals registered',
                      icon: Icons.pets,
                    );
                  }
                  return Column(
                    children: animals
                        .map((a) => _AnimalTile(animal: a))
                        .toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorBanner(message: e.toString()),
              ),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorBanner(message: e.toString()),
      ),
    );
  }
}

class _FarmerCard extends StatelessWidget {
  final LocalFarmer farmer;
  const _FarmerCard({required this.farmer});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF2E7D32),
                  child: Text(
                    farmer.name.isNotEmpty ? farmer.name[0].toUpperCase() : 'F',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(farmer.name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(farmer.phone,
                          style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                SyncStatusBadge(synced: farmer.synced),
              ],
            ),
            if (farmer.addressText != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(farmer.addressText!,
                          style: TextStyle(color: Colors.grey.shade700))),
                ],
              ),
            ],
            if (farmer.latitude != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.gps_fixed, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${farmer.latitude!.toStringAsFixed(4)}, ${farmer.longitude!.toStringAsFixed(4)}',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnimalTile extends StatelessWidget {
  final LocalAnimal animal;
  const _AnimalTile({required this.animal});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.pets, color: Color(0xFF2E7D32)),
        title: Text(animal.earTagId,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            '${animal.species.name} • ${animal.status}'),
        trailing: SyncStatusBadge(synced: animal.synced),
        onTap: () => context
            .push(AppRoutes.animalProfilePath(animal.id)),
      ),
    );
  }
}

/// Add new farmer flow (embedded in farmer profile route with id="new")
class _AddFarmerScreen extends ConsumerStatefulWidget {
  const _AddFarmerScreen();

  @override
  ConsumerState<_AddFarmerScreen> createState() => _AddFarmerScreenState();
}

class _AddFarmerScreenState extends ConsumerState<_AddFarmerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final now = DateTime.now();
      final farmer = LocalFarmer(
        id: _generateUuid(),
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        addressText: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      final syncItem = SyncQueueItem(
        id: _generateUuid(),
        clientId: farmer.id,
        entityType: 'FARMER',
        entityId: farmer.id,
        operation: 'CREATE',
        payload: {
          'name': farmer.name,
          'phone': farmer.phone,
          'address_text': farmer.addressText,
        },
        status: SyncStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      final repo = FarmerLocalRepository();
      await repo.insertWithSync(farmer, syncItem);

      // Trigger background sync cycle
      ref.read(syncEngineProvider).sync();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Farmer saved locally — sync queued'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _generateUuid() {
    final uuid = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    return '${uuid.padLeft(12, '0')}-0000-4000-8000-000000000000';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Farmer'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_error != null) ErrorBanner(message: _error!),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    (v == null || v.length < 10)
                        ? 'Enter a valid phone number'
                        : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.home),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              PrimaryActionButton(
                label: 'Save Farmer Locally',
                icon: Icons.save,
                onTap: _loading ? null : _save,
                isLoading: _loading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
