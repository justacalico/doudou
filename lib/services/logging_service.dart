import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing application logs that can be shared with developers
class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  File? _logFile;
  final List<String> _memoryLogs = [];
  static const int _maxMemoryLogs = 1000;
  static const int _maxLogFileSize = 5 * 1024 * 1024; // 5MB
  bool _initialized = false;
  bool _loggingEnabled = false;

  /// Format DateTime to string
  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// Format DateTime to timestamp string
  String _formatTimestamp(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}_'
        '${dt.hour.toString().padLeft(2, '0')}-${dt.minute.toString().padLeft(2, '0')}-${dt.second.toString().padLeft(2, '0')}';
  }

  /// Format DateTime to full timestamp with milliseconds
  String _formatFullTimestamp(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}.'
        '${dt.millisecond.toString().padLeft(3, '0')}';
  }

  /// Initialize the logging service
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Load logging enabled setting
      final prefs = await SharedPreferences.getInstance();
      _loggingEnabled = prefs.getBool('logging_enabled') ?? false;
      
      // Only initialize file logging on non-web platforms
      if (!kIsWeb) {
        final directory = await getApplicationDocumentsDirectory();
        final logDir = Directory('${directory.path}/logs');
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }
        
        final now = DateTime.now();
        final dateStr = _formatDate(now);
        _logFile = File('${logDir.path}/doudou_$dateStr.log');
        
        // Rotate log if too large
        if (await _logFile!.exists()) {
          final fileSize = await _logFile!.length();
          if (fileSize > _maxLogFileSize) {
            await _rotateLog();
          }
        }
      }
      
      _initialized = true;
      if (_loggingEnabled) {
        log('INFO', 'Logging service initialized (logging enabled)${kIsWeb ? ' - web mode' : ''}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize logging service: $e');
      }
      // Mark as initialized even if file logging failed (web compatibility)
      _initialized = true;
    }
  }

  /// Update logging enabled state
  Future<void> setLoggingEnabled(bool enabled) async {
    _loggingEnabled = enabled;
    if (enabled && _initialized) {
      log('INFO', 'Logging enabled');
    }
  }

  /// Check if logging is enabled
  bool get isLoggingEnabled => _loggingEnabled;

  /// Rotate the log file when it gets too large
  Future<void> _rotateLog() async {
    try {
      // Only rotate logs on non-web platforms
      if (kIsWeb || _logFile == null || !await _logFile!.exists()) return;
      
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');
      final now = DateTime.now();
      final timestamp = _formatTimestamp(now);
      final archivePath = '${logDir.path}/doudou_$timestamp.old.log';
      
      await _logFile!.rename(archivePath);
      
      final dateStr = _formatDate(now);
      _logFile = File('${logDir.path}/doudou_$dateStr.log');
      
      // Clean up old logs (keep only last 5)
      await _cleanOldLogs(logDir);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to rotate log: $e');
      }
    }
  }

  /// Clean up old log files, keeping only the most recent ones
  Future<void> _cleanOldLogs(Directory logDir) async {
    try {
      final files = logDir.listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.log') || f.path.endsWith('.old.log'))
          .toList();
      
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      
      // Keep only the 5 most recent log files
      if (files.length > 5) {
        for (var i = 5; i < files.length; i++) {
          await files[i].delete();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to clean old logs: $e');
      }
    }
  }

  /// Log a message with a specific level
  void log(String level, String message, [String? component]) {
    // Skip logging if not enabled
    if (!_loggingEnabled) return;
    
    final now = DateTime.now();
    final timestamp = _formatFullTimestamp(now);
    final componentStr = component != null ? '[$component] ' : '';
    final logEntry = '$timestamp [$level] $componentStr$message';
    
    // Add to memory logs
    _memoryLogs.add(logEntry);
    if (_memoryLogs.length > _maxMemoryLogs) {
      _memoryLogs.removeAt(0);
    }
    
    // Write to file
    _writeToFile(logEntry);
    
    // Also print in debug mode
    if (kDebugMode) {
      print(logEntry);
    }
  }

  /// Write log entry to file
  Future<void> _writeToFile(String logEntry) async {
    try {
      if (_logFile != null) {
        await _logFile!.writeAsString('$logEntry\n', mode: FileMode.append);
        
        // Check if we need to rotate
        final fileSize = await _logFile!.length();
        if (fileSize > _maxLogFileSize) {
          await _rotateLog();
        }
      }
    } catch (e) {
      // Fail silently to not disrupt app functionality
      if (kDebugMode) {
        print('Failed to write log: $e');
      }
    }
  }

  /// Convenience methods for different log levels
  void info(String message, [String? component]) => log('INFO', message, component);
  void warning(String message, [String? component]) => log('WARN', message, component);
  void error(String message, [String? component]) => log('ERROR', message, component);
  void debug(String message, [String? component]) => log('DEBUG', message, component);

  /// Get all logs from memory
  List<String> getMemoryLogs() {
    return List.unmodifiable(_memoryLogs);
  }

  /// Get the current log file path
  String? getLogFilePath() {
    return _logFile?.path;
  }

  /// Get all log files
  Future<List<File>> getAllLogFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');
      
      if (!await logDir.exists()) {
        return [];
      }
      
      final files = logDir.listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.log') || f.path.endsWith('.old.log'))
          .toList();
      
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      
      return files;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get log files: $e');
      }
      return [];
    }
  }

  /// Read log file contents
  Future<String> readLogFile(File file) async {
    try {
      return await file.readAsString();
    } catch (e) {
      return 'Failed to read log file: $e';
    }
  }

  /// Export all logs as a single string for sharing
  Future<String> exportLogs() async {
    final buffer = StringBuffer();
    buffer.writeln('=== Doudou Application Logs ===');
    buffer.writeln('Exported: ${DateTime.now()}');
    buffer.writeln('App Version: [Will be filled by settings screen]');
    buffer.writeln('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    buffer.writeln('');
    
    final files = await getAllLogFiles();
    
    for (final file in files) {
      buffer.writeln('--- Log file: ${file.path.split('/').last} ---');
      buffer.writeln(await readLogFile(file));
      buffer.writeln('');
    }
    
    if (buffer.isEmpty) {
      buffer.writeln('No logs available');
    }
    
    return buffer.toString();
  }

  /// Clear all logs
  Future<void> clearLogs() async {
    try {
      _memoryLogs.clear();
      
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');
      
      if (await logDir.exists()) {
        final files = logDir.listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.log') || f.path.endsWith('.old.log'))
            .toList();
        
        for (final file in files) {
          await file.delete();
        }
      }
      
      // Reinitialize to create a fresh log file
      _initialized = false;
      await initialize();
      
      info('Logs cleared by user');
    } catch (e) {
      if (kDebugMode) {
        print('Failed to clear logs: $e');
      }
    }
  }

  /// Get log statistics
  Future<Map<String, dynamic>> getLogStats() async {
    try {
      final files = await getAllLogFiles();
      int totalSize = 0;
      
      for (final file in files) {
        totalSize += await file.length();
      }
      
      return {
        'file_count': files.length,
        'total_size': totalSize,
        'memory_logs': _memoryLogs.length,
        'current_log_file': _logFile?.path.split('/').last,
      };
    } catch (e) {
      return {
        'file_count': 0,
        'total_size': 0,
        'memory_logs': _memoryLogs.length,
        'error': e.toString(),
      };
    }
  }
}
