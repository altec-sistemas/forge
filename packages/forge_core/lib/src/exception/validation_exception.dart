import '../validator/validator.dart';

/// Thrown when validation fails due to one or more violations.
///
/// Contains a list of [Violation] objects describing each failed rule.
/// Use [byField] to access violations grouped by their property path.
class ValidationException implements Exception {
  /// The list of validation rule violations.
  final List<Violation> violations;

  /// Creates a new [ValidationException] with the given [violations].
  const ValidationException(this.violations);

  @override
  String toString() {
    if (violations.isEmpty) return 'ValidationException: No violations';
    return 'ValidationException:\n${violations.map((v) => '  - $v').join('\n')}';
  }

  /// Returns all violations grouped by their field name.
  ///
  /// The returned map uses the property path as the key and a list of
  /// corresponding error messages as the value.
  Map<String, List<String>> get byField {
    final map = <String, List<String>>{};
    for (final v in violations) {
      map.putIfAbsent(v.propertyPath, () => []).add(v.message);
    }
    return map;
  }
}
