# Forge Framework

## ⚠️ Experimental Package

> **This package is experimental and still under active development. Breaking changes may occur without notice.**

A lightweight, annotation-based web framework for Dart with built-in dependency injection, validation, and serialization.

## Overview

Forge is a modular framework that uses code generation to handle routing, dependency injection, and request/response processing. It eliminates boilerplate while maintaining type safety through annotations and compile-time code generation.

## Getting Started

## Installation

run the following command to add Forge to your project:

```bash
dart pub add forge dev:forge_builder
```


### Basic Setup

Create a bundle and initialize the kernel:

```dart
import 'package:forge_framework/forge_framework.dart';
import 'forge_example.bundle.dart';

void main() {
  final forge = Kernel('dev')..addBundle(ExampleBundle());
  forge.run();
}

@AutoBundle(paths: ['lib/**.dart'])
class ExampleBundle extends AbstractExampleBundle {}
```

The `@AutoBundle` annotation scans specified paths and generates service registrations. Run `dart run build_runner build` to generate the bundle implementation.

### Controllers

Controllers handle HTTP requests using route annotations:

```dart
@Controller()
class UserController {
  final UserRepository _repository;
  UserController(this._repository);

  @Route.get('/users')
  Future<List<User>> listUsers(Request request) async {
    return _repository.findAll();
  }

  @Route.get('/users/:id')
  Future<User> getUser(int id) async {
    return _repository.findById(id);
  }

  @Route.post('/users')
  Future<User> createUser(@MapRequestPayload() CreateUserRequest request) async {
    return _repository.create(request);
  }
}
```

### Services

Register services with dependency injection:

```dart
@Service()
class UserRepository {
  final Database _db;
  UserRepository(this._db);

  Future<List<User>> findAll() async {
    // implementation
  }
}

@Service()
class PaymentService {
  final Payment paymentMethod;
  PaymentService(this.paymentMethod);
}

@Service()
class StripePayment implements Payment {
  @override
  bool process(double amount) {
    print('Processing Stripe payment of \$$amount');
    return true;
  }
}
```

### Singletons

Register singleton services that are instantiated once:

```dart
@Singleton()
class Configuration {
  final String apiKey;
  final String baseUrl;

  Configuration(this.apiKey, this.baseUrl);
}

@Singleton()
class CacheManager {
  final Map<String, dynamic> _cache = {};

  void set(String key, dynamic value) => _cache[key] = value;
  dynamic get(String key) => _cache[key];
}
```

### Custom Constructors

Specify which constructor to use for service instantiation:

```dart
@Singleton()
class PaymentProcessor {
  final Logger logger;
  final PaymentConfig? config;

  PaymentProcessor(this.logger);

  @Constructor()
  PaymentProcessor.withConfig(this.logger, this.config);
}
```

### Named Dependencies

Use named dependencies to differentiate between implementations:

```dart
abstract class Payment {
  void process(double amount);
}

@Service(name: 'payment.stripe')
class StripePayment implements Payment {
  void process(double amount) {
    print('Processing via Stripe');
  }
}

@Service(name: 'payment.paypal')
class PaypalPayment implements Payment {
  void process(double amount) {
    print('Processing via PayPal');
  }
}

@Service()
class OrderService {
  final Payment payment;

  OrderService(@Inject('payment.stripe') this.payment);
}
```

### Modules

Modules provide an alternative way to register services using methods or getters:

```dart
@Module()
class AppModule {
  @Provide()
  Payment paymentProvider() {
    return StripePayment();
  }

  @ProvideSingleton()
  Logger loggerProvider() {
    return Logger();
  }
}
```

Modules support async service registration:

```dart
@Module()
class ConfigModule {
  @Provide()
  Future<ServerConfig> getConfigFromServer() async {
    return await fetchConfig();
  }

  @ProvideEager()
  Future<DatabaseConnection> getDatabaseConnection() async {
    final config = await getConfigFromServer();
    return DatabaseConnection(config.dbUri);
  }
}
```

Note: Async services can only be resolved using `injector.getAsync()`. Eager services are instantiated when the injector is built and can be resolved synchronously.

## Request Mapping and Validation

### Automatic Deserialization

