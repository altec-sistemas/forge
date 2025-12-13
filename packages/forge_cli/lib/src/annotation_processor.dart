import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element2.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:forge_core/forge_core.dart';
import 'package:source_gen/source_gen.dart';

import 'bundle_generator.dart';
import 'import_collector.dart';

/// Processes annotations and identifies capabilities
class AnnotationProcessor {
  final Resolver resolver;
  final LibraryElement2 library;
  final ScannedData data = ScannedData();
  final ImportCollector? importCollector;

  // ✅ CACHE de anotações processadas
  final _annotationCache = <Annotatable, List<DartObject>>{};

  // ✅ CACHE de verificações de tipo
  final _typeCheckCache = <String, bool>{};

  late final TypeChecker _injectableChecker;
  late final TypeChecker _moduleChecker;
  late final TypeChecker _provideChecker;
  late final TypeChecker _provideSingletonChecker;
  late final TypeChecker _provideEagerChecker;
  late final TypeChecker _bootChecker;
  late final TypeChecker _injectChecker;
  late final TypeChecker _requiredChecker;

  AnnotationProcessor(this.resolver, this.library, {this.importCollector}) {
    _initializeTypeCheckers();
    _collectLibraryImports();
  }

  void _initializeTypeCheckers() {
    try {
      _injectableChecker = TypeChecker.typeNamed(
        Service,
        inPackage: 'forge_core',
      );
      _moduleChecker = TypeChecker.typeNamed(Module, inPackage: 'forge_core');
      _provideChecker = TypeChecker.typeNamed(Provide, inPackage: 'forge_core');
      _provideSingletonChecker = TypeChecker.typeNamed(
        ProvideSingleton,
        inPackage: 'forge_core',
      );
      _provideEagerChecker = TypeChecker.typeNamed(
        ProvideEager,
        inPackage: 'forge_core',
      );
      _bootChecker = TypeChecker.typeNamed(Boot, inPackage: 'forge_core');
      _injectChecker = TypeChecker.typeNamed(Inject, inPackage: 'forge_core');
      _requiredChecker = TypeChecker.typeNamed(
        Required,
        inPackage: 'forge_core',
      );
    } catch (e) {
      log.warning('Could not initialize type checkers: $e');
    }
  }

  void _collectLibraryImports() {
    if (importCollector == null) return;

    final fragment = library.firstFragment;

    for (final import in fragment.libraryImports2) {
      final importedLibrary = import.importedLibrary2;
      if (importedLibrary == null) continue;

      final importUri = import.uri;
      if (importUri is DirectiveUriWithLibrary) {
        if (importUri.relativeUri.scheme == 'dart' ||
            importUri.relativeUri.scheme == 'package') {
          final uriStr = importUri.relativeUriString;
          importCollector!.registerLibraryWithImport(importedLibrary, uriStr);
        }
      }
    }
  }

  /// Process the library and collect data
  Future<void> process() async {
    // ✅ PROCESSAR em lote
    final classes = library.classes.toList();
    final enums = library.enums.toList();

    // Processar classes
    for (final element in classes) {
      await _processClass(element);
    }

    // Processar enums
    for (final element in enums) {
      await _processEnum(element);
    }
  }

