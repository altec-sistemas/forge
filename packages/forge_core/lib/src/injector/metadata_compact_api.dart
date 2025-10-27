import 'metadata_registry.dart';
import 'proxy_system.dart';

/// Creates a TypeMetadata instance
TypeMetadata<T> type<T>([
  List<TypeMetadata> args = const [],
  bool nullable = false,
]) => TypeMetadata<T>(args, nullable);

/// Creates a ClassMetadata instance with compact syntax
ClassMetadata clazz(
  TypeMetadata typeMetadata,
  List<dynamic> annotations, [
  List<ConstructorMetadata>? constructors,
  List<MethodMetadata>? methods,
  List<GetterMetadata>? getters,
  List<SetterMetadata>? setters,
  AbstractProxy Function(
    Object target,
    ProxyHandler handler,
    ClassMetadata metadata,
  )?
  createProxy,
]) {
  return ClassMetadata(
    typeMetadata: typeMetadata,
    annotations: annotations,
    constructors: constructors,
    methods: methods,
    getters: getters,
    setters: setters,
    createProxy: createProxy,
  );
}

/// Creates a ConstructorMetadata instance with compact syntax
ConstructorMetadata constructor(
  Function Function() factory,
  List<ParameterMetadata> parameters, [
  String name = '',
  List<dynamic> annotations = const [],
]) {
  return ConstructorMetadata(
    name: name,
    factory: factory,
    parameters: parameters,
    annotations: annotations,
  );
}

/// Creates a ParameterMetadata instance with compact syntax
/// Creates a ParameterMetadata instance with compact syntax
ParameterMetadata parameter(
  TypeMetadata typeMetadata,
  String name,
  int index,
  bool isOptional,
  bool isNamed, [
  dynamic defaultValue,
  List<dynamic> annotations = const [],
]) {
  return ParameterMetadata(
    typeMetadata: typeMetadata,
    name: name,
    index: index,
    isOptional: isOptional,
    isNamed: isNamed,
    defaultValue: defaultValue,
    annotations: annotations,
  );
}

/// Creates a MethodMetadata instance with compact syntax
MethodMetadata method(
  TypeMetadata returnType,
  String name,
  Function Function(dynamic instance) methodGetter, [
  List<ParameterMetadata>? parameters,
  List<dynamic> annotations = const [],
]) {
  return MethodMetadata(
    returnType: returnType,
    name: name,
    method: methodGetter,
    parameters: parameters,
    annotations: annotations,
  );
}

/// Creates a GetterMetadata instance with compact syntax
GetterMetadata getter(
  TypeMetadata returnType,
  String name,
  dynamic Function(dynamic instance) getterFunc, [
  List<dynamic> annotations = const [],
]) {
  return GetterMetadata(
    returnType: returnType,
    name: name,
    getter: getterFunc,
    annotations: annotations,
  );
}

/// Creates a SetterMetadata instance with compact syntax
SetterMetadata setter(
  TypeMetadata valueType,
  String name,
  void Function(dynamic instance, dynamic value) setterFunc, [
  List<dynamic> annotations = const [],
]) {
  return SetterMetadata(
    valueType: valueType,
    name: name,
    setter: setterFunc,
    annotations: annotations,
  );
}

/// Creates an EnumMetadata instance with compact syntax
EnumMetadata enumMeta(
  TypeMetadata typeMetadata,
  List<dynamic> annotations, [
  List<EnumValueMetadata>? values,
  List<GetterMetadata>? getters,
]) {
  return EnumMetadata(
    typeMetadata: typeMetadata,
    annotations: annotations,
    values: values,
    getters: getters,
  );
}

/// Creates an EnumValueMetadata instance with compact syntax
EnumValueMetadata enumValue(
  String name,
  dynamic value,
  int index, [
  List<dynamic> annotations = const [],
]) {
  return EnumValueMetadata(
    name: name,
    value: value,
    index: index,
    annotations: annotations,
  );
}
