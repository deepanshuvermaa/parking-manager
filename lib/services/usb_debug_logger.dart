import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Log levels for USB debugging
enum LogLevel {
  info,
  success,
  warning,
  error,
  debug,
}

/// Single log entry with timestamp and metadata
class LogEntry {
  final DateTime timestamp;
  final String message;
  final LogLevel level;
  final String? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.message,
    required this.level,
    this.stackTrace,
  });

  String get emoji {
    switch (level) {
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.success:
        return '✅';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.debug:
        return '🔧';
    }
  }

  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}.${timestamp.millisecond.toString().padLeft(3, '0')}';
  }

  @override
  String toString() {
    final sb = StringBuffer();
    sb.write('[$formattedTime] $emoji $message');
    if (stackTrace != null) {
      sb.write('\n$stackTrace');
    }
    return sb.toString();
  }
}

/// Singleton USB Debug Logger
/// Captures all USB printer operations for in-app debugging
class UsbDebugLogger extends ChangeNotifier {
  static final UsbDebugLogger _instance = UsbDebugLogger._internal();
  factory UsbDebugLogger() => _instance;
  UsbDebugLogger._internal();

  final List<LogEntry> _logs = [];
  static const int MAX_LOGS = 500;

  /// Get all logs
  List<LogEntry> get logs => List.unmodifiable(_logs);

  /// Get logs count
  int get logCount => _logs.length;

  /// Log a message with level
  void log(String message, {LogLevel level = LogLevel.info, String? stackTrace}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      message: message,
      level: level,
      stackTrace: stackTrace,
    );

    // Add to beginning for reverse chronological order
    _logs.insert(0, entry);

    // Maintain circular buffer
    if (_logs.length > MAX_LOGS) {
      _logs.removeLast();
    }

    // Also print to console for ADB users
    print('[USB] ${entry.toString()}');

    // Notify listeners for real-time UI updates
    notifyListeners();
  }

  /// Convenience methods for different log levels
  void info(String message) => log(message, level: LogLevel.info);
  void success(String message) => log(message, level: LogLevel.success);
  void warning(String message) => log(message, level: LogLevel.warning);
  void error(String message, {String? stackTrace}) => log(message, level: LogLevel.error, stackTrace: stackTrace);
  void debug(String message) => log(message, level: LogLevel.debug);

  /// Clear all logs
  void clear() {
    _logs.clear();
    notifyListeners();
    log('Logs cleared', level: LogLevel.info);
  }

  /// Export logs to file
  Future<File?> exportLogs() async {
    try {
      if (_logs.isEmpty) {
        log('No logs to export', level: LogLevel.warning);
        return null;
      }

      // Get documents directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final file = File('${directory.path}/usb_debug_logs_$timestamp.txt');

      // Build log content
      final sb = StringBuffer();
      sb.writeln('========================================');
      sb.writeln('USB PRINTER DEBUG LOGS');
      sb.writeln('========================================');
      sb.writeln('Exported: ${DateTime.now()}');
      sb.writeln('Total Entries: ${_logs.length}');
      sb.writeln('========================================\n');

      // Add logs in chronological order (reverse of display)
      for (var entry in _logs.reversed) {
        sb.writeln(entry.toString());
        sb.writeln('----------------------------------------');
      }

      // Write to file
      await file.writeAsString(sb.toString());

      log('Logs exported to: ${file.path}', level: LogLevel.success);
      return file;
    } catch (e, stackTrace) {
      log('Failed to export logs: $e', level: LogLevel.error, stackTrace: stackTrace.toString());
      return null;
    }
  }

  /// Get logs as text (for sharing)
  String getLogsAsText() {
    if (_logs.isEmpty) return 'No logs available';

    final sb = StringBuffer();
    sb.writeln('USB PRINTER DEBUG LOGS');
    sb.writeln('Generated: ${DateTime.now()}');
    sb.writeln('Total: ${_logs.length} entries');
    sb.writeln('========================\n');

    for (var entry in _logs.reversed) {
      sb.writeln(entry.toString());
      sb.writeln('---');
    }

    return sb.toString();
  }

  /// Filter logs by level
  List<LogEntry> filterByLevel(LogLevel level) {
    return _logs.where((entry) => entry.level == level).toList();
  }

  /// Search logs
  List<LogEntry> search(String query) {
    if (query.isEmpty) return _logs;
    final lowerQuery = query.toLowerCase();
    return _logs.where((entry) => entry.message.toLowerCase().contains(lowerQuery)).toList();
  }

  /// Get summary statistics
  Map<String, int> getStatistics() {
    final stats = {
      'total': _logs.length,
      'info': 0,
      'success': 0,
      'warning': 0,
      'error': 0,
      'debug': 0,
    };

    for (var entry in _logs) {
      switch (entry.level) {
        case LogLevel.info:
          stats['info'] = (stats['info'] ?? 0) + 1;
          break;
        case LogLevel.success:
          stats['success'] = (stats['success'] ?? 0) + 1;
          break;
        case LogLevel.warning:
          stats['warning'] = (stats['warning'] ?? 0) + 1;
          break;
        case LogLevel.error:
          stats['error'] = (stats['error'] ?? 0) + 1;
          break;
        case LogLevel.debug:
          stats['debug'] = (stats['debug'] ?? 0) + 1;
          break;
      }
    }

    return stats;
  }
}
