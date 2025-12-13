import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

import '../forge_driver.dart';

class WatchCommand extends Command<int> {
  WatchCommand() {
    argParser.addOption(
      'root',
      abbr: 'r',
      help: 'Root directory to watch',
      defaultsTo: '.',
    );
  }

  @override
  String get description => 'Watch for changes and regenerate code';

  @override
  String get name => 'watch';

  @override
  Future<int> run() async {
    final logger = Logger();
    final rootDir = p.canonicalize(argResults!['root'] as String);

    logger.info('Watching $rootDir for changes');
    logger.info('Press Ctrl+C to stop\n');

    final driver = ForgeDriver(rootDir, logger: logger);

    await _runInitialBuild(driver, logger);

    final watcher = DirectoryWatcher(rootDir);
    final debouncer = _Debouncer(milliseconds: 500);

    try {
      await for (final event in watcher.events) {
        if (!_shouldProcess(event.path)) continue;

        // Identifica o package do arquivo alterado
        final packagePath = _findPackageRoot(event.path, rootDir);

        if (packagePath == null) {
          logger.warn('Could not determine package for ${event.path}');
          continue;
        }

        debouncer.run(() async {
          await _rebuildPackage(driver, logger, event.path, packagePath);
        });
      }
    } catch (e) {
      logger.err('Watch error: $e');
      return ExitCode.software.code;
    }

    return ExitCode.success.code;
  }

  Future<void> _runInitialBuild(ForgeDriver driver, Logger logger) async {
    try {
      await driver.run();
      logger.info('');
    } catch (e) {
      logger.err('Initial build failed: $e');
    }
  }

  Future<void> _rebuildPackage(
    ForgeDriver driver,
    Logger logger,
    String changedPath,
    String packagePath,
  ) async {
    // --- ALTERAÇÃO AQUI ---
    // Limpa o console e reseta a posição do cursor antes de logar a nova alteração
    stdout.write('\x1B[2J\x1B[0;0H');
    // ----------------------

    final fileName = p.basename(changedPath);
    final packageName = p.basename(packagePath);

    logger.info('Change detected in [$packageName]: $fileName\n');

    try {
      await driver.runForPackage(packagePath);
      logger.info('');
    } catch (e) {
      logger.err('Build failed for [$packageName]: $e');
    }
  }

  /// Encontra o diretório raiz do package que contém o arquivo
  String? _findPackageRoot(String filePath, String rootDir) {
    var current = Directory(p.dirname(filePath));
    final root = Directory(rootDir);

    while (current.path.startsWith(root.path)) {
      // Verifica se existe pubspec.yaml neste diretório
      final pubspecFile = File(p.join(current.path, 'pubspec.yaml'));
      if (pubspecFile.existsSync()) {
        return current.path;
      }

      // Sobe um nível
      final parent = current.parent;
      if (parent.path == current.path) break; // Chegou na raiz do sistema
      current = parent;
    }

    return null;
  }

  bool _shouldProcess(String path) {
    if (path.endsWith('.bundle.dart')) return false;
    if (path.endsWith('.g.dart')) return false;
    if (!path.endsWith('.dart')) return false;
    if (path.contains('/.dart_tool/')) return false;
    if (path.contains('/build/')) return false;
    return true;
  }
}

class _Debouncer {
  final int milliseconds;
  Timer? _timer;

  _Debouncer({required this.milliseconds});

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
