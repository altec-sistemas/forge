import 'package:meta/meta.dart';
import '../orm.dart';
import '../repository.dart';
import 'builder.dart';
import '../metadata_schema_resolver.dart';

class EntityQueryBuilder<T> extends Builder<EntityQueryBuilder<T>> {
  @internal
  final Repository<T> repository;

  @internal
  final Orm orm;

  @internal
  final Map<String, EagerLoad> eagerLoads = {};

  EntityQueryBuilder(
    this.repository,
    this.orm, [
    String? alias,
  ]) : super(orm.database) {
    from(repository.schema.tableName, alias);
  }

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

      if (relationInfo.isManyToOne || relationInfo.isOneToOne) {
        if (relationInfo.foreignKey == null) {
          throw Exception(
            'Foreign key not defined for relation "$relationName"',
          );
        }

        final foreignKeyProperty = _findPropertyByColumn(
          repository.schema,
          relationInfo.foreignKey!,
        );
        final foreignKeyColumn = repository.schema.getColumnName(
          foreignKeyProperty,
        );

        final relatedPkColumn = relatedSchema.getColumnName(
          relatedSchema.primaryKey,
        );

        sub.where(
          relatedPkColumn,
          isEqualTo: col(
            resolveColumn(foreignKeyColumn, useTablePrefix: true),
          ),
        );
      } else if (relationInfo.isOneToMany || relationInfo.isOneToOneInverse) {
        if (relationInfo.mappedBy == null) {
          throw Exception(
            'mappedBy not defined for relation "$relationName"',
          );
        }

        final owningRelation = relatedSchema.relations[relationInfo.mappedBy];
        if (owningRelation == null) {
          throw Exception(
            'Owning relation "${relationInfo.mappedBy}" not found in ${relatedSchema.entityType}',
          );
        }

        if (owningRelation.foreignKey == null) {
          throw Exception(
            'Foreign key not defined for owning relation "${relationInfo.mappedBy}"',
          );
        }

        final foreignKeyProperty = _findPropertyByColumn(
          relatedSchema,
          owningRelation.foreignKey!,
        );
        final foreignKeyColumn = relatedSchema.getColumnName(
          foreignKeyProperty,
        );

        final localKeyColumn = repository.schema.getColumnName(
          repository.schema.primaryKey,
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

  Future<List<T>> fetchAll() async {
    final result = await get();
    return deserializeResults(result);
  }

  Future<T?> fetchOne() async {
    limit(1);
    final entities = await fetchAll();
    return entities.isEmpty ? null : entities.first;
  }

  Future<T> fetchOneOrFail() async {
    final entity = await fetchOne();
    if (entity == null) {
      throw EntityNotFoundException('Record $T not found.');
    }
    return entity;
  }

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

  List<T> deserializeResults(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return [];
    return rows.map((row) {
      final propertyData = _convertColumnNamesToProperties(row);
      final entity = orm.serializer.denormalize<T>(propertyData);
      return asProxy(entity as T);
    }).toList();
  }

  Map<String, dynamic> _convertColumnNamesToProperties(
    Map<String, dynamic> row,
  ) {
    final result = <String, dynamic>{};
    final schema = repository.schema;

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

  Future<void> loadRelations(List<Map<String, dynamic>> parentMaps) async {
    if (parentMaps.isEmpty) return;

    for (final entry in eagerLoads.entries) {
      final relationName = entry.key;
      final eagerLoad = entry.value;
      final relationInfo = eagerLoad.relationInfo;

      final parentIds = _extractParentIds(parentMaps, relationInfo);

      if (parentIds.isEmpty) continue;

      final relatedQuery = _createRelatedQueryBuilder(
        orm.schemaResolver.resolveByType(relationInfo.relatedType),
        eagerLoad.alias,
      );

      _buildEagerLoadQuery(relatedQuery, relationInfo, parentIds);

      if (eagerLoad.builder != null) {
        eagerLoad.builder!(relatedQuery);
      }

      final relatedRows = await relatedQuery.get();

      _attachRelatedToParents(
        parentMaps,
        relatedRows,
        relationInfo,
        relationName,
      );
    }
  }

  List<Object> _extractParentIds(
    List<Map<String, dynamic>> parentMaps,
    RelationInfo relationInfo,
  ) {
    final schema = repository.schema;

    if (relationInfo.isManyToOne || relationInfo.isOneToOne) {
      if (relationInfo.foreignKey == null) return [];

      final foreignKeyProperty = _findPropertyByColumn(
        schema,
        relationInfo.foreignKey!,
      );

      return parentMaps
          .map((parent) => parent[foreignKeyProperty])
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

  void _buildEagerLoadQuery(
    EntityQueryBuilder relatedQuery,
    RelationInfo relationInfo,
    List<Object> parentIds,
  ) {
    final relation = relationInfo.relationAnnotation;
    final relatedSchema = orm.schemaResolver.resolveByType(
      relationInfo.relatedType,
    );

    if (relationInfo.isManyToOne || relationInfo.isOneToOne) {
      final pkColumn = relatedSchema.getColumnName(relatedSchema.primaryKey);
      relatedQuery.whereIn(pkColumn, parentIds);
    } else if (relationInfo.isOneToMany || relationInfo.isOneToOneInverse) {
      if (relationInfo.mappedBy == null) {
        throw Exception(
          'mappedBy not defined for relation',
        );
      }

      final owningRelation = relatedSchema.relations[relationInfo.mappedBy];
      if (owningRelation == null || owningRelation.foreignKey == null) {
        throw Exception(
          'Invalid owning relation "${relationInfo.mappedBy}"',
        );
      }

      final foreignKeyProperty = _findPropertyByColumn(
        relatedSchema,
        owningRelation.foreignKey!,
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

  void _attachRelatedToParents(
    List<Map<String, dynamic>> parentMaps,
    List<Map<String, dynamic>> relatedMaps,
    RelationInfo relationInfo,
    String relationName,
  ) {
    final schema = repository.schema;
    final relatedSchema = orm.schemaResolver.resolveByType(
      relationInfo.relatedType,
    );

    final convertedRelatedMaps = relatedMaps.map((map) {
      return _convertColumnNamesToPropertiesForSchema(map, relatedSchema);
    }).toList();

    if (relationInfo.isOneToMany) {
      if (relationInfo.mappedBy == null) return;

      final owningRelation = relatedSchema.relations[relationInfo.mappedBy];
      if (owningRelation == null || owningRelation.foreignKey == null) return;

      final foreignKeyProperty = _findPropertyByColumn(
        relatedSchema,
        owningRelation.foreignKey!,
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
    } else if (relationInfo.isManyToOne ||
        relationInfo.isOneToOne ||
        relationInfo.isOneToOneInverse) {
      if (relationInfo.isManyToOne || relationInfo.isOneToOne) {
        if (relationInfo.foreignKey == null) return;

        final foreignKeyProperty = _findPropertyByColumn(
          schema,
          relationInfo.foreignKey!,
        );

        final relatedByPk = {
          for (final related in convertedRelatedMaps)
            if (related[relatedSchema.primaryKey] != null)
              related[relatedSchema.primaryKey]: related,
        };

        for (final parent in parentMaps) {
          final fk = parent[foreignKeyProperty];
          parent[relationName] = relatedByPk[fk];
        }
      } else {
        if (relationInfo.mappedBy == null) return;

        final owningRelation = relatedSchema.relations[relationInfo.mappedBy];
        if (owningRelation == null || owningRelation.foreignKey == null) return;

        final foreignKeyProperty = _findPropertyByColumn(
          relatedSchema,
          owningRelation.foreignKey!,
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
  }

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

  String _findPropertyByColumn(ResolvedEntitySchema schema, String columnName) {
    for (final column in schema.columns.values) {
      if (column.columnName == columnName ||
          column.propertyName == columnName) {
        return column.propertyName;
      }
    }
    return columnName;
  }

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

    return orm.changeTracker.createTrackedProxy(entity, metadata);
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
