
import 'package:forge_framework/forge_framework.dart';
import 'package:forge_orm/forge_orm.dart';

import '../entity/user.dart';

@Controller(prefix: '/users')
class UsersController {
  final Orm orm;

  UsersController(this.orm);

  @Route.get()
  Future<List<User>> getUsers(Request request) async {
    return await orm.getRepository<User>().createQueryBuilder().fetchAll();
  }

  @Route.get('/create')
  Future<User> createUser(
    @MapRequestQuery() CreateUserRequest request,
    @Inject() EntityManager em,
  ) async {
    final user = User()
      ..name = request.name
      ..email = request.email;

    em.persist(user);

    try {
      await em.flush();
    } on ConstraintViolationException catch (e) {
      if (e.constraintType == ConstraintType.unique) {
        throw HttpException.badRequest(
          'A user with this email already exists.',
        );
      }
      rethrow;
    }

    return user;
  }
}

@Mappable()
class CreateUserRequest {
  @NotBlank()
  final String name;
  @NotBlank()
  @Email()
  final String email;

  CreateUserRequest(this.name, this.email);
}
