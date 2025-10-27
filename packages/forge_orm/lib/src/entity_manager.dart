import 'package:collection/collection.dart';
import 'package:forge_core/forge_core.dart';
import '../forge_orm.dart';
import 'entity_change_tracker.dart';

/// Manages the lifecycle of entities and coordinates database operations.
///
/// The EntityManager is responsible for tracking entity changes and persisting
/// them to the database. It uses a Unit of Work pattern where changes are
/// accumulated and flushed to the database in a single transaction.
abstract class EntityManager {
  /// Factory constructor to create an EntityManager instance.
  factory EntityManager({
    required Database database,
    required Serializer serializer,
    required MetadataSchemaResolver schemaResolver,
  }) = EntityManagerImpl;

  /// Marks an entity for persistence (insert or update).
  ///
  /// If the entity has no ID or an ID <= 0, it will be inserted.
  /// If the entity has a valid ID, it will be updated.
  ///
  /// Changes are not immediately persisted to the database. Call [flush] to
  /// execute all pending operations.
  ///
  /// Example:
  /// ```dart
  /// final user = User()
  ///   ..name = 'Alice'
  ///   ..email = 'alice@example.com';
  ///
  /// entityManager.persist(user);
  /// await entityManager.flush(); // User is now saved
  /// ```
  ///
  /// Throws [ArgumentError] if entity is null.
  void persist<T>(T entity);

  /// Marks an entity for removal (deletion).
  ///
  /// The entity will be deleted when [flush] is called.
  ///
  /// Example:
  /// ```dart
  /// entityManager.remove(user);
  /// await entityManager.flush(); // User is now deleted
  /// ```
  ///
  /// Throws [ArgumentError] if entity is null.
  /// Throws [Exception] if entity has no valid primary key.
  void remove<T>(T entity);

  /// Executes all pending insert, update, and delete operations.
  ///
  /// Operations are executed in the correct order to respect foreign key
  /// constraints (parent entities before children). All operations are
  /// executed within a single database transaction.
  ///
  /// Example:
  /// ```dart
  /// entityManager.persist(user1);
  /// entityManager.persist(user2);
  /// entityManager.remove(user3);
  ///
  /// await entityManager.flush(); // All changes saved atomically
  /// ```
  ///
  /// After flush completes, all pending operations are cleared.
  Future<void> flush();

  /// Discards all pending operations without executing them.
  ///
  /// Use this to cancel all pending changes.
  void clear();

  /// Returns true if there are any pending operations.
  bool get hasPendingOperations;

  /// Returns the number of pending operations.
  int get pendingOperationsCount;
}

abstract class PendingOperation<T> {
  T get entity;

  Future<int?> execute(
    Database database,
    Serializer serializer,
    MetadataSchemaResolver resolver,
    ChangeTrackingManager changeTracker,
  );
}

class PendingInsert<T> extends PendingOperation<T> {
  @override
  final T entity;

  PendingInsert(this.entity);

  @override
  Future<int?> execute(
    Database database,
    Serializer serializer,
    MetadataSchemaResolver resolver,
    ChangeTrackingManager changeTracker,
  ) async {
    final schema = resolver.resolve<T>();

    final originalEntity = changeTracker.getOriginal(entity as Object);
    final data = serializer.normalize<T>(originalEntity as T);

    if (data is! Map<String, dynamic>) {
      throw Exception('Normalized data must be a Map<String, dynamic>');
    }

    final columnData = <String, dynamic>{};
    for (final entry in data.entries) {
      if (schema.isColumn(entry.key)) {
        final columnName = schema.getColumnName(entry.key);
        columnData[columnName] = entry.value;
      }
    }

    final pkColumn = schema.primaryKeyColumn;
    if (pkColumn.isAutoIncrement && columnData[pkColumn.columnName] == null) {
      columnData.remove(pkColumn.columnName);
    }

    final columns = columnData.keys.join(', ');
    final placeholders = List.filled(columnData.length, '?').join(', ');
    final sql =
        'INSERT INTO ${schema.tableName} ($columns) VALUES ($placeholders)';

    final result = await database.connection.execute(
      sql,
      columnData.values.toList(),
    );

    if (pkColumn.isAutoIncrement && result.insertId != null) {
      final setter = schema.classMetadata.setters?.firstWhereOrNull(
        (s) => s.name == schema.primaryKey,
      );
      setter?.setValue(originalEntity, result.insertId!);
      return result.insertId;
    }

    final getter = schema.classMetadata.getters?.firstWhereOrNull(
      (g) => g.name == schema.primaryKey,
    );
    final currentId = getter?.getValue(originalEntity);
    return currentId is int ? currentId : null;
  }
}

