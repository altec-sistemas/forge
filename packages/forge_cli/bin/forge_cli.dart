import 'dart:io';
import 'package:forge_cli/src/commands/command_runner.dart';

Future<void> main(List<String> arguments) async {
  await _flushThenExit(await ForgeCommandRunner().run(arguments));
}

Future<void> _flushThenExit(int status) async {
  await Future.wait<void>([stdout.close(), stderr.close()]);
  exit(status);
}
