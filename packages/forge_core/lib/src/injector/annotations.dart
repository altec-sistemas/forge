import 'package:meta/meta_meta.dart';

import '../../forge_core.dart';

/// Base interface for all reflection capabilities.
///
/// Capabilities define what metadata should be generated for annotated elements.
/// This follows the Reflectable pattern where capabilities are composable and hierarchical.
abstract class ReflectCapability {
  const ReflectCapability();
}

/// Capability that controls whether class metadata is included.
///
/// When a class is annotated with a capability implementing this interface,
/// the class type and its annotations are registered in the metadata system.
/// This is the base requirement for any metadata generation.
///
/// **Example:**
/// ```dart
/// class MyAnnotation implements ClassCapability {
///   const MyAnnotation();
/// }
///
/// @MyAnnotation()
/// class UserService {
///   // Class metadata will be registered
/// }
/// ```
///
/// **Generated metadata code:**
/// ```dart
/// metaBuilder.registerClass<prefix0.UserService>(
///   meta.clazz(
///     meta.type<prefix0.UserService>(),
///     [prefix0.MyAnnotation()],
///   ),
/// );
/// ```
abstract class ClassCapability implements ReflectCapability {
  const ClassCapability();
}

/// Capability that enables metadata about methods.
///
/// **Class-level behavior:**
/// When applied at class level, generates metadata for ALL methods in the class.
///
/// **Method-level behavior:**
/// When applied at method level, generates:
/// - Class metadata (required to access the method metadata)
/// - Metadata only for the annotated method
///
/// **Important:** To access method metadata at runtime, the class metadata must exist.
/// When you annotate a method, the generator creates both the class metadata and the
/// specific method metadata, allowing you to query it later.
///
/// **Example - Class level:**
/// ```dart
/// class RestController implements MethodsCapability {
///   const RestController();
/// }
///
/// @RestController()
/// class UserController {
///   void create() {} // Metadata generated
///   void update() {} // Metadata generated
///   void delete() {} // Metadata generated
/// }
/// ```
///
/// **Generated metadata code:**
/// ```dart
/// metaBuilder.registerClass<prefix0.UserController>(
///   meta.clazz(
///     meta.type<prefix0.UserController>(),
///     [prefix0.RestController()],
///     null, // constructors
///     [
///       meta.method(
///         meta.type<void>(),
///         'create',
///         (instance) => instance.create,
///       ),
///       meta.method(
///         meta.type<void>(),
///         'update',
///         (instance) => instance.update,
///       ),
///       meta.method(
///         meta.type<void>(),
///         'delete',
///         (instance) => instance.delete,
///       ),
///     ],
///   ),
/// );
/// ```
///
/// **At runtime, you can access:**
/// ```dart
/// final classMeta = registry.getClassMetadata<UserController>();
/// // classMeta.methods will contain all three methods
/// ```
///
/// **Example - Method level:**
/// ```dart
/// class Route implements MethodsCapability {
///   final String path;
///   const Route(this.path);
/// }
///
/// class UserController {
///   @Route('/create')
///   void create() {} // Class + this method's metadata generated
///
///   void update() {} // No metadata generated
/// }
/// ```
///
/// **Generated metadata code:**
/// ```dart
/// metaBuilder.registerClass<prefix0.UserController>(
///   meta.clazz(
///     meta.type<prefix0.UserController>(),
///     [], // No class-level annotations
///     null, // constructors
///     [
///       meta.method(
///         meta.type<void>(),
///         'create',
///         (instance) => instance.create,
///         null, // parameters
///         [prefix0.Route('/create')],
///       ),
///     ],
///   ),
/// );
/// ```
///
/// **At runtime:**
/// ```dart
/// final classMeta = registry.getClassMetadata<UserController>();
/// // classMeta.methods will contain only create()
/// final createMethod = classMeta.methods!.first;
/// final route = createMethod.firstAnnotationOf<Route>();
/// print(route.path); // '/create'
/// ```
abstract class MethodsCapability implements ClassCapability {
  const MethodsCapability();
}

