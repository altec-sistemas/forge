import '../../forge_core.dart';
import 'proxy_system.dart';

/// Defines the interface for building and registering metadata
abstract class MetadataRegistryBuilder {
  factory MetadataRegistryBuilder() => _MetadataRegistryBuilderImpl();

  /// Registers metadata for a class type [T].
  void registerClass<T>(ClassMetadata metadata);

  /// Registers metadata for an enum type [T].
  void registerEnum<T>(EnumMetadata metadata);

  /// Builds and returns an immutable [MetadataRegistry] instance.
  MetadataRegistry build();
}

/// Immutable metadata registry runtime interface.
abstract class MetadataRegistry {
  /// Returns the class metadata for type [T].
  ClassMetadata getClassMetadata<T>([Type? type]);

  /// Checks whether metadata for type [T] is registered.
  bool hasClassMetadata<T>([Type? type]);

  /// Returns all registered class metadata.
  List<ClassMetadata> get allClasses;

  /// Returns the enum metadata for type [T].
  EnumMetadata getEnumMetadata<T>([Type? type]);

  /// Checks whether enum metadata for type [T] is registered.
  bool hasEnumMetadata<T>([Type? type]);

  /// Returns all registered enum metadata.
  List<EnumMetadata> get allEnums;

  /// Returns all classes annotated with [A].
  List<ClassMetadata> classesAnnotatedWith<A>();

  /// Returns all enums annotated with [A].
  List<EnumMetadata> enumsAnnotatedWith<A>();

  /// Returns all methods annotated with [A] across all registered classes.
  List<MethodMetadata> methodsAnnotatedWith<A>();

  /// Returns all parameters annotated with [A] across all registered classes.
  List<ParameterMetadata> parametersAnnotatedWith<A>();

  /// Returns all getters annotated with [A] across all registered classes and enums.
  List<GetterMetadata> gettersAnnotatedWith<A>();

  /// Returns all setters annotated with [A] across all registered classes.
  List<SetterMetadata> settersAnnotatedWith<A>();

  /// Returns all constructors annotated with [A] across all registered classes.
  List<ConstructorMetadata> constructorsAnnotatedWith<A>();

  /// Returns all enum values annotated with [A] across all registered enums.
  List<EnumValueMetadata> enumValuesAnnotatedWith<A>();
}

/// Represents metadata about a program element.
class ElementMetadata {
  /// Type information for this element.
  final TypeMetadata typeMetadata;

  /// List of annotations applied to this element.
  final List<dynamic> annotations;

  ElementMetadata(this.typeMetadata, this.annotations);

  /// Returns the first annotation of type [A], if it exists.
  A? firstAnnotationOf<A>() {
    return annotations.whereType<A>().firstOrNull;
  }

  /// Returns all annotations of type [A].
  List<A> allAnnotationsOf<A>() {
    return annotations.whereType<A>().toList();
  }

  /// Checks if this element has an annotation of type [A].
  bool hasAnnotation<A>() {
    return annotations.any((a) => a is A);
  }
}

/// Represents metadata about a class.
class ClassMetadata extends ElementMetadata {
  /// All methods defined in this class.
  final List<MethodMetadata>? methods;

  /// All getters defined in this class.
  final List<GetterMetadata>? getters;

  /// All setters defined in this class.
  final List<SetterMetadata>? setters;

  /// Constructors metadata (if available).
  final List<ConstructorMetadata>? constructors;

  /// Factory function to create a proxy instance for this class.
  /// Returns an AbstractProxy that wraps the target object with the given handler.
  final AbstractProxy Function(
    Object target,
    ProxyHandler handler,
    ClassMetadata metadata,
  )?
  createProxy;

  ClassMetadata({
    required TypeMetadata typeMetadata,
    List<dynamic> annotations = const [],
    this.methods,
    this.getters,
    this.setters,
    this.constructors,
    this.createProxy,
  }) : super(typeMetadata, annotations) {
    // Link back-references
    if (methods != null) {
      for (final method in methods!) {
        method.classMetadata = this;
      }
    }
    if (getters != null) {
      for (final getter in getters!) {
        getter.classMetadata = this;
      }
    }
    if (setters != null) {
      for (final setter in setters!) {
        setter.classMetadata = this;
      }
    }
    if (constructors != null) {
      for (final constructor in constructors!) {
        constructor.classMetadata = this;
      }
    }
  }

  /// Checks if methods were mapped for this class.
  bool get hasMappedMethods => methods != null;

  /// Checks if getters were mapped for this class.
  bool get hasMappedGetters => getters != null;

