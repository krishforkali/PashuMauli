import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:pashumauli/data/local/database_helper.dart';
import 'package:pashumauli/domain/entities/entities.dart';

/// Repository for local farmer persistence.
/// Every write is committed in a SQLite transaction before returning — OFFLINE_SYNC.md rule.
class FarmerLocalRepository {
  final DatabaseHelper _db;
  FarmerLocalRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  Future<String> insert(LocalFarmer farmer) async {
    final database = await _db.database;
    await database.transaction((txn) async {
      await txn.insert('local_farmers', _toMap(farmer));
    });
    return farmer.id;
  }

  Future<LocalFarmer?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query('local_farmers',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _fromMap(rows.first);
  }

  Future<List<LocalFarmer>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('local_farmers', orderBy: 'created_at DESC');
    return rows.map(_fromMap).toList();
  }

  Future<List<LocalFarmer>> getUnsynced() async {
    final db = await _db.database;
    final rows = await db.query('local_farmers',
        where: 'synced = ?', whereArgs: [0], orderBy: 'created_at ASC');
    return rows.map(_fromMap).toList();
  }

  Future<void> update(LocalFarmer farmer) async {
    final database = await _db.database;
    await database.transaction((txn) async {
      await txn.update('local_farmers', _toMap(farmer),
          where: 'id = ?', whereArgs: [farmer.id]);
    });
  }

  Future<void> markSynced(String id) async {
    final database = await _db.database;
    await database.transaction((txn) async {
      await txn.update(
        'local_farmers',
        {'synced': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Map<String, dynamic> _toMap(LocalFarmer f) => {
        'id': f.id,
        'user_id': f.userId,
        'name': f.name,
        'phone': f.phone,
        'preferred_lang': f.preferredLanguage,
        'address_text': f.addressText,
        'latitude': f.latitude,
        'longitude': f.longitude,
        'synced': f.synced ? 1 : 0,
        'created_at': f.createdAt.toIso8601String(),
        'updated_at': f.updatedAt.toIso8601String(),
      };

  LocalFarmer _fromMap(Map<String, dynamic> m) => LocalFarmer(
        id: m['id'] as String,
        userId: m['user_id'] as String?,
        name: m['name'] as String,
        phone: m['phone'] as String,
        preferredLanguage: m['preferred_lang'] as String?,
        addressText: m['address_text'] as String?,
        latitude: m['latitude'] as double?,
        longitude: m['longitude'] as double?,
        synced: (m['synced'] as int) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );
}

/// Repository for local animal persistence.
class AnimalLocalRepository {
  final DatabaseHelper _db;
  AnimalLocalRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  Future<String> insert(LocalAnimal animal) async {
    final database = await _db.database;
    await database.transaction((txn) async {
      await txn.insert('local_animals', _toMap(animal));
    });
    return animal.id;
  }

  Future<LocalAnimal?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query('local_animals',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _fromMap(rows.first);
  }

  Future<List<LocalAnimal>> getByFarmer(String farmerId) async {
    final db = await _db.database;
    final rows = await db.query('local_animals',
        where: 'farmer_id = ?',
        whereArgs: [farmerId],
        orderBy: 'created_at DESC');
    return rows.map(_fromMap).toList();
  }

  Future<List<LocalAnimal>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('local_animals', orderBy: 'created_at DESC');
    return rows.map(_fromMap).toList();
  }

  Future<List<LocalAnimal>> getUnsynced() async {
    final db = await _db.database;
    final rows = await db.query('local_animals',
        where: 'synced = ?', whereArgs: [0], orderBy: 'created_at ASC');
    return rows.map(_fromMap).toList();
  }

  Future<LocalAnimal?> getByEarTag(String earTagId) async {
    final db = await _db.database;
    final rows = await db.query('local_animals',
        where: 'ear_tag_id = ?', whereArgs: [earTagId], limit: 1);
    if (rows.isEmpty) return null;
    return _fromMap(rows.first);
  }

  Future<void> markSynced(String id) async {
    final database = await _db.database;
    await database.transaction((txn) async {
      await txn.update(
        'local_animals',
        {'synced': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Map<String, dynamic> _toMap(LocalAnimal a) => {
        'id': a.id,
        'ear_tag_id': a.earTagId,
        'farmer_id': a.farmerId,
        'species': a.species.toApiString(),
        'breed': a.breed,
        'sex': a.sex?.toApiString(),
        'date_of_birth': a.dateOfBirth?.toIso8601String(),
        'status': a.status,
        'latitude': a.latitude,
        'longitude': a.longitude,
        'synced': a.synced ? 1 : 0,
        'created_at': a.createdAt.toIso8601String(),
        'updated_at': a.updatedAt.toIso8601String(),
      };

  LocalAnimal _fromMap(Map<String, dynamic> m) => LocalAnimal(
        id: m['id'] as String,
        earTagId: m['ear_tag_id'] as String,
        farmerId: m['farmer_id'] as String,
        species: AnimalSpecies.fromString(m['species'] as String),
        breed: m['breed'] as String?,
        sex: m['sex'] != null
            ? AnimalSex.fromString(m['sex'] as String)
            : null,
        dateOfBirth: m['date_of_birth'] != null
            ? DateTime.parse(m['date_of_birth'] as String)
            : null,
        status: m['status'] as String,
        latitude: m['latitude'] as double?,
        longitude: m['longitude'] as double?,
        synced: (m['synced'] as int) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );
}

/// Repository for local health case persistence.
class HealthCaseLocalRepository {
  final DatabaseHelper _db;
  HealthCaseLocalRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  Future<String> insert(LocalHealthCase hc) async {
    final database = await _db.database;
    await database.transaction((txn) async {
      await txn.insert('local_health_cases', _toMap(hc));
    });
    return hc.id;
  }

  Future<LocalHealthCase?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query('local_health_cases',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _fromMap(rows.first);
  }

  Future<LocalHealthCase?> getByClientId(String clientId) async {
    final db = await _db.database;
    final rows = await db.query('local_health_cases',
        where: 'client_id = ?', whereArgs: [clientId], limit: 1);
    if (rows.isEmpty) return null;
    return _fromMap(rows.first);
  }

  Future<List<LocalHealthCase>> getByAnimal(String animalId) async {
    final db = await _db.database;
    final rows = await db.query('local_health_cases',
        where: 'animal_id = ?',
        whereArgs: [animalId],
        orderBy: 'created_at DESC');
    return rows.map(_fromMap).toList();
  }

  Future<List<LocalHealthCase>> getAll() async {
    final db = await _db.database;
    final rows =
        await db.query('local_health_cases', orderBy: 'created_at DESC');
    return rows.map(_fromMap).toList();
  }

  Future<List<LocalHealthCase>> getUnsynced() async {
    final db = await _db.database;
    final rows = await db.query('local_health_cases',
        where: 'synced = ?', whereArgs: [0], orderBy: 'created_at ASC');
    return rows.map(_fromMap).toList();
  }

  Future<void> markSynced(String id) async {
    final database = await _db.database;
    await database.transaction((txn) async {
      await txn.update(
        'local_health_cases',
        {'synced': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Map<String, dynamic> _toMap(LocalHealthCase hc) => {
        'id': hc.id,
        'client_id': hc.clientId,
        'animal_id': hc.animalId,
        'farmer_id': hc.farmerId,
        'reported_by': hc.reportedBy,
        'symptoms': jsonEncode(hc.symptoms),
        'suspected_disease': hc.suspectedDisease,
        'confidence': hc.confidence,
        'risk_level': hc.riskLevel.toApiString(),
        'status': hc.status,
        'latitude': hc.latitude,
        'longitude': hc.longitude,
        'ai_model_version': hc.aiModelVersion,
        'synced': hc.synced ? 1 : 0,
        'created_at': hc.createdAt.toIso8601String(),
        'updated_at': hc.updatedAt.toIso8601String(),
      };

  LocalHealthCase _fromMap(Map<String, dynamic> m) => LocalHealthCase(
        id: m['id'] as String,
        clientId: m['client_id'] as String,
        animalId: m['animal_id'] as String?,
        farmerId: m['farmer_id'] as String?,
        reportedBy: m['reported_by'] as String?,
        symptoms: jsonDecode(m['symptoms'] as String) as Map<String, dynamic>,
        suspectedDisease: m['suspected_disease'] as String?,
        confidence: m['confidence'] as double?,
        riskLevel: RiskLevel.fromString(m['risk_level'] as String),
        status: m['status'] as String,
        latitude: m['latitude'] as double?,
        longitude: m['longitude'] as double?,
        aiModelVersion: m['ai_model_version'] as String?,
        synced: (m['synced'] as int) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );
}

/// Repository for local vaccination records.
class VaccinationLocalRepository {
  final DatabaseHelper _db;
  VaccinationLocalRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  Future<String> insert(LocalVaccination v) async {
    final database = await _db.database;
    await database.transaction((txn) async {
      await txn.insert('local_vaccinations', _toMap(v));
    });
    return v.id;
  }

  Future<List<LocalVaccination>> getByAnimal(String animalId) async {
    final db = await _db.database;
    final rows = await db.query('local_vaccinations',
        where: 'animal_id = ?',
        whereArgs: [animalId],
        orderBy: 'administered_at DESC');
    return rows.map(_fromMap).toList();
  }

  Map<String, dynamic> _toMap(LocalVaccination v) => {
        'id': v.id,
        'animal_id': v.animalId,
        'vaccine': v.vaccine,
        'dose': v.dose,
        'administered_at': v.administeredAt.toIso8601String(),
        'next_due_at': v.nextDueAt?.toIso8601String(),
        'administered_by': v.administeredBy,
        'batch_number': v.batchNumber,
        'notes': v.notes,
        'synced': v.synced ? 1 : 0,
        'created_at': v.createdAt.toIso8601String(),
      };

  LocalVaccination _fromMap(Map<String, dynamic> m) => LocalVaccination(
        id: m['id'] as String,
        animalId: m['animal_id'] as String,
        vaccine: m['vaccine'] as String,
        dose: m['dose'] as String?,
        administeredAt: DateTime.parse(m['administered_at'] as String),
        nextDueAt: m['next_due_at'] != null
            ? DateTime.parse(m['next_due_at'] as String)
            : null,
        administeredBy: m['administered_by'] as String?,
        batchNumber: m['batch_number'] as String?,
        notes: m['notes'] as String?,
        synced: (m['synced'] as int) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// Repository for the sync operation queue.
class SyncQueueRepository {
  final DatabaseHelper _db;
  SyncQueueRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  Future<void> enqueue(SyncQueueItem item) async {
    final database = await _db.database;
    await database.transaction((txn) async {
      await txn.insert('sync_queue', _toMap(item),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }

  Future<List<SyncQueueItem>> getPending() async {
    final db = await _db.database;
    final rows = await db.query('sync_queue',
        where: 'status = ?',
        whereArgs: ['PENDING'],
        orderBy: 'created_at ASC');
    return rows.map(_fromMap).toList();
  }

  Future<List<SyncQueueItem>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('sync_queue', orderBy: 'created_at DESC');
    return rows.map(_fromMap).toList();
  }

  Future<void> updateStatus(
      String id, SyncStatus status, {String? error}) async {
    final database = await _db.database;
    await database.transaction((txn) async {
      await txn.update(
        'sync_queue',
        {
          'status': _statusToString(status),
          'last_error': error,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> incrementAttempt(String id) async {
    final database = await _db.database;
    await database.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE sync_queue SET attempt_count = attempt_count + 1, updated_at = ? WHERE id = ?',
        [DateTime.now().toIso8601String(), id],
      );
    });
  }

  Future<int> countPending() async {
    final db = await _db.database;
    final result = await db.rawQuery(
        "SELECT COUNT(*) as c FROM sync_queue WHERE status = 'PENDING'");
    return (result.first['c'] as int?) ?? 0;
  }

  String _statusToString(SyncStatus s) {
    switch (s) {
      case SyncStatus.pending:
        return 'PENDING';
      case SyncStatus.syncing:
        return 'SYNCING';
      case SyncStatus.synced:
        return 'SYNCED';
      case SyncStatus.failed:
        return 'FAILED';
    }
  }

  SyncStatus _statusFromString(String s) {
    switch (s) {
      case 'SYNCING':
        return SyncStatus.syncing;
      case 'SYNCED':
        return SyncStatus.synced;
      case 'FAILED':
        return SyncStatus.failed;
      default:
        return SyncStatus.pending;
    }
  }

  Map<String, dynamic> _toMap(SyncQueueItem i) => {
        'id': i.id,
        'client_id': i.clientId,
        'entity_type': i.entityType,
        'entity_id': i.entityId,
        'operation': i.operation,
        'payload': jsonEncode(i.payload),
        'status': _statusToString(i.status),
        'attempt_count': i.attemptCount,
        'last_error': i.lastError,
        'created_at': i.createdAt.toIso8601String(),
        'updated_at': i.updatedAt.toIso8601String(),
      };

  SyncQueueItem _fromMap(Map<String, dynamic> m) => SyncQueueItem(
        id: m['id'] as String,
        clientId: m['client_id'] as String,
        entityType: m['entity_type'] as String,
        entityId: m['entity_id'] as String,
        operation: m['operation'] as String,
        payload:
            jsonDecode(m['payload'] as String) as Map<String, dynamic>,
        status: _statusFromString(m['status'] as String),
        attemptCount: m['attempt_count'] as int,
        lastError: m['last_error'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );
}

/// Repository for pending media metadata.
class PendingMediaRepository {
  final DatabaseHelper _db;
  PendingMediaRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  Future<void> insert(PendingMedia media) async {
    final database = await _db.database;
    await database.transaction((txn) async {
      await txn.insert('pending_media', {
        'id': media.id,
        'local_path': media.localPath,
        'entity_type': media.entityType,
        'entity_id': media.entityId,
        'status': media.status,
        'created_at': media.createdAt.toIso8601String(),
      });
    });
  }

  Future<List<PendingMedia>> getQueued() async {
    final db = await _db.database;
    final rows = await db.query('pending_media',
        where: 'status = ?', whereArgs: ['QUEUED']);
    return rows.map(_fromMap).toList();
  }

  Future<List<PendingMedia>> getByEntity(
      String entityType, String entityId) async {
    final db = await _db.database;
    final rows = await db.query('pending_media',
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: [entityType, entityId]);
    return rows.map(_fromMap).toList();
  }

  PendingMedia _fromMap(Map<String, dynamic> m) => PendingMedia(
        id: m['id'] as String,
        localPath: m['local_path'] as String,
        entityType: m['entity_type'] as String,
        entityId: m['entity_id'] as String,
        status: m['status'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
