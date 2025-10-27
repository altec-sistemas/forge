import 'package:forge_core/forge_core.dart';
import 'package:forge_orm/forge_orm.dart';
import 'package:forge_orm/src/connection/mysql_connection.dart';
import 'test_entities.dart';
import 'test_helper.bundle.dart';

/// Helper class to configure test environment
class TestHelper {
  late final Orm orm;
  late final Database database;
  late final Serializer serializer;
  late final MetadataRegistry registry;
  late final MetadataSchemaResolver schemaResolver;

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

    database = MySQLDatabase(
      database: 'test_db',
      host: 'localhost',
      port: 3306,
      username: 'root',
      password: '',
      secure: true,
    );

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
        await database.connection.execute('TRUNCATE TABLE $table');
      } catch (e) {
        // Ignores errors if the table doesn't exist
      }
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
