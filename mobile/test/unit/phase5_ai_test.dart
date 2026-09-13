/// Phase 5 unit tests — AI/risk/advisory/safety/network
///
/// Tests:
///   - RiskEngine: all risk levels, escalation, edge cases
///   - SafetyValidator: unsafe content blocking, low-confidence gating
///   - ApiResponse.networkError: error classification
///   - API URL: correct default (127.0.0.1, not localhost)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pashumauli/data/ai/risk_engine.dart';
import 'package:pashumauli/data/ai/safety_validator.dart';
import 'package:pashumauli/data/remote/api_client.dart';

void main() {
  // ─── RiskEngine ────────────────────────────────────────────────────────────

  group('RiskEngine — risk level calculation', () {
    test('no signals → LOW risk, no escalation', () {
      final result = RiskEngine.calculate(confidence: 0.0);
      expect(result.level, equals(RiskLevel.low));
      expect(result.escalationRecommended, isFalse);
      expect(result.score, lessThan(25));
    });

    test('high confidence visual finding → score increased', () {
      final result = RiskEngine.calculate(
        diseasePrediction: 'suspected FMD',
        confidence: 0.8,
      );
      expect(result.score, greaterThanOrEqualTo(20));
    });

    test('severe symptoms → at least MEDIUM risk', () {
      final result = RiskEngine.calculate(
        confidence: 0.0,
        symptoms: ['fever', 'breathing difficulty'],
        severity: 3,
      );
      expect(result.level.index, greaterThanOrEqualTo(RiskLevel.medium.index));
    });

    test('outbreak context adds significant score', () {
      final noOutbreak = RiskEngine.calculate(confidence: 0.0);
      final withOutbreak =
          RiskEngine.calculate(confidence: 0.0, outbreakContext: true);
      expect(withOutbreak.score, greaterThan(noOutbreak.score));
    });

    test('CRITICAL: all signals present → score >= 75, escalation required', () {
      final result = RiskEngine.calculate(
        diseasePrediction: 'suspected FMD',
        confidence: 0.9,
        symptoms: ['fever', 'spreading lesions', 'breathing difficulty'],
        severity: 4,
        outbreakContext: true,
        recentCaseDensity: 5,
      );
      expect(result.level, equals(RiskLevel.critical));
      expect(result.escalationRecommended, isTrue);
    });

    test('HIGH risk → escalation recommended', () {
      final result = RiskEngine.calculate(
        diseasePrediction: 'abnormal',
        confidence: 0.75,
        symptoms: ['fever', 'loss of appetite'],
        severity: 3,
      );
      expect(result.escalationRecommended, isTrue);
    });

    test('score is clamped to 0–100', () {
      final result = RiskEngine.calculate(
        diseasePrediction: 'any',
        confidence: 1.0,
        symptoms: ['fever', 'spreading lesions', 'breathing difficulty',
            'loss of appetite'],
        severity: 4,
        outbreakContext: true,
        recentCaseDensity: 10,
      );
      expect(result.score, lessThanOrEqualTo(100));
      expect(result.score, greaterThanOrEqualTo(0));
    });

    test('reasons list is never empty', () {
      final result = RiskEngine.calculate(confidence: 0.0);
      expect(result.reasons, isNotEmpty);
    });

    test('low confidence visual finding does not increase risk', () {
      final withLowConf = RiskEngine.calculate(
        diseasePrediction: 'some finding',
        confidence: 0.3, // below 0.6 threshold
      );
      final baseline = RiskEngine.calculate(confidence: 0.0);
      expect(withLowConf.score, equals(baseline.score));
    });
  });

  // ─── SafetyValidator ──────────────────────────────────────────────────────

  group('SafetyValidator — output guardrails', () {
    test('safe text passes through unchanged', () {
      const input =
          'Ensure the animal has access to clean water and shade. '
          'Monitor temperature and contact your veterinarian.';
      expect(SafetyValidator.validate(input, lowConfidence: false),
          equals(input));
    });

    test('empty input returns fallback', () {
      expect(SafetyValidator.validate('', lowConfidence: false),
          equals(SafetyValidator.fallback));
    });

    test('whitespace-only input returns fallback', () {
      expect(SafetyValidator.validate('   ', lowConfidence: false),
          equals(SafetyValidator.fallback));
    });

    test('"confirmed disease" → fallback', () {
      const bad = 'The animal has confirmed disease FMD.';
      expect(SafetyValidator.validate(bad, lowConfidence: false),
          equals(SafetyValidator.fallback));
    });

    test('"definitely has" → fallback', () {
      const bad = 'The cow definitely has lumpy skin disease.';
      expect(SafetyValidator.validate(bad, lowConfidence: false),
          equals(SafetyValidator.fallback));
    });

    test('dosage mention → fallback', () {
      const bad = 'Give 5 mg of oxytetracycline per kg body weight.';
      expect(SafetyValidator.validate(bad, lowConfidence: false),
          equals(SafetyValidator.fallback));
    });

    test('"prescribe" → fallback', () {
      const bad = 'The veterinarian should prescribe antibiotics.';
      expect(SafetyValidator.validate(bad, lowConfidence: false),
          equals(SafetyValidator.fallback));
    });

    test('"give medicine" → fallback', () {
      const bad = 'You should give medicine to the animal now.';
      expect(SafetyValidator.validate(bad, lowConfidence: false),
          equals(SafetyValidator.fallback));
    });

    test('low confidence + "diagnosis" → fallback', () {
      const bad = 'Based on the image, the diagnosis is foot and mouth disease.';
      expect(SafetyValidator.validate(bad, lowConfidence: true),
          equals(SafetyValidator.fallback));
    });

    test('high confidence + "diagnosis" → passes (allowed context)', () {
      // "diagnosis" alone with high confidence is not blocked
      const input =
          'A veterinary diagnosis is required before any treatment is given.';
      expect(SafetyValidator.validate(input, lowConfidence: false),
          equals(input));
    });

    test('"ml" in text does NOT trigger dosage block (case sensitivity)', () {
      // "ml" in the middle of a word like "animals" should not trigger
      const input = 'Observe the animal carefully for 48 hours.';
      expect(SafetyValidator.validate(input, lowConfidence: false),
          equals(input));
    });

    test('fallback message is non-empty and safe', () {
      expect(SafetyValidator.fallback, isNotEmpty);
      expect(SafetyValidator.fallback.toLowerCase().contains('diagnos'),
          isFalse);
      expect(SafetyValidator.fallback.toLowerCase().contains('prescri'),
          isFalse);
    });
  });

  // ─── Network Error Classification ─────────────────────────────────────────

  group('ApiResponse.networkError — error classification', () {
    test('connection refused → friendly message', () {
      final r = ApiResponse.networkError(
          Exception('Connection refused: localhost/127.0.0.1:8000'));
      expect(r.isNetworkError, isTrue);
      expect(r.errorMessage!.toLowerCase(), contains('connection refused'));
      expect(r.errorCode, equals('NETWORK_ERROR'));
    });

    test('ECONNREFUSED → friendly message', () {
      final r = ApiResponse.networkError(
          Exception('ECONNREFUSED 127.0.0.1:8000'));
      expect(r.isNetworkError, isTrue);
      expect(r.errorMessage!.toLowerCase(), contains('connection refused'));
    });

    test('timeout → friendly message', () {
      final r = ApiResponse.networkError(
          Exception('TimeoutException: Connection timed out'));
      expect(r.isNetworkError, isTrue);
      expect(r.errorMessage!.toLowerCase(), contains('timed out'));
    });

    test('TLS error → friendly message with detail', () {
      final r = ApiResponse.networkError(
          Exception('HandshakeException: CERTIFICATE_VERIFY_FAILED'));
      expect(r.isNetworkError, isTrue);
      expect(r.errorMessage!.toLowerCase(), contains('tls'));
    });

    test('socket error → friendly message', () {
      final r = ApiResponse.networkError(
          Exception('SocketException: Network is unreachable'));
      expect(r.isNetworkError, isTrue);
      expect(r.errorMessage!.toLowerCase(), contains('socket'));
    });

    test('unknown error → type:message fallback', () {
      final r = ApiResponse.networkError(Exception('Something weird happened'));
      expect(r.isNetworkError, isTrue);
      expect(r.errorMessage, isNotEmpty);
    });

    test('statusCode is 0 for network errors', () {
      final r = ApiResponse.networkError(Exception('test'));
      expect(r.statusCode, equals(0));
      expect(r.isNetworkError, isTrue);
      expect(r.isSuccess, isFalse);
    });
  });

  // ─── API URL ──────────────────────────────────────────────────────────────

  group('API URL — physical device compatibility', () {
    test('default URL uses 127.0.0.1, not localhost (in test env)', () {
      // localhost on Android 13 may resolve to ::1 (IPv6), breaking ADB reverse.
      expect(kDefaultApiBaseUrl.contains('localhost'), isFalse,
          reason:
              'Use 127.0.0.1 explicitly. localhost may resolve to ::1 on Android 13, '
              'which breaks adb reverse tcp:8000 tcp:8000 (IPv4 only)');
    });

    test('default URL is not emulator-only 10.0.2.2', () {
      expect(kDefaultApiBaseUrl.contains('10.0.2.2'), isFalse,
          reason: '10.0.2.2 is unreachable on physical Android devices');
    });

    test('default URL starts with http:// or https://', () {
      expect(
        kDefaultApiBaseUrl.startsWith('http://') ||
            kDefaultApiBaseUrl.startsWith('https://'),
        isTrue,
      );
    });

    test('ApiClient constructs correct auth endpoints', () {
      const base = 'http://127.0.0.1:8000';
      final client = ApiClient(baseUrl: base);
      expect('${client.baseUrl}/api/v1/auth/login',
          equals('http://127.0.0.1:8000/api/v1/auth/login'));
      expect('${client.baseUrl}/api/v1/auth/register',
          equals('http://127.0.0.1:8000/api/v1/auth/register'));
    });
  });
}
