import 'package:forge_core/forge_core.dart';
import 'package:collection/collection.dart';

import '../../forge_orm.dart';
import 'entity_change_tracker.dart';
import 'entity_persister.dart';
import 'identity_map.dart';
import 'unit_of_work.dart';
import 'relationship_manager.dart';

abstract class EntityManager {
  factory EntityManager({
    required Database database,
    required Serializer serializer,
    required MetadataSchemaResolver schemaResolver,
    required ChangeTrackingManager changeTracker,
  }) = EntityManagerImpl;

  void persist<T>(T entity);
  void remove<T>(T entity);
  Future<void> flush();
  Future<void> refresh<T>(T entity);
  void clear();
  void detach<T>(T entity);
  bool contains<T>(T entity);

  bool get hasPendingOperations;
  int get pendingOperationsCount;
}

class EntityManagerImpl implements EntityManager {
  final Database database;
  final Serializer serializer;
  final MetadataSchemaResolver schemaResolver;

  late final UnitOfWork _unitOfWork;
  late final IdentityMap _identityMap;
  late final EntityPersister _persister;
  late final ChangeTrackingManager _changeTracker;
  late final RelationshipManager _relationshipManager;

  final Map<Object, Map<String, dynamic>> _entitySnapshots = {};
  final Set<Object> _processingEntities = {};

  EntityManagerImpl({
    required this.database,
    required this.serializer,
    required this.schemaResolver,
    required ChangeTrackingManager changeTracker,
  }) : _changeTracker = changeTracker {
    _identityMap = IdentityMap();
    _persister = EntityPersister(
      database: database,
      serializer: serializer,
      schemaResolver: schemaResolver,
      identityMap: _identityMap,
    );
    _unitOfWork = UnitOfWork(
      persister: _persister,
      identityMap: _identityMap,
      changeTracker: _changeTracker,
      schemaResolver: schemaResolver,
    );
    _relationshipManager = RelationshipManager(
      schemaResolver: schemaResolver,
      changeTracker: _changeTracker,
    );

    // Configure callback for relationship changes in proxies
    _changeTracker.onRelationshipChange = _handleRelationshipChangeInProxy;
  }

  /// Handles relationship changes when a setter is called on a proxy
  void _handleRelationshipChangeInProxy(
    Object entity,
    String propertyName,
    dynamic newValue,
  ) {
    final schema = schemaResolver.resolveByType(entity.runtimeType);
    _relationshipManager.handleRelationshipSetter(
      entity,
      propertyName,
      newValue,
      schema,
    );
  }

  @override
  void persist<T>(T entity) {
    if (entity == null) {
      throw ArgumentError('Cannot persist null entity');
    }

    final original = _changeTracker.getOriginal(entity as Object);

    if (_processingEntities.contains(original)) {
      return;
    }

    final schema = schemaResolver.resolve<T>();

    _processingEntities.add(original);

    try {
      if (_isProxy(entity)) {
        _handleProxyPersist(original, schema);
        return;
      }

      _handleNonProxyPersist(original, schema);
    } finally {
      _processingEntities.remove(original);
    }
  }

  void _handleProxyPersist<T>(
    Object entity,
    ResolvedEntitySchema<T> schema,
  ) {
    // Proxies sempre vêm do banco, então sempre são updates
    _ensureTracked(entity, schema);
    _unitOfWork.scheduleUpdate(entity);

    // Sincroniza relações bidirecionais usando RelationshipManager
    _relationshipManager.syncBidirectionalRelations(entity, schema);

    // Process cascade operations
    _processRelations(entity, schema, CascadeOption.persist);
  }

  void _handleNonProxyPersist<T>(
    Object entity,
    ResolvedEntitySchema<T> schema,
  ) {
    final id = _getEntityId(entity, schema);

    if (id == null || (id is int && id <= 0)) {
      _scheduleInsert(entity, schema);
      return;
    }

    if (_identityMap.contains(entity) || _unitOfWork.isScheduled(entity)) {
      _scheduleUpdate(entity, schema);
      return;
    }

    // ID existe, mas não sabemos se o registro existe no banco
    // Precisamos fazer uma existence check
    _scheduleAfterExistenceCheck(entity, schema, id);
  }

  void _scheduleInsert<T>(Object entity, ResolvedEntitySchema<T> schema) {
    _unitOfWork.scheduleInsert(entity);

    // Sincroniza relações e join columns usando RelationshipManager
    _relationshipManager.syncBidirectionalRelations(entity, schema);

    // Track relationships for UnitOfWork dependency resolution
    _trackRelationships(entity, schema);

    // Process cascade operations
    _processRelations(entity, schema, CascadeOption.persist);
  }

  void _scheduleUpdate<T>(Object entity, ResolvedEntitySchema<T> schema) {
    _ensureTracked(entity, schema);
    _detectChangesFromSnapshot(entity, schema);
    _unitOfWork.scheduleUpdate(entity);

    // Sincroniza relações usando RelationshipManager
    _relationshipManager.syncBidirectionalRelations(entity, schema);

    // Process cascade operations
    _processRelations(entity, schema, CascadeOption.persist);
  }

