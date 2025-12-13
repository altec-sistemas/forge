// lib/src/forge_driver.dart
import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:colorize/colorize.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import 'bundle_generator.dart';
import 'cli_adapters.dart';

class ForgeDriver {
  final String rootDir;
  final Logger logger;

  ForgeDriver(this.rootDir, {Logger? logger}) : logger = logger ?? Logger();

  /// Processa todos os packages
  Future<void> run() async {
    final collection = AnalysisContextCollection(
      includedPaths: [rootDir],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );

    final contextCount = collection.contexts.length;
    logger.info('Found $contextCount package(s) to analyze\n');

    for (final context in collection.contexts) {
      final packageRoot = context.contextRoot.root.path;
      final packageName = p.basename(packageRoot);

      await _processContext(context, packageName);
    }

    logger.success('All packages processed');
  }

  /// Processa apenas um package específico
  Future<void> runForPackage(String packagePath) async {
    final collection = AnalysisContextCollection(
      includedPaths: [packagePath],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );

    if (collection.contexts.isEmpty) {
      logger.warn('No analysis context found for $packagePath');
      return;
    }

    final context = collection.contexts.first;
    final packageName = p.basename(packagePath);

    await _processContext(context, packageName);
  }

  Future<void> _processContext(
    AnalysisContext context,
    String packageName,
  ) async {
    final progress = logger.progress(
      '${_package(packageName)} Processing package',
    );

    try {
      final packageRoot = context.contextRoot.root.path;

      // ✅ FILTRAR PRIMEIRO - não deixar o analyzer processar tudo
      final dartFiles = context.contextRoot
          .analyzedFiles()
          .where(_shouldAnalyze) // 👈 Filtro inteligente
          .toList();

      if (dartFiles.isEmpty) {
        progress.complete('${_package(packageName)} No files to process');
        return;
      }

      // ✅ Criar contexto customizado apenas com arquivos relevantes
      final resolverAdapter = ResolverAdapter(
        context.currentSession,
        context,
        packageRoot,
      );

      int generatedCount = 0;
      final bundleFiles = <String>[];

      // ✅ PRIMEIRA PASSAGEM: Identificar apenas arquivos com @AutoBundle
      for (final filePath in dartFiles) {
        if (await _hasAutoBundleAnnotation(context.currentSession, filePath)) {
          bundleFiles.add(filePath);
        }
      }

      // ✅ SEGUNDA PASSAGEM: Processar apenas os relevantes
      for (final filePath in bundleFiles) {
        final generated = await _processFile(
          context.currentSession,
          filePath,
          packageRoot,
          resolverAdapter,
        );

        if (generated) {
          generatedCount++;
        }
      }

      if (generatedCount > 0) {
        progress.complete(
          '${_package(packageName)} Generated $generatedCount file(s)',
        );
      } else {
        progress.complete('${_package(packageName)} No files generated');
      }
    } catch (e) {
      progress.fail('${_package(packageName)} Failed: $e');
    }
  }

  // ✅ Filtro eficiente
  bool _shouldAnalyze(String path) {
    // Ignora completamente esses diretórios
    if (path.contains('/.dart_tool/') ||
        path.contains('/build/') ||
        path.contains('/.pub-cache/') ||
        path.contains('/test/') ||
        path.contains('/example/')) {
      return false;
    }

    // Ignora arquivos gerados
    if (path.endsWith('.g.dart') ||
        path.endsWith('.bundle.dart') ||
        path.endsWith('.freezed.dart') ||
        path.endsWith('.gr.dart')) {
      return false;
    }

    return path.endsWith('.dart');
  }

  // ✅ Verificação rápida sem análise completa
  Future<bool> _hasAutoBundleAnnotation(
    AnalysisSession session,
    String filePath,
  ) async {
    try {
      // Primeiro, tenta ler o arquivo e buscar a string
      final file = File(filePath);
      final content = await file.readAsString();

      // Verificação rápida por string (muito mais rápido que parse)
      if (!content.contains('@AutoBundle') && !content.contains('AutoBundle')) {
        return false;
      }

      // Só se encontrou a string, faz o parse completo
      final parseResult = session.getParsedLibrary(filePath);
      if (parseResult is ParsedLibraryResult) {
        return parseResult.units.any(
          (unit) => unit.unit.declarations.any(
            (decl) =>
                decl is ClassDeclaration &&
                decl.metadata.any((m) => m.name.name == 'AutoBundle'),
          ),
        );
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _processFile(
    AnalysisSession session,
    String filePath,
    String packageRoot,
    ResolverAdapter resolverAdapter,
  ) async {
    try {
      final result = await session.getResolvedLibrary(filePath);

      if (result is! ResolvedLibraryResult) return false;

      final library = result.element2;

      for (final element in library.classes) {
        final hasAnnotation = element.metadata2.annotations.any(
          (meta) => meta.element2?.enclosingElement2?.name3 == 'AutoBundle',
        );

        if (!hasAnnotation) continue;

        final annotation = element.metadata2.annotations
            .firstWhere(
              (m) => m.element2?.enclosingElement2?.name3 == 'AutoBundle',
            )
            .computeConstantValue();

        if (annotation == null) continue;

        final relativePath = p.relative(filePath, from: packageRoot);
        final pkgName = p.basename(packageRoot);
        final inputId = AssetIdAdapter(pkgName, relativePath);

        final buildStep = BuildStepAdapter(
          inputId,
          resolverAdapter,
          packageRoot,
        );

        final generator = BundleGenerator(
          buildStep: buildStep,
          resolver: resolverAdapter,
          bundleClass: element,
          annotation: annotation,
        );

        final code = await generator.generate();

        if (code.isNotEmpty) {
          final outputPath = p.setExtension(filePath, '.bundle.dart');
          await File(outputPath).writeAsString(code);
          return true;
        }
      }

      return false;
    } catch (e, stack) {
      if (logger.level == Level.verbose) {
        logger.err('Error processing ${p.basename(filePath)}: $e');
        logger.detail(stack.toString());
      }
      return false;
    }
  }
}

String _package(String package) {
  return Colorize("[$package]").cyan().bold().toString();
}
