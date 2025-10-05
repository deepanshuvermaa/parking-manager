import 'package:flutter/material.dart';

class DebugLogger {
  static final List<String> _logs = [];
  static final ValueNotifier<List<String>> logsNotifier = ValueNotifier([]);

  static void log(String message, {String? error, StackTrace? stackTrace}) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    String logEntry = '[$timestamp] $message';

    if (error != null) {
      logEntry += '\nERROR: $error';
    }

    if (stackTrace != null) {
      logEntry += '\nSTACK: ${stackTrace.toString().split('\n').take(3).join('\n')}';
    }

    print(logEntry); // Console log
    _logs.insert(0, logEntry);
    if (_logs.length > 50) _logs.removeLast(); // Keep last 50 logs
    logsNotifier.value = List.from(_logs);
  }

  static void clear() {
    _logs.clear();
    logsNotifier.value = [];
  }
}

class DebugOverlay extends StatelessWidget {
  final Widget child;

  const DebugOverlay({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          bottom: 50,
          right: 10,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.red,
            child: const Icon(Icons.bug_report, size: 20),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const DebugLogDialog(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class DebugLogDialog extends StatelessWidget {
  const DebugLogDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Debug Logs'),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              DebugLogger.clear();
            },
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ValueListenableBuilder<List<String>>(
          valueListenable: DebugLogger.logsNotifier,
          builder: (context, logs, _) {
            if (logs.isEmpty) {
              return const Center(child: Text('No logs yet'));
            }
            return ListView.builder(
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                final isError = log.contains('ERROR');
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isError ? Colors.red.shade50 : Colors.grey.shade100,
                    border: Border.all(
                      color: isError ? Colors.red : Colors.grey,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    log,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: isError ? Colors.red.shade900 : Colors.black,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}