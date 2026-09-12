import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pashumauli/domain/entities/entities.dart';
import 'package:pashumauli/presentation/screens/advisory/advisory_screen.dart';
import 'package:pashumauli/presentation/screens/animal/add_animal_screen.dart';
import 'package:pashumauli/presentation/screens/animal/animal_list_screen.dart';
import 'package:pashumauli/presentation/screens/animal/animal_profile_screen.dart';
import 'package:pashumauli/presentation/screens/animal/vaccination_history_screen.dart';
import 'package:pashumauli/presentation/screens/auth/login_screen.dart';
import 'package:pashumauli/presentation/screens/farmer/farmer_profile_screen.dart';
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

/// Named route constants.
class AppRoutes {
  static const splash = '/';
  static const language = '/language';
  static const login = '/login';
  static const home = '/home';
  static const farmerProfile = '/farmer/:farmerId';
  static const animalList = '/animals';
  static const addAnimal = '/animals/add';
  static const animalProfile = '/animals/:animalId';
  static const vaccinationHistory = '/animals/:animalId/vaccinations';
  static const reportSymptoms = '/cases/report';
  static const aiScan = '/ai/scan';
  static const aiResult = '/ai/result';
  static const advisory = '/advisory';
  static const offlineQueue = '/queue';
  static const syncStatus = '/sync';
  static const notifications = '/notifications';
  static const settings = '/settings';

  // Helpers for named parameters
  static String farmerProfilePath(String farmerId) => '/farmer/$farmerId';
  static String animalProfilePath(String animalId) => '/animals/$animalId';
  static String vaccinationHistoryPath(String animalId) =>
      '/animals/$animalId/vaccinations';
}

/// Role-aware GoRouter.
///
/// Route visibility is UX only — backend is always the security authority.
/// See SECURITY.md §Authorization.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final isLoading = authState is AuthLoading;
      final isAuthenticated = authState is AuthAuthenticated;
      final isSplash = state.matchedLocation == AppRoutes.splash;
      final isLanguage = state.matchedLocation == AppRoutes.language;
      final isLogin = state.matchedLocation == AppRoutes.login;

      if (isLoading) return null;

      // Public routes (no auth required)
      if (isSplash || isLanguage || isLogin) {
        if (isAuthenticated && !isSplash) {
          return AppRoutes.home;
        }
        return null;
      }

      // Protected routes — require authentication
      if (!isAuthenticated) return AppRoutes.login;

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.language,
        builder: (context, state) => const LanguageScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: 'queue',
            builder: (context, state) => const OfflineQueueScreen(),
          ),
          GoRoute(
            path: 'sync',
            builder: (context, state) => const SyncStatusScreen(),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: 'ai',
            builder: (context, state) => const AiScanScreen(),
            routes: [
              GoRoute(
                path: 'result',
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return AiResultScreen(resultData: extra);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'advisory',
            builder: (context, state) => const AdvisoryScreen(),
          ),
          GoRoute(
            path: 'cases',
            redirect: (ctx, s) => null,
            routes: [
              GoRoute(
                path: 'report',
                builder: (context, state) => const ReportSymptomsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/farmer/:farmerId',
        builder: (context, state) => FarmerProfileScreen(
          farmerId: state.pathParameters['farmerId']!,
        ),
      ),
      GoRoute(
        path: '/animals',
        builder: (context, state) => const AnimalListScreen(),
        routes: [
          GoRoute(
            path: 'add',
            builder: (context, state) => const AddAnimalScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/animals/:animalId',
        builder: (context, state) => AnimalProfileScreen(
          animalId: state.pathParameters['animalId']!,
        ),
        routes: [
          GoRoute(
            path: 'vaccinations',
            builder: (context, state) => VaccinationHistoryScreen(
              animalId: state.pathParameters['animalId']!,
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Route not found: ${state.matchedLocation}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

/// Helper extension for role-based access checks (UX only — not security).
extension RoleAccess on UserRole {
  bool get canAccessDistrictFeatures => this == UserRole.districtOfficer ||
      this == UserRole.stateAdmin ||
      this == UserRole.systemAdmin;

  bool get canManageFarmers =>
      this == UserRole.fieldVet ||
      this == UserRole.districtOfficer ||
      this == UserRole.stateAdmin ||
      this == UserRole.systemAdmin;

  bool get canPerformAiScan =>
      this == UserRole.farmer ||
      this == UserRole.fieldVet ||
      this == UserRole.districtOfficer ||
      this == UserRole.stateAdmin ||
      this == UserRole.systemAdmin;
}
