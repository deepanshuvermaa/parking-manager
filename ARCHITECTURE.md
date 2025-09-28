# ParkEase Manager - Complete Architecture

## Core Principles
1. **Single Source of Truth**: Each piece of state has exactly one owner
2. **Explicit Actions**: No magic auto-loading, all actions are explicit
3. **Offline First**: Everything works offline, syncs when online
4. **Device Management**: One active device per user at a time
5. **Data Integrity**: No data loss during sync or device switch

## Architecture Layers

### 1. Data Layer
```
models/
  - auth_session.dart      // User session with device info
  - sync_metadata.dart      // Track sync status for all entities
  - offline_queue.dart      // Queue for offline changes

database/
  - database_service.dart   // Single DB service
  - migrations.dart         // DB schema versions
  - sync_tables.sql         // Sync-specific tables
```

### 2. Service Layer
```
services/
  - auth_service.dart       // Authentication only
  - sync_service.dart       // Data synchronization
  - device_service.dart     // Device management
  - api_client.dart         // Simple HTTP client
  - storage_service.dart    // SharedPreferences wrapper
```

### 3. State Management
```
providers/
  - app_state_provider.dart     // Root provider
  - auth_state_provider.dart    // Auth state only
  - sync_state_provider.dart    // Sync status
  - settings_state_provider.dart // Settings state
  - vehicle_state_provider.dart // Vehicle data state
```

### 4. UI Layer
```
screens/
  - Stateless widgets that consume providers
  - No business logic
  - Only UI logic
```

## Data Flow

### Login Flow
```
1. User enters credentials
2. AuthService.login() called
3. Backend validates & returns:
   - JWT token
   - User data
   - Device registration
4. DeviceService registers device
5. SyncService pulls all user data
6. AuthStateProvider updates state
7. Navigation to Dashboard
```

### Logout Flow
```
1. User taps logout
2. SyncService pushes pending changes
3. AuthService.logout() called
4. Clear all local data
5. AuthStateProvider clears state
6. Navigation to Login
```

### Guest Login Flow
```
1. User enters name
2. AuthService.guestLogin() called
3. Creates temporary account
4. Limited features enabled
5. No data persistence
6. Clear on logout
```

### Data Sync Flow
```
1. Every data change:
   - Save to local DB with timestamp
   - Mark as 'pending_sync'
   - Queue for sync

2. When online:
   - Process sync queue
   - Send to backend
   - Mark as 'synced'

3. On conflict:
   - Last-write-wins by timestamp
   - Keep audit log

4. On device switch:
   - Old device: push all pending
   - New device: pull all data
   - Mark old device inactive
```

## Database Schema

### Core Tables
```sql
-- Users table
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  email TEXT UNIQUE,
  full_name TEXT,
  role TEXT,
  is_guest BOOLEAN,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- Devices table
CREATE TABLE devices (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  device_name TEXT,
  device_id TEXT UNIQUE,
  is_active BOOLEAN,
  last_active TIMESTAMP,
  registered_at TIMESTAMP
);

-- Settings table
CREATE TABLE settings (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  key TEXT,
  value TEXT,
  updated_at TIMESTAMP,
  sync_status TEXT
);

-- Sync queue table
CREATE TABLE sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_type TEXT,
  entity_id TEXT,
  operation TEXT, -- CREATE, UPDATE, DELETE
  data TEXT, -- JSON
  created_at TIMESTAMP,
  retry_count INTEGER DEFAULT 0,
  error TEXT
);

-- Sync metadata table
CREATE TABLE sync_metadata (
  entity_type TEXT,
  entity_id TEXT,
  local_updated_at TIMESTAMP,
  server_updated_at TIMESTAMP,
  sync_status TEXT,
  device_id TEXT,
  PRIMARY KEY (entity_type, entity_id)
);
```

## State Management

