import 'package:analyzer/dart/element/element2.dart';
import 'package:build/build.dart';
import 'package:path/path.dart' as path;

/// Collects and manages imports required for generated code.
class ImportCollector {
  final Map<String, String> _importUriToPrefix = {};
  final Map<String, LibraryElement2> _importUriToLibrary = {};
  final Set<String> _usedPrefixes = {};

  // Maps libraries to their source import URI
  final Map<LibraryElement2, String> _libraryToSourceImport = {};

  int _nextPrefixIndex = 0;

  final AssetId from;
  final Resolver resolver;

  ImportCollector(this.from, this.resolver);

  /// Registers a library and its original import URI from the source file
  void registerLibraryWithImport(LibraryElement2 library, String importUri) {
    if (library.isDartCore) return;
    if (importUri.startsWith('../') || importUri.startsWith('./')) return;

    // Skip the bundle file itself
    if (importUri.endsWith('.bundle.dart')) return;

    // Normalize the import URI
    final normalizedUri = _normalizeImportUri(importUri);

    // Register this library with its source import
    if (!_libraryToSourceImport.containsKey(library)) {
      _libraryToSourceImport[library] = normalizedUri;
    }

    // Register the import URI and assign a prefix if needed
    if (!_importUriToPrefix.containsKey(normalizedUri)) {
      String prefix = 'prefix$_nextPrefixIndex';
      _nextPrefixIndex++;
      _importUriToPrefix[normalizedUri] = prefix;
      _importUriToLibrary[normalizedUri] = library;
    }

    // Map exported libraries to use the same import URI
    _mapExportedLibraries(library, normalizedUri);
  }

  /// Maps all libraries exported by an import to use that import URI
  void _mapExportedLibraries(LibraryElement2 library, String importUri) {
    final fragment = library.firstFragment;

    for (final export in fragment.libraryExports2) {
      final exportedLibrary = export.exportedLibrary2;
      if (exportedLibrary != null && !exportedLibrary.isDartCore) {
        // Map this exported library to use the same import URI
        // Only map if not already mapped (first import wins)
        if (!_libraryToSourceImport.containsKey(exportedLibrary)) {
          _libraryToSourceImport[exportedLibrary] = importUri;

          // Recursively handle transitive exports
          _mapExportedLibraries(exportedLibrary, importUri);
        }
      }
    }
  }

  /// Normalize import URI to avoid internal paths
  String _normalizeImportUri(String uri) {
    // Don't normalize dart: URIs
    if (uri.startsWith('dart:')) {
      return uri;
    }

    // Handle asset: URIs - convert to relative or package imports
    if (uri.startsWith('asset:')) {
      final assetPath = uri.substring(6); // Remove 'asset:'
      final parts = assetPath.split('/');

      if (parts.length >= 2) {
        final packageName = parts[0];
        final filePath = parts.sublist(1).join('/');

        // If it's the same package as the one we're generating for
        if (packageName == from.package) {
          // CRITICAL: Check if file is in example/ or other excluded subdirectories
          // These should NEVER be imported by root bundles
          if (_isFileInExcludedSubdirectory(filePath) &&
              !_isFromInSameSubdirectory(filePath)) {
            throw Exception(
              'Cannot import file from excluded subdirectory: $filePath\n'
              'Bundle location: ${from.path}\n'
              'This usually means the bundle is incorrectly scanning files outside its scope.',
            );
          }

          // Convert to relative import, but ensure it's proper
          return _convertToProperRelativeImport(filePath);
        } else {
          // Convert to package import
          final cleanPath = filePath.startsWith('lib/')
              ? filePath.substring(4)
              : filePath;
          return 'package:$packageName/$cleanPath';
        }
      }
    }

    // Don't try to "fix" package imports with /src/
    // Keep them as-is, they might be intentionally importing internal APIs
    return uri;
  }