/// Capability that enables metadata about constructors.
///
/// **Class-level behavior:**
/// When applied at class level, generates metadata for ALL constructors in the class.
///
/// **Constructor-level behavior:**
/// When applied at constructor level, generates:
/// - Class metadata (required to access the constructor metadata)
/// - Metadata only for the annotated constructor
///
/// **Important:** To access constructor metadata at runtime, the class metadata must exist.
/// The generator ensures the class is registered when a constructor is annotated.
///
/// **Example - Class level:**
/// ```dart
/// class Injectable implements ConstructorsCapability {
///   const Injectable();
/// }
///
/// @Injectable()
/// class EmailService {
///   EmailService(SmtpClient client);
///   EmailService.withConfig(SmtpClient client, Config config);
/// }
/// ```
///
/// **Generated metadata code:**
/// ```dart
/// metaBuilder.registerClass<prefix0.EmailService>(
///   meta.clazz(
///     meta.type<prefix0.EmailService>(),
///     [prefix0.Injectable()],
///     [
///       meta.constructor(
///         () => prefix0.EmailService.new as Function,
///         [
///           meta.parameter(meta.type<prefix1.SmtpClient>(), 'client', 0, false, false),
///         ],
///       ),
///       meta.constructor(
///         () => prefix0.EmailService.withConfig as Function,
///         [
///           meta.parameter(meta.type<prefix1.SmtpClient>(), 'client', 0, false, false),
///           meta.parameter(meta.type<prefix2.Config>(), 'config', 1, false, false),
///         ],
///         'withConfig',
///       ),
///     ],
///   ),
/// );
/// ```
///
/// **At runtime:**
/// ```dart
/// final classMeta = registry.getClassMetadata<EmailService>();
/// // classMeta.constructors will contain both constructors
/// ```
///
/// **Example - Constructor level:**
/// ```dart
/// class PrimaryConstructor implements ConstructorsCapability {
///   const PrimaryConstructor();
/// }
///
/// class PaymentService {
///   @PrimaryConstructor()
///   PaymentService(Gateway gateway);
///
///   PaymentService.test(); // No metadata generated
/// }
/// ```
///
/// **Generated metadata code:**
/// ```dart
/// metaBuilder.registerClass<prefix0.PaymentService>(
///   meta.clazz(
///     meta.type<prefix0.PaymentService>(),
///     [],
///     [
///       meta.constructor(
///         () => prefix0.PaymentService.new as Function,
///         [
///           meta.parameter(meta.type<prefix1.Gateway>(), 'gateway', 0, false, false),
///         ],
///         '',
///         [prefix0.PrimaryConstructor()],
///       ),
///     ],
///   ),
/// );
/// ```
///
/// **At runtime:**
/// ```dart
/// final classMeta = registry.getClassMetadata<PaymentService>();
/// // classMeta.constructors will contain only the primary constructor
/// ```
abstract class ConstructorsCapability implements ClassCapability {
  const ConstructorsCapability();
}

/// Capability that enables metadata about getters.
///
/// **Class-level behavior:**
/// When applied at class level, generates metadata for ALL getters in the class.
///
/// **Getter-level behavior:**
/// When applied at getter level, generates:
/// - Class metadata (required to access the getter metadata)
/// - Metadata only for the annotated getter
///
/// **Example - Class level:**
/// ```dart
/// class Serializable implements GettersCapability {
///   const Serializable();
/// }
///
/// @Serializable()
/// class User {
///   String get name => _name;
///   int get age => _age;
/// }
/// ```
///
/// **Generated metadata code:**
/// ```dart
/// metaBuilder.registerClass<prefix0.User>(
///   meta.clazz(
///     meta.type<prefix0.User>(),
///     [prefix0.Serializable()],
///     null, // constructors
///     null, // methods
///     [
///       meta.getter(
///         meta.type<String>(),
///         'name',
///         (instance) => instance.name,
///       ),
///       meta.getter(
///         meta.type<int>(),
///         'age',
///         (instance) => instance.age,
///       ),
///     ],
///   ),
/// );
/// ```
///
/// **Example - Getter level:**
/// ```dart
/// class Computed implements GettersCapability {
///   const Computed();
/// }
///
/// class Product {
///   @Computed()
///   double get totalPrice => price * quantity;
///
///   String get name => _name; // No metadata generated
/// }
/// ```
///
/// **Generated metadata code:**
/// ```dart
/// metaBuilder.registerClass<prefix0.Product>(
///   meta.clazz(
///     meta.type<prefix0.Product>(),
///     [],
///     null, // constructors
///     null, // methods
///     [
///       meta.getter(
///         meta.type<double>(),
///         'totalPrice',
///         (instance) => instance.totalPrice,
///         [prefix0.Computed()],
///       ),
///     ],
///   ),
/// );
/// ```
abstract class GettersCapability implements ClassCapability {
  const GettersCapability();
}

/// Capability that enables metadata about setters.
///
/// **Class-level behavior:**
/// When applied at class level, generates metadata for ALL setters in the class.
///
/// **Setter-level behavior:**
/// When applied at setter level, generates:
/// - Class metadata (required to access the setter metadata)
/// - Metadata only for the annotated setter
///
/// **Example - Class level:**
/// ```dart
/// class Mutable implements SettersCapability {
///   const Mutable();
/// }
///
/// @Mutable()
/// class Configuration {
///   set apiKey(String value) {}
///   set timeout(Duration value) {}
/// }
/// ```
///
/// **Generated metadata code:**
/// ```dart
/// metaBuilder.registerClass<prefix0.Configuration>(
///   meta.clazz(
///     meta.type<prefix0.Configuration>(),
///     [prefix0.Mutable()],
///     null, // constructors
///     null, // methods
///     null, // getters
///     [
///       meta.setter(
///         meta.type<String>(),
///         'apiKey',
///         (instance, value) => instance.apiKey = value,
///       ),
///       meta.setter(
///         meta.type<Duration>(),
///         'timeout',
///         (instance, value) => instance.timeout = value,
///       ),
///     ],
///   ),
/// );
/// ```
///
/// **Example - Setter level:**
/// ```dart
/// class Validated implements SettersCapability {
///   const Validated();
/// }
///
/// class UserProfile {
///   @Validated()
///   set email(String value) {}
///
///   set name(String value) {} // No metadata generated
/// }
/// ```
///
/// **Generated metadata code:**
/// ```dart
/// metaBuilder.registerClass<prefix0.UserProfile>(
///   meta.clazz(
///     meta.type<prefix0.UserProfile>(),
///     [],
///     null, // constructors
///     null, // methods
///     null, // getters
///     [
///       meta.setter(
///         meta.type<String>(),
///         'email',
///         (instance, value) => instance.email = value,
///         [prefix0.Validated()],
///       ),
///     ],
///   ),
/// );
/// ```
abstract class SettersCapability implements ClassCapability {
  const SettersCapability();
}

