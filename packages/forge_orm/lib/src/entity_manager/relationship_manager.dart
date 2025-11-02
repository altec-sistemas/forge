import 'package:collection/collection.dart';

import '../../forge_orm.dart';
import 'entity_change_tracker.dart';

/// Manages relationships and join columns between entities
///
/// This class is responsible for:
/// - Setting foreign key values when relations are attached
/// - Synchronizing bidirectional relationships
/// - Handling circular references
class RelationshipManager {
  final MetadataSchemaResolver schemaResolver;
  final ChangeTrackingManager changeTracker;

  RelationshipManager({
    required this.schemaResolver,
    required this.changeTracker,
  });

  /// Handles relationship attachment when a setter is called on a proxy
  /// This is called by the ChangeTrackingManager when tracking changes
  void handleRelationshipSetter(
    Object entity,
    String propertyName,
    dynamic newValue,
    ResolvedEntitySchema schema,
  ) {
    final relation = schema.relations[propertyName];
    if (relation == null) return;

    // Get original entities (unwrap proxies)
    final originalEntity = changeTracker.getOriginal(entity);

    if (newValue != null) {
      // Handle setting a relation
      if (newValue is List) {
        // OneToMany or similar collection
        _handleCollectionRelation(originalEntity, newValue, relation, schema);
      } else {
        // ManyToOne, OneToOne
        _handleSingleRelation(originalEntity, newValue, relation, schema);
      }
    } else {
      // Handle clearing a relation
      _clearRelation(originalEntity, relation, schema);
    }
  }

  /// Synchronizes bidirectional relationships for a given entity
  /// This should be called when an entity is persisted
  void syncBidirectionalRelations(Object entity, ResolvedEntitySchema schema) {
    final originalEntity = changeTracker.getOriginal(entity);

    // Process owning side (ManyToOne, OneToOne with foreignKey)
    for (final relation in schema.relations.values) {
      if (relation.isManyToOne || relation.isOneToOne) {
        _syncOwningSideRelation(originalEntity, relation, schema);
      }
    }

    // Process inverse side (OneToMany, OneToOne inverse)
    for (final relation in schema.relations.values) {
      if (relation.isOneToMany || relation.isOneToOneInverse) {
        _syncInverseSideRelation(originalEntity, relation, schema);
      }
    }
  }

  /// Sets the foreign key value on an entity when a parent is assigned
  void setForeignKey(
    Object childEntity,
    dynamic parentId,
    String foreignKeyColumn,
    ResolvedEntitySchema childSchema,
  ) {
    // Find property name for the foreign key column
    String? propertyName = _findPropertyNameForColumn(
      foreignKeyColumn,
      childSchema,
    );

    if (propertyName == null) return;

    final setter = childSchema.classMetadata.getSetterByName(propertyName);
    if (setter != null) {
      setter.setValue(childEntity, parentId);
    }
  }

  /// Gets the foreign key value from an entity
  dynamic getForeignKey(
    Object entity,
    String foreignKeyColumn,
    ResolvedEntitySchema schema,
  ) {
    String? propertyName = _findPropertyNameForColumn(foreignKeyColumn, schema);
    if (propertyName == null) return null;

    final getter = schema.classMetadata.getGetterByName(propertyName);
    return getter?.getValue(entity);
  }

  /// Checks if foreign key needs to be updated
  bool needsForeignKeyUpdate(
    Object childEntity,
    dynamic parentId,
    String foreignKeyColumn,
    ResolvedEntitySchema childSchema,
  ) {
    final currentForeignKey = getForeignKey(
      childEntity,
      foreignKeyColumn,
      childSchema,
    );
    return currentForeignKey != parentId;
  }