  Future<void> _processClass(ClassElement2 element) async {
    // ✅ VERIFICAÇÃO RÁPIDA - cache de annotations
    if (_hasAnnotation(element, _moduleChecker)) {
      await _processModule(element);
      return;
    }

    final isService = _hasAnnotation(element, _injectableChecker);
    if (isService) {
      final injectableAnnotation = _injectableChecker.firstAnnotationOf(
        element,
      );
      if (injectableAnnotation != null) {
        final constructor =
            element.unnamedConstructor2 ?? element.constructors2.firstOrNull;
        final constructorInjects = constructor != null
            ? _extractInjectInfo(constructor.formalParameters)
            : <InjectInfo>[];

        final requiredMethods = _processRequiredMethods(element);
        final requiredSetters = _processRequiredSetters(element);

        final envField = injectableAnnotation.getField('env');
        final env = envField?.toStringValue();

        data.services.add(
          ServiceData(
            element: element,
            annotation: injectableAnnotation,
            isSingleton:
                injectableAnnotation.getField('shared')?.toBoolValue() ?? true,
            constructorInjects: constructorInjects,
            requiredMethods: requiredMethods,
            requiredSetters: requiredSetters,
            env: env,
          ),
        );
      }
    }

    // ✅ ANÁLISE OTIMIZADA de capabilities
    final classAnnotations = _getAnnotationsCached(element);
    final classCapabilities = _analyzeCapabilitiesForClass(classAnnotations);

    final memberCapabilities = _collectMemberCapabilities(element);

    final effectiveCapabilities = _mergeCapabilities(
      classCapabilities,
      memberCapabilities,
    );

    final shouldGenerateMetadata = effectiveCapabilities.hasAnyCapability;

    if (!shouldGenerateMetadata) {
      return;
    }

    List<ConstructorData>? constructors;
    List<MethodData>? methods;
    List<GetterData>? getters;
    List<SetterData>? setters;

    if (effectiveCapabilities.hasConstructorsCapability) {
      constructors = _processConstructors(element, effectiveCapabilities);
    }

    if (effectiveCapabilities.hasMethodsCapability) {
      methods = _processMethods(element, effectiveCapabilities);
    }

    if (effectiveCapabilities.hasGettersCapability) {
      getters = _processGetters(element, effectiveCapabilities);
    }

    if (effectiveCapabilities.hasSettersCapability) {
      setters = _processSetters(element, effectiveCapabilities);
    }

    data.classes.add(
      ClassData(
        element: element,
        constructors: constructors,
        methods: methods,
        getters: getters,
        setters: setters,
        hasMetadata: true,
        hasProxyCapability: effectiveCapabilities.hasProxyCapability,
      ),
    );
  }

  /// ✅ CACHE de análise de capabilities
  Capabilities _analyzeCapabilitiesForClass(List<DartObject> annotations) {
    bool hasMethodsCapability = false;
    bool hasConstructorsCapability = false;
    bool hasGettersCapability = false;
    bool hasSettersCapability = false;
    bool hasParametersCapability = false;
    bool hasProxyCapability = false;

    for (final annotation in annotations) {
      final type = annotation.type;
      if (type == null) continue;

      if (_implementsCapabilityCached(type, 'MethodsCapability')) {
        hasMethodsCapability = true;
      }
      if (_implementsCapabilityCached(type, 'ConstructorsCapability')) {
        hasConstructorsCapability = true;
      }
      if (_implementsCapabilityCached(type, 'GettersCapability')) {
        hasGettersCapability = true;
      }
      if (_implementsCapabilityCached(type, 'SettersCapability')) {
        hasSettersCapability = true;
      }
      if (_implementsCapabilityCached(type, 'ParametersCapability')) {
        hasParametersCapability = true;
      }
      if (_implementsCapabilityCached(type, 'ProxyCapability')) {
        hasProxyCapability = true;
        hasMethodsCapability = true;
        hasGettersCapability = true;
        hasSettersCapability = true;
      }
    }

    return Capabilities(
      classLevelMethods: hasMethodsCapability,
      classLevelConstructors: hasConstructorsCapability,
      classLevelGetters: hasGettersCapability,
      classLevelSetters: hasSettersCapability,
      classLevelParameters: hasParametersCapability,
      hasMethodsCapability: hasMethodsCapability,
      hasConstructorsCapability: hasConstructorsCapability,
      hasGettersCapability: hasGettersCapability,
      hasSettersCapability: hasSettersCapability,
      hasParametersCapability: hasParametersCapability,
      hasProxyCapability: hasProxyCapability,
    );
  }