/// Capability that enables proxy generation for runtime interception.
///
/// **Behavior:**
/// When applied at class level, generates:
/// - Full metadata for methods, getters, and setters (required for proxy)
/// - A proxy class (_ClassNameProxy) that extends AbstractProxy
/// - A createProxy function in the class metadata
///
/// The generated proxy allows runtime interception of method calls, getter access,
/// and setter calls through a ProxyHandler.
///
/// **Example:**
/// ```dart
/// @ProxyCapability()
/// class User {
///   String name;
///   int age;
///
///   User(this.name, this.age);
///
///   String greet() => 'Hello, I am $name';
/// }
/// ```
///
/// **Generated code:**
/// ```dart
/// // Proxy class
/// class _UserProxy extends AbstractProxy implements User {
///   _UserProxy._internal(Object target, ProxyHandler handler, ClassMetadata metadata)
///     : super(target, handler, metadata);
/// }
///
/// // In metadata:
/// metaBuilder.registerClass<User>(
///   meta.clazz(
///     meta.type<User>(),
///     [ProxyCapability()],
///     null, // constructors
///     [ /* all methods */ ],
///     [ /* all getters */ ],
///     [ /* all setters */ ],
///     (target, handler, metadata) => _UserProxy._internal(target, handler, metadata),
///   ),
/// );
/// ```
///
/// **Usage:**
/// ```dart
/// final registry = await setupRegistry();
/// final userMetadata = registry.getClassMetadata<User>();
///
/// final realUser = User('Alice', 25);
///
/// final handler = ProxyHandler(
///   onMethodCall: (name, pos, named) {
///     print('Method called: $name');
///     return null; // Execute real method
///   },
///   onGetterAccess: (name) {
///     print('Getter accessed: $name');
///     return null; // Get real value
///   },
///   onSetterAccess: (name, value) {
///     print('Setter: $name = $value');
///   },
/// );
///
/// final proxy = userMetadata.createProxy!(realUser, handler, userMetadata) as User;
/// proxy.name; // Logs: Getter accessed: name
/// proxy.greet(); // Logs: Method called: greet
/// ```
abstract class ProxyCapability
    implements MethodsCapability, GettersCapability, SettersCapability {
  const ProxyCapability();
}

/// Capability that enables metadata about parameters.
///
/// This capability applies to both methods and constructors. It only generates
/// parameter metadata when combined with [MethodsCapability] or [ConstructorsCapability].
///
/// **Class-level behavior:**
/// When applied at class level:
/// - Must be combined with [MethodsCapability] or [ConstructorsCapability]
/// - Generates parameter metadata for ALL methods/constructors that have their metadata generated
///
/// **Method/Constructor-level behavior:**
/// When applied at method or constructor level:
/// - Generates parameter metadata only for that specific method/constructor
///
/// **Type Arguments:**
/// The metadata system supports nullable and generic types:
/// - For nullable types: `meta.type<String>([], true)` or `meta.type<String?>([], true)`
/// - For generic types: `meta.type<List<User>>([meta.type<User>()])`
/// - For nullable generics: `meta.type<List<User>?>([meta.type<User>()], true)`
///
/// **Example - Class level with methods:**
/// ```dart
/// class ApiController implements MethodsCapability, ParametersCapability {
///   const ApiController();
/// }
///
/// @ApiController()
/// class UserController {
///   void create(String name, String email) {}
///   void update(int id, String name) {}
/// }
/// ```
///
/// **Generated metadata code:**
/// ```dart
/// metaBuilder.registerClass<prefix0.UserController>(
///   meta.clazz(
///     meta.type<prefix0.UserController>(),
///     [prefix0.ApiController()],
///     null, // constructors
///     [
///       meta.method(
///         meta.type<void>(),
///         'create',
///         (instance) => instance.create,
///         [
///           meta.parameter(meta.type<String>(), 'name', 0, false, false),
///           meta.parameter(meta.type<String>(), 'email', 1, false, false),
///         ],
///       ),
///       meta.method(
///         meta.type<void>(),
///         'update',
///         (instance) => instance.update,
///         [
///           meta.parameter(meta.type<int>(), 'id', 0, false, false),
///           meta.parameter(meta.type<String>(), 'name', 1, false, false),
///         ],
///       ),
///     ],
///   ),
/// );
/// ```
///
/// **At runtime:**
/// ```dart
/// final classMeta = registry.getClassMetadata<UserController>();
/// final createMethod = classMeta.methods!.first;
/// final parameters = createMethod.parameters; // Contains 'name' and 'email' parameters
/// print(parameters![0].name); // 'name'
/// print(parameters[0].typeMetadata.type); // String
/// ```
///
/// **Example - Method level with nullable and generic types:**
/// ```dart
/// class Validated implements MethodsCapability, ParametersCapability {
///   const Validated();
/// }
///
/// class PaymentService {
///   @Validated()
///   void process(String cardNumber, double? amount, List<String> tags) {}
///
///   void refund(String transactionId) {} // No metadata generated
/// }
/// ```
///
/// **Generated metadata code:**
/// ```dart
/// metaBuilder.registerClass<prefix0.PaymentService>(
///   meta.clazz(
///     meta.type<prefix0.PaymentService>(),
///     [],
///     null, // constructors
///     [
///       meta.method(
///         meta.type<void>(),
///         'process',
///         (instance) => instance.process,
///         [
///           meta.parameter(meta.type<String>(), 'cardNumber', 0, false, false),
///           meta.parameter(meta.type<double>([], true), 'amount', 1, false, false),
///           meta.parameter(meta.type<List<String>>([meta.type<String>()]), 'tags', 2, false, false),
///         ],
///         [prefix0.Validated()],
///       ),
///     ],
///   ),
/// );
/// ```
abstract class ParametersCapability implements ClassCapability {
  const ParametersCapability();
}

