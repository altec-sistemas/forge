import 'package:forge/forge.dart';

import 'forge_example.bundle.dart';

@AutoBundle(
  paths: ['example/**.dart'],
)
class ExampleBundle extends AbstractExampleBundle {}

void main() {
  final forge = Kernel('dev')..addBundle(ExampleBundle());

  forge.run();
}
