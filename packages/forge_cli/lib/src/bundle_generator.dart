import 'dart:async';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element2.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as p;

import 'annotation_code_generator.dart';
import 'annotation_processor.dart';
import 'code_emitter.dart';
import 'import_collector.dart';

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

  Future<String> generate() async {
    final pathsField = annotation.getField('paths');
    final excludePathsField = annotation.getField('excludePaths');

    final paths = _readStringList(pathsField) ?? ['lib/**.dart'];
    final excludePaths = _readStringList(excludePathsField) ?? [];

    final importCollector = ImportCollector(buildStep.inputId, resolver);

    final scannedData = await _scanFiles(paths, excludePaths, importCollector);

    final annotationGenerator = AnnotationCodeGenerator(
      importCollector,
      resolver,
    );

    final codeEmitter = CodeEmitter(
      importCollector,
      annotationGenerator,
      buildStep.inputId,
    );

    final generatedCode = await codeEmitter.generateBundleCode(
      bundleClassName: bundleClass.name3!,
      scannedData: scannedData,
    );

    try {
      final formatter = DartFormatter(
        languageVersion: DartFormatter.latestLanguageVersion,
      );
      return formatter.format(generatedCode);
    } catch (e) {
      return generatedCode;
    }
  }

  Future<ScannedData> _scanFiles(
    List<String> paths,
    List<String> excludePaths,
    ImportCollector importCollector,
  ) async {
    final scannedData = ScannedData();
    final processedFiles = <String>{};

    final inputPath = buildStep.inputId.path;
    final baseDir = _getPackageRoot(inputPath);

    // ✅ COLETAR TODOS OS ASSETS PRIMEIRO
    final allAssets = <AssetId>[];
    for (final pattern in paths) {
      final adjustedPattern = _adjustPattern(pattern, baseDir);
      final glob = Glob(adjustedPattern);

      await for (final asset in buildStep.findAssets(glob)) {
        final assetPath = asset.path;

        if (processedFiles.contains(assetPath)) continue;
        if (_shouldExclude(assetPath, excludePaths, baseDir)) continue;
        if (_isGeneratedFile(assetPath)) continue;

        processedFiles.add(assetPath);
        allAssets.add(asset);
      }
    }

    // ✅ PROCESSAR EM LOTE COM LIMITE DE CONCORRÊNCIA
    const concurrentLimit = 5;
    for (var i = 0; i < allAssets.length; i += concurrentLimit) {
      final batch = allAssets.skip(i).take(concurrentLimit);
      final futures = batch.map(
        (asset) => _processAsset(asset, importCollector),
      );

      final results = await Future.wait(futures);

      for (final result in results) {
        if (result != null) {
          scannedData.merge(result);
        }
      }
    }

    return scannedData;
  }

  /// ✅ PROCESSAR ASSET INDIVIDUAL
  Future<ScannedData?> _processAsset(
    AssetId asset,
    ImportCollector importCollector,
  ) async {
    try {
      final library = await buildStep.resolver.libraryFor(asset);

      final processor = AnnotationProcessor(
        resolver,
        library,
        importCollector: importCollector,
      );

      await processor.process();
      return processor.data;
    } catch (_) {
      return null;
    }
  }

  String _getPackageRoot(String inputPath) {
    final normalized = p.normalize(inputPath);
    final parts = p.split(normalized);
    final libIndex = parts.indexOf('lib');

    if (libIndex <= 0) return '';

    return '${p.joinAll(parts.sublist(0, libIndex))}/';
  }

  String _adjustPattern(String pattern, String baseDir) {
    if (baseDir.isEmpty) return pattern;
    if (pattern.startsWith('lib/')) return '$baseDir$pattern';
    if (pattern.startsWith('/')) return pattern;
    return '$baseDir$pattern';
  }

  bool _shouldExclude(
    String assetPath,
    List<String> excludePatterns,
    String baseDir,
  ) {
    for (final pattern in excludePatterns) {
      final adjustedPattern = _adjustPattern(pattern, baseDir);
      final glob = Glob(adjustedPattern);
      if (glob.matches(assetPath)) return true;
    }
    return false;
  }

  bool _isGeneratedFile(String path) {
    return path.contains('.g.dart') ||
        path.contains('.reflectable.dart') ||
        path.contains('.bundle.dart');
  }

  List<String>? _readStringList(DartObject? object) {
    if (object == null || object.isNull) return null;

    final list = object.toListValue();
    if (list == null) return null;

    return list.map((e) => e.toStringValue()).whereType<String>().toList();
  }
}

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

class ClassData {
  final ClassElement2 element;
  final List<ConstructorData>? constructors;
  final List<MethodData>? methods;
  final List<GetterData>? getters;
  final List<SetterData>? setters;
  final bool hasMetadata;
  final List<RequiredMethodData>? requiredMethods;
  final List<RequiredSetterData>? requiredSetters;
  final bool hasProxyCapability;

  ClassData({
    required this.element,
    this.constructors,
    this.methods,
    this.getters,
    this.setters,
    this.hasMetadata = false,
    this.requiredMethods,
    this.requiredSetters,
    this.hasProxyCapability = false,
  });
}

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

class InjectInfo {
  final DartType? injectType;
  final String? name;
  final bool hasInject;

  InjectInfo({this.injectType, this.name, this.hasInject = false});

  factory InjectInfo.none() => InjectInfo(hasInject: false);
}

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

class GetterData {
  final GetterElement element;

  GetterData({required this.element});
}

class SetterData {
  final SetterElement element;

  SetterData({required this.element});
}

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

class ServiceData {
  final ClassElement2 element;
  final bool isSingleton;
  final DartObject annotation;
  final List<InjectInfo> constructorInjects;
  final List<RequiredMethodData> requiredMethods;
  final List<RequiredSetterData> requiredSetters;
  final String? env;

  ServiceData({
    required this.element,
    required this.annotation,
    required this.isSingleton,
    required this.constructorInjects,
    this.requiredMethods = const [],
    this.requiredSetters = const [],
    this.env,
  });
}

class EnumData {
  final EnumElement2 element;
  final List<EnumValueData> values;
  final List<GetterData>? getters;

  EnumData({required this.element, required this.values, this.getters});
}

class EnumValueData {
  final FieldElement2 element;

  EnumValueData({required this.element});
}

class RequiredMethodData {
  final MethodElement2 element;
  final List<InjectInfo> parameterInjects;

  RequiredMethodData({required this.element, required this.parameterInjects});
}

class RequiredSetterData {
  final SetterElement element;
  final InjectInfo? parameterInject;

  RequiredSetterData({required this.element, this.parameterInject});
}
