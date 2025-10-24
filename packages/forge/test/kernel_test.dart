import 'package:test/test.dart';
import 'package:forge/forge.dart';
import 'dart:async';

class TestBundle extends Bundle {
  final List<String> buildLog;
  final List<String> bootLog;
  final Future<void> Function(InjectorBuilder)? onBuild;
  final Future<void> Function(Injector)? onBoot;

  TestBundle(
    this.buildLog,
    this.bootLog, {
    this.onBuild,
    this.onBoot,
  });

  @override
  Future<void> build(InjectorBuilder builder, String env) async {
    buildLog.add('TestBundle.build');
    await onBuild?.call(builder);
  }

  @override
  Future<void> boot(Injector container) async {
    bootLog.add('TestBundle.boot');
    await onBoot?.call(container);
  }
}

class ServiceBundle extends Bundle {
  @override
  Future<void> build(InjectorBuilder builder, String env) async {
    builder.registerSingleton<TestService>((c) => TestService());
    builder.registerInstance<String>('ServiceBundle', name: 'bundleName');
  }

  @override
  Future<void> boot(Injector container) async {
    final service = container.get<TestService>();
    service.initialize();
  }
}

class ErrorBundle extends Bundle {
  final bool errorInBuild;
  final bool errorInBoot;

  ErrorBundle({this.errorInBuild = false, this.errorInBoot = false});

  @override
  Future<void> build(InjectorBuilder builder, String env) async {
    if (errorInBuild) {
      throw Exception('Error in build phase');
    }
  }

  @override
  Future<void> boot(Injector container) async {
    if (errorInBoot) {
      throw Exception('Error in boot phase');
    }
  }
}

// Test Runners
class TestRunner implements Runner {
  final List<String> runLog;
  final List<String>? receivedArgs;
  final Future<void> Function()? onRun;

  TestRunner(this.runLog, {this.receivedArgs, this.onRun});

  @override
  Future<void> run([List<String>? args]) async {
    runLog.add('TestRunner.run');
    if (receivedArgs != null && args != null) {
      receivedArgs!.addAll(args);
    }
    await onRun?.call();
  }
}

class DelayedRunner implements Runner {
  final Duration delay;
  final List<String> runLog;

  DelayedRunner(this.delay, this.runLog);

  @override
  Future<void> run([List<String>? args]) async {
    runLog.add('DelayedRunner.start');
    await Future.delayed(delay);
    runLog.add('DelayedRunner.end');
  }
}

class ErrorRunner implements Runner {
  @override
  Future<void> run([List<String>? args]) async {
    throw Exception('Runner error');
  }
}

class ContainerRunner implements Runner {
  Injector? container;

  @override
  Future<void> run([List<String>? args]) async {
    // This runner will be registered in the container
  }
}

// Test Services
class TestService {
  bool isInitialized = false;

  void initialize() {
    isInitialized = true;
  }
}

// Test Event Subscribers
class TestEventSubscriber implements EventSubscriber {
  final List<String> eventLog;

  TestEventSubscriber(this.eventLog);

  @override
  void subscribe(EventBus dispatcher) {
    dispatcher.on<KernelRunEvent>(_onKernelRun);
    dispatcher.on<KernelErrorEvent>(_onKernelError);
  }

  void _onKernelRun(KernelRunEvent event) {
    eventLog.add('KernelRunEvent');
  }

  void _onKernelError(KernelErrorEvent event) {
    eventLog.add('KernelErrorEvent: ${event.error}');
  }
}

