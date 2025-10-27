import 'package:forge_orm/forge_orm.dart';
import 'package:test/test.dart';
import 'test_helper.dart';
import 'test_entities.dart';

void main() {
  late TestHelper helper;

  setUp(() async {
    helper = TestHelper();
    await helper.setup();
  });

  tearDown(() async {
    await helper.teardown();
  });

  group('CRUD Operations Tests', () {
    group('Create (Insert)', () {
      test('should insert a new user', () async {
        final user = User()
          ..name = 'Jane Doe'
          ..email = 'jane@example.com'
          ..age = 28;

        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        expect(user.id, isNotNull);
        expect(user.id! > 0, true);

        final count = await helper.countRecords('users');
        expect(count, 1);
      });

      test('should insert multiple users', () async {
        final user1 = User()
          ..name = 'User 1'
          ..email = 'user1@example.com';
        final user2 = User()
          ..name = 'User 2'
          ..email = 'user2@example.com';
        final user3 = User()
          ..name = 'User 3'
          ..email = 'user3@example.com';

        helper.orm.entityManager.persist(user1);
        helper.orm.entityManager.persist(user2);
        helper.orm.entityManager.persist(user3);

        await helper.orm.entityManager.flush();

        expect(user1.id, 1);
        expect(user2.id, 2);
        expect(user3.id, 3);

        final count = await helper.countRecords('users');
        expect(count, 3);
      });

      test('should handle null values correctly', () async {
        final user = User()
          ..name = 'John'
          ..email = 'john@example.com'
          ..age = null;

        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        expect(user.id, isNotNull);

        final result = await helper.executeRaw(
          'SELECT age FROM users WHERE id = ?',
          [user.id],
        );

        expect(result.rows.first['age'], null);
      });

      test('should set timestamps on create', () async {
        final now = DateTime.now();
        final user = User()
          ..name = 'Test User'
          ..email = 'test@example.com'
          ..createdAt = now
          ..updatedAt = now;

        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        expect(user.id, isNotNull);
        expect(user.createdAt, isNotNull);
        expect(user.updatedAt, isNotNull);
      });
    });

    group('Read (Query)', () {
      test('should find user by id', () async {
        final user = User()
          ..name = 'Find Me'
          ..email = 'findme@example.com';
        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        final repository = helper.orm.getRepository<User>();
        final found = await repository.find(user.id);

        expect(found, isNotNull);
        expect(found!.id, user.id);
        expect(found.name, 'Find Me');
        expect(found.email, 'findme@example.com');
      });

      test('should return null for non-existent id', () async {
        final repository = helper.orm.getRepository<User>();
        final found = await repository.find(9999);

        expect(found, null);
      });

      test('should find all users', () async {
        final user1 = User()
          ..name = 'User 1'
          ..email = 'user1@example.com';
        final user2 = User()
          ..name = 'User 2'
          ..email = 'user2@example.com';

        helper.orm.entityManager.persist(user1);
        helper.orm.entityManager.persist(user2);
        await helper.orm.entityManager.flush();

        final repository = helper.orm.getRepository<User>();
        final users = await repository.findAll();

        expect(users.length, 2);
        expect(users[0].name, 'User 1');
        expect(users[1].name, 'User 2');
      });

      test('should find by criteria', () async {
        final user1 = User()
          ..name = 'Alice'
          ..email = 'alice@example.com'
          ..age = 25;
        final user2 = User()
          ..name = 'Bob'
          ..email = 'bob@example.com'
          ..age = 30;
        final user3 = User()
          ..name = 'Charlie'
          ..email = 'charlie@example.com'
          ..age = 25;

        helper.orm.entityManager.persist(user1);
        helper.orm.entityManager.persist(user2);
        helper.orm.entityManager.persist(user3);
        await helper.orm.entityManager.flush();

        final repository = helper.orm.getRepository<User>();
        final users = await repository.findBy({'age': 25});

        expect(users.length, 2);
        expect(users.every((u) => u.age == 25), true);
      });

      test('should find one by criteria', () async {
        final user = User()
          ..name = 'Unique'
          ..email = 'unique@example.com';
        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        final repository = helper.orm.getRepository<User>();
        final found = await repository.findOneBy({
          'email': 'unique@example.com',
        });

        expect(found, isNotNull);
        expect(found!.name, 'Unique');
      });

      test('should count entities', () async {
        final user1 = User()
          ..name = 'User 1'
          ..email = 'user1@example.com';
        final user2 = User()
          ..name = 'User 2'
          ..email = 'user2@example.com';

        helper.orm.entityManager.persist(user1);
        helper.orm.entityManager.persist(user2);
        await helper.orm.entityManager.flush();

        final repository = helper.orm.getRepository<User>();
        final count = await repository.count();

        expect(count, 2);
      });

      test('should check if entity exists', () async {
        final user = User()
          ..name = 'Exists'
          ..email = 'exists@example.com';
        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        final repository = helper.orm.getRepository<User>();
        final exists = await repository.exists(user.id);
        final notExists = await repository.exists(9999);

        expect(exists, true);
        expect(notExists, false);
      });
    });

    group('Update', () {
      test('should update user fields', () async {
        final user = User()
          ..name = 'Original'
          ..email = 'original@example.com';
        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        user.name = 'Updated';
        user.email = 'updated@example.com';
        user.age = 35;

        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        final repository = helper.orm.getRepository<User>();
        final updated = await repository.find(user.id);

        expect(updated!.name, 'Updated');
        expect(updated.email, 'updated@example.com');
        expect(updated.age, 35);
      });

      test('should update only changed fields', () async {
        final user = User()
          ..name = 'Test'
          ..email = 'test@example.com'
          ..age = 20;
        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        user.age = 21;

        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        final repository = helper.orm.getRepository<User>();
        final updated = await repository.find(user.id);

        expect(updated!.name, 'Test');
        expect(updated.age, 21);
      });

      test('should handle null updates', () async {
        final user = User()
          ..name = 'Test'
          ..email = 'test@example.com'
          ..age = 30;
        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        user.age = null;

        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        final repository = helper.orm.getRepository<User>();
        final updated = await repository.find(user.id);

        expect(updated!.age, null);
      });
    });

    group('Delete', () {
      test('should delete a user', () async {
        final user = User()
          ..name = 'Delete Me'
          ..email = 'delete@example.com';
        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        final userId = user.id;
        expect(await helper.recordExists('users', 'id', userId), true);

        helper.orm.entityManager.remove(user);
        await helper.orm.entityManager.flush();

        expect(await helper.recordExists('users', 'id', userId), false);
      });

      test('should delete multiple users', () async {
        final user1 = User()
          ..name = 'User 1'
          ..email = 'user1@example.com';
        final user2 = User()
          ..name = 'User 2'
          ..email = 'user2@example.com';

        helper.orm.entityManager.persist(user1);
        helper.orm.entityManager.persist(user2);
        await helper.orm.entityManager.flush();

        helper.orm.entityManager.remove(user1);
        helper.orm.entityManager.remove(user2);
        await helper.orm.entityManager.flush();

        final count = await helper.countRecords('users');
        expect(count, 0);
      });

      test('should use repository delete method', () async {
        final user = User()
          ..name = 'Delete'
          ..email = 'delete@example.com';
        await helper.orm.getRepository<User>().save(user);

        final userId = user.id;
        expect(await helper.recordExists('users', 'id', userId), true);

        await helper.orm.getRepository<User>().delete(user);

        expect(await helper.recordExists('users', 'id', userId), false);
      });
    });

    group('Repository Methods', () {
      test('should use save method (persist + flush)', () async {
        final user = User()
          ..name = 'Quick Save'
          ..email = 'save@example.com';
        await helper.orm.getRepository<User>().save(user);

        expect(user.id, isNotNull);
        expect(await helper.countRecords('users'), 1);
      });

      test('should throw EntityNotFoundException with findOrFail', () async {
        final repository = helper.orm.getRepository<User>();

        expect(
          () async => await repository.findOrFail(9999),
          throwsA(isA<EntityNotFoundException>()),
        );
      });

      test('should find by criteria with limit and offset', () async {
        for (int i = 1; i <= 10; i++) {
          final user = User()
            ..name = 'User $i'
            ..email = 'user$i@example.com';
          helper.orm.entityManager.persist(user);
        }
        await helper.orm.entityManager.flush();

        final repository = helper.orm.getRepository<User>();
        final users = await repository.findBy({}, limit: 5, offset: 3);

        expect(users.length, 5);
      });
    });
  });
}
