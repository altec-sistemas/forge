import 'package:forge_framework/forge_framework.dart';

@Controller()
class HomeController {
  final List<User> _users = [
    User('John Doe', 'john.doe@email.com', '123'),
    User('Jane Smith', 'jane.smith@email.com', 'qwerty'),
  ];

  final Serializer _serializer;
  HomeController(this._serializer);

  late Validator _validator;

  /// called by the framework to inject the validator
  @Required()
  void setValidador(Validator validator) {
    _validator = validator;
  }

  @Route.get('/')
  Future<List<User>> users(Request request) async {
    return _users;
  }

  @Route.get('/users/create')
  Future<User> createUser(@MapRequestQuery() CreateUserRequest request) async {
    final newUser = User(request.name, request.email, request.password);
    _users.add(newUser);
    return newUser;
  }

  @Route.get('/hello')
  Response index(Request request, [@QueryParam() String name = 'Bob']) {
    /// u can validade manually like this
    _validator.validateOrThrow(name, All([NotBlank(), Length(min: 3)]));
    return Response.ok('Hello, World!, $name');
  }

  @Route.get('/pre-serialize')
  JsonResponse preSerialize() {
    return JsonResponse(
      _serializer.serialize(
        User('some', 'john@email', '123'),
        'json',
        SerializerContext(groups: ['public']),
      ),
    );
  }
}

@Mappable()
class User {
  @Property(name: 'user_name')
  final String name;
  final String email;
  @Ignore()
  final String password;

  User(this.name, this.email, this.password);
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
  final String password;

  CreateUserRequest(this.name, this.email, this.password);
}

@Service()
class SomeListener {
  @AsEventListener()
  void onRequest(HttpKernelRequestEvent event) {
    print('Request received: ${event.context.request.requestedUri}');
  }

  @AsEventListener()
  void onHttpKernelException(HttpKernelExceptionEvent event) {
    print('Error occurred: ${event.exception} ${event.stackTrace}');
  }

  @AsEventListener()
  void onHttpServerStarted(HttpRunnerStarted event) {
    print('HTTP Server started on port:  ${event.port}');
  }
}

@Service()
class SomeNamedService {}

@Service()
class OtherService {
  final SomeNamedService someNamedService;
  OtherService(this.someNamedService);
}

abstract class Payment {
  bool process(double amount);
}

@Service(name: 'credit_card')
class CreditCardPayment implements Payment {
  @override
  bool process(double amount) {
    print('Processing credit card payment of \$$amount');
    return true;
  }
}

@Service(name: 'paypal')
class PaypalPayment implements Payment {
  @override
  bool process(double amount) {
    print('Processing PayPal payment of \$$amount');
    return true;
  }
}

/// resolve service interface with name 'paypal'
@Service()
class PaymentService {
  final Payment paymentMethod;
  PaymentService(@Inject(name: 'paypal') this.paymentMethod);
}

/// configure validation messages to use Portuguese
@Module()
class ValidationModule {
  @Provide()
  ValidationMessageProvider get messageProvider =>
      PortugueseValidationMessageProvider();
}
