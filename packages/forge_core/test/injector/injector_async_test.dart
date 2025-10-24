import 'package:forge_core/forge_core.dart';
import 'package:test/test.dart';

import 'fixtures/injector_fixtures.dart';

void main() {
  group('Container - Async Services', () {
    test('registerAsyncFactory should create new instance each time', () async {
      final builder = InjectorBuilder();
      var creationCount = 0;

      builder.registerAsyncFactory<ServiceA>(
        (c) async {
          creationCount++;
          return ServiceA();
        },
      );
      final container = await builder.build();

      final instance1 = await container.getAsync<ServiceA>();
      final instance2 = await container.getAsync<ServiceA>();

      expect(instance1, isNot(same(instance2)));
      expect(instance1.id, isNot(equals(instance2.id)));
      expect(creationCount, equals(2));
    });

    test('registerAsyncSingleton should return same instance', () async {
      final builder = InjectorBuilder();
      var creationCount = 0;

      builder.registerAsyncSingleton<ServiceA>(
        (c) async {
          creationCount++;
          return ServiceA();
        },
      );
      final container = await builder.build();

      final instance1 = await container.getAsync<ServiceA>();
      final instance2 = await container.getAsync<ServiceA>();

      expect(instance1, same(instance2));
      expect(instance1.id, equals(instance2.id));
      expect(creationCount, equals(1));
    });

    test('registerAsyncSingleton with name should work correctly', () async {
      final builder = InjectorBuilder();

      builder.registerAsyncSingleton<ServiceA>(
        (c) async => ServiceA(),
        name: 'async1',
      );
      builder.registerAsyncSingleton<ServiceA>(
        (c) async => ServiceA(),
        name: 'async2',
      );
      final container = await builder.build();

      final instance1a = await container.getAsync<ServiceA>('async1');
      final instance1b = await container.getAsync<ServiceA>('async1');
      final instance2a = await container.getAsync<ServiceA>('async2');

      expect(instance1a, same(instance1b));
      expect(instance1a, isNot(same(instance2a)));
    });

    test('get should throw for async-only service', () async {
      final builder = InjectorBuilder();

      builder.registerAsyncFactory<ServiceA>((c) async => ServiceA());
      final container = await builder.build();

      expect(
        () => container.get<ServiceA>(),
        throwsA(
          predicate(
            (e) =>
                e is StateError &&
                e.message.contains('async') &&
                e.message.contains('Use getAsync()'),
          ),
        ),
      );
    });

    test('getAsync should throw when service not registered', () async {
      final builder = InjectorBuilder();
      final container = await builder.build();

      expect(
        () async => await container.getAsync<ServiceA>(),
        throwsA(isA<ServiceNotFoundException>()),
      );
    });

    test('getAsync with name should throw when name not found', () async {
      final builder = InjectorBuilder();

      builder.registerAsyncSingleton<ServiceA>(
        (c) async => ServiceA(),
        name: 'existing',
      );

      final container = await builder.build();

      expect(
        () async => await container.getAsync<ServiceA>('missing'),
        throwsA(isA<ServiceNotFoundException>()),
      );
    });

    test('contains should return false for async service', () async {
      final builder = InjectorBuilder();

      builder.registerAsyncFactory<ServiceA>((c) async => ServiceA());
      final container = await builder.build();

      expect(container.contains<ServiceA>(), isFalse);
    });

    test('containsAsync should return true for async service', () async {
      final builder = InjectorBuilder();

      builder.registerAsyncFactory<ServiceA>((c) async => ServiceA());
      final container = await builder.build();

      expect(container.containsAsync<ServiceA>(), isTrue);
    });

    test(
      'containsAsync should return false for unregistered service',
      () async {
        final builder = InjectorBuilder();
        final container = await builder.build();

        expect(container.containsAsync<ServiceA>(), isFalse);
      },
    );

    test('containsAsync with name should work correctly', () async {
      final builder = InjectorBuilder();

      builder.registerAsyncSingleton<ServiceA>(
        (c) async => ServiceA(),
        name: 'test',
      );
      final container = await builder.build();

      expect(container.containsAsync<ServiceA>('test'), isTrue);
      expect(container.containsAsync<ServiceA>('other'), isFalse);
    });

    test('async factory can resolve sync dependencies', () async {
      final builder = InjectorBuilder();

      builder.registerSingleton<ServiceA>((c) => ServiceA());
      builder.registerAsyncFactory<ServiceB>(
        (c) async => ServiceB(c.get<ServiceA>()),
      );
      final container = await builder.build();

      final serviceB = await container.getAsync<ServiceB>();
      final serviceA = container.get<ServiceA>();

      expect(serviceB.serviceA, same(serviceA));
    });

    test('async service can have async dependencies', () async {
      final builder = InjectorBuilder();

      builder.registerAsyncSingleton<ServiceA>((c) async => ServiceA());
      builder.registerAsyncFactory<ServiceB>(
        (c) async {
          final serviceA = await c.getAsync<ServiceA>();
          return ServiceB(serviceA);
        },
      );
      final container = await builder.build();

      final serviceB = await container.getAsync<ServiceB>();
      final serviceA = await container.getAsync<ServiceA>();

      expect(serviceB.serviceA, same(serviceA));
    });

    test('onCreate callback should be called for async factory', () async {
      final builder = InjectorBuilder();
      var callbackCalled = false;
      ServiceA? callbackInstance;

      builder.registerAsyncFactory<ServiceA>(
        (c) async => ServiceA(),
        onCreate: (instance, c) async {
          callbackCalled = true;
          callbackInstance = instance;
        },
      );
      final container = await builder.build();

      final instance = await container.getAsync<ServiceA>();

      expect(callbackCalled, isTrue);
      expect(callbackInstance, same(instance));
    });

    test(
      'onCreate callback should be called once for async singleton',
      () async {
        final builder = InjectorBuilder();
        var callCount = 0;

        builder.registerAsyncSingleton<ServiceA>(
          (c) async => ServiceA(),
          onCreate: (instance, c) async => callCount++,
        );
        final container = await builder.build();

        await container.getAsync<ServiceA>();
        await container.getAsync<ServiceA>();
        await container.getAsync<ServiceA>();

        expect(callCount, equals(1));
      },
    );

    test(
      'onCreate callback should be called each time for async factory',
      () async {
        final builder = InjectorBuilder();
        var callCount = 0;

        builder.registerAsyncFactory<ServiceA>(
          (c) async => ServiceA(),
          onCreate: (instance, c) async => callCount++,
        );
        final container = await builder.build();

        await container.getAsync<ServiceA>();
        await container.getAsync<ServiceA>();
        await container.getAsync<ServiceA>();

        expect(callCount, equals(3));
      },
    );
  });

  group('Container - Eager Singletons', () {
    test('registerEagerSingleton should resolve during build', () async {
      final builder = InjectorBuilder();
      var creationCount = 0;

      builder.registerEagerSingleton<ServiceA>(
        (c) async {
          creationCount++;
          return ServiceA();
        },
      );

      expect(creationCount, equals(0));
      final container = await builder.build();

      expect(creationCount, equals(1));

      final instance = container.get<ServiceA>();
      expect(instance, isNotNull);
      expect(creationCount, equals(1));
    });

    test('eager singleton should be accessible as sync service', () async {
      final builder = InjectorBuilder();
      final expectedInstance = ServiceA();

      builder.registerEagerSingleton<ServiceA>(
        (c) async => expectedInstance,
      );

      final container = await builder.build();
      final instance = container.get<ServiceA>();

      expect(instance, same(expectedInstance));
    });

    test('multiple builds should have independent eager singletons', () async {
      final builder = InjectorBuilder();

      builder.registerEagerSingleton<ServiceA>((c) async => ServiceA());

      final container1 = await builder.build();
      final container2 = await builder.build();

      final instance1 = container1.get<ServiceA>();
      final instance2 = container2.get<ServiceA>();

      expect(instance1, isNot(same(instance2)));
    });

    test('eager singleton onCreate should be called during build', () async {
      final builder = InjectorBuilder();
      var onCreateCalled = false;

      builder.registerEagerSingleton<ServiceA>(
        (c) async => ServiceA(),
        onCreate: (instance, c) async => onCreateCalled = true,
      );

      expect(onCreateCalled, isFalse);
      await builder.build();

      expect(onCreateCalled, isTrue);
    });

    test('eager singleton with name should work correctly', () async {
      final builder = InjectorBuilder();

      builder.registerEagerSingleton<ServiceA>(
        (c) async => ServiceA(),
        name: 'eager1',
      );
      builder.registerEagerSingleton<ServiceA>(
        (c) async => ServiceA(),
        name: 'eager2',
      );

      final container = await builder.build();

      final instance1 = container.get<ServiceA>('eager1');
      final instance2 = container.get<ServiceA>('eager2');

      expect(instance1, isNot(same(instance2)));
    });

    test('eager singleton should have access to sync services', () async {
      final builder = InjectorBuilder();

      builder.registerSingleton<ServiceA>((c) => ServiceA());
      builder.registerEagerSingleton<ServiceB>(
        (c) async => ServiceB(c.get<ServiceA>()),
      );

      final container = await builder.build();

      final serviceB = container.get<ServiceB>();
      final serviceA = container.get<ServiceA>();

      expect(serviceB.serviceA, same(serviceA));
    });

    test('eager singleton can depend on other eager singletons', () async {
      final builder = InjectorBuilder();

      builder.registerEagerSingleton<ServiceA>((c) async => ServiceA());
      builder.registerEagerSingleton<ServiceB>(
        (c) async => ServiceB(c.get<ServiceA>()),
      );

      final container = await builder.build();

      final serviceB = container.get<ServiceB>();
      final serviceA = container.get<ServiceA>();

      expect(serviceB.serviceA, same(serviceA));
    });

    test(
      'eager singletons should be initialized in registration order',
      () async {
        final builder = InjectorBuilder();
        final initOrder = <String>[];

        builder.registerEagerSingleton<ServiceA>(
          (c) async {
            initOrder.add('ServiceA');
            return ServiceA();
          },
        );
        builder.registerEagerSingleton<ServiceB>(
          (c) async {
            initOrder.add('ServiceB');
            return ServiceB(c.get<ServiceA>());
          },
        );
        builder.registerEagerSingleton<ServiceC>(
          (c) async {
            initOrder.add('ServiceC');
            return ServiceC();
          },
        );

        await builder.build();

        expect(initOrder, equals(['ServiceA', 'ServiceB', 'ServiceC']));
      },
    );

    test('eager singleton should maintain singleton semantics', () async {
      final builder = InjectorBuilder();

      builder.registerEagerSingleton<ServiceC>((c) async => ServiceC());
      final container = await builder.build();

      final service1 = container.get<ServiceC>();
      service1.incrementCall();
      service1.incrementCall();

      final service2 = container.get<ServiceC>();

      expect(service2.callCount, equals(2));
      expect(service1, same(service2));
    });

    test('eager singleton should be included in all()', () async {
      final builder = InjectorBuilder();

      builder.registerEagerSingleton<ServiceA>((c) async => ServiceA());
      builder.registerInstance<ServiceA>(ServiceA(), name: 'instance');

      final container = await builder.build();
      final all = container.all<ServiceA>();

      expect(all, hasLength(2));
    });

    test(
      'eager singleton with exceptions should propagate during build',
      () async {
        final builder = InjectorBuilder();

        builder.registerEagerSingleton<ServiceA>(
          (c) async => throw Exception('Eager singleton error'),
        );

        expect(
          () => builder.build(),
          throwsA(isA<Exception>()),
        );
      },
    );

    test(
      'eager singleton onCreate exception should propagate during build',
      () async {
        final builder = InjectorBuilder();

        builder.registerEagerSingleton<ServiceA>(
          (c) async => ServiceA(),
          onCreate: (instance, c) async => throw Exception('onCreate error'),
        );

        expect(
          () async => await builder.build(),
          throwsA(isA<Exception>()),
        );
      },
    );

    test('mixed eager and lazy services should work correctly', () async {
      final builder = InjectorBuilder();
      var eagerCount = 0;
      var lazyCount = 0;

      builder.registerEagerSingleton<ServiceA>(
        (c) async {
          eagerCount++;
          return ServiceA();
        },
      );
      builder.registerSingleton<ServiceB>(
        (c) {
          lazyCount++;
          return ServiceB(c.get<ServiceA>());
        },
      );

      final container = await builder.build();

      expect(eagerCount, equals(1));
      expect(lazyCount, equals(0));

      container.get<ServiceB>();

      expect(eagerCount, equals(1));
      expect(lazyCount, equals(1));
    });
  });

  group('Container - Async Service Registration Combinations', () {
    test('sync and async services can be mixed', () async {
      final builder = InjectorBuilder();

      builder.registerSingleton<ServiceA>((c) => ServiceA());
      builder.registerAsyncSingleton<ServiceB>(
        (c) async => ServiceB(c.get<ServiceA>()),
      );

      final container = await builder.build();

      expect(container.contains<ServiceA>(), isTrue);
      expect(container.contains<ServiceB>(), isFalse);
      expect(container.containsAsync<ServiceB>(), isTrue);
    });

    test('named async services should work correctly', () async {
      final builder = InjectorBuilder();

      builder.registerAsyncSingleton<ServiceA>(
        (c) async => ServiceA(),
        name: 'primary',
      );
      builder.registerAsyncSingleton<ServiceA>(
        (c) async => ServiceA(),
        name: 'secondary',
      );

      final container = await builder.build();

      final primary = await container.getAsync<ServiceA>('primary');
      final secondary = await container.getAsync<ServiceA>('secondary');

      expect(primary, isNot(same(secondary)));
    });

    test('all should not include async services', () async {
      final builder = InjectorBuilder();

      builder.registerInstance<ServiceA>(ServiceA(), name: 'sync');
      builder.registerAsyncSingleton<ServiceA>(
        (c) async => ServiceA(),
        name: 'async',
      );

      final container = await builder.build();

      final all = container.all<ServiceA>();

      expect(all, hasLength(1));
      expect(all.first.id, isNotNull);
    });

    test('complex async dependency chains should resolve correctly', () async {
      final builder = InjectorBuilder();

      builder.registerAsyncSingleton<ServiceA>((c) async => ServiceA());
      builder.registerAsyncSingleton<ServiceB>(
        (c) async => ServiceB(await c.getAsync<ServiceA>()),
      );
      builder.registerAsyncSingleton<ServiceD>(
        (c) async => ServiceD(
          await c.getAsync<ServiceA>(),
          await c.getAsync<ServiceB>(),
        ),
      );

      final container = await builder.build();

      final serviceD = await container.getAsync<ServiceD>();
      final serviceA = await container.getAsync<ServiceA>();
      final serviceB = await container.getAsync<ServiceB>();

      expect(serviceD.serviceA, same(serviceA));
      expect(serviceD.serviceB, same(serviceB));
      expect(serviceD.serviceB.serviceA, same(serviceA));
    });

    test('async factory and eager singleton combination', () async {
      final builder = InjectorBuilder();

      builder.registerEagerSingleton<ServiceA>((c) async => ServiceA());
      builder.registerAsyncFactory<ServiceB>(
        (c) async => ServiceB(c.get<ServiceA>()),
      );

      final container = await builder.build();

      final serviceB1 = await container.getAsync<ServiceB>();
      final serviceB2 = await container.getAsync<ServiceB>();
      final serviceA = container.get<ServiceA>();

      expect(serviceB1, isNot(same(serviceB2)));
      expect(serviceB1.serviceA, same(serviceA));
      expect(serviceB2.serviceA, same(serviceA));
    });

    test('error in async service should not affect container', () async {
      final builder = InjectorBuilder();

      builder.registerAsyncFactory<ServiceA>(
        (c) async => throw Exception('Async error'),
      );

      final container = await builder.build();

      expect(
        () async => await container.getAsync<ServiceA>(),
        throwsA(isA<Exception>()),
      );
    });
  });
}
