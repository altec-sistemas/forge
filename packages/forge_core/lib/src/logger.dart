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
          ? Colorize('[${entry.error.runtimeType}]').yellow().toString()
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

  String _formatChannel(String channel) {
    final channelStr = '[$channel]';
    return colored ? Colorize(channelStr).magenta().toString() : channelStr;
  }

  String _formatContext(String context) {
    final contextStr = '[$context]';
    return colored ? Colorize(contextStr).cyan().toString() : contextStr;
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

/// Estratégia de organização dos arquivos de log
enum LogFileStrategy {
  /// Um único arquivo para todos os logs
  single,

  /// Um arquivo por canal (ex: auth.log, network.log)
  byChannel,

  /// Um arquivo por data (ex: 2025-10-29.log)
  byDate,

  /// Um arquivo por canal e data (ex: auth_2025-10-29.log)
  byChannelAndDate,

  /// Um arquivo por nível de log (ex: error.log, warning.log)
  byLevel,

  /// Um arquivo por canal e nível (ex: auth_error.log)
  byChannelAndLevel,
}

/// Formato de timestamp nos nomes de arquivo
enum DateFormat {
  /// 2025-10-29
  date,

  /// 2025-10
  yearMonth,

  /// 2025-W44 (semana do ano)
  week,

  /// 2025-10-29_14-30-45
  dateTime,
}

/// Estratégia de rotação de arquivos
enum RotationStrategy {
  /// Sem rotação
  none,

  /// Rotação por tamanho máximo
  bySize,

  /// Rotação diária (muda de arquivo a cada dia)
  daily,

  /// Rotação por ambos (tamanho OU tempo)
  bySizeOrDaily,
}

/// Configuração do FileLogHandler
class FileLogConfig {
  /// Diretório base para os logs
  final String baseDirectory;

  /// Estratégia de organização dos arquivos
  final LogFileStrategy strategy;

  /// Formato de data nos nomes de arquivo
  final DateFormat dateFormat;

  /// Extensão dos arquivos (sem o ponto)
  final String extension;

  /// Estratégia de rotação
  final RotationStrategy rotationStrategy;

  /// Tamanho máximo do arquivo em bytes (para rotação por tamanho)
  final int? maxFileSize;

  /// Número máximo de arquivos a manter (0 = ilimitado)
  final int maxFiles;

  /// Criar subdiretórios por data (ex: logs/2025/10/29/)
  final bool createDateDirectories;

  /// Prefixo para nomes de arquivo
  final String? filePrefix;

  /// Sufixo para nomes de arquivo
  final String? fileSuffix;

  const FileLogConfig({
    this.baseDirectory = 'logs',
    this.strategy = LogFileStrategy.byChannelAndDate,
    this.dateFormat = DateFormat.date,
    this.extension = 'log',
    this.rotationStrategy = RotationStrategy.daily,
    this.maxFileSize = 10 * 1024 * 1024, // 10 MB
    this.maxFiles = 30,
    this.createDateDirectories = false,
    this.filePrefix,
    this.fileSuffix,
  });
}

/// File log handler that writes to a file with advanced organization strategies.
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
    super.minLevel,
    this.includeTimestamp = true,
    this.autoFlushInterval = const Duration(seconds: 5),
  }) {
    _flushTimer = Timer.periodic(autoFlushInterval, (_) => flush());
  }

  @override
  void handle(LogEntry entry) {
    final filePath = _getFilePath(entry);
    final buffer = _buffers.putIfAbsent(filePath, () => StringBuffer());

    // Formata a linha do log
    final timestamp = includeTimestamp
        ? '${entry.timestamp.toIso8601String()} '
        : '';

    final context = entry.context != null ? '[${entry.context}] ' : '';

    final line =
        '$timestamp[${entry.level.name.toUpperCase()}] '
        '[${entry.channelName}] $context${entry.message}\n';

    buffer.write(line);

    // Adiciona erro se existir
    if (entry.error != null) {
      buffer.write('  Error: ${entry.error}\n');
    }

    // Adiciona stack trace se existir
    if (entry.stackTrace != null) {
      buffer.write('  Stack trace:\n');
      buffer.write(
        '  ${entry.stackTrace.toString().replaceAll('\n', '\n  ')}\n',
      );
    }

    // Adiciona campos extras se existirem
    if (entry.extra != null && entry.extra!.isNotEmpty) {
      buffer.write('  Extra: ${entry.extra}\n');
    }

    // Verifica se precisa fazer rotação
    _checkRotation(filePath, entry);
  }

  /// Verifica e executa rotação se necessário
  void _checkRotation(String filePath, LogEntry entry) {
    final now = entry.timestamp;
    final lastCheck = _lastRotationCheck[filePath];

    // Rotação diária
    if (config.rotationStrategy == RotationStrategy.daily ||
        config.rotationStrategy == RotationStrategy.bySizeOrDaily) {
      if (lastCheck != null && !_isSameDay(lastCheck, now)) {
        _rotateFile(filePath);
        _lastRotationCheck[filePath] = now;
        return;
      }
    }

    // Rotação por tamanho
    if (config.rotationStrategy == RotationStrategy.bySize ||
        config.rotationStrategy == RotationStrategy.bySizeOrDaily) {
      _checkAndRotateBySize(filePath);
    }

    // Atualiza último check
    _lastRotationCheck[filePath] ??= now;
  }

  /// Verifica se duas datas são do mesmo dia
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Gera o caminho do arquivo baseado na estratégia
  String _getFilePath(LogEntry entry) {
    final fileName = _getFileName(entry);

    if (config.createDateDirectories) {
      final now = entry.timestamp;
      final dateDir = path.join(
        config.baseDirectory,
        now.year.toString(),
        now.month.toString().padLeft(2, '0'),
        now.day.toString().padLeft(2, '0'),
      );
      return path.join(dateDir, fileName);
    }

    return path.join(config.baseDirectory, fileName);
  }

  /// Gera o nome do arquivo baseado na estratégia
  String _getFileName(LogEntry entry) {
    final parts = <String>[];

    // Adiciona prefixo
    if (config.filePrefix != null) {
      parts.add(config.filePrefix!);
    }

    // Adiciona componentes baseados na estratégia
    switch (config.strategy) {
      case LogFileStrategy.single:
        parts.add('app');
        break;

      case LogFileStrategy.byChannel:
        parts.add(entry.channelName);
        break;

      case LogFileStrategy.byDate:
        parts.add(_formatDate(entry.timestamp));
        break;

      case LogFileStrategy.byChannelAndDate:
        parts.add(entry.channelName);
        parts.add(_formatDate(entry.timestamp));
        break;

      case LogFileStrategy.byLevel:
        parts.add(entry.level.name);
        break;

      case LogFileStrategy.byChannelAndLevel:
        parts.add(entry.channelName);
        parts.add(entry.level.name);
        break;
    }

    // Adiciona sufixo
    if (config.fileSuffix != null) {
      parts.add(config.fileSuffix!);
    }

    return '${parts.join('_')}.${config.extension}';
  }

  /// Formata a data de acordo com o formato configurado
  String _formatDate(DateTime date) {
    switch (config.dateFormat) {
      case DateFormat.date:
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';

      case DateFormat.yearMonth:
        return '${date.year}-${date.month.toString().padLeft(2, '0')}';

      case DateFormat.week:
        final weekNumber = _getWeekNumber(date);
        return '${date.year}-W${weekNumber.toString().padLeft(2, '0')}';

      case DateFormat.dateTime:
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}_'
            '${date.hour.toString().padLeft(2, '0')}-'
            '${date.minute.toString().padLeft(2, '0')}-'
            '${date.second.toString().padLeft(2, '0')}';
    }
  }

  /// Calcula o número da semana no ano (ISO 8601)
  int _getWeekNumber(DateTime date) {
    // Encontra a quinta-feira da semana
    final thursday = date.add(Duration(days: 4 - date.weekday));
    // Primeiro dia do ano
    final firstDay = DateTime(thursday.year, 1, 1);
    // Calcula a semana
    final weekNumber = ((thursday.difference(firstDay).inDays) / 7).ceil();
    return weekNumber;
  }

  /// Verifica e faz rotação por tamanho se necessário
  void _checkAndRotateBySize(String filePath) {
    if (config.maxFileSize == null) return;

    final file = File(filePath);
    if (!file.existsSync()) return;

    final size = file.lengthSync();
    if (size >= config.maxFileSize!) {
      _rotateFile(filePath);
    }
  }

  /// Faz a rotação de um arquivo
  void _rotateFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return;

    // Primeiro, faz flush do buffer atual
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

    // Gera nome para arquivo rotacionado
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = path.extension(filePath);
    final nameWithoutExt = path.basenameWithoutExtension(filePath);
    final dir = path.dirname(filePath);
    final rotatedName = '$nameWithoutExt.$timestamp$ext';
    final rotatedPath = path.join(dir, rotatedName);

    // Renomeia o arquivo
    try {
      file.renameSync(rotatedPath);
    } catch (e) {
      print('Error rotating file: $e');
      return;
    }

    // Limpa o cache para este arquivo
    _files.remove(filePath);

    // Limpa arquivos antigos
    _cleanOldFiles(dir);
  }

  /// Remove arquivos antigos baseado no maxFiles
  void _cleanOldFiles(String directory) {
    if (config.maxFiles <= 0) return;

    try {
      final dir = Directory(directory);
      if (!dir.existsSync()) return;

      // Lista todos os arquivos .log no diretório
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.${config.extension}'))
          .toList();

      // Ordena por data de modificação (mais antigo primeiro)
      files.sort((a, b) {
        try {
          return a.statSync().modified.compareTo(b.statSync().modified);
        } catch (e) {
          return 0;
        }
      });

      // Remove arquivos excedentes
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

  /// Faz flush de um buffer específico
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

  /// Obtém ou cria o arquivo de log
  Future<File> _getOrCreateFile(String filePath) async {
    if (_files.containsKey(filePath)) {
      return _files[filePath]!;
    }

    final file = File(filePath);

    // Cria diretórios se necessário
    final directory = file.parent;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    // Cria o arquivo se não existir
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
