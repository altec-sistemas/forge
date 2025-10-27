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

  group('Transaction Tests', () {
    test('should commit transaction successfully', () async {
      final user = User()
        ..name = 'Transaction User'
        ..email = 'trans@example.com';

      helper.orm.entityManager.persist(user);
      await helper.orm.entityManager.flush();

      expect(user.id, isNotNull);
      final count = await helper.countRecords('users');
      expect(count, 1);
    });

    test('should rollback transaction on error', () async {
      final user = User()
        ..name = 'Will Rollback'
        ..email = 'rollback@example.com';

      helper.orm.entityManager.persist(user);

      try {
        await helper.orm.database.connection.transaction((conn) async {
          await helper.orm.database.connection.execute(
            'INSERT INTO users (name, email) VALUES (?, ?)',
            [user.name, user.email],
          );
          throw Exception('Forced error');
        });
      } catch (e) {
        // Expected
      }

      final count = await helper.countRecords('users');
      expect(count, 0);
    });

    test('should handle multiple operations in transaction', () async {
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

      expect(user1.id, isNotNull);
      expect(user2.id, isNotNull);
      expect(user3.id, isNotNull);

      final count = await helper.countRecords('users');
      expect(count, 3);
    });

    test('should rollback all operations on error during flush', () async {
      final user1 = User()
        ..name = 'User 1'
        ..email = 'user1@example.com';
      final user2 = User()
        ..name = 'User 2'
        ..email = 'invalid-email'; // Assuming validation might fail

      helper.orm.entityManager.persist(user1);
      helper.orm.entityManager.persist(user2);

      try {
        // Manually create transaction that will fail
        await helper.orm.database.connection.transaction((conn) async {
          await conn.execute(
            'INSERT INTO users (name, email) VALUES (?, ?)',
            [user1.name, user1.email],
          );
          await conn.execute(
            'INSERT INTO users (name, email) VALUES (?, ?)',
            [user2.name, user2.email],
          );
          throw Exception('Error after second user');
        });
      } catch (e) {
        // Expected
      }

      final count = await helper.countRecords('users');
      expect(count, 0);
    });

    test('should handle nested persist operations', () async {
      final user = User()
        ..name = 'Parent'
        ..email = 'parent@example.com';
      final profile = Profile()..bio = 'Bio';
      final post = Post()
        ..title = 'Post'
        ..content = 'Content';

      user.profile = profile;
      user.posts = [post];

      helper.orm.entityManager.persist(user);
      await helper.orm.entityManager.flush();

      expect(user.id, isNotNull);
      expect(profile.id, isNotNull);
      expect(post.id, isNotNull);

      expect(await helper.countRecords('users'), 1);
      expect(await helper.countRecords('profiles'), 1);
      expect(await helper.countRecords('posts'), 1);
    });

    test('should handle update with flush', () async {
      final user = User()
        ..name = 'Original'
        ..email = 'original@example.com';
      helper.orm.entityManager.persist(user);
      await helper.orm.entityManager.flush();

      user.name = 'Updated';
      helper.orm.entityManager.persist(user);
      await helper.orm.entityManager.flush();

      final repository = helper.orm.getRepository<User>();
      final updated = await repository.find(user.id);
      expect(updated!.name, 'Updated');
    });

    test('should rollback update on flush error', () async {
      final user = User()
        ..name = 'Original'
        ..email = 'original@example.com';
      helper.orm.entityManager.persist(user);
      await helper.orm.entityManager.flush();

      final userId = user.id!;

      try {
        await helper.orm.database.connection.transaction((conn) async {
          await conn.execute(
            'UPDATE users SET name = ? WHERE id = ?',
            ['Should Rollback', userId],
          );
          throw Exception('Rollback update');
        });
      } catch (e) {
        // Expected
      }

      final repository = helper.orm.getRepository<User>();
      final unchanged = await repository.find(userId);
      expect(unchanged!.name, 'Original');
    });

    test('should handle delete with flush', () async {
      final user = User()
        ..name = 'Delete Me'
        ..email = 'delete@example.com';
      helper.orm.entityManager.persist(user);
      await helper.orm.entityManager.flush();

      final userId = user.id;

      helper.orm.entityManager.remove(user);
      await helper.orm.entityManager.flush();

      expect(await helper.recordExists('users', 'id', userId), false);
    });

    test('should rollback delete on error', () async {
      final user = User()
        ..name = 'Keep Me'
        ..email = 'keep@example.com';
      helper.orm.entityManager.persist(user);
      await helper.orm.entityManager.flush();

      final userId = user.id!;

      try {
        await helper.orm.database.connection.transaction((conn) async {
          await conn.execute('DELETE FROM users WHERE id = ?', [userId]);
          throw Exception('Rollback delete');
        });
      } catch (e) {
        // Expected
      }

      expect(await helper.recordExists('users', 'id', userId), true);
    });

    test('should handle complex scenario with mixed operations', () async {
      final existingUser = User()
        ..name = 'Existing'
        ..email = 'existing@example.com';
      helper.orm.entityManager.persist(existingUser);
      await helper.orm.entityManager.flush();

      final newUser = User()
        ..name = 'New'
        ..email = 'new@example.com';
      helper.orm.entityManager.persist(newUser);

      existingUser.name = 'Existing Updated';
      helper.orm.entityManager.persist(existingUser);

      final profile = Profile()..bio = 'New Bio';
      newUser.profile = profile;

      helper.orm.entityManager.persist(profile);
      await helper.orm.entityManager.flush();

      expect(newUser.id, isNotNull);
      expect(profile.id, isNotNull);

      final repository = helper.orm.getRepository<User>();
      final users = await repository.findAll();

      expect(users.length, 2);
      expect(users.any((u) => u.name == 'Existing Updated'), true);
      expect(users.any((u) => u.name == 'New'), true);
    });
  });
}
