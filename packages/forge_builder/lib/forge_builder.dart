import 'dart:async';
import 'package:analyzer/dart/element/element2.dart';
import 'package:build/build.dart';
import 'package:forge_core/forge_core.dart';
import 'package:source_gen/source_gen.dart';

import 'src/bundle_generator.dart';

/// Builder for generating bundle implementations from @AutoBundle annotations
class ForgeBundleBuilder implements Builder {
  final BuilderOptions options;

  ForgeBundleBuilder(this.options);

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;

    try {
      final library = await buildStep.inputLibrary;
      final resolver = buildStep.resolver;

      // Use TypeChecker.fromUrl instead of fromRuntime
      final autoBundleChecker = TypeChecker.typeNamed(AutoBundle);

      // Use specific getters instead of topLevelElements
      for (final element in [
        ...library.classes,
        ...library.enums,
        ...library.extensions,
      ]) {
        if (element is ClassElement2) {
          final annotation = autoBundleChecker.firstAnnotationOf(element);
          if (annotation != null) {
            // Generate bundle implementation
            final generator = BundleGenerator(
              buildStep: buildStep,
              resolver: resolver,
              bundleClass: element,
              annotation: annotation,
            );

            final generatedCode = await generator.generate();

            if (generatedCode.isNotEmpty) {
              final outputId = inputId.changeExtension('.bundle.dart');
              await buildStep.writeAsString(outputId, generatedCode);
            }
          }
        }
      }
    } catch (e, stackTrace) {
      log.severe('Error processing ${inputId.path}', e, stackTrace);
    }
  }

  @override
  Map<String, List<String>> get buildExtensions => const {
    '.dart': ['.bundle.dart'],
  };
}

/// Factory function for creating the builder
Builder forgeBundleBuilder(BuilderOptions options) {
  return ForgeBundleBuilder(options);
}
