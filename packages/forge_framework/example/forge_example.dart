import 'package:forge_framework/forge_framework.dart';

import 'forge_example.bundle.dart';

void main() {
  final forge = Kernel('dev')..addBundle(ExampleBundle());
  forge.run();
}

@AutoBundle(
  paths: ['example/**.dart'],
)
class ExampleBundle extends AbstractExampleBundle {}
