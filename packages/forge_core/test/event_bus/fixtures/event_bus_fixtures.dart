// Test Events
import 'package:forge_core/forge_core.dart';

class UserCreatedEvent {
  final String username;
  final String email;

  UserCreatedEvent(this.username, this.email);
}

class UserUpdatedEvent {
  final String username;
  final Map<String, dynamic> changes;

  UserUpdatedEvent(this.username, this.changes);
}

class UserDeletedEvent {
  final String username;

  UserDeletedEvent(this.username);
}

class OrderPlacedEvent {
  final String orderId;
  final double amount;

  OrderPlacedEvent(this.orderId, this.amount);
}

class PaymentProcessedEvent {
  final String orderId;
  final bool successful;

  PaymentProcessedEvent(this.orderId, this.successful);
}

class GenericEvent {
  final String data;

  GenericEvent(this.data);
}

class ErrorEvent {
  final String message;

  ErrorEvent(this.message);
}

// Test Event Subscribers
class UserEventSubscriber implements EventSubscriber {
  final List<String> log;

  UserEventSubscriber(this.log);

  @override
  void subscribe(EventBus dispatcher) {
    dispatcher.on<UserCreatedEvent>(_onUserCreated, priority: 10);
    dispatcher.on<UserUpdatedEvent>(_onUserUpdated, priority: 5);
    dispatcher.on<UserDeletedEvent>(_onUserDeleted);
  }

  void _onUserCreated(UserCreatedEvent event) {
    log.add('User created: ${event.username}');
  }

  void _onUserUpdated(UserUpdatedEvent event) {
    log.add('User updated: ${event.username}');
  }

  void _onUserDeleted(UserDeletedEvent event) {
    log.add('User deleted: ${event.username}');
  }
}

class OrderEventSubscriber implements EventSubscriber {
  final List<String> log;

  OrderEventSubscriber(this.log);

  @override
  void subscribe(EventBus dispatcher) {
    dispatcher.on<OrderPlacedEvent>(_onOrderPlaced);
    dispatcher.on<PaymentProcessedEvent>(_onPaymentProcessed);
  }

  Future<void> _onOrderPlaced(OrderPlacedEvent event) async {
    await Future.delayed(Duration(milliseconds: 10));
    log.add('Order placed: ${event.orderId}');
  }

  void _onPaymentProcessed(PaymentProcessedEvent event) {
    log.add(
      'Payment ${event.successful ? 'successful' : 'failed'}: ${event.orderId}',
    );
  }
}

class MultiPrioritySubscriber implements EventSubscriber {
  final List<String> log;

  MultiPrioritySubscriber(this.log);

  @override
  void subscribe(EventBus dispatcher) {
    dispatcher.on<GenericEvent>(_highPriority, priority: 100);
    dispatcher.on<GenericEvent>(_mediumPriority, priority: 50);
    dispatcher.on<GenericEvent>(_lowPriority, priority: 1);
    dispatcher.on<GenericEvent>(_noPriority);
  }

  void _highPriority(GenericEvent event) => log.add('high');
  void _mediumPriority(GenericEvent event) => log.add('medium');
  void _lowPriority(GenericEvent event) => log.add('low');
  void _noPriority(GenericEvent event) => log.add('none');
}
