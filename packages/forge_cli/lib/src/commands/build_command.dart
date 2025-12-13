import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../forge_driver.dart';

class BuildCommand extends Command<int> {
  BuildCommand() {
    argParser.addOption(
      'root',
      abbr: 'r',
      help: 'Root directory to scan',
      defaultsTo: '.',
    );
  }

  @override
  String get description => 'Generate code for @AutoBundle classes';

  @override
  String get name => 'build';

  @override
  Future<int> run() async {
    final logger = Logger();
    final rootDir = p.canonicalize(argResults!['root'] as String);

    final stopwatch = Stopwatch()..start();

    try {
      final driver = ForgeDriver(rootDir, logger: logger);
      await driver.run();

      stopwatch.stop();

      logger.success('Build completed in ${stopwatch.elapsedMilliseconds}ms');

      return ExitCode.success.code;
    } catch (e, stack) {
      stopwatch.stop();
      logger.err('Build failed: $e');
      if (logger.level == Level.verbose) {
        logger.detail(stack.toString());
      }
      return ExitCode.software.code;
    }
  }
}
