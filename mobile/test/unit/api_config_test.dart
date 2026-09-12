import 'package:flutter_test/flutter_test.dart';
import 'package:pashumauli/data/remote/api_client.dart';

void main() {
  group('API Base URL Configuration', () {
    test('default base URL does not use emulator-only 10.0.2.2 address', () {
      expect(kDefaultApiBaseUrl.contains('10.0.2.2'), isFalse,
          reason: '10.0.2.2 is unreachable on physical Android devices');
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
