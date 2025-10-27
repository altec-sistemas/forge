import 'package:test/test.dart';
import 'package:forge_orm/forge_orm.dart';
import 'test_helper.dart';
import 'test_entities.dart';

void main() {
  late TestHelper helper;

  setUp(() async {
    helper = TestHelper();
    await helper.setup();
    await _seedData(helper);
  });

  tearDown(() async {
    await helper.teardown();
  });

  group('QueryBuilder Tests', () {
    group('Basic Queries', () {
      test('should select all records', () async {
        final qb = helper.orm.createQueryBuilder().from('users');
        final results = await qb.get();

        expect(results.length, greaterThan(0));
      });

      test('should select specific columns', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .select(['name', 'email'])
            .from('users');

        final results = await qb.get();

        expect(results.first.containsKey('name'), true);
        expect(results.first.containsKey('email'), true);
      });

      test('should use distinct', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .select(['age'])
            .from('users')
            .distinct();

        final results = await qb.get();

        expect(
          results.length,
          lessThanOrEqualTo(await helper.countRecords('users')),
        );
      });
    });

    group('Where Clauses', () {
      test('should filter with where equals', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .from('users')
            .where('name', isEqualTo: 'Alice');

        final results = await qb.get();

        expect(results.length, 1);
        expect(results.first['name'], 'Alice');
      });

      test('should filter with where greater than', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .from('users')
            .where('age', isGreaterThan: 25);

        final results = await qb.get();

        expect(results.isNotEmpty, true);
        expect(results.every((r) => (r['age'] as int) > 25), true);
      });

      test('should filter with where less than or equal', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .from('users')
            .where('age', isLessThanOrEqual: 30);

        final results = await qb.get();

        expect(results.every((r) => (r['age'] as int) <= 30), true);
      });

      test('should filter with LIKE (contains)', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .from('users')
            .where('email', contains: 'example');

        final results = await qb.get();

        expect(results.isNotEmpty, true);
        expect(
          results.every((r) => (r['email'] as String).contains('example')),
          true,
        );
      });

      test('should filter with LIKE (startsWith)', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .from('users')
            .where('name', startsWith: 'A');

        final results = await qb.get();

        expect(results.isNotEmpty, true);
        expect(
          results.every((r) => (r['name'] as String).startsWith('A')),
          true,
        );
      });

      test('should filter with LIKE (endsWith)', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .from('users')
            .where('email', endsWith: '.com');

        final results = await qb.get();

        expect(
          results.every((r) => (r['email'] as String).endsWith('.com')),
          true,
        );
      });

      test('should chain multiple where clauses', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .from('users')
            .where('age', isGreaterThan: 20)
            .where('age', isLessThan: 35);

        final results = await qb.get();

        expect(
          results.every((r) {
            final age = r['age'] as int;
            return age > 20 && age < 35;
          }),
          true,
        );
      });

      test('should use OR where', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .from('users')
            .where('name', isEqualTo: 'Alice')
            .orWhere('name', isEqualTo: 'Bob');

        final results = await qb.get();

        expect(results.length, 2);
        expect(results.any((r) => r['name'] == 'Alice'), true);
        expect(results.any((r) => r['name'] == 'Bob'), true);
      });
    });

    group('Where IN Clauses', () {
      test('should filter with whereIn', () async {
        final qb = helper.orm.createQueryBuilder().from('users').whereIn(
          'name',
          ['Alice', 'Bob', 'Charlie'],
        );

        final results = await qb.get();

        expect(results.length, 3);
        expect(
          results.every((r) => ['Alice', 'Bob', 'Charlie'].contains(r['name'])),
          true,
        );
      });

      test('should filter with whereNotIn', () async {
        final qb = helper.orm.createQueryBuilder().from('users').whereNotIn(
          'name',
          ['Alice'],
        );

        final results = await qb.get();

        expect(results.every((r) => r['name'] != 'Alice'), true);
      });

      test('should handle empty list in whereIn', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .from('users')
            .whereIn('name', []);

        final results = await qb.get();

        expect(results.length, 0);
      });
    });

    group('NULL Checks', () {
      test('should filter with whereNull', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .from('users')
            .whereNull('age');

        final results = await qb.get();

        expect(results.every((r) => r['age'] == null), true);
      });

      test('should filter with whereNotNull', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .from('users')
            .whereNotNull('age');

        final results = await qb.get();

        expect(results.every((r) => r['age'] != null), true);
      });
    });

    group('Between Clauses', () {
      test('should filter with whereBetween', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .from('users')
            .whereBetween('age', 25, 35);

        final results = await qb.get();

        expect(
          results.every((r) {
            final age = r['age'] as int;
            return age >= 25 && age <= 35;
          }),
          true,
        );
      });

      test('should filter with whereNotBetween', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .from('users')
            .whereNotBetween('age', 25, 30);

        final results = await qb.get();

        expect(
          results.every((r) {
            final age = r['age'] as int;
            return age < 25 || age > 30;
          }),
          true,
        );
      });
    });

    group('Raw Queries', () {
      test('should execute whereRaw', () async {
        final qb = helper.orm.createQueryBuilder().from('users').whereRaw(
          'age > ?',
          [25],
        );

        final results = await qb.get();

        expect(results.every((r) => (r['age'] as int) > 25), true);
      });

      test('should use raw expressions in select', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .select([raw('COUNT(*) as total')])
            .from('users');

        final results = await qb.get();

        expect(results.first['total'], greaterThan(0));
      });
    });

    group('Ordering', () {
      test('should order by ascending', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .from('users')
            .whereNotNull('age')
            .orderBy('age', 'ASC');

        final results = await qb.get();

        expect(results.length, greaterThan(1));

        for (int i = 0; i < results.length - 1; i++) {
          final current = results[i]['age'] as int;
          final next = results[i + 1]['age'] as int;
          expect(current <= next, true);
        }
      });

      test('should order by descending', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .from('users')
            .whereNotNull('age')
            .orderByDesc('age');

        final results = await qb.get();

        for (int i = 0; i < results.length - 1; i++) {
          final current = results[i]['age'] as int;
          final next = results[i + 1]['age'] as int;
          expect(current >= next, true);
        }
      });

      test('should order by multiple columns', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .from('users')
            .orderBy('age', 'ASC')
            .orderBy('name', 'ASC');

        final results = await qb.get();

        expect(results.isNotEmpty, true);
      });
    });

    group('Limit and Offset', () {
      test('should limit results', () async {
        final qb = helper.orm.createQueryBuilder().from('users').limit(2);

        final results = await qb.get();

        expect(results.length, lessThanOrEqualTo(2));
      });

      test('should use offset', () async {
        final allQb = helper.orm
            .createQueryBuilder()
            .from('users')
            .orderBy('id', 'ASC');

        final all = await allQb.get();

        final offsetQb = helper.orm
            .createQueryBuilder()
            .from('users')
            .orderBy('id', 'ASC')
            .limit(1)
            .offset(2);

        final offset = await offsetQb.get();

        expect(offset.first['id'], all[2]['id']);
      });

      test('should use take (alias for limit)', () async {
        final qb = helper.orm.createQueryBuilder().from('users').take(3);

        final results = await qb.get();

        expect(results.length, lessThanOrEqualTo(3));
      });

      test('should use skip (alias for offset)', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .from('users')
            .orderBy('id', 'ASC')
            .skip(1)
            .take(2);

        final results = await qb.get();

        expect(results.length, lessThanOrEqualTo(2));
      });
    });

    group('Joins', () {
      test('should perform inner join', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .select(['users.name', 'posts.title'])
            .from('users')
            .join('posts', 'users.id', '=', 'posts.user_id');

        final results = await qb.get();

        expect(results.isNotEmpty, true);
        expect(results.first.containsKey('name'), true);
        expect(results.first.containsKey('title'), true);
      });

      test('should perform left join', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .select(['users.name', 'profiles.bio'])
            .from('users')
            .leftJoin('profiles', 'users.id', '=', 'profiles.user_id');

        final results = await qb.get();

        expect(
          results.length,
          greaterThanOrEqualTo(await helper.countRecords('users')),
        );
      });

      test('should use table aliases in joins', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .select(['u.name', 'p.title'])
            .from('users', 'u')
            .join('posts', 'u.id', '=', 'posts.user_id', 'p');

        final results = await qb.get();

        expect(results.isNotEmpty, true);
      });
    });

    group('Group By', () {
      test('should group by column', () async {
        final qb = helper.orm
            .createQueryBuilder()
            .select([raw('age'), raw('COUNT(*) as count')])
            .from('users')
            .groupBy(['age']);

        final results = await qb.get();

        expect(results.isNotEmpty, true);
      });
    });

    group('Insert, Update, Delete', () {
      test('should insert via query builder', () async {
        final qb = helper.orm.createQueryBuilder().from('categories');
        final id = await qb.insert({
          'name': 'Technology',
          'description': 'Tech articles',
        });

        expect(id, isNotNull);
        expect(id! > 0, true);
      });

      test('should update via query builder', () async {
        final insertQb = helper.orm.createQueryBuilder().from('categories');
        final id = await insertQb.insert({'name': 'Old Name'});

        final updateQb = helper.orm
            .createQueryBuilder()
            .from('categories')
            .where('id', isEqualTo: id);

        final affected = await updateQb.update({'name': 'New Name'});

        expect(affected, 1);

        final result = await helper.executeRaw(
          'SELECT name FROM categories WHERE id = ?',
          [id],
        );

        expect(result.rows.first['name'], 'New Name');
      });

      test('should delete via query builder', () async {
        final insertQb = helper.orm.createQueryBuilder().from('categories');
        final id = await insertQb.insert({'name': 'Delete Me'});

        final deleteQb = helper.orm
            .createQueryBuilder()
            .from('categories')
            .where('id', isEqualTo: id);

        final affected = await deleteQb.delete();

        expect(affected, 1);
        expect(await helper.recordExists('categories', 'id', id), false);
      });
    });
  });
}

Future<void> _seedData(TestHelper helper) async {
  final users = [
    User()
      ..name = 'Alice'
      ..email = 'alice@example.com'
      ..age = 25,
    User()
      ..name = 'Bob'
      ..email = 'bob@example.com'
      ..age = 30,
    User()
      ..name = 'Charlie'
      ..email = 'charlie@example.com'
      ..age = 35,
    User()
      ..name = 'David'
      ..email = 'david@example.com'
      ..age = 28,
    User()
      ..name = 'NoAge'
      ..email = 'noage@example.com'
      ..age = null,
  ];

  for (final user in users) {
    helper.orm.entityManager.persist(user);
  }
  await helper.orm.entityManager.flush();

  final post1 = Post()
    ..userId = 1
    ..title = 'Post 1'
    ..content = 'Content 1';
  final post2 = Post()
    ..userId = 1
    ..title = 'Post 2'
    ..content = 'Content 2';
  final post3 = Post()
    ..userId = 2
    ..title = 'Post 3'
    ..content = 'Content 3';

  helper.orm.entityManager.persist(post1);
  helper.orm.entityManager.persist(post2);
  helper.orm.entityManager.persist(post3);
  await helper.orm.entityManager.flush();
}
