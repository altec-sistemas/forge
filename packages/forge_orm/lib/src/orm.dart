import 'package:forge_core/forge_core.dart';
import 'metadata_schema_resolver.dart';
import 'entity_manager.dart';
import 'database.dart';
import 'repository.dart';
import 'builder/query_builder.dart';

/// Main ORM interface providing access to entity management and database operations.
///
/// The ORM is the central entry point for all database operations. It provides
/// access to repositories, entity manager, query builders, and transaction management.
///
/// ## Basic Usage
///
/// ```dart
/// // Get repository for entity operations
/// final userRepo = orm.getRepository<User>();
///
/// // Find entity by ID
/// final user = await userRepo.find(1);
///
/// // Find all entities
/// final users = await userRepo.findAll();
///
/// // Save entity
/// final newUser = User()
///   ..name = 'John'
///   ..email = 'john@example.com';
/// await userRepo.save(newUser);
/// ```
///
/// ## Using EntityManager
///
/// ```dart
/// // Direct entity manager access
/// orm.entityManager.persist(user1);
/// orm.entityManager.persist(user2);
/// await orm.entityManager.flush();
/// ```
///
/// ## Transactions
///
/// ```dart
/// // Execute operations in a transaction
/// await orm.transaction((em) async {
///   final user = User()..name = 'Alice';
///   em.persist(user);
///   await em.flush();
///
///   final profile = Profile()
///     ..userId = user.id
///     ..bio = 'Developer';
///   em.persist(profile);
///   await em.flush();
/// });
/// ```
///
/// ## Query Builder
///
/// ```dart
/// // Create custom queries
/// final users = await orm.createQueryBuilder()
///   .select()
///   .from('users')
///   .where('age > ?', [18])
///   .fetchAll();
/// ```
abstract class Orm {
  /// Factory constructor to create an ORM instance.
  factory Orm({
    required Database database,
    required Serializer serializer,
    required MetadataSchemaResolver schemaResolver,
  }) = OrmImpl;

  /// EntityManager for managing entity lifecycle.
  ///
  /// Use this for direct control over persist, remove, and flush operations.
  ///
  /// Example:
  /// ```dart
  /// orm.entityManager.persist(user);
  /// await orm.entityManager.flush();
  /// ```
  EntityManager get entityManager;

  /// Database connection instance.
  ///
  /// Provides access to the underlying database connection.
  Database get database;

  /// Serializer for converting entities to/from database format.
  ///
  /// Handles normalization (entity → data) and denormalization (data → entity).
  Serializer get serializer;

  /// Schema resolver for entity metadata.
  ///
  /// Provides access to entity schema information including table names,
  /// columns, and relationships.
  MetadataSchemaResolver get schemaResolver;

  /// Returns a repository for the specified entity type.
  ///
  /// Repositories provide high-level methods for entity operations like
  /// find, findAll, save, and delete.
  ///
  /// Example:
  /// ```dart
  /// final userRepo = orm.getRepository<User>();
  /// final user = await userRepo.find(1);
  /// ```
  Repository<T> getRepository<T>();

  /// Creates a new query builder for custom SQL queries.
  ///
  /// Use query builders when you need more control than repositories provide.
  ///
  /// Example:
  /// ```dart
  /// final users = await orm.createQueryBuilder()
  ///   .select()
  ///   .from('users')
  ///   .where('age > ?', [18])
  ///   .orderBy('name')
  ///   .fetchAll();
  /// ```
  QueryBuilder createQueryBuilder();

  /// Resolves the schema for an entity type.
  ///
  /// Returns metadata about the entity including table name, columns,
  /// primary key, and relationships.
  ///
  /// Example:
  /// ```dart
  /// final schema = orm.getSchema<User>();
  /// print(schema.tableName); // 'users'
  /// print(schema.primaryKey); // 'id'
  /// ```
  ResolvedEntitySchema<T> getSchema<T>();
}

/// ORM implementation
class OrmImpl implements Orm {
  @override
  final Database database;

  @override
  final Serializer serializer;

  @override
  final MetadataSchemaResolver schemaResolver;

  @override
  late final EntityManager entityManager;

  OrmImpl({
    required this.database,
    required this.serializer,
    required this.schemaResolver,
  }) {
    entityManager = EntityManagerImpl(
      database: database,
      serializer: serializer,
      schemaResolver: schemaResolver,
    );
  }

  @override
  Repository<T> getRepository<T>() {
    return GenericRepository<T>(this);
  }

  @override
  QueryBuilder createQueryBuilder() {
    return QueryBuilder(database);
  }

  @override
  ResolvedEntitySchema<T> getSchema<T>() {
    return schemaResolver.resolve<T>();
  }
}

/// Exception thrown when entity is not found
class EntityNotFoundException implements Exception {
  final String message;

  EntityNotFoundException(this.message);

  @override
  String toString() => 'EntityNotFoundException: $message';
}
