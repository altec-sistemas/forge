import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:colorize/colorize.dart';

/// Log level enumeration.
enum LogLevel {
  debug(0),
  info(1),
  success(2),
  warning(3),
  error(4),
  fatal(5);

  final int severity;
  const LogLevel(this.severity);

  bool operator >=(LogLevel other) => severity >= other.severity;
}

/// Represents a log entry.
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? extra;

  LogEntry({
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
    this.extra,
  }) : timestamp = DateTime.now();
}

/// Handler for processing log entries.
abstract class LogHandler {
  /// Process a log entry.
  void handle(LogEntry entry);

  /// Flush any buffered logs.
  Future<void> flush() async {}

  /// Close the handler and release resources.
  Future<void> close() async {}
}

/// Console log handler that prints to stdout with colored formatting.
class ConsoleLogHandler extends LogHandler {
  final bool colored;
  final bool showTimestamp;
  final bool inline;

  ConsoleLogHandler({
    this.colored = true,
    this.showTimestamp = true,
    this.inline = false,
  });

  @override
  void handle(LogEntry entry) {
    final buffer = StringBuffer();

    // Timestamp
    if (showTimestamp) {
      final timestamp = _formatTimestamp(entry.timestamp);
      if (inline) {
        buffer.write('$timestamp ');
      } else {
        print(timestamp);
      }
    }

    // Level with color
    final levelStr = _formatLevel(entry.level);
    buffer.write(levelStr);

    // Tag
    final tagStr = _formatTag(entry.tag);
    buffer.write(' $tagStr');

    // Message
    buffer.write(' ${entry.message}');

    print(buffer.toString());

    // Error details
    if (entry.error != null) {
      final errorType = colored
          ? Colorize('[${entry.error.runtimeType}]').yellow().toString()
          : '[${entry.error.runtimeType}]';
      print('$errorType ${entry.error}');
    }

    // Stack trace
    if (entry.stackTrace != null) {
      _printStackTrace(entry.stackTrace!);
    }

    // Extra fields
    if (entry.extra != null && entry.extra!.isNotEmpty) {
      print(_formatExtra(entry.extra!));
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final timeStr = inline
        ? '${timestamp.toLocal()}'
        : '\n${timestamp.toLocal()}';
    return colored ? Colorize(timeStr).darkGray().toString() : timeStr;
  }

  String _formatLevel(LogLevel level) {
    final levelName = '[${level.name.toUpperCase()}]';

    if (!colored) return levelName;

    final colorized = Colorize(levelName);

    return switch (level) {
      LogLevel.debug => colorized.blue().toString(),
      LogLevel.info => colorized.cyan().toString(),
      LogLevel.success => colorized.green().bold().toString(),
      LogLevel.warning => colorized.yellow().toString(),
      LogLevel.error => colorized.red().bold().toString(),
      LogLevel.fatal => colorized.red().bold().toString(),
    };
  }

  String _formatTag(String tag) {
    final tagStr = '[$tag]';
    return colored ? Colorize(tagStr).magenta().toString() : tagStr;
  }

  String _formatExtra(Map<String, dynamic> extra) {
    final extraStr = extra.toString();
    return colored ? Colorize(extraStr).darkGray().toString() : extraStr;
  }

  void _printStackTrace(StackTrace stackTrace) {
    final trace = stackTrace.toString().replaceAll(
      '<asynchronous suspension>\n',
      '',
    );

    final formatted = colored ? Colorize(trace).darkGray().toString() : trace;
    print(formatted);
  }
}

/// File organization strategy
enum LogFileStrategy {
  /// Single file for all logs
  single,

  /// One file per tag (ex: auth.log, network.log)
  byTag,

  /// One file per date (ex: 2025-11-05.log)
  byDate,

  /// One file per tag and date (ex: auth_2025-11-05.log)
  byTagAndDate,

  /// One file per level (ex: error.log, warning.log)
  byLevel,
}

/// Date format for filenames
enum DateFormat {
  /// 2025-11-05
  date,

  /// 2025-11
  yearMonth,

  /// 2025-11-05_14-30-45
  dateTime,
}

/// File rotation strategy
enum RotationStrategy {
  /// No rotation
  none,

  /// Rotation by max size
  bySize,

  /// Daily rotation
  daily,

  /// Rotation by size OR daily
  bySizeOrDaily,
}

/// File log handler configuration
class FileLogConfig {
  final String baseDirectory;
  final LogFileStrategy strategy;
  final DateFormat dateFormat;
  final String extension;
  final RotationStrategy rotationStrategy;
  final int? maxFileSize;
  final int maxFiles;