class PendingUpdate<T> extends PendingOperation<T> {
  @override
  final T entity;

  PendingUpdate(this.entity);

  @override
  Future<int?> execute(
    Database database,
    Serializer serializer,
    MetadataSchemaResolver resolver,
    ChangeTrackingManager changeTracker,
  ) async {
    final schema = resolver.resolve<T>();
    final originalEntity = changeTracker.getOriginal(entity!);

    final pkGetter = schema.classMetadata.getters?.firstWhereOrNull(
      (g) => g.name == schema.primaryKey,
    );
    final pkValue = pkGetter?.getValue(originalEntity);

    if (pkValue == null) {
      throw Exception('Cannot update entity without primary key value');
    }

    final changedProperties = changeTracker.getChangedProperties(
      entity as Object,
    );

    if (changedProperties != null && changedProperties.isNotEmpty) {
      final columnData = <String, dynamic>{};

      for (final propertyName in changedProperties) {
        if (schema.isColumn(propertyName) &&
            propertyName != schema.primaryKey) {
          final columnName = schema.getColumnName(propertyName);
          final getter = schema.classMetadata.getters?.firstWhereOrNull(
            (g) => g.name == propertyName,
          );
          if (getter != null) {
            columnData[columnName] = getter.getValue(originalEntity);
          }
        }
      }

      if (columnData.isEmpty) {
        return pkValue is int ? pkValue : null;
      }

      final sets = columnData.keys.map((k) => '$k = ?').join(', ');
      final pkColumnName = schema.getColumnName(schema.primaryKey);
      final sql =
          'UPDATE ${schema.tableName} SET $sets WHERE $pkColumnName = ?';

      await database.connection.execute(
        sql,
        [...columnData.values, pkValue],
      );
    } else {
      final data = serializer.normalize<T>(originalEntity as T);

      if (data is! Map<String, dynamic>) {
        throw Exception('Normalized data must be a Map<String, dynamic>');
      }

      final columnData = <String, dynamic>{};
      for (final entry in data.entries) {
        if (schema.isColumn(entry.key) && entry.key != schema.primaryKey) {
          final columnName = schema.getColumnName(entry.key);
          columnData[columnName] = entry.value;
        }
      }

      if (columnData.isEmpty) {
        return pkValue is int ? pkValue : null;
      }

      final sets = columnData.keys.map((k) => '$k = ?').join(', ');
      final pkColumnName = schema.getColumnName(schema.primaryKey);
      final sql =
          'UPDATE ${schema.tableName} SET $sets WHERE $pkColumnName = ?';

      await database.connection.execute(
        sql,
        [...columnData.values, pkValue],
      );
    }

    return pkValue is int ? pkValue : null;
  }
}

class PendingDelete<T> extends PendingOperation<T> {
  @override
  final T entity;

  PendingDelete(this.entity);

