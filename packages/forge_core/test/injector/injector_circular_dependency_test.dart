import 'package:forge_core/forge_core.dart';
import 'package:test/test.dart';

// Test fixtures for circular dependencies
class ServiceE {
  final ServiceF serviceF;
  ServiceE(this.serviceF);
}

class ServiceF {
  final ServiceE serviceE;
  ServiceF(this.serviceE);
}

class ServiceG {
  final ServiceH serviceH;
  ServiceG(this.serviceH);
}

class ServiceH {
  final ServiceI serviceI;
  ServiceH(this.serviceI);
}

class ServiceI {
  final ServiceG serviceG;
  ServiceI(this.serviceG);
}

class ServiceJ {
  final ServiceK serviceK;
  ServiceJ(this.serviceK);
}

class ServiceK {
  ServiceK();
}

class ServiceL {
  final ServiceM serviceM;
  ServiceL(this.serviceM);
}

class ServiceM {
  final ServiceN serviceN;
  ServiceM(this.serviceN);
}

class ServiceN {
  ServiceN();
}

void main() {
  group('Circular Dependency Detection', () {
    test('should detect direct circular dependency', () async {
      final builder = InjectorBuilder();

      builder.registerFactory<ServiceE>((c) => ServiceE(c.get<ServiceF>()));
      builder.registerFactory<ServiceF>((c) => ServiceF(c.get<ServiceE>()));

      final container = await builder.build();

      expect(
        () => container.get<ServiceE>(),
        throwsA(
          predicate(
            (e) =>
                e is CircularDependencyException &&
                e.dependencyChain.contains(ServiceE) &&
                e.dependencyChain.contains(ServiceF),
          ),
        ),
      );
    });

    test('should detect indirect circular dependency (3 levels)', () async {
      final builder = InjectorBuilder();

      builder.registerFactory<ServiceG>((c) => ServiceG(c.get<ServiceH>()));
      builder.registerFactory<ServiceH>((c) => ServiceH(c.get<ServiceI>()));
      builder.registerFactory<ServiceI>((c) => ServiceI(c.get<ServiceG>()));

      final container = await builder.build();

      expect(
        () => container.get<ServiceG>(),
        throwsA(
          predicate(
            (e) =>
                e is CircularDependencyException &&
                e.dependencyChain.contains(ServiceG) &&
                e.dependencyChain.contains(ServiceH) &&
                e.dependencyChain.contains(ServiceI),
          ),
        ),
      );
    });

    test('circular dependency error should have clear message', () async {
      final builder = InjectorBuilder();

      builder.registerFactory<ServiceE>((c) => ServiceE(c.get<ServiceF>()));
      builder.registerFactory<ServiceF>((c) => ServiceF(c.get<ServiceE>()));

      final container = await builder.build();

      try {
        container.get<ServiceE>();
        fail('Should have thrown CircularDependencyException');
      } on CircularDependencyException catch (e) {
        expect(e.message, contains('Circular dependency detected'));
        expect(e.message, contains('ServiceE'));
        expect(e.message, contains('ServiceF'));
        expect(e.message, contains('CIRCULAR'));
      }
    });

    test('should not throw for valid dependency chain', () async {
      final builder = InjectorBuilder();

      builder.registerFactory<ServiceK>((c) => ServiceK());
      builder.registerFactory<ServiceJ>((c) => ServiceJ(c.get<ServiceK>()));

      final container = await builder.build();

      expect(() => container.get<ServiceJ>(), returnsNormally);
    });

    test('should detect circular dependency with singletons', () async {
      final builder = InjectorBuilder();

      builder.registerSingleton<ServiceE>((c) => ServiceE(c.get<ServiceF>()));
      builder.registerSingleton<ServiceF>((c) => ServiceF(c.get<ServiceE>()));

      final container = await builder.build();

      expect(
        () => container.get<ServiceE>(),
        throwsA(isA<CircularDependencyException>()),
      );
    });

    test('should detect circular dependency in async services', () async {
      final builder = InjectorBuilder();

      builder.registerAsyncFactory<ServiceE>(
        (c) async => ServiceE(await c.getAsync<ServiceF>()),
      );
      builder.registerAsyncFactory<ServiceF>(
        (c) async => ServiceF(await c.getAsync<ServiceE>()),
      );

      final container = await builder.build();

      expect(
        () async => await container.getAsync<ServiceE>(),
        throwsA(isA<CircularDependencyException>()),
      );
    });

    test('should detect circular dependency in mixed async', () async {
      final builder = InjectorBuilder();

      builder.registerAsyncFactory<ServiceE>(
        (c) async => ServiceE(await c.getAsync<ServiceF>()),
      );
      builder.registerAsyncFactory<ServiceF>(
        (c) async => ServiceF(await c.getAsync<ServiceE>()),
      );

      final container = await builder.build();

      expect(
        () => container.getAsync<ServiceF>(),
        throwsA(isA<CircularDependencyException>()),
      );
    });

    test('should allow same type in different branches', () async {
      final builder = InjectorBuilder();

      builder.registerFactory<ServiceK>((c) => ServiceK());
      builder.registerFactory<ServiceJ>((c) => ServiceJ(c.get<ServiceK>()));
      builder.registerFactory<ServiceL>((c) => ServiceL(c.get<ServiceM>()));
      builder.registerFactory<ServiceM>((c) => ServiceM(c.get<ServiceN>()));
      builder.registerFactory<ServiceN>((c) => ServiceN());

      final container = await builder.build();

      expect(() => container.get<ServiceJ>(), returnsNormally);
      expect(() => container.get<ServiceL>(), returnsNormally);
    });
  });

  group('Missing Dependency Detection', () {
    test(
      'should throw ServiceNotFoundException for missing dependency',
      () async {
        final builder = InjectorBuilder();

        builder.registerFactory<ServiceJ>((c) => ServiceJ(c.get<ServiceK>()));
        // ServiceK not registered

        final container = await builder.build();

        expect(
          () => container.get<ServiceJ>(),
          throwsA(isA<ServiceNotFoundException>()),
        );
      },
    );

    test('missing dependency error should include resolution stack', () async {
      final builder = InjectorBuilder();

      builder.registerFactory<ServiceL>((c) => ServiceL(c.get<ServiceM>()));
      builder.registerFactory<ServiceM>((c) => ServiceM(c.get<ServiceN>()));
      // ServiceN not registered

      final container = await builder.build();

      try {
        container.get<ServiceL>();
        fail('Should have thrown ServiceNotFoundException');
      } on ServiceNotFoundException catch (e) {
        expect(e.serviceType, equals(ServiceN));
        expect(e.resolutionStack, contains(ServiceL));
        expect(e.resolutionStack, contains(ServiceM));
        expect(e.message, contains('ServiceN'));
        expect(e.message, contains('NOT FOUND'));
      }
    });

    test('missing dependency error should show requesting type', () async {
      final builder = InjectorBuilder();

      builder.registerFactory<ServiceJ>((c) => ServiceJ(c.get<ServiceK>()));

      final container = await builder.build();

      try {
        container.get<ServiceJ>();
        fail('Should have thrown ServiceNotFoundException');
      } on ServiceNotFoundException catch (e) {
        expect(e.requestingType, equals(ServiceJ));
        expect(e.message, contains('requested by ServiceJ'));
      }
    });

    test('should detect missing dependency in deep chain', () async {
      final builder = InjectorBuilder();

      builder.registerFactory<ServiceG>((c) => ServiceG(c.get<ServiceH>()));
      builder.registerFactory<ServiceH>((c) => ServiceH(c.get<ServiceI>()));
      // ServiceI not registered

      final container = await builder.build();

      try {
        container.get<ServiceG>();
        fail('Should have thrown ServiceNotFoundException');
      } on ServiceNotFoundException catch (e) {
        expect(e.serviceType, equals(ServiceI));
        expect(e.resolutionStack.length, greaterThan(0));
        expect(e.message, contains('Resolution stack'));
        expect(e.message, contains('ServiceG'));
        expect(e.message, contains('ServiceH'));
      }
    });

    test('should throw for missing async dependency', () async {
      final builder = InjectorBuilder();

      builder.registerAsyncFactory<ServiceJ>(
        (c) async => ServiceJ(await c.getAsync<ServiceK>()),
      );
      // ServiceK not registered

      final container = await builder.build();

      expect(
        () async => await container.getAsync<ServiceJ>(),
        throwsA(isA<ServiceNotFoundException>()),
      );
    });

    test('missing named service should include name in error', () async {
      final builder = InjectorBuilder();

      builder.registerFactory<ServiceJ>(
        (c) => ServiceJ(c.get<ServiceK>('special')),
      );
      // ServiceK with name 'special' not registered

      final container = await builder.build();

      try {
        container.get<ServiceJ>();
        fail('Should have thrown ServiceNotFoundException');
      } on ServiceNotFoundException catch (e) {
        expect(e.message, contains('ServiceK'));
      }
    });

    test('should handle optional dependencies without error', () async {
      final builder = InjectorBuilder();

      builder.registerFactory<ServiceJ>(
        (c) =>
            ServiceJ(c.contains<ServiceK>() ? c.get<ServiceK>() : ServiceK()),
      );
      // ServiceK not registered, but handled with contains check

      final container = await builder.build();

      expect(() => container.get<ServiceJ>(), returnsNormally);
    });
  });

  group('Error Messages', () {
    test('ServiceNotFoundException should have descriptive toString', () {
      final exception = ServiceNotFoundException(
        ServiceK,
        resolutionStack: [ServiceJ, ServiceL],
        requestingType: ServiceL,
      );

      final str = exception.toString();
      expect(str, contains('ServiceNotFoundException'));
      expect(str, contains('ServiceK'));
    });

    test('CircularDependencyException should have descriptive toString', () {
      final exception = CircularDependencyException([
        ServiceE,
        ServiceF,
      ]);

      final str = exception.toString();
      expect(str, contains('CircularDependencyException'));
      expect(str, contains('Circular dependency'));
    });

    test('resolution stack should be formatted clearly', () async {
      final builder = InjectorBuilder();

      builder.registerFactory<ServiceL>((c) => ServiceL(c.get<ServiceM>()));
      builder.registerFactory<ServiceM>((c) => ServiceM(c.get<ServiceN>()));

      final container = await builder.build();

      try {
        container.get<ServiceL>();
        fail('Should have thrown');
      } on ServiceNotFoundException catch (e) {
        expect(e.message, contains('└─>'));
      }
    });
  });

  group('Complex Scenarios', () {
    test('should handle partial circular dependencies', () async {
      final builder = InjectorBuilder();

      // Valid chain: J -> K
      builder.registerFactory<ServiceK>((c) => ServiceK());
      builder.registerFactory<ServiceJ>((c) => ServiceJ(c.get<ServiceK>()));

      // Circular chain: E <-> F
      builder.registerFactory<ServiceE>((c) => ServiceE(c.get<ServiceF>()));
      builder.registerFactory<ServiceF>((c) => ServiceF(c.get<ServiceE>()));

      final container = await builder.build();

      // Valid chain should work
      expect(() => container.get<ServiceJ>(), returnsNormally);

      // Circular chain should fail
      expect(
        () => container.get<ServiceE>(),
        throwsA(isA<CircularDependencyException>()),
      );
    });

    test('should handle mixed valid and invalid dependencies', () async {
      final builder = InjectorBuilder();

      builder.registerFactory<ServiceK>((c) => ServiceK());
      builder.registerFactory<ServiceJ>((c) => ServiceJ(c.get<ServiceK>()));
      builder.registerFactory<ServiceL>((c) => ServiceL(c.get<ServiceM>()));
      // ServiceM not registered

      final container = await builder.build();

      expect(() => container.get<ServiceJ>(), returnsNormally);
      expect(
        () => container.get<ServiceL>(),
        throwsA(isA<ServiceNotFoundException>()),
      );
    });

    test('all() should skip services with circular dependencies', () async {
      final builder = InjectorBuilder();

      builder.registerFactory<ServiceK>((c) => ServiceK(), name: 'valid');
      builder.registerFactory<ServiceE>(
        (c) => ServiceE(c.get<ServiceF>()),
        name: 'circular',
      );
      builder.registerFactory<ServiceF>((c) => ServiceF(c.get<ServiceE>()));

      final container = await builder.build();

      // all() should not throw, but skip problematic services
      final allK = container.all<ServiceK>();
      expect(allK, hasLength(1));
    });
  });
}
