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
  final String channelName;
  final String? context;
  final Object? error;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? extra;

  LogEntry({
    required this.level,
    required this.message,
    required this.channelName,
    this.context,
    this.error,
    this.stackTrace,
    this.extra,
  }) : timestamp = DateTime.now();
}

/// Handler for processing log entries.
abstract class LogHandler {
  /// Minimum level this handler will process
  LogLevel minLevel;

  LogHandler({this.minLevel = LogLevel.debug});

  /// Check if this handler should process the given level
  bool shouldHandle(LogLevel level) => level.severity >= minLevel.severity;

  /// Process a log entry.
  void handle(LogEntry entry);

  /// Flush any buffered logs.
  Future<void> flush() async {}

  /// Close the handler and release resources.
  Future<void> close() async {}
}

/// Base logging interface.
abstract class Logger {
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
  void debug(String message, {String? context, Map<String, dynamic>? extra});

  /// Logs an info message.
  void info(String message, {String? context, Map<String, dynamic>? extra});

  /// Logs a success message.
  void success(String message, {String? context, Map<String, dynamic>? extra});

  /// Logs a warning message.
  void warning(
    String message, {
    String? context,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  });

  /// Logs an error message.
  void error(
    String message, {
    String? context,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  });

  /// Logs a fatal message.
  void fatal(
    String message, {
    String? context,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  });

  /// Creates a child logger with a specific context.
  Logger child(String context);
}

/// Represents a logging channel (similar to Monolog's Logger).
/// Each channel has its own name and set of handlers.
class LogChannel implements Logger {
  final String name;
  final List<LogHandler> _handlers = [];
  final String? _context;

  LogChannel(this.name, {String? context}) : _context = context;

  /// Add a handler to this channel.
  void pushHandler(LogHandler handler) {
    _handlers.add(handler);
  }

  /// Remove a handler from this channel.
  void popHandler() {
    if (_handlers.isNotEmpty) {
      _handlers.removeLast();
    }
  }

  /// Get all handlers.
  List<LogHandler> get handlers => List.unmodifiable(_handlers);