/// Capability that enables metadata about enum type.
///
/// When an enum is annotated with a capability implementing this interface,
/// the enum type and its annotations are registered in the metadata system.
///
/// **Example:**
/// ```dart
/// class JsonEnum implements EnumCapability {
///   const JsonEnum();
/// }
///
/// @JsonEnum()
/// enum Status {
///   pending,
///   active,
///   completed
/// }
/// ```
///
/// **Generated metadata code:**
/// ```dart
/// metaBuilder.registerEnum<prefix0.Status>(
///   meta.enumMeta(
///     meta.type<prefix0.Status>(),
///     [prefix0.JsonEnum()],
///   ),
/// );
/// ```
abstract class EnumCapability implements ReflectCapability {
  const EnumCapability();
}

/// Capability that enables metadata about enum values.
///
/// When applied at enum level, generates metadata for ALL enum values.
///
/// **Example:**
/// ```dart
/// class SerializableEnum implements EnumValuesCapability {
///   const SerializableEnum();
/// }
///
/// @SerializableEnum()
/// enum Priority {
///   low,    // Metadata: name='low', index=0
///   medium, // Metadata: name='medium', index=1
///   high    // Metadata: name='high', index=2
/// }
/// ```
///
/// **Generated metadata code:**
/// ```dart
/// metaBuilder.registerEnum<prefix0.Priority>(
///   meta.enumMeta(
///     meta.type<prefix0.Priority>(),
///     [prefix0.SerializableEnum()],
///     [
///       meta.enumValue('low', prefix0.Priority.low, 0),
///       meta.enumValue('medium', prefix0.Priority.medium, 1),
///       meta.enumValue('high', prefix0.Priority.high, 2),
///     ],
///   ),
/// );
/// ```
abstract class EnumValuesCapability implements EnumCapability {
  const EnumValuesCapability();
}

/// Comprehensive capability that combines all class member capabilities.
///
/// This is equivalent to implementing [MethodsCapability], [ConstructorsCapability],
/// [GettersCapability], [SettersCapability], and [ParametersCapability].
///
/// Use this when you need complete metadata for all class members.
///
/// **Example:**
/// ```dart
/// class FullReflection implements DeclarationsCapability {
///   const FullReflection();
/// }
///
/// @FullReflection()
/// class CompleteService {
///   CompleteService(Logger logger);
///
///   void process(String data) {}
///
///   String get status => _status;
///
///   set status(String value) {}
/// }
/// ```
///
/// **Generated metadata code:**
/// ```dart
/// metaBuilder.registerClass<prefix0.CompleteService>(
///   meta.clazz(
///     meta.type<prefix0.CompleteService>(),
///     [prefix0.FullReflection()],
///     [
///       meta.constructor(
///         () => prefix0.CompleteService.new as Function,
///         [meta.parameter(meta.type<prefix1.Logger>(), 'logger', 0, false, false)],
///       ),
///     ],
///     [
///       meta.method(
///         meta.type<void>(),
///         'process',
///         (instance) => instance.process,
///         [meta.parameter(meta.type<String>(), 'data', 0, false, false)],
///       ),
///     ],
///     [
///       meta.getter(
///         meta.type<String>(),
///         'status',
///         (instance) => instance.status,
///       ),
///     ],
///     [
///       meta.setter(
///         meta.type<String>(),
///         'status',
///         (instance, value) => instance.status = value,
///       ),
///     ],
///   ),
/// );
/// ```
abstract class DeclarationsCapability
    implements
        MethodsCapability,
        ConstructorsCapability,
        GettersCapability,
        SettersCapability,
        ParametersCapability {
  const DeclarationsCapability();
}

