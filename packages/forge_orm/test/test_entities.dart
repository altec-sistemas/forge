import 'package:forge_core/forge_core.dart';
import 'package:forge_orm/forge_orm.dart';

@Entity('users')
@Mappable()
class User {
  @Column.id()
  int? id;

  @Column.varchar(length: 100)
  String? name;

  @Column.varchar(length: 100)
  String? email;

  @Column.integer(nullable: true)
  int? age;

  @Column.dateTime(dateTimeRole: DateTimeRole.createdAt, nullable: true)
  DateTime? createdAt;

  @Column.dateTime(dateTimeRole: DateTimeRole.updatedAt, nullable: true)
  DateTime? updatedAt;

  @Relation.hasOne(
    foreignKey: 'userId',
    cascade: [CascadeOption.persist, CascadeOption.remove],
  )
  Profile? profile;

  @Relation.hasMany(foreignKey: 'userId', cascade: [CascadeOption.persist])
  List<Post>? posts;
}

@Entity('profiles')
@Mappable()
class Profile {
  @Column.id()
  int? id;

  @Column.integer()
  int? userId;

  @Column.text(nullable: true)
  String? bio;

  @Column.varchar(nullable: true)
  String? website;

  @Relation.belongsTo(foreignKey: 'id', localKey: 'userId')
  User? user;
}

@Entity('posts')
@Mappable()
class Post {
  @Column.id()
  int? id;

  @Column.integer()
  int? userId;

  @Column.varchar(length: 200)
  String? title;

  @Column.text(nullable: true)
  String? content;

  @Column.boolean(defaultValue: false)
  bool published = false;

  @Column.dateTime(nullable: true)
  DateTime? publishedAt;

  @Relation.belongsTo(
    foreignKey: 'id',
    localKey: 'userId',
    cascade: [CascadeOption.persist],
  )
  User? user;

  @Relation.hasMany(
    foreignKey: 'postId',
    cascade: [CascadeOption.persist, CascadeOption.remove],
  )
  List<Comment>? comments;
}

@Entity('comments')
@Mappable()
class Comment {
  @Column.id()
  int? id;

  @Column.integer()
  int? postId;

  @Column.varchar(length: 100, nullable: true)
  String? authorName;

  @Column.text()
  String? content;

  @Column.dateTime(nullable: true)
  DateTime? createdAt;

  @Relation.belongsTo(foreignKey: 'id', localKey: 'postId')
  Post? post;
}

@Entity('categories')
@Mappable()
class Category {
  @Column.id()
  int? id;

  @Column.varchar(length: 100)
  String? name;

  @Column.varchar(nullable: true)
  String? description;
}

@Entity('post_categories')
@Mappable()
class PostCategory {
  @Column.id()
  int? id;

  @Column.integer()
  int? postId;

  @Column.integer()
  int? categoryId;
}
