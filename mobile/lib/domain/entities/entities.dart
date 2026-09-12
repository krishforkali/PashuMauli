// PashuMauli — Domain entities mirroring the server schema for offline use.
// These are pure Dart objects with no Flutter dependency.

/// User roles as defined in SECURITY.md
enum UserRole {
  farmer,
  fieldVet,
  districtOfficer,
  stateAdmin,
  labUser,
  systemAdmin;

  static UserRole fromString(String value) {
    switch (value.toUpperCase()) {
      case 'FARMER':
        return UserRole.farmer;
      case 'FIELD_VET':
        return UserRole.fieldVet;
      case 'DISTRICT_OFFICER':
        return UserRole.districtOfficer;
      case 'STATE_ADMIN':
        return UserRole.stateAdmin;
      case 'LAB_USER':
        return UserRole.labUser;
      case 'SYSTEM_ADMIN':
        return UserRole.systemAdmin;
      default:
        return UserRole.farmer;
    }
  }

  String toApiString() {
    switch (this) {
      case UserRole.farmer:
        return 'FARMER';
      case UserRole.fieldVet:
        return 'FIELD_VET';
      case UserRole.districtOfficer:
        return 'DISTRICT_OFFICER';
      case UserRole.stateAdmin:
        return 'STATE_ADMIN';
      case UserRole.labUser:
        return 'LAB_USER';
      case UserRole.systemAdmin:
        return 'SYSTEM_ADMIN';
    }
  }
}

/// Connectivity status
enum ConnectivityStatus { online, offline, unknown }

/// Sync queue operation status
enum SyncStatus { pending, syncing, synced, failed }

/// Animal species
enum AnimalSpecies {
  cattle,
  buffalo,
  goat,
  sheep,
  pig,
  poultry,
  other;

  static AnimalSpecies fromString(String value) {
    switch (value.toUpperCase()) {
      case 'CATTLE':
        return AnimalSpecies.cattle;
      case 'BUFFALO':
        return AnimalSpecies.buffalo;
      case 'GOAT':
        return AnimalSpecies.goat;
      case 'SHEEP':
        return AnimalSpecies.sheep;
      case 'PIG':
        return AnimalSpecies.pig;
      case 'POULTRY':
        return AnimalSpecies.poultry;
      default:
        return AnimalSpecies.other;
    }
  }

  String toApiString() => name.toUpperCase();
}

/// Animal sex
enum AnimalSex {
  male,
  female;

  static AnimalSex fromString(String value) {
    return value.toUpperCase() == 'MALE' ? AnimalSex.male : AnimalSex.female;
  }

  String toApiString() => name.toUpperCase();
}

/// Risk level for health cases
enum RiskLevel {
  low,
  medium,
  high,
  critical;

  static RiskLevel fromString(String value) {
    switch (value.toUpperCase()) {
      case 'LOW':
        return RiskLevel.low;
      case 'MEDIUM':
        return RiskLevel.medium;
      case 'HIGH':
        return RiskLevel.high;
      case 'CRITICAL':
        return RiskLevel.critical;
      default:
        return RiskLevel.low;
    }
  }

  String toApiString() => name.toUpperCase();
}

