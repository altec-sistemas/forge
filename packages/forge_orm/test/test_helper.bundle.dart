// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=10000
// ignore_for_file: prefer_relative_imports, depend_on_referenced_packages, camel_case_types

import 'package:forge_core/forge_core.dart';
import 'package:forge_core/metadata_compact_api.dart' as meta;

import 'package:forge_orm/forge_orm.dart' as prefix0;
import 'test_entities.dart' as prefix6;

abstract class AbstractTestBundle implements Bundle {
  @override
  Future<void> build(InjectorBuilder builder, String env) async {}

  @override
  Future<void> buildMetadata(MetadataRegistryBuilder metaBuilder, String env) async {
    metaBuilder.registerClass<prefix6.User>(
      meta.clazz(
        meta.type<prefix6.User>(),
        const <Object>[prefix0.Entity('users')],
        [meta.constructor(() => prefix6.User.new, [], 'new', const [])],
        null, // methods
        [
          meta.getter(meta.type<int>([], true), 'id', (instance) => instance.id, const <Object>[prefix0.Column.id()]),
          meta.getter(meta.type<String>([], true), 'name', (instance) => instance.name, const <Object>[prefix0.Column.varchar(length: 100)]),
          meta.getter(meta.type<String>([], true), 'email', (instance) => instance.email, const <Object>[prefix0.Column.varchar(length: 100)]),
          meta.getter(meta.type<int>([], true), 'age', (instance) => instance.age, const <Object>[prefix0.Column.integer(nullable: true)]),
          meta.getter(meta.type<DateTime>([], true), 'createdAt', (instance) => instance.createdAt, const <Object>[prefix0.Column.dateTime(dateTimeRole: prefix0.DateTimeRole.createdAt, nullable: true)]),
          meta.getter(meta.type<DateTime>([], true), 'updatedAt', (instance) => instance.updatedAt, const <Object>[prefix0.Column.dateTime(dateTimeRole: prefix0.DateTimeRole.updatedAt, nullable: true)]),
          meta.getter(meta.type<prefix6.Profile>([], true), 'profile', (instance) => instance.profile, const <Object>[
            prefix0.OneToOne(mappedBy: 'user', cascade: {prefix0.CascadeOption.persist, prefix0.CascadeOption.remove}),
          ]),
          meta.getter(meta.type<List<prefix6.Post>>([meta.type<prefix6.Post>()], true), 'posts', (instance) => instance.posts, const <Object>[
            prefix0.OneToMany(mappedBy: 'user', cascade: {prefix0.CascadeOption.persist}),
          ]),
        ],
        [
          meta.setter(meta.type<int>([], true), 'id', (instance, value) => instance.id = value, const <Object>[prefix0.Column.id()]),
          meta.setter(meta.type<String>([], true), 'name', (instance, value) => instance.name = value, const <Object>[prefix0.Column.varchar(length: 100)]),
          meta.setter(meta.type<String>([], true), 'email', (instance, value) => instance.email = value, const <Object>[prefix0.Column.varchar(length: 100)]),
          meta.setter(meta.type<int>([], true), 'age', (instance, value) => instance.age = value, const <Object>[prefix0.Column.integer(nullable: true)]),
          meta.setter(meta.type<DateTime>([], true), 'createdAt', (instance, value) => instance.createdAt = value, const <Object>[prefix0.Column.dateTime(dateTimeRole: prefix0.DateTimeRole.createdAt, nullable: true)]),
          meta.setter(meta.type<DateTime>([], true), 'updatedAt', (instance, value) => instance.updatedAt = value, const <Object>[prefix0.Column.dateTime(dateTimeRole: prefix0.DateTimeRole.updatedAt, nullable: true)]),
          meta.setter(meta.type<prefix6.Profile>([], true), 'profile', (instance, value) => instance.profile = value, const <Object>[
            prefix0.OneToOne(mappedBy: 'user', cascade: {prefix0.CascadeOption.persist, prefix0.CascadeOption.remove}),
          ]),
          meta.setter(meta.type<List<prefix6.Post>>([meta.type<prefix6.Post>()], true), 'posts', (instance, value) => instance.posts = value, const <Object>[
            prefix0.OneToMany(mappedBy: 'user', cascade: {prefix0.CascadeOption.persist}),
          ]),
        ],
        (target, handler, metadata) => _prefix6UserProxy._(target, handler, metadata),
      ),
    );

    metaBuilder.registerClass<prefix6.Profile>(
      meta.clazz(
        meta.type<prefix6.Profile>(),
        const <Object>[prefix0.Entity('profiles')],
        [meta.constructor(() => prefix6.Profile.new, [], 'new', const [])],
        null, // methods
        [
          meta.getter(meta.type<int>([], true), 'id', (instance) => instance.id, const <Object>[prefix0.Column.id()]),
          meta.getter(meta.type<int>([], true), 'userId', (instance) => instance.userId, const <Object>[prefix0.Column.integer()]),
          meta.getter(meta.type<String>([], true), 'bio', (instance) => instance.bio, const <Object>[prefix0.Column.text(nullable: true)]),
          meta.getter(meta.type<String>([], true), 'website', (instance) => instance.website, const <Object>[prefix0.Column.varchar(nullable: true)]),
          meta.getter(meta.type<prefix6.User>([], true), 'user', (instance) => instance.user, const <Object>[prefix0.OneToOne(inversedBy: 'profile'), prefix0.JoinColumn(name: 'userId', referencedColumnName: 'id')]),
        ],
        [
          meta.setter(meta.type<int>([], true), 'id', (instance, value) => instance.id = value, const <Object>[prefix0.Column.id()]),
          meta.setter(meta.type<int>([], true), 'userId', (instance, value) => instance.userId = value, const <Object>[prefix0.Column.integer()]),
          meta.setter(meta.type<String>([], true), 'bio', (instance, value) => instance.bio = value, const <Object>[prefix0.Column.text(nullable: true)]),
          meta.setter(meta.type<String>([], true), 'website', (instance, value) => instance.website = value, const <Object>[prefix0.Column.varchar(nullable: true)]),
          meta.setter(meta.type<prefix6.User>([], true), 'user', (instance, value) => instance.user = value, const <Object>[prefix0.OneToOne(inversedBy: 'profile'), prefix0.JoinColumn(name: 'userId', referencedColumnName: 'id')]),
        ],
        (target, handler, metadata) => _prefix6ProfileProxy._(target, handler, metadata),
      ),
    );

    metaBuilder.registerClass<prefix6.Post>(
      meta.clazz(
        meta.type<prefix6.Post>(),
        const <Object>[prefix0.Entity('posts')],
        [meta.constructor(() => prefix6.Post.new, [], 'new', const [])],
        null, // methods
        [
          meta.getter(meta.type<int>([], true), 'id', (instance) => instance.id, const <Object>[prefix0.Column.id()]),
          meta.getter(meta.type<int>([], true), 'userId', (instance) => instance.userId, const <Object>[prefix0.Column.integer()]),
          meta.getter(meta.type<String>([], true), 'title', (instance) => instance.title, const <Object>[prefix0.Column.varchar(length: 200)]),
          meta.getter(meta.type<String>([], true), 'content', (instance) => instance.content, const <Object>[prefix0.Column.text(nullable: true)]),
          meta.getter(meta.type<bool>(), 'published', (instance) => instance.published, const <Object>[prefix0.Column.boolean(defaultValue: false)]),
          meta.getter(meta.type<DateTime>([], true), 'publishedAt', (instance) => instance.publishedAt, const <Object>[prefix0.Column.dateTime(nullable: true)]),
          meta.getter(meta.type<prefix6.User>([], true), 'user', (instance) => instance.user, const <Object>[
            prefix0.ManyToOne(inversedBy: 'posts', cascade: {prefix0.CascadeOption.persist}),
            prefix0.JoinColumn(name: 'userId', referencedColumnName: 'id'),
          ]),
          meta.getter(meta.type<List<prefix6.Comment>>([meta.type<prefix6.Comment>()], true), 'comments', (instance) => instance.comments, const <Object>[
            prefix0.OneToMany(mappedBy: 'post', cascade: {prefix0.CascadeOption.persist, prefix0.CascadeOption.remove}),
          ]),
        ],
        [
          meta.setter(meta.type<int>([], true), 'id', (instance, value) => instance.id = value, const <Object>[prefix0.Column.id()]),
          meta.setter(meta.type<int>([], true), 'userId', (instance, value) => instance.userId = value, const <Object>[prefix0.Column.integer()]),
          meta.setter(meta.type<String>([], true), 'title', (instance, value) => instance.title = value, const <Object>[prefix0.Column.varchar(length: 200)]),
          meta.setter(meta.type<String>([], true), 'content', (instance, value) => instance.content = value, const <Object>[prefix0.Column.text(nullable: true)]),
          meta.setter(meta.type<bool>(), 'published', (instance, value) => instance.published = value, const <Object>[prefix0.Column.boolean(defaultValue: false)]),
          meta.setter(meta.type<DateTime>([], true), 'publishedAt', (instance, value) => instance.publishedAt = value, const <Object>[prefix0.Column.dateTime(nullable: true)]),
          meta.setter(meta.type<prefix6.User>([], true), 'user', (instance, value) => instance.user = value, const <Object>[
            prefix0.ManyToOne(inversedBy: 'posts', cascade: {prefix0.CascadeOption.persist}),
            prefix0.JoinColumn(name: 'userId', referencedColumnName: 'id'),
          ]),
          meta.setter(meta.type<List<prefix6.Comment>>([meta.type<prefix6.Comment>()], true), 'comments', (instance, value) => instance.comments = value, const <Object>[
            prefix0.OneToMany(mappedBy: 'post', cascade: {prefix0.CascadeOption.persist, prefix0.CascadeOption.remove}),
          ]),
        ],
        (target, handler, metadata) => _prefix6PostProxy._(target, handler, metadata),
      ),
    );

    metaBuilder.registerClass<prefix6.Comment>(
      meta.clazz(
        meta.type<prefix6.Comment>(),
        const <Object>[prefix0.Entity('comments')],
        [meta.constructor(() => prefix6.Comment.new, [], 'new', const [])],
        null, // methods
        [
          meta.getter(meta.type<int>([], true), 'id', (instance) => instance.id, const <Object>[prefix0.Column.id()]),
          meta.getter(meta.type<int>([], true), 'postId', (instance) => instance.postId, const <Object>[prefix0.Column.integer()]),
          meta.getter(meta.type<String>([], true), 'authorName', (instance) => instance.authorName, const <Object>[prefix0.Column.varchar(length: 100, nullable: true)]),
          meta.getter(meta.type<String>([], true), 'content', (instance) => instance.content, const <Object>[prefix0.Column.text()]),
          meta.getter(meta.type<DateTime>([], true), 'createdAt', (instance) => instance.createdAt, const <Object>[prefix0.Column.dateTime(nullable: true)]),
          meta.getter(meta.type<prefix6.Post>([], true), 'post', (instance) => instance.post, const <Object>[prefix0.ManyToOne(inversedBy: 'comments'), prefix0.JoinColumn(name: 'postId', referencedColumnName: 'id')]),
        ],
        [
          meta.setter(meta.type<int>([], true), 'id', (instance, value) => instance.id = value, const <Object>[prefix0.Column.id()]),
          meta.setter(meta.type<int>([], true), 'postId', (instance, value) => instance.postId = value, const <Object>[prefix0.Column.integer()]),
          meta.setter(meta.type<String>([], true), 'authorName', (instance, value) => instance.authorName = value, const <Object>[prefix0.Column.varchar(length: 100, nullable: true)]),
          meta.setter(meta.type<String>([], true), 'content', (instance, value) => instance.content = value, const <Object>[prefix0.Column.text()]),
          meta.setter(meta.type<DateTime>([], true), 'createdAt', (instance, value) => instance.createdAt = value, const <Object>[prefix0.Column.dateTime(nullable: true)]),
          meta.setter(meta.type<prefix6.Post>([], true), 'post', (instance, value) => instance.post = value, const <Object>[prefix0.ManyToOne(inversedBy: 'comments'), prefix0.JoinColumn(name: 'postId', referencedColumnName: 'id')]),
        ],
        (target, handler, metadata) => _prefix6CommentProxy._(target, handler, metadata),
      ),
    );

    metaBuilder.registerClass<prefix6.Category>(
      meta.clazz(
        meta.type<prefix6.Category>(),
        const <Object>[prefix0.Entity('categories')],
        [meta.constructor(() => prefix6.Category.new, [], 'new', const [])],
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
        (target, handler, metadata) => _prefix6CategoryProxy._(target, handler, metadata),
      ),
    );

    metaBuilder.registerClass<prefix6.PostCategory>(
      meta.clazz(
        meta.type<prefix6.PostCategory>(),
        const <Object>[prefix0.Entity('post_categories')],
        [meta.constructor(() => prefix6.PostCategory.new, [], 'new', const [])],
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
        (target, handler, metadata) => _prefix6PostCategoryProxy._(target, handler, metadata),
      ),
    );
  }

  @override
  Future<void> boot(Injector i) async {}
}

class _prefix6UserProxy extends AbstractProxy implements prefix6.User {
  _prefix6UserProxy._(super.target, super.handler, super.metadata);
}

class _prefix6ProfileProxy extends AbstractProxy implements prefix6.Profile {
  _prefix6ProfileProxy._(super.target, super.handler, super.metadata);
}

class _prefix6PostProxy extends AbstractProxy implements prefix6.Post {
  _prefix6PostProxy._(super.target, super.handler, super.metadata);
}

class _prefix6CommentProxy extends AbstractProxy implements prefix6.Comment {
  _prefix6CommentProxy._(super.target, super.handler, super.metadata);
}

class _prefix6CategoryProxy extends AbstractProxy implements prefix6.Category {
  _prefix6CategoryProxy._(super.target, super.handler, super.metadata);
}

class _prefix6PostCategoryProxy extends AbstractProxy implements prefix6.PostCategory {
  _prefix6PostCategoryProxy._(super.target, super.handler, super.metadata);
}
