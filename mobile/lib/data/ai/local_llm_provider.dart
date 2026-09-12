import 'dart:async';
import 'package:flutter/services.dart';

class LocalModelInfo {
  const LocalModelInfo(
      {required this.name,
      required this.version,
      required this.runtime,
      required this.backend,
      required this.status,
      this.reason});
  final String name, version, runtime, backend, status;
  final String? reason;
}

abstract class LocalLLMProvider {
  Future<void> initialize();
  Future<bool> isAvailable();
  Future<LocalModelInfo> modelInfo();
  Stream<String> sendMessage(Map<String, Object?> context, String message);
  Future<void> cancelGeneration();
  Future<void> dispose();
}

/// Narrow Flutter bridge; Android owns LiteRT-LM and model lifecycle.
class AndroidLiteRtLmProvider implements LocalLLMProvider {
  static const _channel = MethodChannel('org.pashumauli/local_llm');
  static const _events = EventChannel('org.pashumauli/local_llm/stream');
  @override
  Future<void> initialize() => _channel.invokeMethod('initialize');
  @override
  Future<bool> isAvailable() async =>
      await _channel.invokeMethod<bool>('isAvailable') ?? false;
  @override
  Future<LocalModelInfo> modelInfo() async {
    final m = Map<String, dynamic>.from(
        await _channel.invokeMethod('modelInfo') ?? {});
    return LocalModelInfo(
        name: m['name'] ?? 'Gemma 3 1B IT',
        version: m['version'] ?? 'not installed',
        runtime: m['runtime'] ?? 'LiteRT-LM',
        backend: m['backend'] ?? 'CPU',
        status: m['status'] ?? 'NOT_INSTALLED',
        reason: m['reason']);
  }

  @override
  Stream<String> sendMessage(
      Map<String, Object?> context, String message) async* {
    await _channel
        .invokeMethod('sendMessage', {'context': context, 'message': message});
    yield* _events.receiveBroadcastStream().map((e) => e.toString());
  }

  @override
  Future<void> cancelGeneration() => _channel.invokeMethod('cancelGeneration');
  @override
  Future<void> dispose() => _channel.invokeMethod('dispose');
}
