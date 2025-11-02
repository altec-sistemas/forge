class IdentityMap {
  final Map<Type, Map<dynamic, Object>> _map = {};

  void add(Object entity, dynamic id) {
    final type = entity.runtimeType;
    _map.putIfAbsent(type, () => {});
    _map[type]![id] = entity;
  }

  Object? get(Type type, dynamic id) {
    return _map[type]?[id];
  }

  bool contains(Object entity) {
    final type = entity.runtimeType;
    final typeMap = _map[type];
    if (typeMap == null) return false;

    return typeMap.values.any((e) => identical(e, entity));
  }

  dynamic getId(Object entity) {
    final type = entity.runtimeType;
    final typeMap = _map[type];
    if (typeMap == null) return null;

    for (final entry in typeMap.entries) {
      if (identical(entry.value, entity)) {
        return entry.key;
      }
    }
    return null;
  }

  void remove(Object entity) {
    final type = entity.runtimeType;
    final typeMap = _map[type];
    if (typeMap == null) return;

    typeMap.removeWhere((_, e) => identical(e, entity));
  }

  void clear() {
    _map.clear();
  }

  Iterable<Object> get all {
    return _map.values.expand((typeMap) => typeMap.values);
  }
}