  void _scheduleAfterExistenceCheck<T>(
    Object entity,
    ResolvedEntitySchema<T> schema,
    dynamic id,
  ) {
    _unitOfWork.scheduleExistenceCheck(
      entity,
      id,
      () async {
        // Entity exists - é UPDATE
        await _loadDatabaseSnapshot(entity, schema, id);
        _scheduleUpdate(entity, schema);
      },
      () async {
        // Entity doesn't exist - é INSERT
        _scheduleInsert(entity, schema);
      },
    );

    // Sync relationships mesmo antes da check
    _relationshipManager.syncBidirectionalRelations(entity, schema);

    // Process cascade operations
    _processRelations(entity, schema, CascadeOption.persist);
  }

  Future<void> _loadDatabaseSnapshot<T>(
    Object entity,
    ResolvedEntitySchema<T> schema,
    dynamic id,
  ) async {
    final pkColumn = schema.getColumnName(schema.primaryKey);
    final result = await database.execute(
      'SELECT * FROM ${schema.tableName} WHERE $pkColumn = ? LIMIT 1',
      [id],
    );

    if (result.rows.isEmpty) return;

    final row = result.rows.first;
    final snapshot = <String, dynamic>{};

    for (final column in schema.columns.values) {
      final dbValue = row[column.columnName];
      snapshot[column.propertyName] = dbValue;
    }

    _entitySnapshots[entity] = snapshot;
  }

  @override
  void remove<T>(T entity) {
    if (entity == null) {
      throw ArgumentError('Cannot remove null entity');
    }

    final original = _changeTracker.getOriginal(entity as Object);

    if (_processingEntities.contains(original)) {
      return;
    }

    final schema = schemaResolver.resolve<T>();

    final id = _getEntityId(original, schema);
    if (id == null || (id is int && id <= 0)) {
      throw Exception('Cannot remove entity without valid primary key');
    }

    _processingEntities.add(original);

    try {
      _processRelations(original, schema, CascadeOption.remove);
      _unitOfWork.scheduleDelete(original);
      _identityMap.remove(original);
      _changeTracker.stopTracking(original);
      _entitySnapshots.remove(original);
    } finally {
      _processingEntities.remove(original);
    }
  }

  @override
  Future<void> flush() async {
    await _unitOfWork.commit();

    _processingEntities.clear();

    _createSnapshotsForAllEntities();
  }

  void _createSnapshotsForAllEntities() {
    for (final entity in _identityMap.all) {
      final schema = schemaResolver.resolveByType(entity.runtimeType);
      _createSnapshot(entity, schema);

      if (!_changeTracker.isTracked(entity)) {
        _changeTracker.createTrackedProxy(entity, schema.classMetadata);
      }
    }
  }

  @override
  Future<void> refresh<T>(T entity) async {
    if (entity == null) {
      throw ArgumentError('Cannot refresh null entity');
    }

    final original = _changeTracker.getOriginal(entity as Object);
    final schema = schemaResolver.resolve<T>();
    final id = _getEntityId(original, schema);

    if (id == null) {
      throw Exception('Cannot refresh entity without primary key');
    }

    final pkColumn = schema.getColumnName(schema.primaryKey);

    final builder = QueryBuilder(database);
    final result = await builder
        .from(schema.tableName)
        .where(pkColumn, isEqualTo: id)
        .get();

    if (result.isEmpty) {
      throw EntityNotFoundException(
        'Entity not found: ${schema.tableName}#$id',
      );
    }

    final row = result.firstOrNull;
    _updateEntityFromRow(original, schema, row!);
    _changeTracker.resetTracking(original);
  }

  @override
  void clear() {
    _unitOfWork.clear();
    _identityMap.clear();
    _changeTracker.clear();
    _entitySnapshots.clear();
    _processingEntities.clear();
  }

  @override
  void detach<T>(T entity) {
    if (entity == null) return;

    final original = _changeTracker.getOriginal(entity as Object);
    _identityMap.remove(original);
    _changeTracker.stopTracking(original);
    _unitOfWork.removeEntity(original);
    _entitySnapshots.remove(original);
    _processingEntities.remove(original);
  }

  @override
  bool contains<T>(T entity) {
    if (entity == null) return false;
    final original = _changeTracker.getOriginal(entity as Object);
    return _identityMap.contains(original);
  }

  @override
  bool get hasPendingOperations => _unitOfWork.hasPendingOperations;

  @override
  int get pendingOperationsCount => _unitOfWork.pendingOperationsCount;

  void _ensureTracked<T>(Object entity, ResolvedEntitySchema<T> schema) {
    if (!_changeTracker.isTracked(entity)) {
      _changeTracker.createTrackedProxy(entity, schema.classMetadata);
    }

    if (!_entitySnapshots.containsKey(entity)) {
      _createSnapshot(entity, schema);
    }
  }

