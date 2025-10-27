import 'package:forge_core/forge_core.dart';
import 'package:meta/meta.dart';
import '../annotations.dart';
import '../orm.dart';
import '../repository.dart';
import 'builder.dart';
import '../metadata_schema_resolver.dart';

/// Entity-specific query builder with eager loading support
class EntityQueryBuilder<T> extends Builder<EntityQueryBuilder<T>> {
  @internal
  final Repository<T> repository;

  @internal
  final Orm orm;

  @internal
  final Map<String, EagerLoad> eagerLoads = {};

  EntityQueryBuilder(this.repository, this.orm, [String? alias])
    : super(orm.database) {
    from(repository.schema.tableName, alias);
  }

  /// Eagerly loads a relationship
  EntityQueryBuilder<T> load(
    String relation, {
    String? alias,
    void Function(EntityQueryBuilder q)? builder,
  }) {
    final relationInfo = repository.schema.relations[relation];

    if (relationInfo == null) {
      throw Exception(
        'Relation "$relation" not found in ${T.toString()} schema',
      );
    }

    eagerLoads[relation] = EagerLoad(
      relationInfo: relationInfo,
      alias: alias,
      builder: builder,
      name: relation,
    );

    return this;
  }

  /// Adds WHERE EXISTS condition for a relationship
  EntityQueryBuilder<T> whereHas(
    String relation, {
    String? alias,
    void Function(EntityQueryBuilder q)? builder,
  }) {
    _applyWhereHas(
      relation,
      exists: true,
      useOr: false,
      alias: alias,
      builder: builder,
    );
    return this;
  }

  /// Adds OR WHERE EXISTS condition for a relationship
  EntityQueryBuilder<T> orWhereHas(
    String relation, {
    String? alias,
    void Function(EntityQueryBuilder q)? builder,
  }) {
    _applyWhereHas(
      relation,
      exists: true,
      useOr: true,
      alias: alias,
      builder: builder,
    );
    return this;
  }

  /// Adds WHERE NOT EXISTS condition for a relationship
  EntityQueryBuilder<T> whereDoesntHave(
    String relation, {
    String? alias,
    void Function(EntityQueryBuilder q)? builder,
  }) {
    _applyWhereHas(
      relation,
      exists: false,
      useOr: false,
      alias: alias,
      builder: builder,
    );
    return this;
  }

  /// Adds OR WHERE NOT EXISTS condition for a relationship
  EntityQueryBuilder<T> orWhereDoesntHave(
    String relation, {
    String? alias,
    void Function(EntityQueryBuilder q)? builder,
  }) {
    _applyWhereHas(
      relation,
      exists: false,
      useOr: true,
      alias: alias,
      builder: builder,
    );
    return this;
  }

