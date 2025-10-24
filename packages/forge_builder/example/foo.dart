import 'dart:io';
import 'dart:collection';
import 'dart:math';

import 'package:forge_core/forge_core.dart';

@Service()
class Car implements Vehicle {}

@Service()
class Truck implements Vehicle {}

abstract class Vehicle {}

@Service()
class Bar {
  final Vehicle foo;
  Bar(@Inject<Car>() this.foo);
}

@Module()
class SerializerModule {
  @Provide()
  Serializer get serializer => Serializer(transformers: [], encoders: []);

  @ProvideEager()
  Future<JsonEncoder> errorFuture(String env) async {
    return JsonEncoder();
  }

  @Provide()
  Future<UnmodifiableListView<List<List<int>>>> get readOnlyList async {
    return UnmodifiableListView([
      [
        [1, 2, 3],
      ],
    ]);
  }

  @Boot()
  Future<Random> get computedValue async {
    return Random();
  }

  @Provide()
  HttpClient get httpClient => HttpClient();

  @Provide()
  List<Random> get randomGenerators => [Random(), Random()];
}

class Controller extends Service implements ClassCapability, MethodsCapability {
  const Controller();
}

@Controller()
class UserController {
  @Route('/')
  void getUser(HttpRequest? request) {
    // Implementation here
  }

  void anotherMethod() {
    // Another method implementation
  }
}

class Route {
  final String path;
  const Route(this.path);
}
