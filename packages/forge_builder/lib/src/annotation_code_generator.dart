import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';

import 'import_collector.dart';

/// Generates code for annotations using AST-based approach (like build_implementation)
class AnnotationCodeGenerator {
  final ImportCollector importCollector;
  final Resolver resolver;

  AnnotationCodeGenerator(this.importCollector, this.resolver);

  /// Extract metadata code from an element's AST
  Future<String> extractMetadataCode(
    Element element,
    AssetId dataId,
  ) async {
    // Synthetic elements don't have metadata
    if ((element is GetterElement ||
            element is SetterElement ||
            element is ConstructorElement) &&
        element.isSynthetic) {
      return 'const []';
    }

    // Skip platform libraries
    if (_isPlatformLibrary(element.library)) {
      return 'const []';
    }

    NodeList<Annotation>? metadata;
    ResolvedLibraryResult? resolvedLibrary = await _getResolvedLibrary(
      element.library!,
      resolver,
    );

    if (element is LibraryElement && resolvedLibrary != null) {
      metadata = _getLibraryMetadata(_definingLibraryFragment(resolvedLibrary));
    } else {
      metadata = _getOtherMetadata(
        resolvedLibrary?.getFragmentDeclaration(element.firstFragment)?.node,
        element,
      );
    }

    if (metadata == null || metadata.isEmpty) return 'const []';

    var metadataParts = <String>[];
    for (Annotation annotationNode in metadata) {
      Element? annotationNodeElement = annotationNode.element;
      if (annotationNodeElement == null) {
        // Unresolved annotation, skip it
        continue;
      }

      if (!_isImportable(annotationNodeElement, dataId)) {
        // Private or non-importable, skip it
        continue;
      }

      LibraryElement annotationLibrary = annotationNodeElement.library!;
      importCollector.registerLibraryWithImport(
        annotationLibrary,
        annotationLibrary.uri.toString(),
      );

      String prefix = importCollector.getPrefix(annotationLibrary);
      ArgumentList? annotationNodeArguments = annotationNode.arguments;

      if (annotationNodeArguments != null) {
        // Constructor invocation: @MyAnnotation(args)
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
        // Field reference: @myAnnotation
        String name = _extractNameWithoutPrefix(annotationNode.name);
        metadataParts.add('$prefix$name');
      }
    }

    return 'const <Object>[${metadataParts.join(', ')}]';
  }

  /// Extract constant code from an expression (recursive)
  String _extractConstantCode(
    Expression expression,
    ImportCollector importCollector,
    AssetId dataId,
  ) {
    String typeAnnotationHelper(TypeAnnotation typeName) {
      DartType? interfaceType = typeName.type;
      if (interfaceType is InterfaceType) {
        LibraryElement library = interfaceType.element.library;
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

        // Check if prefix is a library prefix
        if (prefix.element is PrefixElement) {
          // Get the library and add it
          var element = identifier.element;
          if (element != null) {
            LibraryElement library = element.library!;
            String libPrefix = importCollector.getPrefix(library);
            return '$libPrefix${identifier.token.lexeme}';
          }
        }

        // Otherwise it's a class member reference (e.g., MyClass.value)
        var element = identifier.element;
        if (element != null && element.library != null) {
          LibraryElement library = element.library!;
          String libPrefix = importCollector.getPrefix(library);
          return '$libPrefix${prefix.token.lexeme}.${identifier.token.lexeme}';
        }

        return expression.name;
      } else if (expression is SimpleIdentifier) {
        var element = expression.element;
        if (element != null && element.library != null) {
          LibraryElement library = element.library!;
          String prefix = importCollector.getPrefix(library);
          return '$prefix${expression.token.lexeme}';
        }
        return expression.token.lexeme;
      } else if (expression is InstanceCreationExpression) {
        ConstructorName constructorName = expression.constructorName;
        NamedType namedType = constructorName.type;
        SimpleIdentifier? constructorIdentifier = constructorName.name;

        // Get the class element
        var element = namedType.element;
        if (element is InterfaceElement) {
          LibraryElement library = element.library;
          String prefix = importCollector.getPrefix(library);

          String className = element.name ?? '';
          String fullName = constructorIdentifier != null
              ? '$className.${constructorIdentifier.name}'
              : className;

          // Process arguments
          var argumentList = <String>[];
          for (Expression argument in expression.argumentList.arguments) {
            argumentList.add(helper(argument));
          }

          // Process type arguments
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
        // Handle special cases like identical(a, b)
        if (expression.target == null &&
            expression.methodName.token.lexeme == 'identical') {
          NodeList<Expression> arguments = expression.argumentList.arguments;
          String a = helper(arguments[0]);
          String b = helper(arguments[1]);
          return 'identical($a, $b)';
        }

        // General method invocation
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
        // Literals: IntegerLiteral, BooleanLiteral, StringLiteral, etc.
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
      // Check if prefix is a library prefix
      if (identifier.prefix.element is PrefixElement) {
        // Strip library prefix, we'll add our own
        name = identifier.identifier.token.lexeme;
      } else {
        // Preserve class prefix (e.g., MyClass.namedConstructor)
        name = identifier.name;
      }
    } else {
      name = identifier.name;
    }
    return name;
  }

  /// Get resolved library
  static Future<ResolvedLibraryResult?> _getResolvedLibrary(
    LibraryElement library,
    Resolver resolver,
  ) async {
    try {
      // Get the AssetId for this library
      var assetId = await resolver.assetIdForElement(library);

      // Get the LibraryElement using the AssetId
      var libraryElement = await resolver.libraryFor(assetId);

      // Use the analyzer session to get the resolved library
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
    LibraryFragment definingFragment = resolvedLibrary.element.firstFragment;
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
    Element element,
  ) {
    if (node == null) {
      return null;
    }

    if (node is EnumConstantDeclaration) {
      return node.metadata;
    }

    // For fields and top-level variables, metadata is on parent nodes
    if (element is FieldElement || element is TopLevelVariableElement) {
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
  static bool _isPlatformLibrary(LibraryElement? library) {
    if (library == null) return false;
    return library.uri.scheme == 'dart';
  }

  /// Check if an element can be imported
  static bool _isImportable(
    Element element,
    AssetId dataId,
  ) {
    // Private elements can't be imported
    if (element.name?.startsWith('_') ?? false) {
      return false;
    }

    // Check if the library is accessible
    LibraryElement? library = element.library;
    if (library == null) return false;

    // Platform private libraries can't be imported
    if (library.uri.scheme == 'dart') {
      String path = library.uri.path;
      if (path.startsWith('_')) return false;
    }

    return true;
  }
}
