import 'dart:async';

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
  final String message;
  final String? context;
  final Object? error;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? extra;

  LogEntry({
    required this.level,
    required this.message,
    this.context,
    this.error,
    this.stackTrace,
    this.extra,
  }) : timestamp = DateTime.now();
}

/// Base logging interface.
abstract class Logger {
  /// Minimum log level to process.
  LogLevel get minLevel;

  /// Sets the minimum log level.
  set minLevel(LogLevel level);

  /// Logs a message at the specified level.
  void log(
    LogLevel level,
    String message, {
    String? context,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  });

  /// Logs a debug message.
  void debug(String message, {String? context, Map<String, dynamic>? extra}) {
    log(LogLevel.debug, message, context: context, extra: extra);
  }

  /// Logs an info message.
  void info(String message, {String? context, Map<String, dynamic>? extra}) {
    log(LogLevel.info, message, context: context, extra: extra);
  }

  /// Logs a success message.
  void success(String message, {String? context, Map<String, dynamic>? extra}) {
    log(LogLevel.success, message, context: context, extra: extra);
  }

  /// Logs a warning message.
  void warning(
    String message, {
    String? context,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    log(
      LogLevel.warning,
      message,
      context: context,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  /// Logs an error message.
  void error(
    String message, {
    String? context,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    log(
      LogLevel.error,
      message,
      context: context,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  /// Logs a fatal message.
  void fatal(
    String message, {
    String? context,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    log(
      LogLevel.fatal,
      message,
      context: context,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  /// Creates a child logger with a specific context.
  Logger child(String context);
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

/// Default logger implementation with multiple handlers.
class DefaultLogger extends Logger {
  final List<LogHandler> _handlers;
  final String? _context;

  @override
  LogLevel minLevel;

  DefaultLogger({
    this.minLevel = LogLevel.info,
    List<LogHandler>? handlers,
    String? context,
  }) : _handlers = handlers ?? [],
       _context = context;

  /// Adds a log handler.
  void addHandler(LogHandler handler) {
    _handlers.add(handler);
  }

  /// Removes a log handler.
  void removeHandler(LogHandler handler) {
    _handlers.remove(handler);
  }

  @override
  void log(
    LogLevel level,
    String message, {
    String? context,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    if (level.severity < minLevel.severity) return;

    final entry = LogEntry(
      level: level,
      message: message,
      context: context ?? _context,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );

    for (final handler in _handlers) {
      try {
        handler.handle(entry);
      } catch (e) {
        // Avoid infinite loops if handler throws
        print('Error in log handler: $e');
      }
    }
  }

  @override
  Logger child(String context) {
    return DefaultLogger(
      minLevel: minLevel,
      handlers: _handlers,
      context: _context != null ? '$_context.$context' : context,
    );
  }

  /// Flush all handlers.
  Future<void> flush() async {
    await Future.wait(_handlers.map((h) => h.flush()));
  }

  /// Close all handlers.
  Future<void> close() async {
    await Future.wait(_handlers.map((h) => h.close()));
  }
}

/// Console log handler that prints to stdout with colored formatting.
class ConsoleLogHandler extends LogHandler {
  final bool colored;
  final bool showTimestamp;
  final bool showContext;

  ConsoleLogHandler({
    this.colored = true,
    this.showTimestamp = true,
    this.showContext = true,
  });

  @override
  void handle(LogEntry entry) {
    // Timestamp
    if (showTimestamp) {
      final timestamp = _formatTimestamp(entry.timestamp);
      print(timestamp);
    }

    // Build main log line
    final buffer = StringBuffer();

    // Level with color
    final levelStr = _formatLevel(entry.level);
    buffer.write(levelStr);

    // Context
    if (showContext && entry.context != null) {
      final contextStr = _formatContext(entry.context!);
      buffer.write(' $contextStr');
    }

    // Message
    buffer.write(' ${entry.message}');

    print(buffer.toString());

    // Error details
    if (entry.error != null) {
      final errorType = colored
          ? '\x1B[33m[${entry.error.runtimeType}]\x1B[0m'
          : '[${entry.error.runtimeType}]';
      print('$errorType ${entry.error}');
    }

    // Stack trace (simplified)
    if (entry.stackTrace != null) {
      _printStackTrace(entry.stackTrace!);
    }

    // Extra fields
    if (entry.extra != null && entry.extra!.isNotEmpty) {
      print(_formatExtra(entry.extra!));
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final timeStr = '\n${timestamp.toLocal()}';
    return colored ? '\x1B[90m$timeStr\x1B[0m' : timeStr; // Dark gray
  }

  String _formatLevel(LogLevel level) {
    final levelName = '[${level.name.toUpperCase()}]';

    if (!colored) return levelName;

    final colorCode = switch (level) {
      LogLevel.debug => '\x1B[34m', // Blue
      LogLevel.info => '\x1B[32m', // Green
      LogLevel.success => '\x1B[32m\x1B[1m', // Green Bold (destaque)
      LogLevel.warning => '\x1B[33m', // Yellow
      LogLevel.error => '\x1B[31m\x1B[1m', // Red Bold
      LogLevel.fatal => '\x1B[31m\x1B[1m', // Red Bold
    };

    return '$colorCode$levelName\x1B[0m';
  }

  String _formatContext(String context) {
    final contextStr = '[$context]';
    return colored ? '\x1B[36m$contextStr\x1B[0m' : contextStr; // Cyan
  }

  String _formatExtra(Map<String, dynamic> extra) {
    final extraStr = extra.toString();
    return colored ? '\x1B[90m$extraStr\x1B[0m' : extraStr; // Dark gray
  }

  void _printStackTrace(StackTrace stackTrace) {
    // Remove <asynchronous suspension> lines and apply dark gray color
    final trace = stackTrace.toString().replaceAll(
      '<asynchronous suspension>\n',
      '',
    );

    final formatted = colored ? '\x1B[90m$trace\x1B[0m' : trace;
    print(formatted);
  }
}

/// Null logger that discards all logs.
class NullLogger extends Logger {
  @override
  LogLevel minLevel = LogLevel.fatal;

  @override
  void log(
    LogLevel level,
    String message, {
    String? context,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {}

  @override
  Logger child(String context) => this;
}