  void _handleSingleRelation(
    Object entity,
    dynamic relatedEntity,
    RelationInfo relation,
    ResolvedEntitySchema schema,
  ) {
    final originalRelated = changeTracker.getOriginal(relatedEntity);

    // Set foreign key if this is owning side
    if (relation.foreignKey != null) {
      final relatedSchema = schemaResolver.resolveByType(
        originalRelated.runtimeType,
      );
      final relatedId = _getEntityId(originalRelated, relatedSchema);

      if (relatedId != null) {
        setForeignKey(entity, relatedId, relation.foreignKey!, schema);
      }
    }

    // Sync bidirectional relationship
    if (relation.inversedBy != null) {
      _syncInverseForSingleRelation(
        entity,
        originalRelated,
        relation.inversedBy!,
      );
    }
  }

  void _handleCollectionRelation(
    Object entity,
    List<dynamic> relatedEntities,
    RelationInfo relation,
    ResolvedEntitySchema schema,
  ) {
    for (final relatedEntity in relatedEntities) {
      if (relatedEntity == null) continue;

      final originalRelated = changeTracker.getOriginal(relatedEntity);

      // If this is OneToMany, sync the owning side (ManyToOne)
      if (relation.mappedBy != null) {
        _syncOwningForCollectionRelation(
          entity,
          originalRelated,
          relation.mappedBy!,
        );
      }
    }
  }

  void _clearRelation(
    Object entity,
    RelationInfo relation,
    ResolvedEntitySchema schema,
  ) {
    // If clearing owning side, set foreign key to null
    if (relation.foreignKey != null) {
      setForeignKey(entity, null, relation.foreignKey!, schema);
    }

    // Clear inverse side too if bidirectional
    // This would require getting the old value first
    // For now, we'll handle this during sync
  }

  void _syncOwningSideRelation(
    Object entity,
    RelationInfo relation,
    ResolvedEntitySchema schema,
  ) {
    final getter = schema.classMetadata.getGetterByName(relation.propertyName);
    if (getter == null) return;

    final relatedEntity = getter.getValue(entity);
    if (relatedEntity == null) return;

    final originalRelated = changeTracker.getOriginal(relatedEntity);

    // Set foreign key
    if (relation.foreignKey != null) {
      final relatedSchema = schemaResolver.resolveByType(
        originalRelated.runtimeType,
      );
      final relatedId = _getEntityId(originalRelated, relatedSchema);

      if (relatedId != null &&
          needsForeignKeyUpdate(
            entity,
            relatedId,
            relation.foreignKey!,
            schema,
          )) {
        setForeignKey(entity, relatedId, relation.foreignKey!, schema);
      }
    }

    if (relation.inversedBy != null) {
      final relatedSchema = schemaResolver.resolveByType(
        originalRelated.runtimeType,
      );

      final inverseRelation = relatedSchema.relations[relation.inversedBy];

      if (inverseRelation != null) {
        _ensureInverseContains(
          originalRelated,
          entity,
          inverseRelation,
          relatedSchema,
        );
      }
    }
  }

  void _syncInverseSideRelation(
    Object entity,
    RelationInfo relation,
    ResolvedEntitySchema schema,
  ) {
    if (relation.mappedBy == null) return;

    final getter = schema.classMetadata.getGetterByName(relation.propertyName);
    if (getter == null) return;

    final value = getter.getValue(entity);
    if (value == null) return;

    final relatedEntities = (value is List) ? value : [value];

    for (final relatedEntity in relatedEntities) {
      if (relatedEntity == null) continue;

      final originalRelated = changeTracker.getOriginal(relatedEntity);
      final relatedSchema = schemaResolver.resolveByType(
        originalRelated.runtimeType,
      );

      final owningRelation = relatedSchema.relations[relation.mappedBy];
      if (owningRelation == null) continue;

      // Set owning side reference
      final owningSetter = relatedSchema.classMetadata.getSetterByName(
        owningRelation.propertyName,
      );
      if (owningSetter != null) {
        final currentValue = relatedSchema.classMetadata
            .getGetterByName(owningRelation.propertyName)
            ?.getValue(originalRelated);

        if (!identical(currentValue, entity)) {
          owningSetter.setValue(originalRelated, entity);
        }
      }

      // Set foreign key
      if (owningRelation.foreignKey != null) {
        final parentId = _getEntityId(entity, schema);
        if (parentId != null &&
            needsForeignKeyUpdate(
              originalRelated,
              parentId,
              owningRelation.foreignKey!,
              relatedSchema,
            )) {
          setForeignKey(
            originalRelated,
            parentId,
            owningRelation.foreignKey!,
            relatedSchema,
          );
        }
      }
    }
  }