  @override
  Future<int?> execute(
    Database database,
    Serializer serializer,
    MetadataSchemaResolver resolver,
    ChangeTrackingManager changeTracker,
  ) async {
    final schema = resolver.resolve<T>();
    final originalEntity = changeTracker.getOriginal(entity as Object);

    final pkGetter = schema.classMetadata.getters?.firstWhereOrNull(
      (g) => g.name == schema.primaryKey,
    );
    final pkValue = pkGetter?.getValue(originalEntity);

    if (pkValue == null) {
      throw Exception('Cannot delete entity without primary key value');
    }

    final pkColumnName = schema.getColumnName(schema.primaryKey);
    final sql = 'DELETE FROM ${schema.tableName} WHERE $pkColumnName = ?';

    await database.connection.execute(sql, [pkValue]);
    return null;
  }
}

class RelationshipTracker<P, C> {
  final P parent;
  final C child;
  final String foreignKeyProperty;
  final RelationType relationType;

  RelationshipTracker({
    required this.parent,
    required this.child,
    required this.foreignKeyProperty,
    required this.relationType,
  });
}

/// Entity state similar to Doctrine ORM
enum EntityState {
  /// Entity is not yet managed and has no database identity
  newEntity,

  /// Entity is managed and has database identity
  managed,

  /// Entity is scheduled for deletion
  removed,
}

class EntityManagerImpl implements EntityManager {
  final Database database;
  final Serializer serializer;
  final MetadataSchemaResolver schemaResolver;
  final ChangeTrackingManager changeTracker = ChangeTrackingManager();

  final List<PendingOperation> _pendingOperations = [];
  final Set<Object> _processedEntities = {};
  final Map<Object, int> _entityIds = {};
  final Map<Object, int> _identityMap = {};
  final List<RelationshipTracker> _relationships = [];

  EntityManagerImpl({
    required this.database,
    required this.serializer,
    required this.schemaResolver,
  });

  @override
  void persist<T>(T entity) {
    if (entity == null) throw ArgumentError('Entity cannot be null');

    final originalEntity = changeTracker.getOriginal(entity as Object);

    if (_processedEntities.contains(originalEntity)) return;
    _processedEntities.add(originalEntity);

    try {
      final schema = schemaResolver.resolve<T>();

      final pkGetter = schema.classMetadata.getters?.firstWhereOrNull(
        (g) => g.name == schema.primaryKey,
      );
      final pkValue = pkGetter?.getValue(originalEntity);

      final isManaged = _identityMap.containsKey(originalEntity);
      final state = _determineEntityState(originalEntity, pkValue, isManaged);

      T trackedEntity = entity;
      if (!changeTracker.isTracked(originalEntity)) {
        trackedEntity =
            changeTracker.createTrackedProxy<T>(
                  entity,
                  schema.classMetadata,
                )
                as T;
      }

      _removeEntityFromPending(originalEntity);

      if (state == EntityState.managed) {
        _pendingOperations.add(PendingUpdate<T>(trackedEntity));
      } else {
        _pendingOperations.add(PendingInsert<T>(trackedEntity));
      }

      _detectCascadePersist(trackedEntity, schema);
      _detectInverseRelationships(trackedEntity, schema);
      _detectParentInPendingOperations(trackedEntity, schema, originalEntity);

      _processedEntities.remove(originalEntity);
    } catch (e) {
      _processedEntities.remove(originalEntity);
      rethrow;
    }
  }

  EntityState _determineEntityState(
    Object entity,
    dynamic pkValue,
    bool isManaged,
  ) {
    if (isManaged) {
      return EntityState.managed;
    }

    if (pkValue == null || (pkValue is num && pkValue <= 0)) {
      return EntityState.newEntity;
    }

    return EntityState.newEntity;
  }

  @override
  void remove<T>(T entity) {
    if (entity == null) throw ArgumentError('Entity cannot be null');

    final originalEntity = changeTracker.getOriginal(entity as Object);

    if (_processedEntities.contains(originalEntity)) return;
    _processedEntities.add(originalEntity);

    try {
      final schema = schemaResolver.resolve<T>();

      final pkGetter = schema.classMetadata.getters?.firstWhereOrNull(
        (g) => g.name == schema.primaryKey,
      );

      final pkValue = pkGetter?.getValue(originalEntity);

      if (pkValue == null || (pkValue is num && pkValue <= 0)) {
        throw Exception('Cannot remove entity without valid primary key');
      }

      _detectCascadeRemove(entity, schema);

      _removeEntityFromPending(originalEntity);
      _pendingOperations.add(PendingDelete<T>(entity));

      _processedEntities.remove(originalEntity);
    } catch (e) {
      _processedEntities.remove(originalEntity);
      rethrow;
    }
  }