Use `@MapRequestPayload` for JSON request bodies or `@MapRequestQuery` for query parameters:

```dart
@Route.post('/users')
Future<User> createUser(@MapRequestPayload() CreateUserRequest request) async {
  final user = User(request.name, request.email, request.password);
  _users.add(user);
  return user;
}

@Route.get('/search')
Future<List<User>> searchUsers(@MapRequestQuery() SearchRequest query) async {
  return _users.where((u) => u.name.contains(query.term)).toList();
}

@Mappable()
class CreateUserRequest {
  @NotBlank()
  @Length(min: 3)
  final String name;

  @NotBlank()
  @Email()
  final String email;

  @NotBlank()
  @Length(min: 8)
  final String password;

  CreateUserRequest(this.name, this.email, this.password);
}

@Mappable()
class SearchRequest {
  @NotBlank()
  final String term;

  final int? limit;

  SearchRequest(this.term, this.limit);
}
```

Both annotations automatically validate and deserialize data into your model classes. Set `validade: false` to skip validation:

```dart
@Route.post('/raw')
Future<Response> raw(@MapRequestPayload(validade: false) Map data) async {
  // No validation performed
}
```

### Argument Resolvers

Controllers support various argument resolvers for injecting request data:

#### Query Parameters

Extract individual query parameters:

```dart
@Route.get('/hello')
Response greet(
    Request request,
    [@QueryParam() String name = 'World']
    ) {
  return Response.ok('Hello, $name!');
}

@Route.get('/users')
Future<List<User>> listUsers(
[@QueryParam('page') int page = 1],
[@QueryParam('limit') int limit = 10]
) async {
return _repository.findAll(page: page, limit: limit);
}
```

#### Path Parameters

Path parameters are automatically resolved by name:

```dart
@Route.get('/users/:id')
Future<User> getUser(int id) async {
  return _repository.findById(id);
}

@Route.get('/posts/:postId/comments/:commentId')
Future<Comment> getComment(int postId, int commentId) async {
  return _commentRepository.find(postId, commentId);
}
```

#### Dependency Injection

Inject services directly into controller methods:

```dart
@Route.post('/users')
Future<User> createUser(
    @MapRequestPayload() CreateUserRequest request,
    @Inject() UserRepository repository,
    @Inject() EventBus eventBus
    ) async {
  final user = await repository.create(request);
  await eventBus.dispatch(UserCreatedEvent(user));
  return user;
}

@Route.get('/orders')
Future<List<Order>> getOrders(
    @Inject('payment.stripe') Payment payment,
    @Inject() Logger logger
    ) async {
  logger.info('Fetching orders with payment: $payment');
  // implementation
}
```

### Custom Argument Resolvers

Create custom resolvers to inject context-specific data:

```dart
// Custom annotation
@Target({TargetKind.parameter})
class CurrentUser {
  const CurrentUser();
}

// Custom resolver
@Service()
class CurrentUserResolver implements ValueResolver {
  final AuthService _authService;

  CurrentUserResolver(this._authService);

  @override
  int get priority => 150;

  @override
  Future<ArgumentValue?> resolve(
      Request request,
      ParameterMetadata meta,
      ) async {
    if (!meta.hasAnnotation<CurrentUser>()) {
      return null;
    }

    final token = request.headers['authorization'];
    if (token == null) {
      throw UnauthorizedException('Missing authorization header');
    }

    final user = await _authService.getUserFromToken(token);
    return ArgumentValue(user);
  }
}

// Usage in controller
@Route.get('/profile')
Future<UserProfile> getProfile(@CurrentUser() User user) async {
  return UserProfile(user);
}

@Route.post('/posts')
Future<Post> createPost(
    @CurrentUser() User user,
    @MapRequestPayload() CreatePostRequest request
    ) async {
  return _postRepository.create(user.id, request);
}
```

All `ValueResolver` implementations registered as services are automatically added to the argument resolution chain.

## Serialization

The serializer handles normalization and denormalization:

```dart
// Serialize to JSON
final json = _serializer.serialize(user, 'json');

// Deserialize from JSON
final user = _serializer.deserialize<User>(json, 'json');

// Direct normalization/denormalization
final map = _serializer.normalize(user);
final user = _serializer.denormalize<User>(map);
```

