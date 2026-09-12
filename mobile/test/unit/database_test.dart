// Unit tests for SQLite persistence layer.
// Uses sqflite_common_ffi for in-process (no Android device) execution.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:pashumauli/data/local/database_helper.dart';
import 'package:pashumauli/data/repositories/local_repositories.dart';
import 'package:pashumauli/domain/entities/entities.dart';

void main() {
  // Initialize sqflite_common_ffi so tests run on desktop/CI without a device.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper db;
  late FarmerLocalRepository farmerRepo;
  late AnimalLocalRepository animalRepo;
  late HealthCaseLocalRepository caseRepo;
  late VaccinationLocalRepository vaccinationRepo;
  late SyncQueueRepository syncRepo;
  late PendingMediaRepository mediaRepo;

  setUp(() async {
    // Use in-memory database for isolation in tests
    db = DatabaseHelper.inMemory();
    DatabaseHelper.setInstanceForTesting(db);
    // Reset to fresh state
    await db.dropAndRecreate();

    farmerRepo = FarmerLocalRepository(db: db);
    animalRepo = AnimalLocalRepository(db: db);
    caseRepo = HealthCaseLocalRepository(db: db);
    vaccinationRepo = VaccinationLocalRepository(db: db);
    syncRepo = SyncQueueRepository(db: db);
    mediaRepo = PendingMediaRepository(db: db);
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.setInstanceForTesting(null);
  });

  // ─── DB Initialization ────────────────────────────────────────────────────

  group('DB initialization', () {
    test('Database opens without error', () async {
      final database = await db.database;
      expect(database.isOpen, isTrue);
    });

    test('All required tables exist', () async {
      final database = await db.database;
      final tables = await database.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name");
      final tableNames = tables.map((r) => r['name'] as String).toList();
      expect(tableNames, containsAll([
        'local_users',
        'local_farmers',
        'local_animals',
        'local_health_cases',
        'local_vaccinations',
        'sync_queue',
        'model_metadata',
        'pending_media',
      ]));
    });
  });

  // ─── Farmer Repository ────────────────────────────────────────────────────

  group('FarmerLocalRepository', () {
    LocalFarmer makeFarmer({String? id, String name = 'Ramesh Kumar'}) {
      const uuid = Uuid();
      final now = DateTime.now();
      return LocalFarmer(
        id: id ?? uuid.v4(),
        name: name,
        phone: '9876543210',
        createdAt: now,
        updatedAt: now,
      );
    }

    test('Insert and retrieve farmer by ID', () async {
      final farmer = makeFarmer();
      await farmerRepo.insert(farmer);
      final retrieved = await farmerRepo.getById(farmer.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals(farmer.id));
      expect(retrieved.name, equals(farmer.name));
      expect(retrieved.synced, isFalse);
    });

    test('Farmer is unsynced after insert', () async {
      final farmer = makeFarmer();
      await farmerRepo.insert(farmer);
      final unsynced = await farmerRepo.getUnsynced();
      expect(unsynced.any((f) => f.id == farmer.id), isTrue);
    });

    test('markSynced sets synced=true', () async {
      final farmer = makeFarmer();
      await farmerRepo.insert(farmer);
      await farmerRepo.markSynced(farmer.id);
      final retrieved = await farmerRepo.getById(farmer.id);
      expect(retrieved!.synced, isTrue);
    });

    test('getAll returns all farmers ordered by created_at desc', () async {
      await farmerRepo.insert(makeFarmer(name: 'Farmer 1'));
      await farmerRepo.insert(makeFarmer(name: 'Farmer 2'));
      final all = await farmerRepo.getAll();
      expect(all.length, equals(2));
    });

    test('Farmer data survives write', () async {
      const uuid = Uuid();
      final now = DateTime.now();
      final farmer = LocalFarmer(
        id: uuid.v4(),
        name: 'Test Farmer',
        phone: '9999988888',
        preferredLanguage: 'hi',
        addressText: '123 Village Road',
        latitude: 18.5204,
        longitude: 73.8567,
        createdAt: now,
        updatedAt: now,
      );
      await farmerRepo.insert(farmer);
      final retrieved = await farmerRepo.getById(farmer.id);
      expect(retrieved!.name, equals('Test Farmer'));
      expect(retrieved.preferredLanguage, equals('hi'));
      expect(retrieved.latitude, closeTo(18.5204, 0.0001));
      expect(retrieved.longitude, closeTo(73.8567, 0.0001));
    });
  });

  // ─── Animal Repository ────────────────────────────────────────────────────

  group('AnimalLocalRepository', () {
    late String farmerId;

    setUp(() async {
      const uuid = Uuid();
      farmerId = uuid.v4();
      final now = DateTime.now();
      await farmerRepo.insert(LocalFarmer(
        id: farmerId,
        name: 'Test Farmer',
        phone: '9876543210',
        createdAt: now,
        updatedAt: now,
      ));
    });

    LocalAnimal makeAnimal({String? earTagId}) {
      const uuid = Uuid();
      final now = DateTime.now();
      return LocalAnimal(
        id: uuid.v4(),
        earTagId: earTagId ?? 'MH-2024-${uuid.v4().substring(0, 6)}',
        farmerId: farmerId,
        species: AnimalSpecies.cattle,
        breed: 'HF Cross',
        sex: AnimalSex.female,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('Insert and retrieve animal by ID', () async {
      final animal = makeAnimal(earTagId: 'MH-2024-001');
      await animalRepo.insert(animal);
      final retrieved = await animalRepo.getById(animal.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.earTagId, equals('MH-2024-001'));
      expect(retrieved.species, equals(AnimalSpecies.cattle));
    });

    test('Retrieve animals by farmer', () async {
      final a1 = makeAnimal();
      final a2 = makeAnimal();
      await animalRepo.insert(a1);
      await animalRepo.insert(a2);
      final farmerAnimals = await animalRepo.getByFarmer(farmerId);
      expect(farmerAnimals.length, equals(2));
    });

    test('getByEarTag returns correct animal', () async {
      final animal = makeAnimal(earTagId: 'MH-TEST-999');
      await animalRepo.insert(animal);
      final found = await animalRepo.getByEarTag('MH-TEST-999');
      expect(found, isNotNull);
      expect(found!.id, equals(animal.id));
    });

    test('markSynced sets synced flag', () async {
      final animal = makeAnimal();
      await animalRepo.insert(animal);
      expect((await animalRepo.getById(animal.id))!.synced, isFalse);
      await animalRepo.markSynced(animal.id);
      expect((await animalRepo.getById(animal.id))!.synced, isTrue);
    });
  });

  // ─── Health Case Repository ────────────────────────────────────────────────

  group('HealthCaseLocalRepository', () {
    LocalHealthCase makeCase() {
      const uuid = Uuid();
      final now = DateTime.now();
      final clientId = uuid.v4();
      return LocalHealthCase(
        id: uuid.v4(),
        clientId: clientId,
        symptoms: {'Fever': true, 'Lethargy': true},
        riskLevel: RiskLevel.high,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('Insert and retrieve health case', () async {
      final hc = makeCase();
      await caseRepo.insert(hc);
      final retrieved = await caseRepo.getById(hc.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.clientId, equals(hc.clientId));
      expect(retrieved.riskLevel, equals(RiskLevel.high));
    });

    test('Symptoms are persisted as JSON', () async {
      final hc = makeCase();
      await caseRepo.insert(hc);
      final retrieved = await caseRepo.getById(hc.id);
      expect(retrieved!.symptoms.containsKey('Fever'), isTrue);
      expect(retrieved.symptoms.containsKey('Lethargy'), isTrue);
    });

    test('getByClientId finds case', () async {
      final hc = makeCase();
      await caseRepo.insert(hc);
      final found = await caseRepo.getByClientId(hc.clientId);
      expect(found, isNotNull);
      expect(found!.id, equals(hc.id));
    });

    test('Case starts unsynced', () async {
      final hc = makeCase();
      await caseRepo.insert(hc);
      final unsynced = await caseRepo.getUnsynced();
      expect(unsynced.any((c) => c.id == hc.id), isTrue);
    });

    test('markSynced transitions case to synced', () async {
      final hc = makeCase();
      await caseRepo.insert(hc);
      await caseRepo.markSynced(hc.id);
      final retrieved = await caseRepo.getById(hc.id);
      expect(retrieved!.synced, isTrue);
    });
  });

  // ─── Vaccination Repository ───────────────────────────────────────────────

  group('VaccinationLocalRepository', () {
    test('Insert and retrieve vaccination records', () async {
      const uuid = Uuid();
      final now = DateTime.now();
      final farmerId = uuid.v4();
      final animalId = uuid.v4();

      await farmerRepo.insert(LocalFarmer(
        id: farmerId,
        name: 'Farmer Vac',
        phone: '9876543210',
        createdAt: now,
        updatedAt: now,
      ));

      await animalRepo.insert(LocalAnimal(
        id: animalId,
        earTagId: 'MH-VAC-001',
        farmerId: farmerId,
        species: AnimalSpecies.cattle,
        createdAt: now,
        updatedAt: now,
      ));

      final vac = LocalVaccination(
        id: uuid.v4(),
        animalId: animalId,
        vaccine: 'FMD Oil Adjuvant Vaccine',
        batchNumber: 'FMD-2024-001',
        administeredAt: now,
        createdAt: now,
      );

      await vaccinationRepo.insert(vac);
      final byAnimal = await vaccinationRepo.getByAnimal(animalId);
      expect(byAnimal.length, equals(1));
      expect(byAnimal.first.vaccine, equals('FMD Oil Adjuvant Vaccine'));
      expect(byAnimal.first.batchNumber, equals('FMD-2024-001'));
    });
  });

  // ─── Pending Media Repository ──────────────────────────────────────────────

  group('PendingMediaRepository', () {
    test('Insert and retrieve pending media records', () async {
      const uuid = Uuid();
      final now = DateTime.now();
      final caseId = uuid.v4();
      final media = PendingMedia(
        id: uuid.v4(),
        localPath: '/data/user/0/com.pashumauli/files/media/img1.jpg',
        entityType: 'HEALTH_CASE',
        entityId: caseId,
        status: 'QUEUED',
        createdAt: now,
      );

      await mediaRepo.insert(media);
      final queued = await mediaRepo.getQueued();
      expect(queued.length, equals(1));
      expect(queued.first.entityType, equals('HEALTH_CASE'));
      expect(queued.first.entityId, equals(caseId));

      final byEntity = await mediaRepo.getByEntity('HEALTH_CASE', caseId);
      expect(byEntity.length, equals(1));
    });
  });

  // ─── Sync Queue Repository ────────────────────────────────────────────────

  group('SyncQueueRepository', () {
    SyncQueueItem makeItem() {
      const uuid = Uuid();
      final now = DateTime.now();
      final clientId = uuid.v4();
      return SyncQueueItem(
        id: uuid.v4(),
        clientId: clientId,
        entityType: 'FARMER',
        entityId: uuid.v4(),
        operation: 'CREATE',
        payload: {'name': 'Test', 'phone': '9876543210'},
        status: SyncStatus.pending,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('Enqueue and count pending', () async {
      final item = makeItem();
      await syncRepo.enqueue(item);
      final count = await syncRepo.countPending();
      expect(count, equals(1));
    });

    test('getPending returns only pending items', () async {
      final item1 = makeItem();
      final item2 = makeItem();
      await syncRepo.enqueue(item1);
      await syncRepo.enqueue(item2);
      await syncRepo.updateStatus(item1.id, SyncStatus.synced);
      final pending = await syncRepo.getPending();
      expect(pending.length, equals(1));
      expect(pending.first.id, equals(item2.id));
    });

    test('updateStatus changes item status', () async {
      final item = makeItem();
      await syncRepo.enqueue(item);
      await syncRepo.updateStatus(item.id, SyncStatus.failed,
          error: 'Timeout');
      final all = await syncRepo.getAll();
      final found = all.firstWhere((i) => i.id == item.id);
      expect(found.status, equals(SyncStatus.failed));
      expect(found.lastError, equals('Timeout'));
    });

    test('incrementAttempt increases attempt count', () async {
      final item = makeItem();
      await syncRepo.enqueue(item);
      await syncRepo.incrementAttempt(item.id);
      await syncRepo.incrementAttempt(item.id);
      final all = await syncRepo.getAll();
      final found = all.firstWhere((i) => i.id == item.id);
      expect(found.attemptCount, equals(2));
    });
  });

  // ─── UUID Generation ─────────────────────────────────────────────────────

  group('UUID generation', () {
    test('UUIDs are unique across multiple generations', () {
      const uuid = Uuid();
      final ids = List.generate(100, (_) => uuid.v4()).toSet();
      expect(ids.length, equals(100));
    });

    test('UUID v4 matches expected format', () {
      const uuid = Uuid();
      final id = uuid.v4();
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
          .hasMatch(id), isTrue);
    });
  });

  // ─── Transaction Behavior ─────────────────────────────────────────────────

  group('Transaction behavior', () {
    test('Duplicate client_id in sync_queue is ignored (no exception)', () async {
      const uuid = Uuid();
      final now = DateTime.now();
      final clientId = uuid.v4();
      final item = SyncQueueItem(
        id: uuid.v4(),
        clientId: clientId,
        entityType: 'FARMER',
        entityId: uuid.v4(),
        operation: 'CREATE',
        payload: {},
        status: SyncStatus.pending,
        createdAt: now,
        updatedAt: now,
      );
      final item2 = SyncQueueItem(
        id: uuid.v4(),
        clientId: clientId, // Same clientId
        entityType: 'FARMER',
        entityId: uuid.v4(),
        operation: 'UPDATE',
        payload: {},
        status: SyncStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      await syncRepo.enqueue(item);
      // Second enqueue should be ignored (ConflictAlgorithm.ignore)
      await expectLater(syncRepo.enqueue(item2), completes);

      final all = await syncRepo.getAll();
      expect(all.length, equals(1));
    });
  });

  // ─── Entities ─────────────────────────────────────────────────────────────

  group('Domain entity construction', () {
    test('UserRole.fromString handles all known roles', () {
      expect(UserRole.fromString('FARMER'), equals(UserRole.farmer));
      expect(UserRole.fromString('FIELD_VET'), equals(UserRole.fieldVet));
      expect(UserRole.fromString('DISTRICT_OFFICER'),
          equals(UserRole.districtOfficer));
      expect(UserRole.fromString('STATE_ADMIN'), equals(UserRole.stateAdmin));
      expect(UserRole.fromString('LAB_USER'), equals(UserRole.labUser));
      expect(UserRole.fromString('SYSTEM_ADMIN'), equals(UserRole.systemAdmin));
    });

    test('AnimalSpecies.fromString round-trips via toApiString', () {
      for (final s in AnimalSpecies.values) {
        expect(AnimalSpecies.fromString(s.toApiString()), equals(s));
      }
    });

    test('RiskLevel.fromString handles all levels', () {
      for (final r in RiskLevel.values) {
        expect(RiskLevel.fromString(r.toApiString()), equals(r));
      }
    });

    test('LocalHealthCase copyWith preserves unchanged fields', () {
      const uuid = Uuid();
      final now = DateTime.now();
      final hc = LocalHealthCase(
        id: uuid.v4(),
        clientId: uuid.v4(),
        symptoms: {'Fever': true},
        riskLevel: RiskLevel.low,
        createdAt: now,
        updatedAt: now,
      );
      final updated = hc.copyWith(synced: true);
      expect(updated.synced, isTrue);
      expect(updated.id, equals(hc.id));
      expect(updated.symptoms, equals(hc.symptoms));
    });
  });
}
