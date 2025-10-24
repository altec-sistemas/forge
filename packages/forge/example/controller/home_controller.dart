import 'package:forge/forge.dart';

@Controller()
class HomeController {
  final List<User> _users = [
    User('John Doe', 'john.doe@email.com', '123'),
    User('Jane Smith', 'jane.smith@email.com', 'qwerty'),
  ];

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
class SomeList {
  @AsEventListener()
  void onRequest(HttpKernelRequestEvent event) {
    print('Request received: ${event.context.request.requestedUri}');
  }
}

@Module()
class ValidationModule {
  @Provide()
  ValidationMessageProvider get messageProvider =>
      PortugueseValidationMessageProvider();
}
