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

  // Type checkers for identifying annotations
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

  /// Collect all imports from the source library and register them
  void _collectLibraryImports() {
    if (importCollector == null) return;

    final fragment = library.firstFragment;

    for (final import in fragment.libraryImports2) {
      final importedLibrary = import.importedLibrary2;
      if (importedLibrary == null) continue;

      final importUri = import.uri;
      if (importUri is DirectiveUriWithLibrary) {
        final uriStr = importUri.relativeUriString;
        importCollector!.registerLibraryWithImport(importedLibrary, uriStr);
      }
    }
  }

  /// Process the library and collect data
  Future<void> process() async {
    for (final element in library.classes) {
      await _processClass(element);
    }

    for (final element in library.enums) {
      await _processEnum(element);
    }
  }

  /// Process a class element
  Future<void> _processClass(ClassElement2 element) async {
    // Check if it's a Module
    if (_hasAnnotation(element, _moduleChecker)) {
      await _processModule(element);
      return;
    }

    // Check if it's a Service (Injectable)
    final isService = _hasAnnotation(element, _injectableChecker);
    if (isService) {
      final injectableAnnotation = _injectableChecker.firstAnnotationOf(
        element,
      );
      if (injectableAnnotation != null) {
        // Get constructor and extract InjectInfo
        final constructor =
            element.unnamedConstructor2 ?? element.constructors2.firstOrNull;
        final constructorInjects = constructor != null
            ? _extractInjectInfo(constructor.formalParameters)
            : <InjectInfo>[];

        // Process @Required methods and setters
        final requiredMethods = _processRequiredMethods(element);
        final requiredSetters = _processRequiredSetters(element);

        data.services.add(
          ServiceData(
            element: element,
            annotation: injectableAnnotation,
            isSingleton:
                injectableAnnotation.getField('shared')?.toBoolValue() ?? true,
            constructorInjects: constructorInjects,
            requiredMethods: requiredMethods,
            requiredSetters: requiredSetters,
          ),
        );
      }
    }

    // Analyze class-level and member-level capabilities
    final classAnnotations = _getAnnotations(element);
    final classCapabilities = _analyzeCapabilitiesForClass(classAnnotations);

    // Check if any member has capabilities (cascading effect)
    final memberCapabilities = _collectMemberCapabilities(element);

    // Merge capabilities: class-level OR any member-level
    final effectiveCapabilities = _mergeCapabilities(
      classCapabilities,
      memberCapabilities,
    );

    // CHANGE: For services with member capabilities, we MUST generate metadata
    // even if there are no class-level capabilities
    final shouldGenerateMetadata = effectiveCapabilities.hasAnyCapability;

    if (!shouldGenerateMetadata) {
      return;
    }

    // Generate metadata based on effective capabilities
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

  /// Analyze capabilities from class-level annotations
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

      if (_implementsCapability(type, 'MethodsCapability')) {
        hasMethodsCapability = true;
      }
      if (_implementsCapability(type, 'ConstructorsCapability')) {
        hasConstructorsCapability = true;
      }
      if (_implementsCapability(type, 'GettersCapability')) {
        hasGettersCapability = true;
      }
      if (_implementsCapability(type, 'SettersCapability')) {
        hasSettersCapability = true;
      }
      if (_implementsCapability(type, 'ParametersCapability')) {
        hasParametersCapability = true;
      }
      if (_implementsCapability(type, 'ProxyCapability')) {
        hasProxyCapability = true;
        // ProxyCapability requires methods, getters, and setters
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

  /// Collect capabilities from all members (for cascading)
  Capabilities _collectMemberCapabilities(ClassElement2 element) {
    bool hasMethodsCapability = false;
    bool hasConstructorsCapability = false;
    bool hasGettersCapability = false;
    bool hasSettersCapability = false;
    bool hasParametersCapability = false;

    // Check constructors
    for (final constructor in element.constructors2) {
      final annotations = _getAnnotations(constructor);
      for (final annotation in annotations) {
        if (_implementsCapability(annotation.type, 'ConstructorsCapability')) {
          hasConstructorsCapability = true;
        }
        if (_implementsCapability(annotation.type, 'ParametersCapability')) {
          hasParametersCapability = true;
        }
      }

      // Check constructor parameters
      for (final param in constructor.formalParameters) {
        final paramAnnotations = _getAnnotations(param);
        for (final annotation in paramAnnotations) {
          if (_implementsCapability(annotation.type, 'ParametersCapability')) {
            hasParametersCapability = true;
            // Parameters capability cascades up to require constructors
            hasConstructorsCapability = true;
          }
        }
      }
    }

    // Check methods
    for (final method in element.methods2) {
      final annotations = _getAnnotations(method);
      for (final annotation in annotations) {
        if (_implementsCapability(annotation.type, 'MethodsCapability')) {
          hasMethodsCapability = true;
        }
        if (_implementsCapability(annotation.type, 'ParametersCapability')) {
          hasParametersCapability = true;
        }
      }

      // Check method parameters
      for (final param in method.formalParameters) {
        final paramAnnotations = _getAnnotations(param);
        for (final annotation in paramAnnotations) {
          if (_implementsCapability(annotation.type, 'ParametersCapability')) {
            hasParametersCapability = true;
            // Parameters capability cascades up to require methods
            hasMethodsCapability = true;
          }
        }
      }
    }

    // Check getters
    for (final getter in element.getters2) {
      final annotations = [
        ..._getAnnotations(getter),
        if (getter.variable3 != null) ..._getAnnotations(getter.variable3!),
      ];
      for (final annotation in annotations) {
        if (_implementsCapability(annotation.type, 'GettersCapability')) {
          hasGettersCapability = true;
        }
      }
    }

    // Check setters
    for (final setter in element.setters2) {
      final annotations = _getAnnotations(setter);
      for (final annotation in annotations) {
        if (_implementsCapability(annotation.type, 'SettersCapability')) {
          hasSettersCapability = true;
        }
        if (_implementsCapability(annotation.type, 'ParametersCapability')) {
          hasParametersCapability = true;
        }
      }

      // Check setter parameters
      for (final param in setter.formalParameters) {
        final paramAnnotations = _getAnnotations(param);
        for (final annotation in paramAnnotations) {
          if (_implementsCapability(annotation.type, 'ParametersCapability')) {
            hasParametersCapability = true;
            hasSettersCapability = true;
          }
        }
      }
    }

    return Capabilities(
      classLevelMethods: false, // Member-level don't set class-level flags
      classLevelConstructors: false,
      classLevelGetters: false,
      classLevelSetters: false,
      classLevelParameters: false,
      hasMethodsCapability: hasMethodsCapability,
      hasConstructorsCapability: hasConstructorsCapability,
      hasGettersCapability: hasGettersCapability,
      hasSettersCapability: hasSettersCapability,
      hasParametersCapability: hasParametersCapability,
      hasProxyCapability: false, // ProxyCapability is only class-level
    );
  }

  /// Merge class-level and member-level capabilities
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

  /// Process module
  Future<void> _processModule(ClassElement2 element) async {
    final providers = <ProviderData>[];
    final bootMethods = <BootMethodData>[];

    // Process methods
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

    // Process getters (they can also be providers)
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
            parameterInjects: [], // Getters don't have parameters
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

  /// Process enum
  Future<void> _processEnum(EnumElement2 element) async {
    // Check if enum has any capabilities
    final annotations = _getAnnotations(element);
    if (!_hasAnyCapability(annotations)) {
      return;
    }

    final values = <EnumValueData>[];
    for (final field in element.constants2) {
      if (field.isEnumConstant) {
        values.add(EnumValueData(element: field));
      }
    }

    // Check if we need to generate getter metadata
    List<GetterData>? getters;
    final capabilities = _analyzeCapabilitiesForClass(annotations);
    if (capabilities.hasGettersCapability) {
      getters = _processGetters(element, capabilities);
    }

    data.enums.add(
      EnumData(
        element: element,
        values: values,
        getters: getters,
      ),
    );
  }

  /// Process constructors based on capabilities
  List<ConstructorData> _processConstructors(
    InterfaceElement2 element,
    Capabilities capabilities,
  ) {
    final constructors = <ConstructorData>[];

    for (final constructor in element.constructors2) {
      final annotations = _getAnnotations(constructor);

      // Class-level capability: include ALL constructors
      // Member-level: only include if annotated with capability
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

  /// Process methods based on capabilities
  List<MethodData> _processMethods(
    InterfaceElement2 element,
    Capabilities capabilities,
  ) {
    final methods = <MethodData>[];

    for (final method in element.methods2) {
      final annotations = _getAnnotations(method);

      // Class-level capability: include ALL methods
      // Member-level: only include if annotated with capability
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

  /// Process getters based on capabilities
  List<GetterData> _processGetters(
    InstanceElement2 element,
    Capabilities capabilities,
  ) {
    final getters = <GetterData>[];

    for (final getter in element.getters2) {
      final annotations = [
        ..._getAnnotations(getter),
        if (getter.variable3 != null) ..._getAnnotations(getter.variable3!),
      ];

      // Class-level capability: include ALL getters
      // Member-level: only include if annotated with capability
      final shouldInclude =
          capabilities.classLevelGetters ||
          _hasCapability(annotations, 'GettersCapability');

      if (shouldInclude) {
        getters.add(
          GetterData(
            element: getter,
          ),
        );
      }
    }

    return getters;
  }

  /// Process setters based on capabilities
  List<SetterData> _processSetters(
    InterfaceElement2 element,
    Capabilities capabilities,
  ) {
    final setters = <SetterData>[];

    for (final setter in element.setters2) {
      final annotations = _getAnnotations(setter);

      // Class-level capability: include ALL setters
      // Member-level: only include if annotated with capability
      final shouldInclude =
          capabilities.classLevelSetters ||
          _hasCapability(annotations, 'SettersCapability');

      if (shouldInclude) {
        setters.add(
          SetterData(
            element: setter,
          ),
        );
      }
    }

    return setters;
  }

  /// Get all annotations for an element
  List<DartObject> _getAnnotations(Annotatable element) {
    return element.metadata2.annotations
        .map((m) => m.computeConstantValue())
        .whereType<DartObject>()
        .toList();
  }

  /// Check if element has a specific annotation
  bool _hasAnnotation(Element2 element, TypeChecker checker) {
    try {
      return checker.hasAnnotationOf(element);
    } catch (e) {
      return false;
    }
  }

  /// Check if any annotation has a specific capability
  bool _hasCapability(List<DartObject> annotations, String capabilityName) {
    for (final annotation in annotations) {
      if (_implementsCapability(annotation.type, capabilityName)) {
        return true;
      }
    }
    return false;
  }

  /// Check if any annotation implements a capability interface
  bool _hasAnyCapability(List<DartObject> annotations) {
    for (final annotation in annotations) {
      if (_implementsAnyCapability(annotation.type)) {
        return true;
      }
    }
    return false;
  }

  /// Check if a type implements any capability interface
  bool _implementsAnyCapability(DartType? type) {
    if (type == null || type is! InterfaceType) return false;

    final element = type.element3;
    if (element is! ClassElement2) return false;

    final allInterfaces = [
      element.thisType,
      ...element.allSupertypes,
    ];

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

  /// Check if a type implements a specific capability interface
  bool _implementsCapability(DartType? type, String capabilityName) {
    if (type == null || type is! InterfaceType) return false;

    final element = type.element3;
    if (element is! ClassElement2) return false;

    final allInterfaces = [
      element.thisType,
      ...element.allSupertypes,
    ];

    for (final interface in allInterfaces) {
      if (interface.element3.name3 == capabilityName) {
        return true;
      }
    }

    return false;
  }

  /// Extract @Inject information from method/constructor parameters
  List<InjectInfo> _extractInjectInfo(List<FormalParameterElement> parameters) {
    final injectInfos = <InjectInfo>[];

    for (final param in parameters) {
      final annotations = _getAnnotations(param);
      InjectInfo? injectInfo;

      for (final annotation in annotations) {
        if (_injectChecker.isExactlyType(annotation.type!)) {
          // Get the type argument from @Inject<Type>()
          DartType? injectType;
          if (annotation.type is InterfaceType) {
            final interfaceType = annotation.type as InterfaceType;
            if (interfaceType.typeArguments.isNotEmpty) {
              injectType = interfaceType.typeArguments.first;
            }
          }

          // Get the name from @Inject(name: 'name')
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

  /// Process methods marked with @Required annotation
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

  /// Process setters marked with @Required annotation
  List<RequiredSetterData> _processRequiredSetters(ClassElement2 element) {
    final requiredSetters = <RequiredSetterData>[];

    for (final setter in element.setters2) {
      if (_hasAnnotation(setter, _requiredChecker)) {
        // Setters have exactly one parameter
        final param = setter.formalParameters.firstOrNull;
        InjectInfo? parameterInject;

        if (param != null) {
          final injectInfos = _extractInjectInfo([param]);
          parameterInject = injectInfos.isNotEmpty ? injectInfos.first : null;
        }

        requiredSetters.add(
          RequiredSetterData(
            element: setter,
            parameterInject: parameterInject,
          ),
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

  /// Check if there are any capabilities at all
  bool get hasAnyCapability =>
      hasMethodsCapability ||
      hasConstructorsCapability ||
      hasGettersCapability ||
      hasSettersCapability ||
      hasParametersCapability ||
      hasProxyCapability;
}