  void _applyWhereHas(
    String relationName, {
    required bool exists,
    required bool useOr,
    String? alias,
    void Function(EntityQueryBuilder q)? builder,
  }) {
    final relationInfo = repository.schema.relations[relationName];

    if (relationInfo == null) {
      throw Exception(
        'Relation "$relationName" not found in ${T.toString()} schema',
      );
    }

    final relatedSchema = orm.schemaResolver.resolveByType(
      relationInfo.relatedType,
    );

    void existsCallback(EntityQueryBuilder sub) {
      sub.from(relatedSchema.tableName, alias);

      final relation = relationInfo.relationAnnotation;

      if (relationInfo.isInverse) {
        final foreignKeyColumn = relatedSchema.getColumnName(
          _findPropertyByColumn(relatedSchema, relation.foreignKey),
        );
        final localKeyColumn = repository.schema.getColumnName(
          _findPropertyByColumn(repository.schema, relation.localKey),
        );

        sub.where(
          foreignKeyColumn,
          isEqualTo: col(
            resolveColumn(localKeyColumn, useTablePrefix: true),
          ),
        );
      } else {
        final foreignKeyColumn = relatedSchema.getColumnName(
          _findPropertyByColumn(relatedSchema, relation.foreignKey),
        );
        final localKeyColumn = repository.schema.getColumnName(
          _findPropertyByColumn(repository.schema, relation.localKey),
        );

        sub.where(
          foreignKeyColumn,
          isEqualTo: col(
            resolveColumn(localKeyColumn, useTablePrefix: true),
          ),
        );
      }

      if (builder != null) {
        builder(sub);
      }

      if (relation.queryBuilder != null) {
        relation.queryBuilder!(sub);
      }

      if (relation.conditionColumn != null) {
        final conditionColumnName = relatedSchema.getColumnName(
          _findPropertyByColumn(relatedSchema, relation.conditionColumn!),
        );
        sub.where(
          conditionColumnName,
          isEqualTo: relation.conditionValue,
        );
      }
    }

    if (exists) {
      if (useOr) {
        orWhereExists((sub) => existsCallback(sub as EntityQueryBuilder));
      } else {
        whereExists((sub) => existsCallback(sub as EntityQueryBuilder));
      }
    } else {
      if (useOr) {
        orWhereNotExists((sub) => existsCallback(sub as EntityQueryBuilder));
      } else {
        whereNotExists((sub) => existsCallback(sub as EntityQueryBuilder));
      }
    }
  }

  /// Fetches all entities
  Future<List<T>> fetchAll() async {
    final result = await get();
    return deserializeResults(result);
  }

  /// Fetches a single entity
  Future<T?> fetchOne() async {
    limit(1);
    final entities = await fetchAll();
    return entities.isEmpty ? null : entities.first;
  }

  /// Fetches a single entity or throws exception
  Future<T> fetchOneOrFail() async {
    final entity = await fetchOne();
    if (entity == null) {
      throw EntityNotFoundException('Record $T not found.');
    }
    return entity;
  }

  /// Paginates results
  Future<Pagination<T>> paginate(int page, int perPage) async {
    if (page <= 0) {
      throw ArgumentError('Page must be greater than 0');
    }

    if (perPage <= 0) {
      throw ArgumentError('PerPage must be greater than 0');
    }

    final offset = (page - 1) * perPage;
    limit(perPage);
    this.offset(offset);

    final entities = await fetchAll();

    return Pagination<T>(
      data: entities,
      currentPage: page,
      perPage: perPage,
      total: entities.length,
    );
  }

  /// Counts records
  Future<int> count() async {
    final originalColumns = List<String>.from(selectedColumns);
    final originalLimit = limitValue;
    final originalOffset = offsetValue;

    selectedColumns.clear();
    selectedColumns.add('COUNT(*) as count');
    limitValue = null;
    offsetValue = null;

    final result = await super.get();

    selectedColumns.clear();
    selectedColumns.addAll(originalColumns);
    limitValue = originalLimit;
    offsetValue = originalOffset;

    if (result.isEmpty) return 0;

    final countValue = result.first['count'];
    if (countValue is int) return countValue;
    if (countValue is String) return int.parse(countValue);

    return 0;
  }

  @internal
  List<T> deserializeResults(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return [];

    return rows.map((row) {
      final propertyData = _convertColumnNamesToProperties(row);
      final entity = orm.serializer.denormalize<T>(propertyData);
      return asProxy(entity as T);
    }).toList();
  }

  /// Converts database column names to property names
  Map<String, dynamic> _convertColumnNamesToProperties(
    Map<String, dynamic> row,
  ) {
    final result = <String, dynamic>{};

    for (final entry in row.entries) {
      String? propertyName;

      for (final column in repository.schema.columns.values) {
        if (column.columnName == entry.key) {
          propertyName = column.propertyName;
          break;
        }
      }

      propertyName ??= entry.key;

      result[propertyName] = entry.value;
    }

    return result;
  }