  /// Checks if setters were mapped for this class.
  bool get hasMappedSetters => setters != null;

  /// Checks if constructors were mapped for this class.
  bool get hasMappedConstructors => constructors != null;

  /// Returns methods annotated with [A].
  List<MethodMetadata> methodsAnnotatedWith<A>() {
    if (methods == null) return [];
    return methods!.where((m) => m.hasAnnotation<A>()).toList();
  }

  /// Returns getters annotated with [A].
  List<GetterMetadata> gettersAnnotatedWith<A>() {
    if (getters == null) return [];
    return getters!.where((g) => g.hasAnnotation<A>()).toList();
  }

  /// Returns setters annotated with [A].
  List<SetterMetadata> settersAnnotatedWith<A>() {
    if (setters == null) return [];
    return setters!.where((s) => s.hasAnnotation<A>()).toList();
  }

  /// Returns constructors annotated with [A].
  List<ConstructorMetadata> constructorsAnnotatedWith<A>() {
    if (constructors == null) return [];
    return constructors!.where((c) => c.hasAnnotation<A>()).toList();
  }
}

/// Represents metadata about an enum.
class EnumMetadata extends ElementMetadata {
  /// All enum values.
  final List<EnumValueMetadata>? values;

  /// All getters defined in this enum.
  final List<GetterMetadata>? getters;

  EnumMetadata({
    required TypeMetadata typeMetadata,
    List<dynamic> annotations = const [],
    this.values,
    this.getters,
  }) : super(typeMetadata, annotations) {
    // Link back-references
    if (values != null) {
      for (final value in values!) {
        value.enumMetadata = this;
      }
    }
    if (getters != null) {
      for (final getter in getters!) {
        getter.enumMetadata = this;
      }
    }
  }

  /// Checks if values were mapped for this enum.
  bool get hasMappedValues => values != null;

  /// Checks if getters were mapped for this enum.
  bool get hasMappedGetters => getters != null;

  /// Returns enum values annotated with [A].
  List<EnumValueMetadata> valuesAnnotatedWith<A>() {
    if (values == null) return [];
    return values!.where((v) => v.hasAnnotation<A>()).toList();
  }

  /// Returns getters annotated with [A].
  List<GetterMetadata> gettersAnnotatedWith<A>() {
    if (getters == null) return [];
    return getters!.where((g) => g.hasAnnotation<A>()).toList();
  }

  /// Returns an enum value by name.
  EnumValueMetadata? getValueByName(String name) {
    if (values == null) return null;
    try {
      return values!.firstWhere((v) => v.name == name);
    } catch (_) {
      return null;
    }
  }
}

/// Represents metadata about an enum value.
class EnumValueMetadata extends ElementMetadata {
  /// Back-reference to the enum that contains this value.
  late final EnumMetadata enumMetadata;

  /// The name of this enum value.
  final String name;

  /// The actual enum value instance.
  final dynamic value;

  /// The index of this value in the enum.
  final int index;

  EnumValueMetadata({
    required this.name,
    required this.value,
    required this.index,
    List<dynamic> annotations = const [],
  }) : super(TypeMetadata<dynamic>(), annotations);
}

/// Base class for function-like metadata (methods, constructors).
abstract class FunctionMetadata extends ElementMetadata {
  /// Back-reference to the class that contains this function.
  late final ClassMetadata classMetadata;

  /// The name of this function.
  final String name;

  /// Parameters of this function.
  final List<ParameterMetadata>? parameters;

  FunctionMetadata({
    required TypeMetadata returnType,
    required this.name,
    this.parameters,
    List<dynamic> annotations = const [],
  }) : super(returnType, annotations) {
    // Link back-references
    if (parameters != null) {
      for (final parameter in parameters!) {
        parameter.functionMetadata = this;
      }
    }
  }

  /// Checks if parameters were mapped for this function.
  bool get hasMappedParameters => parameters != null;

  /// Returns parameters annotated with [A].
  List<ParameterMetadata> parametersAnnotatedWith<A>() {
    if (parameters == null) return [];
    return parameters!.where((p) => p.hasAnnotation<A>()).toList();
  }
}

/// Represents metadata about a method.
class MethodMetadata extends FunctionMetadata {
  /// Function that extracts the method reference from an instance.
  final Function Function(dynamic instance) method;

  MethodMetadata({
    required super.returnType,
    required super.name,
    required this.method,
    super.parameters,
    super.annotations,
  });

  /// Gets the method reference from the given instance.
  Function getMethod(dynamic instance) {
    return method(instance);
  }
}

