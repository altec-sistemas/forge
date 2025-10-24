import '../../forge_core.dart';

/// Extracts constraints based on class metadata.
class ConstraintExtractor {
  final MetadataRegistry _registry;

  ConstraintExtractor(this._registry);

  /// Extracts a constraint to validate type [T].
  ///
  /// Returns `null` if the type is not mapped in the registry.
  Constraint? extractConstraint<T>() {
    if (!_registry.hasClassMetadata<T>()) {
      return null;
    }

    final classMetadata = _registry.getClassMetadata<T>();
    return _buildConstraintFromClass(classMetadata);
  }

  /// Extracts a constraint to validate a dynamic type.
  Constraint? extractConstraintForType(Type type) {
    if (!_registry.hasClassMetadata(type)) {
      return null;
    }

    final classMetadata = _registry.getClassMetadata(type);
    return _buildConstraintFromClass(classMetadata);
  }

  /// Builds a Collection constraint based on the class getters.
  Constraint _buildConstraintFromClass(ClassMetadata classMetadata) {
    if (!classMetadata.hasMappedGetters) {
      return Collection({});
    }

    final fields = <String, Constraint>{};

    for (final getter in classMetadata.getters!) {
      final fieldConstraint = _buildConstraintForGetter(getter);
      if (fieldConstraint != null) {
        fields[getter.name] = fieldConstraint;
      }
    }

    return Collection(
      fields,
      allowExtraFields: false,
      allowMissingFields: false,
    );
  }

  /// Builds a constraint for a specific getter.
  Constraint? _buildConstraintForGetter(GetterMetadata getter) {
    final constraints = <Constraint>[];

    final typeConstraint = _getPrimitiveTypeConstraint(getter.typeMetadata);
    if (typeConstraint != null) {
      constraints.add(typeConstraint);
    }

    final annotationConstraints = _extractConstraintsFromAnnotations(getter);
    constraints.addAll(annotationConstraints);

    if (constraints.isEmpty) {
      return null;
    }

    final combinedConstraint = constraints.length == 1
        ? constraints.first
        : All(constraints);

    if (_isNullableGetter(getter)) {
      return Optional(combinedConstraint);
    }

    return combinedConstraint;
  }

  /// Returns a validation constraint for primitive types.
  Constraint? _getPrimitiveTypeConstraint(TypeMetadata typeMetadata) {
    final type = typeMetadata.type;

    if (type == String) return const IsString();
    if (type == int) return const IsInt();
    if (type == double) return const IsDouble();
    if (type == num) return const IsNum();
    if (type == bool) return const IsBool();

    if (type == List || _isListType(type)) {
      return const IsList();
    }

    return null;
  }

  /// Checks if the type is a [List<T>].
  bool _isListType(Type type) {
    final typeString = type.toString();
    return typeString.startsWith('List<') || typeString == 'List';
  }

  /// Extracts all Constraint annotations from a getter.
  List<Constraint> _extractConstraintsFromAnnotations(GetterMetadata getter) {
    final constraints = <Constraint>[];

    for (final annotation in getter.annotations) {
      if (annotation is Constraint) {
        constraints.add(annotation);
      }
    }

    return constraints;
  }

  bool _isNullableGetter(GetterMetadata getter) {
    return getter.typeMetadata.nullable;
  }
}