  /// ✅ OTIMIZADO: Verificação com cache
  bool _implementsCapabilityCached(DartType? type, String capabilityName) {
    if (type == null || type is! InterfaceType) return false;

    final cacheKey = '${type.element3.name3}:$capabilityName';
    if (_typeCheckCache.containsKey(cacheKey)) {
      return _typeCheckCache[cacheKey]!;
    }

    final result = _implementsCapability(type, capabilityName);
    _typeCheckCache[cacheKey] = result;
    return result;
  }

  Capabilities _collectMemberCapabilities(ClassElement2 element) {
    bool hasMethodsCapability = false;
    bool hasConstructorsCapability = false;
    bool hasGettersCapability = false;
    bool hasSettersCapability = false;
    bool hasParametersCapability = false;

    for (final constructor in element.constructors2) {
      final annotations = _getAnnotationsCached(constructor);
      for (final annotation in annotations) {
        if (_implementsCapabilityCached(
          annotation.type,
          'ConstructorsCapability',
        )) {
          hasConstructorsCapability = true;
        }
        if (_implementsCapabilityCached(
          annotation.type,
          'ParametersCapability',
        )) {
          hasParametersCapability = true;
        }
      }

      for (final param in constructor.formalParameters) {
        final paramAnnotations = _getAnnotationsCached(param);
        for (final annotation in paramAnnotations) {
          if (_implementsCapabilityCached(
            annotation.type,
            'ParametersCapability',
          )) {
            hasParametersCapability = true;
            hasConstructorsCapability = true;
          }
        }
      }
    }

    for (final method in element.methods2) {
      final annotations = _getAnnotationsCached(method);
      for (final annotation in annotations) {
        if (_implementsCapabilityCached(annotation.type, 'MethodsCapability')) {
          hasMethodsCapability = true;
        }
        if (_implementsCapabilityCached(
          annotation.type,
          'ParametersCapability',
        )) {
          hasParametersCapability = true;
        }
      }

      for (final param in method.formalParameters) {
        final paramAnnotations = _getAnnotationsCached(param);
        for (final annotation in paramAnnotations) {
          if (_implementsCapabilityCached(
            annotation.type,
            'ParametersCapability',
          )) {
            hasParametersCapability = true;
            hasMethodsCapability = true;
          }
        }
      }
    }

    for (final getter in element.getters2) {
      final annotations = [
        ..._getAnnotationsCached(getter),
        if (getter.variable3 != null)
          ..._getAnnotationsCached(getter.variable3!),
      ];
      for (final annotation in annotations) {
        if (_implementsCapabilityCached(annotation.type, 'GettersCapability')) {
          hasGettersCapability = true;
        }
      }
    }

    for (final setter in element.setters2) {
      final annotations = _getAnnotationsCached(setter);
      for (final annotation in annotations) {
        if (_implementsCapabilityCached(annotation.type, 'SettersCapability')) {
          hasSettersCapability = true;
        }
        if (_implementsCapabilityCached(
          annotation.type,
          'ParametersCapability',
        )) {
          hasParametersCapability = true;
        }
      }

      for (final param in setter.formalParameters) {
        final paramAnnotations = _getAnnotationsCached(param);
        for (final annotation in paramAnnotations) {
          if (_implementsCapabilityCached(
            annotation.type,
            'ParametersCapability',
          )) {
            hasParametersCapability = true;
            hasSettersCapability = true;
          }
        }
      }
    }

    return Capabilities(
      classLevelMethods: false,
      classLevelConstructors: false,
      classLevelGetters: false,
      classLevelSetters: false,
      classLevelParameters: false,
      hasMethodsCapability: hasMethodsCapability,
      hasConstructorsCapability: hasConstructorsCapability,
      hasGettersCapability: hasGettersCapability,
      hasSettersCapability: hasSettersCapability,
      hasParametersCapability: hasParametersCapability,
      hasProxyCapability: false,
    );
  }

