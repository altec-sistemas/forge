import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:path/path.dart' as path;

/// Collects and manages imports required for generated code.
class ImportCollector {
  final Map<LibraryElement, String> _libraryToPrefix = {};
  final Map<LibraryElement, String> _libraryToOriginalImport = {};
  final Map<String, LibraryElement> _importUriToLibrary = {};
  final Set<String> _usedPrefixes = {};

  // Maps element libraries to the import that was actually used in source
  final Map<LibraryElement, String> _elementLibraryToSourceImport = {};

  int _nextPrefixIndex = 0;

  final AssetId from;
  final Resolver resolver;

  ImportCollector(this.from, this.resolver);

  /// Registers a library and its original import URI from the source file
  void registerLibraryWithImport(LibraryElement library, String importUri) {
    if (library.isDartCore) return;

    // Skip the bundle file itself
    if (importUri.endsWith('.bundle.dart')) return;

    // Normalize the import URI
    final normalizedUri = _normalizeImportUri(importUri);

    if (!_libraryToOriginalImport.containsKey(library)) {
      _libraryToOriginalImport[library] = normalizedUri;
      _importUriToLibrary[normalizedUri] = library;

      // Also assign a prefix if not already assigned
      if (!_libraryToPrefix.containsKey(library)) {
        String prefix = 'prefix$_nextPrefixIndex';
        _nextPrefixIndex++;
        _libraryToPrefix[library] = prefix;
      }
    }

    // Map any exported libraries from this import to use the same import URI
    _mapExportedLibraries(library, normalizedUri);
  }

  /// Maps all libraries exported by an import to use that import URI
  void _mapExportedLibraries(LibraryElement library, String importUri) {
    // Map the library itself
    if (!_elementLibraryToSourceImport.containsKey(library)) {
      _elementLibraryToSourceImport[library] = importUri;
    }

    // Map all exported libraries - use firstFragment.libraryExports
    final fragment = library.firstFragment;
    for (final export in fragment.libraryExports) {
      final exportedLibrary = export.exportedLibrary;
      if (exportedLibrary != null) {
        // Only map if not already mapped (first import wins)
        if (!_elementLibraryToSourceImport.containsKey(exportedLibrary)) {
          _elementLibraryToSourceImport[exportedLibrary] = importUri;

          // Also ensure we have a prefix for it
          if (!_libraryToPrefix.containsKey(exportedLibrary)) {
            final prefix = _libraryToPrefix[library]!;
            _libraryToPrefix[exportedLibrary] = prefix;
          }
        }

        // Recursively handle transitive exports
        _mapExportedLibraries(exportedLibrary, importUri);
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
          // Convert to relative import
          final fromDir = path.url.dirname(from.path);
          final targetPath = filePath;
          final relativePath = path.url.relative(targetPath, from: fromDir);
          return relativePath;
        } else {
          // Convert to package import
          final cleanPath = filePath.startsWith('lib/')
              ? filePath.substring(4)
              : filePath;
          return 'package:$packageName/$cleanPath';
        }
      }
    }

    // Check if it's an internal package path (contains /src/)
    if (uri.startsWith('package:') && uri.contains('/src/')) {
      final parts = uri.split('/');
      if (parts.length >= 2) {
        final packagePart = parts[0];
        final packageName = packagePart.substring(8);
        return 'package:$packageName/$packageName.dart';
      }
    }

    return uri;
  }

  /// Gets the prefix for a library (with trailing dot).
  String getPrefix(LibraryElement library) {
    if (library.isDartCore) return '';

    // First, check if we have a mapped source import for this library
    final sourceImport = _elementLibraryToSourceImport[library];
    if (sourceImport != null) {
      // Find the library that corresponds to this import
      final importLibrary = _importUriToLibrary[sourceImport];
      if (importLibrary != null &&
          _libraryToPrefix.containsKey(importLibrary)) {
        final prefix = _libraryToPrefix[importLibrary]!;
        _usedPrefixes.add(prefix);
        return '$prefix.';
      }
    }

    // Fallback to direct library lookup
    String? prefix = _libraryToPrefix[library];
    if (prefix == null) {
      prefix = 'prefix$_nextPrefixIndex';
      _nextPrefixIndex++;
      _libraryToPrefix[library] = prefix;
    }

    _usedPrefixes.add(prefix);
    return prefix.isEmpty ? '' : '$prefix.';
  }

  /// Returns all libraries that need to be imported.
  Iterable<LibraryElement> get libraries => _libraryToPrefix.keys;

  /// Returns all collected import statements (sorted deterministically).
  /// Only includes imports that are actually used in the generated code.
  List<String> getImports() {
    final importsList = <String>[];
    final processedUris = <String>{};

    for (final entry in _libraryToPrefix.entries) {
      final library = entry.key;
      final prefix = entry.value;

      // Skip unused imports
      if (!_usedPrefixes.contains(prefix)) continue;

      // Try to use original import first
      String uri;
      if (_libraryToOriginalImport.containsKey(library)) {
        uri = _libraryToOriginalImport[library]!;
      } else {
        // Check if we have a source import mapping
        final sourceImport = _elementLibraryToSourceImport[library];
        if (sourceImport != null) {
          uri = sourceImport;
        } else {
          uri = _getImportUri(library).toString();
        }
      }

      // Skip bundle files
      if (uri.endsWith('.bundle.dart')) continue;

      // Skip if we already added this URI
      if (processedUris.contains(uri)) continue;
      processedUris.add(uri);

      if (prefix.isEmpty) {
        importsList.add("import '$uri';");
      } else {
        importsList.add("import '$uri' as $prefix;");
      }
    }

    importsList.sort();
    return importsList;
  }

  /// Gets a URI which would be appropriate for importing [library].
  Uri _getImportUri(LibraryElement library) {
    // Use firstFragment.source instead of library.source
    final fragment = library.firstFragment;
    final source = fragment.source;
    Uri uri = source.uri;

    // Check if we have a source import mapping first
    final sourceImport = _elementLibraryToSourceImport[library];
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

    // For package: libraries with /src/, try to use main package import
    if (uri.scheme == 'package' && uri.path.contains('/src/')) {
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final packageName = pathSegments[0];
        return Uri.parse('package:$packageName/$packageName.dart');
      }
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
  AssetId? _tryGetAssetId(LibraryElement library) {
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

    // Lib asset - use package: import
    return 'package:${assetId.package}/${assetId.path.substring(4)}';
  }

  /// Clears all collected imports.
  void clear() {
    _libraryToPrefix.clear();
    _libraryToOriginalImport.clear();
    _importUriToLibrary.clear();
    _usedPrefixes.clear();
    _elementLibraryToSourceImport.clear();
    _nextPrefixIndex = 0;
  }
}
