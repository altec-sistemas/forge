import 'package:meta/meta_meta.dart';
import 'package:forge_core/forge_core.dart';

@Target({TargetKind.classType})
class Entity
    implements
        DeclarationsCapability,
        EnumCapability,
        EnumValuesCapability,
        ProxyCapability {
  final String table;

  const Entity(this.table);
}

@Target({TargetKind.getter, TargetKind.field})
class Column {
  final ColumnType type;
  final bool nullable;
  final bool autoIncrement;
  final bool primaryKey;
  final bool unique;
  final bool unsigned;
  final DateTimeRole? dateTimeRole;
  final dynamic defaultValue;
  final String? comment;
  final String? name;
  final int? length;
  final int? precision;
  final int? scale;

  const Column(
    this.type, {
    this.nullable = false,
    this.autoIncrement = false,
    this.primaryKey = false,
    this.unique = false,
    this.unsigned = false,
    this.dateTimeRole,
    this.defaultValue,
    this.comment,
    this.name,
    this.length,
    this.precision,
    this.scale,
  });

  const Column.id({this.autoIncrement = true, this.comment, this.name})
    : type = ColumnType.mediumInteger,
      nullable = false,
      primaryKey = true,
      unique = false,
      unsigned = true,
      dateTimeRole = null,
      defaultValue = null,
      length = null,
      precision = null,
      scale = null;

  const Column.varchar({
    this.length = 255,
    this.nullable = false,
    this.defaultValue,
    this.unique = false,
    this.comment,
    this.primaryKey = false,
    this.name,
  }) : type = ColumnType.varchar,
       autoIncrement = false,
       unsigned = false,
       dateTimeRole = null,
       precision = null,
       scale = null;

  const Column.integer({
    this.nullable = false,
    this.defaultValue,
    this.unique = false,
    this.comment,
    this.primaryKey = false,
    this.unsigned = false,
    this.name,
  }) : type = ColumnType.integer,
       autoIncrement = false,
       dateTimeRole = null,
       length = null,
       precision = null,
       scale = null;

  const Column.text({
    this.nullable = false,
    this.defaultValue,
    this.comment,
    this.name,
  }) : type = ColumnType.text,
       length = null,
       autoIncrement = false,
       unsigned = false,
       primaryKey = false,
       unique = false,
       dateTimeRole = null,
       precision = null,
       scale = null;

  const Column.dateTime({
    this.nullable = false,
    this.defaultValue,
    this.comment,
    this.primaryKey = false,
    this.dateTimeRole,
    this.name,
  }) : type = ColumnType.dateTime,
       length = null,
       unique = false,
       autoIncrement = false,
       unsigned = false,
       precision = null,
       scale = null;

  const Column.boolean({
    this.nullable = false,
    this.defaultValue,
    this.comment,
    this.name,
  }) : type = ColumnType.boolean,
       length = null,
       unique = false,
       autoIncrement = false,
       unsigned = false,
       primaryKey = false,
       dateTimeRole = null,
       precision = null,
       scale = null;
}

enum ColumnType {
  integer,
  mediumInteger,
  smallInteger,
  bigInteger,
  tinyInteger,
  varchar,
  text,
  longText,
  mediumText,
  char,
  boolean,
  dateTime,
  date,
  time,
  decimal,
  float,
  double,
  binary,
  json,
}

enum DateTimeRole { createdAt, updatedAt, syncAt, deletedAt }

/// Cascade options for relationships
enum CascadeOption {
  /// Automatically persists the related entity
  persist,

  /// Automatically removes the related entity
  remove,

  /// Automatically merges the related entity
  merge,

  /// Automatically detaches the related entity
  detach,

  /// Automatically refreshes the related entity
  refresh,

  /// All cascade options
  all,
}

/// Defines a relationship with another entity
@Target({TargetKind.field, TargetKind.getter})
class Relation<T> {
  /// Relationship type
  final RelationType type;

  /// Foreign key (in the child table for BelongsTo, in the related table for others)
  final String foreignKey;

  /// Local key (usually the primary key)
  final String localKey;

  /// Property name in the class (if different from the attribute)
  final String? name;

  /// Cascade options
  final List<CascadeOption> cascade;

  /// Custom query builder
  final void Function(dynamic)? queryBuilder;

  /// For conditional relationships
  final String? conditionColumn;
  final dynamic conditionValue;

  const Relation({
    required this.type,
    required this.foreignKey,
    required this.localKey,
    this.name,
    this.cascade = const [],
    this.queryBuilder,
    this.conditionColumn,
    this.conditionValue,
  });

  /// Helper for HasOne
  const Relation.hasOne({
    required this.foreignKey,
    this.localKey = 'id',
    this.name,
    this.cascade = const [],
    this.queryBuilder,
  }) : type = RelationType.hasOne,
       conditionColumn = null,
       conditionValue = null;

  /// Helper for HasMany
  const Relation.hasMany({
    required this.foreignKey,
    this.localKey = 'id',
    this.name,
    this.cascade = const [],
    this.queryBuilder,
  }) : type = RelationType.hasMany,
       conditionColumn = null,
       conditionValue = null;

  /// Helper for BelongsTo
  const Relation.belongsTo({
    required this.foreignKey,
    this.localKey = 'id',
    this.name,
    this.cascade = const [],
    this.queryBuilder,
  }) : type = RelationType.belongsTo,
       conditionColumn = null,
       conditionValue = null;

  /// Helper for conditional BelongsTo
  const Relation.conditionalBelongsTo({
    required this.foreignKey,
    this.localKey = 'id',
    required this.conditionColumn,
    required this.conditionValue,
    this.name,
    this.cascade = const [],
    this.queryBuilder,
  }) : type = RelationType.conditionalBelongsTo;

  bool get hasCascadePersist =>
      cascade.contains(CascadeOption.persist) ||
      cascade.contains(CascadeOption.all);

  bool get hasCascadeRemove =>
      cascade.contains(CascadeOption.remove) ||
      cascade.contains(CascadeOption.all);

  bool get hasCascadeMerge =>
      cascade.contains(CascadeOption.merge) ||
      cascade.contains(CascadeOption.all);

  bool get hasCascadeDetach =>
      cascade.contains(CascadeOption.detach) ||
      cascade.contains(CascadeOption.all);

  bool get hasCascadeRefresh =>
      cascade.contains(CascadeOption.refresh) ||
      cascade.contains(CascadeOption.all);
}

enum RelationType {
  hasOne,
  hasMany,
  belongsTo,
  conditionalBelongsTo,
  conditionalHasMany,
  conditionalHasOne,
}
