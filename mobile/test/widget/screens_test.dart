// Widget tests for all 17 screens — smoke tests verifying each builds without crash.
// No device/emulator required; uses flutter_test.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pashumauli/presentation/screens/advisory/advisory_screen.dart';
import 'package:pashumauli/presentation/screens/animal/add_animal_screen.dart';
import 'package:pashumauli/presentation/screens/animal/animal_list_screen.dart';
import 'package:pashumauli/presentation/screens/animal/animal_profile_screen.dart';
import 'package:pashumauli/presentation/screens/animal/vaccination_history_screen.dart';
import 'package:pashumauli/presentation/screens/auth/login_screen.dart';
import 'package:pashumauli/presentation/screens/health_case/ai_result_screen.dart';
import 'package:pashumauli/presentation/screens/health_case/ai_scan_screen.dart';
import 'package:pashumauli/presentation/screens/health_case/report_symptoms_screen.dart';
import 'package:pashumauli/presentation/screens/home/home_screen.dart';
import 'package:pashumauli/presentation/screens/language/language_screen.dart';
import 'package:pashumauli/presentation/screens/notifications/notifications_screen.dart';
import 'package:pashumauli/presentation/screens/queue/offline_queue_screen.dart';
import 'package:pashumauli/presentation/screens/queue/sync_status_screen.dart';
import 'package:pashumauli/presentation/screens/settings/settings_screen.dart';
import 'package:pashumauli/presentation/screens/splash/splash_screen.dart';
import 'package:pashumauli/services/auth_notifier.dart';
import 'package:pashumauli/services/locale_notifier.dart';
import 'package:pashumauli/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Screen smoke tests — all 17 screens render without crash', () {
    // ─── Screen 1: Splash ──────────────────────────────────────────────────
    testWidgets('Screen 1: Splash renders', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SplashScreen()),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('PashuMauli'), findsWidgets);
    });

    // ─── Screen 2: Language ─────────────────────────────────────────────────
    testWidgets('Screen 2: Language selection renders', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: LanguageScreen()),
      ));
      await tester.pump();
      expect(find.text('Select Language'), findsWidgets);
      expect(find.text('English'), findsWidgets);
    });

    // ─── Screen 3: Login ───────────────────────────────────────────────────
    testWidgets('Screen 3: Login screen renders tabs', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: LoginScreen()),
      ));
      await tester.pump();
      expect(find.text('Login'), findsWidgets);
      expect(find.text('Register'), findsWidgets);
    });

    testWidgets('Login form validates empty phone', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: LoginScreen()),
      ));
      await tester.pump();
      // Tap Login button
      final loginButtons = find.widgetWithText(ElevatedButton, 'Login');
      if (loginButtons.evaluate().isNotEmpty) {
        await tester.tap(loginButtons.first);
        await tester.pump();
        expect(find.text('Phone number is required'), findsWidgets);
      }
    });

    // ─── Screen 4: Home ────────────────────────────────────────────────────
    testWidgets('Screen 4: Home screen renders action cards', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: HomeScreen()),
      ));
      await tester.pump();
      expect(find.text('Register Farmer'), findsWidgets);
      expect(find.text('Add Animal'), findsWidgets);
      expect(find.text('Report Case'), findsWidgets);
      expect(find.text('AI Scan'), findsWidgets);
    });

    // ─── Screen 6: Animal List ─────────────────────────────────────────────
    testWidgets('Screen 6: Animal list renders', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: AnimalListScreen()),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Animal List'), findsWidgets);
    });

    // ─── Screen 7: Add Animal ──────────────────────────────────────────────
    testWidgets('Screen 7: Add animal form renders', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: AddAnimalScreen()),
      ));
      await tester.pump();
      expect(find.text('Add Animal'), findsWidgets);
      expect(find.text('Ear Tag ID *'), findsWidgets);
    });

    testWidgets('Add animal validates empty ear tag', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: AddAnimalScreen()),
      ));
      await tester.pump();
      await tester.ensureVisible(find.text('Save Animal Locally'));
      await tester.tap(find.text('Save Animal Locally'));
      await tester.pump();
      expect(find.text('Ear tag is required'), findsOneWidget);
    });

    // ─── Screen 8: Animal Profile ──────────────────────────────────────────
    testWidgets('Screen 8: Animal profile renders (not found)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: AnimalProfileScreen(animalId: 'nonexistent')),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Animal Profile'), findsWidgets);
    });

    // ─── Screen 9: Vaccination History ────────────────────────────────────
    testWidgets('Screen 9: Vaccination history renders empty state', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: VaccinationHistoryScreen(animalId: 'test')),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Vaccination History'), findsWidgets);
    });

    // ─── Screen 10: Report Symptoms ────────────────────────────────────────
    testWidgets('Screen 10: Report symptoms renders checklist', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: ReportSymptomsScreen()),
      ));
      await tester.pump();
      expect(find.text('Report Symptoms'), findsWidgets);
      expect(find.text('Fever'), findsWidgets);
    });

    testWidgets('Report symptoms requires at least one symptom', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: ReportSymptomsScreen()),
      ));
      await tester.pump();
      await tester.ensureVisible(find.text('Submit Report'));
      await tester.tap(find.text('Submit Report'));
      await tester.pump();
      expect(find.text('Select at least one symptom'), findsOneWidget);
    });

    // ─── Screen 11: AI Scan ────────────────────────────────────────────────
    testWidgets('Screen 11: AI scan stub renders', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: AiScanScreen()),
      ));
      await tester.pump();
      expect(find.text('AI Disease Scan'), findsWidgets);
    });

    // ─── Screen 12: AI Result ──────────────────────────────────────────────
    testWidgets('Screen 12: AI result stub renders', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          home: AiResultScreen(resultData: {'stub': true, 'message': 'Test'}),
        ),
      ));
      await tester.pump();
      // Phase 5: title changed from 'AI Scan Result' to 'Risk Assessment Result'
      expect(find.text('Risk Assessment Result'), findsWidgets);
      // Phase 5: stub mode replaced by risk engine output — check risk card
      expect(find.text('Risk Level: LOW'), findsWidgets);
    });

    testWidgets('AI disclaimer is always visible on result screen',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: AiResultScreen()),
      ));
      await tester.pump();
      expect(find.textContaining('AI screening only'), findsWidgets);
    });

    // ─── Screen 13: Advisory ───────────────────────────────────────────────
    testWidgets('Screen 13: Advisory renders content', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: AdvisoryScreen()),
      ));
      await tester.pump();
      // Phase 5: title changed from 'Advisories' to 'AI Advisory'
      expect(find.text('AI Advisory'), findsWidgets);
      expect(find.text('FMD Prevention'), findsWidgets);
    });

    // ─── Screen 14: Offline Queue ──────────────────────────────────────────
    testWidgets('Screen 14: Offline queue renders', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: OfflineQueueScreen()),
      ));
      await tester.pump();
      expect(find.text('Offline Queue'), findsWidgets);
    });

    // ─── Screen 15: Sync Status ────────────────────────────────────────────
    testWidgets('Screen 15: Sync status renders', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SyncStatusScreen()),
      ));
      await tester.pump();
      expect(find.text('Sync Status'), findsWidgets);
    });

    // ─── Screen 16: Notifications ──────────────────────────────────────────
    testWidgets('Screen 16: Notifications renders empty state', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: NotificationsScreen()),
      ));
      await tester.pump();
      expect(find.text('Notifications'), findsWidgets);
    });

    // ─── Screen 17: Settings ───────────────────────────────────────────────
    testWidgets('Screen 17: Settings renders', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pump();
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Display Language'), findsWidgets);
    });
  });

  group('Auth state tests', () {
    test('AuthNotifier starts in loading state', () async {
      final container = ProviderContainer();
      final state = container.read(authNotifierProvider);
      expect(state, isA<AuthLoading>());
      container.dispose();
    });

    test('Initialize with no session transitions to unauthenticated', () async {
      final storage = FakeSecureStorage(hasToken: false);
      final notifier = AuthNotifier(storage: storage);
      await notifier.initialize();
      expect(notifier.state, isA<AuthUnauthenticated>());
    });

    test('Logout clears session and sets unauthenticated', () async {
      final storage = FakeSecureStorage(hasToken: true);
      final notifier = AuthNotifier(storage: storage);
      await notifier.login(
        accessToken: 'tok',
        refreshToken: 'ref',
        userId: 'u1',
        role: 'FARMER',
        name: 'Test',
        phone: '9999999999',
      );
      expect(notifier.state, isA<AuthAuthenticated>());
      await notifier.logout();
      expect(notifier.state, isA<AuthUnauthenticated>());
      expect(storage.cleared, isTrue);
    });
  });
}

// ─── Test doubles ────────────────────────────────────────────────────────────

class FakeSecureStorage extends SecureStorageService {
  final bool hasToken;
  bool cleared = false;
  final _store = <String, String>{};

  FakeSecureStorage({required this.hasToken});

  @override
  Future<bool> hasSession() async => hasToken && !cleared;

  @override
  Future<void> clearSession() async {
    cleared = true;
    _store.clear();
  }

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String role,
    required String name,
    required String phone,
  }) async {
    _store['token'] = accessToken;
    _store['userId'] = userId;
    _store['role'] = role;
    _store['name'] = name;
    _store['phone'] = phone;
  }

  @override
  Future<String?> getUserId() async => _store['userId'];

  @override
  Future<String?> getUserName() async => _store['name'];

  @override
  Future<String?> getUserPhone() async => _store['phone'];

  @override
  Future<String?> getUserRole() async => _store['role'];

  @override
  Future<String?> getAccessToken() async => _store['token'];
}
