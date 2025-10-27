import 'package:forge_core/forge_core.dart';
import 'annotations.dart';

class ColumnInfo {
  final String propertyName;
  final String columnName;
  final Column columnAnnotation;

  ColumnInfo({
    required this.propertyName,
    required this.columnName,
    required this.columnAnnotation,
  });

  bool get isPrimaryKey => columnAnnotation.primaryKey;
  bool get isAutoIncrement => columnAnnotation.autoIncrement;
  bool get isNullable => columnAnnotation.nullable;
  ColumnType get type => columnAnnotation.type;
  DateTimeRole? get dateTimeRole => columnAnnotation.dateTimeRole;
}

class RelationInfo<T> {
  final String propertyName;
  final String relationName;
  final Relation<T> relationAnnotation;
  final Type relatedType;

  RelationInfo({
    required this.propertyName,
    required this.relationName,
    required this.relationAnnotation,
    required this.relatedType,
  });

  RelationType get type => relationAnnotation.type;
  String get foreignKey => relationAnnotation.foreignKey;
  String get localKey => relationAnnotation.localKey;
  List<CascadeOption> get cascade => relationAnnotation.cascade;
  bool get hasCascadePersist => relationAnnotation.hasCascadePersist;
  bool get hasCascadeRemove => relationAnnotation.hasCascadeRemove;

  bool get isInverse =>
      type == RelationType.belongsTo ||
      type == RelationType.conditionalBelongsTo;
}

class ResolvedEntitySchema<T> with GenericCaller<T> {
  final Type entityType;
  final String tableName;
  final Map<String, ColumnInfo> columns;
  final Map<String, RelationInfo> relations;
  final ClassMetadata classMetadata;

  ResolvedEntitySchema({
    required this.entityType,
    required this.tableName,
    required this.columns,
    required this.relations,
    required this.classMetadata,
  });

  String get primaryKey {
    final pkColumn = columns.values.firstWhere(
      (col) => col.isPrimaryKey,
      orElse: () => throw Exception('No primary key found in $entityType'),
    );
    return pkColumn.propertyName;
  }

  ColumnInfo get primaryKeyColumn {
    return columns.values.firstWhere(
      (col) => col.isPrimaryKey,
      orElse: () => throw Exception('No primary key found in $entityType'),
    );
  }

  String? get syncAt {
    try {
      final col = columns.values.firstWhere(
        (col) => col.dateTimeRole == DateTimeRole.syncAt,
      );
      return col.propertyName;
    } catch (_) {
      return null;
    }
  }

  String? get updatedAt {
    try {
      final col = columns.values.firstWhere(
        (col) => col.dateTimeRole == DateTimeRole.updatedAt,
      );
      return col.propertyName;
    } catch (_) {
      return null;
    }
  }

  String? get createdAt {
    try {
      final col = columns.values.firstWhere(
        (col) => col.dateTimeRole == DateTimeRole.createdAt,
      );
      return col.propertyName;
    } catch (_) {
      return null;
    }
  }

  String getColumnName(String propertyName) {
    final column = columns[propertyName];
    if (column == null) {
      throw Exception('Column $propertyName not found in $entityType');
    }
    return column.columnName;
  }

  bool isColumn(String propertyName) => columns.containsKey(propertyName);

  bool isRelation(String propertyName) => relations.containsKey(propertyName);
}

class MetadataSchemaResolver {
  final MetadataRegistry _registry;
  final NamingStrategy _namingStrategy;
  final Map<Type, ResolvedEntitySchema> _schemaCache = {};

  MetadataSchemaResolver(this._registry, [NamingStrategy? namingStrategy])
    : _namingStrategy = namingStrategy ?? DefaultNamingStrategy();

  ResolvedEntitySchema<T> resolve<T>() {
    if (_schemaCache.containsKey(T)) {
      return _schemaCache[T] as ResolvedEntitySchema<T>;
    }

    final classMetadata = _registry.getClassMetadata<T>();

    final entityAnnotation = classMetadata.firstAnnotationOf<Entity>();
    if (entityAnnotation == null) {
      throw Exception('Class $T is not annotated with @Entity');
    }

    final columns = _resolveColumns(classMetadata);
    final relations = _resolveRelations(classMetadata);

    final tableName = entityAnnotation.table.isNotEmpty
        ? entityAnnotation.table
        : _namingStrategy.tableName(T.toString());

    final schema = ResolvedEntitySchema<T>(
      entityType: T,
      tableName: tableName,
      columns: columns,
      relations: relations,
      classMetadata: classMetadata,
    );

    _schemaCache[T] = schema;

    return schema;
  }

