import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Screen 12 — AI Scan Result (Phase 5)
///
/// Displays risk engine output (deterministic) and optional vision finding.
/// Language strictly follows AI safety rules:
///   - "Possible finding" NOT "Diagnosis: X"
///   - Risk level with reasons
///   - Escalation notice for HIGH/CRITICAL
///   - Confidence always visible
///   - Disclaimer always visible
class AiResultScreen extends ConsumerWidget {
  final Map<String, dynamic>? resultData;
  const AiResultScreen({super.key, this.resultData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = resultData ?? {};

    final visionAvailable = data['vision_available'] as bool? ?? false;
    final visionError = data['vision_error'] as String?;
    final prediction = data['prediction'] as String?;
    final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;
    final inferenceMs = (data['inference_ms'] as num?)?.toInt() ?? 0;
    final modelName = data['model_name'] as String? ?? 'Unknown';

    final riskScore = (data['risk_score'] as num?)?.toInt() ?? 0;
    final riskLevelStr = data['risk_level'] as String? ?? 'low';
    final riskReasons = (data['risk_reasons'] as List?)?.cast<String>() ?? [];
    final escalation = data['escalation_recommended'] as bool? ?? false;
    final symptoms = (data['selected_symptoms'] as List?)?.cast<String>() ?? [];
    final severity = (data['severity'] as num?)?.toInt() ?? 0;

    final riskLevel = _riskLevel(riskLevelStr);
    final riskColor = _riskColor(riskLevel);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Risk Assessment Result'),
        backgroundColor: const Color(0xFF00838F),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Risk Level Card ───────────────────────────────────────────
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: riskColor.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    Icon(_riskIcon(riskLevel), color: riskColor, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'Risk Level: ${riskLevelStr.toUpperCase()}',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: riskColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Score: $riskScore / 100',
                      style: TextStyle(color: riskColor.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ─── Escalation Notice ─────────────────────────────────────────
            if (escalation) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_hospital,
                            color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Veterinary Review Recommended',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red)),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Risk signals indicate this case should be reviewed '
                      'by a qualified veterinarian as soon as possible.',
                      style: TextStyle(fontSize: 13, color: Colors.red),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ─── Risk Reasons ──────────────────────────────────────────────
            if (riskReasons.isNotEmpty) ...[
              const Text('Risk Signals Detected',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              ...riskReasons.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.circle, size: 8,
                            color: riskColor.withValues(alpha: 0.7)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(r, style: const TextStyle(fontSize: 13))),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
            ],

            // ─── Symptoms Summary ──────────────────────────────────────────
            if (symptoms.isNotEmpty) ...[
              const Text('Reported Symptoms',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: symptoms
                    .map((s) => Chip(
                          label: Text(s, style: const TextStyle(fontSize: 12)),
                          backgroundColor:
                              const Color(0xFF00838F).withValues(alpha: 0.1),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],

            // ─── Vision Finding (only if available) ────────────────────────
            if (visionAvailable && prediction != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Visual Screening Finding',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Possible finding: $prediction',
                              style: const TextStyle(fontSize: 14)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: confidence >= 0.6
                                  ? Colors.orange.shade100
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${(confidence * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: confidence >= 0.6
                                      ? Colors.orange.shade800
                                      : Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                      if (confidence < 0.6) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Low confidence — consult a veterinarian for evaluation.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.orange.shade700),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Model: $modelName · ${inferenceMs}ms',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ] else if (visionError == 'vision_unavailable') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.model_training,
                        color: Colors.grey.shade500, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Vision model not installed.\n'
                        'Risk assessment based on reported symptoms only.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ─── Severity ──────────────────────────────────────────────────
            if (severity > 0) ...[
              Text('Reported Severity: ${_severityLabel(severity)}',
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
            ],

            // ─── Disclaimer (always visible) ───────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI screening only — NOT a confirmed veterinary diagnosis. '
                      'All results must be verified by a qualified veterinarian.',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── Actions ───────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/home/cases/report'),
                icon: const Icon(Icons.medical_services),
                label: const Text('File a Health Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/home/advisory'),
                icon: const Icon(Icons.assistant),
                label: const Text('View Advisory'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => context.pop(),
                child: const Text('Back to Scan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _RiskLevel _riskLevel(String level) {
    switch (level.toLowerCase()) {
      case 'critical':
        return _RiskLevel.critical;
      case 'high':
        return _RiskLevel.high;
      case 'medium':
        return _RiskLevel.medium;
      default:
        return _RiskLevel.low;
    }
  }

  Color _riskColor(_RiskLevel level) {
    switch (level) {
      case _RiskLevel.critical:
        return Colors.red;
      case _RiskLevel.high:
        return Colors.orange;
      case _RiskLevel.medium:
        return Colors.amber.shade700;
      case _RiskLevel.low:
        return Colors.green;
    }
  }

  IconData _riskIcon(_RiskLevel level) {
    switch (level) {
      case _RiskLevel.critical:
        return Icons.emergency;
      case _RiskLevel.high:
        return Icons.warning_amber;
      case _RiskLevel.medium:
        return Icons.info;
      case _RiskLevel.low:
        return Icons.check_circle;
    }
  }

  String _severityLabel(int severity) {
    switch (severity) {
      case 1:
        return 'Mild';
      case 2:
        return 'Moderate';
      case 3:
        return 'Severe';
      case 4:
        return 'Critical';
      default:
        return 'None';
    }
  }
}

enum _RiskLevel { low, medium, high, critical }
