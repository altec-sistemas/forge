import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element2.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';

import 'import_collector.dart';

/// Generates code for annotations using AST-based approach (like build_implementation)
class AnnotationCodeGenerator {
  final ImportCollector importCollector;
  final Resolver resolver;

  // ✅ CACHE de bibliotecas resolvidas
  final _resolvedLibraryCache = <String, ResolvedLibraryResult?>{};

  // ✅ CACHE de metadata extraída
  final _metadataCache = <String, String>{};

  AnnotationCodeGenerator(this.importCollector, this.resolver);

  /// Extract metadata code from an element's AST
  Future<String> extractMetadataCode(Element2 element, AssetId dataId) async {
    // ✅ CACHE de metadata por element
    final cacheKey = _getElementCacheKey(element);
    if (_metadataCache.containsKey(cacheKey)) {
      return _metadataCache[cacheKey]!;
    }

    // Synthetic elements don't have metadata
    if ((element is GetterElement ||
            element is SetterElement ||
            element is ConstructorElement2) &&
        element.isSynthetic) {
      const result = 'const []';
      _metadataCache[cacheKey] = result;
      return result;
    }

    // Skip platform libraries
    if (_isPlatformLibrary(element.library2)) {
      const result = 'const []';
      _metadataCache[cacheKey] = result;
      return result;
    }

    NodeList<Annotation>? metadata;
    ResolvedLibraryResult? resolvedLibrary = await _getResolvedLibraryCached(
      element.library2!,
    );

    if (element is LibraryElement2 && resolvedLibrary != null) {
      metadata = _getLibraryMetadata(_definingLibraryFragment(resolvedLibrary));
    } else {
      metadata = _getOtherMetadata(
        resolvedLibrary?.getFragmentDeclaration(element.firstFragment)?.node,
        element,
      );
    }

    if (metadata == null || metadata.isEmpty) {
      const result = 'const []';
      _metadataCache[cacheKey] = result;
      return result;
    }

    var metadataParts = <String>[];
    for (Annotation annotationNode in metadata) {
      Element2? annotationNodeElement = annotationNode.element2;
      if (annotationNodeElement == null) {
        continue;
      }

      if (!_isImportable(annotationNodeElement, dataId)) {
        continue;
      }

      LibraryElement2 annotationLibrary = annotationNodeElement.library2!;
      importCollector.registerLibraryWithImport(
        annotationLibrary,
        annotationLibrary.uri.toString(),
      );

      String prefix = importCollector.getPrefix(annotationLibrary);
      ArgumentList? annotationNodeArguments = annotationNode.arguments;

      if (annotationNodeArguments != null) {
        String name = _extractNameWithoutPrefix(annotationNode.name);
        var argumentList = <String>[];

        for (Expression argument in annotationNodeArguments.arguments) {
          argumentList.add(
            _extractConstantCode(argument, importCollector, dataId),
          );
        }

        String arguments = argumentList.join(', ');
        metadataParts.add('$prefix$name($arguments)');
      } else {
        String name = _extractNameWithoutPrefix(annotationNode.name);
        metadataParts.add('$prefix$name');
      }
    }

    final result = 'const <Object>[${metadataParts.join(', ')}]';
    _metadataCache[cacheKey] = result;
    return result;
  }

  /// ✅ CACHE KEY para elementos
  String _getElementCacheKey(Element2 element) {
    return '${element.library2?.uri}::${element.name3}::${element.runtimeType}';
  }

  /// ✅ Get resolved library com CACHE
  Future<ResolvedLibraryResult?> _getResolvedLibraryCached(
    LibraryElement2 library,
  ) async {
    final libraryUri = library.uri.toString();

    if (_resolvedLibraryCache.containsKey(libraryUri)) {
      return _resolvedLibraryCache[libraryUri];
    }

    final result = await _getResolvedLibrary(library, resolver);
    _resolvedLibraryCache[libraryUri] = result;
    return result;
  }

