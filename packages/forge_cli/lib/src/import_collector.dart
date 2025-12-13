import 'package:analyzer/dart/element/element2.dart';
import 'package:build/build.dart';
import 'package:path/path.dart' as path;

/// Collects and manages imports required for generated code.
class ImportCollector {
  final Map<String, String> _importUriToPrefix = {};
  final Map<String, LibraryElement2> _importUriToLibrary = {};
  final Set<String> _usedPrefixes = {};
  final Map<LibraryElement2, String> _libraryToSourceImport = {};

  // ✅ CACHE para evitar reprocessamento de exports
  final Set<String> _processedExports = {};

  int _nextPrefixIndex = 0;

  final AssetId from;
  final Resolver resolver;

  ImportCollector(this.from, this.resolver);

  /// Registers a library and its original import URI from the source file
  void registerLibraryWithImport(LibraryElement2 library, String importUri) {
    if (library.isDartCore) return;
    if (importUri.startsWith('../') || importUri.startsWith('./')) return;
    if (importUri.endsWith('.bundle.dart')) return;

    final normalizedUri = _normalizeImportUri(importUri);

    if (!_libraryToSourceImport.containsKey(library)) {
      _libraryToSourceImport[library] = normalizedUri;
    }

    if (!_importUriToPrefix.containsKey(normalizedUri)) {
      String prefix = 'prefix$_nextPrefixIndex';
      _nextPrefixIndex++;
      _importUriToPrefix[normalizedUri] = prefix;
      _importUriToLibrary[normalizedUri] = library;
    }

    // ✅ OTIMIZAÇÃO: Verificar se já processamos exports desta biblioteca
    final libKey = library.uri.toString();
    if (!_processedExports.contains(libKey)) {
      _processedExports.add(libKey);
      _mapExportedLibraries(library, normalizedUri);
    }
  }

  /// ✅ OTIMIZADO: Maps exported libraries com limite de profundidade
  void _mapExportedLibraries(
    LibraryElement2 library,
    String importUri, {
    int depth = 0,
  }) {
    // Limitar profundidade para evitar recursão infinita em exports circulares
    if (depth > 5) return;

    final fragment = library.firstFragment;

    for (final export in fragment.libraryExports2) {
      final exportedLibrary = export.exportedLibrary2;
      if (exportedLibrary != null && !exportedLibrary.isDartCore) {
        if (!_libraryToSourceImport.containsKey(exportedLibrary)) {
          _libraryToSourceImport[exportedLibrary] = importUri;

          // ✅ Verificar cache antes de recursão
          final exportKey = exportedLibrary.uri.toString();
          if (!_processedExports.contains(exportKey)) {
            _processedExports.add(exportKey);
            _mapExportedLibraries(exportedLibrary, importUri, depth: depth + 1);
          }
        }
      }
    }
  }

  /// Normalize import URI to avoid internal paths
  String _normalizeImportUri(String uri) {
    if (uri.startsWith('dart:')) {
      return uri;
    }

    if (uri.startsWith('asset:')) {
      final assetPath = uri.substring(6);
      final parts = assetPath.split('/');

      if (parts.length >= 2) {
        final packageName = parts[0];
        final filePath = parts.sublist(1).join('/');

        if (packageName == from.package) {
          if (_isFileInExcludedSubdirectory(filePath) &&
              !_isFromInSameSubdirectory(filePath)) {
            throw Exception(
              'Cannot import file from excluded subdirectory: $filePath\n'
              'Bundle location: ${from.path}\n'
              'This usually means the bundle is incorrectly scanning files outside its scope.',
            );
          }

          return _convertToProperRelativeImport(filePath);
        } else {
          final cleanPath = filePath.startsWith('lib/')
              ? filePath.substring(4)
              : filePath;
          return 'package:$packageName/$cleanPath';
        }
      }
    }

    return uri;
  }

  bool _isFileInExcludedSubdirectory(String filePath) {
    const excludedDirs = [
      'example/',
      'test/',
      'integration_test/',
      'tool/',
      'benchmark/',
    ];
    for (final dir in excludedDirs) {
      if (filePath.startsWith(dir)) {
        return true;
      }
    }
    return false;
  }

  bool _isFromInSameSubdirectory(String targetFilePath) {
    final fromSubdir = _extractSubdirectory(from.path);
    final targetSubdir = _extractSubdirectory(targetFilePath);
    return fromSubdir == targetSubdir;
  }

  String _extractSubdirectory(String filePath) {
    const excludedDirs = [
      'example/',
      'test/',
      'integration_test/',
      'tool/',
      'benchmark/',
    ];
    for (final dir in excludedDirs) {
      if (filePath.startsWith(dir)) {
        return dir;
      }
    }
    return '';
  }

