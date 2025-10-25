import 'package:forge_core/forge_core.dart';

void main() async {
  /// Example of using EventBus for asynchronous event handling
  final eventBus = EventBus();

  eventBus.on<MyCustomEvent>((event) async {
    await Future.delayed(Duration(seconds: 1));
    print('Handling event asynchronously: ${event.message}');
  });

  eventBus.on<MyCustomEvent>((event) async {
    print('Received event with message: ${event.message}');
  });

  /// Stream listener is the best choice for non-blocking operations, and it’s best utilized in Forge Flutter.
  eventBus.stream<MyCustomEvent>().listen((event) {
    print('Stream listener received event: ${event.message}');
  });

  /// Example of using Validator for data validation
  final validator = Validator();

  final result = validator.validate(
    {
      'username': 'john_doe',
      'email': 'wrong_email_format',
    },
    Collection({
      'username': All([
        NotBlank(),
        Length(min: 3, max: 20),
      ]),
      'email': Email(),
    }),
  );

  print(result.toString());

  /// Example of using Injector for dependency injection
  final builder = InjectorBuilder();

  builder.registerFactory<Foo>((i) => Foo());
  builder.registerFactory<Bar>((i) => Bar(i.get<Foo>()));

  final injector = await builder.build();

  final bar = injector.get<Bar>();

  print('Bar has Foo: ${bar.foo}');

  /// Example of using Serializer for data serialization
  /// Serializer is normally used in Forge Framework with MetadataRegistry
  final serializer = Serializer(
    transformers: [PrimitiveTransformer(), MapTransformer(), ListTransformer()],
    encoders: [JsonEncoder()],
  );

  final data = {'name': 'Alice', 'age': 30};
  final serialized = serializer.serialize(data, 'json');

  print('Serialized data: $serialized');

  final deserialized = serializer.deserialize(
    serialized,
    'json',
  );

  print('Deserialized data: $deserialized');
}

class MyCustomEvent {
  final String message;

  MyCustomEvent(this.message);
}

class Foo {}

class Bar {
  final Foo foo;

  Bar(this.foo);
}
