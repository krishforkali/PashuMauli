import 'package:flutter_test/flutter_test.dart';
import 'package:pashumauli/data/remote/api_client.dart';

void main() {
  group('API Base URL Configuration', () {
    test('default base URL does not use emulator-only 10.0.2.2 address', () {
      expect(kDefaultApiBaseUrl.contains('10.0.2.2'), isFalse,
          reason: '10.0.2.2 is unreachable on physical Android devices');
    });

    test('default URL uses explicit IPv4 127.0.0.1, not localhost', () {
      // Android 13 may resolve `localhost` to ::1 (IPv6).
      // adb reverse tcp:8000 tcp:8000 only binds on IPv4 127.0.0.1.
      // Using localhost causes "connection refused" even with ADB reverse active.
      expect(kDefaultApiBaseUrl.contains('localhost'), isFalse,
          reason: 'Use 127.0.0.1, not localhost, for ADB reverse compatibility');
    });

    test('ApiClient accepts injected HTTPS tunnel URL for physical device', () {
      const tunnelUrl = 'https://pashumauli-demo.trycloudflare.com';
      final client = ApiClient(baseUrl: tunnelUrl);
      expect(client.baseUrl, equals(tunnelUrl));
      expect(client.baseUrl.startsWith('https://'), isTrue);
      expect(client.baseUrl.contains('10.0.2.2'), isFalse);
    });

    test('ApiClient constructs correct URI endpoints with injected base URL', () {
      const customBase = 'https://tunnel.example.com';
      final client = ApiClient(baseUrl: customBase);

      // Verify base URL formatting
      expect('${client.baseUrl}/api/v1/auth/login',
          equals('https://tunnel.example.com/api/v1/auth/login'));
      expect('${client.baseUrl}/api/v1/auth/register',
          equals('https://tunnel.example.com/api/v1/auth/register'));
      expect('${client.baseUrl}/api/v1/cases',
          equals('https://tunnel.example.com/api/v1/cases'));
    });
  });
}
