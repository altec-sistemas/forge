import 'kernel_exception.dart';

/// Thrown when a service is not found in the dependency container.
///
/// This exception occurs when attempting to resolve a service type
/// that is not registered or has no available implementations.
/// Provides detailed information about the resolution context.
class ServiceNotFoundException extends KernelException {
  /// The type of the service that could not be found.
  final Type serviceType;

  /// The resolution stack at the time of the error (shows which service was trying to resolve which).
  final List<Type> resolutionStack;

  /// The type that was requesting the dependency when the error occurred.
  final Type? requestingType;

  /// Creates a new [ServiceNotFoundException].
  ///
  /// The [serviceType] represents the type of service that failed to resolve.
  /// The [resolutionStack] shows the dependency chain leading up to the error.
  /// The [requestingType] indicates which type was requesting the dependency.
  ServiceNotFoundException(
    this.serviceType, {
    this.resolutionStack = const [],
    this.requestingType,
  }) : super(_buildMessage(serviceType, resolutionStack, requestingType));

  static String _buildMessage(
    Type serviceType,
    List<Type> resolutionStack,
    Type? requestingType,
  ) {
    final buffer = StringBuffer();
    buffer.write('Service of type $serviceType not found in the container');

    if (requestingType != null) {
      buffer.write(' (requested by $requestingType)');
    }

    if (resolutionStack.isNotEmpty) {
      buffer.write('.\n\nResolution stack:\n');
      for (int i = 0; i < resolutionStack.length; i++) {
        final indent = '  ' * (i + 1);
        final arrow = i == resolutionStack.length - 1 ? '└─> ' : '├─> ';
        buffer.write('$indent$arrow${resolutionStack[i]}\n');
      }
      buffer.write(
        '${'  ' * (resolutionStack.length + 1)}└─> $serviceType (NOT FOUND)',
      );
    } else {
      buffer.write('.');
    }

    return buffer.toString();
  }

  @override
  String toString() => 'ServiceNotFoundException: $message';
}

/// Thrown when a circular dependency is detected.
///
/// This exception is raised when two or more services depend on each other
/// in a way that creates an infinite resolution loop.
class CircularDependencyException extends KernelException {
  /// The dependency chain that caused the circular reference.
  final List<Type> dependencyChain;

  /// Creates a new [CircularDependencyException] with the given dependency chain.
  CircularDependencyException(this.dependencyChain)
    : super(_buildMessage(dependencyChain));

  static String _buildMessage(List<Type> chain) {
    if (chain.isEmpty) return 'Circular dependency detected';

    final buffer = StringBuffer();
    buffer.write('Circular dependency detected:\n\n');

    for (int i = 0; i < chain.length; i++) {
      final indent = '  ' * (i + 1);
      final arrow = '├─> ';
      buffer.write('$indent$arrow${chain[i]}\n');
    }

    // Show the cycle returning to the first dependency
    final indent = '  ' * (chain.length + 1);
    buffer.write('$indent└─> ${chain.first} (CIRCULAR!)');

    return buffer.toString();
  }

  @override
  String toString() => 'CircularDependencyException: $message';
}
