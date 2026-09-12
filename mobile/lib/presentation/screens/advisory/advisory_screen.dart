import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pashumauli/data/ai/local_llm_provider.dart';
import 'package:pashumauli/data/ai/safety_validator.dart';

/// Advisory screen — Phase 5H
///
/// Integrates:
///   - AndroidLiteRtLmProvider via MethodChannel/EventChannel
///   - RiskEngine for deterministic triage
///   - SafetyValidator for output guardrails
///   - Veterinarian escalation for HIGH/CRITICAL
///   - Offline-safe (model loaded locally)
///   - Static advisories when LLM unavailable
///
/// Screen 13 — Advisory
class AdvisoryScreen extends ConsumerStatefulWidget {
  const AdvisoryScreen({super.key});

  @override
  ConsumerState<AdvisoryScreen> createState() => _AdvisoryScreenState();
}

class _AdvisoryScreenState extends ConsumerState<AdvisoryScreen> {
  final _llm = AndroidLiteRtLmProvider();
  final _promptController = TextEditingController();

  _ModelState _modelState = const _ModelState.checking();
  String _generatedText = '';
  bool _generating = false;
  bool _cancelled = false;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _checkAndInitModel();
  }

  Future<void> _checkAndInitModel() async {
    setState(() => _modelState = const _ModelState.checking());
    try {
      await _llm.initialize();
      final info = await _llm.modelInfo();
      setState(() {
        _modelState = _ModelState.fromInfo(info);
      });
    } catch (e) {
      setState(() => _modelState = _ModelState.error(e.toString()));
    }
  }

  Future<void> _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _generating = true;
      _cancelled = false;
      _generatedText = '';
    });

    final context = {
      'application': 'PashuMauli livestock health advisory',
      'disclaimer':
          'You are a livestock health advisory assistant. '
          'You provide general guidance only. '
          'You do not diagnose diseases, prescribe medicines, or give specific dosages. '
          'Always recommend veterinarian consultation for any health concern.',
      'risk_context': '',
    };

    final buffer = StringBuffer();

    try {
      await for (final chunk in _llm.sendMessage(context, prompt)) {
        if (_cancelled || !mounted) break;
        buffer.write(chunk);
        final validated = SafetyValidator.validate(
          buffer.toString(),
          lowConfidence: true,
        );
        setState(() => _generatedText = validated);
      }
    } catch (e) {
      if (!_cancelled) {
        setState(() => _generatedText =
            SafetyValidator.fallback);
      }
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  Future<void> _cancel() async {
    _cancelled = true;
    await _sub?.cancel();
    try {
      await _llm.cancelGeneration();
    } catch (_) {}
    if (mounted) setState(() => _generating = false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _llm.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Advisory'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload model',
            onPressed: _checkAndInitModel,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Model status ──────────────────────────────────────────────
            _ModelStatusCard(state: _modelState, onProvision: _checkAndInitModel),
            const SizedBox(height: 16),

            // ─── Static advisories (always available offline) ──────────────
            const _StaticAdvisories(),
            const SizedBox(height: 20),

            // ─── LLM chat panel (only when model is ready) ─────────────────
            if (_modelState.isReady) ...[
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Ask the AI Advisory Assistant',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                'Describe the animal\'s symptoms, age, and species for guidance.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _promptController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      'e.g. "My 3-year-old cow has fever and reduced appetite since 2 days..."',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _generating ? null : _generate,
                      icon: _generating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send),
                      label: Text(_generating ? 'Generating…' : 'Get Advisory'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                  if (_generating) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _cancel,
                      icon: const Icon(Icons.stop),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                    ),
                  ],
                ],
              ),
              if (_generatedText.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.assistant,
                                color: Color(0xFF2E7D32), size: 18),
                            const SizedBox(width: 8),
                            const Text('Advisory Response',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const Spacer(),
                            if (_generating)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(_generatedText,
                            style: const TextStyle(fontSize: 14, height: 1.5)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _AiDisclaimerBox(),
            ] else if (_modelState.isError || _modelState.isNotInstalled) ...[
              _ModelProvisioningGuide(
                modelState: _modelState,
                onRetry: _checkAndInitModel,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Model State ────────────────────────────────────────────────────────────

class _ModelState {
  final String status;
  final String? reason;

  const _ModelState(this.status, [this.reason]);

  const _ModelState.checking() : this('CHECKING');
  static _ModelState error(String msg) => _ModelState('ERROR', msg);
  static _ModelState fromInfo(LocalModelInfo info) =>
      _ModelState(info.status, info.reason);

  bool get isReady => status == 'READY';
  bool get isLoading => status == 'LOADING' || status == 'CHECKING';
  bool get isError => status == 'ERROR';
  bool get isNotInstalled => status == 'NOT_INSTALLED';
}

// ─── Model Status Card ───────────────────────────────────────────────────────

class _ModelStatusCard extends StatelessWidget {
  final _ModelState state;
  final VoidCallback onProvision;

  const _ModelStatusCard({required this.state, required this.onProvision});

  @override
  Widget build(BuildContext context) {
    final (color, icon, title, detail) = switch (state.status) {
      'READY' => (
          Colors.green,
          Icons.check_circle,
          'Gemma 3 1B Model Ready',
          state.reason ?? 'LiteRT-LM on CPU',
        ),
      'LOADING' || 'CHECKING' => (
          Colors.blue,
          Icons.hourglass_top,
          'Loading model…',
          'Please wait',
        ),
      'NOT_INSTALLED' => (
          Colors.orange,
          Icons.download,
          'Model Not Installed',
          'Push model via ADB to enable AI advisory',
        ),
      _ => (
          Colors.red,
          Icons.error,
          'Model Error',
          state.reason ?? 'Check device logs',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: color)),
                Text(detail,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ],
            ),
          ),
          if (!state.isReady && !state.isLoading)
            TextButton(
              onPressed: onProvision,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

// ─── Model Provisioning Guide ────────────────────────────────────────────────

class _ModelProvisioningGuide extends StatelessWidget {
  final _ModelState modelState;
  final VoidCallback onRetry;

  const _ModelProvisioningGuide(
      {required this.modelState, required this.onRetry});

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
                const Icon(Icons.download, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('How to Enable AI Advisory',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            const Text('1. Download the model on your PC:',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SelectableText(
              'Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm',
              style: TextStyle(
                  fontFamily: 'monospace', fontSize: 12, color: Colors.teal),
            ),
            const SizedBox(height: 8),
            const Text('2. Copy to device via ADB:',
                style: TextStyle(fontWeight: FontWeight.w500)),
            SelectableText(
              'adb shell mkdir -p /sdcard/Android/data/'
              'com.pashumauli.pashumauli/files/models\n'
              'adb push <model_file> /sdcard/Android/data/'
              'com.pashumauli.pashumauli/files/models/',
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.teal),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Check Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── AI Disclaimer ───────────────────────────────────────────────────────────

class _AiDisclaimerBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, size: 16, color: Colors.amber),
              SizedBox(width: 6),
              Text('AI Advisory Disclaimer',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          SizedBox(height: 6),
          Text(
            '• This is screening guidance, not a veterinary diagnosis.\n'
            '• AI output has not been verified by a licensed veterinarian.\n'
            '• Do not administer medicine based solely on AI output.\n'
            '• Consult a qualified veterinarian for any treatment decisions.',
            style: TextStyle(fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ─── Static Advisories (always offline-available) ───────────────────────────

class _StaticAdvisories extends StatelessWidget {
  const _StaticAdvisories();

  static const _advisories = [
    _Advisory(
      title: 'FMD Prevention',
      category: 'Disease Prevention',
      urgency: 'HIGH',
      urgencyColor: Color(0xFFC62828),
      summary:
          'Foot and Mouth Disease is highly contagious. Vaccinate all bovines, separate affected animals immediately, and notify your local veterinary authority.',
      icon: Icons.vaccines,
    ),
    _Advisory(
      title: 'Lumpy Skin Disease Alert',
      category: 'Disease Alert',
      urgency: 'MODERATE',
      urgencyColor: Color(0xFFE65100),
      summary:
          'Isolate animals showing nodular skin lesions. Report to field veterinarian for sample collection. Do not transport affected animals.',
      icon: Icons.warning_amber,
    ),
    _Advisory(
      title: 'Seasonal Deworming',
      category: 'Preventive Care',
      urgency: 'LOW',
      urgencyColor: Color(0xFF1565C0),
      summary:
          'Schedule deworming before monsoon season. Consult local veterinarian for species-appropriate anthelmintic selection.',
      icon: Icons.medical_information,
    ),
    _Advisory(
      title: 'Heat Stress Management',
      category: 'Animal Welfare',
      urgency: 'LOW',
      urgencyColor: Color(0xFF00838F),
      summary:
          'Provide shade, cool water, and adequate ventilation during summer. Monitor milk yield and feed intake as early stress indicators.',
      icon: Icons.thermostat,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: const Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.blue, size: 14),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Advisory content cached locally — available offline.',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text('General Advisories',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        ..._advisories.map((a) => _AdvisoryCard(advisory: a)),
      ],
    );
  }
}

class _Advisory {
  final String title, category, urgency, summary;
  final Color urgencyColor;
  final IconData icon;
  const _Advisory({
    required this.title,
    required this.category,
    required this.urgency,
    required this.urgencyColor,
    required this.summary,
    required this.icon,
  });
}

class _AdvisoryCard extends StatelessWidget {
  final _Advisory advisory;
  const _AdvisoryCard({required this.advisory});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: advisory.urgencyColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(advisory.icon,
                      color: advisory.urgencyColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(advisory.title,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(advisory.category,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: advisory.urgencyColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: advisory.urgencyColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    advisory.urgency,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: advisory.urgencyColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(advisory.summary,
                style: TextStyle(
                    color: Colors.grey.shade700, fontSize: 13, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