/// Marks a class as a service to be registered in the dependency injection container.
///
/// Services are registered as **factories** by default (creating new instances on each request).
/// Use [Singleton] for shared instances, or set [shared] to true.
///
/// **IMPORTANT:** [Service] and [Singleton] annotations can only be used at class level,
/// NOT inside [@Module] classes. For module providers, use [Provide], [ProvideSingleton],
/// or [ProvideEager] instead.
///
/// **Note:** [Service] does NOT support async factories. Services must be synchronously instantiable.
/// For async initialization, use module providers with [Provide], [ProvideSingleton], or [ProvideEager].
///
/// By default, [Service] provides no metadata capabilities. To enable metadata generation,
/// extend this class and implement the desired capability interfaces.
///
/// **Example - Basic service:**
/// ```dart
/// @Service()
/// class UserRepository {
///   UserRepository(DatabaseService db);
/// }
///
/// // Generated code:
/// builder.registerFactory<UserRepository>(
///   (i) => UserRepository(i()),
/// );
/// ```
///
/// **Example - Named service:**
/// ```dart
/// @Service(name: 'userRepo')
/// class UserRepository {
///   UserRepository(DatabaseService db);
/// }
///
/// // Generated code:
/// builder.registerFactory<UserRepository>(
///   (i) => UserRepository(i()),
///   name: 'userRepo',
/// );
///
/// // Usage:
/// final repo = injector.get<UserRepository>('userRepo');
/// ```
///
/// **Example - Service with constructor metadata:**
/// ```dart
/// class InjectableService extends Service implements ConstructorsCapability {
///   const InjectableService({super.name, super.shared});
/// }
///
/// @InjectableService()
/// class ApiService {
///   ApiService(HttpClient client);
/// }
///
/// // Generated code for DI:
/// builder.registerFactory<ApiService>(
///   (i) => ApiService(i()),
/// );
/// ```
///
/// **Example - Environment-specific service:**
/// ```dart
/// @Service(env: 'production', priority: 10)
/// class ProductionLogger implements Logger {
///   // Only registered when env == 'production'
/// }
///
/// // Generated code:
/// if (env == 'production') {
///   builder.registerFactory<ProductionLogger>(
///     (i) => ProductionLogger(),
///   );
/// }
/// ```
@Target({TargetKind.classType})
class Service implements ReflectCapability {
  /// The environment in which this service should be registered.
  ///
  /// When specified, the service will only be registered if the current environment matches this value.
  /// If null, the service is registered in all environments.
  final String? env;

  /// A unique name for this service registration.
  ///
  /// Allows multiple implementations of the same type to be registered with different names.
  /// Use `injector.get<Type>(name: 'serviceName')` to retrieve named services.
  final String? name;

  /// Whether this service should be shared (singleton) or created fresh each time (factory).
  ///
  /// - `true`: A single instance is created and shared across all requests (singleton pattern)
  /// - `false`: A new instance is created for each request (factory pattern)
  ///
  /// Defaults to `false` for [Service] and `true` for [Singleton].
  final bool shared;

  /// The registration priority for this service.
  ///
  /// Services with higher priority values are registered first.
  /// Useful when registration order matters, such as for services with side effects or initialization logic.
  final int? priority;

  const Service({
    this.name,
    this.env,
    this.priority,
    this.shared = false,
  });
}

/// Marks a class as a singleton service to be registered in the dependency injection container.
///
/// A convenience annotation that is equivalent to `@Service(shared: true)`.
/// Singleton services are instantiated once and the same instance is returned for all requests.
///
/// **IMPORTANT:** [Singleton] and [Service] annotations can only be used at class level,
/// NOT inside [@Module] classes. For module providers, use [ProvideSingleton] instead.
///
/// **Note:** [Singleton] does NOT support async factories. Services must be synchronously instantiable.
/// For async initialization, use module providers with [ProvideSingleton] or [ProvideEager].
///
/// Like [Service], this provides no metadata capabilities by default. Extend this class
/// and implement capability interfaces to enable metadata generation.
///
/// **Example - Basic singleton:**
/// ```dart
/// @Singleton()
/// class AppConfig {
///   final String apiKey;
///   AppConfig(this.apiKey);
/// }
///
/// // Generated code:
/// builder.registerSingleton<AppConfig>(
///   (i) => AppConfig(i()),
/// );
/// ```
///
/// **Example - Singleton with constructor metadata:**
/// ```dart
/// class InjectableSingleton extends Singleton implements ConstructorsCapability {
///   const InjectableSingleton({super.name});
/// }
///
/// @InjectableSingleton()
/// class CacheService {
///   CacheService(Config config);
/// }
///
/// // Generated code for DI:
/// builder.registerSingleton<CacheService>(
///   (i) => CacheService(i()),
/// );
/// ```
///
/// **Example - Named singleton:**
/// ```dart
/// @Singleton(name: 'mainCache')
/// class CacheService {
///   CacheService();
/// }
///
/// // Generated code:
/// builder.registerSingleton<CacheService>(
///   (i) => CacheService(),
///   name: 'mainCache',
/// );
///
/// // Usage:
/// final cache = injector.get<CacheService>('mainCache');
/// ```
@Target({TargetKind.classType})
class Singleton extends Service {
  const Singleton({
    super.name,
    super.env,
    super.priority,
  }) : super(shared: true);
}

/// Marks a method that must be called after the service is constructed.
///
/// Required methods are invoked automatically after dependency injection, ensuring proper initialization.
/// They can accept dependencies through their parameters, which are automatically resolved by the injector.
///
/// **Example:**
/// ```dart
/// @Service()
/// class EmailService {
///   late SmtpClient _client;
///
///   @Required()
///   void initialize(SmtpClient client) {
///     _client = client;
///     _client.connect();
///   }
///
///   @Required()
///   Future<void> loadTemplates(TemplateLoader loader) async {
///     await loader.loadAll();
///   }
/// }
/// ```
///
/// The generated code will call these methods in order:
/// ```dart
/// builder.registerFactory<EmailService>(
///   (i) => EmailService(),
///   onCreate: (instance, i) async {
///     instance.initialize(i());
///     await instance.loadTemplates(i());
///   }
/// );
/// ```
@Target({TargetKind.method, TargetKind.getter})
class Required {
  const Required();
}

