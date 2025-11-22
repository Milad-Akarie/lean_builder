import 'dart:io' show File;

import 'package:collection/collection.dart' show IterableExtension;
import 'package:dart_style/dart_style.dart' show DartFormatter;
import 'package:lean_builder/builder.dart';
import 'package:lean_builder/element.dart';
import 'package:lean_builder/src/build_script/errors.dart';
import 'package:lean_builder/src/build_script/generator.dart';
import 'package:lean_builder/src/graph/references_scan_manager.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/type/type.dart';
import 'package:lean_builder/src/type/type_checker.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p show relative, join, current, normalize, dirname;
import 'compile.dart' as compile;
import 'paths.dart' as paths;

/// Import path for lean_builder annotation classes.
const String _leanAnnotations = 'package:lean_builder/src/build_script/annotations.dart';

/// Import path for the Generator base class.
const String _leanGenerator = 'package:lean_builder/src/builder/generator/generator.dart';

/// Import path for the Builder base class.
const String _leanBuilders = 'package:lean_builder/src/builder/builder.dart';

/// Import path for parsed builder entry classes.
const String _parsedBuilderEntry = 'package:lean_builder/src/build_script/parsed_builder_entry.dart';

/// Prepares the build script by generating code based on the provided assets.
///
/// This function analyzes the input assets to find builder and generator
/// annotations, then generates a Dart script that will use these builders
/// during the build process.
///
/// If no changes are detected and a script already exists, it returns the
/// path to the existing script. Otherwise, it generates a new script,
/// formats it, and invalidates any existing compiled executable.
///
/// @param assets Set of assets to analyze for annotations
/// @param resolver Resolver to use for parsing annotations
/// @return Path to the build script file, or null if no builders were found
String? prepareBuildScript(
  Set<ProcessableAsset> assets,
  ResolverImpl resolver,
) {
  final File scriptFile = File(paths.buildScriptOutput);

  void deleteScriptFile() {
    if (scriptFile.existsSync()) {
      scriptFile.deleteSync();
    }
  }

  bool hasChanges = false;
  for (final ProcessableAsset entry in Set<ProcessableAsset>.of(assets)) {
    if (entry.state == AssetState.deleted) {
      hasChanges = true;
      resolver.graph.removeAsset(entry.asset.id);
      entry.asset.safeDelete();
      assets.remove(entry);
    } else if (entry.state == AssetState.unProcessed) {
      hasChanges = true;
    }
  }

  if (!hasChanges && scriptFile.existsSync()) {
    return scriptFile.path;
  }

  /// invalidate processed assets on new build script generation
  final String rootPackage = resolver.fileResolver.rootPackage;
  resolver.graph.invalidateProcessedAssetsOf(rootPackage);

  final (
    List<BuilderDefinitionEntry> entries,
    List<BuilderOverride> overrides,
  ) = parseBuilderEntries(
    Set<Asset>.of(assets.map((ProcessableAsset e) => e.asset)),
    resolver,
  );
  if (entries.isEmpty) {
    deleteScriptFile();
    return null;
  }

  final withOverrides = applyOverrides(entries, overrides);

  Logger.info('Generating a new build script...');
  String script = generateBuildScript(withOverrides);
  final DartFormatter formatter = DartFormatter(
    languageVersion: DartFormatter.latestShortStyleLanguageVersion,
  );
  script = formatter.format(script);

  if (!scriptFile.existsSync()) {
    scriptFile.createSync(recursive: true);
  }
  scriptFile.writeAsStringSync(script);

  compile.invalidateExecutable();
  return scriptFile.path;
}

/// Applies overrides to builder definitions and returns the merged result.
///
/// For each builder definition, if there's a matching override with the
/// same key, it merges the override into the definition. Otherwise, it
/// keeps the original definition unchanged.
///
/// @param entries Original builder definitions
/// @param overrides Builder overrides to apply
/// @return List of builder definitions with overrides applied
List<BuilderDefinitionEntry> applyOverrides(
  List<BuilderDefinitionEntry> entries,
  List<BuilderOverride> overrides,
) {
  if (overrides.isEmpty) return entries;

  final List<BuilderDefinitionEntry> finalEntries = <BuilderDefinitionEntry>[];
  for (final BuilderDefinitionEntry entry in entries) {
    final BuilderOverride? override = overrides.firstWhereOrNull(
      (BuilderOverride e) => e.key == entry.key,
    );
    if (override != null) {
      finalEntries.add(entry.merge(override));
    } else {
      finalEntries.add(entry);
    }
  }

  return finalEntries;
}

