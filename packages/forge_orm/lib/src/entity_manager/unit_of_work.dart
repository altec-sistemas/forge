import 'package:collection/collection.dart';
import 'package:forge_core/forge_core.dart';

import '../../forge_orm.dart';
import 'entity_change_tracker.dart';
import 'entity_persister.dart';
import 'identity_map.dart';

class UnitOfWork {
  final EntityPersister persister;
  final IdentityMap identityMap;
  final ChangeTrackingManager changeTracker;
  final MetadataSchemaResolver schemaResolver;

  final List<ScheduledInsert> _scheduledInserts = [];
  final List<ScheduledUpdate> _scheduledUpdates = [];
  final List<ScheduledDelete> _scheduledDeletes = [];
  final List<ExistenceCheck> _existenceChecks = [];
  final Map<Object, RelationshipData> _relationships = {};

  UnitOfWork({
    required this.persister,
    required this.identityMap,
    required this.changeTracker,
    required this.schemaResolver,
  });

  void scheduleInsert(Object entity) {
    if (_isAlreadyScheduled(entity, OperationType.insert)) return;

    _removeFromOtherSchedules(entity);
    _scheduledInserts.add(ScheduledInsert(entity));
  }

  void scheduleUpdate(Object entity) {
    if (_isAlreadyScheduled(entity, OperationType.update)) return;

    if (_isScheduledFor(entity, OperationType.insert)) return;

    _removeFromSchedule(entity, OperationType.update);
    _scheduledUpdates.add(ScheduledUpdate(entity));
  }

  void scheduleDelete(Object entity) {
    _removeFromOtherSchedules(entity);
    _scheduledDeletes.add(ScheduledDelete(entity));
  }

  void scheduleExistenceCheck(
    Object entity,
    dynamic id,
    Future<void> Function() onExists,
    Future<void> Function() onNotExists,
  ) {
    _existenceChecks.add(ExistenceCheck(entity, id, onExists, onNotExists));
  }

  void trackRelationship(Object parent, Object child, String foreignKey) {
    if (!_relationships.containsKey(child)) {
      _relationships[child] = RelationshipData(parent, foreignKey);
    }
  }

  Future<void> commit() async {
    await _processExistenceChecks();

    final operations = _computeExecutionOrder();

    await persister.executeInTransaction((_) async {
      for (final operation in operations) {
        switch (operation) {
          case ScheduledInsert():
            final id = await persister.insert(operation.entity);
            if (id != null) {
              identityMap.add(operation.entity, id);
              _propagateForeignKey(operation.entity, id);
            }
          case ScheduledUpdate():
            if (changeTracker.hasChanges(operation.entity)) {
              await persister.update(operation.entity, changeTracker);
            }
          case ScheduledDelete():
            await persister.delete(operation.entity);
        }
      }
    });

    _reset();
  }

  void clear() {
    _scheduledInserts.clear();
    _scheduledUpdates.clear();
    _scheduledDeletes.clear();
    _existenceChecks.clear();
    _relationships.clear();
  }

  void removeEntity(Object entity) {
    _scheduledInserts.removeWhere((op) => identical(op.entity, entity));
    _scheduledUpdates.removeWhere((op) => identical(op.entity, entity));
    _scheduledDeletes.removeWhere((op) => identical(op.entity, entity));
    _relationships.remove(entity);
  }

  bool isScheduled(Object entity) {
    return _isScheduledFor(entity, OperationType.insert) ||
        _isScheduledFor(entity, OperationType.update) ||
        _isScheduledFor(entity, OperationType.delete);
  }

  bool get hasPendingOperations {
    return _scheduledInserts.isNotEmpty ||
        _scheduledUpdates.isNotEmpty ||
        _scheduledDeletes.isNotEmpty ||
        _existenceChecks.isNotEmpty;
  }

  int get pendingOperationsCount {
    return _scheduledInserts.length +
        _scheduledUpdates.length +
        _scheduledDeletes.length +
        _existenceChecks.length;
  }

  Future<void> _processExistenceChecks() async {
    if (_existenceChecks.isEmpty) return;

    await Future.wait(
      _existenceChecks.map((check) async {
        final exists = await persister.exists(check.entity);
        if (exists) {
          await check.onExists();
        } else {
          await check.onNotExists();
        }
      }),
    );
    _existenceChecks.clear();
  }