  Capabilities _mergeCapabilities(
    Capabilities classLevel,
    Capabilities memberLevel,
  ) {
    return Capabilities(
      classLevelMethods: classLevel.classLevelMethods,
      classLevelConstructors: classLevel.classLevelConstructors,
      classLevelGetters: classLevel.classLevelGetters,
      classLevelSetters: classLevel.classLevelSetters,
      classLevelParameters: classLevel.classLevelParameters,
      hasMethodsCapability:
          classLevel.hasMethodsCapability || memberLevel.hasMethodsCapability,
      hasConstructorsCapability:
          classLevel.hasConstructorsCapability ||
          memberLevel.hasConstructorsCapability,
      hasGettersCapability:
          classLevel.hasGettersCapability || memberLevel.hasGettersCapability,
      hasSettersCapability:
          classLevel.hasSettersCapability || memberLevel.hasSettersCapability,
      hasParametersCapability:
          classLevel.hasParametersCapability ||
          memberLevel.hasParametersCapability,
      hasProxyCapability: classLevel.hasProxyCapability,
    );
  }

  Future<void> _processModule(ClassElement2 element) async {
    final providers = <ProviderData>[];
    final bootMethods = <BootMethodData>[];

    for (final method in element.methods2) {
      final provideAnnotation = _provideChecker.firstAnnotationOf(method);
      final provideSingletonAnnotation = _provideSingletonChecker
          .firstAnnotationOf(method);
      final provideEagerAnnotation = _provideEagerChecker.firstAnnotationOf(
        method,
      );
      final bootAnnotation = _bootChecker.firstAnnotationOf(method);

      if (provideAnnotation != null ||
          provideSingletonAnnotation != null ||
          provideEagerAnnotation != null) {
        final annotation =
            provideAnnotation ??
            provideSingletonAnnotation ??
            provideEagerAnnotation!;

        final nameField = annotation.getField('name');
        final envField = annotation.getField('env');
        final sharedField = annotation.getField('shared');
        final priorityField = annotation.getField('priority');

        final parameterInjects = _extractInjectInfo(method.formalParameters);

        providers.add(
          ProviderData(
            method: method,
            annotation: annotation,
            name: nameField?.toStringValue(),
            env: envField?.toStringValue(),
            shared: sharedField?.toBoolValue() ?? true,
            eager: provideEagerAnnotation != null,
            priority: priorityField?.toIntValue(),
            parameterInjects: parameterInjects,
          ),
        );
      }

      if (bootAnnotation != null) {
        final parameterInjects = _extractInjectInfo(method.formalParameters);
        bootMethods.add(
          BootMethodData(
            method: method,
            annotation: bootAnnotation,
            parameterInjects: parameterInjects,
          ),
        );
      }
    }

    for (final getter in element.getters2) {
      final provideAnnotation = _provideChecker.firstAnnotationOf(getter);
      final provideSingletonAnnotation = _provideSingletonChecker
          .firstAnnotationOf(getter);
      final provideEagerAnnotation = _provideEagerChecker.firstAnnotationOf(
        getter,
      );

      if (provideAnnotation != null ||
          provideSingletonAnnotation != null ||
          provideEagerAnnotation != null) {
        final annotation =
            provideAnnotation ??
            provideSingletonAnnotation ??
            provideEagerAnnotation!;

        final nameField = annotation.getField('name');
        final envField = annotation.getField('env');
        final sharedField = annotation.getField('shared');
        final priorityField = annotation.getField('priority');

        providers.add(
          ProviderData(
            method: getter,
            annotation: annotation,
            name: nameField?.toStringValue(),
            env: envField?.toStringValue(),
            shared: sharedField?.toBoolValue() ?? true,
            eager: provideEagerAnnotation != null,
            priority: priorityField?.toIntValue(),
            parameterInjects: [],
          ),
        );
      }
    }

    data.modules.add(
      ModuleData(
        element: element,
        providers: providers,
        bootMethods: bootMethods,
      ),
    );
  }

  Future<void> _processEnum(EnumElement2 element) async {
    final annotations = _getAnnotationsCached(element);
    if (!_hasAnyCapability(annotations)) {
      return;
    }

    final values = <EnumValueData>[];
    for (final field in element.constants2) {
      if (field.isEnumConstant) {
        values.add(EnumValueData(element: field));
      }
    }

    List<GetterData>? getters;
    final capabilities = _analyzeCapabilitiesForClass(annotations);
    if (capabilities.hasGettersCapability) {
      getters = _processGetters(element, capabilities);
    }

    data.enums.add(
      EnumData(element: element, values: values, getters: getters),
    );
  }

