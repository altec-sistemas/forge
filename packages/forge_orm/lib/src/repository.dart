import '../forge_orm.dart';

/// Generic repository for entities
abstract class Repository<T> {
  final Orm orm;
  final ResolvedEntitySchema<T> schema;

  Repository(this.orm) : schema = orm.getSchema<T>();

  /// Creates a query builder for the entity
  EntityQueryBuilder<T> createQueryBuilder([String? alias]) {
    return EntityQueryBuilder<T>(this, orm, alias);
  }

  /// Finds an entity by ID
  Future<T?> find(dynamic id, {List<String>? relations}) {
    final builder = createQueryBuilder();

    // Uses the database column name, not the property name
    final pkColumnName = schema.primaryKeyColumn.columnName;

    builder.where(
      pkColumnName,
      isEqualTo: id,
    );

    if (relations != null) {
      for (final relation in relations) {
        builder.load(relation);
      }
    }

    return builder.fetchOne();
  }

  /// Finds an entity by ID or throws an exception
  Future<T> findOrFail(dynamic id, {List<String>? relations}) async {
    final entity = await find(id, relations: relations);
    if (entity == null) {
      throw EntityNotFoundException(
        'Entity $T with id $id not found',
      );
    }
    return entity;
  }

  /// Finds all entities
  Future<List<T>> findAll({List<String>? relations}) {
    final builder = createQueryBuilder();

    if (relations != null) {
      for (final relation in relations) {
        builder.load(relation);
      }
    }

    return builder.fetchAll();
  }

  /// Finds entities with custom conditions
  Future<List<T>> findBy(
    Map<String, dynamic> criteria, {
    List<String>? relations,
    int? limit,
    int? offset,
  }) {
    final builder = createQueryBuilder();

    // Applies criteria
    for (final entry in criteria.entries) {
      final propertyName = entry.key;
      final value = entry.value;

      // Converts property name to column name
      if (schema.isColumn(propertyName)) {
        final columnName = schema.getColumnName(propertyName);
        builder.where(columnName, isEqualTo: value);
      }
    }

    // Applies relations
    if (relations != null) {
      for (final relation in relations) {
        builder.load(relation);
      }
    }

    // Applies limit and offset
    if (limit != null) {
      builder.limit(limit);
    }
    if (offset != null) {
      builder.offset(offset);
    }

    return builder.fetchAll();
  }

  /// Finds one entity with custom conditions
  Future<T?> findOneBy(
    Map<String, dynamic> criteria, {
    List<String>? relations,
  }) async {
    final results = await findBy(
      criteria,
      relations: relations,
      limit: 1,
    );
    return results.isEmpty ? null : results.first;
  }
}

/// Generic implementation of Repository
class GenericRepository<T> extends Repository<T> {
  GenericRepository(super.orm);
}