### AppStateProvider (Root)
```dart
class AppStateProvider extends ChangeNotifier {
  AuthState? authState;
  SyncState? syncState;
  SettingsState? settingsState;

  // Initialization (called once)
  Future<void> initialize() async {
    // Check stored auth
    // Load settings if authenticated
    // Start sync if online
  }

  // Clear all state
  void reset() {
    authState = null;
    syncState = null;
    settingsState = null;
    notifyListeners();
  }
}
```

### AuthStateProvider
```dart
class AuthStateProvider extends ChangeNotifier {
  AuthSession? _session;
  bool _isLoading = false;

  bool get isAuthenticated => _session != null;
  bool get isGuest => _session?.isGuest ?? false;
  String get displayName => _session?.user.fullName ?? '';

  // NO constructor loading
  // NO auto-login

  Future<void> login(String email, String password, bool rememberMe) async {
    // Login logic
    // Device registration
    // Data sync
  }

  Future<void> logout() async {
    // Sync pending
    // Clear session
    // Notify listeners
  }
}
```

## Key Services

### SyncService
```dart
class SyncService {
  // Push local changes to server
  Future<SyncResult> pushChanges() async {
    final pending = await getQueuedChanges();
    final results = <SyncResult>[];

    for (final change in pending) {
      try {
        await apiClient.sync(change);
        await markSynced(change.id);
        results.add(SyncResult.success(change.id));
      } catch (e) {
        await incrementRetry(change.id);
        results.add(SyncResult.failed(change.id, e));
      }
    }

    return SyncResult.batch(results);
  }

  // Pull server changes to local
  Future<void> pullChanges(DateTime lastSync) async {
    final changes = await apiClient.getChanges(lastSync);
    await applyServerChanges(changes);
  }
}
```

### DeviceService
```dart
class DeviceService {
  Future<bool> registerDevice(String userId) async {
    final deviceId = await getDeviceId();
    final response = await apiClient.registerDevice(userId, deviceId);
    await storage.setActiveDevice(deviceId);
    return response.success;
  }

  Future<bool> checkActiveStatus() async {
    final localDevice = await storage.getActiveDevice();
    final serverDevice = await apiClient.getActiveDevice();
    return localDevice == serverDevice;
  }

  Stream<DeviceStatus> monitorDeviceStatus() {
    // Check every 30 seconds
    return Stream.periodic(Duration(seconds: 30))
      .asyncMap((_) => checkActiveStatus())
      .map((active) => active ? DeviceStatus.active : DeviceStatus.inactive);
  }
}
```

## Implementation Order

1. **Phase 1: Core Infrastructure**
   - Delete broken providers
   - Create new models
   - Setup database with sync tables
   - Create storage service

2. **Phase 2: Authentication**
   - Implement AuthService
   - Implement DeviceService
   - Create AuthStateProvider
   - Fix login/logout screens

3. **Phase 3: Data Sync**
   - Implement SyncService
   - Create sync queue
   - Add conflict resolution
   - Test offline/online

4. **Phase 4: Settings**
   - Implement SettingsStateProvider
   - Fix settings screens
   - Add version tracking

5. **Phase 5: Integration**
   - Wire everything together
   - Add error handling
   - Test all flows
   - Add monitoring

## Error Handling

```dart
class AppError {
  final String code;
  final String message;
  final String? details;
  final bool isRecoverable;

  // Predefined errors
  static const deviceInactive = AppError(
    code: 'DEVICE_INACTIVE',
    message: 'This device is no longer active',
    isRecoverable: false,
  );

  static const syncFailed = AppError(
    code: 'SYNC_FAILED',
    message: 'Failed to sync data',
    isRecoverable: true,
  );
}
```

## Testing Strategy

1. **Unit Tests**
   - Test each service independently
   - Mock dependencies
   - Test error cases

2. **Integration Tests**
   - Test full flows
   - Test offline scenarios
   - Test device switching

3. **Manual Tests**
   - Login/logout
   - Guest login
   - Settings persistence
   - Device switch
   - Offline work