/// Represents metadata about a constructor.
class ConstructorMetadata extends FunctionMetadata {
  /// Factory function that creates instances using this constructor.
  final Function Function() factory;

  ConstructorMetadata({
    super.name = '',
    required this.factory,
    super.parameters,
    super.annotations,
  }) : super(returnType: TypeMetadata<dynamic>());

  /// Creates an instance using this constructor.
  dynamic createInstance([
    List<dynamic> positionalArgs = const [],
    Map<Symbol, dynamic> namedArgs = const {},
  ]) {
    return Function.apply(factory(), positionalArgs, namedArgs);
  }
}

/// Represents metadata about a method or constructor parameter.
class ParameterMetadata extends ElementMetadata {
  /// Back-reference to the function that contains this parameter.
  late final FunctionMetadata functionMetadata;

  /// The name of this parameter.
  final String name;

  /// Position index in the parameter list.
  final int index;

  /// Whether this parameter is optional.
  final bool isOptional;

  /// Whether this parameter is named.
  final bool isNamed;

  /// Default value of this parameter (if any).
  final dynamic defaultValue;

  ParameterMetadata({
    required TypeMetadata typeMetadata,
    required this.name,
    required this.index,
    required this.isOptional,
    required this.isNamed,
    this.defaultValue,
    List<dynamic> annotations = const [],
  }) : super(typeMetadata, annotations);

  /// Gets the method metadata if this parameter belongs to a method.
  MethodMetadata? get methodMetadata {
    return functionMetadata is MethodMetadata
        ? functionMetadata as MethodMetadata
        : null;
  }

  /// Gets the constructor metadata if this parameter belongs to a constructor.
  ConstructorMetadata? get constructorMetadata {
    return functionMetadata is ConstructorMetadata
        ? functionMetadata as ConstructorMetadata
        : null;
  }

  /// Whether this parameter type is nullable (delegates to TypeMetadata).
  bool get isNullable => typeMetadata.nullable;
}

/// Represents metadata about a getter.
class GetterMetadata extends ElementMetadata {
  /// Back-reference to the class that contains this getter.
  ClassMetadata? classMetadata;

  /// Back-reference to the enum that contains this getter.
  EnumMetadata? enumMetadata;

  /// The name of this getter.
  final String name;

  /// Function that extracts the getter value from an instance.
  final dynamic Function(dynamic instance) getter;

  GetterMetadata({
    required TypeMetadata returnType,
    required this.name,
    required this.getter,
    List<dynamic> annotations = const [],
  }) : super(returnType, annotations);

  /// Gets the getter value from the given instance.
  dynamic getValue(dynamic instance) {
    return getter(instance);
  }
}

/// Represents metadata about a setter.
class SetterMetadata extends ElementMetadata {
  /// Back-reference to the class that contains this setter.
  late final ClassMetadata classMetadata;

  /// The name of this setter.
  final String name;

  /// Function that invokes the setter on an instance.
  final void Function(dynamic instance, dynamic value) setter;

  SetterMetadata({
    required TypeMetadata valueType,
    required this.name,
    required this.setter,
    List<dynamic> annotations = const [],
  }) : super(valueType, annotations);

  /// Sets the value on the given instance.
  void setValue(dynamic instance, dynamic value) {
    setter(instance, value);
  }
}

class _MetadataRegistryBuilderImpl implements MetadataRegistryBuilder {
  final Map<Type, ClassMetadata> _classes = {};
  final Map<Type, EnumMetadata> _enums = {};

  @override
  void registerClass<T>(ClassMetadata metadata) {
    _classes[T] = metadata;
  }

  @override
  void registerEnum<T>(EnumMetadata metadata) {
    _enums[T] = metadata;
  }

  @override
  MetadataRegistry build() {
    return _MetadataRegistryImpl(
      Map<Type, ClassMetadata>.unmodifiable(_classes),
      Map<Type, EnumMetadata>.unmodifiable(_enums),
    );
  }
}

class _MetadataRegistryImpl implements MetadataRegistry {
  final Map<Type, ClassMetadata> _classes;
  final Map<Type, EnumMetadata> _enums;

  _MetadataRegistryImpl(this._classes, this._enums);

  @override
  ClassMetadata getClassMetadata<T>([Type? type]) {
    if (type != null) {
      final metadata = _classes[type];
      if (metadata == null) {
        throw StateError('No metadata registered for type $type');
      }
      return metadata;
    }

    final metadata = _classes[T];
    if (metadata == null) {
      throw StateError('No metadata registered for type $T');
    }
    return metadata;
  }

