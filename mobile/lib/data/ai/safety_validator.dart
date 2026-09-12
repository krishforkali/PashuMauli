class SafetyValidator {
  static const fallback =
      'I cannot safely provide a definitive answer from the available information. Please provide more symptoms or consult a veterinarian.';
  static String validate(String text, {required bool lowConfidence}) {
    final lower = text.toLowerCase();
    final unsafe = [
      'confirmed disease',
      'definitely has',
      ' mg',
      ' ml',
      'dosage',
      'prescribe',
      'give medicine'
    ];
    if (text.trim().isEmpty ||
        unsafe.any(lower.contains) ||
        (lowConfidence && lower.contains('diagnosis'))) {
      return fallback;
    }
    return text;
  }
}
