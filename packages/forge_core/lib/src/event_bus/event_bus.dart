import 'dart:async';

/// A function that handles events of type [T].
///
/// Can be either synchronous or asynchronous (returning a [Future]).
typedef EventListener<T> = FutureOr<void> Function(T event);

/// Manages event listeners and dispatches events to them.
///
/// The EventBus allows decoupling of components by enabling
/// publish-subscribe patterns. Listeners can subscribe to specific event types
/// and are notified when those events are dispatched.
///
/// ## Execution Models
///
/// The EventBus provides two ways to listen to events:
///
/// 1. **Sequential execution** via [on]: Listeners are executed in priority order,
///    each waiting for the previous one to complete before starting. This ensures
///    predictable execution order and is suitable for business logic that has
///    dependencies between listeners.
///
/// 2. **Parallel execution** via [stream]: Listeners execute independently without
///    waiting for each other. This is ideal for UI updates in Flutter and other
///    reactive scenarios where you don't need guaranteed execution order.
abstract class EventBus {
  /// Creates a new EventBus instance.
  factory EventBus() => _EventBusImpl();

  /// Registers a sequential listener for events of type [T].
  ///
  /// **Sequential Execution Model:**
  /// Listeners registered with [on] are executed sequentially in priority order
  /// when [dispatch] is called. Each listener completes fully before the next
  /// one begins, making the execution order predictable and deterministic.
  ///
  /// **Use cases:**
  /// - Business logic with dependencies between handlers
  /// - Operations that must complete in a specific order
  /// - Backend/server-side event processing
  /// - Critical operations that need guaranteed sequential execution
  ///
  /// **Parameters:**
  /// - [listener]: The function to call when the event is dispatched
  /// - [priority]: Execution priority (higher values execute first, default: 0)
  ///
  /// Example:
  /// ```dart
  /// // These listeners will execute in order: first high priority, then default
  /// eventBus.on<UserCreatedEvent>((event) async {
  ///   await saveToDatabase(event); // Completes first
  /// }, priority: 10);
  ///
  /// eventBus.on<UserCreatedEvent>((event) async {
  ///   await sendWelcomeEmail(event); // Executes after database save
  /// });
  /// ```
  void on<T>(EventListener<T> listener, {int priority = 0});

  /// Registers all listeners from an event subscriber.
  ///
  /// This is a convenience method for bulk registration of related listeners.
  /// The subscriber's [EventSubscriber.subscribe] method will be called
  /// with this EventBus instance.
  void addSubscriber(EventSubscriber subscriber);

  /// Dispatches an event to all registered listeners of its type.
  ///
  /// **Execution behavior:**
  /// - Sequential listeners (registered via [on]) execute in priority order,
  ///   each waiting for the previous to complete
  /// - Stream listeners (from [stream]) receive the event in parallel and
  ///   execute independently without blocking [dispatch]
  ///
  /// Returns a [Future] that completes when all sequential listeners have
  /// finished executing. Stream listeners may still be processing.
  ///
  /// Example:
  /// ```dart
  /// await eventBus.dispatch(UserCreatedEvent('john_doe'));
  /// // All sequential listeners have completed here
  /// // Stream listeners may still be processing
  /// ```
  Future<void> dispatch<T>(T event);