  @override
  Future<void> flush() async {
    if (!hasPendingOperations) return;

    await database.connection.transaction<void>((connection) async {
      final orderedOperations = _orderOperationsByDependencies();

      for (final operation in orderedOperations) {
        if (operation is PendingInsert) {
          _fillForeignKeysBeforeInsert(operation.entity);
        }

        final id = await operation.execute(
          database,
          serializer,
          schemaResolver,
          changeTracker,
        );

        final originalEntity = changeTracker.getOriginal(operation.entity);

        if (id != null) {
          _entityIds[originalEntity] = id;
          _identityMap[originalEntity] = id;

          if (operation is PendingInsert) {
            _propagateParentIdToChildren(originalEntity, id);
          }
        }

        if (operation is PendingDelete) {
          _identityMap.remove(originalEntity);
          changeTracker.untrack(originalEntity);
        }
      }
    });

    clear();
  }

  @override
  void clear() {
    _pendingOperations.clear();
    _entityIds.clear();
    _relationships.clear();
  }

  void _detectParentInPendingOperations<T>(
    T entity,
    ResolvedEntitySchema<T> schema,
    Object originalEntity,
  ) {
    for (final operation in _pendingOperations) {
      if (operation is! PendingInsert) continue;

      final parentOriginal = changeTracker.getOriginal(operation.entity);
      final parentSchema = schemaResolver.resolveByType(
        parentOriginal.runtimeType,
      );

      for (final relation in parentSchema.relations.values) {
        if (relation.isInverse) continue;

        final relationGetter = parentSchema.classMetadata.getters
            ?.firstWhereOrNull((g) => g.name == relation.propertyName);
        if (relationGetter == null) continue;

        final relationValue = relationGetter.getValue(parentOriginal);
        if (relationValue == null) continue;

        if (relationValue is List) {
          for (final item in relationValue) {
            final itemOriginal = changeTracker.getOriginal(item);
            if (identical(itemOriginal, originalEntity)) {
              _relationships.add(
                RelationshipTracker(
                  parent: parentOriginal,
                  child: originalEntity,
                  foreignKeyProperty: relation.foreignKey,
                  relationType: relation.type,
                ),
              );
              return;
            }
          }
        } else {
          final relatedOriginal = changeTracker.getOriginal(relationValue);
          if (identical(relatedOriginal, originalEntity)) {
            _relationships.add(
              RelationshipTracker(
                parent: parentOriginal,
                child: originalEntity,
                foreignKeyProperty: relation.foreignKey,
                relationType: relation.type,
              ),
            );
            return;
          }
        }
      }
    }
  }

  void _detectCascadePersist<T>(T entity, ResolvedEntitySchema<T> schema) {
    final originalEntity = changeTracker.getOriginal(entity as Object);

    for (final relation in schema.relations.values) {
      if (!relation.hasCascadePersist) continue;

      final relationGetter = schema.classMetadata.getters?.firstWhereOrNull(
        (g) => g.name == relation.propertyName,
      );
      if (relationGetter == null) continue;

      final relationValue = relationGetter.getValue(originalEntity);
      if (relationValue == null) continue;

      if (relationValue is List) {
        for (final relatedEntity in relationValue) {
          if (relatedEntity != null) {
            _trackRelationship(
              entity,
              relatedEntity,
              relation,
              originalEntity,
            );
            _persistWithType(relatedEntity, relation.relatedType);
          }
        }
      } else {
        if (relation.isInverse) {
          _trackInverseRelationship(
            entity,
            relationValue,
            relation,
            originalEntity,
          );
        } else {
          _trackRelationship(entity, relationValue, relation, originalEntity);
        }
        _persistWithType(relationValue, relation.relatedType);
      }
    }
  }

