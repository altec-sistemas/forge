// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/element2.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';

import 'annotation_code_generator.dart';
import 'bundle_generator.dart';
import 'import_collector.dart';

/// Generates code for bundle implementations
class CodeEmitter {
  final ImportCollector importCollector;
  final AnnotationCodeGenerator annotationGenerator;
  final AssetId inputId;
  final StringBuffer _buffer = StringBuffer();

  CodeEmitter(
      this.importCollector,
      this.annotationGenerator,
      this.inputId,
      );

  /// Generate complete bundle code
  Future<String> generateBundleCode({
    required String bundleClassName,
    required ScannedData scannedData,
  }) async {
    _buffer.clear();

    // Generate abstract class
    await _generateBundleClass(bundleClassName, scannedData);

    _generateImports();

    return _buffer.toString();
  }

  void _generateImports() {
    final buffer = StringBuffer();

    buffer.writeln("// GENERATED CODE - DO NOT MODIFY BY HAND");
    buffer.writeln("// dart format width=10000");
    buffer.writeln();
    buffer.writeln("import 'package:forge_core/forge_core.dart';");
    buffer.writeln(
      "import 'package:forge_core/metadata_compact_api.dart' as meta;",
    );
    buffer.writeln();

    // Add collected imports
    final imports = importCollector.getImports();

    for (final import in imports) {
      buffer.writeln(import);
    }
    buffer.writeln();

    buffer.write(_buffer.toString());
    _buffer.clear();
    _buffer.write(buffer.toString());
  }

  Future<void> _generateBundleClass(
      String bundleClassName,
      ScannedData data,
      ) async {
    _buffer.writeln(
      'abstract class Abstract$bundleClassName implements Bundle {',
    );
    _buffer.writeln('  @override');
    _buffer.writeln(
      '  Future<void> build(InjectorBuilder builder, String env) async {',
    );

    // Register services
    _generateServiceRegistrations(data.services);

    // Register modules
    _generateModuleRegistrations(data.modules);

    _buffer.writeln('  }');
    _buffer.writeln();

    // Generate metadata registration
    _buffer.writeln('  @override');
    _buffer.writeln(
      '  Future<void> buildMetadata(MetadataRegistryBuilder metaBuilder, String env) async {',
    );

    // Register class metadata
    for (final classData in data.classes) {
      await _generateClassMetadata(classData);
    }

    // Register enum metadata
    for (final enumData in data.enums) {
      await _generateEnumMetadata(enumData);
    }

    _buffer.writeln('  }');
    _buffer.writeln();

    // Generate boot method
    _buffer.writeln('  @override');
    _buffer.writeln('  Future<void> boot(Injector i) async {');

    _generateBootCalls(data.modules);

    _buffer.writeln('  }');
    _buffer.writeln('}');
  }

  void _generateModuleRegistrations(List<ModuleData> modules) {
    if (modules.isEmpty) return;

    _buffer.writeln('    // Register modules');
    for (final module in modules) {
      final moduleType = _getTypeName(module.element.thisType);
      _buffer.writeln('    builder.registerSingleton<$moduleType>(');
      _buffer.writeln('      (i) => $moduleType(),');
      _buffer.writeln('    );');

      // Sort providers by priority (highest first)
      final sortedProviders = List<ProviderData>.from(module.providers);
      sortedProviders.sort(
            (a, b) => (b.priority ?? 0).compareTo(a.priority ?? 0),
      );

      // Register providers
      for (final provider in sortedProviders) {
        _generateProviderRegistration(module, provider);
      }
    }
  }

  void _generateProviderRegistration(
      ModuleData module,
      ProviderData provider,
      ) {
    final method = provider.method;
    final returnType = switch (method) {
      MethodElement m => m.returnType,
      GetterElement g => g.returnType,
      _ => throw UnsupportedError(
        'Unsupported provider method type: ${method.runtimeType}',
      ),
    };
    final moduleType = _getTypeName(module.element.thisType);

    // Check if async
    final isAsync =
        returnType.isDartAsyncFuture || returnType.isDartAsyncFutureOr;
    final actualReturnType = _extractTypeFromFuture(returnType);

    // Generate environment check if needed
    if (provider.env != null) {
      _buffer.writeln("    if (env == '${provider.env}') {");
    }

    final typeStr = _getTypeName(actualReturnType);
    _buffer.write(
      '      builder.${_getRegistrationMethod(
        isEager: provider.eager,
        isShared: provider.shared,
        isAsync: isAsync,
      )}<$typeStr>(',
    );

