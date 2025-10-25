import 'dart:async';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element2.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:dart_style/dart_style.dart';

import 'annotation_code_generator.dart';
import 'annotation_processor.dart';
import 'code_emitter.dart';
import 'import_collector.dart';

/// Main generator for @AutoBundle annotated classes
class BundleGenerator {
  final BuildStep buildStep;
  final Resolver resolver;
  final ClassElement2 bundleClass;
  final DartObject annotation;

  BundleGenerator({
    required this.buildStep,
    required this.resolver,
    required this.bundleClass,
    required this.annotation,
  });

  /// Generate the complete bundle implementation
  Future<String> generate() async {
    // Parse annotation parameters
    final pathsField = annotation.getField('paths');
    final excludePathsField = annotation.getField('excludePaths');

    final paths = _readStringList(pathsField) ?? ['lib/**.dart'];
    final excludePaths = _readStringList(excludePathsField) ?? [];

    // Create import collector FIRST
    final importCollector = ImportCollector(buildStep.inputId, resolver);

    // Scan all files matching the patterns
    final scannedData = await _scanFiles(paths, excludePaths, importCollector);

    final annotationGenerator = AnnotationCodeGenerator(
      importCollector,
      resolver,
    );

    // Generate code - pass inputId to CodeEmitter
    final codeEmitter = CodeEmitter(
      importCollector,
      annotationGenerator,
      buildStep.inputId,
    );

    final generatedCode = await codeEmitter.generateBundleCode(
      bundleClassName: bundleClass.name3!,
      scannedData: scannedData,
    );

    // Format the generated code
    try {
      final formatter = DartFormatter(
        languageVersion: DartFormatter.latestLanguageVersion,
      );
      return formatter.format(generatedCode);
    } catch (e) {
      log.warning('Failed to format generated code: $e');
      return generatedCode;
    }
  }

  /// Scan files matching the given patterns
  Future<ScannedData> _scanFiles(
    List<String> paths,
    List<String> excludePaths,
    ImportCollector importCollector,
  ) async {
    final scannedData = ScannedData();
    final processedFiles = <String>{};

    for (final pattern in paths) {
      final glob = Glob(pattern);

      await for (final asset in buildStep.findAssets(glob)) {
        final assetPath = asset.path;

        // Skip if already processed
        if (processedFiles.contains(assetPath)) continue;

        // Skip if matches exclude patterns
        if (_shouldExclude(assetPath, excludePaths)) continue;

        // Skip generated files
        if (assetPath.contains('.g.dart') ||
            assetPath.contains('.reflectable.dart') ||
            assetPath.contains('.bundle.dart')) {
          continue;
        }

        processedFiles.add(assetPath);

        try {
          // Read and analyze the file
          final library = await buildStep.resolver.libraryFor(asset);

          // Pass the importCollector to the processor
          final processor = AnnotationProcessor(
            resolver,
            library,
            importCollector: importCollector,
          );

          await processor.process();

          // Merge results
          scannedData.merge(processor.data);
        } catch (e) {
          log.warning('Error processing $assetPath: $e');
        }
      }
    }

    return scannedData;
  }

  bool _shouldExclude(String assetPath, List<String> excludePatterns) {
    for (final pattern in excludePatterns) {
      final glob = Glob(pattern);
      if (glob.matches(assetPath)) {
        return true;
      }
    }
    return false;
  }

  List<String>? _readStringList(DartObject? object) {
    if (object == null || object.isNull) return null;

    final list = object.toListValue();
    if (list == null) return null;

    return list.map((e) => e.toStringValue()).whereType<String>().toList();
  }
}

/// Data collected from scanning files
class ScannedData {
  final List<ClassData> classes = [];
  final List<ModuleData> modules = [];
  final List<ServiceData> services = [];
  final List<EnumData> enums = [];

  void merge(ScannedData other) {
    classes.addAll(other.classes);
    modules.addAll(other.modules);
    services.addAll(other.services);
    enums.addAll(other.enums);
  }

  bool get isEmpty =>
      classes.isEmpty && modules.isEmpty && services.isEmpty && enums.isEmpty;
}

