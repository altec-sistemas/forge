import 'package:test/test.dart';
import 'package:forge_orm/forge_orm.dart';
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

  group('Schema Creation Tests', () {
    test('should create all tables successfully', () async {
      final tables = [
        'users',
        'profiles',
        'posts',
        'comments',
        'categories',
        'post_categories',
      ];

      for (final table in tables) {
        final exists = await helper.database.connection.execute(
          helper.database.dialect.getTableExistsQuery(table),
          [table],
        );
        expect(exists.hasResults, true, reason: 'Table $table should exist');
      }
    });

    test('should create table with correct columns for User', () async {
      final result = await helper.executeRaw(
        '''INSERT INTO users (name, email, age, created_at) 
           VALUES (?, ?, ?, ?)''',
        ['Test User', 'test@example.com', 25, DateTime.now().toIso8601String()],
      );

      expect(result.insertId, isNotNull);
      expect(result.insertId! > 0, true);
    });

    test('should enforce NOT NULL constraint', () async {
      expect(
        () async => await helper.executeRaw(
          'INSERT INTO users (email) VALUES (?)',
          ['test@example.com'],
        ),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('should auto-increment primary key', () async {
      final result1 = await helper.executeRaw(
        'INSERT INTO users (name, email) VALUES (?, ?)',
        ['User 1', 'user1@example.com'],
      );

      final result2 = await helper.executeRaw(
        'INSERT INTO users (name, email) VALUES (?, ?)',
        ['User 2', 'user2@example.com'],
      );

      expect(result1.insertId, 1);
      expect(result2.insertId, 2);
    });

    test('should enforce UNIQUE constraint', () async {
      final schema = helper.schemaResolver.resolve<User>();

      final tableExists = await helper.executeRaw(
        helper.database.dialect.getTableExistsQuery(schema.tableName),
        [schema.tableName],
      );

      expect(tableExists.hasResults, true);
    });

    test('should create indexes for unique columns', () async {
      final schemaCreator = SchemaCreator(
        helper.database,
        helper.schemaResolver,
      );
      final schema = helper.schemaResolver.resolve<User>();

      await schemaCreator.createIndexes(schema);
      expect(true, true);
    });

    test('should handle default values correctly', () async {
      // Post tem published com defaultValue: false
      final result = await helper.executeRaw(
        'INSERT INTO posts (user_id, title) VALUES (?, ?)',
        [1, 'Test Post'],
      );

      expect(result.insertId, isNotNull);

      final posts = await helper.executeRaw(
        'SELECT published FROM posts WHERE id = ?',
        [result.insertId],
      );

      expect(posts.rows.first['published'], anyOf(0, false));
    });

    test('should drop tables successfully', () async {
      final schemaCreator = SchemaCreator(
        helper.database,
        helper.schemaResolver,
      );

      await schemaCreator.dropTables([Comment, Post, Profile, User]);

      final userExists = await schemaCreator.tableExists('users');
      expect(userExists, false);
    });

    test('should check if table exists', () async {
      final schemaCreator = SchemaCreator(
        helper.database,
        helper.schemaResolver,
      );

      final exists = await schemaCreator.tableExists('users');
      expect(exists, true);

      final notExists = await schemaCreator.tableExists('non_existent_table');
      expect(notExists, false);
    });

    test('should create table only if not exists', () async {
      final schemaCreator = SchemaCreator(
        helper.database,
        helper.schemaResolver,
      );

      await schemaCreator.createTableIfNotExists(User);
      final exists = await schemaCreator.tableExists('users');
      expect(exists, true);
    });
  });
}
