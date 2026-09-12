import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pashumauli/data/ai/ml_model_adapter.dart';
import 'package:pashumauli/data/ai/risk_engine.dart';
import 'package:pashumauli/presentation/widgets/common/common_widgets.dart';

/// Phase 5: Vision model scan screen.
/// Uses TFLiteAdapter when a validated model is installed; falls back to
/// StubMLAdapter (returns UnsupportedError) when no model is present.
/// Risk engine runs deterministically regardless of vision availability.
/// Screen 11 — AI Disease Scan
class AiScanScreen extends ConsumerStatefulWidget {
  const AiScanScreen({super.key});

  @override
  ConsumerState<AiScanScreen> createState() => _AiScanScreenState();
}

class _AiScanScreenState extends ConsumerState<AiScanScreen> {
  final _picker = ImagePicker();
  Uint8List? _imageBytes;
  bool _scanning = false;
  String? _scanError;

  // Symptom selections for risk engine
  final List<String> _selectedSymptoms = [];
  int _severity = 0;

  static const _symptomOptions = [
    'fever',
    'loss of appetite',
    'breathing difficulty',
    'spreading lesions',
    'lameness',
    'nasal discharge',
    'diarrhea',
  ];

  /// The active adapter — StubMLAdapter since no validated livestock model exists.
  /// When a validated .tflite model is installed, replace with TFLiteAdapter.
  final MLModelAdapter _adapter = StubMLAdapter();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = Uint8List.fromList(bytes);
        _scanError = null;
      });
    } catch (e) {
      setState(() => _scanError = 'Could not load image: $e');
    }
  }

  Future<void> _runScan() async {
    setState(() {
      _scanning = true;
      _scanError = null;
    });

    MLResult? mlResult;
    String? visionError;

    // Attempt vision inference
    try {
      // TFLiteAdapter.load() is called when a real model path is set.
      // StubMLAdapter.infer() always throws UnsupportedError.
      if (_imageBytes != null && _adapter.isReady) {
        mlResult = await _adapter.infer(_imageBytes!.toList());
      }
    } on UnsupportedError {
      // No validated livestock vision model installed — expected state.
      visionError = 'vision_unavailable';
    } on StateError catch (e) {
      visionError = e.message;
    } catch (e) {
      visionError = e.toString();
    }

    // Run deterministic risk engine
    final risk = RiskEngine.calculate(
      diseasePrediction: mlResult?.topPrediction,
      confidence: mlResult?.topConfidence ?? 0.0,
      symptoms: _selectedSymptoms,
      severity: _severity,
    );

    if (!mounted) return;
    setState(() => _scanning = false);

    context.push('/home/ai/result', extra: {
      'vision_available': visionError == null && mlResult != null,
      'vision_error': visionError,
      'prediction': mlResult?.topPrediction,
      'confidence': mlResult?.topConfidence ?? 0.0,
      'model_name': mlResult?.modelName ?? 'Not installed',
      'model_version': mlResult?.modelVersion ?? 'N/A',
      'inference_ms': mlResult?.inferenceMs ?? 0,
      'risk_score': risk.score,
      'risk_level': risk.level.name,
      'risk_reasons': risk.reasons,
      'escalation_recommended': risk.escalationRecommended,
      'selected_symptoms': List<String>.from(_selectedSymptoms),
      'severity': _severity,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Disease Scan'),
        backgroundColor: const Color(0xFF00838F),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vision model status banner
            _VisionModelStatusBanner(adapter: _adapter),
            const SizedBox(height: 16),

            // Image capture
            GestureDetector(
              onTap: () => _showImageSourceSheet(context),
              child: Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _imageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to capture or select image',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '(Optional — risk assessment works without image)',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade400),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Symptom selection for risk engine
            const Text('Reported Symptoms',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _symptomOptions.map((s) {
                final selected = _selectedSymptoms.contains(s);
                return FilterChip(
                  label: Text(s),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    v ? _selectedSymptoms.add(s) : _selectedSymptoms.remove(s);
                  }),
                  selectedColor: const Color(0xFF00838F).withValues(alpha: 0.2),
                  checkmarkColor: const Color(0xFF00838F),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Severity slider
            const Text('Severity',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Row(
              children: [
                const Text('Mild'),
                Expanded(
                  child: Slider(
                    value: _severity.toDouble(),
                    min: 0,
                    max: 4,
                    divisions: 4,
                    label: _severityLabel(_severity),
                    activeColor: const Color(0xFF00838F),
                    onChanged: (v) => setState(() => _severity = v.round()),
                  ),
                ),
                const Text('Critical'),
              ],
            ),

            if (_scanError != null) ...[
              const SizedBox(height: 8),
              Text(_scanError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],

            const SizedBox(height: 16),

            // Disclaimer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber,
                      color: Colors.amber.shade700, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'AI screening only — not a confirmed veterinary diagnosis.\n'
                      'All positive results must be reviewed by a qualified veterinarian.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            PrimaryActionButton(
              label: 'Run Risk Assessment',
              icon: Icons.analytics,
              onTap: _scanning ? null : _runScan,
              isLoading: _scanning,
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _severityLabel(int severity) {
    switch (severity) {
      case 0:
        return 'None';
      case 1:
        return 'Mild';
      case 2:
        return 'Moderate';
      case 3:
        return 'Severe';
      case 4:
        return 'Critical';
      default:
        return 'Unknown';
    }
  }

  @override
  void dispose() {
    _adapter.unload();
    super.dispose();
  }
}

class _VisionModelStatusBanner extends StatelessWidget {
  final MLModelAdapter adapter;
  const _VisionModelStatusBanner({required this.adapter});

  @override
  Widget build(BuildContext context) {
    if (adapter is StubMLAdapter) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.model_training, color: Colors.grey.shade600, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Vision model not installed.\n'
                'Risk assessment from reported symptoms is still available.',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ],
        ),
      );
    }
    if (adapter.isReady) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 16),
            SizedBox(width: 8),
            Text('Vision model ready', style: TextStyle(fontSize: 12)),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
