import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:pashumauli/data/repositories/local_repositories.dart';
import 'package:pashumauli/domain/entities/entities.dart';
import 'package:pashumauli/presentation/widgets/common/common_widgets.dart';

/// Screen 7 — Add Animal
/// Fields: ear-tag, species, breed, sex, DOB, GPS location.
/// Writes to SQLite transaction before UI reports success.
class AddAnimalScreen extends ConsumerStatefulWidget {
  const AddAnimalScreen({super.key});

  @override
  ConsumerState<AddAnimalScreen> createState() => _AddAnimalScreenState();
}

class _AddAnimalScreenState extends ConsumerState<AddAnimalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _earTagCtrl = TextEditingController();
  final _breedCtrl = TextEditingController();
  final _farmerIdCtrl = TextEditingController();
  AnimalSpecies _species = AnimalSpecies.cattle;
  AnimalSex? _sex;
  DateTime? _dob;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _earTagCtrl.dispose();
    _breedCtrl.dispose();
    _farmerIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final now = DateTime.now();
      const uuid = Uuid();
      final animalId = uuid.v4();

      // For now use a placeholder farmer if none specified
      final farmerId = _farmerIdCtrl.text.trim().isEmpty
          ? 'LOCAL_FARMER'
          : _farmerIdCtrl.text.trim();

      final animal = LocalAnimal(
        id: animalId,
        earTagId: _earTagCtrl.text.trim(),
        farmerId: farmerId,
        species: _species,
        breed: _breedCtrl.text.trim().isEmpty ? null : _breedCtrl.text.trim(),
        sex: _sex,
        dateOfBirth: _dob,
        createdAt: now,
        updatedAt: now,
      );

      final repo = AnimalLocalRepository();
      await repo.insert(animal);

      // Enqueue for sync
      final syncItem = SyncQueueItem(
        id: uuid.v4(),
        clientId: animalId,
        entityType: 'ANIMAL',
        entityId: animalId,
        operation: 'CREATE',
        payload: {
          'ear_tag_id': animal.earTagId,
          'farmer_id': animal.farmerId,
          'species': animal.species.toApiString(),
          'breed': animal.breed,
          'sex': animal.sex?.toApiString(),
          'date_of_birth': animal.dateOfBirth?.toIso8601String(),
        },
        status: SyncStatus.pending,
        createdAt: now,
        updatedAt: now,
      );
      await SyncQueueRepository().enqueue(syncItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Animal saved locally'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Animal'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                ErrorBanner(message: _error!),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _earTagCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ear Tag ID *',
                  prefixIcon: Icon(Icons.label),
                  border: OutlineInputBorder(),
                  hintText: 'e.g. MH-2024-001',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ear tag is required' : null,
              ),
              const SizedBox(height: 16),
              const Text('Species *',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AnimalSpecies.values.map((s) {
                  final selected = _species == s;
                  return ChoiceChip(
                    label: Text(s.name.toUpperCase()),
                    selected: selected,
                    selectedColor: const Color(0xFF2E7D32),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _species = s),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _breedCtrl,
                decoration: const InputDecoration(
                  labelText: 'Breed',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Sex', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _SexChip(
                    label: 'Male',
                    selected: _sex == AnimalSex.male,
                    onTap: () => setState(() => _sex = AnimalSex.male),
                  ),
                  const SizedBox(width: 8),
                  _SexChip(
                    label: 'Female',
                    selected: _sex == AnimalSex.female,
                    onTap: () => setState(() => _sex = AnimalSex.female),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDob,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _dob != null
                        ? '${_dob!.day}/${_dob!.month}/${_dob!.year}'
                        : 'Tap to select date',
                    style: TextStyle(
                      color: _dob != null
                          ? Colors.black87
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _farmerIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Farmer ID (optional)',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                  hintText: 'Leave empty for standalone',
                ),
              ),
              const SizedBox(height: 32),
              PrimaryActionButton(
                label: 'Save Animal Locally',
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

class _SexChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SexChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color:
              selected ? const Color(0xFF2E7D32) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
