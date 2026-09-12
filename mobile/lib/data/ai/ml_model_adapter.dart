import 'dart:typed_data';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Swappable local visual screening adapter. It never makes a diagnosis.
abstract class MLModelAdapter {
  /// Load the model from [modelPath].
  /// Returns true if the model is loaded and ready.
  Future<bool> load(String modelPath);

  /// Run inference on [imageBytes].
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
  final Map<String, Object> preprocessingMetadata;

  const MLResult({
    required this.modelName,
    required this.modelVersion,
    required this.labels,
    required this.confidences,
    required this.inferenceMs,
    this.preprocessingMetadata = const {},
  });

  String? get topPrediction => labels.isEmpty ? null : labels.first;
  double? get topConfidence => confidences.isEmpty ? null : confidences.first;

  /// Returns true if confidence is below the low-confidence threshold.
  /// See AI_SPEC.md §Low confidence.
  bool isLowConfidence({double threshold = 0.6}) =>
      topConfidence == null || topConfidence! < threshold;
}

/// Actual TensorFlow Lite runner. Labels and normalization are supplied with
/// the validated model manifest; no disease labels are embedded in app code.
class TFLiteAdapter implements MLModelAdapter {
  TFLiteAdapter(
      {required this.modelName,
      required this.modelVersion,
      required this.labels,
      this.threshold = .6,
      this.normalizeToMinusOneToOne = false});
  final String modelName;
  final String modelVersion;
  final List<String> labels;
  final double threshold;
  final bool normalizeToMinusOneToOne;
  Interpreter? _interpreter;
  @override
  bool get isReady => _interpreter != null;

  @override
  Future<bool> load(String modelPath) async {
    await unload();
    try {
      _interpreter = Interpreter.fromFile(File(modelPath));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<MLResult> infer(List<int> imageBytes) async {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('Vision model is not loaded');
    }
    final decoded = img.decodeImage(Uint8List.fromList(imageBytes));
    if (decoded == null) throw ArgumentError('Unsupported image format');
    final shape = interpreter.getInputTensor(0).shape;
    if (shape.length != 4 || shape[3] != 3) {
      throw StateError('Unsupported vision model input shape: $shape');
    }
    final h = shape[1], w = shape[2];
    final resized = img.copyResize(decoded, width: w, height: h);
    double n(int value) =>
        normalizeToMinusOneToOne ? value / 127.5 - 1 : value / 255;
    final input = List.generate(
        1,
        (_) => List.generate(
            h,
            (y) => List.generate(w, (x) {
                  final p = resized.getPixel(x, y);
                  return [n(p.r.toInt()), n(p.g.toInt()), n(p.b.toInt())];
                })));
    final output = List.generate(
        1,
        (_) =>
            List<double>.filled(interpreter.getOutputTensor(0).shape.last, 0));
    final started = DateTime.now();
    try {
      interpreter.run(input, output);
    } catch (e) {
      throw StateError('Vision inference failed: $e');
    }
    final ranked =
        List.generate(output[0].length, (i) => MapEntry(i, output[0][i]))
            .where((e) => e.key < labels.length)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final top = ranked.take(3).where((e) => e.value >= threshold).toList();
    return MLResult(
        modelName: modelName,
        modelVersion: modelVersion,
        labels: top.map((e) => labels[e.key]).toList(),
        confidences: top.map((e) => e.value.clamp(0.0, 1.0)).toList(),
        inferenceMs: DateTime.now().difference(started).inMilliseconds,
        preprocessingMetadata: {
          'width': w,
          'height': h,
          'colorFormat': 'RGB',
          'normalization': normalizeToMinusOneToOne ? '[-1,1]' : '[0,1]'
        });
  }

  @override
  Future<void> unload() async {
    _interpreter?.close();
    _interpreter = null;
  }
}

/// Test/demo-only adapter. It is never registered as production AI.
class StubMLAdapter implements MLModelAdapter {
  bool _ready = false;

  @override
  Future<bool> load(String modelPath) async {
    _ready = false;
    return false;
  }

  @override
  Future<MLResult> infer(List<int> imageBytes) async {
    throw UnsupportedError('Validated vision model not installed');
  }

  @override
  Future<void> unload() async {
    _ready = false;
  }

  @override
  bool get isReady => _ready;
}