  const FileLogConfig({
    this.baseDirectory = 'logs',
    this.strategy = LogFileStrategy.byTagAndDate,
    this.dateFormat = DateFormat.date,
    this.extension = 'log',
    this.rotationStrategy = RotationStrategy.daily,
    this.maxFileSize = 10 * 1024 * 1024, // 10 MB
    this.maxFiles = 30,
  });
}

/// File log handler that writes to a file.
class FileLogHandler extends LogHandler {
  final FileLogConfig config;
  final bool includeTimestamp;
  final Duration autoFlushInterval;

  final Map<String, StringBuffer> _buffers = {};
  final Map<String, File> _files = {};
  final Map<String, DateTime> _lastRotationCheck = {};
  Timer? _flushTimer;

  FileLogHandler({
    required this.config,
    this.includeTimestamp = true,
    this.autoFlushInterval = const Duration(seconds: 5),
  }) {
    _flushTimer = Timer.periodic(autoFlushInterval, (_) => flush());
  }

  @override
  void handle(LogEntry entry) {
    final filePath = _getFilePath(entry);
    final buffer = _buffers.putIfAbsent(filePath, () => StringBuffer());

    // Format log line
    final timestamp = includeTimestamp
        ? '${entry.timestamp.toIso8601String()} '
        : '';

    final line =
        '$timestamp[${entry.level.name.toUpperCase()}] '
        '[${entry.tag}] ${entry.message}\n';

    buffer.write(line);

    // Add error if present
    if (entry.error != null) {
      buffer.write('  Error: ${entry.error}\n');
    }

    // Add stack trace if present
    if (entry.stackTrace != null) {
      buffer.write('  Stack trace:\n');
      buffer.write(
        '  ${entry.stackTrace.toString().replaceAll('\n', '\n  ')}\n',
      );
    }

    // Add extra fields if present
    if (entry.extra != null && entry.extra!.isNotEmpty) {
      buffer.write('  Extra: ${entry.extra}\n');
    }

    // Check if rotation is needed
    _checkRotation(filePath, entry);
  }

  void _checkRotation(String filePath, LogEntry entry) {
    final now = entry.timestamp;
    final lastCheck = _lastRotationCheck[filePath];

    // Daily rotation
    if (config.rotationStrategy == RotationStrategy.daily ||
        config.rotationStrategy == RotationStrategy.bySizeOrDaily) {
      if (lastCheck != null && !_isSameDay(lastCheck, now)) {
        _rotateFile(filePath);
        _lastRotationCheck[filePath] = now;
        return;
      }
    }

    // Size rotation
    if (config.rotationStrategy == RotationStrategy.bySize ||
        config.rotationStrategy == RotationStrategy.bySizeOrDaily) {
      _checkAndRotateBySize(filePath);
    }

    _lastRotationCheck[filePath] ??= now;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getFilePath(LogEntry entry) {
    final fileName = _getFileName(entry);
    return path.join(config.baseDirectory, fileName);
  }

  String _getFileName(LogEntry entry) {
    final parts = <String>[];

    switch (config.strategy) {
      case LogFileStrategy.single:
        parts.add('app');
        break;

      case LogFileStrategy.byTag:
        parts.add(entry.tag);
        break;

      case LogFileStrategy.byDate:
        parts.add(_formatDate(entry.timestamp));
        break;

      case LogFileStrategy.byTagAndDate:
        parts.add(entry.tag);
        parts.add(_formatDate(entry.timestamp));
        break;

      case LogFileStrategy.byLevel:
        parts.add(entry.level.name);
        break;
    }

    return '${parts.join('_')}.${config.extension}';
  }

  String _formatDate(DateTime date) {
    switch (config.dateFormat) {
      case DateFormat.date:
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';

      case DateFormat.yearMonth:
        return '${date.year}-${date.month.toString().padLeft(2, '0')}';

      case DateFormat.dateTime:
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}_'
            '${date.hour.toString().padLeft(2, '0')}-'
            '${date.minute.toString().padLeft(2, '0')}-'
            '${date.second.toString().padLeft(2, '0')}';
    }
  }

  void _checkAndRotateBySize(String filePath) {
    if (config.maxFileSize == null) return;

    final file = File(filePath);
    if (!file.existsSync()) return;

    final size = file.lengthSync();
    if (size >= config.maxFileSize!) {
      _rotateFile(filePath);
    }
  }

