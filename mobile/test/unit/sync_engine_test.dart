import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:pashumauli/data/local/database_helper.dart';
import 'package:pashumauli/data/remote/api_client.dart';
import 'package:pashumauli/data/repositories/local_repositories.dart';
import 'package:pashumauli/domain/entities/entities.dart';
import 'package:pashumauli/services/connectivity_service.dart';
import 'package:pashumauli/services/sync_engine.dart';
import 'package:pashumauli/services/secure_storage_service.dart';

class FakeSecureStorage extends SecureStorageService {
  final Map<String, String> _store = {};

  @override
  Future<void> saveAccessToken(String token) async => _store['token'] = token;

  @override
  Future<String?> getAccessToken() async => _store['token'] ?? 'fake-token';

  @override
  Future<void> saveRefreshToken(String token) async => _store['refresh'] = token;

  @override
  Future<String?> getRefreshToken() async => _store['refresh'] ?? 'fake-refresh';

  @override
  Future<bool> hasSession() async => true;

  @override
  Future<void> clearSession() async => _store.clear();
}

class MockApiClient extends ApiClient {
  final List<String> callLog = [];
  bool shouldFailTransient = false;
  bool shouldFailPermanent = false;
  bool returnAlreadyApplied = false;
  int createCaseCallCount = 0;

  MockApiClient({super.storage})
      : super(baseUrl: 'http://mock-test');

  @override
  Future<ApiResponse> createFarmer(Map<String, dynamic> payload) async {
    callLog.add('createFarmer:${payload['phone']}');
    if (shouldFailTransient) {
      return ApiResponse.error('NETWORK_ERROR', 'Network connection timed out', 0);
    }
    if (shouldFailPermanent) {
      return ApiResponse.error('INVALID_PHONE', 'Phone format invalid', 422);
    }
    return ApiResponse.success({'id': 'server-farmer-1', ...payload}, 201);
  }

  @override
  Future<ApiResponse> createAnimal(Map<String, dynamic> payload) async {
    callLog.add('createAnimal:${payload['ear_tag_id']}');
    if (shouldFailTransient) {
      return ApiResponse.error('NETWORK_ERROR', 'Connection failed', 0);
    }
    if (shouldFailPermanent) {
      return ApiResponse.error('EAR_TAG_TAKEN', 'Tag exists', 409);
    }
    return ApiResponse.success({'id': 'server-animal-1', ...payload}, 201);
  }

  @override
  Future<ApiResponse> createCase(Map<String, dynamic> payload) async {
    createCaseCallCount++;
    final clientId = payload['client_id'] as String? ?? 'unknown-client-id';
    final riskLevel = payload['risk_level'] as String? ?? 'LOW';
    callLog.add('createCase:$clientId');
    if (shouldFailTransient) {
      return ApiResponse.error('SERVER_ERROR', '503 Gateway Timeout', 503);
    }
    if (returnAlreadyApplied) {
      // Idempotency: HTTP 200 ALREADY_APPLIED
      return ApiResponse.success({
        'id': 'existing-case-id',
        'client_id': clientId,
        'risk_level': riskLevel,
        'message': 'Case already exists'
      }, 200);
    }
    return ApiResponse.success({
      'id': 'new-case-id',
      'client_id': clientId,
      'risk_level': riskLevel,
    }, 201);
  }

  Future<ApiResponse> postVaccination(Map<String, dynamic> payload) async {
    callLog.add('postVaccination:${payload['vaccine_name']}');
    return ApiResponse.success({'id': 'server-vax-1', ...payload}, 201);
  }

  @override
  Future<ApiResponse> refreshToken(String refreshToken) async {
    return ApiResponse.success({
      'access_token': 'new-valid-access-token',
      'refresh_token': 'new-valid-refresh-token',
    }, 200);
  }
}

class MockConnectivityService implements ConnectivityService {
  ConnectivityStatus _mockStatus;
  final _controller = StreamController<ConnectivityStatus>.broadcast();

  MockConnectivityService([this._mockStatus = ConnectivityStatus.online]);

  @override
  ConnectivityStatus get current => _mockStatus;