  /// Returns a broadcast stream of events of type [T].
  ///
  /// **Parallel Execution Model:**
  /// Listeners on this stream execute independently and in parallel. They do
  /// NOT wait for each other to complete, and their execution order is not
  /// guaranteed. The stream receives events immediately when [dispatch] is
  /// called, without blocking other listeners.
  ///
  /// **Use cases:**
  /// - UI updates in Flutter (recommended for widgets/state management)
  /// - Reactive programming patterns
  /// - Independent operations that don't depend on each other
  /// - Non-critical side effects like logging or analytics
  /// - Multiple subscribers that should process events independently
  ///
  /// **Flutter recommendation:**
  /// Prefer [stream] over [on] for UI-related listeners in Flutter apps.
  /// This prevents blocking the UI thread and allows widgets to update
  /// independently without waiting for other listeners.
  ///
  /// The stream is broadcast, meaning multiple listeners can subscribe to it
  /// simultaneously, and each will receive all events independently.
  ///
  /// Example:
  /// ```dart
  /// // In Flutter: UI updates happen independently
  /// eventBus.stream<UserCreatedEvent>().listen((event) {
  ///   setState(() => users.add(event.user)); // Updates immediately
  /// });
  ///
  /// eventBus.stream<UserCreatedEvent>().listen((event) {
  ///   showSnackBar('User created!'); // Runs in parallel with above
  /// });
  ///
  /// // Dispatch doesn't wait for these stream listeners
  /// await eventBus.dispatch(UserCreatedEvent('jane_doe'));
  /// print('Dispatched!'); // Prints immediately, UI updates in parallel
  /// ```
  Stream<T> stream<T>();

  /// Closes all stream controllers.
  ///
  /// Should be called when the EventBus is no longer needed to prevent
  /// memory leaks.
  void dispose();
}

/// Defines a component that subscribes to multiple events.
///
/// Event subscribers provide a clean way to organize related event listeners
/// into a single class. This is useful for grouping listeners by feature or domain.
///
/// Example:
/// ```dart
/// class UserEventSubscriber implements EventSubscriber {
///   @override
///   void subscribe(EventBus eventBus) {
///     eventBus.on<UserCreatedEvent>(_onUserCreated);
///     eventBus.on<UserDeletedEvent>(_onUserDeleted);
///   }
///
///   void _onUserCreated(UserCreatedEvent event) { ... }
///   void _onUserDeleted(UserDeletedEvent event) { ... }
/// }
/// ```
abstract class EventSubscriber {
  /// Registers this subscriber's listeners with the given EventBus.
  ///
  /// This method should call [EventBus.on] for each event type
  /// that this subscriber wants to handle.
  void subscribe(EventBus eventBus);
}

/// Internal representation of a registered event listener with its priority.
class _ListenerEntry {
  /// The listener function to be invoked when the event is dispatched.
  final Function listener;

  /// The execution priority (higher values execute first).
  final int priority;

  _ListenerEntry(this.listener, this.priority);
}

/// Default implementation of the EventBus with priority support.
///
/// Manages listeners organized by event type and executes them according
/// to their registration method: sequentially for [on] listeners,
/// in parallel for [stream] listeners.
class _EventBusImpl implements EventBus {
  /// Map of event types to their registered listeners.
  final Map<Type, List<_ListenerEntry>> _listeners = {};

  /// Map of event types to their stream controllers.
  final Map<Type, StreamController<dynamic>> _controllers = {};

  @override
  void on<T>(EventListener<T> listener, {int priority = 0}) {
    _listeners.putIfAbsent(T, () => []);
    _listeners[T]!.add(_ListenerEntry(listener, priority));
    _listeners[T]!.sort((a, b) => b.priority.compareTo(a.priority));
  }

  @override
  void addSubscriber(EventSubscriber subscriber) {
    subscriber.subscribe(this);
  }

  @override
  Future<void> dispatch<T>(T event) async {
    // Execute sequential listeners in priority order
    final listeners = _listeners[T];
    if (listeners != null) {
      for (final entry in listeners) {
        final typedListener = entry.listener as EventListener<T>;
        await typedListener(event);
      }
    }

    // Emit to stream listeners (executes in parallel)
    final controller = _controllers[T];
    if (controller != null && !controller.isClosed) {
      controller.add(event);
    }
  }

  @override
  Stream<T> stream<T>() {
    _controllers.putIfAbsent(T, () => StreamController<T>.broadcast());
    return (_controllers[T] as StreamController<T>).stream;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
    _listeners.clear();
  }
}
