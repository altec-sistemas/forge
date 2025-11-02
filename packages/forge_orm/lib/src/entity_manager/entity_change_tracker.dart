import 'package:forge_core/forge_core.dart';

/// Tracks changes in an entity through proxy
class EntityChangeTracker {
  final Object _originalEntity;
  final Object _proxyEntity;
  final ClassMetadata _metadata;
  final Set<String> _changedProperties = {};
  final Map<String, dynamic> _originalValues = {};

  EntityChangeTracker({
    required Object originalEntity,
    required Object proxyEntity,
    required ClassMetadata metadata,
  }) : _originalEntity = originalEntity,
       _proxyEntity = proxyEntity,
       _metadata = metadata;

  Object get entity => _proxyEntity;
  Object get originalEntity => _originalEntity;
  Set<String> get changedProperties => Set.unmodifiable(_changedProperties);
  bool get hasChanges => _changedProperties.isNotEmpty;

  /// Marks a property as changed
  void markChanged(String propertyName, dynamic newValue) {
    if (!_changedProperties.contains(propertyName)) {
      final getter = _metadata.getters?.firstWhere(
        (g) => g.name == propertyName,
        orElse: () => throw Exception('Getter $propertyName not found'),
      );
      _originalValues[propertyName] = getter?.getValue(_originalEntity);
    }

    _changedProperties.add(propertyName);
  }

  /// Gets the original value of a property
  dynamic getOriginalValue(String propertyName) {
    return _originalValues[propertyName];
  }

  /// Resets change tracking
  void reset() {
    _changedProperties.clear();
    _originalValues.clear();
  }
}

/// Change tracking manager for entities
class ChangeTrackingManager {
  final Map<Object, EntityChangeTracker> _trackers = {};

  // Callback para RelationshipManager - será definido pelo EntityManager
  void Function(Object entity, String propertyName, dynamic newValue)?
  onRelationshipChange;

  /// Creates a trackable proxy for an entity
  T createTrackedProxy<T>(T entity, ClassMetadata metadata) {
    if (metadata.createProxy == null) {
      return entity!;
    }

    final handler = ProxyHandler(
      onSetterAccess: (setterName, value) {
        final tracker = _trackers[entity];
        if (tracker != null) {
          tracker.markChanged(setterName, value);
        }

        // Notify relationship manager if this is a relationship property
        if (onRelationshipChange != null) {
          onRelationshipChange!(entity!, setterName, value);
        }

        return null;
      },
    );

    final proxy = metadata.createProxy!(entity!, handler, metadata);

    _trackers[entity] = EntityChangeTracker(
      originalEntity: entity,
      proxyEntity: proxy,
      metadata: metadata,
    );

    return proxy as T;
  }

  /// Gets the tracker for an entity
  EntityChangeTracker? getTracker(Object entity) {
    return _trackers[entity];
  }

  /// Checks if an entity is being tracked
  bool isTracked(Object entity) {
    return _trackers.containsKey(entity);
  }

  /// Gets the original entity (without proxy)
  Object getOriginal(Object entity) {
    if (entity is AbstractProxy) {
      return entity.target;
    }
    final tracker = _trackers[entity];
    return tracker?.originalEntity ?? entity;
  }

  /// Removes tracking for an entity
  void untrack(Object entity) {
    _trackers.remove(entity);
  }

  /// Removes all tracking
  void clear() {
    _trackers.clear();
  }

  /// Gets all changed properties of an entity
  Set<String>? getChangedProperties(Object entity) {
    final tracker = _trackers[entity];
    return tracker?.changedProperties;
  }

  /// Checks if an entity has changes
  bool hasChanges(Object entity) {
    final tracker = _trackers[entity];
    return tracker?.hasChanges ?? false;
  }

  /// Resets the change tracking for an entity (keeps the tracker active)
  ///
  /// This method clears all tracked changes but keeps the entity in the tracking system.
  /// Useful after flush operations to start tracking new changes.
  void resetTracking(Object entity) {
    final tracker = _trackers[entity];
    if (tracker != null) {
      tracker.reset();
    }
  }

  /// Stops tracking an entity completely (removes from tracking system)
  ///
  /// This is an alias for [untrack]. Use this when you want to completely
  /// remove an entity from the tracking system, typically after deletion.
  void stopTracking(Object entity) {
    untrack(entity);
  }
}
