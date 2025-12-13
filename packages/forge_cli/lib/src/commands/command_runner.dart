import 'dart:io';
import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import 'build_command.dart';
import 'watch_command.dart';

const String version = '1.0.0';

class ForgeCommandRunner extends CommandRunner<int> {
  ForgeCommandRunner()
    : super('forge', 'Code generation tool for Forge framework') {
    argParser.addFlag(
      'version',
      negatable: false,
      help: 'Print the current version.',
    );

    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Show verbose output',
    );

    addCommand(BuildCommand());
    addCommand(WatchCommand());
  }

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      final topLevelResults = parse(args);

      if (topLevelResults['version'] == true) {
        _logger.info('forge version $version');
        return ExitCode.success.code;
      }

      return await runCommand(topLevelResults) ?? ExitCode.success.code;
    } on FormatException catch (e) {
      _logger.err(e.message);
      _logger.info('');
      _logger.info(usage);
      return ExitCode.usage.code;
    } on UsageException catch (e) {
      _logger.err(e.message);
      _logger.info('');
      _logger.info(e.usage);
      return ExitCode.usage.code;
    }
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    final verbose = topLevelResults['verbose'] == true;

    if (verbose) {
      _logger.level = Level.verbose;
    }

    return super.runCommand(topLevelResults);
  }
}

final _logger = Logger();
