import 'package:forge_core/forge_core.dart';

import '../../forge_orm.dart';
import 'entity_change_tracker.dart';
import 'identity_map.dart';

class EntityPersister {
  final Database database;
  final Serializer serializer;
  final MetadataSchemaResolver schemaResolver;
  final IdentityMap identityMap;

  EntityPersister({
    required this.database,
    required this.serializer,
    required this.schemaResolver,
    required this.identityMap,
  });

  Future<dynamic> insert(Object entity) async {
    final schema = schemaResolver.resolveByType(entity.runtimeType);

    final data = serializer.normalize(entity);
    if (data is! Map<String, dynamic>) {
      throw Exception('Normalized data must be a Map<String, dynamic>');
    }

    final columnData = _buildColumnData(schema, data);

    final pkColumn = schema.primaryKeyColumn;
    if (pkColumn.isAutoIncrement && columnData[pkColumn.columnName] == null) {
      columnData.remove(pkColumn.columnName);
    }

    final builder = QueryBuilder(database);
    final id = await builder.from(schema.tableName).insert(columnData);

    if (pkColumn.isAutoIncrement && id != null) {
      _setEntityId(entity, schema, id);
      return id;
    }

    return _getEntityId(entity, schema);
  }

  Future<void> update(
    Object entity,
    ChangeTrackingManager changeTracker,
  ) async {
    final schema = schemaResolver.resolveByType(entity.runtimeType);

    final id = _getEntityId(entity, schema);
    if (id == null) {
      throw Exception('Cannot update entity without primary key');
    }

    final changedProps = changeTracker.getChangedProperties(entity);

    if (changedProps == null || changedProps.isEmpty) {
      return;
    }

    final columnData = _buildColumnDataFromChanges(
      entity,
      schema,
      changedProps,
    );

    if (columnData.isEmpty) return;

    final builder = QueryBuilder(database);
    final pkColumn = schema.getColumnName(schema.primaryKey);

    await builder
        .from(schema.tableName)
        .where(pkColumn, isEqualTo: id)
        .update(columnData);
  }

  Future<void> delete(Object entity) async {
    final schema = schemaResolver.resolveByType(entity.runtimeType);
    final id = _getEntityId(entity, schema);

    final builder = QueryBuilder(database);
    await builder
        .from(schema.tableName)
        .where(schema.primaryKey, isEqualTo: id)
        .delete();
  }

  Future<bool> exists(Object entity) async {
    final schema = schemaResolver.resolveByType(entity.runtimeType);
    final pkColumn = schema.getColumnName(schema.primaryKey);
    final id = _getEntityId(entity, schema);

    if (id == null) {
      return false;
    }

    final builder = QueryBuilder(database);
    final result = await builder
        .from(schema.tableName)
        .select(['1'])
        .where(pkColumn, isEqualTo: id)
        .get();

    return result.isNotEmpty;
  }

  Future<T> executeInTransaction<T>(
    Future<T> Function(Connection) action,
  ) async {
    return await database.connection.transaction((tx) => action(tx));
  }

  Map<String, dynamic> _buildColumnData(
    ResolvedEntitySchema schema,
    Map<String, dynamic> data,
  ) {
    final columnData = <String, dynamic>{};

    for (final entry in data.entries) {
      if (schema.isColumn(entry.key)) {
        final columnName = schema.getColumnName(entry.key);
        columnData[columnName] = entry.value;
      }
    }

    return columnData;
  }

  Map<String, dynamic> _buildColumnDataFromChanges(
    Object entity,
    ResolvedEntitySchema schema,
    Set<String> changedProps,
  ) {
    final columnData = <String, dynamic>{};

    for (final propName in changedProps) {
      if (schema.isColumn(propName) && propName != schema.primaryKey) {
        final columnName = schema.getColumnName(propName);
        final getter = schema.classMetadata.getGetterByName(
          propName,
        );

        if (getter != null) {
          columnData[columnName] = serializer.normalize(
            getter.getValue(entity),
          );
        }
      }
    }

    return columnData;
  }

  dynamic _getEntityId(Object entity, ResolvedEntitySchema schema) {
    final getter = schema.classMetadata.getGetterByName(schema.primaryKey);
    return getter?.getValue(entity);
  }

  void _setEntityId(Object entity, ResolvedEntitySchema schema, dynamic id) {
    final setter = schema.classMetadata.getSetterByName(schema.primaryKey);
    setter?.setValue(entity, id);
  }
}