/// Marks which constructor should be used for dependency injection.
///
/// When a class has multiple constructors, use this annotation to specify which one
/// the dependency injection container should use for instantiation.
///
/// **Example:**
/// ```dart
/// @Service()
/// class PaymentProcessor {
///   PaymentProcessor(Logger logger);
///
///   @Constructor()
///   PaymentProcessor.withConfig(Logger logger, PaymentConfig config);
///
///   PaymentProcessor.testing();
/// }
/// ```
///
/// The generated code will use the annotated constructor:
/// ```dart
/// builder.registerFactory<PaymentProcessor>(
///   (i) => PaymentProcessor.withConfig(i(), i()),
/// );
/// ```
///
/// Without this annotation, the unnamed constructor (or first constructor) is used by default.
@Target({TargetKind.constructor})
class Constructor {
  const Constructor();
}

/// Marks a class as a module that provides service configurations.
///
/// Modules are classes that contain methods annotated with [Provide], [ProvideSingleton],
/// or [ProvideEager] to provide service instances. The module itself is registered as a
/// singleton and its methods are called to create services.
///
/// **IMPORTANT:** Inside modules, use [Provide], [ProvideSingleton], or [ProvideEager].
/// DO NOT use [@Service] or [@Singleton] annotations on module methods.
///
/// By default, [Module] does NOT provide any metadata capabilities. To enable metadata
/// generation for the module class itself, create a custom module annotation that implements
/// the desired capability interfaces.
///
/// **Example - Basic module:**
/// ```dart
/// @Module()
/// class NetworkModule {
///   @ProvideSingleton()
///   HttpClient createHttpClient() {
///     return HttpClient()..timeout = Duration(seconds: 30);
///   }
///
///   @Provide()
///   ApiService createApiService(HttpClient client) {
///     return ApiService(client);
///   }
///
///   @ProvideEager()
///   Future<ApiConfig> loadApiConfig() async {
///     final config = await fetchConfigFromFile();
///     return config;
///   }
///
///   @Boot()
///   Future<void> warmUpConnection(HttpClient client) async {
///     await client.get('https://api.example.com/health');
///   }
/// }
/// ```
///
/// **Example - Module with method metadata:**
/// ```dart
/// class ReflectiveModule extends Module implements MethodsCapability {
///   const ReflectiveModule();
/// }
///
/// @ReflectiveModule()
/// class ServicesModule {
///   @Provide()
///   UserService createUserService() => UserService();
///   // Method metadata will be generated for createUserService()
/// }
/// ```
@Target({TargetKind.classType})
class Module {
  const Module();
}

/// Marks a method in a module to be executed during the boot phase.
///
/// Boot methods are called after all services are registered but before the application starts.
/// They are useful for initialization tasks, warmup operations, or validation.
/// Dependencies can be injected through method parameters.
///
/// **Example:**
/// ```dart
/// @Module()
/// class DatabaseModule {
///   @ProvideSingleton()
///   Database createDatabase() => Database();
///
///   @Boot()
///   Future<void> runMigrations(Database db) async {
///     await db.migrate();
///   }
///
///   @Boot()
///   void validateConnection(Database db) {
///     if (!db.isConnected) {
///       throw Exception('Database connection failed');
///     }
///   }
/// }
/// ```
///
/// The generated boot method will execute these in order:
/// ```dart
/// @override
/// Future<void> boot(Injector i) async {
///   await i<DatabaseModule>().runMigrations(i());
///   i<DatabaseModule>().validateConnection(i());
/// }
/// ```
@Target({TargetKind.method, TargetKind.getter})
class Boot {
  const Boot();
}