### Serialization Annotations

Control serialization behavior with annotations:

```dart
@Mappable()
class User {
  @Property(name: 'user_name')
  final String name;

  final String email;

  @Ignore()
  final String password;

  @Property(groups: ['admin'])
  final String adminNotes;

  @Property(groups: ['admin', 'manager'])
  final double salary;

  User(this.name, this.email, this.password, this.adminNotes, this.salary);
}
```

Serialize with specific groups:

```dart
// Only includes fields without groups or with 'admin' group
final json = _serializer.serialize(
    user,
    'json',
    SerializerContext(groups: ['admin'])
);

// Includes fields with 'admin' or 'manager' groups
final json = _serializer.serialize(
    user,
    'json',
    SerializerContext(groups: ['admin', 'manager'])
);
```

### Custom Transformers

Create custom transformers for specific types:

```dart
@Service()
class DecimalTransformer implements Transformer {
  @override
  dynamic normalize<T>(T object, SerializerContext context) {
    return object.toString();
  }

  @override
  bool supportsNormalization<T>(T object, SerializerContext context) {
    return object is Decimal;
  }

  @override
  T denormalize<T>(dynamic data, SerializerContext context) {
    return Decimal.parse(data as String) as T;
  }

  @override
  bool supportsDenormalization<T>(dynamic data, SerializerContext context) {
    return data is String && (T == Decimal || T == Decimal?);
  }
}

@Service()
class UuidTransformer implements Transformer {
  @override
  dynamic normalize<T>(T object, SerializerContext context) {
    return (object as Uuid).value;
  }

  @override
  bool supportsNormalization<T>(T object, SerializerContext context) {
    return object is Uuid;
  }

  @override
  T denormalize<T>(dynamic data, SerializerContext context) {
    return Uuid(data as String) as T;
  }

  @override
  bool supportsDenormalization<T>(dynamic data, SerializerContext context) {
    return data is String && (T == Uuid || T == Uuid?);
  }
}
```

All `Transformer` implementations registered as services are automatically available to the serializer.

## Validation

Validate data structures manually:

```dart
// Validate and throw on error
_validator.validateOrThrow(name, All([NotBlank(), Length(min: 3)]));

// Validate maps
final violations = _validator.validate(
{'name': 'Jo', 'email': 'invalid'},
Collection(fields: {
'name': All([NotBlank(), Length(min: 3)]),
'email': Email(),
}),
);

if (violations.isNotEmpty) {
for (final violation in violations) {
print('${violation.propertyPath}: ${violation.message}');
}
}

// Check validity
if (_validator.isValid(data, constraint)) {
// proceed
}
```

### Available Constraints

```dart
// Basic
NotNull()
NotBlank()
Email()

// String
Length(min: 3, max: 100)
Regex(pattern: r'^\d+$')

// Numeric
Range(min: 0, max: 100)
GreaterThan(5)
LessThan(10)

// Collections
Collection(fields: {
'name': NotBlank(),
'age': Range(min: 0, max: 150),
})

// Composition
All([NotBlank(), Length(min: 3)])
Any([Email(), Regex(pattern: phoneRegex)])
```

### Custom Validation Messages

Configure validation messages by providing a custom message provider:

```dart
@Module()
class ValidationModule {
  @Provide()
  ValidationMessageProvider get messageProvider =>
      PortugueseValidationMessageProvider();
}
```

Create custom message providers:

```dart
class SpanishValidationMessageProvider extends ValidationMessageProvider {
  const SpanishValidationMessageProvider()
      : super(const {
    ValidationMessageKey.notBlank: 'Este valor no debe estar vacío.',
    ValidationMessageKey.invalidEmail: 'Este valor no es una dirección de correo válida.',
    // ... more messages
  });
}
```

## Events

Listen to framework events:

```dart
@Service()
class AppListener {
  @AsEventListener()
  void onRequest(HttpKernelRequestEvent event) {
    print('Request: ${event.context.request.requestedUri}');
  }

  @AsEventListener()
  void onException(HttpKernelExceptionEvent event) {
    print('Error: ${event.exception}');
  }

  @AsEventListener()
  void onServerStarted(HttpRunnerStarted event) {
    print('Server started on port ${event.port}');
  }
}
```