  String _convertToProperRelativeImport(String targetPath) {
    final fromSubdir = _extractSubdirectory(from.path);
    final targetSubdir = _extractSubdirectory(targetPath);

    if (fromSubdir != targetSubdir) {
      throw Exception(
        'Cannot create relative import across different subdirectories:\n'
        'From: ${from.path} (subdir: $fromSubdir)\n'
        'Target: $targetPath (subdir: $targetSubdir)',
      );
    }

    String fromPathAdjusted = from.path;
    String targetPathAdjusted = targetPath;

    if (fromSubdir.isNotEmpty) {
      fromPathAdjusted = from.path.substring(fromSubdir.length);
      targetPathAdjusted = targetPath.substring(targetSubdir.length);
    }

    final targetInLib = targetPathAdjusted.startsWith('lib/');
    final fromInLib = fromPathAdjusted.startsWith('lib/');

    if (targetInLib && fromInLib) {
      final fromPathWithoutLib = fromPathAdjusted.substring(4);
      final targetPathWithoutLib = targetPathAdjusted.substring(4);
      final fromDir = path.url.dirname(fromPathWithoutLib);
      final relativePath = path.url.relative(
        targetPathWithoutLib,
        from: fromDir,
      );
      return relativePath;
    }

    if (!targetInLib && fromInLib) {
      final fromDir = path.url.dirname(fromPathAdjusted);
      final relativePath = path.url.relative(targetPathAdjusted, from: fromDir);
      return relativePath;
    }

    if (!targetInLib && !fromInLib) {
      final fromDir = path.url.dirname(fromPathAdjusted);
      return path.url.relative(targetPathAdjusted, from: fromDir);
    }

    final fromDir = path.url.dirname(fromPathAdjusted);
    return path.url.relative(targetPathAdjusted, from: fromDir);
  }

  /// Gets the prefix for a library (with trailing dot).
  String getPrefix(LibraryElement2 library) {
    if (library.isDartCore) return '';

    final sourceImport = _libraryToSourceImport[library];
    if (sourceImport == null) {
      final uri = _getImportUri(library).toString();
      registerLibraryWithImport(library, uri);
      return getPrefix(library);
    }

    final prefix = _importUriToPrefix[sourceImport];
    if (prefix == null) {
      return '';
    }

    _usedPrefixes.add(prefix);
    return '$prefix.';
  }

  /// Returns all collected import statements (sorted deterministically).
  List<String> getImports() {
    final importsList = <String>[];
    final sortedImports = _importUriToPrefix.keys.toList()..sort();

    for (final uri in sortedImports) {
      final prefix = _importUriToPrefix[uri]!;
      if (!_usedPrefixes.contains(prefix)) continue;
      if (uri.endsWith('.bundle.dart')) continue;
      importsList.add("import '$uri' as $prefix;");
    }

    return importsList;
  }

  Uri _getImportUri(LibraryElement2 library) {
    final fragment = library.firstFragment;
    final source = fragment.source;
    Uri uri = source.uri;

    final sourceImport = _libraryToSourceImport[library];
    if (sourceImport != null) {
      return Uri.parse(sourceImport);
    }

    if (uri.scheme == 'dart') {
      return uri;
    }

    if (uri.scheme == 'asset') {
      final normalized = _normalizeImportUri(uri.toString());
      return Uri.parse(normalized);
    }

    if (uri.scheme == 'package') {
      return uri;
    }

    if (uri.scheme == 'file') {
      final assetId = _tryGetAssetId(library);
      if (assetId != null) {
        return Uri.parse(_assetIdToUri(assetId));
      }
    }

    return uri;
  }

  AssetId? _tryGetAssetId(LibraryElement2 library) {
    try {
      final fragment = library.firstFragment;
      final source = fragment.source;
      final fullPath = source.fullName;
      final pathParts = fullPath.split('/');

      final pubCacheIndex = pathParts.indexOf('.pub-cache');
      if (pubCacheIndex != -1 && pubCacheIndex + 3 < pathParts.length) {
        final packageWithVersion = pathParts[pubCacheIndex + 3];
        final packageName = packageWithVersion.split('-').first;

        final libIndex = pathParts.indexOf('lib', pubCacheIndex);
        if (libIndex != -1) {
          final relativePath =
              'lib/${pathParts.sublist(libIndex + 1).join('/')}';
          return AssetId(packageName, relativePath);
        }
      }

      for (var i = 0; i < pathParts.length; i++) {
        if (pathParts[i] == 'lib' && i > 0) {
          final packageName = pathParts[i - 1];
          final relativePath = 'lib/${pathParts.sublist(i + 1).join('/')}';
          return AssetId(packageName, relativePath);
        }
      }
    } catch (e) {
      // Ignore
    }

    return null;
  }

  String _assetIdToUri(AssetId assetId) {
    if (!assetId.path.startsWith('lib/')) {
      if (assetId.package != from.package) {
        throw Exception(
          'Cannot generate non-lib import from different package: $assetId',
        );
      }

      final fromDir = path.url.dirname(from.path);
      final relative = path.url.relative(assetId.path, from: fromDir);
      return relative;
    }

    if (assetId.package == from.package && from.path.startsWith('lib/')) {
      return _convertToProperRelativeImport(assetId.path);
    }

    return 'package:${assetId.package}/${assetId.path.substring(4)}';
  }

  void clear() {
    _importUriToPrefix.clear();
    _importUriToLibrary.clear();
    _usedPrefixes.clear();
    _libraryToSourceImport.clear();
    _processedExports.clear();
    _nextPrefixIndex = 0;
  }
}
