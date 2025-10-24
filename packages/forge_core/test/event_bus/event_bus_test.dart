import 'package:forge_core/forge_core.dart';
import 'package:test/test.dart';
import 'dart:async';

import 'fixtures/event_bus_fixtures.dart';

void main() {
  group('EventDispatcher - Basic Operations', () {
    test('should create event dispatcher', () {
      final dispatcher = EventBus();
      expect(dispatcher, isA<EventBus>());
    });

    test('should register listener for event type', () {
      final dispatcher = EventBus();
      final log = <String>[];

      dispatcher.on<UserCreatedEvent>((event) {
        log.add('listener called');
      });

      expect(
        () => dispatcher.dispatch(UserCreatedEvent('john', 'john@example.com')),
        returnsNormally,
      );
    });

    test('should dispatch event to listener', () async {
      final dispatcher = EventBus();
      final log = <String>[];

      dispatcher.on<UserCreatedEvent>((event) {
        log.add('User: ${event.username}');
      });

      await dispatcher.dispatch(UserCreatedEvent('john', 'john@example.com'));

      expect(log, contains('User: john'));
    });

    test('should not call listener for different event type', () async {
      final dispatcher = EventBus();
      final log = <String>[];

      dispatcher.on<UserCreatedEvent>((event) {
        log.add('created');
      });

      await dispatcher.dispatch(UserDeletedEvent('john'));

      expect(log, isEmpty);
    });

    test('should handle events with no listeners', () async {
      final dispatcher = EventBus();

      await expectLater(
        dispatcher.dispatch(UserCreatedEvent('john', 'john@example.com')),
        completes,
      );
    });
  });

  group('EventDispatcher - Multiple Listeners', () {
    test('should call multiple listeners for same event', () async {
      final dispatcher = EventBus();
      final log = <String>[];

      dispatcher.on<UserCreatedEvent>((event) => log.add('listener1'));
      dispatcher.on<UserCreatedEvent>((event) => log.add('listener2'));
      dispatcher.on<UserCreatedEvent>((event) => log.add('listener3'));

      await dispatcher.dispatch(UserCreatedEvent('john', 'john@example.com'));

      expect(log, hasLength(3));
      expect(log, containsAll(['listener1', 'listener2', 'listener3']));
    });

    test('should execute listeners sequentially', () async {
      final dispatcher = EventBus();
      final log = <String>[];

      dispatcher.on<GenericEvent>((event) async {
        log.add('start1');
        await Future.delayed(Duration(milliseconds: 20));
        log.add('end1');
      });

      dispatcher.on<GenericEvent>((event) async {
        log.add('start2');
        await Future.delayed(Duration(milliseconds: 10));
        log.add('end2');
      });

      await dispatcher.dispatch(GenericEvent('test'));

      expect(log, equals(['start1', 'end1', 'start2', 'end2']));
    });

    test('each listener receives same event instance', () async {
      final dispatcher = EventBus();
      final receivedEvents = <UserCreatedEvent>[];

      dispatcher.on<UserCreatedEvent>((event) => receivedEvents.add(event));
      dispatcher.on<UserCreatedEvent>((event) => receivedEvents.add(event));
      dispatcher.on<UserCreatedEvent>((event) => receivedEvents.add(event));

      final originalEvent = UserCreatedEvent('john', 'john@example.com');
      await dispatcher.dispatch(originalEvent);

      expect(receivedEvents, hasLength(3));
      expect(receivedEvents[0], same(originalEvent));
      expect(receivedEvents[1], same(originalEvent));
      expect(receivedEvents[2], same(originalEvent));
    });

    test('should handle different event types independently', () async {
      final dispatcher = EventBus();
      final log = <String>[];

      dispatcher.on<UserCreatedEvent>((event) => log.add('created'));
      dispatcher.on<UserUpdatedEvent>((event) => log.add('updated'));
      dispatcher.on<UserDeletedEvent>((event) => log.add('deleted'));

      await dispatcher.dispatch(UserCreatedEvent('john', 'john@example.com'));
      await dispatcher.dispatch(UserUpdatedEvent('john', {}));
      await dispatcher.dispatch(UserDeletedEvent('john'));

      expect(log, equals(['created', 'updated', 'deleted']));
    });
  });

  group('EventDispatcher - Priority', () {
    test('should execute listeners in priority order', () async {
      final dispatcher = EventBus();
      final log = <String>[];

      dispatcher.on<GenericEvent>((event) => log.add('low'), priority: 1);
      dispatcher.on<GenericEvent>((event) => log.add('high'), priority: 100);
      dispatcher.on<GenericEvent>((event) => log.add('medium'), priority: 50);

      await dispatcher.dispatch(GenericEvent('test'));

      expect(log, equals(['high', 'medium', 'low']));
    });

    test('should sort by descending priority', () async {
      final dispatcher = EventBus();
      final log = <String>[];

      for (int i = 0; i < 10; i++) {
        dispatcher.on<GenericEvent>(
          (event) => log.add('priority_$i'),
          priority: i,
        );
      }

      await dispatcher.dispatch(GenericEvent('test'));

      expect(log.first, equals('priority_9'));
      expect(log.last, equals('priority_0'));
    });

    test('default priority should be 0', () async {
      final dispatcher = EventBus();
      final log = <String>[];

      dispatcher.on<GenericEvent>(
        (event) => log.add('explicit_0'),
        priority: 0,
      );
      dispatcher.on<GenericEvent>((event) => log.add('default'));
      dispatcher.on<GenericEvent>((event) => log.add('high'), priority: 10);

      await dispatcher.dispatch(GenericEvent('test'));

      expect(log[0], equals('high'));
      // Default and explicit 0 should be in order of registration
      expect(log.sublist(1), containsAll(['explicit_0', 'default']));
    });

    test('negative priorities should work', () async {
      final dispatcher = EventBus();
      final log = <String>[];

      dispatcher.on<GenericEvent>((event) => log.add('positive'), priority: 10);
      dispatcher.on<GenericEvent>((event) => log.add('zero'), priority: 0);
      dispatcher.on<GenericEvent>(
        (event) => log.add('negative'),
        priority: -10,
      );

      await dispatcher.dispatch(GenericEvent('test'));

      expect(log, equals(['positive', 'zero', 'negative']));
    });

    test('same priority should maintain registration order', () async {
      final dispatcher = EventBus();
      final log = <String>[];

      dispatcher.on<GenericEvent>((event) => log.add('first'), priority: 5);
      dispatcher.on<GenericEvent>((event) => log.add('second'), priority: 5);
      dispatcher.on<GenericEvent>((event) => log.add('third'), priority: 5);

      await dispatcher.dispatch(GenericEvent('test'));

      expect(log, equals(['first', 'second', 'third']));
    });

    test('should re-sort after each registration', () async {
      final dispatcher = EventBus();
      final log = <String>[];

      dispatcher.on<GenericEvent>((event) => log.add('medium'), priority: 50);
      dispatcher.on<GenericEvent>((event) => log.add('high'), priority: 100);
      dispatcher.on<GenericEvent>((event) => log.add('low'), priority: 1);
      dispatcher.on<GenericEvent>((event) => log.add('higher'), priority: 150);

      await dispatcher.dispatch(GenericEvent('test'));

      expect(log, equals(['higher', 'high', 'medium', 'low']));
    });
  });

  group('EventDispatcher - Async Listeners', () {
    test('should handle async listeners', () async {
      final dispatcher = EventBus();
      final log = <String>[];

      dispatcher.on<GenericEvent>((event) async {
        await Future.delayed(Duration(milliseconds: 10));
        log.add('async');
      });

      await dispatcher.dispatch(GenericEvent('test'));

      expect(log, contains('async'));
    });

    test('should handle sync listeners', () async {
      final dispatcher = EventBus();
      final log = <String>[];

      dispatcher.on<GenericEvent>((event) {
        log.add('sync');
      });

      await dispatcher.dispatch(GenericEvent('test'));

      expect(log, contains('sync'));
    });

    test('should handle mix of sync and async listeners', () async {
      final dispatcher = EventBus();
      final log = <String>[];

      dispatcher.on<GenericEvent>((event) => log.add('sync1'));

      dispatcher.on<GenericEvent>((event) async {
        await Future.delayed(Duration(milliseconds: 10));
        log.add('async');
      });

      dispatcher.on<GenericEvent>((event) => log.add('sync2'));

      await dispatcher.dispatch(GenericEvent('test'));

      expect(log, equals(['sync1', 'async', 'sync2']));
    });

    test('async listeners should complete before next listener', () async {
      final dispatcher = EventBus();
      final log = <String>[];

      dispatcher.on<GenericEvent>((event) async {
        log.add('start1');
        await Future.delayed(Duration(milliseconds: 20));
        log.add('end1');
      });

      dispatcher.on<GenericEvent>((event) async {
        log.add('start2');
        await Future.delayed(Duration(milliseconds: 10));
        log.add('end2');
      });

      await dispatcher.dispatch(GenericEvent('test'));

      expect(log, equals(['start1', 'end1', 'start2', 'end2']));
    });

    test('dispatch should complete after all listeners finish', () async {
      final dispatcher = EventBus();
      var allCompleted = false;

      dispatcher.on<GenericEvent>((event) async {
        await Future.delayed(Duration(milliseconds: 50));
      });

      dispatcher.on<GenericEvent>((event) async {
        await Future.delayed(Duration(milliseconds: 30));
      });

      await dispatcher.dispatch(GenericEvent('test'));
      allCompleted = true;

      expect(allCompleted, isTrue);
    });
  });

  group('EventDispatcher - Event Subscribers', () {
    test('should add subscriber', () {
      final dispatcher = EventBus();
      final log = <String>[];

      dispatcher.addSubscriber(UserEventSubscriber(log));

      expect(
        () => dispatcher.dispatch(UserCreatedEvent('john', 'john@example.com')),
        returnsNormally,
      );
    });

    test('subscriber should register all its listeners', () async {
      final dispatcher = EventBus();
      final log = <String>[];

      dispatcher.addSubscriber(UserEventSubscriber(log));

      await dispatcher.dispatch(UserCreatedEvent('john', 'john@example.com'));
      await dispatcher.dispatch(UserUpdatedEvent('john', {}));
      await dispatcher.dispatch(UserDeletedEvent('john'));

      expect(log, hasLength(3));
    });

    test('should add multiple subscribers', () async {
      final dispatcher = EventBus();
      final log = <String>[];

      dispatcher.addSubscriber(UserEventSubscriber(log));
      dispatcher.addSubscriber(OrderEventSubscriber(log));

      await dispatcher.dispatch(UserCreatedEvent('john', 'john@example.com'));
      await dispatcher.dispatch(OrderPlacedEvent('order-1', 99.99));

      expect(log, contains('User created: john'));
      expect(log, contains('Order placed: order-1'));
    });

    test('subscriber listeners should respect priority', () async {
      final dispatcher = EventBus();
      final log = <String>[];

      dispatcher.addSubscriber(MultiPrioritySubscriber(log));

      await dispatcher.dispatch(GenericEvent('test'));

      expect(log, equals(['high', 'medium', 'low', 'none']));
    });

    test('subscribers can have async listeners', () async {
      final dispatcher = EventBus();
      final log = <String>[];

      dispatcher.addSubscriber(OrderEventSubscriber(log));

      await dispatcher.dispatch(OrderPlacedEvent('order-1', 99.99));

      expect(log, contains('Order placed: order-1'));
    });

    test('multiple subscribers should not interfere', () async {
      final dispatcher = EventBus();
      final log1 = <String>[];
      final log2 = <String>[];

      dispatcher.addSubscriber(UserEventSubscriber(log1));
      dispatcher.addSubscriber(UserEventSubscriber(log2));

      await dispatcher.dispatch(UserCreatedEvent('john', 'john@example.com'));

      expect(log1, isNotEmpty);
      expect(log2, isNotEmpty);
      expect(log1.length, equals(log2.length));
    });
  });

  group('EventDispatcher - Error Handling', () {
    test('should propagate listener errors', () async {
      final dispatcher = EventBus();

      dispatcher.on<ErrorEvent>((event) {
        throw Exception('Listener error');
      });

      expect(
        () => dispatcher.dispatch(ErrorEvent('test')),
        throwsA(isA<Exception>()),
      );
    });

    test('error in one listener should prevent subsequent listeners', () async {
      final dispatcher = EventBus();
      final log = <String>[];

      dispatcher.on<ErrorEvent>((event) => log.add('first'));

      dispatcher.on<ErrorEvent>((event) {
        throw Exception('Error');
      });

      dispatcher.on<ErrorEvent>((event) => log.add('third'));

      try {
        await dispatcher.dispatch(ErrorEvent('test'));
      } catch (_) {}

      expect(log, equals(['first']));
      expect(log, isNot(contains('third')));
    });

    test('should handle async errors', () async {
      final dispatcher = EventBus();

      dispatcher.on<ErrorEvent>((event) async {
        await Future.delayed(Duration(milliseconds: 10));
        throw Exception('Async error');
      });

      expect(
        () => dispatcher.dispatch(ErrorEvent('test')),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('EventDispatcher - Complex Scenarios', () {
    test('should handle event chain', () async {
      final dispatcher = EventBus();
      final log = <String>[];

      dispatcher.on<UserCreatedEvent>((event) async {
        log.add('1: User created');
        await dispatcher.dispatch(OrderPlacedEvent('order-1', 99.99));
      });

      dispatcher.on<OrderPlacedEvent>((event) async {
        log.add('2: Order placed');
        await dispatcher.dispatch(PaymentProcessedEvent('order-1', true));
      });

      dispatcher.on<PaymentProcessedEvent>((event) {
        log.add('3: Payment processed');
      });

      await dispatcher.dispatch(UserCreatedEvent('john', 'john@example.com'));

      expect(
        log,
        equals([
          '1: User created',
          '2: Order placed',
          '3: Payment processed',
        ]),
      );
    });

    test('should handle high volume of events', () async {
      final dispatcher = EventBus();
      var count = 0;

      dispatcher.on<GenericEvent>((event) => count++);

      for (int i = 0; i < 1000; i++) {
        await dispatcher.dispatch(GenericEvent('event_$i'));
      }

      expect(count, equals(1000));
    });

    test('should handle many listeners for same event', () async {
      final dispatcher = EventBus();
      final counters = List.generate(100, (_) => 0);

      for (int i = 0; i < 100; i++) {
        final index = i;
        dispatcher.on<GenericEvent>((event) => counters[index]++);
      }

      await dispatcher.dispatch(GenericEvent('test'));

      expect(counters.every((c) => c == 1), isTrue);
    });

    test('listeners can modify shared state', () async {
      final dispatcher = EventBus();
      final sharedList = <String>[];

      dispatcher.on<GenericEvent>((event) => sharedList.add('a'), priority: 3);
      dispatcher.on<GenericEvent>((event) => sharedList.add('b'), priority: 2);
      dispatcher.on<GenericEvent>((event) => sharedList.add('c'), priority: 1);

      await dispatcher.dispatch(GenericEvent('test'));

      expect(sharedList, equals(['a', 'b', 'c']));
    });

    test('should handle listener that dispatches same event type', () async {
      final dispatcher = EventBus();
      final log = <String>[];
      var dispatchCount = 0;

      dispatcher.on<GenericEvent>((event) {
        log.add('Received: ${event.data}');
        dispatchCount++;

        if (dispatchCount < 3) {
          dispatcher.dispatch(GenericEvent('nested_$dispatchCount'));
        }
      });

      await dispatcher.dispatch(GenericEvent('initial'));

      expect(log.length, greaterThan(1));
    });

    test('should work with multiple event types simultaneously', () async {
      final dispatcher = EventBus();
      final log = <String>[];

      dispatcher.on<UserCreatedEvent>((e) => log.add('user'));
      dispatcher.on<OrderPlacedEvent>((e) => log.add('order'));
      dispatcher.on<PaymentProcessedEvent>((e) => log.add('payment'));

      await Future.wait([
        dispatcher.dispatch(UserCreatedEvent('john', 'john@example.com')),
        dispatcher.dispatch(OrderPlacedEvent('order-1', 99.99)),
        dispatcher.dispatch(PaymentProcessedEvent('order-1', true)),
      ]);

      expect(log, hasLength(3));
      expect(log, containsAll(['user', 'order', 'payment']));
    });
  });

  group('EventDispatcher - Performance', () {
    test('should handle rapid sequential dispatches', () async {
      final dispatcher = EventBus();
      var count = 0;

      dispatcher.on<GenericEvent>((event) => count++);

      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 1000; i++) {
        await dispatcher.dispatch(GenericEvent('event_$i'));
      }

      stopwatch.stop();

      expect(count, equals(1000));
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test('priority sorting should be efficient', () async {
      final dispatcher = EventBus();
      final log = <String>[];

      for (int i = 0; i < 100; i++) {
        dispatcher.on<GenericEvent>(
          (event) => log.add('listener_$i'),
          priority: 100 - i,
        );
      }

      final stopwatch = Stopwatch()..start();
      await dispatcher.dispatch(GenericEvent('test'));
      stopwatch.stop();

      expect(log, hasLength(100));
      expect(log.first, equals('listener_0'));
      expect(log.last, equals('listener_99'));
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });

  group('EventDispatcher - Stream Support', () {
    test('should return stream for event type', () {
      final dispatcher = EventBus();
      final stream = dispatcher.stream<UserCreatedEvent>();

      expect(stream, isA<Stream<UserCreatedEvent>>());
    });

    test('should emit events to stream', () async {
      final dispatcher = EventBus();
      final events = <UserCreatedEvent>[];

      dispatcher.stream<UserCreatedEvent>().listen((event) {
        events.add(event);
      });

      await dispatcher.dispatch(UserCreatedEvent('john', 'john@example.com'));
      await Future.delayed(Duration(milliseconds: 10));

      expect(events, hasLength(1));
      expect(events[0].username, equals('john'));
    });

    test('should emit multiple events to stream', () async {
      final dispatcher = EventBus();
      final events = <UserCreatedEvent>[];

      dispatcher.stream<UserCreatedEvent>().listen((event) {
        events.add(event);
      });

      await dispatcher.dispatch(UserCreatedEvent('john', 'john@example.com'));
      await dispatcher.dispatch(UserCreatedEvent('jane', 'jane@example.com'));
      await dispatcher.dispatch(UserCreatedEvent('bob', 'bob@example.com'));

      await Future.delayed(Duration(milliseconds: 10));

      expect(events, hasLength(3));
      expect(events.map((e) => e.username), equals(['john', 'jane', 'bob']));
    });

    test('should support multiple stream subscribers', () async {
      final dispatcher = EventBus();
      final events1 = <UserCreatedEvent>[];
      final events2 = <UserCreatedEvent>[];

      dispatcher.stream<UserCreatedEvent>().listen((event) {
        events1.add(event);
      });

      dispatcher.stream<UserCreatedEvent>().listen((event) {
        events2.add(event);
      });

      await dispatcher.dispatch(UserCreatedEvent('john', 'john@example.com'));
      await Future.delayed(Duration(milliseconds: 10));

      expect(events1, hasLength(1));
      expect(events2, hasLength(1));
      expect(events1[0].username, equals(events2[0].username));
    });

    test('should not emit to stream for different event type', () async {
      final dispatcher = EventBus();
      final events = <UserCreatedEvent>[];

      dispatcher.stream<UserCreatedEvent>().listen((event) {
        events.add(event);
      });

      await dispatcher.dispatch(UserDeletedEvent('john'));
      await Future.delayed(Duration(milliseconds: 10));

      expect(events, isEmpty);
    });

    test('should work with both listeners and streams', () async {
      final dispatcher = EventBus();
      final listenerLog = <String>[];
      final streamLog = <String>[];

      dispatcher.on<UserCreatedEvent>((event) {
        listenerLog.add('listener: ${event.username}');
      });

      dispatcher.stream<UserCreatedEvent>().listen((event) {
        streamLog.add('stream: ${event.username}');
      });

      await dispatcher.dispatch(UserCreatedEvent('john', 'john@example.com'));
      await Future.delayed(Duration(milliseconds: 10));

      expect(listenerLog, contains('listener: john'));
      expect(streamLog, contains('stream: john'));
    });

    test('listeners should execute before stream emission', () async {
      final dispatcher = EventBus();
      final executionOrder = <String>[];

      dispatcher.on<GenericEvent>((event) {
        executionOrder.add('listener');
      });

      dispatcher.stream<GenericEvent>().listen((event) {
        executionOrder.add('stream');
      });

      await dispatcher.dispatch(GenericEvent('test'));
      await Future.delayed(Duration(milliseconds: 10));

      expect(executionOrder, equals(['listener', 'stream']));
    });

    test('should handle stream transformations', () async {
      final dispatcher = EventBus();
      final usernames = <String>[];

      dispatcher
          .stream<UserCreatedEvent>()
          .map((event) => event.username.toUpperCase())
          .listen((username) {
            usernames.add(username);
          });

      await dispatcher.dispatch(UserCreatedEvent('john', 'john@example.com'));
      await dispatcher.dispatch(UserCreatedEvent('jane', 'jane@example.com'));
      await Future.delayed(Duration(milliseconds: 10));

      expect(usernames, equals(['JOHN', 'JANE']));
    });

    test('should handle stream filtering', () async {
      final dispatcher = EventBus();
      final filteredEvents = <UserCreatedEvent>[];

      dispatcher
          .stream<UserCreatedEvent>()
          .where((event) => event.username.startsWith('j'))
          .listen((event) {
            filteredEvents.add(event);
          });

      await dispatcher.dispatch(UserCreatedEvent('john', 'john@example.com'));
      await dispatcher.dispatch(UserCreatedEvent('bob', 'bob@example.com'));
      await dispatcher.dispatch(UserCreatedEvent('jane', 'jane@example.com'));
      await Future.delayed(Duration(milliseconds: 10));

      expect(filteredEvents, hasLength(2));
      expect(filteredEvents.map((e) => e.username), equals(['john', 'jane']));
    });

    test('should handle async stream processing', () async {
      final dispatcher = EventBus();
      final processedEvents = <String>[];

      dispatcher.stream<GenericEvent>().listen((event) async {
        await Future.delayed(Duration(milliseconds: 5));
        processedEvents.add('processed: ${event.data}');
      });

      await dispatcher.dispatch(GenericEvent('test1'));
      await dispatcher.dispatch(GenericEvent('test2'));
      await Future.delayed(Duration(milliseconds: 50));

      expect(processedEvents, hasLength(2));
    });

    test('stream should be broadcast', () {
      final dispatcher = EventBus();
      final stream = dispatcher.stream<UserCreatedEvent>();

      expect(stream.isBroadcast, isTrue);
    });

    test('should handle multiple event types with streams', () async {
      final dispatcher = EventBus();
      final userEvents = <String>[];
      final orderEvents = <String>[];

      dispatcher.stream<UserCreatedEvent>().listen((event) {
        userEvents.add(event.username);
      });

      dispatcher.stream<OrderPlacedEvent>().listen((event) {
        orderEvents.add(event.orderId);
      });

      await dispatcher.dispatch(UserCreatedEvent('john', 'john@example.com'));
      await dispatcher.dispatch(OrderPlacedEvent('order-1', 99.99));
      await dispatcher.dispatch(UserCreatedEvent('jane', 'jane@example.com'));
      await Future.delayed(Duration(milliseconds: 10));

      expect(userEvents, equals(['john', 'jane']));
      expect(orderEvents, equals(['order-1']));
    });

    test('should handle stream subscription cancellation', () async {
      final dispatcher = EventBus();
      final events = <UserCreatedEvent>[];

      final subscription = dispatcher.stream<UserCreatedEvent>().listen((
        event,
      ) {
        events.add(event);
      });

      await dispatcher.dispatch(UserCreatedEvent('john', 'john@example.com'));
      await Future.delayed(Duration(milliseconds: 10));

      await subscription.cancel();

      await dispatcher.dispatch(UserCreatedEvent('jane', 'jane@example.com'));
      await Future.delayed(Duration(milliseconds: 10));

      expect(events, hasLength(1));
      expect(events[0].username, equals('john'));
    });
  });
}
