import 'package:meta/meta_meta.dart';

import '../../forge_core.dart';

@Target({TargetKind.method})
class AsEventListener implements MethodsCapability, ParametersCapability {
  final int priority;

  const AsEventListener({this.priority = 0});
}
