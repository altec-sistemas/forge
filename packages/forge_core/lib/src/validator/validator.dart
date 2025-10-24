import '../exception/validation_exception.dart';
import 'message_provider.dart';

/// Represents a validation violation
class Violation {
  final String propertyPath;
  final String message;
  final dynamic value;

  const Violation(this.propertyPath, this.message, [this.value]);

  @override
  String toString() => '$propertyPath: $message';
}

/// Validation context that accumulates violations
class ValidationContext {
  final List<Violation> _violations;
  final String propertyPath;
  final ValidationMessageProvider? messageProvider;

  ValidationContext([
    this.propertyPath = '',
    this.messageProvider,
  ]) : _violations = [];

  ValidationContext._shared(
    this._violations,
    this.propertyPath,
    this.messageProvider,
  );

  /// Adds a violation to the context
  /// If [messageOrKey] exists in the message provider, uses the translated message
  /// Otherwise, uses the [messageOrKey] as is
  void addViolation(
    String key, {
    String? message,
    dynamic value,
    Map<String, dynamic>? params,
  }) {
    if (message != null) {
      _violations.add(Violation(propertyPath, message, value));
      return;
    }

    final provider =
        messageProvider ?? const DefaultValidationMessageProvider();
    _violations.add(
      Violation(propertyPath, provider.getMessage(key, params), value),
    );
  }

  /// Adds a violation with custom path
  void addViolationAt(
    String path,
    String key, {
    String? message,
    dynamic value,
    Map<String, dynamic>? params,
  }) {
    if (message != null) {
      _violations.add(Violation(path, message, value));
      return;
    }

    final provider =
        messageProvider ?? const DefaultValidationMessageProvider();
    _violations.add(Violation(path, provider.getMessage(key, params), value));
  }

  /// Creates a new context for a sub-path (shares the violations list)
  ValidationContext atPath(String path) {
    final newPath = propertyPath.isEmpty ? path : '$propertyPath.$path';
    return ValidationContext._shared(_violations, newPath, messageProvider);
  }

  /// Creates a new context for an array index
  ValidationContext atIndex(int index) {
    return atPath('[$index]');
  }

  List<Violation> get violations => List.unmodifiable(_violations);
  bool get hasViolations => _violations.isNotEmpty;
  bool get isValid => _violations.isEmpty;
}

/// Base interface for constraints
abstract class Constraint {
  const Constraint();

  /// Validates the value within the provided context
  void validate(dynamic value, ValidationContext context);
}

abstract class Validator {
  factory Validator([ValidationMessageProvider? messageProvider]) =>
      _ValidatorImpl(messageProvider);

  /// Validates a value against a constraint
  List<Violation> validate(dynamic data, Constraint constraint);

  /// Validates and throws an exception if there are violations
  void validateOrThrow(dynamic data, Constraint constraint);

  /// Checks if the data is valid
  bool isValid(dynamic data, Constraint constraint);
}

/// Main validator implementation
class _ValidatorImpl implements Validator {
  final ValidationMessageProvider? messageProvider;

  _ValidatorImpl([this.messageProvider]);

  @override
  List<Violation> validate(dynamic data, Constraint constraint) {
    final context = ValidationContext('', messageProvider);
    constraint.validate(data, context);
    return context.violations;
  }

  @override
  void validateOrThrow(dynamic data, Constraint constraint) {
    final violations = validate(data, constraint);
    if (violations.isNotEmpty) {
      throw ValidationException(violations);
    }
  }

  @override
  bool isValid(dynamic data, Constraint constraint) {
    return validate(data, constraint).isEmpty;
  }
}