  /// Eagerly loads relationships
  @internal
  Future<void> loadRelations(List<Map<String, dynamic>> parentMaps) async {
    for (final eagerLoad in eagerLoads.values) {
      final relationInfo = eagerLoad.relationInfo;

      final parentIds = _extractParentIds(parentMaps, relationInfo);
      if (parentIds.isEmpty) continue;

      final relatedSchema = orm.schemaResolver.resolveByType(
        relationInfo.relatedType,
      );

      final relatedQuery = _createRelatedQueryBuilder(
        relatedSchema,
        eagerLoad.alias,
      );

      _buildEagerLoadQuery(relatedQuery, relationInfo, parentIds);

      if (eagerLoad.builder != null) {
        eagerLoad.builder!(relatedQuery);
      }

      final relatedMaps = await relatedQuery.get();

      _attachRelatedToParents(
        parentMaps,
        relatedMaps,
        relationInfo,
        eagerLoad.name,
      );
    }
  }

  /// Extracts parent IDs to load relationships
  List<Object> _extractParentIds(
    List<Map<String, dynamic>> parentMaps,
    RelationInfo relationInfo,
  ) {
    final relation = relationInfo.relationAnnotation;
    final schema = repository.schema;

    if (relationInfo.isInverse) {
      final localKeyProperty = _findPropertyByColumn(schema, relation.localKey);
      return parentMaps
          .map((parent) => parent[localKeyProperty])
          .whereType<Object>()
          .toSet()
          .toList();
    } else {
      return parentMaps
          .map((parent) => parent[schema.primaryKey])
          .whereType<Object>()
          .toSet()
          .toList();
    }
  }

  /// Builds query for eager loading
  void _buildEagerLoadQuery(
    EntityQueryBuilder relatedQuery,
    RelationInfo relationInfo,
    List<Object> parentIds,
  ) {
    final relation = relationInfo.relationAnnotation;
    final relatedSchema = orm.schemaResolver.resolveByType(
      relationInfo.relatedType,
    );

    if (relationInfo.isInverse) {
      final foreignKeyProperty = _findPropertyByColumn(
        relatedSchema,
        relation.foreignKey,
      );
      final foreignKeyColumn = relatedSchema.getColumnName(foreignKeyProperty);
      relatedQuery.whereIn(foreignKeyColumn, parentIds);
    } else {
      final foreignKeyProperty = _findPropertyByColumn(
        relatedSchema,
        relation.foreignKey,
      );
      final foreignKeyColumn = relatedSchema.getColumnName(foreignKeyProperty);
      relatedQuery.whereIn(foreignKeyColumn, parentIds);
    }

    if (relation.queryBuilder != null) {
      relation.queryBuilder!(relatedQuery);
    }

    if (relation.conditionColumn != null) {
      final conditionProperty = _findPropertyByColumn(
        relatedSchema,
        relation.conditionColumn!,
      );
      final conditionColumn = relatedSchema.getColumnName(conditionProperty);
      relatedQuery.where(conditionColumn, isEqualTo: relation.conditionValue);
    }
  }