/// Parses a set of assets to extract builder definitions and overrides.
///
/// Analyzes the provided assets looking for classes annotated with
/// LeanGenerator or LeanBuilder, and variables annotated with
/// LeanBuilderOverrides. Validates that annotated classes extend
/// the appropriate base classes and that overrides are correctly defined.
///
/// @param assets Set of assets to analyze
/// @param resolver Resolver to use for parsing annotations
/// @return Tuple containing a list of builder definitions and a list of overrides
(List<BuilderDefinitionEntry>, List<BuilderOverride>) parseBuilderEntries(
  Set<Asset> assets,
  ResolverImpl resolver,
) {
  final List<BuilderDefinitionEntry> parsedEntries = <BuilderDefinitionEntry>[];
  final List<BuilderOverride> parsedOverrides = <BuilderOverride>[];
  late final leanGenTypeChecker = resolver.typeCheckerFor('LeanGenerator', _leanAnnotations);
  late final leanBuilderTypeChecker = resolver.typeCheckerFor('LeanBuilder', _leanAnnotations);
  late final leanBuilderOverrideTypeChecker = resolver.typeCheckerFor('LeanBuilderOverrides', _leanAnnotations);
  late final generatorTypeChecker = resolver.typeCheckerFor('Generator', _leanGenerator);
  late final builderTypeChecker = resolver.typeCheckerFor('Builder', _leanBuilders);
  late final builderOverrideTypeChecker = resolver.typeCheckerFor('BuilderOverride', _parsedBuilderEntry);

  for (final Asset asset in assets) {
    final LibraryElement library = resolver.resolveLibrary(asset);
    for (final AnnotatedElement annotatedElement in library.annotatedWithExact(
      leanGenTypeChecker,
    )) {
      final Element element = annotatedElement.element;
      if (element is! ClassElement) {
        throw BuildConfigError(
          'Expected a class element for generator annotation',
        );
      }
      final NamedDartType? superType = element.superType;
      if (superType == null || !generatorTypeChecker.isAssignableFromType(superType)) {
        throw BuildConfigError(
          'Expected a class that extends Generator for LeanGenerator annotation',
        );
      }

      final Constant constObj = annotatedElement.annotation.constant;
      if (constObj is! ConstObject) {
        throw BuildConfigError('Could not read annotation object');
      }

      final bool isShared = constObj.constructorName == 'shared';
      final BuilderType builderType = isShared ? BuilderType.shared : BuilderType.library;
      final builderEntry = _buildEntry(asset, constObj, resolver, element, builderType);
      parsedEntries.add(builderEntry);
    }

    for (final AnnotatedElement annotatedElement in library.annotatedWithExact(
      leanBuilderTypeChecker,
    )) {
      final Element element = annotatedElement.element;
      if (element is! ClassElement) {
        throw BuildConfigError(
          'Expected a class element for builder annotation',
        );
      }
      final NamedDartType? superType = element.superType;

      if (superType == null || !builderTypeChecker.isAssignableFromType(superType)) {
        throw BuildConfigError(
          'Expected a class that extends Builder for LeanBuilder annotation',
        );
      }

      final Constant constObj = annotatedElement.annotation.constant;
      if (constObj is! ConstObject) {
        throw BuildConfigError('Could not read annotation object');
      }

      final BuilderDefinitionEntry builderEntry = _buildEntry(
        asset,
        constObj,
        resolver,
        element,
        BuilderType.custom,
      );
      parsedEntries.add(builderEntry);
    }

    for (final AnnotatedElement annotatedElement in library.annotatedWithExact(
      leanBuilderOverrideTypeChecker,
    )) {
      final Element element = annotatedElement.element;
      if (element is! TopLevelVariableElement || !element.isConst) {
        throw BuildConfigError(
          'Expected a const top-level variable of type List<BuilderOverride> for LeanBuilderOverrides annotation',
        );
      }
      final Constant? constObj = element.constantValue;
      if (constObj is! ConstList) {
        throw BuildConfigError('Could not read annotation object');
      }
      final List<Constant> list = constObj.value;
      if (list.isEmpty) continue;
      for (final Constant obj in list) {
        if (obj is! ConstObject || !builderOverrideTypeChecker.isExactlyType(obj.type)) {
          throw BuildConfigError(
            'Expected a const object of type BuilderOverride as list element',
          );
        }
        final BuilderOverride builderOverride = BuilderOverride(
          key: obj.getString('key')!.value,
          generateFor: obj.getSet('generateFor')?.literalValue.cast<String>(),
          runsBefore: obj.getSet('runsBefore')?.literalValue.cast<String>(),
          options: obj.getMap('options')?.literalValue.cast<String, dynamic>(),
        );
        if (builderOverride.key.isEmpty) {
          throw BuildConfigError(
            'Expected a non-empty key for BuilderOverride',
          );
        }
        if (parsedOverrides.any(
          (BuilderOverride e) => e.key == builderOverride.key,
        )) {
          throw BuildConfigError(
            'Duplicate key found for BuilderOverride: ${builderOverride.key}',
          );
        }
        parsedOverrides.add(builderOverride);
      }
    }
  }

  return (parsedEntries, parsedOverrides);
}

