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

  const Column.char({
    this.length = 1,
    this.nullable = false,
    this.defaultValue,
    this.unique = false,
    this.comment,
    this.primaryKey = false,
    this.name,
  }) : type = ColumnType.char,
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

  const Column.longText({
    this.nullable = false,
    this.defaultValue,
    this.comment,
    this.name,
  }) : type = ColumnType.longText,
       length = null,
       autoIncrement = false,
       unsigned = false,
       primaryKey = false,
       unique = false,
       dateTimeRole = null,
       precision = null,
       scale = null;

  const Column.mediumText({
    this.nullable = false,
    this.defaultValue,
    this.comment,
    this.name,
  }) : type = ColumnType.mediumText,
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

  const Column.decimal({
    this.precision = 10,
    this.scale = 2,
    this.nullable = false,
    this.defaultValue,
    this.comment,
    this.name,
  }) : type = ColumnType.decimal,
       length = null,
       unique = false,
       autoIncrement = false,
       unsigned = false,
       primaryKey = false,
       dateTimeRole = null;

  const Column.smallInteger({
    this.nullable = false,
    this.defaultValue,
    this.unique = false,
    this.comment,
    this.primaryKey = false,
    this.unsigned = false,
    this.name,
  }) : type = ColumnType.smallInteger,
       autoIncrement = false,
       dateTimeRole = null,
       length = null,
       precision = null,
       scale = null;

  const Column.mediumInteger({
    this.nullable = false,
    this.defaultValue,
    this.unique = false,
    this.comment,
    this.primaryKey = false,
    this.unsigned = false,
    this.name,
  }) : type = ColumnType.mediumInteger,
       autoIncrement = false,
       dateTimeRole = null,
       length = null,
       precision = null,
       scale = null;

  const Column.bigInteger({
    this.nullable = false,
    this.defaultValue,
    this.unique = false,
    this.comment,
    this.primaryKey = false,
    this.unsigned = false,
    this.name,
  }) : type = ColumnType.bigInteger,
       autoIncrement = false,
       dateTimeRole = null,
       length = null,
       precision = null,
       scale = null;

  const Column.tinyInteger({
    this.nullable = false,
    this.defaultValue,
    this.unique = false,
    this.comment,
    this.primaryKey = false,
    this.unsigned = false,
    this.name,
  }) : type = ColumnType.tinyInteger,
       autoIncrement = false,
       dateTimeRole = null,
       length = null,
       precision = null,
       scale = null;

  const Column.date({
    this.nullable = false,
    this.defaultValue,
    this.comment,
    this.name,
  }) : type = ColumnType.date,
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
}

/// Defines the join column for a relationship (similar to Doctrine's @JoinColumn)
///
/// This annotation is used on the OWNING side of a relationship to specify:
/// - Which column in THIS table contains the foreign key
/// - Which column in the RELATED table is being referenced (usually 'id')
@Target({TargetKind.field, TargetKind.getter})
class JoinColumn {
  /// The name of the foreign key column in THIS entity's table
  /// Example: 'user_id', 'category_id', 'parent_id'
  final String name;

  /// The name of the column in the RELATED entity's table that is referenced
  /// Usually 'id' (the primary key of the related table)
  final String referencedColumnName;

  /// Whether the column can be null
  final bool nullable;

  /// Whether the column should have a unique constraint
  final bool unique;

  /// Action to perform on delete (e.g., 'CASCADE', 'SET NULL', 'RESTRICT')
  final String? onDelete;

  /// Action to perform on update (e.g., 'CASCADE', 'SET NULL', 'RESTRICT')
  final String? onUpdate;

  const JoinColumn({
    required this.name,
    this.referencedColumnName = 'id',
    this.nullable = true,
    this.unique = false,
    this.onDelete,
    this.onUpdate,
  });
}

/// Base class for relationship annotations
abstract class Relation<T> {
  /// Property name in the class (if different from the attribute)
  final String? name;

  /// Cascade options
  final Set<CascadeOption> cascade;

  /// The target entity type (optional, can be inferred)
  final Type? targetEntity;

  /// Custom query builder
  final void Function(dynamic)? queryBuilder;

  /// For conditional relationships
  final String? conditionColumn;
  final dynamic conditionValue;

  const Relation({
    this.name,
    this.cascade = const {},
    this.targetEntity,
    this.queryBuilder,
    this.conditionColumn,
    this.conditionValue,
  });

  bool get hasCascadePersist => cascade.contains(CascadeOption.persist);
  bool get hasCascadeRemove => cascade.contains(CascadeOption.remove);
}

/// Many-to-One relationship (owning side - has foreign key)
///
/// Use when THIS entity has a foreign key column pointing to another entity.
/// Multiple entities of this type can point to the same related entity.
/// Must be used with @JoinColumn to specify the foreign key details.
///
/// Example:
/// ```dart
/// @Entity('posts')
/// class Post {
///   @ManyToOne(inversedBy: 'posts')
///   @JoinColumn(name: 'user_id', referencedColumnName: 'id')
///   User? user;
/// }
/// ```
@Target({TargetKind.field, TargetKind.getter})
class ManyToOne<T> extends Relation<T> {
  /// Property name on the inverse side (in the related entity)
  /// Points to the OneToMany property in the related entity
  final String? inversedBy;

  const ManyToOne({
    this.inversedBy,
    super.name,
    super.cascade,
    super.targetEntity,
    super.queryBuilder,
    super.conditionColumn,
    super.conditionValue,
  });
}

/// One-to-Many relationship (inverse side - doesn't have foreign key)
///
/// Use when you want to access a collection of related entities that point to this one.
/// The related entities have the foreign key (ManyToOne side).
///
/// Example:
/// ```dart
/// @Entity('users')
/// class User {
///   @OneToMany(mappedBy: 'user')
///   List<Post>? posts;
/// }
/// ```
@Target({TargetKind.field, TargetKind.getter})
class OneToMany<T> extends Relation<T> {
  /// Property name on the owning side (in the related entity)
  /// Points to the ManyToOne property that holds the foreign key
  final String mappedBy;

  const OneToMany({
    required this.mappedBy,
    super.name,
    super.cascade,
    super.targetEntity,
    super.queryBuilder,
    super.conditionColumn,
    super.conditionValue,
  });
}

/// One-to-One relationship (owning side - has foreign key)
///
/// Use when THIS entity has a foreign key column pointing to another entity.
/// Must be used with @JoinColumn to specify the foreign key details.
///
/// Example:
/// ```dart
/// @Entity('profiles')
/// class Profile {
///   @OneToOne(inversedBy: 'profile')
///   @JoinColumn(name: 'user_id', referencedColumnName: 'id')
///   User? user;
/// }
/// ```
@Target({TargetKind.field, TargetKind.getter})
class OneToOne<T> extends Relation<T> {
  /// Property name on the inverse side (in the related entity)
  final String? inversedBy;

  /// Property name on the owning side (in the related entity)
  final String? mappedBy;

  const OneToOne({
    this.inversedBy,
    this.mappedBy,
    super.name,
    super.cascade,
    super.targetEntity,
    super.queryBuilder,
    super.conditionColumn,
    super.conditionValue,
  });
}
