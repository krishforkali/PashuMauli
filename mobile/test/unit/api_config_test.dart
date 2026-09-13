import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pashumauli/data/remote/api_client.dart';
import 'package:pashumauli/services/secure_storage_service.dart';
import 'dart:convert';

class FakeSecureStorage extends SecureStorageService {
  @override
  Future<String?> getAccessToken() async => 'fake_token';
  
  @override
  Future<String?> getRefreshToken() async => 'fake_refresh_token';
}

void main() {
  group('API Base URL Configuration', () {
    test('default base URL does not use emulator-only 10.0.2.2 address', () {
      expect(kDefaultApiBaseUrl.contains('10.0.2.2'), isFalse,
          reason: '10.0.2.2 is unreachable on physical Android devices');
    });

    test('default URL uses explicit IPv4 127.0.0.1, not localhost (in test env)', () {
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

    test('ApiClient uses the injected base URL for requests, never 127.0.0.1', () async {
      const customBase = 'https://tunnel.example.com';
      String? requestUrl;

      final mockHttpClient = MockClient((request) async {
        requestUrl = request.url.toString();
        // Ensure that the request NEVER goes to 127.0.0.1 or localhost
        expect(requestUrl?.contains('127.0.0.1'), isFalse);
        expect(requestUrl?.contains('localhost'), isFalse);
        return http.Response(jsonEncode({}), 200);
      });

      final client = ApiClient(
        baseUrl: customBase, 
        httpClient: mockHttpClient,
        storage: FakeSecureStorage(),
      );

      await client.login(phone: '123', password: '123');
      expect(requestUrl, equals('https://tunnel.example.com/api/v1/auth/login'));

      await client.createFarmer({});
      expect(requestUrl, equals('https://tunnel.example.com/api/v1/farmers'));

      await client.createAnimal({});
      expect(requestUrl, equals('https://tunnel.example.com/api/v1/animals'));

      await client.createCase({});
      expect(requestUrl, equals('https://tunnel.example.com/api/v1/cases'));
    });
  });
}


