import 'package:forge_core/forge_core.dart';
import 'package:test/test.dart';

import 'fixtures/injector_fixtures.dart';

void main() async {
  group('ContainerBuilder - Registration', () {
    test('registerInstance should store and retrieve instance', () async {
      final builder = InjectorBuilder();
      final instance = ServiceA();

      builder.registerInstance<ServiceA>(instance);
      final container = await builder.build();

      expect(container.get<ServiceA>(), same(instance));
    });

    test('registerInstance with name should work correctly', () async {
      final builder = InjectorBuilder();
      final instance1 = ServiceA();
      final instance2 = ServiceA();

      builder.registerInstance<ServiceA>(instance1, name: 'first');
      builder.registerInstance<ServiceA>(instance2, name: 'second');
      final container = await builder.build();

      expect(container.get<ServiceA>('first'), same(instance1));
      expect(container.get<ServiceA>('second'), same(instance2));
      expect(container.get<ServiceA>('first'), isNot(same(instance2)));
    });

    test('registerFactory should create new instance each time', () async {
      final builder = InjectorBuilder();

      builder.registerFactory<ServiceA>((c) => ServiceA());

      final container = await builder.build();

      final instance1 = container.get<ServiceA>();
      final instance2 = container.get<ServiceA>();

      expect(instance1, isNot(same(instance2)));
      expect(instance1.id, isNot(equals(instance2.id)));
    });

    test('registerSingleton should return same instance', () async {
      final builder = InjectorBuilder();

      builder.registerSingleton<ServiceA>((c) => ServiceA());
      final container = await builder.build();

      final instance1 = container.get<ServiceA>();
      final instance2 = container.get<ServiceA>();

      expect(instance1, same(instance2));
      expect(instance1.id, equals(instance2.id));
    });

    test('registerSingleton with name should work correctly', () async {
      final builder = InjectorBuilder();

      builder.registerSingleton<ServiceA>(
        (c) => ServiceA(),
        name: 'singleton1',
      );
      builder.registerSingleton<ServiceA>(
        (c) => ServiceA(),
        name: 'singleton2',
      );
      final container = await builder.build();

      final instance1a = container.get<ServiceA>('singleton1');
      final instance1b = container.get<ServiceA>('singleton1');
      final instance2a = container.get<ServiceA>('singleton2');

      expect(instance1a, same(instance1b));
      expect(instance1a, isNot(same(instance2a)));
    });

    test('registering same type without name should overwrite', () async {
      final builder = InjectorBuilder();
      final instance1 = ServiceA();
      final instance2 = ServiceA();

      builder.registerInstance<ServiceA>(instance1);
      builder.registerInstance<ServiceA>(instance2);
      final container = await builder.build();

      expect(container.get<ServiceA>(), same(instance2));
    });
  });

  group('Container - Resolution', () {
    test('get should resolve registered service', () async {
      final builder = InjectorBuilder();
      final instance = ServiceA();

      builder.registerInstance<ServiceA>(instance);
      final container = await builder.build();

      expect(container.get<ServiceA>(), same(instance));
    });

    test('get should throw when service not registered', () async {
      final builder = InjectorBuilder();
      final container = await builder.build();

      expect(
        () => container.get<ServiceA>(),
        throwsA(isA<ServiceNotFoundException>()),
      );
    });

    test('get with name should throw when name not found', () async {
      final builder = InjectorBuilder();
      builder.registerInstance<ServiceA>(ServiceA(), name: 'test');
      final container = await builder.build();

      expect(
        () => container.get<ServiceA>('other'),
        throwsA(isA<ServiceNotFoundException>()),
      );
    });

    test('call operator should work like get', () async {
      final builder = InjectorBuilder();
      final instance = ServiceA();

      builder.registerInstance<ServiceA>(instance);
      final container = await builder.build();

      expect(container<ServiceA>(), same(instance));
      expect(container<ServiceA>(), equals(container.get<ServiceA>()));
    });

    test('call operator should work with named services', () async {
      final builder = InjectorBuilder();
      final instance = ServiceA();

      builder.registerInstance<ServiceA>(instance, name: 'test');
      final container = await builder.build();

      expect(container<ServiceA>('test'), same(instance));
    });

    test('contains should return true for registered service', () async {
      final builder = InjectorBuilder();
      builder.registerInstance<ServiceA>(ServiceA());
      final container = await builder.build();

      expect(container.contains<ServiceA>(), isTrue);
    });

    test('contains should return false for unregistered service', () async {
      final builder = InjectorBuilder();
      final container = await builder.build();

      expect(container.contains<ServiceA>(), isFalse);
    });

    test('contains with name should work correctly', () async {
      final builder = InjectorBuilder();
      builder.registerInstance<ServiceA>(ServiceA(), name: 'test');
      final container = await builder.build();

      expect(container.contains<ServiceA>('test'), isTrue);
      expect(container.contains<ServiceA>('other'), isFalse);
      expect(container.contains<ServiceA>(), isFalse);
    });

    test('should handle null names correctly', () async {
      final builder = InjectorBuilder();
      final instance1 = ServiceA();
      final instance2 = ServiceA();

      builder.registerInstance<ServiceA>(instance1);
      builder.registerInstance<ServiceA>(instance2, name: 'named');

      final container = await builder.build();

      expect(container.get<ServiceA>(), same(instance1));
      expect(container.get<ServiceA>(null), same(instance1));
      expect(container.get<ServiceA>('named'), same(instance2));
    });

    test('all should return all instances of type', () async {
      final builder = InjectorBuilder();
      final instance1 = ServiceA();
      final instance2 = ServiceA();

      builder.registerInstance<ServiceA>(instance1, name: 'first');
      builder.registerInstance<ServiceA>(instance2, name: 'second');
      final container = await builder.build();

      final all = container.all<ServiceA>();

      expect(all, hasLength(2));
      expect(all, containsAll([instance1, instance2]));
    });

    test('all should return empty list when no instances registered', () async {
      final builder = InjectorBuilder();
      final container = await builder.build();

      expect(container.all<ServiceA>(), isEmpty);
    });
  });

  group('Container - Dependency Injection', () {
    test('factory can resolve dependencies from container', () async {
      final builder = InjectorBuilder();

      builder.registerSingleton<ServiceA>((c) => ServiceA());
      builder.registerFactory<ServiceB>((c) => ServiceB(c.get<ServiceA>()));
      final container = await builder.build();

      final serviceB = container.get<ServiceB>();
      final serviceA = container.get<ServiceA>();

      expect(serviceB.serviceA, same(serviceA));
    });

    test('complex dependency chain should work', () async {
      final builder = InjectorBuilder();

      builder.registerSingleton<ServiceA>((c) => ServiceA());
      builder.registerSingleton<ServiceB>((c) => ServiceB(c.get<ServiceA>()));
      final container = await builder.build();

      final serviceB = container.get<ServiceB>();
      final serviceA = container.get<ServiceA>();

      expect(serviceB.serviceA, same(serviceA));
    });

    test('should resolve multiple dependencies in correct order', () async {
      final builder = InjectorBuilder();

      builder.registerSingleton<ServiceA>((c) => ServiceA());
      builder.registerSingleton<ServiceB>((c) => ServiceB(c.get<ServiceA>()));
      builder.registerSingleton<ServiceD>(
        (c) => ServiceD(c.get<ServiceA>(), c.get<ServiceB>()),
      );

      final container = await builder.build();
      final serviceD = container.get<ServiceD>();

      expect(serviceD.serviceA, same(container.get<ServiceA>()));
      expect(serviceD.serviceB, same(container.get<ServiceB>()));
      expect(serviceD.serviceB.serviceA, same(container.get<ServiceA>()));
    });

    test('should handle optional dependencies', () async {
      final builder = InjectorBuilder();

      builder.registerFactory<ServiceWithOptional>(
        (c) => ServiceWithOptional(
          c.contains<ServiceA>() ? c.get<ServiceA>() : null,
        ),
      );

      final container = await builder.build();
      final service = container.get<ServiceWithOptional>();

      expect(service.optionalService, isNull);
    });

    test('should resolve named dependencies correctly', () async {
      final builder = InjectorBuilder();

      builder.registerSingleton<ServiceA>((c) => ServiceA(), name: 'primary');
      builder.registerSingleton<ServiceA>((c) => ServiceA(), name: 'secondary');
      builder.registerFactory<ServiceB>(
        (c) => ServiceB(c.get<ServiceA>('primary')),
      );

      final container = await builder.build();
      final serviceB = container.get<ServiceB>();

      expect(serviceB.serviceA, same(container.get<ServiceA>('primary')));
      expect(
        serviceB.serviceA,
        isNot(same(container.get<ServiceA>('secondary'))),
      );
    });

    test('factory can access other named services', () async {
      final builder = InjectorBuilder();
      final config = {'key': 'value'};

      builder.registerInstance<Map<String, dynamic>>(
        config,
        name: 'appConfig',
      );
      builder.registerFactory<ConfigService>(
        (c) => ConfigService(c.get<Map<String, dynamic>>('appConfig')),
      );

      final container = await builder.build();
      final configService = container.get<ConfigService>();

      expect(configService.config, same(config));
    });

    test('should handle complex nested dependencies', () async {
      final builder = InjectorBuilder();

      builder.registerSingleton<ServiceA>((c) => ServiceA());
      builder.registerSingleton<ServiceB>((c) => ServiceB(c.get<ServiceA>()));
      builder.registerSingleton<ServiceD>(
        (c) => ServiceD(c.get<ServiceA>(), c.get<ServiceB>()),
      );

      final container = await builder.build();

      for (int i = 0; i < 10; i++) {
        final service = container.get<ServiceD>();
        expect(service.serviceA, same(container.get<ServiceA>()));
        expect(service.serviceB, same(container.get<ServiceB>()));
      }
    });
  });

  group('Container - Lifecycle and State', () {
    test('onCreate should be called after factory creation', () async {
      final builder = InjectorBuilder();
      var callbackCalled = false;
      ServiceA? callbackInstance;

      builder.registerFactory<ServiceA>(
        (c) => ServiceA(),
        onCreate: (instance, c) {
          callbackCalled = true;
          callbackInstance = instance;
        },
      );
      final container = await builder.build();

      final instance = container.get<ServiceA>();

      expect(callbackCalled, isTrue);
      expect(callbackInstance, same(instance));
    });

    test('onCreate should be called once for singleton', () async {
      final builder = InjectorBuilder();
      var callCount = 0;

      builder.registerSingleton<ServiceA>(
        (c) => ServiceA(),
        onCreate: (instance, c) => callCount++,
      );
      final container = await builder.build();

      container.get<ServiceA>();
      container.get<ServiceA>();
      container.get<ServiceA>();

      expect(callCount, equals(1));
    });

    test('onCreate should be called each time for factory', () async {
      final builder = InjectorBuilder();
      var callCount = 0;

      builder.registerFactory<ServiceA>(
        (c) => ServiceA(),
        onCreate: (instance, c) => callCount++,
      );
      final container = await builder.build();

      container.get<ServiceA>();
      container.get<ServiceA>();
      container.get<ServiceA>();

      expect(callCount, equals(3));
    });

    test('onCreate should have access to container services', () async {
      final builder = InjectorBuilder();
      ServiceA? serviceFromCallback;

      builder.registerSingleton<ServiceA>((c) => ServiceA());
      builder.registerFactory<ServiceB>(
        (c) => ServiceB(c.get<ServiceA>()),
        onCreate: (instance, container) {
          serviceFromCallback = container.get<ServiceA>();
        },
      );

      final container = await builder.build();
      container.get<ServiceB>();

      expect(serviceFromCallback, same(container.get<ServiceA>()));
    });

    test(
      'onCreate should be called in correct order for dependencies',
      () async {
        final builder = InjectorBuilder();
        final callOrder = <String>[];

        builder.registerSingleton<ServiceA>(
          (c) => ServiceA(),
          onCreate: (_, _) => callOrder.add('ServiceA'),
        );
        builder.registerSingleton<ServiceB>(
          (c) => ServiceB(c.get<ServiceA>()),
          onCreate: (_, _) => callOrder.add('ServiceB'),
        );

        final container = await builder.build();
        container.get<ServiceB>();

        expect(callOrder, equals(['ServiceA', 'ServiceB']));
      },
    );

    test('singleton should maintain state across multiple gets', () async {
      final builder = InjectorBuilder();

      builder.registerSingleton<ServiceC>((c) => ServiceC());
      final container = await builder.build();

      final service1 = container.get<ServiceC>();
      service1.incrementCall();
      service1.incrementCall();

      final service2 = container.get<ServiceC>();

      expect(service2.callCount, equals(2));
      expect(service1, same(service2));
    });

    test('factory instances should have independent state', () async {
      final builder = InjectorBuilder();

      builder.registerFactory<ServiceC>((c) => ServiceC());
      final container = await builder.build();

      final service1 = container.get<ServiceC>();
      service1.incrementCall();
      service1.incrementCall();

      final service2 = container.get<ServiceC>();
      service2.incrementCall();

      expect(service1.callCount, equals(2));
      expect(service2.callCount, equals(1));
    });
  });

  group('Container - Multiple Instances', () {
    test('all() should return instances in registration order', () async {
      final builder = InjectorBuilder();

      builder.registerInstance<ServiceA>(ServiceA(), name: 'first');
      builder.registerInstance<ServiceA>(ServiceA(), name: 'second');
      builder.registerInstance<ServiceA>(ServiceA(), name: 'third');

      final container = await builder.build();
      final all = container.all<ServiceA>();

      expect(all, hasLength(3));
      expect(all[0], same(container.get<ServiceA>('first')));
      expect(all[1], same(container.get<ServiceA>('second')));
      expect(all[2], same(container.get<ServiceA>('third')));
    });

    test('all() should include unnamed registration', () async {
      final builder = InjectorBuilder();

      builder.registerInstance<ServiceA>(ServiceA());
      builder.registerInstance<ServiceA>(ServiceA(), name: 'named');

      final container = await builder.build();
      final all = container.all<ServiceA>();

      expect(all, hasLength(2));
    });

    test('all() should create new instances for factories', () async {
      final builder = InjectorBuilder();

      builder.registerFactory<ServiceA>((c) => ServiceA(), name: 'factory1');
      builder.registerFactory<ServiceA>((c) => ServiceA(), name: 'factory2');

      final container = await builder.build();

      final all1 = container.all<ServiceA>();
      final all2 = container.all<ServiceA>();

      expect(all1[0], isNot(same(all2[0])));
      expect(all1[1], isNot(same(all2[1])));
    });

    test('all() should return same singletons', () async {
      final builder = InjectorBuilder();

      builder.registerSingleton<ServiceA>((c) => ServiceA(), name: 's1');
      builder.registerSingleton<ServiceA>((c) => ServiceA(), name: 's2');

      final container = await builder.build();

      final all1 = container.all<ServiceA>();
      final all2 = container.all<ServiceA>();

      expect(all1[0], same(all2[0]));
      expect(all1[1], same(all2[1]));
    });
  });

  group('Container - Error Handling', () {
    test('should throw ServiceNotFoundException for missing service', () async {
      final builder = InjectorBuilder();
      final container = await builder.build();

      expect(
        () => container.get<ServiceA>(),
        throwsA(
          predicate(
            (e) =>
                e is ServiceNotFoundException &&
                e.serviceType == ServiceA &&
                e.message.contains('ServiceA'),
          ),
        ),
      );
    });

    test(
      'should throw ServiceNotFoundException for missing named service',
      () async {
        final builder = InjectorBuilder();
        builder.registerInstance<ServiceA>(ServiceA(), name: 'existing');
        final container = await builder.build();

        expect(
          () => container.get<ServiceA>('missing'),
          throwsA(
            predicate(
              (e) => e is ServiceNotFoundException && e.serviceType == ServiceA,
            ),
          ),
        );
      },
    );

    test('should handle exceptions in factory gracefully', () async {
      final builder = InjectorBuilder();

      builder.registerFactory<ServiceA>(
        (c) => throw Exception('Factory error'),
      );

      final container = await builder.build();

      expect(
        () => container.get<ServiceA>(),
        throwsA(isA<Exception>()),
      );
    });

    test('should handle exceptions in onCreate callback', () async {
      final builder = InjectorBuilder();

      builder.registerFactory<ServiceA>(
        (c) => ServiceA(),
        onCreate: (_, _) => throw Exception('onCreate error'),
      );

      final container = await builder.build();

      expect(
        () => container.get<ServiceA>(),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Container - Edge Cases', () {
    test('multiple builds should create independent containers', () async {
      final builder = InjectorBuilder();
      builder.registerFactory<ServiceA>((c) => ServiceA());

      final container1 = await builder.build();
      final container2 = await builder.build();

      expect(container1, isNot(same(container2)));
    });

    test('container should be immutable after build', () async {
      final builder = InjectorBuilder();
      builder.registerSingleton<ServiceA>((c) => ServiceA());

      final container = await builder.build();
      final instance1 = container.get<ServiceA>();

      builder.registerSingleton<ServiceB>((c) => ServiceB(c.get<ServiceA>()));

      expect(
        () => container.get<ServiceB>(),
        throwsA(isA<ServiceNotFoundException>()),
      );
      expect(container.get<ServiceA>(), same(instance1));
    });

    test('singleton instances should be isolated per container', () async {
      final builder = InjectorBuilder();
      builder.registerSingleton<ServiceA>((c) => ServiceA());

      final container1 = await builder.build();
      final container2 = await builder.build();

      final instance1 = container1.get<ServiceA>();
      final instance2 = container2.get<ServiceA>();

      expect(instance1, isNot(same(instance2)));
    });

    test('multiple builds should not share singleton instances', () async {
      final builder = InjectorBuilder();
      var creationCount = 0;

      builder.registerSingleton<ServiceA>((c) {
        creationCount++;
        return ServiceA();
      });

      final container1 = await builder.build();
      final container2 = await builder.build();

      container1.get<ServiceA>();
      container2.get<ServiceA>();

      expect(creationCount, equals(2));
    });

    test('should handle generic types correctly', () async {
      final builder = InjectorBuilder();

      builder.registerInstance<List<String>>(['a', 'b', 'c']);
      builder.registerInstance<List<int>>([1, 2, 3]);

      final container = await builder.build();

      expect(container.get<List<String>>(), equals(['a', 'b', 'c']));
      expect(container.get<List<int>>(), equals([1, 2, 3]));
    });
  });

  group('Container - Type Matching', () {
    test(
      'all() should return implementations when requesting by interface',
      () async {
        final builder = InjectorBuilder();

        builder.registerInstance<SomeLogger>(ConsoleLogger(), name: 'console');
        builder.registerInstance<SomeLogger>(FileLogger(), name: 'file');

        final container = await builder.build();
        final loggers = container.all<SomeLogger>();

        expect(loggers, hasLength(2));
        expect(loggers.whereType<ConsoleLogger>(), hasLength(1));
        expect(loggers.whereType<FileLogger>(), hasLength(1));
      },
    );

    test(
      'all() should return subclasses when requesting by base class',
      () async {
        final builder = InjectorBuilder();

        builder.registerInstance<Animal>(Dog(), name: 'dog');
        builder.registerInstance<Animal>(Cat(), name: 'cat');
        builder.registerInstance<Animal>(Bird(), name: 'bird');

        final container = await builder.build();
        final animals = container.all<Animal>();

        expect(animals, hasLength(3));
        expect(animals.whereType<Dog>(), hasLength(1));
        expect(animals.whereType<Cat>(), hasLength(1));
        expect(animals.whereType<Bird>(), hasLength(1));
      },
    );

    test('all() should work with specific implementation type', () async {
      final builder = InjectorBuilder();

      builder.registerInstance<SomeLogger>(ConsoleLogger(), name: 'console');
      builder.registerInstance<SomeLogger>(FileLogger(), name: 'file');

      final container = await builder.build();
      final consoleLoggers = container.all<ConsoleLogger>();

      expect(consoleLoggers, hasLength(1));
      expect(consoleLoggers.first, isA<ConsoleLogger>());
    });

    test('all() should not return unrelated types', () async {
      final builder = InjectorBuilder();

      builder.registerInstance<SomeLogger>(ConsoleLogger(), name: 'logger');
      builder.registerInstance<Animal>(Dog(), name: 'animal');
      builder.registerInstance<ServiceA>(ServiceA(), name: 'service');

      final container = await builder.build();

      expect(container.all<SomeLogger>(), hasLength(1));
      expect(container.all<Animal>(), hasLength(1));
      expect(container.all<ServiceA>(), hasLength(1));
    });

    test('all() should handle multiple inheritance levels', () async {
      final builder = InjectorBuilder();

      builder.registerInstance<Animal>(Bird(), name: 'bird');
      builder.registerInstance<Mammal>(Cat(), name: 'cat');
      builder.registerInstance<Mammal>(Dog(), name: 'dog');

      final container = await builder.build();

      final animals = container.all<Animal>();
      expect(animals, hasLength(3));

      final mammals = container.all<Mammal>();
      expect(mammals, hasLength(2));
    });

    test('all() should respect generic type parameters', () async {
      final builder = InjectorBuilder();

      builder.registerInstance<Repository<String>>(
        StringRepository(),
        name: 'string',
      );
      builder.registerInstance<Repository<int>>(
        IntRepository(),
        name: 'int',
      );

      final container = await builder.build();

      final stringRepos = container.all<Repository<String>>();
      final intRepos = container.all<Repository<int>>();
      final allRepos = container.all<Repository>();

      expect(stringRepos, hasLength(1));
      expect(intRepos, hasLength(1));
      expect(allRepos, hasLength(2));
    });

    test('all() should work with mixin types', () async {
      final builder = InjectorBuilder();

      builder.registerInstance<Flyable>(Bird(), name: 'bird');
      builder.registerInstance<Flyable>(Plane(), name: 'plane');

      final container = await builder.build();
      final flyables = container.all<Flyable>();

      expect(flyables, hasLength(2));
      expect(flyables.whereType<Bird>(), hasLength(1));
      expect(flyables.whereType<Plane>(), hasLength(1));
    });

    test('all() should work with abstract classes', () async {
      final builder = InjectorBuilder();

      builder.registerInstance<Shape>(Circle(), name: 'circle');
      builder.registerInstance<Shape>(Rectangle(), name: 'rectangle');

      final container = await builder.build();
      final shapes = container.all<Shape>();

      expect(shapes, hasLength(2));
      expect(shapes.whereType<Circle>(), hasLength(1));
      expect(shapes.whereType<Rectangle>(), hasLength(1));
    });

    test('matches should work correctly with factories', () async {
      final builder = InjectorBuilder();

      builder.registerFactory<SomeLogger>(
        (c) => ConsoleLogger(),
        name: 'console',
      );
      builder.registerFactory<SomeLogger>((c) => FileLogger(), name: 'file');

      final container = await builder.build();

      final all1 = container.all<SomeLogger>();
      final all2 = container.all<SomeLogger>();

      expect(all1, hasLength(2));
      expect(all2, hasLength(2));
      expect(all1[0], isNot(same(all2[0])));
    });

    test('matches should work with complex type hierarchies', () async {
      final builder = InjectorBuilder();

      builder.registerInstance<Animal>(Dog(), name: 'dog');
      builder.registerInstance<Mammal>(Cat(), name: 'cat');
      builder.registerInstance<Flyable>(Bird(), name: 'bird');

      final container = await builder.build();

      final animals = container.all<Animal>();
      expect(animals, hasLength(3));

      final mammals = container.all<Mammal>();
      expect(mammals, hasLength(2));

      final flyables = container.all<Flyable>();
      expect(flyables, hasLength(1));
    });

    test(
      'all() should handle identical types registered multiple times',
      () async {
        final builder = InjectorBuilder();

        builder.registerInstance<ConsoleLogger>(ConsoleLogger(), name: 'first');
        builder.registerInstance<ConsoleLogger>(
          ConsoleLogger(),
          name: 'second',
        );
        builder.registerInstance<SomeLogger>(ConsoleLogger(), name: 'third');

        final container = await builder.build();

        final consoleLoggers = container.all<ConsoleLogger>();
        final loggers = container.all<SomeLogger>();

        expect(consoleLoggers, hasLength(3));
        expect(loggers, hasLength(3));
      },
    );

    test('all() with mixed registration types should work correctly', () async {
      final builder = InjectorBuilder();

      builder.registerInstance<SomeLogger>(ConsoleLogger(), name: 'instance');
      builder.registerFactory<SomeLogger>((c) => FileLogger(), name: 'factory');
      builder.registerSingleton<SomeLogger>(
        (c) => ConsoleLogger(),
        name: 'singleton',
      );

      final container = await builder.build();
      final loggers = container.all<SomeLogger>();

      expect(loggers, hasLength(3));
    });
  });
}