  List<dynamic> _computeExecutionOrder() {
    final orderedInserts = _orderInsertsByDependency();
    return [...orderedInserts, ..._scheduledUpdates, ..._scheduledDeletes];
  }

  List<ScheduledInsert> _orderInsertsByDependency() {
    final ordered = <ScheduledInsert>[];
    final remaining = List<ScheduledInsert>.from(_scheduledInserts);

    while (remaining.isNotEmpty) {
      var progress = false;

      for (var i = 0; i < remaining.length; i++) {
        final insert = remaining[i];

        if (_canInsertNow(insert.entity, ordered)) {
          ordered.add(insert);
          remaining.removeAt(i);
          i--;
          progress = true;
        }
      }

      if (!progress && remaining.isNotEmpty) {
        ordered.add(remaining.removeAt(0));
      }
    }

    return ordered;
  }

  bool _canInsertNow(Object entity, List<ScheduledInsert> ordered) {
    final relationship = _relationships[entity];
    if (relationship == null) return true;

    final parent = relationship.parent;

    if (identityMap.contains(parent)) return true;

    final parentInsert = _scheduledInserts.firstWhereOrNull(
      (op) => identical(op.entity, parent),
    );

    if (parentInsert == null) return true;

    return ordered.contains(parentInsert);
  }

  void _propagateForeignKey(Object entity, dynamic id) {
    final children = _relationships.entries.where(
      (e) => identical(e.value.parent, entity),
    );

    for (final entry in children) {
      final child = entry.key;
      final foreignKeyColumn = entry.value.foreignKey;

      final schema = schemaResolver.resolveByType(child.runtimeType);

      // Find the property name that corresponds to the foreign key column
      String? propertyName;
      for (final column in schema.columns.values) {
        if (column.columnName == foreignKeyColumn) {
          propertyName = column.propertyName;
          break;
        }
      }

      // If not found by column name, try using it directly as property name
      propertyName ??= foreignKeyColumn;

      final setter = schema.classMetadata.getSetterByName(propertyName);

      setter?.setValue(child, id);
    }
  }

  bool _isAlreadyScheduled(Object entity, OperationType type) {
    return _isScheduledFor(entity, type);
  }

  bool _isScheduledFor(Object entity, OperationType type) {
    switch (type) {
      case OperationType.insert:
        return _scheduledInserts.any((op) => identical(op.entity, entity));
      case OperationType.update:
        return _scheduledUpdates.any((op) => identical(op.entity, entity));
      case OperationType.delete:
        return _scheduledDeletes.any((op) => identical(op.entity, entity));
    }
  }

  void _removeFromOtherSchedules(Object entity) {
    _scheduledInserts.removeWhere((op) => identical(op.entity, entity));
    _scheduledUpdates.removeWhere((op) => identical(op.entity, entity));
    _scheduledDeletes.removeWhere((op) => identical(op.entity, entity));
  }

  void _removeFromSchedule(Object entity, OperationType type) {
    switch (type) {
      case OperationType.insert:
        _scheduledInserts.removeWhere((op) => identical(op.entity, entity));
        break;
      case OperationType.update:
        _scheduledUpdates.removeWhere((op) => identical(op.entity, entity));
        break;
      case OperationType.delete:
        _scheduledDeletes.removeWhere((op) => identical(op.entity, entity));
        break;
    }
  }

  void _reset() {
    _scheduledInserts.clear();
    _scheduledUpdates.clear();
    _scheduledDeletes.clear();
    _relationships.clear();

    for (final entity in identityMap.all) {
      changeTracker.resetTracking(entity);
    }
  }
}

class ScheduledInsert extends ScheduledOperation {
  ScheduledInsert(super.entity);
}

class ScheduledUpdate extends ScheduledOperation {
  ScheduledUpdate(super.entity);
}

class ScheduledDelete extends ScheduledOperation {
  ScheduledDelete(super.entity);
}

sealed class ScheduledOperation {
  final Object entity;
  ScheduledOperation(this.entity);
}

class ExistenceCheck {
  final Object entity;
  final dynamic id;
  final Future<void> Function() onExists;
  final Future<void> Function() onNotExists;

  ExistenceCheck(this.entity, this.id, this.onExists, this.onNotExists);
}

class RelationshipData {
  final Object parent;
  final String foreignKey;

  RelationshipData(this.parent, this.foreignKey);
}

enum OperationType {
  insert,
  update,
  delete,
}
