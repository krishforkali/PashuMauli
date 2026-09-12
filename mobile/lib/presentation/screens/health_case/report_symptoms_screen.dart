import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:pashumauli/data/repositories/local_repositories.dart';
import 'package:pashumauli/domain/entities/entities.dart';
import 'package:pashumauli/presentation/widgets/common/common_widgets.dart';
import 'package:pashumauli/services/auth_notifier.dart';

/// Screen 10 — Report Symptoms
/// Captures: symptoms (checklist), notes, animal ID (optional), GPS.
class ReportSymptomsScreen extends ConsumerStatefulWidget {
  const ReportSymptomsScreen({super.key});

  @override
  ConsumerState<ReportSymptomsScreen> createState() =>
      _ReportSymptomsScreenState();
}

class _ReportSymptomsScreenState
    extends ConsumerState<ReportSymptomsScreen> {
  final _animalIdCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  static const _allSymptoms = [
    'Fever',
    'Loss of appetite',
    'Lethargy / weakness',
    'Nasal discharge',
    'Coughing',
    'Diarrhoea',
    'Lameness',
    'Skin lesions',
    'Swollen lymph nodes',
    'Eye discharge',
    'Difficulty breathing',
    'Mouth sores',
    'Weight loss',
    'Abnormal behavior',
    'Sudden death of nearby animals',
  ];

  final Set<String> _selectedSymptoms = {};

  @override
  void dispose() {
    _animalIdCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedSymptoms.isEmpty) {
      setState(() => _error = 'Select at least one symptom');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final now = DateTime.now();
      const uuid = Uuid();
      final caseId = uuid.v4();
      final clientId = uuid.v4();
      final authState = ref.read(authNotifierProvider);
      final userId = authState is AuthAuthenticated ? authState.userId : null;

      final healthCase = LocalHealthCase(
        id: caseId,
        clientId: clientId,
        animalId: _animalIdCtrl.text.trim().isEmpty
            ? null
            : _animalIdCtrl.text.trim(),
        reportedBy: userId,
        symptoms: {
          for (final s in _selectedSymptoms) s: true,
        },
        riskLevel: _selectedSymptoms.length > 5
            ? RiskLevel.high
            : RiskLevel.medium,
        createdAt: now,
        updatedAt: now,
      );

      final repo = HealthCaseLocalRepository();
      await repo.insert(healthCase);

      // Enqueue for sync
      final syncItem = SyncQueueItem(
        id: uuid.v4(),
        clientId: clientId,
        entityType: 'HEALTH_CASE',
        entityId: caseId,
        operation: 'CREATE',
        payload: {
          'client_id': clientId,
          'animal_id': healthCase.animalId,
          'symptoms': _selectedSymptoms.toList(),
          'notes': _notesCtrl.text.trim(),
          'risk_level': healthCase.riskLevel.toApiString(),
          'reported_by': userId,
        },
        status: SyncStatus.pending,
        createdAt: now,
        updatedAt: now,
      );
      await SyncQueueRepository().enqueue(syncItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Case saved locally — will sync when online'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Symptoms'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              ErrorBanner(message: _error!),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _animalIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Animal Ear Tag / ID (optional)',
                prefixIcon: Icon(Icons.pets),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Symptoms Observed *',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: _allSymptoms.map((symptom) {
                  final selected = _selectedSymptoms.contains(symptom);
                  return CheckboxListTile(
                    title: Text(symptom),
                    value: selected,
                    activeColor: const Color(0xFF2E7D32),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedSymptoms.add(symptom);
                        } else {
                          _selectedSymptoms.remove(symptom);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Additional Notes',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'AI screening only — not a confirmed diagnosis. Consult a veterinarian for high-risk cases.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            PrimaryActionButton(
              label: 'Submit Report',
              icon: Icons.send,
              onTap: _loading ? null : _submit,
              isLoading: _loading,
            ),
          ],
        ),
      ),
    );
  }
}
