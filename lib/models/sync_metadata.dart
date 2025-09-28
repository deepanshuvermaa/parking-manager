import 'dart:convert';

/// Sync metadata for tracking data synchronization
class SyncMetadata {
  final String entityType;
  final String entityId;
  final DateTime localUpdatedAt;
  final DateTime? serverUpdatedAt;
  final SyncStatus syncStatus;
  final String deviceId;
  final int retryCount;
  final String? lastError;

  SyncMetadata({
    required this.entityType,
    required this.entityId,
    required this.localUpdatedAt,
    this.serverUpdatedAt,
    required this.syncStatus,
    required this.deviceId,
    this.retryCount = 0,
    this.lastError,
  });

  Map<String, dynamic> toJson() {
    return {
      'entityType': entityType,
      'entityId': entityId,
      'localUpdatedAt': localUpdatedAt.toIso8601String(),
      'serverUpdatedAt': serverUpdatedAt?.toIso8601String(),
      'syncStatus': syncStatus.name,
      'deviceId': deviceId,
      'retryCount': retryCount,
      'lastError': lastError,
    };
  }

  factory SyncMetadata.fromJson(Map<String, dynamic> json) {
    return SyncMetadata(
      entityType: json['entityType'],
      entityId: json['entityId'],
      localUpdatedAt: DateTime.parse(json['localUpdatedAt']),
      serverUpdatedAt: json['serverUpdatedAt'] != null
          ? DateTime.parse(json['serverUpdatedAt'])
          : null,
      syncStatus: SyncStatus.values.byName(json['syncStatus']),
      deviceId: json['deviceId'],
      retryCount: json['retryCount'] ?? 0,
      lastError: json['lastError'],
    );
  }
}

/// Sync status enumeration
enum SyncStatus {
  pending,    // Waiting to be synced
  syncing,    // Currently syncing
  synced,     // Successfully synced
  conflict,   // Conflict detected
  failed,     // Sync failed
}

/// Sync operation type
enum SyncOperation {
  create,
  update,
  delete,
}

/// Sync queue item for offline changes
class SyncQueueItem {
  final int? id;
  final String entityType;
  final String entityId;
  final SyncOperation operation;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;
  final String? error;

  SyncQueueItem({
    this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.error,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entityType': entityType,
      'entityId': entityId,
      'operation': operation.name,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'error': error,
    };
  }

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id'],
      entityType: json['entityType'],
      entityId: json['entityId'],
      operation: SyncOperation.values.byName(json['operation']),
      data: json['data'] is String
          ? Map<String, dynamic>.from(jsonDecode(json['data']))
          : Map<String, dynamic>.from(json['data']),
      createdAt: DateTime.parse(json['createdAt']),
      retryCount: json['retryCount'] ?? 0,
      error: json['error'],
    );
  }
}

/// Sync result for tracking sync operations
class SyncResult {
  final bool success;
  final int itemsSynced;
  final int itemsFailed;
  final List<String> errors;
  final DateTime syncTime;

  SyncResult({
    required this.success,
    required this.itemsSynced,
    required this.itemsFailed,
    required this.errors,
    required this.syncTime,
  });

  factory SyncResult.empty() {
    return SyncResult(
      success: true,
      itemsSynced: 0,
      itemsFailed: 0,
      errors: [],
      syncTime: DateTime.now(),
    );
  }

  factory SyncResult.failure(String error) {
    return SyncResult(
      success: false,
      itemsSynced: 0,
      itemsFailed: 1,
      errors: [error],
      syncTime: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'itemsSynced': itemsSynced,
      'itemsFailed': itemsFailed,
      'errors': errors,
      'syncTime': syncTime.toIso8601String(),
    };
  }
}