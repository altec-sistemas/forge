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

  /// Creates a trackable proxy for an entity
  Object createTrackedProxy<T>(T entity, ClassMetadata metadata) {
    if (_trackers.containsKey(entity)) {
      return _trackers[entity]!.entity;
    }

    if (metadata.createProxy == null) {
      return entity!;
    }

    final handler = ProxyHandler(
      onSetterAccess: (setterName, value) {
        final tracker = _trackers[entity];
        if (tracker != null) {
          tracker.markChanged(setterName, value);
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

    return proxy;
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
}