/// Builds a BuilderDefinitionEntry from a class element and its annotation.
///
/// Extracts configuration values from the annotation and validates that
/// required fields are present depending on the builder type. Also processes
/// type annotations referenced by the builder and records them for runtime
/// registration.
///
/// @param asset The asset containing the annotated class
/// @param constObj The annotation constant object
/// @param resolver Resolver to use for type checking
/// @param element The annotated class element
/// @param builderType The type of builder being created
/// @return A complete BuilderDefinitionEntry
BuilderDefinitionEntry _buildEntry(
  Asset asset,
  ConstObject constObj,
  ResolverImpl resolver,
  ClassElement element,
  BuilderType builderType,
) {
  Set<String>? outputExtensions;
  if (builderType.isLibrary) {
    final Set<String>? extensions = constObj.getSet('outputExtensions')?.literalValue.cast<String>();
    if (extensions != null && extensions.isNotEmpty) {
      outputExtensions = extensions;
    } else {
      throw BuildConfigError(
        'Expected a non-empty `outputExtensions` key in ${asset.shortUri}',
      );
    }
  }
  late final TypeChecker optionsTypeChecker = resolver.typeCheckerFor(
    'BuilderOptions',
    _leanBuilders,
  );
  bool expectsOptions = false;
  final ConstructorElement? constructor = element.unnamedConstructor;
  if (constructor != null) {
    if (constructor.parameters.length > 1) {
      throw BuildConfigError(
        'Expected a constructor with no parameters or one positional parameter of type (BuilderOptions)',
      );
    }
    final ParameterElement? options = constructor.parameters.isNotEmpty ? constructor.parameters.first : null;
    if (options != null && (!options.isPositional || !optionsTypeChecker.isExactlyType(options.type))) {
      throw BuildConfigError(
        'Expected a parameter of exact type BuilderOptions, but got ${options.type}',
      );
    }
    expectsOptions = options != null;
  }

  final List<RuntimeTypeRegisterEntry> typesToRegister = <RuntimeTypeRegisterEntry>[];

  final String import = resolveImport(asset.shortUri, uri: asset.uri)!;
  final Set<Constant>? annotationRefs = constObj.getSet('registerTypes')?.value;
  final Set<DartType> types = <DartType>{
    ...?annotationRefs?.whereType<ConstType>().map((ConstType e) => e.value),
  };
  final NamedDartType? superType = element.superType;
  if (superType is InterfaceType && superType.typeArguments.isNotEmpty) {
    types.addAll(superType.typeArguments);
  }

  for (final DartType type in types) {
    if (type is! InterfaceType) {
      throw BuildConfigError(
        'Expected an InterfaceType for annotation reference',
      );
    }
    final Uri typeImport = resolver.uriForAsset(type.declarationRef.srcId);
    typesToRegister.add(
      RuntimeTypeRegisterEntry(
        type.name,
        resolveImport(typeImport),
        type.declarationRef.srcId,
      ),
    );
  }

  final BuilderDefinitionEntry builderDef = BuilderDefinitionEntry(
    import: import,
    builderType: builderType,
    generatorName: element.name,
    expectsOptions: expectsOptions,
    outputExtensions: outputExtensions,
    registeredTypes: typesToRegister.isEmpty ? null : typesToRegister,
    key: constObj.getString('key')?.value ?? element.name,
    generateToCache: constObj.getBool('generateToCache')?.value,
    options: constObj.getMap('options')?.literalValue.cast<String, dynamic>(),
    generateFor: constObj.getSet('generateFor')?.literalValue.cast<String>(),
    runsBefore: constObj.getSet('runsBefore')?.literalValue.cast<String>(),
    allowSyntaxErrors: constObj.getBool('allowSyntaxErrors')?.value,
    applies: constObj.getSet('applies')?.literalValue.cast<String>(),
  );
  return builderDef;
}

/// Resolves the import path for a given URI.
///
/// Converts asset URIs to relative paths based on the build script location,
/// and leaves package URIs unchanged.
/// @param shortUri The URI to resolve
/// @param uri Optional original URI for more accurate path resolution
/// @return Resolved import path as a string, or null for core Dart libraries
@visibleForTesting
String? resolveImport(Uri shortUri, {Uri? uri}) {
  if (shortUri.scheme == 'dart' && shortUri.pathSegments.firstOrNull == 'core') {
    return null;
  }
  if (shortUri.scheme == 'asset') {
    final Uri targetUri = Uri.parse(p.join(p.current, paths.buildScriptOutput));
    final base = p.normalize(p.dirname(targetUri.path));
    final target = (uri ?? shortUri).path.replaceAll(RegExp(r'\\'), '/');
    // remove optional leading backslash and drive letter (e.g. "\C:\...", "C:\...", or "C:/...")
    final withoutDrive = p.normalize(target.replaceFirst(RegExp(r'^/?[A-Za-z]:/'), r'/'));
    return p.relative(withoutDrive, from: base).replaceAll(RegExp(r'\\'), '/');
  } else {
    // it's either a package import or a first-party dart library
    return shortUri.toString();
  }
}
