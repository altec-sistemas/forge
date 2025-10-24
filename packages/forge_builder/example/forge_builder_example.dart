import 'package:forge_core/forge_core.dart';

import 'forge_builder_example.bundle.dart';

void main() {
  print(ty<String>() == String);
  print(ty<String?>() == String);
}

Type ty<T>() {
  return T;
}

@AutoBundle(paths: ['example/**.dart'])
class ExampleBundle extends AbstractExampleBundle {}