  ResolvedEntitySchema resolveByType(Type type) {
    if (_schemaCache.containsKey(type)) {
      return _schemaCache[type]!;
    }

    final classMetadata = _registry.getClassMetadata(type);

    final entityAnnotation = classMetadata.firstAnnotationOf<Entity>();
    if (entityAnnotation == null) {
      throw Exception('Class $type is not annotated with @Entity');
    }

    final columns = _resolveColumns(classMetadata);
    final relations = _resolveRelations(classMetadata);

    final tableName = entityAnnotation.table.isNotEmpty
        ? entityAnnotation.table
        : _namingStrategy.tableName(type.toString());

    final schema = classMetadata.typeMetadata.captureGeneric(
      <S>() => ResolvedEntitySchema<S>(
        entityType: type,
        tableName: tableName,
        columns: columns,
        relations: relations,
        classMetadata: classMetadata,
      ),
    );

    _schemaCache[type] = schema;

    return schema;
  }

  ResolvedEntitySchema? resolveByTableName(String tableName) {
    for (final schema in _schemaCache.values) {
      if (schema.tableName == tableName) {
        return schema;
      }
    }

    for (final classMetadata in _registry.allClasses) {
      final entityAnnotation = classMetadata.firstAnnotationOf<Entity>();
      if (entityAnnotation?.table == tableName) {
        return resolveByType(classMetadata.typeMetadata.type);
      }
    }

    return null;
  }

  Map<String, ColumnInfo> _resolveColumns(ClassMetadata classMetadata) {
    final columns = <String, ColumnInfo>{};

    if (!classMetadata.hasMappedGetters) {
      return columns;
    }

    for (final getter in classMetadata.getters!) {
      final columnAnnotation = getter.firstAnnotationOf<Column>();
      if (columnAnnotation == null) continue;

      final propertyName = getter.name;

      final columnName = columnAnnotation.name?.isNotEmpty == true
          ? columnAnnotation.name!
          : _namingStrategy.columnName(propertyName);

      columns[propertyName] = ColumnInfo(
        propertyName: propertyName,
        columnName: columnName,
        columnAnnotation: columnAnnotation,
      );
    }

    return columns;
  }

  Map<String, RelationInfo> _resolveRelations(ClassMetadata classMetadata) {
    final relations = <String, RelationInfo>{};

    if (!classMetadata.hasMappedGetters) {
      return relations;
    }

    for (final getter in classMetadata.getters!) {
      final relationAnnotation = getter.firstAnnotationOf<Relation>();
      if (relationAnnotation == null) continue;

      final propertyName = getter.name;
      final relationName = relationAnnotation.name ?? propertyName;
      final relatedType = _extractRelatedType(getter.typeMetadata);

      relations[propertyName] = RelationInfo(
        propertyName: propertyName,
        relationName: relationName,
        relationAnnotation: relationAnnotation,
        relatedType: relatedType,
      );
    }

    return relations;
  }

  Type _extractRelatedType(TypeMetadata typeMetadata) {
    if (typeMetadata.isType<List>() && typeMetadata.typeArguments.isNotEmpty) {
      return typeMetadata.typeArguments.first.type;
    }

    return typeMetadata.type;
  }

  void clearCache() {
    _schemaCache.clear();
  }

  List<ResolvedEntitySchema> get allSchemas => _schemaCache.values.toList();
}

abstract class NamingStrategy {
  String columnName(String propertyName);
  String tableName(String className);
}

class DefaultNamingStrategy implements NamingStrategy {
  @override
  String columnName(String propertyName) => propertyName;

  @override
  String tableName(String className) => className;
}

class UnderscoreNamingStrategy implements NamingStrategy {
  String _toUnderscore(String input) {
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char.toUpperCase() == char && i != 0) {
        buffer.write('_');
      }
      buffer.write(char.toLowerCase());
    }
    return buffer.toString();
  }

  @override
  String columnName(String propertyName) => _toUnderscore(propertyName);

  @override
  String tableName(String className) => _toUnderscore(className);
}