  void _syncInverseForSingleRelation(
    Object owningEntity,
    Object inverseEntity,
    String inversePropertyName,
  ) {
    final inverseSchema = schemaResolver.resolveByType(
      inverseEntity.runtimeType,
    );
    final inverseRelation = inverseSchema.relations[inversePropertyName];

    if (inverseRelation == null) return;

    _ensureInverseContains(
      inverseEntity,
      owningEntity,
      inverseRelation,
      inverseSchema,
    );
  }

  void _syncOwningForCollectionRelation(
    Object inverseEntity,
    Object owningEntity,
    String owningPropertyName,
  ) {
    final owningSchema = schemaResolver.resolveByType(owningEntity.runtimeType);
    final owningRelation = owningSchema.relations[owningPropertyName];

    if (owningRelation == null) return;

    // Set owning side reference
    final owningSetter = owningSchema.classMetadata.getSetterByName(
      owningRelation.propertyName,
    );
    if (owningSetter != null) {
      final currentValue = owningSchema.classMetadata
          .getGetterByName(owningRelation.propertyName)
          ?.getValue(owningEntity);

      if (!identical(currentValue, inverseEntity)) {
        owningSetter.setValue(owningEntity, inverseEntity);
      }
    }

    // Set foreign key
    if (owningRelation.foreignKey != null) {
      final inverseSchema = schemaResolver.resolveByType(
        inverseEntity.runtimeType,
      );
      final inverseId = _getEntityId(inverseEntity, inverseSchema);

      if (inverseId != null &&
          needsForeignKeyUpdate(
            owningEntity,
            inverseId,
            owningRelation.foreignKey!,
            owningSchema,
          )) {
        setForeignKey(
          owningEntity,
          inverseId,
          owningRelation.foreignKey!,
          owningSchema,
        );
      }
    }
  }

  void _ensureInverseContains(
    Object inverseEntity,
    Object owningEntity,
    RelationInfo inverseRelation,
    ResolvedEntitySchema inverseSchema,
  ) {
    final getter = inverseSchema.classMetadata.getGetterByName(
      inverseRelation.propertyName,
    );
    if (getter == null) return;

    final type = getter.typeMetadata;
    final isList = type.isType<List>();

    if (isList) {
      final currentValue = getter.getValue(inverseEntity) as List?;
      final itemType = type.typeArguments.firstOrNull;

      if (itemType == null) {
        return;
      }

      if (currentValue == null) {
        final setter = inverseSchema.classMetadata.getSetterByName(
          inverseRelation.propertyName,
        );

        if (setter == null) {
          return;
        }

        itemType.captureGeneric(
          <S>() => setter.setValue(inverseEntity, <S>[owningEntity as S]),
        );

        return;
      }

      if (!currentValue.any((e) => identical(e, owningEntity))) {
        currentValue.add(owningEntity);
      }

      return;
    }

    final currentValue = getter.getValue(inverseEntity);
    if (!identical(currentValue, owningEntity)) {
      final setter = inverseSchema.classMetadata.getSetterByName(
        inverseRelation.propertyName,
      );
      if (setter != null) {
        setter.setValue(inverseEntity, owningEntity);
      }
    }
  }

  String? _findPropertyNameForColumn(
    String columnName,
    ResolvedEntitySchema schema,
  ) {
    // Try to find by column name first
    for (final column in schema.columns.values) {
      if (column.columnName == columnName) {
        return column.propertyName;
      }
    }

    // If not found, try using column name as property name
    if (schema.isColumn(columnName)) {
      return columnName;
    }

    return null;
  }

  dynamic _getEntityId(Object entity, ResolvedEntitySchema schema) {
    final getter = schema.classMetadata.getGetterByName(schema.primaryKey);
    return getter?.getValue(entity);
  }
}