/// Local session / user entity (stored in local_users)
class LocalUser {
  final String id;
  final String name;
  final String phone;
  final UserRole role;
  final String? preferredLanguage;
  final String? accessToken;
  final String? refreshToken;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LocalUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.preferredLanguage,
    this.accessToken,
    this.refreshToken,
    required this.createdAt,
    required this.updatedAt,
  });

  LocalUser copyWith({
    String? accessToken,
    String? refreshToken,
    String? preferredLanguage,
    DateTime? updatedAt,
  }) {
    return LocalUser(
      id: id,
      name: name,
      phone: phone,
      role: role,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Local farmer entity (stored in local_farmers)
class LocalFarmer {
  final String id;
  final String? userId;
  final String name;
  final String phone;
  final String? preferredLanguage;
  final String? addressText;
  final double? latitude;
  final double? longitude;
  final bool synced;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LocalFarmer({
    required this.id,
    this.userId,
    required this.name,
    required this.phone,
    this.preferredLanguage,
    this.addressText,
    this.latitude,
    this.longitude,
    this.synced = false,
    required this.createdAt,
    required this.updatedAt,
  });

  LocalFarmer copyWith({bool? synced, DateTime? updatedAt}) {
    return LocalFarmer(
      id: id,
      userId: userId,
      name: name,
      phone: phone,
      preferredLanguage: preferredLanguage,
      addressText: addressText,
      latitude: latitude,
      longitude: longitude,
      synced: synced ?? this.synced,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Local animal entity (stored in local_animals)
class LocalAnimal {
  final String id;
  final String earTagId;
  final String farmerId;
  final AnimalSpecies species;
  final String? breed;
  final AnimalSex? sex;
  final DateTime? dateOfBirth;
  final String status;
  final double? latitude;
  final double? longitude;
  final bool synced;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LocalAnimal({
    required this.id,
    required this.earTagId,
    required this.farmerId,
    required this.species,
    this.breed,
    this.sex,
    this.dateOfBirth,
    this.status = 'ACTIVE',
    this.latitude,
    this.longitude,
    this.synced = false,
    required this.createdAt,
    required this.updatedAt,
  });

  LocalAnimal copyWith({bool? synced, DateTime? updatedAt, String? status}) {
    return LocalAnimal(
      id: id,
      earTagId: earTagId,
      farmerId: farmerId,
      species: species,
      breed: breed,
      sex: sex,
      dateOfBirth: dateOfBirth,
      status: status ?? this.status,
      latitude: latitude,
      longitude: longitude,
      synced: synced ?? this.synced,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Local health case entity (stored in local_health_cases)
class LocalHealthCase {
  final String id;
  final String clientId;
  final String? animalId;
  final String? farmerId;
  final String? reportedBy;
  final Map<String, dynamic> symptoms;
  final String? suspectedDisease;
  final double? confidence;
  final RiskLevel riskLevel;
  final String status;
  final double? latitude;
  final double? longitude;
  final String? aiModelVersion;
  final bool synced;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LocalHealthCase({
    required this.id,
    required this.clientId,
    this.animalId,
    this.farmerId,
    this.reportedBy,
    required this.symptoms,
    this.suspectedDisease,
    this.confidence,
    this.riskLevel = RiskLevel.low,
    this.status = 'OPEN',
    this.latitude,
    this.longitude,
    this.aiModelVersion,
    this.synced = false,
    required this.createdAt,
    required this.updatedAt,
  });

  LocalHealthCase copyWith({
    bool? synced,
    String? status,
    DateTime? updatedAt,
  }) {
    return LocalHealthCase(
      id: id,
      clientId: clientId,
      animalId: animalId,
      farmerId: farmerId,
      reportedBy: reportedBy,
      symptoms: symptoms,
      suspectedDisease: suspectedDisease,
      confidence: confidence,
      riskLevel: riskLevel,
      status: status ?? this.status,
      latitude: latitude,
      longitude: longitude,
      aiModelVersion: aiModelVersion,
      synced: synced ?? this.synced,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Local vaccination entity (stored in local_vaccinations)
class LocalVaccination {
  final String id;
  final String animalId;
  final String vaccine;
  final String? dose;
  final DateTime administeredAt;
  final DateTime? nextDueAt;
  final String? administeredBy;
  final String? batchNumber;
  final String? notes;
  final bool synced;
  final DateTime createdAt;

  const LocalVaccination({
    required this.id,
    required this.animalId,
    required this.vaccine,
    this.dose,
    required this.administeredAt,
    this.nextDueAt,
    this.administeredBy,
    this.batchNumber,
    this.notes,
    this.synced = false,
    required this.createdAt,
  });
}

/// Sync queue item (stored in sync_queue)
class SyncQueueItem {
  final String id;
  final String clientId;
  final String entityType;
  final String entityId;
  final String operation;
  final Map<String, dynamic> payload;
  final SyncStatus status;
  final int attemptCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SyncQueueItem({
    required this.id,
    required this.clientId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.status,
    this.attemptCount = 0,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  SyncQueueItem copyWith({
    SyncStatus? status,
    int? attemptCount,
    String? lastError,
    DateTime? updatedAt,
  }) {
    return SyncQueueItem(
      id: id,
      clientId: clientId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// AI model metadata (stored in model_metadata)
class ModelMetadata {
  final String modelName;
  final String modelVersion;
  final String filePath;
  final String hash;
  final DateTime installedAt;
  final String runtime;
  final String backend;
  final String status;

  const ModelMetadata({
    required this.modelName,
    required this.modelVersion,
    required this.filePath,
    required this.hash,
    required this.installedAt,
    this.runtime = 'UNKNOWN',
    this.backend = 'CPU',
    this.status = 'NOT_INSTALLED',
  });
}

/// Pending media (stored in pending_media)
class PendingMedia {
  final String id;
  final String localPath;
  final String entityType;
  final String entityId;
  final String status;
  final DateTime createdAt;

  const PendingMedia({
    required this.id,
    required this.localPath,
    required this.entityType,
    required this.entityId,
    this.status = 'QUEUED',
    required this.createdAt,
  });
}