  void _createSnapshot<T>(Object entity, ResolvedEntitySchema<T> schema) {
    final snapshot = <String, dynamic>{};
    for (final column in schema.columns.values) {
      final getter = schema.classMetadata.getGetterByName(column.propertyName);
      if (getter != null) {
        snapshot[column.propertyName] = getter.getValue(entity);
      }
    }
    _entitySnapshots[entity] = snapshot;
  }

  void _detectChangesFromSnapshot<T>(
    Object entity,
    ResolvedEntitySchema<T> schema,
  ) {
    final snapshot = _entitySnapshots[entity];
    if (snapshot == null) return;

    final tracker = _changeTracker.getTracker(entity);
    if (tracker == null) return;

    for (final entry in snapshot.entries) {
      final currentGetter = schema.classMetadata.getGetterByName(entry.key);
      if (currentGetter == null) continue;

      final currentValue = currentGetter.getValue(entity);
      final snapshotValue = entry.value;

      if (currentValue != snapshotValue) {
        tracker.markChanged(entry.key, currentValue);
      }
    }
  }

  void _trackRelationships<T>(Object entity, ResolvedEntitySchema<T> schema) {
    // Track ManyToOne and OneToOne (owning side)
    for (final relation in schema.relations.values) {
      if (!relation.isManyToOne && !relation.isOneToOne) {
        continue;
      }

      final getter = schema.classMetadata.getGetterByName(
        relation.propertyName,
      );
      if (getter == null) continue;

      final parent = getter.getValue(entity);
      if (parent == null) continue;

      final originalParent = _changeTracker.getOriginal(parent);

      if (relation.foreignKey != null) {
        _unitOfWork.trackRelationship(
          originalParent,
          entity,
          relation.foreignKey!,
        );
      }
    }

    // Track OneToMany and OneToOne inverse
    for (final relation in schema.relations.values) {
      if (!relation.isOneToMany && !relation.isOneToOneInverse) {
        continue;
      }

      final getter = schema.classMetadata.getGetterByName(
        relation.propertyName,
      );
      if (getter == null) continue;

      final value = getter.getValue(entity);
      if (value == null) continue;

      if (value is List) {
        for (final child in value) {
          if (child != null) {
            final originalChild = _changeTracker.getOriginal(child);
            _trackInverseRelationship(entity, originalChild, relation);
          }
        }
      } else {
        final originalChild = _changeTracker.getOriginal(value);
        _trackInverseRelationship(entity, originalChild, relation);
      }
    }
  }

  void _trackInverseRelationship(
    Object parent,
    Object child,
    RelationInfo parentRelation,
  ) {
    if (parentRelation.mappedBy == null) return;

    final childSchema = schemaResolver.resolveByType(child.runtimeType);

    final owningRelation = childSchema.relations[parentRelation.mappedBy];
    if (owningRelation == null) return;

    if (owningRelation.foreignKey != null) {
      _unitOfWork.trackRelationship(
        parent,
        child,
        owningRelation.foreignKey!,
      );
    }
  }

  void _processRelations<T>(
    Object entity,
    ResolvedEntitySchema<T> schema,
    CascadeOption cascade,
  ) {
    for (final relation in schema.relations.values) {
      if (!relation.cascade.contains(cascade)) continue;

      final getter = schema.classMetadata.getGetterByName(
        relation.propertyName,
      );
      if (getter == null) continue;

      final value = getter.getValue(entity);
      if (value == null) continue;

      if (value is List) {
        for (final item in value) {
          if (item != null) {
            _cascadeOperation(item, relation.relatedType, cascade);
          }
        }
      } else {
        _cascadeOperation(value, relation.relatedType, cascade);
      }
    }
  }

  void _cascadeOperation(
    Object entity,
    Type entityType,
    CascadeOption cascade,
  ) {
    final schema = schemaResolver.resolveByType(entityType);
    schema.classMetadata.typeMetadata.captureGeneric(<T>() {
      if (cascade == CascadeOption.persist) {
        persist<T>(entity as T);
      } else if (cascade == CascadeOption.remove) {
        remove<T>(entity as T);
      }
    });
  }

  dynamic _getEntityId<T>(Object entity, ResolvedEntitySchema<T> schema) {
    final getter = schema.classMetadata.getGetterByName(schema.primaryKey);
    return getter?.getValue(entity);
  }

  void _updateEntityFromRow<T>(
    Object entity,
    ResolvedEntitySchema<T> schema,
    Map<String, dynamic> row,
  ) {
    for (final entry in row.entries) {
      final column = schema.columns.values.firstWhereOrNull(
        (col) => col.columnName == entry.key,
      );

      if (column == null) continue;

      final setter = schema.classMetadata.getSetterByName(
        column.propertyName,
      );

      setter?.setValue(entity, entry.value);
    }
  }

  bool _isProxy(Object entity) {
    return entity is AbstractProxy;
  }
}
