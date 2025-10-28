import 'dart:io';
import 'package:forge_core/forge_core.dart';
import 'package:forge_orm/forge_orm.dart';
import 'package:forge_orm/src/connection/mysql_connection.dart';
import 'package:forge_orm/src/connection/sqllite_connection.dart';
import 'test_entities.dart';
import 'test_helper.bundle.dart';

/// Helper class to configure test environment with database selection from environment
class TestHelper {
  late final Orm orm;
  late final Database database;
  late final Serializer serializer;
  late final MetadataRegistry registry;
  late final MetadataSchemaResolver schemaResolver;

  /// Gets database type from environment variable
  /// Defaults to SQLite for safety
  String get _databaseType {
    return Platform.environment['FORGE_TEST_DB']?.toLowerCase() ?? 'sqlite';
  }

  /// Initializes the ORM for tests
  Future<void> setup() async {
    // Creates registry and registers entities
    final builder = MetadataRegistryBuilder();

    TestBundle().buildMetadata(builder, 'test');

    registry = builder.build();
    serializer = Serializer(
      transformers: [
        PrimitiveTransformer(),
        MapTransformer(),
        ListTransformer(),
        MetadataTransformer(registry),
      ],
      encoders: [JsonEncoder()],
    );

    // Select database based on environment
    database = _createDatabase();

    await database.connect();
    schemaResolver = MetadataSchemaResolver(
      registry,
      UnderscoreNamingStrategy(),
    );

    // Creates ORM
    orm = OrmImpl(
      database: database,
      serializer: serializer,
      schemaResolver: schemaResolver,
    );

    // Creates the tables
    await createTables();
    await clearTables();
  }

  /// Creates database instance based on environment configuration
  Database _createDatabase() {
    switch (_databaseType) {
      case 'mysql':
        return MySQLDatabase(
          database: Platform.environment['MYSQL_DATABASE'] ?? 'test_db',
          host: Platform.environment['MYSQL_HOST'] ?? 'localhost',
          port: int.parse(Platform.environment['MYSQL_PORT'] ?? '3306'),
          username: Platform.environment['MYSQL_USER'] ?? 'test_user',
          password: Platform.environment['MYSQL_PASSWORD'] ?? 'test_password',
          secure: true,
        );

      case 'sqlite':
      default:
        return SqliteDatabase(path: null);
    }
  }

  /// Creates all necessary tables
  Future<void> createTables() async {
    final schemaCreator = SchemaCreator(database, schemaResolver);

    await schemaCreator.createTablesComplete([
      User,
      Profile,
      Post,
      Comment,
      Category,
      PostCategory,
    ]);
  }

  /// Clears all tables
  Future<void> clearTables() async {
    final tables = [
      'comments',
      'post_categories',
      'posts',
      'profiles',
      'categories',
      'users',
    ];

    for (final table in tables) {
      try {
        if (_databaseType == 'sqlite') {
          await database.connection.execute('DELETE FROM $table');
        } else {
          await database.connection.execute('TRUNCATE TABLE $table');
        }
      } catch (_) {}
    }
  }

  /// Closes connections
  Future<void> teardown() async {
    await database.closeAllConnections();
  }

  /// Inserts basic test data
  Future<Map<String, dynamic>> seedBasicData() async {
    final user = User()
      ..name = 'John Doe'
      ..email = 'john@example.com'
      ..age = 30
      ..createdAt = DateTime.now();

    final profile = Profile()
      ..bio = 'Software Developer'
      ..website = 'https://johndoe.com';

    final post1 = Post()
      ..title = 'First Post'
      ..content = 'This is my first post'
      ..published = true
      ..publishedAt = DateTime.now();

    final post2 = Post()
      ..title = 'Second Post'
      ..content = 'This is my second post'
      ..published = false;

    user.profile = profile;
    user.posts = [post1, post2];

    orm.entityManager.persist(user);
    await orm.entityManager.flush();

    return {
      'user': user,
      'profile': profile,
      'post1': post1,
      'post2': post2,
    };
  }

  /// Executes a SQL query directly
  Future<QueryResult> executeRaw(String sql, [List<dynamic>? params]) {
    return database.connection.execute(sql, params);
  }

  /// Counts records in a table
  Future<int> countRecords(String tableName) async {
    final result = await executeRaw('SELECT COUNT(*) as count FROM $tableName');
    final count = result.rows.first['count'];
    if (count is int) return count;
    if (count is String) return int.parse(count);
    return 0;
  }

  /// Checks if a record exists
  Future<bool> recordExists(
    String tableName,
    String column,
    dynamic value,
  ) async {
    final result = await executeRaw(
      'SELECT COUNT(*) as count FROM $tableName WHERE $column = ?',
      [value],
    );
    final count = result.rows.first['count'];
    return (count is int ? count : int.parse(count as String)) > 0;
  }
}

@AutoBundle(paths: ['test/**.dart'])
class TestBundle extends AbstractTestBundle {}
