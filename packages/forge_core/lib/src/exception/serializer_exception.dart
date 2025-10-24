/// Exception thrown when serialization or deserialization fails.
///
/// This exception is used to indicate errors during the serialization
/// process, such as missing transformers, invalid data, or unsupported
/// operations.
class SerializerException implements Exception {
  /// A description of what went wrong.
  final String message;

  /// Creates a serializer exception with the given error [message].
  SerializerException(this.message);

  @override
  String toString() => 'SerializerException: $message';
}
