enum RiskLevel { low, medium, high, critical }

class RiskAssessment {
  const RiskAssessment(
      this.score, this.level, this.reasons, this.escalationRecommended);
  final int score;
  final RiskLevel level;
  final List<String> reasons;
  final bool escalationRecommended;
}

/// Deterministic triage scoring. It is intentionally independent of network and LLMs.
class RiskEngine {
  static RiskAssessment calculate(
      {String? diseasePrediction,
      required double confidence,
      List<String> symptoms = const [],
      int severity = 0,
      bool outbreakContext = false,
      int recentCaseDensity = 0,
      Map<String, String> animalContext = const {}}) {
    var score = 0;
    final reasons = <String>[];
    if (confidence >= .6 && diseasePrediction != null) {
      score += 20;
      reasons.add('Visual screening finding requires review');
    }
    if (symptoms.any((s) => [
          'fever',
          'loss of appetite',
          'breathing difficulty',
          'spreading lesions'
        ].contains(s.toLowerCase()))) {
      score += 20;
      reasons.add('Reported warning symptoms');
    }
    if (severity >= 3) {
      score += 25;
      reasons.add('Reported symptoms are severe');
    } else if (severity > 0) {
      score += severity * 5;
    }
    if (outbreakContext) {
      score += 20;
      reasons.add('Nearby suspected cases reported');
    }
    if (recentCaseDensity >= 3) {
      score += 15;
      reasons.add('Elevated recent case density');
    }
    score = score.clamp(0, 100);
    final level = score >= 75
        ? RiskLevel.critical
        : score >= 50
            ? RiskLevel.high
            : score >= 25
                ? RiskLevel.medium
                : RiskLevel.low;
    return RiskAssessment(
        score,
        level,
        reasons.isEmpty ? ['No high-risk signals reported'] : reasons,
        level == RiskLevel.high || level == RiskLevel.critical);
  }
}