/// Marks a method in a module as a provider for a service.
///
/// Provider methods are called to create service instances. They can accept dependencies
/// through their parameters, which are automatically resolved by the injector.
///
/// By default, [Provide] creates **singleton** instances ([shared] = true). Use [shared] = false
/// for factory behavior, or use [ProvideSingleton] for explicit singleton semantics.
///
/// **Async Support:** Provider methods can return `Future<T>` for async initialization.
///
/// **Example - Basic provider:**
/// ```dart
/// @Module()
/// class AppModule {
///   @Provide()
///   Logger createLogger() {
///     return ConsoleLogger();
///   }
///
///   @Provide()
///   ApiService createApiService(HttpClient client, Logger logger) {
///     return ApiService(client, logger);
///   }
/// }
///
/// // Generated code:
/// builder.registerSingleton<Logger>(
///   (i) => i<AppModule>().createLogger(),
/// );
/// builder.registerSingleton<ApiService>(
///   (i) => i<AppModule>().createApiService(i(), i()),
/// );
/// ```
///
/// **Example - Named provider:**
/// ```dart
/// @Module()
/// class CacheModule {
///   @Provide(name: 'userCache')
///   Cache createUserCache() => MemoryCache();
///
///   @Provide(name: 'apiCache')
///   Cache createApiCache() => RedisCache();
/// }
///
/// // Generated code:
/// builder.registerSingleton<Cache>(
///   (i) => i<CacheModule>().createUserCache(),
///   name: 'userCache',
/// );
/// builder.registerSingleton<Cache>(
///   (i) => i<CacheModule>().createApiCache(),
///   name: 'apiCache',
/// );
///
/// // Usage:
/// final userCache = injector.get<Cache>('userCache');
/// final apiCache = injector.get<Cache>('apiCache');
/// ```
///
/// **Example - Factory provider:**
/// ```dart
/// @Module()
/// class HandlerModule {
///   @Provide(shared: false)
///   RequestHandler createHandler() => RequestHandler();
/// }
///
/// // Generated code:
/// builder.registerFactory<RequestHandler>(
///   (i) => i<HandlerModule>().createHandler(),
/// );
/// ```
///
/// **Example - Async provider:**
/// ```dart
/// @Module()
/// class ConfigModule {
///   @Provide()
///   Future<AppConfig> loadConfig() async {
///     return await AppConfig.fromFile('config.json');
///   }
/// }
///
/// // Generated code:
/// builder.registerAsyncSingleton<AppConfig>(
///   (i) async => await i<ConfigModule>().loadConfig(),
/// );
///
/// // Usage:
/// final config = await injector.getAsync<AppConfig>();
/// ```
///
/// **Example - Environment-specific provider:**
/// ```dart
/// @Module()
/// class LoggerModule {
///   @Provide(env: 'development')
///   Logger createDevLogger() => ConsoleLogger();
///
///   @Provide(env: 'production')
///   Logger createProdLogger() => FileLogger();
/// }
///
/// // Generated code:
/// if (env == 'development') {
///   builder.registerSingleton<Logger>(
///     (i) => i<LoggerModule>().createDevLogger(),
///   );
/// }
/// if (env == 'production') {
///   builder.registerSingleton<Logger>(
///     (i) => i<LoggerModule>().createProdLogger(),
///   );
/// }
/// ```
class Provide {
  /// The environment in which this provider should be registered.
  ///
  /// When specified, the provider will only be registered if the current environment matches this value.
  /// If null, the provider is registered in all environments.
  final String? env;

  /// A unique name for this provider registration.
  ///
  /// Allows multiple providers of the same return type to be registered with different names.
  final String? name;

  /// Whether the provided service should be shared (singleton) or created fresh each time (factory).
  ///
  /// - `true`: A single instance is created and shared across all requests (singleton pattern)
  /// - `false`: A new instance is created for each request (factory pattern)
  ///
  /// Defaults to `true`.
  final bool shared;

  /// The registration priority for this provider.
  ///
  /// Providers with higher priority values are registered first.
  final int? priority;

  const Provide({
    this.name,
    this.env,
    this.priority,
    this.shared = false,
  });
}

/// Marks a method in a module as a singleton provider.
///
/// A convenience annotation that is equivalent to `@Provide(shared: true)`.
/// This is the recommended way to explicitly mark singleton providers in modules.
///
/// **Async Support:** Provider methods can return `Future<T>` for async initialization.
///
/// **Example - Basic singleton provider:**
/// ```dart
/// @Module()
/// class CoreModule {
///   @ProvideSingleton()
///   DatabaseConnection createConnection() => DatabaseConnection();
///
///   @ProvideSingleton(name: 'mainCache')
///   Cache createCache() => MemoryCache();
/// }
///
/// // Generated code:
/// builder.registerSingleton<DatabaseConnection>(
///   (i) => i<CoreModule>().createConnection(),
/// );
/// builder.registerSingleton<Cache>(
///   (i) => i<CoreModule>().createCache(),
///   name: 'mainCache',
/// );
/// ```
///
/// **Example - Async singleton provider:**
/// ```dart
/// @Module()
/// class DatabaseModule {
///   @ProvideSingleton()
///   Future<Database> createDatabase() async {
///     final db = Database();
///     await db.connect();
///     return db;
///   }
/// }
///
/// // Generated code:
/// builder.registerAsyncSingleton<Database>(
///   (i) async => await i<DatabaseModule>().createDatabase(),
/// );
///
/// // Usage:
/// final db = await injector.getAsync<Database>();
/// ```
class ProvideSingleton extends Provide {
  const ProvideSingleton({
    super.name,
    super.env,
    super.priority,
  }) : super(shared: true);
}

/// Marks a method in a module as an eager provider.
///
/// Eager providers are instantiated immediately during the boot phase (before the application starts),
/// rather than lazily when first requested. This is useful for services that need to be initialized
/// before the application starts, such as configuration loaders or database connections.
///
/// Eager providers are always singletons ([shared] is always true) and must return a `Future<T>`.
///
/// **Example - Basic eager provider:**
/// ```dart
/// @Module()
/// class ConfigModule {
///   @ProvideEager()
///   Future<AppConfig> loadConfig() async {
///     return await AppConfig.fromFile('config.json');
///   }
/// }
///
/// // Generated code:
/// builder.registerEagerSingleton<AppConfig>(
///   (i) async => await i<ConfigModule>().loadConfig(),
/// );
/// ```
///
/// **Example - Eager database connection:**
/// ```dart
/// @Module()
/// class DatabaseModule {
///   @ProvideEager()
///   Future<DatabaseConnection> createConnection() async {
///     final conn = DatabaseConnection();
///     await conn.connect();
///     await conn.runMigrations();
///     return conn;
///   }
/// }
///
/// // Generated code:
/// builder.registerEagerSingleton<DatabaseConnection>(
///   (i) async => await i<DatabaseModule>().createConnection(),
/// );
///
/// // The connection is established during boot, before any routes are handled
/// ```
///
/// **Example - Preloading data with generic types:**
/// ```dart
/// @Module()
/// class DataModule {
///   @ProvideEager(name: 'preloadedUsers')
///   Future<List<User>> preloadUsers(Database db) async {
///     return await db.query('SELECT * FROM users');
///   }
/// }
///
/// // Generated code:
/// builder.registerEagerSingleton<List<User>>(
///   (i) async => await i<DataModule>().preloadUsers(i()),
///   name: 'preloadedUsers',
/// );
///
/// // Usage (after boot):
/// final users = injector.get<List<User>>('preloadedUsers'); // Already loaded
/// ```
@Target({TargetKind.getter, TargetKind.method})
class ProvideEager extends Provide {
  const ProvideEager({
    super.name,
    super.env,
    super.priority,
    super.shared = true,
  });
}

