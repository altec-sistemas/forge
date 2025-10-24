/// Exception thrown when an argument cannot be resolved.
class ArgumentResolutionException implements Exception {
  final String message;
  final String? argumentName;

  ArgumentResolutionException(
    this.message, {
    this.argumentName,
  });

  @override
  String toString() {
    final buffer = StringBuffer('ArgumentResolutionException: $message');

    if (argumentName != null) {
      buffer.write(' (argument: $argumentName)');
    }

    return buffer.toString();
  }
}