  void _trackInverseRelationship<T>(
    T child,
    Object parent,
    RelationInfo relation,
    Object originalChild,
  ) {
    final originalParent = changeTracker.getOriginal(parent);
    final parentSchema = schemaResolver.resolveByType(parent.runtimeType);
    final parentPkGetter = parentSchema.classMetadata.getters?.firstWhereOrNull(
      (g) => g.name == parentSchema.primaryKey,
    );

    if (parentPkGetter == null) return;

    var parentId = parentPkGetter.getValue(originalParent);

    if (parentId == null || (parentId is num && parentId <= 0)) {
      parentId = _identityMap[originalParent] ?? _entityIds[originalParent];
    }

    if (parentId != null && parentId is int && parentId > 0) {
      final childSchema = schemaResolver.resolve<T>();
      final fkSetter = childSchema.classMetadata.setters?.firstWhereOrNull(
        (s) => s.name == relation.localKey,
      );
      fkSetter?.setValue(originalChild, parentId);
    } else {
      _relationships.add(
        RelationshipTracker(
          parent: originalParent,
          child: originalChild,
          foreignKeyProperty: relation.localKey,
          relationType: relation.type,
        ),
      );
    }
  }

  void _detectInverseRelationships<T>(
    T entity,
    ResolvedEntitySchema<T> schema,
  ) {
    final originalEntity = changeTracker.getOriginal(entity as Object);

    for (final relation in schema.relations.values) {
      if (!relation.isInverse) continue;

      final relationGetter = schema.classMetadata.getters?.firstWhereOrNull(
        (g) => g.name == relation.propertyName,
      );
      if (relationGetter == null) continue;

      final relationValue = relationGetter.getValue(originalEntity);
      if (relationValue == null) continue;

      final originalRelatedEntity = changeTracker.getOriginal(relationValue);
      final relatedSchema = schemaResolver.resolveByType(relation.relatedType);
      final relatedPkGetter = relatedSchema.classMetadata.getters
          ?.firstWhereOrNull((g) => g.name == relatedSchema.primaryKey);

      if (relatedPkGetter == null) continue;

      var relatedId = relatedPkGetter.getValue(originalRelatedEntity);

      if (relatedId == null || (relatedId is num && relatedId <= 0)) {
        relatedId =
            _identityMap[originalRelatedEntity] ??
            _entityIds[originalRelatedEntity];
      }

      if (relatedId != null && relatedId is int && relatedId > 0) {
        final fkSetter = schema.classMetadata.setters?.firstWhereOrNull(
          (s) => s.name == relation.localKey,
        );
        fkSetter?.setValue(originalEntity, relatedId);
      } else {
        final pendingParentOp = _pendingOperations.firstWhereOrNull((op) {
          if (op is! PendingInsert) return false;
          final opEntity = changeTracker.getOriginal(op.entity);
          return identical(opEntity, originalRelatedEntity);
        });

        if (pendingParentOp != null) {
          _relationships.add(
            RelationshipTracker(
              parent: originalRelatedEntity,
              child: originalEntity,
              foreignKeyProperty: relation.localKey,
              relationType: relation.type,
            ),
          );

          return;
        }
      }
    }
  }