  void _rotateFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return;

    // Flush current buffer first
    final buffer = _buffers[filePath];
    if (buffer != null && buffer.isNotEmpty) {
      try {
        file.writeAsStringSync(
          buffer.toString(),
          mode: FileMode.append,
          flush: true,
        );
        buffer.clear();
      } catch (e) {
        print('Error flushing before rotation: $e');
      }
    }

    // Generate rotated filename
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = path.extension(filePath);
    final nameWithoutExt = path.basenameWithoutExtension(filePath);
    final dir = path.dirname(filePath);
    final rotatedName = '$nameWithoutExt.$timestamp$ext';
    final rotatedPath = path.join(dir, rotatedName);

    // Rename file
    try {
      file.renameSync(rotatedPath);
    } catch (e) {
      print('Error rotating file: $e');
      return;
    }

    // Clear cache
    _files.remove(filePath);

    // Clean old files
    _cleanOldFiles(dir);
  }

  void _cleanOldFiles(String directory) {
    if (config.maxFiles <= 0) return;

    try {
      final dir = Directory(directory);
      if (!dir.existsSync()) return;

      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.${config.extension}'))
          .toList();

      files.sort((a, b) {
        try {
          return a.statSync().modified.compareTo(b.statSync().modified);
        } catch (e) {
          return 0;
        }
      });

      while (files.length > config.maxFiles) {
        try {
          files.first.deleteSync();
          files.removeAt(0);
        } catch (e) {
          print('Error deleting old log file: $e');
          break;
        }
      }
    } catch (e) {
      print('Error cleaning old files: $e');
    }
  }

  @override
  Future<void> flush() async {
    final futures = <Future>[];

    for (final entry in _buffers.entries) {
      if (entry.value.isEmpty) continue;
      futures.add(_flushBuffer(entry.key, entry.value));
    }

    await Future.wait(futures);
  }

  Future<void> _flushBuffer(String filePath, StringBuffer buffer) async {
    try {
      final file = await _getOrCreateFile(filePath);
      await file.writeAsString(
        buffer.toString(),
        mode: FileMode.append,
        flush: true,
      );
      buffer.clear();
    } catch (e) {
      print('Error flushing file handler ($filePath): $e');
    }
  }

  Future<File> _getOrCreateFile(String filePath) async {
    if (_files.containsKey(filePath)) {
      return _files[filePath]!;
    }

    final file = File(filePath);

    final directory = file.parent;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    if (!await file.exists()) {
      await file.create(recursive: true);
    }

    _files[filePath] = file;
    return file;
  }

  @override
  Future<void> close() async {
    _flushTimer?.cancel();
    await flush();
    _buffers.clear();
    _files.clear();
    _lastRotationCheck.clear();
  }
}

/// Filter function type
typedef LogFilter = bool Function(LogEntry entry);

/// Global logger configuration
class _LoggerConfig {
  LogLevel globalMinLevel = LogLevel.debug;
  final List<LogHandler> globalHandlers = [];
  final Map<String, LogLevel> tagLevels = {};
  final Map<String, List<LogHandler>> tagHandlers = {};
  final Map<String, LogFilter> tagFilters = {};
}

/// Global logger configuration instance
final _config = _LoggerConfig();

/// Logger instance for a specific tag
class Logger {
  final String tag;

  const Logger(this.tag);

