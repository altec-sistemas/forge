// lib/src/cli_adapters.dart
import 'dart:async';
import 'dart:convert' show utf8, Encoding;
import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/element2.dart';
import 'package:analyzer/src/dart/ast/ast.dart';
import 'package:build/build.dart';
import 'package:crypto/src/digest.dart';
import 'package:glob/glob.dart';
import 'package:package_config/src/package_config.dart';
import 'package:path/path.dart' as p;

/// Adapter que simula o AssetId do build_runner
class AssetIdAdapter implements AssetId {
  @override
  final String package;

  @override
  final String path;

  AssetIdAdapter(this.package, this.path);

  factory AssetIdAdapter.fromPath(String absolutePath, String packageRoot) {
    final relativePath = p.relative(absolutePath, from: packageRoot);
    final packageName = p.basename(packageRoot);
    return AssetIdAdapter(packageName, relativePath);
  }

  @override
  Uri get uri => _constructUri(this);

  @override
  AssetId addExtension(String extension) {
    return AssetIdAdapter(package, '$path$extension');
  }

  @override
  AssetId changeExtension(String newExtension) {
    return AssetIdAdapter(package, p.setExtension(path, newExtension));
  }

  @override
  String toString() => '$package|$path';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetId &&
          runtimeType == other.runtimeType &&
          package == other.package &&
          path == other.path;

  @override
  int get hashCode => package.hashCode ^ path.hashCode;

  @override
  int compareTo(AssetId other) {
    // TODO: implement compareTo
    throw UnimplementedError();
  }

  @override
  // TODO: implement extension
  String get extension => throw UnimplementedError();

  @override
  // TODO: implement pathSegments
  List<String> get pathSegments => throw UnimplementedError();

  @override
  Object serialize() {
    // TODO: implement serialize
    throw UnimplementedError();
  }
}

/// Adapter que simula o Resolver do build_runner usando o Analyzer
class ResolverAdapter implements Resolver {
  final AnalysisSession session;
  final AnalysisContext context;
  final String packageRoot;

  ResolverAdapter(this.session, this.context, this.packageRoot);

  @override
  Future<LibraryElement2> libraryFor(
    AssetId assetId, {
    bool allowSyntaxErrors = false,
  }) async {
    final absolutePath = p.join(packageRoot, assetId.path);
    final result = await session.getResolvedLibrary(absolutePath);

    if (result is ResolvedLibraryResult) {
      return result.element2;
    }

    throw Exception('Failed to resolve library for $assetId');
  }

  @override
  Future<AssetId> assetIdForElement(Element2 element) async {
    if (element is MultiplyDefinedElement2) {
      throw UnresolvableAssetException('${element.name3} is ambiguous');
    }

    final source = element.firstFragment.libraryFragment?.source;
    if (source == null) {
      throw UnresolvableAssetException(
        '${element.name3} does not have a source',
      );
    }

    final uri = source.uri;
    if (!uri.isScheme('package') && !uri.isScheme('asset')) {
      throw UnresolvableAssetException('${element.name3} in ${source.uri}');
    }
    return AssetId.resolve(source.uri);
  }

  @override
  Stream<LibraryElement2> get libraries async* {
    for (final filePath in context.contextRoot.analyzedFiles()) {
      if (!filePath.endsWith('.dart')) continue;

      try {
        final result = await session.getResolvedLibrary(filePath);
        if (result is ResolvedLibraryResult) {
          yield result.element2;
        }
      } catch (e) {
        // Ignore files that can't be resolved
      }
    }
  }

  @override
  Future<bool> isLibrary(AssetId assetId) async {
    try {
      await libraryFor(assetId);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<LibraryElement2?> findLibraryByName(String libraryName) async {
    await for (final library in libraries) {
      if (library.name3 == libraryName) {
        return library;
      }
    }
    return null;
  }

  @override
  Future<AstNode?> astNodeFor(Fragment fragment, {bool resolve = false}) {
    // TODO: implement astNodeFor
    throw UnimplementedError();
  }

  @override
  Future<CompilationUnit> compilationUnitFor(
    AssetId assetId, {
    bool allowSyntaxErrors = false,
  }) {
    // TODO: implement compilationUnitFor
    throw UnimplementedError();
  }
}

/// Adapter que simula o BuildStep do build_runner
class BuildStepAdapter implements BuildStep {
  @override
  final AssetId inputId;

  final ResolverAdapter _resolver;
  final String packageRoot;

  BuildStepAdapter(this.inputId, this._resolver, this.packageRoot);

  @override
  ResolverAdapter get resolver => _resolver;

  @override
  Stream<AssetId> findAssets(Glob glob) async* {
    final pattern = glob.pattern;
    final directory = Directory(packageRoot);

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        final relativePath = p.relative(entity.path, from: packageRoot);
        if (glob.matches(relativePath)) {
          yield AssetIdAdapter(inputId.package, relativePath);
        }
      }
    }
  }

  @override
  Future<String> readAsString(AssetId id, {Encoding encoding = utf8}) async {
    final absolutePath = p.join(packageRoot, id.path);
    final file = File(absolutePath);
    return file.readAsString(encoding: encoding);
  }

  @override
  Future<List<int>> readAsBytes(AssetId id) async {
    final absolutePath = p.join(packageRoot, id.path);
    final file = File(absolutePath);
    return file.readAsBytes();
  }

  @override
  Future<bool> canRead(AssetId id) async {
    final absolutePath = p.join(packageRoot, id.path);
    return File(absolutePath).exists();
  }

  @override
  Future<void> writeAsString(
    AssetId id,
    FutureOr<String> contents, {
    Encoding encoding = utf8,
  }) async {
    final absolutePath = p.join(packageRoot, id.path);
    final file = File(absolutePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(await contents, encoding: encoding);
  }

  @override
  Future<void> writeAsBytes(AssetId id, FutureOr<List<int>> bytes) async {
    final absolutePath = p.join(packageRoot, id.path);
    final file = File(absolutePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(await bytes);
  }

  @override
  Future<T> fetchResource<T>(Resource<T> resource) =>
      throw UnimplementedError();

  @override
  void reportUnusedAssets(Iterable<AssetId> ids) {}

  @override
  Iterable<AssetId> get allowedOutputs => throw UnimplementedError();

  @override
  Future<LibraryElement2> get inputLibrary => throw UnimplementedError();

  @override
  Future<PackageConfig> get packageConfig => throw UnimplementedError();

  @override
  Future<Digest> digest(AssetId id) {
    // TODO: implement digest
    throw UnimplementedError();
  }

  @override
  T trackStage<T>(
    String label,
    T Function() action, {
    bool isExternal = false,
  }) {
    // TODO: implement trackStage
    throw UnimplementedError();
  }
}

Uri _constructUri(AssetId id) {
  final originalSegments = id.pathSegments;
  final isLib = originalSegments.first == 'lib';
  final scheme = isLib ? 'package' : 'asset';
  final pathSegments = isLib ? originalSegments.skip(1) : originalSegments;
  return Uri(scheme: scheme, pathSegments: [id.package, ...pathSegments]);
}