  @override
  bool hasClassMetadata<T>([Type? type]) {
    return _classes.containsKey(type ?? T);
  }

  @override
  List<ClassMetadata> get allClasses {
    return _classes.values.toList();
  }

  @override
  EnumMetadata getEnumMetadata<T>([Type? type]) {
    final metadata = _enums[type ?? T];
    if (metadata == null) {
      throw StateError('No metadata registered for enum type $T');
    }
    return metadata;
  }

  @override
  bool hasEnumMetadata<T>([Type? type]) {
    return _enums.containsKey(type ?? T);
  }

  @override
  List<EnumMetadata> get allEnums {
    return _enums.values.toList();
  }

  @override
  List<ClassMetadata> classesAnnotatedWith<A>() {
    return _classes.values
        .where((metadata) => metadata.hasAnnotation<A>())
        .toList();
  }

  @override
  List<EnumMetadata> enumsAnnotatedWith<A>() {
    return _enums.values
        .where((metadata) => metadata.hasAnnotation<A>())
        .toList();
  }

  @override
  List<MethodMetadata> methodsAnnotatedWith<A>() {
    final results = <MethodMetadata>[];
    for (final classMetadata in _classes.values) {
      if (classMetadata.methods != null) {
        results.addAll(
          classMetadata.methods!.where((m) => m.hasAnnotation<A>()),
        );
      }
    }
    return results;
  }

  @override
  List<ParameterMetadata> parametersAnnotatedWith<A>() {
    final results = <ParameterMetadata>[];
    for (final classMetadata in _classes.values) {
      if (classMetadata.methods != null) {
        for (final method in classMetadata.methods!) {
          if (method.parameters != null) {
            results.addAll(
              method.parameters!.where((p) => p.hasAnnotation<A>()),
            );
          }
        }
      }
      if (classMetadata.constructors != null) {
        for (final constructor in classMetadata.constructors!) {
          if (constructor.parameters != null) {
            results.addAll(
              constructor.parameters!.where((p) => p.hasAnnotation<A>()),
            );
          }
        }
      }
    }
    return results;
  }

  @override
  List<GetterMetadata> gettersAnnotatedWith<A>() {
    final results = <GetterMetadata>[];
    for (final classMetadata in _classes.values) {
      if (classMetadata.getters != null) {
        results.addAll(
          classMetadata.getters!.where((g) => g.hasAnnotation<A>()),
        );
      }
    }
    for (final enumMetadata in _enums.values) {
      if (enumMetadata.getters != null) {
        results.addAll(
          enumMetadata.getters!.where((g) => g.hasAnnotation<A>()),
        );
      }
    }
    return results;
  }

  @override
  List<SetterMetadata> settersAnnotatedWith<A>() {
    final results = <SetterMetadata>[];
    for (final classMetadata in _classes.values) {
      if (classMetadata.setters != null) {
        results.addAll(
          classMetadata.setters!.where((s) => s.hasAnnotation<A>()),
        );
      }
    }
    return results;
  }

  @override
  List<ConstructorMetadata> constructorsAnnotatedWith<A>() {
    final results = <ConstructorMetadata>[];
    for (final classMetadata in _classes.values) {
      if (classMetadata.constructors != null) {
        results.addAll(
          classMetadata.constructors!.where((c) => c.hasAnnotation<A>()),
        );
      }
    }
    return results;
  }

  @override
  List<EnumValueMetadata> enumValuesAnnotatedWith<A>() {
    final results = <EnumValueMetadata>[];
    for (final enumMetadata in _enums.values) {
      if (enumMetadata.values != null) {
        results.addAll(
          enumMetadata.values!.where((v) => v.hasAnnotation<A>()),
        );
      }
    }
    return results;
  }
}

/// Represents a type with its generic type arguments
class TypeMetadata<T> with GenericCaller<T> {
  Type get type => T;
  final List<TypeMetadata> typeArguments;
  final bool nullable;

  const TypeMetadata([this.typeArguments = const [], this.nullable = false]);

  @override
  String toString() {
    if (typeArguments.isEmpty) return '$T';
    final args = typeArguments.map((t) => t.toString()).join(', ');
    return '$T<$args>';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypeMetadata &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          _listEquals(typeArguments, other.typeArguments);

  @override
  int get hashCode => Object.hash(type, Object.hashAll(typeArguments));

  static bool _listEquals<E>(List<E>? a, List<E>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool isType<U>() {
    return <T>[] is List<U>;
  }
}