  /// Extract constant code from an expression (recursive)
  String _extractConstantCode(
    Expression expression,
    ImportCollector importCollector,
    AssetId dataId,
  ) {
    // ✅ HELPER inline para evitar closure overhead
    String typeAnnotationHelper(TypeAnnotation typeName) {
      DartType? interfaceType = typeName.type;
      if (interfaceType is InterfaceType) {
        LibraryElement2 library = interfaceType.element3.library2;
        String prefix = importCollector.getPrefix(library);
        return '$prefix$typeName';
      } else {
        return '$typeName';
      }
    }

    String helper(Expression expression) {
      if (expression is ListLiteral) {
        var elements = <String>[];
        for (CollectionElement collectionElement in expression.elements) {
          if (collectionElement is Expression) {
            elements.add(helper(collectionElement));
          }
        }

        TypeArgumentList? typeArguments = expression.typeArguments;
        if (typeArguments != null && typeArguments.arguments.isNotEmpty) {
          var typeArgs = <String>[];
          for (TypeAnnotation typeArg in typeArguments.arguments) {
            typeArgs.add(typeAnnotationHelper(typeArg));
          }
          return '<${typeArgs.join(', ')}>[${elements.join(', ')}]';
        }
        return '[${elements.join(', ')}]';
      } else if (expression is SetOrMapLiteral) {
        var elements = <String>[];
        for (CollectionElement collectionElement in expression.elements) {
          if (collectionElement is Expression) {
            elements.add(helper(collectionElement));
          } else if (collectionElement is MapLiteralEntry) {
            String key = helper(collectionElement.key);
            String value = helper(collectionElement.value);
            elements.add('$key: $value');
          }
        }

        TypeArgumentList? typeArguments = expression.typeArguments;
        if (typeArguments != null && typeArguments.arguments.isNotEmpty) {
          var typeArgs = <String>[];
          for (TypeAnnotation typeArg in typeArguments.arguments) {
            typeArgs.add(typeAnnotationHelper(typeArg));
          }
          return '<${typeArgs.join(', ')}>{${elements.join(', ')}}';
        }
        return '{${elements.join(', ')}}';
      } else if (expression is PrefixedIdentifier) {
        var prefix = expression.prefix;
        var identifier = expression.identifier;

        if (prefix.element is PrefixElement2) {
          var element = identifier.element;
          if (element != null) {
            LibraryElement2 library = element.library2!;
            String libPrefix = importCollector.getPrefix(library);
            return '$libPrefix${identifier.token.lexeme}';
          }
        }

        var element = identifier.element;
        if (element != null && element.library2 != null) {
          LibraryElement2 library = element.library2!;
          String libPrefix = importCollector.getPrefix(library);
          return '$libPrefix${prefix.token.lexeme}.${identifier.token.lexeme}';
        }

        return expression.name;
      } else if (expression is SimpleIdentifier) {
        var element = expression.element;
        if (element != null && element.library2 != null) {
          LibraryElement2 library = element.library2!;
          String prefix = importCollector.getPrefix(library);
          return '$prefix${expression.token.lexeme}';
        }
        return expression.token.lexeme;
      } else if (expression is InstanceCreationExpression) {
        ConstructorName constructorName = expression.constructorName;
        NamedType namedType = constructorName.type;
        SimpleIdentifier? constructorIdentifier = constructorName.name;

        var element = namedType.element2;
        if (element is InterfaceElement2) {
          LibraryElement2 library = element.library2;
          String prefix = importCollector.getPrefix(library);

          String className = element.name3 ?? '';
          String fullName = constructorIdentifier != null
              ? '$className.${constructorIdentifier.name}'
              : className;

          var argumentList = <String>[];
          for (Expression argument in expression.argumentList.arguments) {
            argumentList.add(helper(argument));
          }

          String typeArgs = '';
          TypeArgumentList? typeArguments = namedType.typeArguments;
          if (typeArguments != null && typeArguments.arguments.isNotEmpty) {
            var typeArgStrings = <String>[];
            for (TypeAnnotation typeArg in typeArguments.arguments) {
              typeArgStrings.add(typeAnnotationHelper(typeArg));
            }
            typeArgs = '<${typeArgStrings.join(', ')}>';
          }

          return '$prefix$fullName$typeArgs(${argumentList.join(', ')})';
        }
        return expression.toSource();
      } else if (expression is TypeLiteral) {
        return typeAnnotationHelper(expression.type);
      } else if (expression is ConditionalExpression) {
        String condition = helper(expression.condition);
        String thenExpr = helper(expression.thenExpression);
        String elseExpr = helper(expression.elseExpression);
        return '$condition ? $thenExpr : $elseExpr';
      } else if (expression is BinaryExpression) {
        String left = helper(expression.leftOperand);
        String right = helper(expression.rightOperand);
        String operator = expression.operator.lexeme;
        return '$left $operator $right';
      } else if (expression is ParenthesizedExpression) {
        String nested = helper(expression.expression);
        return '($nested)';
      } else if (expression is PropertyAccess) {
        String target = helper(expression.realTarget);
        String selector = expression.propertyName.token.lexeme;
        return '$target.$selector';
      } else if (expression is MethodInvocation) {
        if (expression.target == null &&
            expression.methodName.token.lexeme == 'identical') {
          NodeList<Expression> arguments = expression.argumentList.arguments;
          String a = helper(arguments[0]);
          String b = helper(arguments[1]);
          return 'identical($a, $b)';
        }

        String? target;
        if (expression.target != null) {
          target = helper(expression.target!);
        }

        var argumentList = <String>[];
        for (Expression argument in expression.argumentList.arguments) {
          argumentList.add(helper(argument));
        }

        String methodName = expression.methodName.token.lexeme;
        String targetPart = target != null ? '$target.' : '';
        return '$targetPart$methodName(${argumentList.join(', ')})';
      } else if (expression is NamedExpression) {
        String value = _extractConstantCode(
          expression.expression,
          importCollector,
          dataId,
        );
        return '${expression.name} $value';
      } else if (expression is FunctionReference) {
        String function = _extractConstantCode(
          expression.function,
          importCollector,
          dataId,
        );
        TypeArgumentList? expressionTypeArguments = expression.typeArguments;
        if (expressionTypeArguments == null) {
          return function;
        } else {
          var typeArguments = <String>[];
          for (TypeAnnotation expressionTypeArgument
              in expressionTypeArguments.arguments) {
            String typeArgument = typeAnnotationHelper(expressionTypeArgument);
            typeArguments.add(typeArgument);
          }
          return '$function<${typeArguments.join(', ')}>';
        }
      } else {
        return expression.toSource();
      }
    }

    return helper(expression);
  }

