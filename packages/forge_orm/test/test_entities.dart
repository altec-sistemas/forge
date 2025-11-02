import 'package:forge_core/forge_core.dart';
import 'package:forge_orm/forge_orm.dart';

@Entity('users')
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

  @OneToOne(
    mappedBy: 'user',
    cascade: {CascadeOption.persist, CascadeOption.remove},
  )
  Profile? profile;

  @OneToMany(
    mappedBy: 'user',
    cascade: {CascadeOption.persist},
  )
  List<Post>? posts;
}

@Entity('profiles')
class Profile {
  @Column.id()
  int? id;

  @Column.integer()
  int? userId;

  @Column.text(nullable: true)
  String? bio;

  @Column.varchar(nullable: true)
  String? website;

  @OneToOne(inversedBy: 'profile')
  @JoinColumn(name: 'userId', referencedColumnName: 'id')
  User? user;
}

@Entity('posts')
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

  @ManyToOne(inversedBy: 'posts', cascade: {CascadeOption.persist})
  @JoinColumn(name: 'userId', referencedColumnName: 'id')
  User? user;

  @OneToMany(
    mappedBy: 'post',
    cascade: {CascadeOption.persist, CascadeOption.remove},
  )
  List<Comment>? comments;
}

@Entity('comments')
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

  @ManyToOne(inversedBy: 'comments')
  @JoinColumn(name: 'postId', referencedColumnName: 'id')
  Post? post;
}

@Entity('categories')
class Category {
  @Column.id()
  int? id;

  @Column.varchar(length: 100)
  String? name;

  @Column.varchar(nullable: true)
  String? description;
}

@Entity('post_categories')
class PostCategory {
  @Column.id()
  int? id;

  @Column.integer()
  int? postId;

  @Column.integer()
  int? categoryId;
}
