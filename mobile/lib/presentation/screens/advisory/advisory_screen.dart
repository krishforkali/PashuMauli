import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Screen 13 — Advisory
/// Phase 3: static advisory content. Phase 4 will populate from API/offline cache.
class AdvisoryScreen extends ConsumerWidget {
  const AdvisoryScreen({super.key});

  static const _advisories = [
    _Advisory(
      title: 'FMD Prevention',
      category: 'Disease Prevention',
      urgency: 'HIGH',
      summary:
          'Foot and Mouth Disease outbreak reported in district. Vaccinate all bovines immediately.',
      icon: Icons.vaccines,
      color: Color(0xFFC62828),
    ),
    _Advisory(
      title: 'Lumpy Skin Disease Alert',
      category: 'Disease Alert',
      urgency: 'MEDIUM',
      summary:
          'Lumpy skin disease cases rising. Isolate affected animals and contact nearest vet.',
      icon: Icons.warning_amber,
      color: Color(0xFFE65100),
    ),
    _Advisory(
      title: 'Seasonal Deworming',
      category: 'Preventive Care',
      urgency: 'LOW',
      summary:
          'Schedule deworming before monsoon season. Consult local veterinarian for dosage.',
      icon: Icons.medical_information,
      color: Color(0xFF1565C0),
    ),
    _Advisory(
      title: 'Heat Stress Management',
      category: 'Animal Welfare',
      urgency: 'LOW',
      summary:
          'Ensure access to shade and clean water. Milk yield may drop during extreme heat.',
      icon: Icons.thermostat,
      color: Color(0xFF00838F),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advisories'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.cloud_off, color: Colors.blue, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Advisory content is cached locally. Connect to server for latest updates.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._advisories
              .map((a) => _AdvisoryCard(advisory: a))
              ,
        ],
      ),
    );
  }
}

class _Advisory {
  final String title;
  final String category;
  final String urgency;
  final String summary;
  final IconData icon;
  final Color color;

  const _Advisory({
    required this.title,
    required this.category,
    required this.urgency,
    required this.summary,
    required this.icon,
    required this.color,
  });
}

class _AdvisoryCard extends StatelessWidget {
  final _Advisory advisory;
  const _AdvisoryCard({required this.advisory});

  @override
  Widget build(BuildContext context) {
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
                    color: advisory.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      Icon(advisory.icon, color: advisory.color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(advisory.title,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      Text(advisory.category,
                          style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12)),
                    ],
                  ),
                ),
                _UrgencyBadge(urgency: advisory.urgency, color: advisory.color),
              ],
            ),
            const SizedBox(height: 12),
            Text(advisory.summary,
                style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}

class _UrgencyBadge extends StatelessWidget {
  final String urgency;
  final Color color;
  const _UrgencyBadge({required this.urgency, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        urgency,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
