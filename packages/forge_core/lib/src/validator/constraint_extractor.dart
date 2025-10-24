import '../../forge_core.dart';

/// Extrai constraints baseadas em metadados de classe
class ConstraintExtractor {
  final MetadataRegistry _registry;

  ConstraintExtractor(this._registry);

  /// Extrai constraint para validar um tipo [T]
  /// Retorna null se o tipo não estiver mapeado no registry
  Constraint? extractConstraint<T>() {
    if (!_registry.hasClassMetadata<T>()) {
      return null;
    }

    final classMetadata = _registry.getClassMetadata<T>();
    return _buildConstraintFromClass(classMetadata);
  }

  /// Extrai constraint para validar um tipo dinâmico
  Constraint? extractConstraintForType(Type type) {
    if (!_registry.hasClassMetadata(type)) {
      return null;
    }

    final classMetadata = _registry.getClassMetadata(type);
    return _buildConstraintFromClass(classMetadata);
  }

  /// Constrói uma Collection constraint baseada nos getters da classe
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

  /// Constrói constraint para um getter específico
  Constraint? _buildConstraintForGetter(GetterMetadata getter) {
    final constraints = <Constraint>[];

    // 1. Adiciona constraint de tipo primitivo
    final typeConstraint = _getPrimitiveTypeConstraint(getter.typeMetadata);
    if (typeConstraint != null) {
      constraints.add(typeConstraint);
    }

    // 2. Adiciona constraints das annotations
    final annotationConstraints = _extractConstraintsFromAnnotations(getter);
    constraints.addAll(annotationConstraints);

    // Se não tem constraints, retorna null
    if (constraints.isEmpty) {
      return null;
    }

    // 3. Combina múltiplas constraints com All
    final combinedConstraint = constraints.length == 1
        ? constraints.first
        : All(constraints);

    // 4. Envolve em Optional se for nullable
    if (_isNullableGetter(getter)) {
      return Optional(combinedConstraint);
    }

    return combinedConstraint;
  }

  /// Retorna constraint de validação para tipos primitivos
  Constraint? _getPrimitiveTypeConstraint(TypeMetadata typeMetadata) {
    final type = typeMetadata.type;

    // Tipos primitivos
    if (type == String) return const IsString();
    if (type == int) return const IsInt();
    if (type == double) return const IsDouble();
    if (type == num) return const IsNum();
    if (type == bool) return const IsBool();

    // Lista
    if (type == List || _isListType(type)) {
      return const IsList();
    }

    // Tipo não primitivo - não adiciona constraint de tipo
    return null;
  }

  /// Verifica se é um tipo [List<T>]
  bool _isListType(Type type) {
    final typeString = type.toString();
    return typeString.startsWith('List<') || typeString == 'List';
  }

  /// Extrai todas as Constraint annotations de um getter
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
