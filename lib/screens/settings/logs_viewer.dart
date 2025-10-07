import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/logging_service.dart';

class LogsViewerScreen extends StatefulWidget {
  const LogsViewerScreen({super.key});

  @override
  State<LogsViewerScreen> createState() => _LogsViewerScreenState();
}

class _LogsViewerScreenState extends State<LogsViewerScreen> {
  final LoggingService _loggingService = LoggingService();
  List<String> _logs = [];
  Map<String, dynamic> _logStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    
    try {
      final logs = _loggingService.getMemoryLogs();
      final stats = await _loggingService.getLogStats();
      
      setState(() {
        _logs = logs;
        _logStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _logs = ['Error loading logs: $e'];
        _isLoading = false;
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes > 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes > 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '$bytes bytes';
    }
  }

  Future<void> _exportLogs() async {
    try {
      final logs = await _loggingService.exportLogs();
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/doudou_logs_export.txt');
      await file.writeAsString(logs);
      
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Logs Exported'),
            content: Text('Logs saved to:\n${file.path}\n\nYou can find this file in your Documents folder and share it manually.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('Copy Path'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: file.path));
                  Navigator.pop(context);
                },
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Export Failed'),
            content: Text('Failed to export logs: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _copyLogs() async {
    try {
      final logs = await _loggingService.exportLogs();
      await Clipboard.setData(ClipboardData(text: logs));
      
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Copied'),
            content: const Text('Logs copied to clipboard'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Copy Failed'),
            content: Text('Failed to copy logs: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _clearLogs() async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Clear Logs'),
        content: const Text('Are you sure you want to clear all logs? This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Clear'),
            onPressed: () => Navigator.pop(context, true),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await _loggingService.clearLogs();
      await _loadLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFF000000),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back, color: CupertinoColors.activeBlue),
          onPressed: () => Navigator.pop(context),
        ),
        middle: const Text(
          'Application Logs',
          style: TextStyle(color: Color(0xFFFFFFFF)),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _loadLogs,
          child: const Icon(CupertinoIcons.refresh, color: CupertinoColors.activeBlue),
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : Column(
                children: [
                  // Stats section
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2C2C2E)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Log Statistics',
                          style: TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Log Files:',
                              style: TextStyle(color: CupertinoColors.systemGrey),
                            ),
                            Text(
                              '${_logStats['file_count'] ?? 0}',
                              style: const TextStyle(color: Color(0xFFFFFFFF)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Size:',
                              style: TextStyle(color: CupertinoColors.systemGrey),
                            ),
                            Text(
                              _formatSize(_logStats['total_size'] ?? 0),
                              style: const TextStyle(color: Color(0xFFFFFFFF)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Memory Logs:',
                              style: TextStyle(color: CupertinoColors.systemGrey),
                            ),
                            Text(
                              '${_logStats['memory_logs'] ?? 0}',
                              style: const TextStyle(color: Color(0xFFFFFFFF)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            color: CupertinoColors.activeBlue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            onPressed: _exportLogs,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.share, size: 18),
                                SizedBox(width: 8),
                                Text('Export'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CupertinoButton(
                            color: const Color(0xFF1C1C1E),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            onPressed: _copyLogs,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.doc_on_clipboard, size: 18),
                                SizedBox(width: 8),
                                Text('Copy'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        CupertinoButton(
                          color: CupertinoColors.destructiveRed,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          onPressed: _clearLogs,
                          child: const Icon(CupertinoIcons.trash, size: 18),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Logs list
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2C2C2E)),
                      ),
                      child: _logs.isEmpty
                          ? const Center(
                              child: Text(
                                'No logs available',
                                style: TextStyle(color: CupertinoColors.systemGrey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _logs.length,
                              itemBuilder: (context, index) {
                                final log = _logs[_logs.length - 1 - index]; // Reverse order (newest first)
                                Color logColor = const Color(0xFFFFFFFF);
                                
                                if (log.contains('[ERROR]')) {
                                  logColor = CupertinoColors.destructiveRed;
                                } else if (log.contains('[WARN]')) {
                                  logColor = CupertinoColors.systemOrange;
                                } else if (log.contains('[INFO]')) {
                                  logColor = CupertinoColors.activeBlue;
                                } else if (log.contains('[DEBUG]')) {
                                  logColor = CupertinoColors.systemGrey;
                                }
                                
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    log,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: logColor,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                ],
              ),
      ),
    );
  }
}