void main() {
  group('Kernel - Basic Operations', () {
    test('should create kernel with environment', () {
      final kernel = Kernel('test');
      expect(kernel.env, equals('test'));
    });

    test('should accept different environment names', () {
      final devKernel = Kernel('dev');
      final prodKernel = Kernel('prod');
      final testKernel = Kernel('test');

      expect(devKernel.env, equals('dev'));
      expect(prodKernel.env, equals('prod'));
      expect(testKernel.env, equals('test'));
    });

    test('should add bundles', () {
      final kernel = Kernel('test');
      final buildLog = <String>[];
      final bootLog = <String>[];

      kernel.addBundle(TestBundle(buildLog, bootLog));
      kernel.addBundle(TestBundle(buildLog, bootLog));

      expect(() => kernel.run(), returnsNormally);
    });

    test('should add runners', () {
      final kernel = Kernel('test');
      final runLog = <String>[];

      kernel.addRunner(TestRunner(runLog));
      kernel.addRunner(TestRunner(runLog));

      expect(() => kernel.run(), returnsNormally);
    });

    test('should throw when accessing container before run', () {
      final kernel = Kernel('test');

      expect(
        () => kernel.injector,
        throwsA(
          predicate(
            (e) =>
                e is KernelException &&
                e.toString().contains('Kernel is not built yet'),
          ),
        ),
      );
    });

    test('container should be accessible after run', () async {
      final kernel = Kernel('test');
      await kernel.run();

      expect(() => kernel.injector, returnsNormally);
      expect(kernel.injector, isA<Injector>());
    });
  });

  group('Kernel - Build Phase', () {
    test('should call build on all bundles', () async {
      final kernel = Kernel('test');
      final buildLog = <String>[];
      final bootLog = <String>[];

      kernel.addBundle(TestBundle(buildLog, bootLog));
      kernel.addBundle(TestBundle(buildLog, bootLog));
      kernel.addBundle(TestBundle(buildLog, bootLog));

      await kernel.run();

      expect(buildLog.length, equals(3));
    });

    test('should build bundles in order of registration', () async {
      final kernel = Kernel('test');
      final log = <String>[];

      kernel.addBundle(
        TestBundle(log, [], onBuild: (b) async => log.add('Bundle1')),
      );
      kernel.addBundle(
        TestBundle(log, [], onBuild: (b) async => log.add('Bundle2')),
      );
      kernel.addBundle(
        TestBundle(log, [], onBuild: (b) async => log.add('Bundle3')),
      );

      await kernel.run();

      expect(
        log,
        equals([
          'TestBundle.build',
          'Bundle1',
          'TestBundle.build',
          'Bundle2',
          'TestBundle.build',
          'Bundle3',
        ]),
      );
    });

    test('should provide ContainerBuilder to bundles', () async {
      final kernel = Kernel('test');
      InjectorBuilder? capturedBuilder;

      kernel.addBundle(
        TestBundle(
          [],
          [],
          onBuild: (builder) async {
            capturedBuilder = builder;
            builder.registerInstance<String>('test-value');
          },
        ),
      );

      await kernel.run();

      expect(capturedBuilder, isNotNull);
      expect(kernel.injector.get<String>(), equals('test-value'));
    });

    test('should register kernel instance in container', () async {
      final kernel = Kernel('test');
      await kernel.run();

      final containerKernel = kernel.injector.get<Kernel>();
      expect(containerKernel, same(kernel));
    });

    test('should register environment in container', () async {
      final kernel = Kernel('production');
      await kernel.run();

      final env = kernel.injector.get<String>('env');
      expect(env, equals('production'));
    });

    test('should register EventDispatcher in container', () async {
      final kernel = Kernel('test');
      await kernel.run();

      final dispatcher = kernel.injector.get<EventBus>();
      expect(dispatcher, isA<EventBus>());
    });

    test('should register Container itself in container', () async {
      final kernel = Kernel('test');
      await kernel.run();

      final container = kernel.injector.get<Injector>();
      expect(container, same(kernel.injector));
    });
  });

  group('Kernel - Boot Phase', () {
    test('should call boot on all bundles', () async {
      final kernel = Kernel('test');
      final buildLog = <String>[];
      final bootLog = <String>[];

      kernel.addBundle(TestBundle(buildLog, bootLog));
      kernel.addBundle(TestBundle(buildLog, bootLog));
      kernel.addBundle(TestBundle(buildLog, bootLog));

      await kernel.run();

      expect(bootLog.length, equals(3));
    });

    test('should boot bundles in order of registration', () async {
      final kernel = Kernel('test');
      final log = <String>[];

      kernel.addBundle(
        TestBundle([], log, onBoot: (c) async => log.add('Bundle1')),
      );
      kernel.addBundle(
        TestBundle([], log, onBoot: (c) async => log.add('Bundle2')),
      );
      kernel.addBundle(
        TestBundle([], log, onBoot: (c) async => log.add('Bundle3')),
      );

      await kernel.run();

      expect(
        log,
        equals([
          'TestBundle.boot',
          'Bundle1',
          'TestBundle.boot',
          'Bundle2',
          'TestBundle.boot',
          'Bundle3',
        ]),
      );
    });

    test('should provide built container to boot phase', () async {
      final kernel = Kernel('test');
      kernel.addBundle(ServiceBundle());

      await kernel.run();

      final service = kernel.injector.get<TestService>();
      expect(service.isInitialized, isTrue);
    });

    test('boot should happen after build', () async {
      final kernel = Kernel('test');
      final log = <String>[];

      kernel.addBundle(TestBundle(log, log));

      await kernel.run();

      expect(log, equals(['TestBundle.build', 'TestBundle.boot']));
    });

    test('should collect runners from container', () async {
      final kernel = Kernel('test');
      final runLog = <String>[];

      kernel.addBundle(
        TestBundle(
          [],
          [],
          onBuild: (builder) async {
            builder.registerInstance<Runner>(TestRunner(runLog));
          },
        ),
      );

      await kernel.run();

      expect(runLog, contains('TestRunner.run'));
    });

    test('should register EventSubscribers', () async {
      final kernel = Kernel('test');
      final eventLog = <String>[];

      kernel.addBundle(
        TestBundle(
          [],
          [],
          onBuild: (builder) async {
            builder.registerInstance<EventSubscriber>(
              TestEventSubscriber(eventLog),
            );
          },
        ),
      );

      await kernel.run();

      expect(eventLog, contains('KernelRunEvent'));
    });
  });

  group('Kernel - Runner Execution', () {
    test('should execute all runners', () async {
      final kernel = Kernel('test');
      final runLog = <String>[];

      kernel.addRunner(TestRunner(runLog));
      kernel.addRunner(TestRunner(runLog));
      kernel.addRunner(TestRunner(runLog));

      await kernel.run();

      expect(runLog.length, equals(3));
    });

    test('should pass arguments to runners', () async {
      final kernel = Kernel('test');
      final receivedArgs = <String>[];

      kernel.addRunner(TestRunner([], receivedArgs: receivedArgs));

      await kernel.run(['arg1', 'arg2', 'arg3']);

      expect(receivedArgs, equals(['arg1', 'arg2', 'arg3']));
    });

    test('should execute runners concurrently', () async {
      final kernel = Kernel('test');
      final runLog = <String>[];

      kernel.addRunner(DelayedRunner(Duration(milliseconds: 100), runLog));
      kernel.addRunner(DelayedRunner(Duration(milliseconds: 50), runLog));
      kernel.addRunner(DelayedRunner(Duration(milliseconds: 10), runLog));

      final stopwatch = Stopwatch()..start();
      await kernel.run();
      stopwatch.stop();

      // If concurrent, should take ~100ms (longest runner)
      // If sequential, would take ~160ms (sum of all)
      expect(stopwatch.elapsedMilliseconds, lessThan(130));
      expect(runLog, hasLength(6)); // 3 starts + 3 ends
    });

    test('should include runners from container', () async {
      final kernel = Kernel('test');
      final runLog = <String>[];

      kernel.addRunner(TestRunner(runLog));

      kernel.addBundle(
        TestBundle(
          [],
          [],
          onBuild: (builder) async {
            builder.registerInstance<Runner>(
              TestRunner(runLog),
              name: 'test_runner_1',
            );
            builder.registerInstance<Runner>(
              TestRunner(runLog),
              name: 'test_runner_2',
            );
          },
        ),
      );

      await kernel.run();

      expect(runLog, hasLength(3));
    });

    test('runners can access kernel services', () async {
      final kernel = Kernel('test');

      kernel.addBundle(
        TestBundle(
          [],
          [],
          onBuild: (builder) async {
            builder.registerInstance<String>('test-data');
          },
        ),
      );

      var accessedData = false;
      kernel.addRunner(
        TestRunner(
          [],
          onRun: () async {
            final data = kernel.injector.get<String>();
            accessedData = data == 'test-data';
          },
        ),
      );

      await kernel.run();

      expect(accessedData, isTrue);
    });
  });

  group('Kernel - Events', () {
    test('should dispatch KernelRunEvent', () async {
      final kernel = Kernel('test');
      final eventLog = <String>[];

      kernel.addBundle(
        TestBundle(
          [],
          [],
          onBuild: (builder) async {
            builder.registerInstance<EventSubscriber>(
              TestEventSubscriber(eventLog),
            );
          },
        ),
      );

      await kernel.run();

      expect(eventLog, contains('KernelRunEvent'));
    });

    test('KernelRunEvent should contain kernel reference', () async {
      final kernel = Kernel('test');
      Kernel? eventKernel;

      kernel.addBundle(
        TestBundle(
          [],
          [],
          onBuild: (builder) async {
            builder.registerInstance<EventSubscriber>(
              _CustomSubscriber((event) => eventKernel = event.kernel),
            );
          },
        ),
      );

      await kernel.run();

      expect(eventKernel, same(kernel));
    });

    test('KernelRunEvent should contain args', () async {
      final kernel = Kernel('test');
      List<String>? eventArgs;

      kernel.addBundle(
        TestBundle(
          [],
          [],
          onBuild: (builder) async {
            builder.registerInstance<EventSubscriber>(
              _CustomSubscriber((event) => eventArgs = event.args),
            );
          },
        ),
      );

      await kernel.run(['test', 'args']);

      expect(eventArgs, equals(['test', 'args']));
    });

    test('should dispatch KernelErrorEvent on runner error', () async {
      final kernel = Kernel('test');
      final eventLog = <String>[];

      kernel.addBundle(
        TestBundle(
          [],
          [],
          onBuild: (builder) async {
            builder.registerInstance<EventSubscriber>(
              TestEventSubscriber(eventLog),
            );
          },
        ),
      );

      kernel.addRunner(ErrorRunner());

      await kernel.run();

      expect(
        eventLog.any((log) => log.contains('KernelErrorEvent')),
        isTrue,
      );
    });

    test('KernelErrorEvent should contain error details', () async {
      final kernel = Kernel('test');
      Object? capturedError;
      StackTrace? capturedStack;

      kernel.addBundle(
        TestBundle(
          [],
          [],
          onBuild: (builder) async {
            builder.registerInstance<EventSubscriber>(
              _ErrorSubscriber((error, stack) {
                capturedError = error;
                capturedStack = stack;
              }),
            );
          },
        ),
      );

      kernel.addRunner(ErrorRunner());

      await kernel.run();

      expect(capturedError, isA<Exception>());
      expect(capturedStack, isNotNull);
    });
  });

  group('Kernel - Error Handling', () {
    test('should throw when run called multiple times', () async {
      final kernel = Kernel('test');

      await kernel.run();

      expect(
        () => kernel.run(),
        throwsA(
          predicate(
            (e) =>
                e is KernelException && e.toString().contains('already booted'),
          ),
        ),
      );
    });

    test('should handle errors in runner gracefully', () async {
      final kernel = Kernel('test');
      final runLog = <String>[];

      kernel.addRunner(ErrorRunner());
      kernel.addRunner(TestRunner(runLog));

      await kernel.run();
      await Future.delayed(Duration(milliseconds: 100));

      // Other runner should still execute
      expect(runLog, contains('TestRunner.run'));
    });

    test('should catch and dispatch errors from runners', () async {
      final kernel = Kernel('test');
      var errorCaught = false;

      kernel.addBundle(
        TestBundle(
          [],
          [],
          onBuild: (builder) async {
            builder.registerInstance<EventSubscriber>(
              _ErrorSubscriber((error, stack) {
                errorCaught = true;
              }),
            );
          },
        ),
      );

      kernel.addRunner(ErrorRunner());

      await kernel.run();

      expect(errorCaught, isTrue);
    });
  });

  group('Kernel - Integration', () {
    test('complete kernel lifecycle should work', () async {
      final kernel = Kernel('test');
      final buildLog = <String>[];
      final bootLog = <String>[];
      final runLog = <String>[];

      kernel.addBundle(TestBundle(buildLog, bootLog));
      kernel.addRunner(TestRunner(runLog));

      await kernel.run();

      expect(buildLog, isNotEmpty);
      expect(bootLog, isNotEmpty);
      expect(runLog, isNotEmpty);
      expect(kernel.injector, isA<Injector>());
    });

    test('bundles can register services used by runners', () async {
      final kernel = Kernel('test');
      var serviceUsed = false;

      kernel.addBundle(
        TestBundle(
          [],
          [],
          onBuild: (builder) async {
            builder.registerInstance<String>('service-data');
          },
        ),
      );

      kernel.addRunner(
        TestRunner(
          [],
          onRun: () async {
            final data = kernel.injector.get<String>();
            serviceUsed = data == 'service-data';
          },
        ),
      );

      await kernel.run();

      expect(serviceUsed, isTrue);
    });

    test('multiple bundles can collaborate', () async {
      final kernel = Kernel('test');

      kernel.addBundle(
        TestBundle(
          [],
          [],
          onBuild: (builder) async {
            builder.registerInstance<String>('value1', name: 'key1');
          },
        ),
      );

      kernel.addBundle(
        TestBundle(
          [],
          [],
          onBuild: (builder) async {
            builder.registerInstance<String>('value2', name: 'key2');
          },
        ),
      );

      await kernel.run();

      expect(kernel.injector.get<String>('key1'), equals('value1'));
      expect(kernel.injector.get<String>('key2'), equals('value2'));
    });

    test('should handle complex application structure', () async {
      final kernel = Kernel('production');

      // Configuration bundle
      kernel.addBundle(
        TestBundle(
          [],
          [],
          onBuild: (builder) async {
            builder.registerInstance<Map<String, dynamic>>(
              {'port': 8080, 'host': 'localhost'},
              name: 'config',
            );
          },
        ),
      );

      // Service bundle
      kernel.addBundle(ServiceBundle());

      // Runner
      final runLog = <String>[];
      kernel.addRunner(TestRunner(runLog));

      await kernel.run(['--debug']);

      expect(kernel.env, equals('production'));
      expect(runLog, contains('TestRunner.run'));
    });
  });
}

// Helper subscribers for testing
class _CustomSubscriber implements EventSubscriber {
  final void Function(KernelRunEvent) onRun;

  _CustomSubscriber(this.onRun);

  @override
  void subscribe(EventBus dispatcher) {
    dispatcher.on<KernelRunEvent>(onRun);
  }
}

class _ErrorSubscriber implements EventSubscriber {
  final void Function(Object, StackTrace) onError;

  _ErrorSubscriber(this.onError);

  @override
  void subscribe(EventBus dispatcher) {
    dispatcher.on<KernelErrorEvent>((event) {
      onError(event.error, event.stackTrace);
    });
  }
}
