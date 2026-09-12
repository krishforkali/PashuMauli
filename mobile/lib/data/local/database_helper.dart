import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// PashuMauli local SQLite database.
///
/// Manages schema versioning and migrations.
/// All writes must go through transactions — see OFFLINE_SYNC.md §Offline write rule.
class DatabaseHelper {
  static const String _dbName = 'pashumauli.db';
  static const int _dbVersion = 2;

  static DatabaseHelper? _instance;
  Database? _database;
  final String? _dbPath;

  DatabaseHelper._({String? dbPath}) : _dbPath = dbPath;

  static DatabaseHelper get instance {
    _instance ??= DatabaseHelper._();
    return _instance!;
  }

  /// Create an in-memory database helper for tests
  static DatabaseHelper inMemory() =>
      DatabaseHelper._(dbPath: inMemoryDatabasePath);

  /// Create a database helper for a custom path
  static DatabaseHelper forPath(String path) => DatabaseHelper._(dbPath: path);

  /// Set the singleton instance (for testing)
  static void setInstanceForTesting(DatabaseHelper? helper) {
    _instance = helper;
  }

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final customPath = _dbPath;
    final String path;
    if (customPath != null) {
      path = customPath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = p.join(dir.path, _dbName);
    }
    debugPrint('[DB] Opening database at $path');
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Enable foreign key enforcement
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('[DB] Creating schema version $version');
    await db.transaction((txn) async {
      await _createLocalUsers(txn);
      await _createLocalFarmers(txn);
      await _createLocalAnimals(txn);
      await _createLocalHealthCases(txn);
      await _createLocalVaccinations(txn);
      await _createSyncQueue(txn);
      await _createModelMetadata(txn);
      await _createPendingMedia(txn);
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('[DB] Upgrading from $oldVersion to $newVersion');
    if (oldVersion < 2) {
      await db.execute(
          "ALTER TABLE model_metadata ADD COLUMN runtime TEXT NOT NULL DEFAULT 'UNKNOWN'");
      await db.execute(
          "ALTER TABLE model_metadata ADD COLUMN backend TEXT NOT NULL DEFAULT 'CPU'");
      await db.execute(
          "ALTER TABLE model_metadata ADD COLUMN status TEXT NOT NULL DEFAULT 'NOT_INSTALLED'");
    }
  }

  // ─── Schema DDL ─────────────────────────────────────────────────────────────

  Future<void> _createLocalUsers(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_users (
        id             TEXT PRIMARY KEY NOT NULL,
        name           TEXT NOT NULL,
        phone          TEXT NOT NULL UNIQUE,
        role           TEXT NOT NULL,
        preferred_lang TEXT,
        is_active      INTEGER NOT NULL DEFAULT 1,
        created_at     TEXT NOT NULL,
        updated_at     TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_local_users_phone ON local_users(phone)');
  }

  Future<void> _createLocalFarmers(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_farmers (
        id             TEXT PRIMARY KEY NOT NULL,
        user_id        TEXT,
        name           TEXT NOT NULL,
        phone          TEXT NOT NULL,
        preferred_lang TEXT,
        address_text   TEXT,
        latitude       REAL,
        longitude      REAL,
        synced         INTEGER NOT NULL DEFAULT 0,
        created_at     TEXT NOT NULL,
        updated_at     TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_local_farmers_synced ON local_farmers(synced)');
  }

  Future<void> _createLocalAnimals(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_animals (
        id            TEXT PRIMARY KEY NOT NULL,
        ear_tag_id    TEXT NOT NULL UNIQUE,
        farmer_id     TEXT NOT NULL REFERENCES local_farmers(id),
        species       TEXT NOT NULL,
        breed         TEXT,
        sex           TEXT,
        date_of_birth TEXT,
        status        TEXT NOT NULL DEFAULT 'ACTIVE',
        latitude      REAL,
        longitude     REAL,
        synced        INTEGER NOT NULL DEFAULT 0,
        created_at    TEXT NOT NULL,
        updated_at    TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_local_animals_farmer ON local_animals(farmer_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_local_animals_synced ON local_animals(synced)');
  }

  Future<void> _createLocalHealthCases(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_health_cases (
        id                 TEXT PRIMARY KEY NOT NULL,
        client_id          TEXT NOT NULL UNIQUE,
        animal_id          TEXT,
        farmer_id          TEXT,
        reported_by        TEXT,
        symptoms           TEXT NOT NULL DEFAULT '{}',
        suspected_disease  TEXT,
        confidence         REAL,
        risk_level         TEXT NOT NULL DEFAULT 'LOW',
        status             TEXT NOT NULL DEFAULT 'OPEN',
        latitude           REAL,
        longitude          REAL,
        ai_model_version   TEXT,
        synced             INTEGER NOT NULL DEFAULT 0,
        created_at         TEXT NOT NULL,
        updated_at         TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_local_cases_synced ON local_health_cases(synced)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_local_cases_animal ON local_health_cases(animal_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_local_cases_client ON local_health_cases(client_id)');
  }

  Future<void> _createLocalVaccinations(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_vaccinations (
        id               TEXT PRIMARY KEY NOT NULL,
        animal_id        TEXT NOT NULL REFERENCES local_animals(id),
        vaccine          TEXT NOT NULL,
        dose             TEXT,
        administered_at  TEXT NOT NULL,
        next_due_at      TEXT,
        administered_by  TEXT,
        batch_number     TEXT,
        notes            TEXT,
        synced           INTEGER NOT NULL DEFAULT 0,
        created_at       TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_local_vacc_animal ON local_vaccinations(animal_id)');
  }

  Future<void> _createSyncQueue(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id             TEXT PRIMARY KEY NOT NULL,
        client_id      TEXT NOT NULL UNIQUE,
        entity_type    TEXT NOT NULL,
        entity_id      TEXT NOT NULL,
        operation      TEXT NOT NULL,
        payload        TEXT NOT NULL DEFAULT '{}',
        status         TEXT NOT NULL DEFAULT 'PENDING',
        attempt_count  INTEGER NOT NULL DEFAULT 0,
        last_error     TEXT,
        created_at     TEXT NOT NULL,
        updated_at     TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(status, created_at)');
  }

  Future<void> _createModelMetadata(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS model_metadata (
        model_name     TEXT PRIMARY KEY NOT NULL,
        model_version  TEXT NOT NULL,
        file_path      TEXT NOT NULL,
        hash           TEXT NOT NULL,
        installed_at   TEXT NOT NULL,
        runtime        TEXT NOT NULL DEFAULT 'UNKNOWN',
        backend        TEXT NOT NULL DEFAULT 'CPU',
        status         TEXT NOT NULL DEFAULT 'NOT_INSTALLED'
      )
    ''');
  }

  Future<void> _createPendingMedia(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_media (
        id           TEXT PRIMARY KEY NOT NULL,
        local_path   TEXT NOT NULL,
        entity_type  TEXT NOT NULL,
        entity_id    TEXT NOT NULL,
        status       TEXT NOT NULL DEFAULT 'QUEUED',
        created_at   TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_pending_media_entity ON pending_media(entity_type, entity_id)');
  }

  // ─── Utilities ───────────────────────────────────────────────────────────────

  /// Close the database (useful in tests)
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  /// Drop and recreate all tables (test/demo use only)
  @visibleForTesting
  Future<void> dropAndRecreate() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.execute('DROP TABLE IF EXISTS pending_media');
      await txn.execute('DROP TABLE IF EXISTS model_metadata');
      await txn.execute('DROP TABLE IF EXISTS sync_queue');
      await txn.execute('DROP TABLE IF EXISTS local_vaccinations');
      await txn.execute('DROP TABLE IF EXISTS local_health_cases');
      await txn.execute('DROP TABLE IF EXISTS local_animals');
      await txn.execute('DROP TABLE IF EXISTS local_farmers');
      await txn.execute('DROP TABLE IF EXISTS local_users');
    });
    await _onCreate(db, _dbVersion);
  }
}