  /// Internal log method
  void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
    bool force = false,
  }) {
    // Get tag-specific level or use global
    final minLevel = _config.tagLevels[tag] ?? _config.globalMinLevel;

    // Check level
    if (!force && level.severity < minLevel.severity) {
      return;
    }

    // Create entry
    final entry = LogEntry(
      level: level,
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );

    // Apply tag filter
    final filter = _config.tagFilters[tag];
    if (filter != null && !filter(entry)) {
      return;
    }

    // Process with tag-specific handlers
    final tagHandlers = _config.tagHandlers[tag];
    if (tagHandlers != null) {
      for (final handler in tagHandlers) {
        try {
          handler.handle(entry);
        } catch (e) {
          print('Error in tag handler: $e');
        }
      }
    }

    // Process with global handlers
    for (final handler in _config.globalHandlers) {
      try {
        handler.handle(entry);
      } catch (e) {
        print('Error in global handler: $e');
      }
    }
  }

  /// Log debug message
  void debug(
    String message, {
    Map<String, dynamic>? extra,
    bool force = false,
  }) {
    _log(LogLevel.debug, message, extra: extra, force: force);
  }

  /// Log info message
  void info(
    String message, {
    Map<String, dynamic>? extra,
    bool force = false,
  }) {
    _log(LogLevel.info, message, extra: extra, force: force);
  }

  /// Log success message
  void success(
    String message, {
    Map<String, dynamic>? extra,
    bool force = false,
  }) {
    _log(LogLevel.success, message, extra: extra, force: force);
  }

  /// Log warning message
  void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
    bool force = false,
  }) {
    _log(
      LogLevel.warning,
      message,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
      force: force,
    );
  }

  /// Log error message
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
    bool force = false,
  }) {
    _log(
      LogLevel.error,
      message,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
      force: force,
    );
  }

  /// Log fatal message
  void fatal(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
    bool force = false,
  }) {
    _log(
      LogLevel.fatal,
      message,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
      force: force,
    );
  }

  // Static configuration methods

  /// Configure global minimum log level
  static void setMinLevel(LogLevel level) {
    _config.globalMinLevel = level;
  }

  /// Get current global minimum level
  static LogLevel get minLevel => _config.globalMinLevel;

  /// Add a global handler (applies to all tags)
  static void addHandler(LogHandler handler) {
    _config.globalHandlers.add(handler);
  }

  /// Remove a global handler
  static void removeHandler(LogHandler handler) {
    _config.globalHandlers.remove(handler);
  }

  /// Remove all global handlers
  static void clearHandlers() {
    _config.globalHandlers.clear();
  }

  /// Get all global handlers
  static List<LogHandler> get handlers =>
      List.unmodifiable(_config.globalHandlers);

  /// Set minimum level for a specific tag
  static void setLevelForTag(String tag, LogLevel level) {
    _config.tagLevels[tag] = level;
  }

  /// Get minimum level for a specific tag
  static LogLevel? getLevelForTag(String tag) => _config.tagLevels[tag];

  /// Remove level configuration for a tag
  static void removeLevelForTag(String tag) {
    _config.tagLevels.remove(tag);
  }

  /// Add a handler to a specific tag
  static void addHandlerForTag(String tag, LogHandler handler) {
    _config.tagHandlers.putIfAbsent(tag, () => []).add(handler);
  }

  /// Remove a handler from a specific tag
  static void removeHandlerForTag(String tag, LogHandler handler) {
    _config.tagHandlers[tag]?.remove(handler);
  }

  /// Remove all handlers for a specific tag
  static void clearHandlersForTag(String tag) {
    _config.tagHandlers[tag]?.clear();
  }

  /// Get all handlers for a specific tag
  static List<LogHandler>? getHandlersForTag(String tag) {
    final handlers = _config.tagHandlers[tag];
    return handlers != null ? List.unmodifiable(handlers) : null;
  }

  /// Set filter for a specific tag
  static void setFilterForTag(String tag, LogFilter filter) {
    _config.tagFilters[tag] = filter;
  }

  /// Get filter for a specific tag
  static LogFilter? getFilterForTag(String tag) => _config.tagFilters[tag];

  /// Remove filter for a tag
  static void removeFilterForTag(String tag) {
    _config.tagFilters.remove(tag);
  }

  /// Remove all configurations for a tag
  static void removeTag(String tag) {
    _config.tagLevels.remove(tag);
    _config.tagHandlers.remove(tag);
    _config.tagFilters.remove(tag);
  }

  /// Get all configured tags
  static List<String> get configuredTags {
    return {
      ..._config.tagLevels.keys,
      ..._config.tagHandlers.keys,
      ..._config.tagFilters.keys,
    }.toList();
  }

  /// Flush all handlers
  static Future<void> flush() async {
    final futures = <Future>[];

    for (final handler in _config.globalHandlers) {
      futures.add(handler.flush());
    }

    for (final handlers in _config.tagHandlers.values) {
      for (final handler in handlers) {
        futures.add(handler.flush());
      }
    }

    await Future.wait(futures);
  }

  /// Close all handlers and clear configurations
  static Future<void> close() async {
    final futures = <Future>[];

    for (final handler in _config.globalHandlers) {
      futures.add(handler.close());
    }

    for (final handlers in _config.tagHandlers.values) {
      for (final handler in handlers) {
        futures.add(handler.close());
      }
    }

    await Future.wait(futures);

    _config.globalHandlers.clear();
    _config.tagLevels.clear();
    _config.tagHandlers.clear();
    _config.tagFilters.clear();
  }
}