/// Data about a class with metadata
class ClassData {
  final ClassElement2 element;
  final List<ConstructorData>? constructors;
  final List<MethodData>? methods;
  final List<GetterData>? getters;
  final List<SetterData>? setters;
  final bool hasMetadata;
  final List<RequiredMethodData>? requiredMethods;
  final List<RequiredSetterData>? requiredSetters;

  ClassData({
    required this.element,
    this.constructors,
    this.methods,
    this.getters,
    this.setters,
    this.hasMetadata = false,
    this.requiredMethods,
    this.requiredSetters,
  });
}

/// Data about a constructor
class ConstructorData {
  final ConstructorElement2 element;
  final List<DartObject> annotations;
  final List<InjectInfo> parameterInjects;

  ConstructorData({
    required this.element,
    required this.annotations,
    required this.parameterInjects,
  });
}

/// Information about @Inject annotation on a parameter
class InjectInfo {
  /// The type specified in [@Inject<Type>()], null if not specified
  final DartType? injectType;

  /// The name specified in @Inject(name: 'name'), null if not specified
  final String? name;

  /// Whether this parameter has @Inject annotation
  final bool hasInject;

  InjectInfo({
    this.injectType,
    this.name,
    this.hasInject = false,
  });

  factory InjectInfo.none() => InjectInfo(hasInject: false);
}

/// Data about a method
class MethodData {
  final MethodElement2 element;
  final List<DartObject> annotations;
  final List<InjectInfo> parameterInjects;

  MethodData({
    required this.element,
    required this.annotations,
    required this.parameterInjects,
  });
}

/// Data about a getter
class GetterData {
  final GetterElement element;

  GetterData({
    required this.element,
  });
}

/// Data about a setter
class SetterData {
  final SetterElement element;

  SetterData({
    required this.element,
  });
}

/// Data about a module
class ModuleData {
  final ClassElement2 element;
  final List<ProviderData> providers;
  final List<BootMethodData> bootMethods;

  ModuleData({
    required this.element,
    required this.providers,
    required this.bootMethods,
  });
}

class BootMethodData {
  final ExecutableElement2 method;
  final DartObject annotation;
  final List<InjectInfo> parameterInjects;

  BootMethodData({
    required this.method,
    required this.annotation,
    required this.parameterInjects,
  });
}

/// Data about a provider method
class ProviderData {
  final FunctionTypedElement2 method;
  final DartObject annotation;
  final String? name;
  final String? env;
  final bool shared;
  final bool eager;
  final int? priority;
  final List<InjectInfo> parameterInjects;

  ProviderData({
    required this.method,
    required this.annotation,
    this.name,
    this.env,
    required this.shared,
    this.eager = false,
    this.priority,
    required this.parameterInjects,
  });
}

/// Data about a service (class with @Injectable)
class ServiceData {
  final ClassElement2 element;
  final bool isSingleton;
  final DartObject annotation;
  final List<InjectInfo> constructorInjects;
  final List<RequiredMethodData> requiredMethods;
  final List<RequiredSetterData> requiredSetters;

  ServiceData({
    required this.element,
    required this.annotation,
    required this.isSingleton,
    required this.constructorInjects,
    this.requiredMethods = const [],
    this.requiredSetters = const [],
  });
}

/// Data about an enum
class EnumData {
  final EnumElement2 element;
  final List<EnumValueData> values;
  final List<GetterData>? getters;

  EnumData({
    required this.element,
    required this.values,
    this.getters,
  });
}

/// Data about an enum value
class EnumValueData {
  final FieldElement2 element;

  EnumValueData({
    required this.element,
  });
}

/// Data about a method marked with @Required
class RequiredMethodData {
  final MethodElement2 element;
  final List<InjectInfo> parameterInjects;

  RequiredMethodData({
    required this.element,
    required this.parameterInjects,
  });
}

/// Data about a setter marked with @Required
class RequiredSetterData {
  final SetterElement element;
  final InjectInfo? parameterInject;

  RequiredSetterData({
    required this.element,
    this.parameterInject,
  });
}