  /// Check if a file path is in an excluded subdirectory
  bool _isFileInExcludedSubdirectory(String filePath) {
    final excludedDirs = [
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

  /// Check if the 'from' file is in the same subdirectory as the target file
  bool _isFromInSameSubdirectory(String targetFilePath) {
    // Extract subdirectory from both paths
    final fromSubdir = _extractSubdirectory(from.path);
    final targetSubdir = _extractSubdirectory(targetFilePath);

    return fromSubdir == targetSubdir;
  }

  /// Extract the subdirectory prefix (example/, test/, etc.) or empty string for root
  String _extractSubdirectory(String filePath) {
    final excludedDirs = [
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
    return ''; // Root
  }

  /// Convert a file path to a proper relative import from the bundle file
  /// Examples:
  /// - from: lib/config/app_bundle.dart, target: lib/entity/user.dart -> ../entity/user.dart
  /// - from: lib/config/app_bundle.dart, target: lib/config/settings.dart -> settings.dart
  /// - from: example/lib/main.dart, target: example/lib/test.dart -> test.dart
  String _convertToProperRelativeImport(String targetPath) {
    // Extract subdirectory from both paths (example/, test/, or '' for root)
    final fromSubdir = _extractSubdirectory(from.path);
    final targetSubdir = _extractSubdirectory(targetPath);

    // Ensure both are in the same subdirectory
    if (fromSubdir != targetSubdir) {
      throw Exception(
        'Cannot create relative import across different subdirectories:\n'
        'From: ${from.path} (subdir: $fromSubdir)\n'
        'Target: $targetPath (subdir: $targetSubdir)',
      );
    }

    // Remove subdirectory prefix if present
    String fromPathAdjusted = from.path;
    String targetPathAdjusted = targetPath;

    if (fromSubdir.isNotEmpty) {
      fromPathAdjusted = from.path.substring(fromSubdir.length);
      targetPathAdjusted = targetPath.substring(targetSubdir.length);
    }

    // Check if target is in lib/
    final targetInLib = targetPathAdjusted.startsWith('lib/');
    final fromInLib = fromPathAdjusted.startsWith('lib/');

    // Case 1: Both in lib/ - use relative imports
    if (targetInLib && fromInLib) {
      // Remove 'lib/' prefix from both
      final fromPathWithoutLib = fromPathAdjusted.substring(4);
      final targetPathWithoutLib = targetPathAdjusted.substring(4);

      // Get the directory of the from file (without filename)
      final fromDir = path.url.dirname(fromPathWithoutLib);

      // Calculate relative path
      final relativePath = path.url.relative(
        targetPathWithoutLib,
        from: fromDir,
      );

      // ✅ CORREÇÃO: Sempre retornar o caminho relativo calculado
      return relativePath;
    }

    // Case 2: Target outside lib/, from inside lib/ - use ../ to go up
    if (!targetInLib && fromInLib) {
      final fromDir = path.url.dirname(fromPathAdjusted);
      final relativePath = path.url.relative(
        targetPathAdjusted,
        from: fromDir,
      );

      return relativePath;
    }

    // Case 3: Both outside lib/ - simple relative
    if (!targetInLib && !fromInLib) {
      final fromDir = path.url.dirname(fromPathAdjusted);
      return path.url.relative(targetPathAdjusted, from: fromDir);
    }

    // Case 4: From outside lib/, target inside lib/ - unusual, but handle it
    final fromDir = path.url.dirname(fromPathAdjusted);
    return path.url.relative(targetPathAdjusted, from: fromDir);
  }

  /// Gets the prefix for a library (with trailing dot).
  String getPrefix(LibraryElement2 library) {
    if (library.isDartCore) return '';

    // Find the source import for this library
    final sourceImport = _libraryToSourceImport[library];
    if (sourceImport == null) {
      // Library not registered, this shouldn't happen in normal usage
      // but handle it gracefully
      final uri = _getImportUri(library).toString();
      registerLibraryWithImport(library, uri);
      return getPrefix(library);
    }

    // Get the prefix for this import
    final prefix = _importUriToPrefix[sourceImport];
    if (prefix == null) {
      // Import not registered, shouldn't happen
      return '';
    }

    _usedPrefixes.add(prefix);
    return '$prefix.';
  }

  /// Returns all collected import statements (sorted deterministically).
  /// Only includes imports that are actually used in the generated code.
  List<String> getImports() {
    final importsList = <String>[];

    // Sort import URIs for deterministic output
    final sortedImports = _importUriToPrefix.keys.toList()..sort();

    for (final uri in sortedImports) {
      final prefix = _importUriToPrefix[uri]!;

      // Skip unused imports
      if (!_usedPrefixes.contains(prefix)) continue;

      // Skip bundle files
      if (uri.endsWith('.bundle.dart')) continue;

      importsList.add("import '$uri' as $prefix;");
    }

    return importsList;
  }

  /// Gets a URI which would be appropriate for importing [library].
  Uri _getImportUri(LibraryElement2 library) {
    final fragment = library.firstFragment;
    final source = fragment.source;
    Uri uri = source.uri;

    // Check if we have a source import mapping first
    final sourceImport = _libraryToSourceImport[library];
    if (sourceImport != null) {
      return Uri.parse(sourceImport);
    }

    // For dart: libraries, use as-is
    if (uri.scheme == 'dart') {
      return uri;
    }

    // For asset: URIs, normalize them
    if (uri.scheme == 'asset') {
      final normalized = _normalizeImportUri(uri.toString());
      return Uri.parse(normalized);
    }

    // For package: libraries, use as-is
    if (uri.scheme == 'package') {
      return uri;
    }

    // For file: or other schemes, try to convert to package: or relative
    if (uri.scheme == 'file') {
      final assetId = _tryGetAssetId(library);
      if (assetId != null) {
        return Uri.parse(_assetIdToUri(assetId));
      }
    }

    // Fallback: use the URI as-is
    return uri;
  }

  /// Try to get AssetId from library
  AssetId? _tryGetAssetId(LibraryElement2 library) {
    try {
      final fragment = library.firstFragment;
      final source = fragment.source;
      final fullPath = source.fullName;

      final pathParts = fullPath.split('/');

      // Look for .pub-cache pattern
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

      // Look for package pattern in the path
      for (var i = 0; i < pathParts.length; i++) {
        if (pathParts[i] == 'lib' && i > 0) {
          final packageName = pathParts[i - 1];
          final relativePath = 'lib/${pathParts.sublist(i + 1).join('/')}';
          return AssetId(packageName, relativePath);
        }
      }
    } catch (e) {
      // Ignore errors
    }

    return null;
  }

  /// Converts an AssetId to a relative or package: URI string.
  String _assetIdToUri(AssetId assetId) {
    if (!assetId.path.startsWith('lib/')) {
      // Non-lib asset - must use relative path
      if (assetId.package != from.package) {
        throw Exception(
          'Cannot generate non-lib import from different package: $assetId',
        );
      }

      final fromDir = path.url.dirname(from.path);
      final relative = path.url.relative(assetId.path, from: fromDir);
      return relative;
    }

    // Lib asset - prefer relative imports for same package
    if (assetId.package == from.package && from.path.startsWith('lib/')) {
      return _convertToProperRelativeImport(assetId.path);
    }

    // Different package - use package: import
    return 'package:${assetId.package}/${assetId.path.substring(4)}';
  }

  /// Clears all collected imports.
  void clear() {
    _importUriToPrefix.clear();
    _importUriToLibrary.clear();
    _usedPrefixes.clear();
    _libraryToSourceImport.clear();
    _nextPrefixIndex = 0;
  }
}