  List<ConstructorData> _processConstructors(
    InterfaceElement2 element,
    Capabilities capabilities,
  ) {
    final constructors = <ConstructorData>[];

    for (final constructor in element.constructors2) {
      final annotations = _getAnnotationsCached(constructor);

      final shouldInclude =
          capabilities.classLevelConstructors ||
          _hasCapability(annotations, 'ConstructorsCapability');

      if (shouldInclude) {
        final parameterInjects = _extractInjectInfo(
          constructor.formalParameters,
        );

        constructors.add(
          ConstructorData(
            element: constructor,
            annotations: annotations,
            parameterInjects: parameterInjects,
          ),
        );
      }
    }

    return constructors;
  }

  List<MethodData> _processMethods(
    InterfaceElement2 element,
    Capabilities capabilities,
  ) {
    final methods = <MethodData>[];

    for (final method in element.methods2) {
      final annotations = _getAnnotationsCached(method);

      final shouldInclude =
          capabilities.classLevelMethods ||
          _hasCapability(annotations, 'MethodsCapability');

      if (shouldInclude) {
        final parameterInjects = _extractInjectInfo(method.formalParameters);

        methods.add(
          MethodData(
            element: method,
            annotations: annotations,
            parameterInjects: parameterInjects,
          ),
        );
      }
    }

    return methods;
  }

  List<GetterData> _processGetters(
    InstanceElement2 element,
    Capabilities capabilities,
  ) {
    final getters = <GetterData>[];

    for (final getter in element.getters2) {
      final annotations = [
        ..._getAnnotationsCached(getter),
        if (getter.variable3 != null)
          ..._getAnnotationsCached(getter.variable3!),
      ];

      final shouldInclude =
          capabilities.classLevelGetters ||
          _hasCapability(annotations, 'GettersCapability');

      if (shouldInclude) {
        getters.add(GetterData(element: getter));
      }
    }

    return getters;
  }

  List<SetterData> _processSetters(
    InterfaceElement2 element,
    Capabilities capabilities,
  ) {
    final setters = <SetterData>[];

    for (final setter in element.setters2) {
      final annotations = _getAnnotationsCached(setter);

      final shouldInclude =
          capabilities.classLevelSetters ||
          _hasCapability(annotations, 'SettersCapability');

      if (shouldInclude) {
        setters.add(SetterData(element: setter));
      }
    }

    return setters;
  }

  /// ✅ CACHE de annotations
  List<DartObject> _getAnnotationsCached(Annotatable element) {
    if (_annotationCache.containsKey(element)) {
      return _annotationCache[element]!;
    }

    final annotations = element.metadata2.annotations
        .map((m) => m.computeConstantValue())
        .whereType<DartObject>()
        .toList();

    _annotationCache[element] = annotations;
    return annotations;
  }

  List<DartObject> _getAnnotations(Annotatable element) {
    return _getAnnotationsCached(element);
  }

  bool _hasAnnotation(Element2 element, TypeChecker checker) {
    try {
      return checker.hasAnnotationOf(element);
    } catch (e) {
      return false;
    }
  }

  bool _hasCapability(List<DartObject> annotations, String capabilityName) {
    for (final annotation in annotations) {
      if (_implementsCapabilityCached(annotation.type, capabilityName)) {
        return true;
      }
    }
    return false;
  }

  bool _hasAnyCapability(List<DartObject> annotations) {
    for (final annotation in annotations) {
      if (_implementsAnyCapability(annotation.type)) {
        return true;
      }
    }
    return false;
  }