  /// Attaches related entities to parents
  void _attachRelatedToParents(
    List<Map<String, dynamic>> parentMaps,
    List<Map<String, dynamic>> relatedMaps,
    RelationInfo relationInfo,
    String relationName,
  ) {
    final relation = relationInfo.relationAnnotation;
    final schema = repository.schema;
    final relatedSchema = orm.schemaResolver.resolveByType(
      relationInfo.relatedType,
    );

    final convertedRelatedMaps = relatedMaps.map((map) {
      return _convertColumnNamesToPropertiesForSchema(map, relatedSchema);
    }).toList();

    if (relationInfo.type == RelationType.hasMany) {
      final foreignKeyProperty = _findPropertyByColumn(
        relatedSchema,
        relation.foreignKey,
      );

      final relatedByForeignKey = <dynamic, List<Map<String, dynamic>>>{};
      for (final related in convertedRelatedMaps) {
        final fk = related[foreignKeyProperty];
        if (fk != null) {
          relatedByForeignKey.putIfAbsent(fk, () => []).add(related);
        }
      }

      for (final parent in parentMaps) {
        final parentId = parent[schema.primaryKey];
        parent[relationName] = relatedByForeignKey[parentId] ?? [];
      }
    } else if (relationInfo.isInverse) {
      final foreignKeyProperty = _findPropertyByColumn(
        relatedSchema,
        relation.foreignKey,
      );
      final localKeyProperty = _findPropertyByColumn(schema, relation.localKey);

      final relatedByPk = {
        for (final related in convertedRelatedMaps)
          if (related[foreignKeyProperty] != null)
            related[foreignKeyProperty]: related,
      };

      for (final parent in parentMaps) {
        final fk = parent[localKeyProperty];
        parent[relationName] = relatedByPk[fk];
      }
    } else {
      final foreignKeyProperty = _findPropertyByColumn(
        relatedSchema,
        relation.foreignKey,
      );

      final relatedByForeignKey = {
        for (final related in convertedRelatedMaps)
          if (related[foreignKeyProperty] != null)
            related[foreignKeyProperty]: related,
      };

      for (final parent in parentMaps) {
        final parentId = parent[schema.primaryKey];
        parent[relationName] = relatedByForeignKey[parentId];
      }
    }
  }

  /// Converts column names to properties for a specific schema
  Map<String, dynamic> _convertColumnNamesToPropertiesForSchema(
    Map<String, dynamic> row,
    ResolvedEntitySchema schema,
  ) {
    final result = <String, dynamic>{};

    for (final entry in row.entries) {
      String? propertyName;

      for (final column in schema.columns.values) {
        if (column.columnName == entry.key) {
          propertyName = column.propertyName;
          break;
        }
      }

      propertyName ??= entry.key;
      result[propertyName] = entry.value;
    }

    return result;
  }

  /// Finds property name by column name
  String _findPropertyByColumn(ResolvedEntitySchema schema, String columnName) {
    for (final column in schema.columns.values) {
      if (column.columnName == columnName ||
          column.propertyName == columnName) {
        return column.propertyName;
      }
    }
    return columnName;
  }

  /// Creates query builder for related entity
  EntityQueryBuilder _createRelatedQueryBuilder(
    ResolvedEntitySchema schema,
    String? alias,
  ) {
    return schema.captureGeneric(<S>() {
      final repository = orm.getRepository<S>();
      return EntityQueryBuilder<S>(repository, orm, alias);
    });
  }

  @internal
  T asProxy(T entity) {
    final metadata = orm.schemaResolver.resolve<T>().classMetadata;
    return metadata.createProxy!(entity as Object, ProxyHandler(), metadata)
        as T;
  }

  @override
  Future<List<Map<String, dynamic>>> get() async {
    final result = await super.get();

    if (eagerLoads.isNotEmpty && result.isNotEmpty) {
      final convertedResult = result.map((row) {
        return _convertColumnNamesToProperties(row);
      }).toList();

      await loadRelations(convertedResult);

      return convertedResult;
    }

    return result;
  }

  @override
  EntityQueryBuilder<T> createNew() {
    return EntityQueryBuilder<T>(repository, orm);
  }

  @override
  EntityQueryBuilder<T> get self => this;
}

/// Eager loading information
class EagerLoad {
  final RelationInfo relationInfo;
  final String name;
  final String? alias;
  final void Function(EntityQueryBuilder q)? builder;

  EagerLoad({
    required this.relationInfo,
    required this.name,
    this.alias,
    this.builder,
  });
}

/// Result pagination
class Pagination<T> {
  final List<T> data;
  final int currentPage;
  final int perPage;
  final int total;

  Pagination({
    required this.data,
    required this.currentPage,
    required this.perPage,
    required this.total,
  });

  int get lastPage => (total / perPage).ceil();
  bool get hasNextPage => currentPage < lastPage;
  bool get hasPreviousPage => currentPage > 1;
}