  @override
  bool get isOnline => _mockStatus == ConnectivityStatus.online;

  @override
  bool get isOffline => _mockStatus == ConnectivityStatus.offline;

  @override
  Stream<ConnectivityStatus> get statusStream => _controller.stream;

  void setStatus(ConnectivityStatus status) {
    _mockStatus = status;
    _controller.add(status);
  }

  @override
  void dispose() {
    _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper db;
  late FarmerLocalRepository farmerRepo;
  late AnimalLocalRepository animalRepo;
  late HealthCaseLocalRepository caseRepo;
  late SyncQueueRepository queueRepo;
  late FakeSecureStorage fakeStorage;
  late MockApiClient mockApi;
  late MockConnectivityService mockConnectivity;
  late SyncEngine syncEngine;

  setUp(() async {
    db = DatabaseHelper.inMemory();
    DatabaseHelper.setInstanceForTesting(db);
    await db.dropAndRecreate();

    farmerRepo = FarmerLocalRepository(db: db);
    animalRepo = AnimalLocalRepository(db: db);
    caseRepo = HealthCaseLocalRepository(db: db);
    queueRepo = SyncQueueRepository(db: db);
    fakeStorage = FakeSecureStorage();
    mockApi = MockApiClient(storage: fakeStorage);
    mockConnectivity = MockConnectivityService(ConnectivityStatus.online);

    syncEngine = SyncEngine(
      apiClient: mockApi,
      queueRepo: queueRepo,
      farmerRepo: farmerRepo,
      animalRepo: animalRepo,
      caseRepo: caseRepo,
      connectivity: mockConnectivity,
      storage: fakeStorage,
      autoStart: false,
    );
  });

  tearDown(() async {
    syncEngine.dispose();
    mockConnectivity.dispose();
    await db.close();
    DatabaseHelper.setInstanceForTesting(null);
  });

  group('Atomic Transactions (Local Mutation + Sync Queue Enqueue)', () {
    test('insertWithSync commits entity and queue atomically', () async {
      const uuid = Uuid();
      final farmerId = uuid.v4();
      final farmer = LocalFarmer(
        id: farmerId,
        name: 'Ramesh Patil',
        phone: '9876543210',
        addressText: 'Pune',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final syncItem = SyncQueueItem(
        id: uuid.v4(),
        clientId: farmerId,
        entityType: 'FARMER',
        entityId: farmerId,
        operation: 'CREATE',
        payload: {
          'name': farmer.name,
          'phone': farmer.phone,
          'address_text': farmer.addressText,
        },
        status: SyncStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await farmerRepo.insertWithSync(farmer, syncItem);

      // Verify both were written
      final savedFarmer = await farmerRepo.getById(farmerId);
      expect(savedFarmer, isNotNull);
      expect(savedFarmer!.name, equals('Ramesh Patil'));

      final pendingItems = await queueRepo.getPending();
      expect(pendingItems.length, equals(1));
      expect(pendingItems.first.entityId, equals(farmerId));
      expect(pendingItems.first.status, equals(SyncStatus.pending));
    });

    test('HealthCase insertWithSync writes case and queue item', () async {
      const uuid = Uuid();
      final caseId = uuid.v4();
      final clientId = uuid.v4();
      final healthCase = LocalHealthCase(
        id: caseId,
        clientId: clientId,
        reportedBy: 'user-123',
        symptoms: {'Fever': true, 'Loss of appetite': true},
        riskLevel: RiskLevel.high,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final syncItem = SyncQueueItem(
        id: uuid.v4(),
        clientId: clientId,
        entityType: 'HEALTH_CASE',
        entityId: caseId,
        operation: 'CREATE',
        payload: {
          'client_id': clientId,
          'symptoms': ['Fever', 'Loss of appetite'],
          'risk_level': 'HIGH',
          'reported_by': 'user-123',
        },
        status: SyncStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await caseRepo.insertWithSync(healthCase, syncItem);

      final saved = await caseRepo.getById(caseId);
      expect(saved, isNotNull);
      expect(saved!.riskLevel, equals(RiskLevel.high));
      expect(saved.synced, isFalse);

      final pending = await queueRepo.getPending();
      expect(pending.length, equals(1));
      expect(pending.first.clientId, equals(clientId));
    });
  });

  group('SyncEngine FIFO Replay & Status Transitions', () {
    test('Replays items in FIFO order (created_at ASC) and marks SYNCED', () async {
      const uuid = Uuid();
      final t1 = DateTime.now().subtract(const Duration(minutes: 5));
      final t2 = DateTime.now().subtract(const Duration(minutes: 2));

      final fId = uuid.v4();
      final fSync = SyncQueueItem(
        id: uuid.v4(),
        clientId: fId,
        entityType: 'FARMER',
        entityId: fId,
        operation: 'CREATE',
        payload: {'name': 'Farmer 1', 'phone': '9100000001'},
        status: SyncStatus.pending,
        createdAt: t1,
        updatedAt: t1,
      );

      final aId = uuid.v4();
      final aSync = SyncQueueItem(
        id: uuid.v4(),
        clientId: aId,
        entityType: 'ANIMAL',
        entityId: aId,
        operation: 'CREATE',
        payload: {'ear_tag_id': 'MH-001', 'species': 'cattle'},
        status: SyncStatus.pending,
        createdAt: t2,
        updatedAt: t2,
      );

      await queueRepo.enqueue(fSync);
      await queueRepo.enqueue(aSync);

      await syncEngine.sync();

      expect(mockApi.callLog, equals(['createFarmer:9100000001', 'createAnimal:MH-001']));

      final pending = await queueRepo.getPending();
      expect(pending, isEmpty);

      final all = await queueRepo.getAll();
      expect(all.every((i) => i.status == SyncStatus.synced), isTrue);
    });

    test('HealthCase markSynced updates local case record upon sync', () async {
      const uuid = Uuid();
      final caseId = uuid.v4();
      final clientId = uuid.v4();
      final healthCase = LocalHealthCase(
        id: caseId,
        clientId: clientId,
        reportedBy: 'user-1',
        symptoms: {'Fever': true},
        riskLevel: RiskLevel.medium,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final syncItem = SyncQueueItem(
        id: uuid.v4(),
        clientId: clientId,
        entityType: 'HEALTH_CASE',
        entityId: caseId,
        operation: 'CREATE',
        payload: {
          'client_id': clientId,
          'symptoms': ['Fever'],
          'risk_level': 'MEDIUM',
          'reported_by': 'user-1',
        },
        status: SyncStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await caseRepo.insertWithSync(healthCase, syncItem);

      await syncEngine.sync();

      final updatedCase = await caseRepo.getById(caseId);
      expect(updatedCase!.synced, isTrue);

      final queue = await queueRepo.getAll();
      expect(queue.first.status, equals(SyncStatus.synced));
    });
  });

  group('Idempotency & Retry Handling', () {
    test('Idempotent replay: HTTP 200 ALREADY_APPLIED succeeds and marks SYNCED', () async {
      mockApi.returnAlreadyApplied = true;

      const uuid = Uuid();
      final caseId = uuid.v4();
      final clientId = uuid.v4();
      final healthCase = LocalHealthCase(
        id: caseId,
        clientId: clientId,
        reportedBy: 'user-1',
        symptoms: {'Lameness': true},
        riskLevel: RiskLevel.low,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final syncItem = SyncQueueItem(
        id: uuid.v4(),
        clientId: clientId,
        entityType: 'HEALTH_CASE',
        entityId: caseId,
        operation: 'CREATE',
        payload: {
          'client_id': clientId,
          'symptoms': ['Lameness'],
          'risk_level': 'LOW',
          'reported_by': 'user-1',
        },
        status: SyncStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await caseRepo.insertWithSync(healthCase, syncItem);

      await syncEngine.sync();

      final updatedCase = await caseRepo.getById(caseId);
      expect(updatedCase!.synced, isTrue);

      final queue = await queueRepo.getAll();
      expect(queue.first.status, equals(SyncStatus.synced));
    });

    test('Transient failure increments attempts and stays PENDING', () async {
      mockApi.shouldFailTransient = true;

      const uuid = Uuid();
      final fId = uuid.v4();
      final syncItem = SyncQueueItem(
        id: uuid.v4(),
        clientId: fId,
        entityType: 'FARMER',
        entityId: fId,
        operation: 'CREATE',
        payload: {'name': 'Farmer 1', 'phone': '9111111111'},
        status: SyncStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await queueRepo.enqueue(syncItem);

      await syncEngine.sync();

      final queue = await queueRepo.getAll();
      expect(queue.first.status, equals(SyncStatus.pending));
      expect(queue.first.attemptCount, equals(1));
      expect(queue.first.lastError, contains('Network connection'));
    });

    test('Permanent failure (4xx unrecoverable) transitions item to FAILED', () async {
      mockApi.shouldFailPermanent = true;

      const uuid = Uuid();
      final aId = uuid.v4();
      final syncItem = SyncQueueItem(
        id: uuid.v4(),
        clientId: aId,
        entityType: 'ANIMAL',
        entityId: aId,
        operation: 'CREATE',
        payload: {'ear_tag_id': 'MH-TAKEN', 'species': 'cattle'},
        status: SyncStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await queueRepo.enqueue(syncItem);

      await syncEngine.sync();

      final queue = await queueRepo.getAll();
      expect(queue.first.status, equals(SyncStatus.failed));
      expect(queue.first.lastError, contains('EAR_TAG_TAKEN'));
    });

    test('retryFailed resets all failed items back to PENDING and triggers sync', () async {
      const uuid = Uuid();
      final itemId = uuid.v4();
      final failedItem = SyncQueueItem(
        id: itemId,
        clientId: uuid.v4(),
        entityType: 'FARMER',
        entityId: uuid.v4(),
        operation: 'CREATE',
        payload: {'name': 'Retry Farmer', 'phone': '9998887776'},
        status: SyncStatus.failed,
        attemptCount: 3,
        lastError: 'Previous failure',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await queueRepo.enqueue(failedItem);

      // Now server is working
      mockApi.shouldFailTransient = false;
      mockApi.shouldFailPermanent = false;

      await syncEngine.retryFailed();

      final queue = await queueRepo.getAll();
      expect(queue.first.status, equals(SyncStatus.synced));
    });
  });

  group('Concurrency & Offline Reactivity', () {
    test('Sync does not run when offline', () async {
      mockConnectivity.setStatus(ConnectivityStatus.offline);

      const uuid = Uuid();
      final syncItem = SyncQueueItem(
        id: uuid.v4(),
        clientId: uuid.v4(),
        entityType: 'FARMER',
        entityId: uuid.v4(),
        operation: 'CREATE',
        payload: {'name': 'Offline Farmer', 'phone': '9888888888'},
        status: SyncStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await queueRepo.enqueue(syncItem);

      await syncEngine.sync();

      expect(mockApi.callLog, isEmpty);
      final pending = await queueRepo.getPending();
      expect(pending.length, equals(1));
    });

    test('Offline to online transition triggers automatic sync', () async {
      mockConnectivity.setStatus(ConnectivityStatus.offline);

      final transitionEngine = SyncEngine(
        apiClient: mockApi,
        queueRepo: queueRepo,
        farmerRepo: farmerRepo,
        animalRepo: animalRepo,
        caseRepo: caseRepo,
        connectivity: mockConnectivity,
        storage: fakeStorage,
        autoStart: true,
      );
      addTearDown(transitionEngine.dispose);

      const uuid = Uuid();
      final syncItem = SyncQueueItem(
        id: uuid.v4(),
        clientId: uuid.v4(),
        entityType: 'FARMER',
        entityId: uuid.v4(),
        operation: 'CREATE',
        payload: {'name': 'Reconnected Farmer', 'phone': '9777777777'},
        status: SyncStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await queueRepo.enqueue(syncItem);

      // Reconnect
      mockConnectivity.setStatus(ConnectivityStatus.online);

      // Wait for stream event + sync cycle
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(mockApi.callLog, contains('createFarmer:9777777777'));
      final pending = await queueRepo.getPending();
      expect(pending, isEmpty);
    });
  });
}
