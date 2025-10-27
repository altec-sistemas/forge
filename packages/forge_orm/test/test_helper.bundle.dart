// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=10000
// ignore_for_file: prefer_relative_imports, depend_on_referenced_packages, camel_case_types

import 'package:forge_core/forge_core.dart';
import 'package:forge_core/metadata_compact_api.dart' as meta;

import 'package:forge_core/forge_core.dart' as prefix4;
import 'package:forge_orm/forge_orm.dart' as prefix0;
import 'test_entities.dart' as prefix3;

abstract class AbstractTestBundle implements Bundle {
  @override
  Future<void> build(InjectorBuilder builder, String env) async {}

  @override
  Future<void> buildMetadata(MetadataRegistryBuilder metaBuilder, String env) async {
    metaBuilder.registerClass<prefix3.User>(
      meta.clazz(
        meta.type<prefix3.User>(),
        const <Object>[prefix0.Entity('users'), prefix4.Mappable()],
        [meta.constructor(() => prefix3.User.new, [], 'new', const [])],
        null, // methods
        [
          meta.getter(meta.type<int>([], true), 'id', (instance) => instance.id, const <Object>[prefix0.Column.id()]),
          meta.getter(meta.type<String>([], true), 'name', (instance) => instance.name, const <Object>[prefix0.Column.varchar(length: 100)]),
          meta.getter(meta.type<String>([], true), 'email', (instance) => instance.email, const <Object>[prefix0.Column.varchar(length: 100)]),
          meta.getter(meta.type<int>([], true), 'age', (instance) => instance.age, const <Object>[prefix0.Column.integer(nullable: true)]),
          meta.getter(meta.type<DateTime>([], true), 'createdAt', (instance) => instance.createdAt, const <Object>[prefix0.Column.dateTime(dateTimeRole: prefix0.DateTimeRole.createdAt, nullable: true)]),
          meta.getter(meta.type<DateTime>([], true), 'updatedAt', (instance) => instance.updatedAt, const <Object>[prefix0.Column.dateTime(dateTimeRole: prefix0.DateTimeRole.updatedAt, nullable: true)]),
          meta.getter(meta.type<prefix3.Profile>([], true), 'profile', (instance) => instance.profile, const <Object>[
            prefix0.Relation.hasOne(foreignKey: 'userId', cascade: [prefix0.CascadeOption.persist, prefix0.CascadeOption.remove]),
          ]),
          meta.getter(meta.type<List<prefix3.Post>>([meta.type<prefix3.Post>()], true), 'posts', (instance) => instance.posts, const <Object>[
            prefix0.Relation.hasMany(foreignKey: 'userId', cascade: [prefix0.CascadeOption.persist]),
          ]),
        ],
        [
          meta.setter(meta.type<int>([], true), 'id', (instance, value) => instance.id = value, const <Object>[prefix0.Column.id()]),
          meta.setter(meta.type<String>([], true), 'name', (instance, value) => instance.name = value, const <Object>[prefix0.Column.varchar(length: 100)]),
          meta.setter(meta.type<String>([], true), 'email', (instance, value) => instance.email = value, const <Object>[prefix0.Column.varchar(length: 100)]),
          meta.setter(meta.type<int>([], true), 'age', (instance, value) => instance.age = value, const <Object>[prefix0.Column.integer(nullable: true)]),
          meta.setter(meta.type<DateTime>([], true), 'createdAt', (instance, value) => instance.createdAt = value, const <Object>[prefix0.Column.dateTime(dateTimeRole: prefix0.DateTimeRole.createdAt, nullable: true)]),
          meta.setter(meta.type<DateTime>([], true), 'updatedAt', (instance, value) => instance.updatedAt = value, const <Object>[prefix0.Column.dateTime(dateTimeRole: prefix0.DateTimeRole.updatedAt, nullable: true)]),
          meta.setter(meta.type<prefix3.Profile>([], true), 'profile', (instance, value) => instance.profile = value, const <Object>[
            prefix0.Relation.hasOne(foreignKey: 'userId', cascade: [prefix0.CascadeOption.persist, prefix0.CascadeOption.remove]),
          ]),
          meta.setter(meta.type<List<prefix3.Post>>([meta.type<prefix3.Post>()], true), 'posts', (instance, value) => instance.posts = value, const <Object>[
            prefix0.Relation.hasMany(foreignKey: 'userId', cascade: [prefix0.CascadeOption.persist]),
          ]),
        ],
        (target, handler, metadata) => _prefix3UserProxy._(target, handler, metadata),
      ),
    );

    metaBuilder.registerClass<prefix3.Profile>(
      meta.clazz(
        meta.type<prefix3.Profile>(),
        const <Object>[prefix0.Entity('profiles'), prefix4.Mappable()],
        [meta.constructor(() => prefix3.Profile.new, [], 'new', const [])],
        null, // methods
        [
          meta.getter(meta.type<int>([], true), 'id', (instance) => instance.id, const <Object>[prefix0.Column.id()]),
          meta.getter(meta.type<int>([], true), 'userId', (instance) => instance.userId, const <Object>[prefix0.Column.integer()]),
          meta.getter(meta.type<String>([], true), 'bio', (instance) => instance.bio, const <Object>[prefix0.Column.text(nullable: true)]),
          meta.getter(meta.type<String>([], true), 'website', (instance) => instance.website, const <Object>[prefix0.Column.varchar(nullable: true)]),
          meta.getter(meta.type<prefix3.User>([], true), 'user', (instance) => instance.user, const <Object>[prefix0.Relation.belongsTo(foreignKey: 'id', localKey: 'userId')]),
        ],
        [
          meta.setter(meta.type<int>([], true), 'id', (instance, value) => instance.id = value, const <Object>[prefix0.Column.id()]),
          meta.setter(meta.type<int>([], true), 'userId', (instance, value) => instance.userId = value, const <Object>[prefix0.Column.integer()]),
          meta.setter(meta.type<String>([], true), 'bio', (instance, value) => instance.bio = value, const <Object>[prefix0.Column.text(nullable: true)]),
          meta.setter(meta.type<String>([], true), 'website', (instance, value) => instance.website = value, const <Object>[prefix0.Column.varchar(nullable: true)]),
          meta.setter(meta.type<prefix3.User>([], true), 'user', (instance, value) => instance.user = value, const <Object>[prefix0.Relation.belongsTo(foreignKey: 'id', localKey: 'userId')]),
        ],
        (target, handler, metadata) => _prefix3ProfileProxy._(target, handler, metadata),
      ),
    );

    metaBuilder.registerClass<prefix3.Post>(
      meta.clazz(
        meta.type<prefix3.Post>(),
        const <Object>[prefix0.Entity('posts'), prefix4.Mappable()],
        [meta.constructor(() => prefix3.Post.new, [], 'new', const [])],
        null, // methods
        [
          meta.getter(meta.type<int>([], true), 'id', (instance) => instance.id, const <Object>[prefix0.Column.id()]),
          meta.getter(meta.type<int>([], true), 'userId', (instance) => instance.userId, const <Object>[prefix0.Column.integer()]),
          meta.getter(meta.type<String>([], true), 'title', (instance) => instance.title, const <Object>[prefix0.Column.varchar(length: 200)]),
          meta.getter(meta.type<String>([], true), 'content', (instance) => instance.content, const <Object>[prefix0.Column.text(nullable: true)]),
          meta.getter(meta.type<bool>(), 'published', (instance) => instance.published, const <Object>[prefix0.Column.boolean(defaultValue: false)]),
          meta.getter(meta.type<DateTime>([], true), 'publishedAt', (instance) => instance.publishedAt, const <Object>[prefix0.Column.dateTime(nullable: true)]),
          meta.getter(meta.type<prefix3.User>([], true), 'user', (instance) => instance.user, const <Object>[
            prefix0.Relation.belongsTo(foreignKey: 'id', localKey: 'userId', cascade: [prefix0.CascadeOption.persist]),
          ]),
          meta.getter(meta.type<List<prefix3.Comment>>([meta.type<prefix3.Comment>()], true), 'comments', (instance) => instance.comments, const <Object>[
            prefix0.Relation.hasMany(foreignKey: 'postId', cascade: [prefix0.CascadeOption.persist, prefix0.CascadeOption.remove]),
          ]),
        ],
        [
          meta.setter(meta.type<int>([], true), 'id', (instance, value) => instance.id = value, const <Object>[prefix0.Column.id()]),
          meta.setter(meta.type<int>([], true), 'userId', (instance, value) => instance.userId = value, const <Object>[prefix0.Column.integer()]),
          meta.setter(meta.type<String>([], true), 'title', (instance, value) => instance.title = value, const <Object>[prefix0.Column.varchar(length: 200)]),
          meta.setter(meta.type<String>([], true), 'content', (instance, value) => instance.content = value, const <Object>[prefix0.Column.text(nullable: true)]),
          meta.setter(meta.type<bool>(), 'published', (instance, value) => instance.published = value, const <Object>[prefix0.Column.boolean(defaultValue: false)]),
          meta.setter(meta.type<DateTime>([], true), 'publishedAt', (instance, value) => instance.publishedAt = value, const <Object>[prefix0.Column.dateTime(nullable: true)]),
          meta.setter(meta.type<prefix3.User>([], true), 'user', (instance, value) => instance.user = value, const <Object>[
            prefix0.Relation.belongsTo(foreignKey: 'id', localKey: 'userId', cascade: [prefix0.CascadeOption.persist]),
          ]),
          meta.setter(meta.type<List<prefix3.Comment>>([meta.type<prefix3.Comment>()], true), 'comments', (instance, value) => instance.comments = value, const <Object>[
            prefix0.Relation.hasMany(foreignKey: 'postId', cascade: [prefix0.CascadeOption.persist, prefix0.CascadeOption.remove]),
          ]),
        ],
        (target, handler, metadata) => _prefix3PostProxy._(target, handler, metadata),
      ),
    );

    metaBuilder.registerClass<prefix3.Comment>(
      meta.clazz(
        meta.type<prefix3.Comment>(),
        const <Object>[prefix0.Entity('comments'), prefix4.Mappable()],
        [meta.constructor(() => prefix3.Comment.new, [], 'new', const [])],
        null, // methods
        [
          meta.getter(meta.type<int>([], true), 'id', (instance) => instance.id, const <Object>[prefix0.Column.id()]),
          meta.getter(meta.type<int>([], true), 'postId', (instance) => instance.postId, const <Object>[prefix0.Column.integer()]),
          meta.getter(meta.type<String>([], true), 'authorName', (instance) => instance.authorName, const <Object>[prefix0.Column.varchar(length: 100, nullable: true)]),
          meta.getter(meta.type<String>([], true), 'content', (instance) => instance.content, const <Object>[prefix0.Column.text()]),
          meta.getter(meta.type<DateTime>([], true), 'createdAt', (instance) => instance.createdAt, const <Object>[prefix0.Column.dateTime(nullable: true)]),
          meta.getter(meta.type<prefix3.Post>([], true), 'post', (instance) => instance.post, const <Object>[prefix0.Relation.belongsTo(foreignKey: 'id', localKey: 'postId')]),
        ],
        [
          meta.setter(meta.type<int>([], true), 'id', (instance, value) => instance.id = value, const <Object>[prefix0.Column.id()]),
          meta.setter(meta.type<int>([], true), 'postId', (instance, value) => instance.postId = value, const <Object>[prefix0.Column.integer()]),
          meta.setter(meta.type<String>([], true), 'authorName', (instance, value) => instance.authorName = value, const <Object>[prefix0.Column.varchar(length: 100, nullable: true)]),
          meta.setter(meta.type<String>([], true), 'content', (instance, value) => instance.content = value, const <Object>[prefix0.Column.text()]),
          meta.setter(meta.type<DateTime>([], true), 'createdAt', (instance, value) => instance.createdAt = value, const <Object>[prefix0.Column.dateTime(nullable: true)]),
          meta.setter(meta.type<prefix3.Post>([], true), 'post', (instance, value) => instance.post = value, const <Object>[prefix0.Relation.belongsTo(foreignKey: 'id', localKey: 'postId')]),
        ],
        (target, handler, metadata) => _prefix3CommentProxy._(target, handler, metadata),
      ),
    );

    metaBuilder.registerClass<prefix3.Category>(
      meta.clazz(
        meta.type<prefix3.Category>(),
        const <Object>[prefix0.Entity('categories'), prefix4.Mappable()],
        [meta.constructor(() => prefix3.Category.new, [], 'new', const [])],
        null, // methods
        [
          meta.getter(meta.type<int>([], true), 'id', (instance) => instance.id, const <Object>[prefix0.Column.id()]),
          meta.getter(meta.type<String>([], true), 'name', (instance) => instance.name, const <Object>[prefix0.Column.varchar(length: 100)]),
          meta.getter(meta.type<String>([], true), 'description', (instance) => instance.description, const <Object>[prefix0.Column.varchar(nullable: true)]),
        ],
        [
          meta.setter(meta.type<int>([], true), 'id', (instance, value) => instance.id = value, const <Object>[prefix0.Column.id()]),
          meta.setter(meta.type<String>([], true), 'name', (instance, value) => instance.name = value, const <Object>[prefix0.Column.varchar(length: 100)]),
          meta.setter(meta.type<String>([], true), 'description', (instance, value) => instance.description = value, const <Object>[prefix0.Column.varchar(nullable: true)]),
        ],
        (target, handler, metadata) => _prefix3CategoryProxy._(target, handler, metadata),
      ),
    );

    metaBuilder.registerClass<prefix3.PostCategory>(
      meta.clazz(
        meta.type<prefix3.PostCategory>(),
        const <Object>[prefix0.Entity('post_categories'), prefix4.Mappable()],
        [meta.constructor(() => prefix3.PostCategory.new, [], 'new', const [])],
        null, // methods
        [
          meta.getter(meta.type<int>([], true), 'id', (instance) => instance.id, const <Object>[prefix0.Column.id()]),
          meta.getter(meta.type<int>([], true), 'postId', (instance) => instance.postId, const <Object>[prefix0.Column.integer()]),
          meta.getter(meta.type<int>([], true), 'categoryId', (instance) => instance.categoryId, const <Object>[prefix0.Column.integer()]),
        ],
        [
          meta.setter(meta.type<int>([], true), 'id', (instance, value) => instance.id = value, const <Object>[prefix0.Column.id()]),
          meta.setter(meta.type<int>([], true), 'postId', (instance, value) => instance.postId = value, const <Object>[prefix0.Column.integer()]),
          meta.setter(meta.type<int>([], true), 'categoryId', (instance, value) => instance.categoryId = value, const <Object>[prefix0.Column.integer()]),
        ],
        (target, handler, metadata) => _prefix3PostCategoryProxy._(target, handler, metadata),
      ),
    );
  }

  @override
  Future<void> boot(Injector i) async {}
}

class _prefix3UserProxy extends AbstractProxy implements prefix3.User {
  _prefix3UserProxy._(super.target, super.handler, super.metadata);
}

class _prefix3ProfileProxy extends AbstractProxy implements prefix3.Profile {
  _prefix3ProfileProxy._(super.target, super.handler, super.metadata);
}

class _prefix3PostProxy extends AbstractProxy implements prefix3.Post {
  _prefix3PostProxy._(super.target, super.handler, super.metadata);
}

class _prefix3CommentProxy extends AbstractProxy implements prefix3.Comment {
  _prefix3CommentProxy._(super.target, super.handler, super.metadata);
}

class _prefix3CategoryProxy extends AbstractProxy implements prefix3.Category {
  _prefix3CategoryProxy._(super.target, super.handler, super.metadata);
}

class _prefix3PostCategoryProxy extends AbstractProxy implements prefix3.PostCategory {
  _prefix3PostCategoryProxy._(super.target, super.handler, super.metadata);
}
