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

  group('Relationships Tests', () {
    group('HasOne Relationship', () {
      test('should create user with profile (cascade persist)', () async {
        final user = User()
          ..name = 'John Doe'
          ..email = 'john@example.com';

        final profile = Profile()
          ..bio = 'Software Developer'
          ..website = 'https://johndoe.com';

        user.profile = profile;

        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        expect(user.id, isNotNull);
        expect(profile.id, isNotNull);
        expect(profile.userId, user.id);
      });

      test('should load profile with eager loading', () async {
        final data = await helper.seedBasicData();
        final userId = (data['user'] as User).id;

        final repository = helper.orm.getRepository<User>();
        final user = await repository.find(userId, relations: ['profile']);

        expect(user, isNotNull);
        expect(user!.profile, isNotNull);
        expect(user.profile!.bio, 'Software Developer');
      });

      test('should update profile through user', () async {
        final user = User()
          ..name = 'Test'
          ..email = 'test@example.com';

        final profile = Profile()..bio = 'Original Bio';

        user.profile = profile;

        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        profile.bio = 'Updated Bio';
        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        final repository = helper.orm.getRepository<Profile>();
        final updated = await repository.find(profile.id);

        expect(updated!.bio, 'Updated Bio');
      });

      test(
        'should delete profile when user is deleted (cascade remove)',
        () async {
          final user = User()
            ..name = 'Test'
            ..email = 'test@example.com';

          final profile = Profile()..bio = 'Test Bio';

          user.profile = profile;

          helper.orm.entityManager.persist(user);
          await helper.orm.entityManager.flush();

          final profileId = profile.id;

          helper.orm.entityManager.remove(user);
          await helper.orm.entityManager.flush();

          expect(await helper.recordExists('profiles', 'id', profileId), false);
        },
      );
    });

    group('HasMany Relationship', () {
      test('should create user with posts (cascade persist)', () async {
        final user = User()
          ..name = 'Author'
          ..email = 'author@example.com';

        final post1 = Post()
          ..title = 'First Post'
          ..content = 'Content 1';

        final post2 = Post()
          ..title = 'Second Post'
          ..content = 'Content 2';

        user.posts = [post1, post2];

        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        expect(user.id, isNotNull);
        expect(post1.id, isNotNull);
        expect(post2.id, isNotNull);
        expect(post1.userId, user.id);
        expect(post2.userId, user.id);
      });

      test('should load posts with eager loading', () async {
        final data = await helper.seedBasicData();
        final userId = (data['user'] as User).id;

        final repository = helper.orm.getRepository<User>();
        final user = await repository.find(userId, relations: ['posts']);

        expect(user, isNotNull);
        expect(user!.posts, isNotNull);
        expect(user.posts!.length, 2);
      });

      test('should add post to existing user', () async {
        final user = User()
          ..name = 'Author'
          ..email = 'author@example.com';

        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        final post = Post()
          ..title = 'New Post'
          ..content = 'New Content';

        user.posts = [post];

        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        expect(post.id, isNotNull);
        expect(post.userId, user.id);
      });

      test('should count posts correctly', () async {
        final data = await helper.seedBasicData();
        final userId = (data['user'] as User).id;

        final repository = helper.orm.getRepository<User>();
        final user = await repository.find(userId, relations: ['posts']);

        expect(user!.posts!.length, 2);
      });
    });

    group('BelongsTo Relationship', () {
      test('should create post with existing user', () async {
        final user = User()
          ..name = 'Author'
          ..email = 'author@example.com';

        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        final post = Post()
          ..userId = user.id
          ..title = 'Test Post'
          ..content = 'Test Content';

        helper.orm.entityManager.persist(post);
        await helper.orm.entityManager.flush();

        expect(post.id, isNotNull);
        expect(post.userId, user.id);
      });

      test('should load user with post (eager loading)', () async {
        final data = await helper.seedBasicData();
        final postId = (data['post1'] as Post).id;

        final repository = helper.orm.getRepository<Post>();
        final post = await repository.find(postId, relations: ['user']);

        expect(post, isNotNull);
        expect(post!.user, isNotNull);
        expect(post.user!.name, 'John Doe');
      });

      test('should create post and user together (cascade)', () async {
        final user = User()
          ..name = 'New Author'
          ..email = 'new@example.com';

        final post = Post()
          ..title = 'Post'
          ..content = 'Content';

        post.user = user;

        helper.orm.entityManager.persist(post);
        await helper.orm.entityManager.flush();

        expect(user.id, isNotNull);
        expect(post.id, isNotNull);
        expect(post.userId, user.id);
      });
    });

    group('Nested Relationships', () {
      test('should load user with profile and posts', () async {
        final data = await helper.seedBasicData();
        final userId = (data['user'] as User).id;

        final repository = helper.orm.getRepository<User>();
        final user = await repository.find(
          userId,
          relations: ['profile', 'posts'],
        );

        expect(user, isNotNull);
        expect(user!.profile, isNotNull);
        expect(user.posts, isNotNull);
        expect(user.posts!.length, 2);
      });

      test('should create complete user hierarchy', () async {
        final user = User()
          ..name = 'Complete'
          ..email = 'complete@example.com';

        final profile = Profile()..bio = 'Full Bio';

        final post1 = Post()
          ..title = 'Post 1'
          ..content = 'Content 1';

        final post2 = Post()
          ..title = 'Post 2'
          ..content = 'Content 2';

        user.profile = profile;
        user.posts = [post1, post2];

        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        expect(user.id, isNotNull);
        expect(profile.id, isNotNull);
        expect(post1.id, isNotNull);
        expect(post2.id, isNotNull);
        expect(profile.userId, user.id);
        expect(post1.userId, user.id);
        expect(post2.userId, user.id);
      });

      test('should load post with user and user profile', () async {
        final user = User()
          ..name = 'Author'
          ..email = 'author@example.com';

        final profile = Profile()..bio = 'Author Bio';

        final post = Post()
          ..title = 'Post'
          ..content = 'Content';

        user.profile = profile;
        user.posts = [post];

        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        final postRepository = helper.orm.getRepository<Post>();
        final loadedPost = await postRepository.find(
          post.id,
          relations: ['user'],
        );

        expect(loadedPost, isNotNull);
        expect(loadedPost!.user, isNotNull);

        final userRepository = helper.orm.getRepository<User>();
        final loadedUser = await userRepository.find(
          loadedPost.user!.id,
          relations: ['profile'],
        );

        expect(loadedUser!.profile, isNotNull);
        expect(loadedUser.profile!.bio, 'Author Bio');
      });
    });

    group('Cascade Operations', () {
      test('should cascade persist from user to profile and posts', () async {
        final user = User()
          ..name = 'Cascade Test'
          ..email = 'cascade@example.com';

        final profile = Profile()..bio = 'Bio';

        final post = Post()
          ..title = 'Post'
          ..content = 'Content';

        user.profile = profile;
        user.posts = [post];

        // Only persist user - profile and posts should cascade
        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        expect(user.id, isNotNull);
        expect(profile.id, isNotNull);
        expect(post.id, isNotNull);

        final userCount = await helper.countRecords('users');
        final profileCount = await helper.countRecords('profiles');
        final postCount = await helper.countRecords('posts');

        expect(userCount, 1);
        expect(profileCount, 1);
        expect(postCount, 1);
      });

      test('should cascade remove from user to profile', () async {
        final user = User()
          ..name = 'Delete Test'
          ..email = 'delete@example.com';

        final profile = Profile()..bio = 'Delete Bio';

        user.profile = profile;

        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        final profileId = profile.id;

        helper.orm.entityManager.remove(user);
        await helper.orm.entityManager.flush();

        expect(await helper.recordExists('profiles', 'id', profileId), false);
      });

      test('should cascade remove from post to comments', () async {
        final post = Post()
          ..userId = 1
          ..title = 'Post with Comments'
          ..content = 'Content';

        final comment1 = Comment()
          ..authorName = 'User1'
          ..content = 'Comment 1';

        final comment2 = Comment()
          ..authorName = 'User2'
          ..content = 'Comment 2';

        post.comments = [comment1, comment2];

        // First create a user for the post
        final user = User()
          ..name = 'Test'
          ..email = 'test@example.com';

        helper.orm.entityManager.persist(user);
        await helper.orm.entityManager.flush();

        post.userId = user.id;

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

    group('Query Relationships', () {
      test('should use whereHas to filter users with posts', () async {
        final user1 = User()
          ..name = 'Has Posts'
          ..email = 'hasposts@example.com';

        final user2 = User()
          ..name = 'No Posts'
          ..email = 'noposts@example.com';

        final post = Post()
          ..title = 'Post'
          ..content = 'Content';

        user1.posts = [post];

        helper.orm.entityManager.persist(user1);
        helper.orm.entityManager.persist(user2);
        await helper.orm.entityManager.flush();

        final repository = helper.orm.getRepository<User>();
        final users = await repository
            .createQueryBuilder()
            .whereHas('posts')
            .fetchAll();

        expect(users.length, 1);
        expect(users.first.name, 'Has Posts');
      });

      test(
        'should use whereDoesntHave to filter users without profile',
        () async {
          final user1 = User()
            ..name = 'Has Profile'
            ..email = 'hasprofile@example.com';

          final user2 = User()
            ..name = 'No Profile'
            ..email = 'noprofile@example.com';

          final profile = Profile()..bio = 'Bio';

          user1.profile = profile;

          helper.orm.entityManager.persist(user1);
          helper.orm.entityManager.persist(user2);
          await helper.orm.entityManager.flush();

          final repository = helper.orm.getRepository<User>();
          final users = await repository
              .createQueryBuilder()
              .whereDoesntHave('profile')
              .fetchAll();

          expect(users.length, 1);
          expect(users.first.name, 'No Profile');
        },
      );

      test('should filter whereHas with additional conditions', () async {
        final user1 = User()
          ..name = 'User 1'
          ..email = 'user1@example.com';

        final user2 = User()
          ..name = 'User 2'
          ..email = 'user2@example.com';

        final post1 = Post()
          ..title = 'Published'
          ..content = 'Content'
          ..published = true;

        final post2 = Post()
          ..title = 'Draft'
          ..content = 'Content'
          ..published = false;

        user1.posts = [post1];
        user2.posts = [post2];

        helper.orm.entityManager.persist(user1);
        helper.orm.entityManager.persist(user2);
        await helper.orm.entityManager.flush();

        final repository = helper.orm.getRepository<User>();
        final users = await repository
            .createQueryBuilder()
            .whereHas(
              'posts',
              builder: (q) {
                q.where('published', isEqualTo: true);
              },
            )
            .fetchAll();

        expect(users.length, 1);
        expect(users.first.name, 'User 1');
      });
    });
  });
}