  void _trackRelationship<T>(
    T parent,
    Object child,
    RelationInfo relation,
    Object originalParent,
  ) {
    final originalChild = changeTracker.getOriginal(child);
    final parentSchema = schemaResolver.resolve<T>();
    final parentPkGetter = parentSchema.classMetadata.getters?.firstWhereOrNull(
      (g) => g.name == parentSchema.primaryKey,
    );

    if (parentPkGetter == null) return;

    var parentId = parentPkGetter.getValue(originalParent);

    if (parentId == null || (parentId is num && parentId <= 0)) {
      parentId = _identityMap[originalParent] ?? _entityIds[originalParent];
    }

    if (parentId != null && parentId is int && parentId > 0) {
      _setForeignKeyOnChild(originalChild, relation, parentId);
    } else {
      final pendingParentOp = _pendingOperations.firstWhereOrNull((op) {
        if (op is! PendingInsert) return false;
        final opEntity = changeTracker.getOriginal(op.entity);
        return identical(opEntity, originalParent);
      });

      if (pendingParentOp != null) {
        _relationships.add(
          RelationshipTracker(
            parent: originalParent,
            child: originalChild,
            foreignKeyProperty: relation.foreignKey,
            relationType: relation.type,
          ),
        );
      }
    }
  }

  void _setForeignKeyOnChild(
    Object child,
    RelationInfo relation,
    int parentId,
  ) {
    final childSchema = schemaResolver.resolveByType(child.runtimeType);
    final fieldName = relation.isInverse
        ? relation.localKey
        : relation.foreignKey;
    final fkSetter = childSchema.classMetadata.setters?.firstWhereOrNull(
      (s) => s.name == fieldName,
    );
    fkSetter?.setValue(child, parentId);
  }

  void _detectCascadeRemove<T>(T entity, ResolvedEntitySchema<T> schema) {
    final originalEntity = changeTracker.getOriginal(entity as Object);

    for (final relation in schema.relations.values) {
      if (!relation.hasCascadeRemove) continue;

      final relationGetter = schema.classMetadata.getters?.firstWhereOrNull(
        (g) => g.name == relation.propertyName,
      );
      if (relationGetter == null) continue;

      final relationValue = relationGetter.getValue(originalEntity);
      if (relationValue == null) continue;

      if (relationValue is List) {
        for (final relatedEntity in relationValue) {
          if (relatedEntity != null) {
            _removeWithType(relatedEntity, relation.relatedType);
          }
        }
      } else {
        _removeWithType(relationValue, relation.relatedType);
      }
    }
  }

  void _fillForeignKeysBeforeInsert(Object entity) {
    final originalEntity = changeTracker.getOriginal(entity);
    final schema = schemaResolver.resolveByType(originalEntity.runtimeType);

    for (final relation in schema.relations.values) {
      if (relation.type != RelationType.belongsTo &&
          relation.type != RelationType.conditionalBelongsTo) {
        continue;
      }

      final relationGetter = schema.classMetadata.getters?.firstWhereOrNull(
        (g) => g.name == relation.propertyName,
      );
      if (relationGetter == null) continue;

      final relatedEntity = relationGetter.getValue(originalEntity);
      if (relatedEntity == null) continue;

      final originalRelatedEntity = changeTracker.getOriginal(relatedEntity);

      final relatedSchema = schemaResolver.resolveByType(relation.relatedType);
      final relatedPkGetter = relatedSchema.classMetadata.getters
          ?.firstWhereOrNull((g) => g.name == relatedSchema.primaryKey);

      if (relatedPkGetter == null) continue;

      var relatedId = relatedPkGetter.getValue(originalRelatedEntity);

      if (relatedId == null || (relatedId is num && relatedId <= 0)) {
        relatedId =
            _identityMap[originalRelatedEntity] ??
            _entityIds[originalRelatedEntity];
      }

      if (relatedId != null && relatedId is int && relatedId > 0) {
        final fkSetter = schema.classMetadata.setters?.firstWhereOrNull(
          (s) => s.name == relation.localKey,
        );
        fkSetter?.setValue(originalEntity, relatedId);
      }
    }
  }

  void _propagateParentIdToChildren(Object parent, int parentId) {
    final children = _relationships.where((r) => identical(r.parent, parent));

    for (final relationship in children) {
      final childSchema = schemaResolver.resolveByType(
        relationship.child.runtimeType,
      );

      final fkSetter = childSchema.classMetadata.setters?.firstWhereOrNull(
        (s) => s.name == relationship.foreignKeyProperty,
      );

      if (fkSetter != null) {
        fkSetter.setValue(relationship.child, parentId);
      }
    }
  }