### Custom Events

Create and dispatch custom events:

```dart
class SaleCompletedEvent {
  final Sale sale;
  final DateTime timestamp;

  SaleCompletedEvent(this.sale) : timestamp = DateTime.now();
}

@Service()
class SaleService {
  final EventBus _eventBus;

  SaleService(this._eventBus);

  Future<void> completeSale(Sale sale) async {
    // Sale logic
    await _eventBus.dispatch(SaleCompletedEvent(sale));
  }
}

@Service()
class SaleListener {
  @AsEventListener()
  void onSaleCompleted(SaleCompletedEvent event) {
    print('Sale completed: ${event.sale.id}');
  }
}
```

Note: Event listeners are executed synchronously one after another. For asynchronous listeners, use the EventBus stream directly:

```dart
@Service()
class AsyncSaleProcessor {
  AsyncSaleProcessor(EventBus eventBus) {
    eventBus.stream<SaleCompletedEvent>().listen((event) async {
      await processAfterSale(event.sale);
    });
  }

  Future<void> processAfterSale(Sale sale) async {
    // Async processing
  }
}
```

## Metadata System

Forge includes a reflection-like metadata system for runtime introspection. Create custom annotations by implementing capabilities:

```dart
@Target({TargetKind.method})
class AsEventListener implements MethodsCapability, ParametersCapability {
  final int priority;
  const AsEventListener({this.priority = 0});
}

@Target({TargetKind.parameter})
class Authorized implements ParametersCapability {
  final List<String> roles;
  const Authorized(this.roles);
}
```

Access metadata at runtime:

```dart
final registry = injector.get<MetadataRegistry>();

// Find all methods with specific annotation
final listeners = registry.methodsAnnotatedWith<AsEventListener>();

// Access class metadata
final classMetadata = registry.getClassMetadata<UserController>();
final methods = classMetadata.methods;
```

## Complete Example

```dart
import 'package:forge_framework/forge_framework.dart';
import 'app.bundle.dart';

void main() {
  final forge = Kernel('dev')..addBundle(AppBundle());
  forge.run();
}

@AutoBundle(paths: ['lib/**.dart'])
class AppBundle extends AbstractAppBundle {}

// Models
@Mappable()
class User {
  final int id;

  @Property(name: 'user_name')
  final String name;

  final String email;

  @Ignore()
  final String password;

  User(this.id, this.name, this.email, this.password);
}

@Mappable()
class CreateUserRequest {
  @NotBlank()
  @Length(min: 3, max: 50)
  final String name;

  @NotBlank()
  @Email()
  final String email;

  @NotBlank()
  @Length(min: 8)
  final String password;

  CreateUserRequest(this.name, this.email, this.password);
}

// Repository
@Service()
class UserRepository {
  final List<User> _users = [];

  Future<List<User>> findAll() async => _users;

  Future<User?> findById(int id) async {
    return _users.firstWhere((u) => u.id == id);
  }

  Future<User> create(CreateUserRequest request) async {
    final user = User(
      _users.length + 1,
      request.name,
      request.email,
      request.password,
    );
    _users.add(user);
    return user;
  }
}

// Controller
@Controller(prefix: '/api')
class UserController {
  final UserRepository _repository;
  final EventBus _eventBus;

  UserController(this._repository, this._eventBus);

  @Route.get('/users')
  Future<List<User>> listUsers(
  [@QueryParam('page') int page = 1],
  [@QueryParam('limit') int limit = 10]
  ) async {
  return _repository.findAll();
  }

  @Route.get('/users/:id')
  Future<User> getUser(int id) async {
  final user = await _repository.findById(id);
  if (user == null) {
  throw NotFoundException('User not found');
  }
  return user;
  }

  @Route.post('/users')
  Future<User> createUser(@MapRequestPayload() CreateUserRequest request) async {
  final user = await _repository.create(request);
  await _eventBus.dispatch(UserCreatedEvent(user));
  return user;
  }
}

// Events
class UserCreatedEvent {
  final User user;
  UserCreatedEvent(this.user);
}

@Service()
class UserListener {
  @AsEventListener()
  void onUserCreated(UserCreatedEvent event) {
    print('New user created: ${event.user.name}');
  }
}
```