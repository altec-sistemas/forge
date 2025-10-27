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

  group('EntityManager Tests', () {
    group('Persist Operations', () {
      test('should track pending insert operation', () async {
        final user = User()
          ..name = 'Test'
          ..email = 'test@example.com';

        helper.orm.entityManager.persist(user);

        expect(helper.orm.entityManager.hasPendingOperations, true);
        expect(helper.orm.entityManager.pendingOperationsCount, 1);
      });

      test('should clear pending operations after flush', () async {
        final user = User()
          ..name = 'Test'
          ..email = 'test@example.com';

        helper.orm.entityManager.persist(user);
        expect(helper.orm.entityManager.hasPendingOperations, true);

        await helper.orm.entityManager.flush();

        expect(helper.orm.entityManager.hasPendingOperations, false);
        expect(helper.orm.entityManager.pendingOperationsCount, 0);
      });

      test('should detect insert vs update based on primary key', () async {
        final user = User()
          ..name = 'Test'
          ..email = 'test@example.com';

        // First persist - should be insert
        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        expect(user.id, isNotNull);

        // Second persist - should be update
        user.name = 'Updated';
        helper.orm.entityManager.persist(user);

        expect(helper.orm.entityManager.hasPendingOperations, true);
      });

      test('should handle multiple persists before flush', () async {
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

        expect(helper.orm.entityManager.pendingOperationsCount, 3);

        await helper.orm.entityManager.flush();

        expect(user1.id, isNotNull);
        expect(user2.id, isNotNull);
        expect(user3.id, isNotNull);
      });

      test('should update entity ID after insert', () async {
        final user = User()
          ..name = 'Test'
          ..email = 'test@example.com';

        expect(user.id, null);

        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        expect(user.id, isNotNull);
        expect(user.id! > 0, true);
      });

      test('should not duplicate operations for same entity', () async {
        final user = User()
          ..name = 'Test'
          ..email = 'test@example.com';

        helper.orm.entityManager.persist(user);
        helper.orm.entityManager.persist(user);
        helper.orm.entityManager.persist(user);

        expect(helper.orm.entityManager.pendingOperationsCount, 1);
      });
    });

    group('Remove Operations', () {
      test('should track pending delete operation', () async {
        final user = User()
          ..name = 'Delete Me'
          ..email = 'delete@example.com';
        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        helper.orm.entityManager.remove(user);

        expect(helper.orm.entityManager.hasPendingOperations, true);
      });

      test('should remove entity after flush', () async {
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

      test('should handle remove without prior flush', () async {
        final user = User()
          ..id = 999
          ..name = 'Test'
          ..email = 'test@example.com';

        expect(
          () async {
            helper.orm.entityManager.remove(user);
            await helper.orm.entityManager.flush();
          },
          returnsNormally,
        );
      });
    });

    group('Clear Operations', () {
      test('should clear all pending operations', () async {
        final user1 = User()
          ..name = 'User 1'
          ..email = 'user1@example.com';
        final user2 = User()
          ..name = 'User 2'
          ..email = 'user2@example.com';

        helper.orm.entityManager.persist(user1);
        helper.orm.entityManager.persist(user2);

        expect(helper.orm.entityManager.pendingOperationsCount, 2);

        helper.orm.entityManager.clear();

        expect(helper.orm.entityManager.hasPendingOperations, false);
        expect(helper.orm.entityManager.pendingOperationsCount, 0);
      });

      test('should not persist cleared operations', () async {
        final user = User()
          ..name = 'Cleared'
          ..email = 'cleared@example.com';

        helper.orm.entityManager.persist(user);
        helper.orm.entityManager.clear();
        await helper.orm.entityManager.flush();

        expect(await helper.countRecords('users'), 0);
      });
    });

    group('Cascade Persist', () {
      test('should cascade persist from user to profile', () async {
        final user = User()
          ..name = 'User'
          ..email = 'user@example.com';
        final profile = Profile()..bio = 'Bio';
        user.profile = profile;

        helper.orm.entityManager.persist(user);

        // Should have 2 pending inserts: user + profile
        expect(
          helper.orm.entityManager.pendingOperationsCount,
          greaterThanOrEqualTo(2),
        );

        await helper.orm.entityManager.flush();

        expect(profile.id, isNotNull);
        expect(profile.userId, user.id);
      });

      test('should cascade persist from user to multiple posts', () async {
        final user = User()
          ..name = 'Author'
          ..email = 'author@example.com';
        final post1 = Post()
          ..title = 'Post 1'
          ..content = 'Content 1';
        final post2 = Post()
          ..title = 'Post 2'
          ..content = 'Content 2';

        user.posts = [post1, post2];

        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        expect(post1.id, isNotNull);
        expect(post2.id, isNotNull);
        expect(post1.userId, user.id);
        expect(post2.userId, user.id);
      });

      test('should set foreign keys correctly', () async {
        final user = User()
          ..name = 'Parent'
          ..email = 'parent@example.com';
        final profile = Profile()..bio = 'Child';
        user.profile = profile;

        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        final result = await helper.executeRaw(
          'SELECT user_id FROM profiles WHERE id = ?',
          [profile.id],
        );

        expect(result.rows.first['user_id'], user.id);
      });
    });

    group('Cascade Remove', () {
      test('should cascade remove from user to profile', () async {
        final user = User()
          ..name = 'User'
          ..email = 'user@example.com';
        final profile = Profile()..bio = 'Bio';
        user.profile = profile;

        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        final profileId = profile.id;

        helper.orm.entityManager.remove(user);
        await helper.orm.entityManager.flush();

        expect(await helper.recordExists('profiles', 'id', profileId), false);
      });

      test('should cascade remove from post to comments', () async {
        final user = User()
          ..name = 'User'
          ..email = 'user@example.com';
        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        final post = Post()
          ..userId = user.id
          ..title = 'Post'
          ..content = 'Content';
        final comment1 = Comment()
          ..content = 'Comment 1'
          ..authorName = 'Author 1';
        final comment2 = Comment()
          ..content = 'Comment 2'
          ..authorName = 'Author 2';

        post.comments = [comment1, comment2];

        helper.orm.entityManager.persist(post);
        await helper.orm.entityManager.flush();

        final commentIds = [comment1.id, comment2.id];

        helper.orm.entityManager.remove(post);
        await helper.orm.entityManager.flush();

        expect(
          await helper.recordExists('comments', 'id', commentIds[0]),
          false,
        );
        expect(
          await helper.recordExists('comments', 'id', commentIds[1]),
          false,
        );
      });
    });

    group('Operation Ordering', () {
      test('should insert parent before children', () async {
        final user = User()
          ..name = 'Parent'
          ..email = 'parent@example.com';
        final profile = Profile()..bio = 'Child';
        final post = Post()
          ..title = 'Child Post'
          ..content = 'Content';

        user.profile = profile;
        user.posts = [post];

        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        // All should have IDs
        expect(user.id, isNotNull);
        expect(profile.id, isNotNull);
        expect(post.id, isNotNull);

        // Children should reference parent
        expect(profile.userId, user.id);
        expect(post.userId, user.id);
      });

      test('should handle complex hierarchy', () async {
        final user = User()
          ..name = 'Root'
          ..email = 'root@example.com';
        final profile = Profile()..bio = 'Profile';
        final post1 = Post()
          ..title = 'Post 1'
          ..content = 'Content 1';
        final post2 = Post()
          ..title = 'Post 2'
          ..content = 'Content 2';
        final comment1 = Comment()
          ..content = 'Comment 1'
          ..authorName = 'Author';
        final comment2 = Comment()
          ..content = 'Comment 2'
          ..authorName = 'Author';

        user.profile = profile;
        user.posts = [post1, post2];
        post1.comments = [comment1, comment2];

        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        // Verify all entities were created
        expect(user.id, isNotNull);
        expect(profile.id, isNotNull);
        expect(post1.id, isNotNull);
        expect(post2.id, isNotNull);
        expect(comment1.id, isNotNull);
        expect(comment2.id, isNotNull);

        // Verify relationships
        expect(profile.userId, user.id);
        expect(post1.userId, user.id);
        expect(post2.userId, user.id);
        expect(comment1.postId, post1.id);
        expect(comment2.postId, post1.id);
      });
    });

    group('Error Handling', () {
      test('should throw error when persisting null entity', () {
        expect(
          () => helper.orm.entityManager.persist(null),
          throwsArgumentError,
        );
      });

      test('should throw error when removing null entity', () {
        expect(
          () => helper.orm.entityManager.remove(null),
          throwsArgumentError,
        );
      });

      test('should handle flush errors gracefully', () async {
        final user = User()
          ..name = 'Test'
          ..email = 'test@example.com';
        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        // Try to insert duplicate with same ID
        final duplicate = User()
          ..id = user.id
          ..name = 'Duplicate'
          ..email = 'dup@example.com';
        helper.orm.entityManager.persist(duplicate);

        expect(
          () async => await helper.orm.entityManager.flush(),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
