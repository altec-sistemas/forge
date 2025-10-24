import 'package:forge_flutter/forge_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Test Bundles
class TestBundle extends Bundle {
  final List<String> buildLog;
  final List<String> bootLog;
  final Future<void> Function(InjectorBuilder)? onBuild;
  final Future<void> Function(Injector)? onBoot;

  TestBundle(this.buildLog, this.bootLog, {this.onBuild, this.onBoot});

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
    dispatcher.on<KernelErrorEvent>(_onKernelError);
  }

  void _onKernelError(KernelErrorEvent event) {
    eventLog.add('KernelErrorEvent: ${event.error}');
  }
}

// Test Widgets
class TestApp extends StatelessWidget {
  final String title;

  const TestApp({super.key, this.title = 'Test App'});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      home: Scaffold(body: Center(child: Text(title))),
    );
  }
}

class ErrorWidget extends StatelessWidget {
  const ErrorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    throw Exception('Error in widget build');
  }
}

void main() {
  group('Application - Basic Operations', () {
    testWidgets('should create application', (tester) async {
      final app = Application();
      expect(app, isA<Application>());
    });

    testWidgets('should add bundles', (tester) async {
      final app = Application();
      final buildLog = <String>[];
      final bootLog = <String>[];

      app.addBundle(TestBundle(buildLog, bootLog));
      app.addBundle(TestBundle(buildLog, bootLog));

      expect(
        () async => await app.run((i) => const TestApp()),
        returnsNormally,
      );
    });

    testWidgets('should throw when accessing container before run', (
      tester,
    ) async {
      final app = Application();

      expect(
        () => app.injector,
        throwsA(
          predicate(
            (e) =>
                e is KernelException &&
                e.toString().contains('Kernel is not built yet'),
          ),
        ),
      );
    });

    testWidgets('container should be accessible after run', (tester) async {
      final app = Application();
      await app.run((i) => const TestApp());
      await tester.pumpAndSettle();

      expect(() => app.injector, returnsNormally);
      expect(app.injector, isA<Injector>());
    });

    testWidgets('should register Application instance in container', (
      tester,
    ) async {
      final app = Application();
      await app.run((i) => const TestApp());
      await tester.pumpAndSettle();

      final containerApp = app.injector.get<Application>();
      expect(containerApp, same(app));
    });

    testWidgets('should register BaseKernel instance in container', (
      tester,
    ) async {
      final app = Application();
      await app.run((i) => const TestApp());
      await tester.pumpAndSettle();

      final baseKernel = app.injector.get<BaseKernel>();
      expect(baseKernel, same(app));
    });
  });

  group('Application - Build Phase', () {
    testWidgets('should call build on all bundles', (tester) async {
      final app = Application();
      final buildLog = <String>[];
      final bootLog = <String>[];

      app.addBundle(TestBundle(buildLog, bootLog));
      app.addBundle(TestBundle(buildLog, bootLog));
      app.addBundle(TestBundle(buildLog, bootLog));

      await app.run((i) => const TestApp());
      await tester.pumpAndSettle();

      expect(buildLog.length, equals(3));
    });

    testWidgets('should build bundles in order of registration', (
      tester,
    ) async {
      final app = Application();
      final log = <String>[];

      app.addBundle(
        TestBundle(log, [], onBuild: (b) async => log.add('Bundle1')),
      );
      app.addBundle(
        TestBundle(log, [], onBuild: (b) async => log.add('Bundle2')),
      );
      app.addBundle(
        TestBundle(log, [], onBuild: (b) async => log.add('Bundle3')),
      );

      await app.run((i) => const TestApp());
      await tester.pumpAndSettle();

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

    testWidgets('should provide ContainerBuilder to bundles', (tester) async {
      final app = Application();
      InjectorBuilder? capturedBuilder;

      app.addBundle(
        TestBundle(
          [],
          [],
          onBuild: (builder) async {
            capturedBuilder = builder;
            builder.registerInstance<String>('test-value');
          },
        ),
      );

      await app.run((i) => const TestApp());
      await tester.pumpAndSettle();

      expect(capturedBuilder, isNotNull);
      expect(app.injector.get<String>(), equals('test-value'));
    });

    testWidgets('should register EventBus in container', (tester) async {
      final app = Application();
      await app.run((i) => const TestApp());
      await tester.pumpAndSettle();

      final dispatcher = app.injector.get<EventBus>();
      expect(dispatcher, isA<EventBus>());
    });

    testWidgets('should register Container itself in container', (
      tester,
    ) async {
      final app = Application();
      await app.run((i) => const TestApp());
      await tester.pumpAndSettle();

      final container = app.injector.get<Injector>();
      expect(container, same(app.injector));
    });
  });

  group('Application - Boot Phase', () {
    testWidgets('should call boot on all bundles', (tester) async {
      final app = Application();
      final buildLog = <String>[];
      final bootLog = <String>[];

      app.addBundle(TestBundle(buildLog, bootLog));
      app.addBundle(TestBundle(buildLog, bootLog));
      app.addBundle(TestBundle(buildLog, bootLog));

      await app.run((i) => const TestApp());
      await tester.pumpAndSettle();

      expect(bootLog.length, equals(3));
    });

    testWidgets('should boot bundles in order of registration', (tester) async {
      final app = Application();
      final log = <String>[];

      app.addBundle(
        TestBundle([], log, onBoot: (c) async => log.add('Bundle1')),
      );
      app.addBundle(
        TestBundle([], log, onBoot: (c) async => log.add('Bundle2')),
      );
      app.addBundle(
        TestBundle([], log, onBoot: (c) async => log.add('Bundle3')),
      );

      await app.run((i) => const TestApp());
      await tester.pumpAndSettle();

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

    testWidgets('should provide built container to boot phase', (tester) async {
      final app = Application();
      app.addBundle(ServiceBundle());

      await app.run((i) => const TestApp());
      await tester.pumpAndSettle();

      final service = app.injector.get<TestService>();
      expect(service.isInitialized, isTrue);
    });

    testWidgets('boot should happen after build', (tester) async {
      final app = Application();
      final log = <String>[];

      app.addBundle(TestBundle(log, log));

      await app.run((i) => const TestApp());
      await tester.pumpAndSettle();

      expect(log, equals(['TestBundle.build', 'TestBundle.boot']));
    });

    testWidgets('should register EventSubscribers', (tester) async {
      final app = Application();
      final eventLog = <String>[];

      app.addBundle(
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

      await app.run((i) => const TestApp());
      await tester.pumpAndSettle();

      // KernelErrorEvent não é disparado automaticamente, apenas em caso de erro
      expect(eventLog, isEmpty);
    });
  });

  group('Application - Widget Execution', () {
    testWidgets('should run the provided widget', (tester) async {
      final app = Application();
      await app.run((i) => const TestApp(title: 'My Test App'));
      await tester.pumpAndSettle();

      expect(find.text('My Test App'), findsOneWidget);
    });

    testWidgets('should run MaterialApp correctly', (tester) async {
      final app = Application();
      await app.run(
        (i) => MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Test')),
            body: const Center(child: Text('Content')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test'), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('should handle custom widgets', (tester) async {
      final app = Application();
      await app.run(
        (i) => const MaterialApp(
          home: Scaffold(body: CustomTestWidget(data: 'Custom Data')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom Data'), findsOneWidget);
    });

    testWidgets('widgets can access application services', (tester) async {
      final app = Application();

      app.addBundle(
        TestBundle(
          [],
          [],
          onBuild: (builder) async {
            builder.registerInstance<String>('service-data');
          },
        ),
      );

      await app.run((i) => const MaterialApp(home: ServiceConsumerWidget()));
      await tester.pumpAndSettle();

      expect(find.text('service-data'), findsOneWidget);
    });
  });

  group('Application - Error Handling', () {
    testWidgets('should throw when run called multiple times', (tester) async {
      final app = Application();

      await app.run((i) => const TestApp());
      await tester.pumpAndSettle();

      expect(
        () async => await app.run((i) => const TestApp()),
        throwsA(
          predicate(
            (e) =>
                e is KernelException &&
                e.toString().contains('already running'),
          ),
        ),
      );
    });

    testWidgets('should dispatch KernelErrorEvent on boot error', (
      tester,
    ) async {
      final app = Application();
      final eventLog = <String>[];

      app.addBundle(
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

      app.addBundle(ErrorBundle(errorInBoot: true));

      await app.run((i) => const TestApp());
      await tester.pumpAndSettle();

      expect(eventLog.any((log) => log.contains('KernelErrorEvent')), isTrue);
    });

    testWidgets('should catch errors in boot phase', (tester) async {
      final app = Application();
      var errorCaught = false;

      app.addBundle(
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

      app.addBundle(ErrorBundle(errorInBoot: true));

      await app.run((i) => const TestApp());
      await tester.pumpAndSettle();

      expect(errorCaught, isTrue);
    });

    testWidgets('KernelErrorEvent should contain error details', (
      tester,
    ) async {
      final app = Application();
      Object? capturedError;
      StackTrace? capturedStack;

      app.addBundle(
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

      app.addBundle(ErrorBundle(errorInBoot: true));

      await app.run((i) => const TestApp());
      await tester.pumpAndSettle();

      expect(capturedError, isA<Exception>());
      expect(capturedStack, isNotNull);
    });

    testWidgets('should handle errors in build phase', (tester) async {
      final app = Application();
      var errorCaught = false;

      app.addBundle(
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

      app.addBundle(ErrorBundle(errorInBuild: true));

      try {
        await app.run((i) => const TestApp());
        await tester.pumpAndSettle();
      } catch (e) {
        // Expected to throw during build
      }

      // Build errors throw directly, not through event system
      expect(errorCaught, isFalse);
    });
  });

  group('Application - Integration', () {
    testWidgets('complete application lifecycle should work', (tester) async {
      final app = Application();
      final buildLog = <String>[];
      final bootLog = <String>[];

      app.addBundle(TestBundle(buildLog, bootLog));

      await app.run((i) => const TestApp(title: 'Integration Test'));
      await tester.pumpAndSettle();

      expect(buildLog, isNotEmpty);
      expect(bootLog, isNotEmpty);
      expect(app.injector, isA<Injector>());
      expect(find.text('Integration Test'), findsOneWidget);
    });

    testWidgets('bundles can register services used by widgets', (
      tester,
    ) async {
      final app = Application();

      app.addBundle(
        TestBundle(
          [],
          [],
          onBuild: (builder) async {
            builder.registerInstance<String>('widget-data');
          },
        ),
      );

      await app.run((i) => const MaterialApp(home: ServiceConsumerWidget()));
      await tester.pumpAndSettle();

      expect(find.text('widget-data'), findsOneWidget);
    });

    testWidgets('multiple bundles can collaborate', (tester) async {
      final app = Application();

      app.addBundle(
        TestBundle(
          [],
          [],
          onBuild: (builder) async {
            builder.registerInstance<String>('value1', name: 'key1');
          },
        ),
      );

      app.addBundle(
        TestBundle(
          [],
          [],
          onBuild: (builder) async {
            builder.registerInstance<String>('value2', name: 'key2');
          },
        ),
      );

      await app.run((i) => const TestApp());
      await tester.pumpAndSettle();

      expect(app.injector.get<String>('key1'), equals('value1'));
      expect(app.injector.get<String>('key2'), equals('value2'));
    });

    testWidgets('should handle complex application structure', (tester) async {
      final app = Application();

      // Configuration bundle
      app.addBundle(
        TestBundle(
          [],
          [],
          onBuild: (builder) async {
            builder.registerInstance<Map<String, dynamic>>({
              'theme': 'dark',
              'locale': 'en_US',
            }, name: 'config');
          },
        ),
      );

      // Service bundle
      app.addBundle(ServiceBundle());

      await app.run((i) => const TestApp(title: 'Complex App'));
      await tester.pumpAndSettle();

      expect(app.injector.get<TestService>().isInitialized, isTrue);
      expect(find.text('Complex App'), findsOneWidget);

      final config = app.injector.get<Map<String, dynamic>>('config');
      expect(config['theme'], equals('dark'));
    });

    testWidgets('should work with stateful widgets', (tester) async {
      final app = Application();

      app.addBundle(
        TestBundle(
          [],
          [],
          onBuild: (builder) async {
            builder.registerInstance<String>('initial-state');
          },
        ),
      );

      await app.run((i) => const MaterialApp(home: StatefulTestWidget()));
      await tester.pumpAndSettle();

      expect(find.text('initial-state'), findsOneWidget);

      // Tap to change state
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('changed-state'), findsOneWidget);
    });
  });

  group('Application - State Management', () {
    testWidgets('should maintain state across rebuilds', (tester) async {
      final app = Application();

      app.addBundle(
        TestBundle(
          [],
          [],
          onBuild: (builder) async {
            builder.registerInstance<String>('some');
            builder.registerInstance<TestService>(TestService());
          },
        ),
      );

      await app.run((i) => const MaterialApp(home: ServiceConsumerWidget()));

      await tester.pumpAndSettle();

      final service1 = app.injector.get<TestService>();

      // Rebuild
      await tester.pump();

      final service2 = app.injector.get<TestService>();
      expect(service1, same(service2));
    });

    testWidgets('container should remain accessible after boot', (
      tester,
    ) async {
      final app = Application();
      await app.run((i) => const TestApp());
      await tester.pumpAndSettle();

      // Access multiple times
      expect(() => app.injector.get<EventBus>(), returnsNormally);
      expect(() => app.injector.get<Application>(), returnsNormally);
      expect(() => app.injector.get<Injector>(), returnsNormally);
    });
  });
}

// Helper widgets for testing
class CustomTestWidget extends StatelessWidget {
  final String data;

  const CustomTestWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(data));
  }
}

class ServiceConsumerWidget extends StatelessWidget {
  const ServiceConsumerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final data = injector.get<String>();
    return Scaffold(body: Center(child: Text(data)));
  }
}

class StatefulTestWidget extends StatefulWidget {
  const StatefulTestWidget({super.key});

  @override
  State<StatefulTestWidget> createState() => _StatefulTestWidgetState();
}

class _StatefulTestWidgetState extends State<StatefulTestWidget> {
  late String data;

  @override
  void initState() {
    super.initState();
    data = injector.get<String>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(data),
            ElevatedButton(
              onPressed: () => setState(() => data = 'changed-state'),
              child: const Text('Change State'),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper subscribers for testing
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