/// Configures automatic bundle generation by scanning source files.
///
/// This annotation marks a class that will have a generated bundle implementation.
/// The generator scans the specified paths for modules, services, and metadata annotations,
/// then generates registration code.
///
/// **Metadata Generation Rules:**
/// - Only annotations that implement capability interfaces generate metadata
/// - If an annotation has no capabilities, no metadata is generated (only DI registration)
/// - Class-level capabilities generate metadata for all matching members
/// - Member-level capabilities generate metadata for that member AND its containing class
///
/// **Example:**
/// ```dart
/// @AutoBundle(
///   paths: ['lib/**.dart'],
///   excludePaths: ['lib/generated/**.dart', 'lib/**_test.dart'],
/// )
/// abstract class AppBundle implements Bundle {}
/// ```
///
/// This generates `app_bundle.bundle.dart` containing:
/// ```dart
/// abstract class AbstractAppBundle implements Bundle {
///   @override
///   Future<void> build(InjectorBuilder builder, String env) async {
///     // Module registrations
///     // Service registrations
///   }
///
///   @override
///   Future<void> buildMetadata(MetadataRegistryBuilder metaBuilder, String env) async {
///     // Metadata registrations (only for annotations with capabilities)
///   }
///
///   @override
///   Future<void> boot(Injector i) async {
///     // Boot method calls
///   }
/// }
/// ```
@Target({TargetKind.classType})
class AutoBundle {
  /// List of glob patterns specifying which files to scan for annotations.
  ///
  /// Defaults to `['lib/**.dart']` which scans all Dart files in the lib directory.
  final List<String> paths;

  /// List of glob patterns specifying which files to exclude from scanning.
  ///
  /// Useful for excluding generated files, test files, or specific directories.
  ///
  /// **Example:**
  /// ```dart
  /// @AutoBundle(
  ///   paths: ['lib/**.dart'],
  ///   excludePaths: [
  ///     'lib/generated/**.dart',
  ///     'lib/**_test.dart',
  ///     'lib/internal/**.dart',
  ///   ],
  /// )
  /// ```
  final List<String> excludePaths;

  const AutoBundle({
    this.paths = const ['lib/**.dart'],
    this.excludePaths = const [],
  });
}

/// Marks a parameter for dependency injection with specific resolution rules.
///
/// This annotation is used on constructor and method parameters to control how
/// dependencies are resolved from the injector. It allows you to:
/// - Specify a concrete type when the parameter type is abstract/interface
/// - Specify a named instance when multiple instances of the same type exist
///
/// **Type Resolution:**
/// When a parameter type is abstract and you want to inject a specific concrete implementation,
/// use the generic type parameter:
///
/// ```dart
/// @Service()
/// class Car implements Vehicle {}
///
/// @Service()
/// class Truck implements Vehicle {}
///
/// abstract class Vehicle {}
///
/// @Service()
/// class Bar {
///   final Vehicle foo;
///   Bar(@Inject<Car>() this.foo); // Injects Car specifically
/// }
///
/// // Generated code:
/// builder.registerFactory<Bar>((i) => Bar(i<Car>()));
/// ```
///
/// **Named Resolution:**
/// When you have multiple instances of the same type registered with different names:
///
/// ```dart
/// @Service(name: 'car')
/// class Car implements Vehicle {}
///
/// @Service(name: 'truck')
/// class Truck implements Vehicle {}
///
/// abstract class Vehicle {}
///
/// @Service()
/// class Bar {
///   final Vehicle foo;
///   Bar(@Inject(name: 'car') this.foo); // Injects the 'car' named instance
/// }
///
/// // Generated code:
/// builder.registerFactory<Bar>((i) => Bar(i<Vehicle>('car')));
/// ```
///
/// **Works in multiple contexts:**
/// - Service constructors
/// - Provider method parameters
/// - Boot method parameters
///
/// **Example with providers:**
/// ```dart
/// @Module()
/// class AppModule {
///   @Provide()
///   RequestHandler createHandler(@Inject<ProductionLogger>() Logger logger) {
///     return RequestHandler(logger);
///   }
/// }
///
/// // Generated code:
/// builder.registerSingleton<RequestHandler>(
///   (i) => i<AppModule>().createHandler(i<ProductionLogger>()),
/// );
/// ```
@Target({TargetKind.parameter})
class Inject<T> with GenericCaller<T> {
  /// The name of the instance to resolve when multiple instances of the same type exist.
  ///
  /// If provided, the injector will look for an instance registered with this specific name.
  /// If null, the default (unnamed) instance will be resolved.
  final String? name;

  const Inject({this.name});
}
