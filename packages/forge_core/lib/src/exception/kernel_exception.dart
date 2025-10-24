/// Base exception for all kernel-related errors.
///
/// Provides detailed information about issues that occur within
/// the kernel's operation, including a descriptive message,
/// an optional underlying exception, and a stack trace for debugging.
class KernelException implements Exception {
  /// The error message describing what went wrong.
  final String message;

  /// The underlying exception that caused this error, if any.
  final Object? previous;

  /// The stack trace captured at the time of the exception.
  final StackTrace? stackTrace;

  /// Creates a new [KernelException].
  ///
  /// The [message] describes the error.
  /// The optional [previous] and [stackTrace] provide additional context.
  KernelException(this.message, [this.previous, this.stackTrace]);

  @override
  String toString() =>
      'KernelException: $message\nPrevious: $previous\nStackTrace: $stackTrace';
}

/// Exception thrown during kernel setup.
///
/// Indicates that an error occurred while setting up the kernel,
/// such as during dependency registration, bundle configuration,
/// or container initialization.
class KernelSetupException extends KernelException {
  /// Creates a new [KernelSetupException].
  ///
  /// The [message] should describe the setup stage that failed.
  /// The optional [previous] and [stackTrace] provide additional context.
  KernelSetupException(super.message, [super.previous, super.stackTrace]);
}