  /// Extract name without library prefix
  String _extractNameWithoutPrefix(Identifier identifier) {
    String name;
    if (identifier is SimpleIdentifier) {
      name = identifier.token.lexeme;
    } else if (identifier is PrefixedIdentifier) {
      if (identifier.prefix.element is PrefixElement2) {
        name = identifier.identifier.token.lexeme;
      } else {
        name = identifier.name;
      }
    } else {
      name = identifier.name;
    }
    return name;
  }

  /// Get resolved library
  static Future<ResolvedLibraryResult?> _getResolvedLibrary(
    LibraryElement2 library,
    Resolver resolver,
  ) async {
    try {
      var assetId = await resolver.assetIdForElement(library);
      var libraryElement = await resolver.libraryFor(assetId);
      var session = libraryElement.session;
      var libraryPath = library.firstFragment.source.fullName;

      var result = await session.getResolvedLibrary(libraryPath);
      if (result is ResolvedLibraryResult) {
        return result;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get defining library fragment
  static CompilationUnit? _definingLibraryFragment(
    ResolvedLibraryResult resolvedLibrary,
  ) {
    LibraryFragment definingFragment = resolvedLibrary.element2.firstFragment;
    List<ResolvedUnitResult> units = resolvedLibrary.units;
    for (var unit in units) {
      if (unit.unit.declaredFragment == definingFragment) {
        return unit.unit;
      }
    }
    return null;
  }

  /// Get library metadata
  static NodeList<Annotation>? _getLibraryMetadata(CompilationUnit? unit) {
    if (unit != null) {
      for (var directive in unit.directives) {
        if (directive is LibraryDirective) {
          return directive.metadata;
        }
      }
    }
    return null;
  }

  /// Get metadata from other elements
  static NodeList<Annotation>? _getOtherMetadata(
    AstNode? node,
    Element2 element,
  ) {
    if (node == null) {
      return null;
    }

    if (node is EnumConstantDeclaration) {
      return node.metadata;
    }

    if (element is FieldElement2 || element is TopLevelVariableElement2) {
      node = node.parent?.parent;
      if (node == null) return null;
    }

    if (node is AnnotatedNode) {
      return node.metadata;
    } else if (node is FormalParameter) {
      return node.metadata;
    }

    return null;
  }

  /// Check if library is a platform library (dart:*)
  static bool _isPlatformLibrary(LibraryElement2? library) {
    if (library == null) return false;
    return library.uri.scheme == 'dart';
  }

  /// Check if an element can be imported
  static bool _isImportable(Element2 element, AssetId dataId) {
    if (element.name3?.startsWith('_') ?? false) {
      return false;
    }

    LibraryElement2? library = element.library2;
    if (library == null) return false;

    if (library.uri.scheme == 'dart') {
      String path = library.uri.path;
      if (path.startsWith('_')) return false;
    }

    return true;
  }

  /// ✅ Limpar cache quando necessário
  void clearCache() {
    _resolvedLibraryCache.clear();
    _metadataCache.clear();
  }
}