  @override
  void log(
    LogLevel level,
    String message, {
    String? context,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    final entry = LogEntry(
      level: level,
      message: message,
      channelName: name,
      context: context ?? _context,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );

    for (final handler in _handlers) {
      try {
        if (handler.shouldHandle(level)) {
          handler.handle(entry);
        }
      } catch (e) {
        // Avoid infinite loops if handler throws
        print('Error in log handler: $e');
      }
    }
  }

  @override
  void debug(String message, {String? context, Map<String, dynamic>? extra}) {
    log(LogLevel.debug, message, context: context, extra: extra);
  }

  @override
  void info(String message, {String? context, Map<String, dynamic>? extra}) {
    log(LogLevel.info, message, context: context, extra: extra);
  }

  @override
  void success(String message, {String? context, Map<String, dynamic>? extra}) {
    log(LogLevel.success, message, context: context, extra: extra);
  }

  @override
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

  @override
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

  @override
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

  @override
  LogChannel child(String context) {
    final childChannel = LogChannel(
      name,
      context: _context != null ? '$_context.$context' : context,
    );

    // Share the same handlers
    for (final handler in _handlers) {
      childChannel.pushHandler(handler);
    }

    return childChannel;
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

/// Configuration for a predefined channel.
class ChannelConfig {
  final String name;
  final List<LogHandler> handlers;

  ChannelConfig({
    required this.name,
    List<LogHandler>? handlers,
  }) : handlers = handlers ?? [];

  /// Add a handler to this configuration.
  ChannelConfig withHandler(LogHandler handler) {
    handlers.add(handler);
    return this;
  }
}

/// Main LoggerManager class that manages multiple channels (similar to Monolog).
class LoggerManager implements Logger {
  final Map<String, LogChannel> _channels = {};
  final Map<String, ChannelConfig> _channelConfigs = {};
  final String _defaultChannelName;

  LoggerManager({
    String defaultChannel = 'app',
    List<ChannelConfig>? channels,
  }) : _defaultChannelName = defaultChannel {
    // Register predefined channels
    if (channels != null) {
      for (final config in channels) {
        _channelConfigs[config.name] = config;
      }
    }

    // Create default channel
    _getOrCreateChannel(defaultChannel);
  }

  /// Internal method to get or create a channel with configuration.
  LogChannel _getOrCreateChannel(String name) {
    if (_channels.containsKey(name)) {
      return _channels[name]!;
    }

    final channel = LogChannel(name);

    // Apply predefined configuration if exists
    if (_channelConfigs.containsKey(name)) {
      final config = _channelConfigs[name]!;
      for (final handler in config.handlers) {
        channel.pushHandler(handler);
      }
    }

    _channels[name] = channel;
    return channel;
  }

  /// Get or create a channel by name.
  LogChannel channel(String name) {
    return _getOrCreateChannel(name);
  }

  /// Get the default channel.
  LogChannel get defaultChannel => channel(_defaultChannelName);

  /// Check if a channel exists.
  bool hasChannel(String name) => _channels.containsKey(name);

  /// Get all channel names.
  List<String> get channelNames => _channels.keys.toList();

  /// Get all configured (predefined) channel names.
  List<String> get configuredChannelNames => _channelConfigs.keys.toList();

  /// Remove a channel.
  void removeChannel(String name) {
    _channels.remove(name);
  }

  /// Register a new channel configuration (can be used after LoggerManager creation).
  void registerChannelConfig(ChannelConfig config) {
    _channelConfigs[config.name] = config;

    // If channel already exists, apply handlers
    if (_channels.containsKey(config.name)) {
      final channel = _channels[config.name]!;
      for (final handler in config.handlers) {
        channel.pushHandler(handler);
      }
    }
  }

  // Convenience methods that delegate to default channel and implement Logger interface

  @override
  void log(
    LogLevel level,
    String message, {
    String? context,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    defaultChannel.log(
      level,
      message,
      context: context,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  @override
  void debug(String message, {String? context, Map<String, dynamic>? extra}) {
    defaultChannel.debug(message, context: context, extra: extra);
  }

  @override
  void info(String message, {String? context, Map<String, dynamic>? extra}) {
    defaultChannel.info(message, context: context, extra: extra);
  }

  @override
  void success(String message, {String? context, Map<String, dynamic>? extra}) {
    defaultChannel.success(message, context: context, extra: extra);
  }

  @override
  void warning(
    String message, {
    String? context,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    defaultChannel.warning(
      message,
      context: context,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  @override
  void error(
    String message, {
    String? context,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    defaultChannel.error(
      message,
      context: context,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  @override
  void fatal(
    String message, {
    String? context,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    defaultChannel.fatal(
      message,
      context: context,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  @override
  Logger child(String context) {
    return defaultChannel.child(context);
  }

  /// Flush all channels.
  Future<void> flush() async {
    await Future.wait(_channels.values.map((c) => c.flush()));
  }

  /// Close all channels.
  Future<void> close() async {
    await Future.wait(_channels.values.map((c) => c.close()));
  }
}

/// Console log handler that prints to stdout with colored formatting.
class ConsoleLogHandler extends LogHandler {
  final bool colored;
  final bool showTimestamp;
  final bool showContext;
  final bool showChannel;

  ConsoleLogHandler({
    super.minLevel,
    this.colored = true,
    this.showTimestamp = true,
    this.showContext = true,
    this.showChannel = true,
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

    // Channel
    if (showChannel) {
      final channelStr = _formatChannel(entry.channelName);
      buffer.write(' $channelStr');
    }

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
      LogLevel.success => '\x1B[32m\x1B[1m', // Green Bold
      LogLevel.warning => '\x1B[33m', // Yellow
      LogLevel.error => '\x1B[31m\x1B[1m', // Red Bold
      LogLevel.fatal => '\x1B[31m\x1B[1m', // Red Bold
    };

    return '$colorCode$levelName\x1B[0m';
  }

  String _formatChannel(String channel) {
    final channelStr = '[$channel]';
    return colored ? '\x1B[35m$channelStr\x1B[0m' : channelStr; // Magenta
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
    final trace = stackTrace.toString().replaceAll(
      '<asynchronous suspension>\n',
      '',
    );

    final formatted = colored ? '\x1B[90m$trace\x1B[0m' : trace;
    print(formatted);
  }
}

/// File log handler that writes to a file.
class FileLogHandler extends LogHandler {
  final String filePath;
  final bool includeTimestamp;
  final StringBuffer _buffer = StringBuffer();
  Timer? _flushTimer;

  FileLogHandler({
    required this.filePath,
    super.minLevel,
    this.includeTimestamp = true,
    Duration autoFlushInterval = const Duration(seconds: 5),
  }) {
    // Auto flush periodically
    _flushTimer = Timer.periodic(autoFlushInterval, (_) => flush());
  }

  @override
  void handle(LogEntry entry) {
    final timestamp = includeTimestamp
        ? '${entry.timestamp.toIso8601String()} '
        : '';

    final context = entry.context != null ? '[${entry.context}] ' : '';

    final line =
        '$timestamp[${entry.level.name.toUpperCase()}] '
        '[${entry.channelName}] $context${entry.message}\n';

    _buffer.write(line);

    if (entry.error != null) {
      _buffer.write('  Error: ${entry.error}\n');
    }

    if (entry.stackTrace != null) {
      _buffer.write('  Stack trace:\n');
      _buffer.write(
        '  ${entry.stackTrace.toString().replaceAll('\n', '\n  ')}\n',
      );
    }

    if (entry.extra != null && entry.extra!.isNotEmpty) {
      _buffer.write('  Extra: ${entry.extra}\n');
    }
  }

  @override
  Future<void> flush() async {
    if (_buffer.isEmpty) return;

    try {
      // In a real implementation, write to actual file
      // For now, just simulate
      print('[FILE WRITE to $filePath] ${_buffer.length} bytes');
      _buffer.clear();
    } catch (e) {
      print('Error flushing file handler: $e');
    }
  }

  @override
  Future<void> close() async {
    _flushTimer?.cancel();
    await flush();
  }
}

/// Null logger handler that discards all logs.
class NullLogHandler extends LogHandler {
  NullLogHandler() : super(minLevel: LogLevel.fatal);

  @override
  void handle(LogEntry entry) {}
}

/// Stream handler that sends logs to a stream.
class StreamLogHandler extends LogHandler {
  final StreamController<LogEntry> _controller = StreamController.broadcast();

  StreamLogHandler({super.minLevel});

  Stream<LogEntry> get stream => _controller.stream;

  @override
  void handle(LogEntry entry) {
    _controller.add(entry);
  }

  @override
  Future<void> close() async {
    await _controller.close();
  }
}
