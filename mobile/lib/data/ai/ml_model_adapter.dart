/// TFLite model adapter interface — Phase 3 stub only.
/// Full implementation belongs to Phase 5 (AI/risk/advisory).
/// The interface is stable; implementations are swappable without changing the business layer.
/// See AI_SPEC.md §Model lifecycle.
abstract class MLModelAdapter {
  /// Load the model from [modelPath].
  /// Returns true if the model is loaded and ready.
  Future<bool> load(String modelPath);

  /// Run inference on [imageBytes].
  /// Never called in Phase 3 — the model is not bundled yet.
  Future<MLResult> infer(List<int> imageBytes);

  /// Unload model resources.
  Future<void> unload();

  /// Whether a model is currently loaded and ready.
  bool get isReady;
}

/// AI inference result — Phase 3 model only; populated by Phase 5.
class MLResult {
  final String modelName;
  final String modelVersion;
  final List<String> labels;
  final List<double> confidences;
  final int inferenceMs;
  final String? topPrediction;
  final double? topConfidence;

  const MLResult({
    required this.modelName,
    required this.modelVersion,
    required this.labels,
    required this.confidences,
    required this.inferenceMs,
    this.topPrediction,
    this.topConfidence,
  });

  /// Returns true if confidence is below the low-confidence threshold.
  /// See AI_SPEC.md §Low confidence.
  bool isLowConfidence({double threshold = 0.6}) =>
      topConfidence == null || topConfidence! < threshold;
}

/// Stub implementation used in Phase 3 — never calls TFLite.
/// Replace with TFLiteAdapter in Phase 5.
class StubMLAdapter implements MLModelAdapter {
  bool _ready = false;

  @override
  Future<bool> load(String modelPath) async {
    // Phase 5 will load the actual TFLite flatbuffer.
    _ready = false;
    return false;
  }

  @override
  Future<MLResult> infer(List<int> imageBytes) async {
    throw UnsupportedError('AI inference not available in Phase 3');
  }

  @override
  Future<void> unload() async {
    _ready = false;
  }

  @override
  bool get isReady => _ready;
}
