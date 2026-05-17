import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/usb_debug_logger.dart';

/// USB Debug Log Viewer Screen
/// Displays real-time USB printer connection and operation logs
class UsbDebugLogScreen extends StatefulWidget {
  const UsbDebugLogScreen({super.key});

  @override
  State<UsbDebugLogScreen> createState() => _UsbDebugLogScreenState();
}

class _UsbDebugLogScreenState extends State<UsbDebugLogScreen> {
  final UsbDebugLogger _logger = UsbDebugLogger();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  LogLevel? _filterLevel;

  @override
  void initState() {
    super.initState();
    _logger.addListener(_onLogsUpdated);
  }

  @override
  void dispose() {
    _logger.removeListener(_onLogsUpdated);
    _searchController.dispose();
    super.dispose();
  }

  void _onLogsUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  List<LogEntry> _getFilteredLogs() {
    var logs = _logger.logs;

    // Filter by level
    if (_filterLevel != null) {
      logs = logs.where((log) => log.level == _filterLevel).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      logs = logs.where((log) => log.message.toLowerCase().contains(query)).toList();
    }

    return logs;
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.success:
        return Colors.green;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.debug:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _getFilteredLogs();
    final stats = _logger.getStatistics();

    return Scaffold(
      appBar: AppBar(
        title: const Text('USB Debug Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear Logs',
            onPressed: _confirmClearLogs,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Logs',
            onPressed: _shareLogs,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Export Logs',
            onPressed: _exportLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Bar
          _buildStatisticsBar(stats),

          // Search and Filter Bar
          _buildSearchBar(),

          // Logs List
          Expanded(
            child: filteredLogs.isEmpty
                ? _buildEmptyState()
                : _buildLogsList(filteredLogs),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsBar(Map<String, int> stats) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[200],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatChip('Total', stats['total']!, Colors.grey),
          _buildStatChip('Info', stats['info']!, Colors.blue),
          _buildStatChip('Success', stats['success']!, Colors.green),
          _buildStatChip('Warning', stats['warning']!, Colors.orange),
          _buildStatChip('Error', stats['error']!, Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          // Toggle filter
          if (_filterLevel != null && _filterLevel.toString().contains(label.toLowerCase())) {
            _filterLevel = null;
          } else {
            switch (label.toLowerCase()) {
              case 'info':
                _filterLevel = LogLevel.info;
                break;
              case 'success':
                _filterLevel = LogLevel.success;
                break;
              case 'warning':
                _filterLevel = LogLevel.warning;
                break;
              case 'error':
                _filterLevel = LogLevel.error;
                break;
              case 'debug':
                _filterLevel = LogLevel.debug;
                break;
              default:
                _filterLevel = null;
            }
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _filterLevel != null && _filterLevel.toString().contains(label.toLowerCase())
              ? color.withOpacity(0.3)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search logs...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty || _filterLevel != null
                ? Icons.search_off
                : Icons.library_books,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _filterLevel != null
                ? 'No logs match your filters'
                : 'No logs yet',
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          if (_searchQuery.isEmpty && _filterLevel == null) ...[
            const SizedBox(height: 8),
            const Text(
              'Logs will appear here when you use USB printer features',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogsList(List<LogEntry> logs) {
    return ListView.builder(
      reverse: false, // Latest at top
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return _buildLogEntry(log);
      },
    );
  }

  Widget _buildLogEntry(LogEntry log) {
    final color = _getLevelColor(log.level);

    return InkWell(
      onLongPress: () => _copyLogToClipboard(log),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Time + Emoji + Level
            Row(
              children: [
                Text(
                  log.emoji,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  log.formattedTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    log.level.toString().split('.').last.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Message
            Text(
              log.message,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
              ),
            ),

            // Stack trace (if present)
            if (log.stackTrace != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  log.stackTrace!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _copyLogToClipboard(LogEntry log) {
    Clipboard.setData(ClipboardData(text: log.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Log copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _confirmClearLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Logs?'),
        content: const Text('This will delete all USB debug logs. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _logger.clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs cleared')),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _shareLogs() async {
    final logsText = _logger.getLogsAsText();
    await Share.share(
      logsText,
      subject: 'USB Printer Debug Logs',
    );
  }

  void _exportLogs() async {
    final file = await _logger.exportLogs();
    if (file != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logs exported to:\n${file.path}'),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to export logs'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