  bool _implementsAnyCapability(DartType? type) {
    if (type == null || type is! InterfaceType) return false;

    final element = type.element3;
    if (element is! ClassElement2) return false;

    final allInterfaces = [element.thisType, ...element.allSupertypes];

    for (final interface in allInterfaces) {
      final name = interface.element3.name3;
      if (name == 'ClassCapability' ||
          name == 'MethodsCapability' ||
          name == 'ConstructorsCapability' ||
          name == 'GettersCapability' ||
          name == 'SettersCapability' ||
          name == 'ParametersCapability' ||
          name == 'ProxyCapability' ||
          name == 'EnumsCapability') {
        return true;
      }
    }

    return false;
  }

  bool _implementsCapability(DartType? type, String capabilityName) {
    if (type == null || type is! InterfaceType) return false;

    final element = type.element3;
    if (element is! ClassElement2) return false;

    final allInterfaces = [element.thisType, ...element.allSupertypes];

    for (final interface in allInterfaces) {
      if (interface.element3.name3 == capabilityName) {
        return true;
      }
    }

    return false;
  }

  List<InjectInfo> _extractInjectInfo(List<FormalParameterElement> parameters) {
    final injectInfos = <InjectInfo>[];

    for (final param in parameters) {
      final annotations = _getAnnotationsCached(param);
      InjectInfo? injectInfo;

      for (final annotation in annotations) {
        if (_injectChecker.isExactlyType(annotation.type!)) {
          DartType? injectType;
          if (annotation.type is InterfaceType) {
            final interfaceType = annotation.type as InterfaceType;
            if (interfaceType.typeArguments.isNotEmpty) {
              injectType = interfaceType.typeArguments.first;
            }
          }

          final nameField = annotation.getField('name');
          final name = nameField?.toStringValue();

          injectInfo = InjectInfo(
            injectType: injectType,
            name: name,
            hasInject: true,
          );
          break;
        }
      }

      injectInfos.add(injectInfo ?? InjectInfo.none());
    }

    return injectInfos;
  }

  List<RequiredMethodData> _processRequiredMethods(ClassElement2 element) {
    final requiredMethods = <RequiredMethodData>[];

    for (final method in element.methods2) {
      if (_hasAnnotation(method, _requiredChecker)) {
        final parameterInjects = _extractInjectInfo(method.formalParameters);
        requiredMethods.add(
          RequiredMethodData(
            element: method,
            parameterInjects: parameterInjects,
          ),
        );
      }
    }

    return requiredMethods;
  }

  List<RequiredSetterData> _processRequiredSetters(ClassElement2 element) {
    final requiredSetters = <RequiredSetterData>[];

    for (final setter in element.setters2) {
      if (_hasAnnotation(setter, _requiredChecker)) {
        final param = setter.formalParameters.firstOrNull;
        InjectInfo? parameterInject;

        if (param != null) {
          final injectInfos = _extractInjectInfo([param]);
          parameterInject = injectInfos.isNotEmpty ? injectInfos.first : null;
        }

        requiredSetters.add(
          RequiredSetterData(element: setter, parameterInject: parameterInject),
        );
      }
    }

    return requiredSetters;
  }
}

/// Capabilities detected on a class
class Capabilities {
  final bool classLevelMethods;
  final bool classLevelConstructors;
  final bool classLevelGetters;
  final bool classLevelSetters;
  final bool classLevelParameters;

  final bool hasMethodsCapability;
  final bool hasConstructorsCapability;
  final bool hasGettersCapability;
  final bool hasSettersCapability;
  final bool hasParametersCapability;
  final bool hasProxyCapability;

  Capabilities({
    required this.classLevelMethods,
    required this.classLevelConstructors,
    required this.classLevelGetters,
    required this.classLevelSetters,
    required this.classLevelParameters,
    required this.hasMethodsCapability,
    required this.hasConstructorsCapability,
    required this.hasGettersCapability,
    required this.hasSettersCapability,
    required this.hasParametersCapability,
    this.hasProxyCapability = false,
  });

  bool get hasAnyCapability =>
      hasMethodsCapability ||
      hasConstructorsCapability ||
      hasGettersCapability ||
      hasSettersCapability ||
      hasParametersCapability ||
      hasProxyCapability;
}