  List<PendingOperation> _orderOperationsByDependencies() {
    final deletes = _pendingOperations.whereType<PendingDelete>().toList();
    final inserts = _pendingOperations.whereType<PendingInsert>().toList();
    final updates = _pendingOperations.whereType<PendingUpdate>().toList();

    final orderedInserts = <PendingInsert>[];
    final remaining = List<PendingInsert>.from(inserts);

    while (remaining.isNotEmpty) {
      var addedInThisRound = false;

      for (var i = 0; i < remaining.length; i++) {
        final insert = remaining[i];
        final originalEntity = changeTracker.getOriginal(insert.entity);

        if (_canInsertNow(originalEntity, orderedInserts)) {
          orderedInserts.add(insert);
          remaining.removeAt(i);
          i--;
          addedInThisRound = true;
        }
      }

      if (!addedInThisRound && remaining.isNotEmpty) {
        orderedInserts.add(remaining.removeAt(0));
      }
    }

    return [...orderedInserts, ...updates, ...deletes];
  }

  bool _canInsertNow(Object entity, List<PendingInsert> alreadyOrdered) {
    final parents = _relationships
        .where((r) => identical(r.child, entity))
        .map((r) => r.parent);

    for (final parent in parents) {
      if (_identityMap.containsKey(parent)) {
        continue;
      }

      final parentInsert = _pendingOperations
          .whereType<PendingInsert>()
          .firstWhereOrNull((op) {
            final originalEntity = changeTracker.getOriginal(op.entity);
            return identical(originalEntity, parent);
          });

      if (parentInsert != null) {
        if (!alreadyOrdered.contains(parentInsert)) {
          return false;
        }
      }
    }

    return true;
  }

  void _persistWithType(Object entity, Type entityType) {
    final schema = schemaResolver.resolveByType(entityType);
    schema.classMetadata.typeMetadata.captureGeneric(<T>() {
      persist<T>(entity as T);
    });
  }

  void _removeWithType(Object entity, Type entityType) {
    final schema = schemaResolver.resolveByType(entityType);
    schema.classMetadata.typeMetadata.captureGeneric(<T>() {
      remove<T>(entity as T);
    });
  }

  void _removeEntityFromPending(Object entity) {
    _pendingOperations.removeWhere((op) {
      final originalEntity = changeTracker.getOriginal(op.entity);
      return identical(originalEntity, entity);
    });
  }

  int? getEntityId(Object entity) {
    final originalEntity = changeTracker.getOriginal(entity);
    return _identityMap[originalEntity] ?? _entityIds[originalEntity];
  }

  int get pendingInsertsCount =>
      _pendingOperations.whereType<PendingInsert>().length;
  int get pendingUpdatesCount =>
      _pendingOperations.whereType<PendingUpdate>().length;
  int get pendingDeletesCount =>
      _pendingOperations.whereType<PendingDelete>().length;

  bool hasEntityPending(Object entity) {
    final originalEntity = changeTracker.getOriginal(entity);
    return _pendingOperations.any((op) {
      final opEntity = changeTracker.getOriginal(op.entity);
      return identical(opEntity, originalEntity);
    });
  }

  String? getPendingOperationType(Object entity) {
    final originalEntity = changeTracker.getOriginal(entity);
    for (final operation in _pendingOperations) {
      final opEntity = changeTracker.getOriginal(operation.entity);
      if (identical(opEntity, originalEntity)) {
        if (operation is PendingInsert) return 'insert';
        if (operation is PendingUpdate) return 'update';
        if (operation is PendingDelete) return 'delete';
      }
    }
    return null;
  }

  List<PendingOperation> get pendingOperations =>
      List.unmodifiable(_pendingOperations);

  @override
  bool get hasPendingOperations => _pendingOperations.isNotEmpty;

  @override
  int get pendingOperationsCount => _pendingOperations.length;
}
