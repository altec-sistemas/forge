import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:forge_core/forge_core.dart';
import 'package:source_gen/source_gen.dart';

import 'bundle_generator.dart';
import 'import_collector.dart';

/// Processes annotations and identifies capabilities
class AnnotationProcessor {
  final Resolver resolver;
  final LibraryElement library;
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
    } catch (e) {
      log.warning('Could not initialize type checkers: $e');
    }
  }

  /// Collect all imports from the source library and register them
  void _collectLibraryImports() {
    if (importCollector == null) return;

    final fragment = library.firstFragment;

    for (final import in fragment.libraryImports) {
      final importedLibrary = import.importedLibrary;
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
  Future<void> _processClass(ClassElement element) async {
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
            element.unnamedConstructor ?? element.constructors.firstOrNull;
        final constructorInjects = constructor != null
            ? _extractInjectInfo(constructor.formalParameters)
            : <InjectInfo>[];

        data.services.add(
          ServiceData(
            element: element,
            annotation: injectableAnnotation,
            isSingleton:
                injectableAnnotation.getField('shared')?.toBoolValue() ?? true,
            constructorInjects: constructorInjects,
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
    );
  }

  /// Collect capabilities from all members (for cascading)
  Capabilities _collectMemberCapabilities(ClassElement element) {
    bool hasMethodsCapability = false;
    bool hasConstructorsCapability = false;
    bool hasGettersCapability = false;
    bool hasSettersCapability = false;
    bool hasParametersCapability = false;

    // Check constructors
    for (final constructor in element.constructors) {
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
    for (final method in element.methods) {
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
    for (final getter in element.getters) {
      final annotations = [
        ..._getAnnotations(getter),
        ..._getAnnotations(getter.variable),
      ];
      for (final annotation in annotations) {
        if (_implementsCapability(annotation.type, 'GettersCapability')) {
          hasGettersCapability = true;
        }
      }
    }

    // Check setters
    for (final setter in element.setters) {
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
    );
  }

  /// Process module
  Future<void> _processModule(ClassElement element) async {
    final providers = <ProviderData>[];
    final bootMethods = <BootMethodData>[];

    // Process methods
    for (final method in element.methods) {
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
    for (final getter in element.getters) {
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
  Future<void> _processEnum(EnumElement element) async {
    // Check if enum has any capabilities
    final annotations = _getAnnotations(element);
    if (!_hasAnyCapability(annotations)) {
      return;
    }

    final values = <EnumValueData>[];
    for (final field in element.fields) {
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
    InterfaceElement element,
    Capabilities capabilities,
  ) {
    final constructors = <ConstructorData>[];

    for (final constructor in element.constructors) {
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
    InterfaceElement element,
    Capabilities capabilities,
  ) {
    final methods = <MethodData>[];

    for (final method in element.methods) {
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
    InterfaceElement element,
    Capabilities capabilities,
  ) {
    final getters = <GetterData>[];

    for (final getter in element.getters) {
      final annotations = [
        ..._getAnnotations(getter),
        ..._getAnnotations(getter.variable),
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
    InterfaceElement element,
    Capabilities capabilities,
  ) {
    final setters = <SetterData>[];

    for (final setter in element.setters) {
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
  List<DartObject> _getAnnotations(Element element) {
    return element.metadata.annotations
        .map((m) => m.computeConstantValue())
        .whereType<DartObject>()
        .toList();
  }

  /// Check if element has a specific annotation
  bool _hasAnnotation(Element element, TypeChecker checker) {
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

    final element = type.element;
    if (element is! ClassElement) return false;

    final allInterfaces = [
      element.thisType,
      ...element.allSupertypes,
    ];

    for (final interface in allInterfaces) {
      final name = interface.element.name;
      if (name == 'ClassCapability' ||
          name == 'MethodsCapability' ||
          name == 'ConstructorsCapability' ||
          name == 'GettersCapability' ||
          name == 'SettersCapability' ||
          name == 'ParametersCapability' ||
          name == 'EnumsCapability') {
        return true;
      }
    }

    return false;
  }

  /// Check if a type implements a specific capability interface
  bool _implementsCapability(DartType? type, String capabilityName) {
    if (type == null || type is! InterfaceType) return false;

    final element = type.element;
    if (element is! ClassElement) return false;

    final allInterfaces = [
      element.thisType,
      ...element.allSupertypes,
    ];

    for (final interface in allInterfaces) {
      if (interface.element.name == capabilityName) {
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
  });

  /// Check if there are any capabilities at all
  bool get hasAnyCapability =>
      hasMethodsCapability ||
      hasConstructorsCapability ||
      hasGettersCapability ||
      hasSettersCapability ||
      hasParametersCapability;
}