    _buffer.write('(i) => i<$moduleType>().${method.name3}');

    // Add parameters
    if (method is MethodElement2) {
      _buffer.write('(');
      final params = method.formalParameters;
      for (var i = 0; i < params.length; i++) {
        if (i > 0) _buffer.write(', ');
        final param = params[i];
        if (param.isNamed) {
          _buffer.write('${param.name3}: ');
        }

        // Use InjectInfo if available
        final injectInfo = i < provider.parameterInjects.length
            ? provider.parameterInjects[i]
            : null;
        _buffer.write(_generateInjectorCall(param, injectInfo));
      }
      _buffer.write(')');
    }

    if (isAsync) _buffer.write(',');

    // Add name if specified
    if (provider.name != null) {
      _buffer.writeln("        name: '${provider.name}',");
    }

    _buffer.writeln('      );');

    if (provider.env != null) {
      _buffer.writeln('    }');
    }
  }

  String _getRegistrationMethod({
    required bool isEager,
    required bool isShared,
    required bool isAsync,
  }) {
    if (isEager) return 'registerEagerSingleton';

    if (isShared) {
      return isAsync ? 'registerAsyncSingleton' : 'registerSingleton';
    }

    return isAsync ? 'registerAsyncFactory' : 'registerFactory';
  }

  void _generateBootCalls(List<ModuleData> modules) {
    if (modules.isEmpty) return;

    bool hasBootMethods = modules.any((m) => m.bootMethods.isNotEmpty);
    if (!hasBootMethods) {
      _buffer.writeln('    // No boot methods to execute');
      return;
    }

    _buffer.writeln('    // Execute boot methods');

    for (final module in modules) {
      if (module.bootMethods.isEmpty) continue;

      final moduleType = _getTypeName(module.element.thisType);

      for (final bootMethod in module.bootMethods) {
        final method = bootMethod.method;

        final returnType = switch (method) {
          MethodElement m => m.returnType,
          GetterElement g => g.returnType,
          _ => throw UnsupportedError(
            'Unsupported boot method type: ${method.runtimeType}',
          ),
        };

        final isAsync =
            returnType.isDartAsyncFuture || returnType.isDartAsyncFutureOr;

        _buffer.write('    ');
        if (isAsync) {
          _buffer.write('await ');
        }
        _buffer.write('i<$moduleType>().${method.name3}');

        if (method is MethodElement) {
          _buffer.write('(');
          final params = method.formalParameters;
          for (var i = 0; i < params.length; i++) {
            if (i > 0) _buffer.write(', ');
            final param = params[i];
            if (param.isNamed) {
              _buffer.write('${param.name3}: ');
            }

            // Use InjectInfo if available
            final injectInfo = i < bootMethod.parameterInjects.length
                ? bootMethod.parameterInjects[i]
                : null;
            _buffer.write(_generateInjectorCall(param, injectInfo));
          }
          _buffer.write(')');
        }

        _buffer.writeln(';');
      }
    }
  }

  void _generateServiceRegistrations(List<ServiceData> services) {
    if (services.isEmpty) return;

    _buffer.writeln('    // Register services');
    for (final service in services) {
      final serviceType = _getTypeName(service.element.thisType);

      // Find constructor (use default or first available)
      final constructor =
          service.element.unnamedConstructor2 ??
              service.element.constructors2.firstOrNull;

      if (constructor == null) continue;

      // Check if we have @Required methods or setters
      final hasRequired = service.requiredMethods.isNotEmpty ||
          service.requiredSetters.isNotEmpty;

      // Check if any @Required method is async
      final hasAsyncRequired = service.requiredMethods.any((m) {
        final returnType = m.element.returnType;
        return returnType.isDartAsyncFuture || returnType.isDartAsyncFutureOr;
      });

      // Register as singleton or factory
      if (service.isSingleton) {
        _buffer.writeln('    builder.registerSingleton<$serviceType>(');
      } else {
        _buffer.writeln('    builder.registerFactory<$serviceType>(');
      }

      _buffer.write('      (i) => $serviceType');

      final constructorName = constructor.name3!;
      if (constructorName.isNotEmpty && constructorName != 'new') {
        _buffer.write('.$constructorName');
      }

      _buffer.write('(');

      // Add constructor parameters
      final params = constructor.formalParameters;
      for (var i = 0; i < params.length; i++) {
        if (i > 0) _buffer.write(', ');
        final param = params[i];
        if (param.isNamed) {
          _buffer.write('${param.name3}: ');
        }

        // Use InjectInfo if available
        final injectInfo = i < service.constructorInjects.length
            ? service.constructorInjects[i]
            : null;
        _buffer.write(_generateInjectorCall(param, injectInfo));
      }

      _buffer.write(')');

      // Generate onCreate callback if there are @Required methods or setters
      if (hasRequired) {
        _buffer.writeln(',');
        if (hasAsyncRequired) {
          _buffer.writeln('      onCreate: (instance, i) async {');
        } else {
          _buffer.writeln('      onCreate: (instance, i) {');
        }

        // Generate calls to @Required setters
        for (final setter in service.requiredSetters) {
          final setterName = setter.element.name3;
          final param = setter.element.formalParameters.firstOrNull;

          if (param != null) {
            _buffer.write('        instance.$setterName = ');
            _buffer.write(_generateInjectorCall(param, setter.parameterInject));
            _buffer.writeln(';');
          }
        }

        // Generate calls to @Required methods
        for (final method in service.requiredMethods) {
          final methodName = method.element.name3;
          final returnType = method.element.returnType;
          final isAsync = returnType.isDartAsyncFuture ||
              returnType.isDartAsyncFutureOr;

          _buffer.write('        ');
          if (isAsync) {
            _buffer.write('await ');
          }
          _buffer.write('instance.$methodName(');

          final methodParams = method.element.formalParameters;
          for (var i = 0; i < methodParams.length; i++) {
            if (i > 0) _buffer.write(', ');
            final param = methodParams[i];
            if (param.isNamed) {
              _buffer.write('${param.name3}: ');
            }

            final injectInfo = i < method.parameterInjects.length
                ? method.parameterInjects[i]
                : null;
            _buffer.write(_generateInjectorCall(param, injectInfo));
          }

          _buffer.writeln(');');
        }

        _buffer.writeln('      },');
      } else {
        _buffer.writeln(',');
      }

      _buffer.writeln('    );');
    }
  }

  Future<void> _generateClassMetadata(ClassData classData) async {
    final element = classData.element;
    final typeStr = _getTypeName(element.thisType);

    _buffer.writeln('    metaBuilder.registerClass<$typeStr>(');
    _buffer.writeln('      meta.clazz(');
    _buffer.write('        ${_generateMetaType(element.thisType)}');
    _buffer.writeln(',');

    // Annotations - use the element to extract metadata
    _buffer.write('        ');
    await _generateAnnotationsFromElement(element);
    _buffer.writeln(',');

    // Constructors
    if (classData.constructors != null && classData.constructors!.isNotEmpty) {
      _buffer.writeln('        [');
      for (final constructor in classData.constructors!) {
        await _generateConstructorMetadata(element, constructor);
      }
      _buffer.writeln('        ],');
    } else {
      _buffer.writeln('        null, // constructors');
    }

    // Methods
    if (classData.methods != null && classData.methods!.isNotEmpty) {
      _buffer.writeln('        [');
      for (final method in classData.methods!) {
        await _generateMethodMetadata(method);
      }
      _buffer.writeln('        ],');
    } else {
      _buffer.writeln('        null, // methods');
    }

    // Getters
    if (classData.getters != null && classData.getters!.isNotEmpty) {
      _buffer.writeln('        [');
      for (final getter in classData.getters!) {
        await _generateGetterMetadata(getter);
      }
      _buffer.writeln('        ],');
    } else {
      _buffer.writeln('        null, // getters');
    }

    // Setters
    if (classData.setters != null && classData.setters!.isNotEmpty) {
      _buffer.writeln('        [');
      for (final setter in classData.setters!) {
        await _generateSetterMetadata(setter);
      }
      _buffer.writeln('        ],');
    } else {
      _buffer.writeln('        null, // setters');
    }

    _buffer.writeln('      ),');
    _buffer.writeln('    );');
    _buffer.writeln();
  }

  Future<void> _generateConstructorMetadata(
      ClassElement2 classElement,
      ConstructorData constructor,
      ) async {
    final element = constructor.element;
    final className = _getTypeName(classElement.thisType);

    _buffer.writeln('          meta.constructor(');
    _buffer.write('            () => $className');

    final constructorName = element.name3!;
    if (constructorName.isNotEmpty) {
      _buffer.write('.$constructorName');
    } else {
      _buffer.write('.new');
    }

    _buffer.writeln(',');

    // Parameters - usar formalParameters
    _buffer.writeln('            [');
    final params = element.formalParameters;
    for (var i = 0; i < params.length; i++) {
      final param = params[i];
      await _generateParameterMetadata(param, i);
    }
    _buffer.writeln('            ],');

    // Name
    _buffer.writeln("            '$constructorName',");

    // Annotations - use the element
    _buffer.write('            ');
    await _generateAnnotationsFromElement(element);
    _buffer.writeln(',');

    _buffer.writeln('          ),');
  }

  Future<void> _generateParameterMetadata(
      FormalParameterElement param,
      int index,
      ) async {
    final isOptional = param.isOptional;
    final isNamed = param.isNamed;

    _buffer.write('              meta.parameter(');
    _buffer.write('${_generateMetaType(param.type)}, ');
    _buffer.write("'${param.name3}', ");
    _buffer.write('$index, ');
    _buffer.write('$isOptional, ');
    _buffer.write('$isNamed');

    _buffer.write(', ${param.defaultValueCode ?? 'null'}');

    _buffer.writeln(',');
    await _generateAnnotationsFromElement(param);

    _buffer.writeln('),');
  }

  Future<void> _generateMethodMetadata(MethodData method) async {
    final element = method.element;

    _buffer.writeln('          meta.method(');
    _buffer.write('            ${_generateMetaType(element.returnType)}');
    _buffer.writeln(',');
    _buffer.writeln("            '${element.name3}',");
    _buffer.writeln('            (instance) => instance.${element.name3},');

    // Parameters
    final params = element.formalParameters;
    if (params.isNotEmpty) {
      _buffer.writeln('            [');
      for (var i = 0; i < params.length; i++) {
        final param = params[i];
        await _generateParameterMetadata(param, i);
      }
      _buffer.writeln('            ],');
    } else {
      _buffer.writeln('            null, // parameters');
    }

    // Annotations - use the element
    _buffer.write('            ');
    await _generateAnnotationsFromElement(element);
    _buffer.writeln(',');

    _buffer.writeln('          ),');
  }

  Future<void> _generateGetterMetadata(GetterData getter) async {
    final element = getter.element;

    _buffer.writeln('          meta.getter(');
    _buffer.write('            ${_generateMetaType(element.returnType)}');
    _buffer.writeln(',');
    _buffer.writeln("            '${element.name3}',");
    _buffer.writeln('            (instance) => instance.${element.name3},');

    // Annotations - use the element
    _buffer.write('            ');
    if (element.variable3 != null ) {
      await _generateAnnotationsFromElement(element.variable3!);
      _buffer.writeln(',');
    }

    _buffer.writeln('          ),');
  }

  Future<void> _generateSetterMetadata(SetterData setter) async {
    final element = setter.element;
    final params = element.formalParameters;
    if (params.isEmpty) return; // Setters must have parameters

    final param = params.first;

    _buffer.writeln('          meta.setter(');
    _buffer.write('            ${_generateMetaType(param.type)}');
    _buffer.writeln(',');
    _buffer.writeln("            '${element.name3}',");
    _buffer.writeln(
      '            (instance, value) => instance.${element.name3} = value,',
    );

    // Annotations - use the element
    _buffer.write('            ');
    if (element.variable3 != null ) {
      await _generateAnnotationsFromElement(element.variable3!);
      _buffer.writeln(',');
    }

    _buffer.writeln('          ),');
  }

  Future<void> _generateEnumMetadata(EnumData enumData) async {
    final element = enumData.element;
    final typeStr = _getTypeName(element.thisType);

    _buffer.writeln('    metaBuilder.registerEnum<$typeStr>(');
    _buffer.writeln('      meta.enumMeta(');
    _buffer.write('        ${_generateMetaType(element.thisType)}');
    _buffer.writeln(',');

    // Annotations - use the element
    _buffer.write('        ');
    await _generateAnnotationsFromElement(element);
    _buffer.writeln(',');

    // Values
    _buffer.writeln('        [');
    for (var i = 0; i < enumData.values.length; i++) {
      final value = enumData.values[i];
      await _generateEnumValueMetadata(value, i, typeStr);
    }
    _buffer.writeln('        ],');

    // Getters
    if (enumData.getters != null && enumData.getters!.isNotEmpty) {
      _buffer.writeln('        [');
      for (final getter in enumData.getters!) {
        await _generateGetterMetadata(getter);
      }
      _buffer.writeln('        ],');
    } else {
      _buffer.writeln('        null, // getters');
    }

    _buffer.writeln('      ),');
    _buffer.writeln('    );');
    _buffer.writeln();
  }

  Future<void> _generateEnumValueMetadata(
      EnumValueData value,
      int index,
      String enumType,
      ) async {
    final element = value.element;
    final elementName = element.name3;

    _buffer.writeln('          meta.enumValue(');
    _buffer.writeln("            '$elementName',");
    _buffer.writeln('            $enumType.$elementName,');
    _buffer.writeln('            $index,');

    // Annotations - use the element
    _buffer.write('            ');
    await _generateAnnotationsFromElement(element);
    _buffer.writeln(',');

    _buffer.writeln('          ),');
  }

  /// Generate annotations using the AnnotationCodeGenerator
  Future<void> _generateAnnotationsFromElement(Element2 element) async {
    final code = await annotationGenerator.extractMetadataCode(
      element,
      inputId,
    );
    _buffer.write(code);
  }

  /// Generate type name with proper prefix handling
  String _getTypeName(DartType type, {bool showNullability = false}) {
    if (type is DynamicType) return 'dynamic';
    if (type is VoidType) return 'void';

    if (type is InterfaceType) {
      final element = type.element3;
      final library = element.library2;

      // Get prefix (will be empty for dart:core)
      String prefix = importCollector.getPrefix(library);
      String typeName = prefix.isEmpty
          ? element.name3!
          : '${prefix.substring(0, prefix.length - 1)}.${element.name3}';

      // Handle type arguments (generics)
      if (type.typeArguments.isNotEmpty) {
        final args = type.typeArguments
            .map((arg) => _getTypeName(arg, showNullability: showNullability))
            .join(', ');
        typeName = '$typeName<$args>';
      }

      // Handle nullability
      if (type.nullabilitySuffix == NullabilitySuffix.question && !showNullability) {
        typeName = '$typeName?';
      }

      return typeName;
    }

    // Fallback for other types

    return type.getDisplayString(withNullability: !showNullability);
  }

  /// Generate meta.type() call with proper arguments and nullability
  String _generateMetaType(DartType type) {
    if (type is DynamicType) return 'meta.type<dynamic>()';
    if (type is VoidType) return 'meta.type<void>()';

    if (type is InterfaceType) {
      final element = type.element3;
      final library = element.library2;

      // Build type name with prefix
      String prefix = importCollector.getPrefix(library);
      String typeName = prefix.isEmpty
          ? element.name3!
          : '${prefix.substring(0, prefix.length - 1)}.${element.name3}';

      // Build type arguments for generics
      final hasTypeArgs = type.typeArguments.isNotEmpty;
      final isNullable = type.nullabilitySuffix == NullabilitySuffix.question;

      if (hasTypeArgs) {
        final typeArgsString = type.typeArguments
            .map((arg) => _getTypeName(arg, showNullability: true))
            .join(', ');

        final metaTypeArgs = type.typeArguments
            .map((arg) => _generateMetaType(arg))
            .join(', ');

        return 'meta.type<$typeName<$typeArgsString>>([$metaTypeArgs]${isNullable ? ', true' : ''})';
      } else {
        // Simple type: meta.type<String>([], nullable)
        if (isNullable) {
          return 'meta.type<$typeName>([], true)';
        } else {
          return 'meta.type<$typeName>()';
        }
      }
    }

    // Fallback
    final typeStr = type.getDisplayString(withNullability: true);
    return 'meta.type<$typeStr>()';
  }

  DartType _extractTypeFromFuture(DartType type) {
    if (type is InterfaceType &&
        (type.isDartAsyncFuture || type.isDartAsyncFutureOr)) {
      if (type.typeArguments.isNotEmpty) {
        return type.typeArguments.first;
      }
    }
    return type;
  }

  /// Generate injector call based on InjectInfo
  /// If InjectInfo has injectType, use that type instead of param.type
  /// If InjectInfo has name, add the name parameter
  String _generateInjectorCall(
      FormalParameterElement param,
      InjectInfo? injectInfo,
      ) {
    // Determine the type to use
    final DartType typeToUse = injectInfo?.injectType ?? param.type;
    final String typeName = _getTypeName(typeToUse, showNullability: false);

    // Build the injector call
    if (injectInfo?.name != null) {
      return "i('${injectInfo!.name}')";
    } else {
      return 'i<$typeName>()';
    }
  }
}