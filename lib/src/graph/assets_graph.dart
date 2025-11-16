import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;
import 'package:analyzer/dart/ast/ast.dart';
import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/builder/builder.dart';
import 'package:lean_builder/src/graph/directive_statement.dart';
import 'package:lean_builder/src/graph/references_scan_manager.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:collection/collection.dart';
import 'package:lean_builder/src/resolvers/errors.dart';
import 'package:lean_builder/src/type/core_type_source.dart';
import 'package:xxh3/xxh3.dart';

import 'declaration_ref.dart';

/// {@template assets_graph}
/// A graph of Dart assets and their dependencies.
///
/// The [AssetsGraph] tracks all Dart files in the project, their declarations,
/// and the relationships between them (imports, exports, parts).
///
/// It provides methods to:
/// - Query assets by package
/// - Look up declarations
/// - Trace dependencies between files
/// - Track generated outputs
/// - Determine which assets need processing
///
/// The graph can be persisted to disk to improve build performance across runs.
/// {@endtemplate}
class AssetsGraph extends AssetsScanResults {
  /// File where the assets graph cache is stored
  static final File cacheFile = File('.dart_tool/lean_build/assets_graph.json');

  /// Invalidates the cached graph, forcing a rebuild
  static void invalidateCache() {
    if (cacheFile.existsSync()) {
      cacheFile.deleteSync(recursive: true);
    }
  }

  /// A hash of the build configuration
  ///
  /// Used to determine if the cached graph is still valid
  final String hash;

  /// Whether the graph was loaded from cache
  final bool loadedFromCache;

  /// Whether the cached graph should be invalidated
  final bool shouldInvalidate;

  /// Version of the graph format
  ///
  /// Used to determine if the cached graph is compatible
  static const String version = '1.0.0';

  /// ID for the dart:core import
  late final String _coreImportId = xxh3String(
    Uint8List.fromList(CoreTypeSource.core.codeUnits),
  );

  /// Representation of an import of dart:core
  late final List<Object?> _coreImport = <Object?>[
    DirectiveStatement.import,
    _coreImportId,
    '',
    null,
    null,
  ];

  /// {@macro assets_graph}
  AssetsGraph(this.hash) : loadedFromCache = false, shouldInvalidate = false;

  /// Creates a graph from cached data
  AssetsGraph._fromCache(this.hash, {this.shouldInvalidate = false}) : loadedFromCache = true;

  /// {@template assets_graph.init}
  /// Initialize an assets graph, loading from cache if possible.
  ///
  /// If the cache exists, it will be loaded.
  /// Otherwise, a new graph will be created.
  ///
  /// A loaded graph does not mean it doesn't require invalidation.
  /// [shouldInvalidate] is used to determine if the cached graph is still valid.
  ///
  /// [hash] is used to determine if the cached graph is still valid.
  /// {@endtemplate}
  factory AssetsGraph.init(String hash) {
    if (cacheFile.existsSync()) {
      try {
        final dynamic cachedGraph = jsonDecode(cacheFile.readAsStringSync());
        final AssetsGraph instance = AssetsGraph.fromCache(cachedGraph, hash);
        if (!instance.loadedFromCache || instance.shouldInvalidate) {
          Logger.info('Cache is invalid, rebuilding...');
          cacheFile.deleteSync(recursive: true);
        }
        return instance;
      } catch (e) {
        Logger.info('Cache is invalid, rebuilding...');
        cacheFile.deleteSync(recursive: true);
      }
    }
    return AssetsGraph(hash);
  }

  /// {@template assets_graph.save}
  /// Saves the graph to disk for future use.
  ///
  /// This persists the current state of the graph to improve build performance
  /// in subsequent runs.
  /// {@endtemplate}
  Future<void> save() async {
    final File file = AssetsGraph.cacheFile;
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    await file.writeAsString(jsonEncode(toJson()));
  }

  /// {@template assets_graph.clear_all}
  /// Clears all data from the graph.
  ///
  /// This removes all assets, identifiers, directives, and outputs from the graph.
  /// {@endtemplate}
  void clearAll() {
    assets.clear();
    identifiers.clear();
    directives.clear();
    outputs.clear();
  }

  /// {@template assets_graph.get_assets_for_package}
  /// Returns all assets for a specific package.
  ///
  /// [package] is the name of the package to get assets for.
  /// {@endtemplate}
  List<ScannedAsset> getAssetsForPackages(Set<String> packages) {
    final List<ScannedAsset> assets = <ScannedAsset>[];
    for (final MapEntry<String, List<dynamic>> entry in this.assets.entries) {
      final Uri uri = Uri.parse(entry.value[GraphIndex.assetUri]);
      if (uri.pathSegments.isEmpty) continue;
      if (packages.contains(uri.pathSegments[0])) {
        assets.add(
          ScannedAsset(
            entry.key,
            uri,
            entry.value[GraphIndex.assetDigest] as String?,
            (entry.value[GraphIndex.assetTLMFlag] as int) == 1,
          ),
        );
      }
    }
    return assets;
  }

  /// {@template assets_graph.invalidate_processed_assets_of}
  /// Marks all assets from a package as needing to be reprocessed.
  ///
  /// [package] is the name of the package to invalidate.
  /// {@endtemplate}
  void invalidateProcessedAssetsOf(String package) {
    for (final MapEntry<String, List<dynamic>> entry in assets.entries) {
      final Uri uri = Uri.parse(entry.value[GraphIndex.assetUri]);
      if (uri.pathSegments.isEmpty) continue;
      if (uri.pathSegments[0] == package) {
        entry.value[GraphIndex.assetState] = AssetState.unProcessed.index;
      }
    }
  }

  /// {@template assets_graph.get_declaration_ref}
  /// Looks up a declaration reference for an identifier.
  ///
  /// This method resolves an identifier to its declaration, handling imports,
  /// exports, and re-exports correctly.
  ///
  /// [identifier] is the name of the identifier to look up.
  /// [importingSrc] is the asset that is importing the identifier.
  /// [importPrefix] is an optional import prefix (e.g., 'prefix' in 'prefix.identifier').
  ///
  /// Throws [IdentifierNotFoundError] if the identifier cannot be resolved.
  /// {@endtemplate}
  DeclarationRef? getDeclarationRef(
    String identifier,
    Asset importingSrc, {
    String? importPrefix,
  }) {
    DeclarationRef buildRef(
      MapEntry<String, int> srcEntry, {
      String? providerId,
    }) {
      return DeclarationRef(
        identifier: identifier,
        srcId: srcEntry.key,
        srcUri: uriForAsset(srcEntry.key),
        providerId: providerId ?? srcEntry.key,
        type: ReferenceType.fromValue(srcEntry.value),
        importingLibrary: importingSrc,
        importPrefix: importPrefix,
      );
    }

    final Map<String, int> possibleSrcs = Map<String, int>.fromEntries(
      identifiers
          .where(
            (List<dynamic> e) => e[GraphIndex.identifierName] == identifier,
          )
          .map(
            (List<dynamic> e) => MapEntry<String, int>(
              e[GraphIndex.identifierSrc],
              e[GraphIndex.identifierType],
            ),
          ),
    );

    final String actualSrc = getParentSrc(importingSrc.id);
    // First check if the identifier is declared directly in this file
    for (final MapEntry<String, int> entry in possibleSrcs.entries) {
      if (entry.key == importingSrc.id || entry.key == actualSrc) {
        return buildRef(entry, providerId: actualSrc);
      }
    }

    // Check all imports of the source file
    final List<List<Object?>> fileImports = <List<Object?>>[
      ...importsOf(importingSrc.id),
      if (assets.containsKey(_coreImportId)) _coreImport,
    ];

    for (final List<Object?> importEntry in fileImports) {
      final String importedFileSrc = importEntry[GraphIndex.directiveSrc] as String;
      final String? prefix = importEntry.elementAtOrNull(GraphIndex.directivePrefix) as String?;
      if (importPrefix != null && importPrefix != prefix) continue;

      // Skip if the identifier is hidden
      final List<dynamic> hides = importEntry[GraphIndex.directiveHide] as List<dynamic>? ?? const <dynamic>[];
      if (hides.contains(identifier)) continue;

      // Skip if the identifier is not shown
      final List<dynamic> shows = importEntry[GraphIndex.directiveShow] as List<dynamic>? ?? const <dynamic>[];
      if (shows.isNotEmpty && !shows.contains(identifier)) continue;

      // Check if the imported file directly declares the identifier
      for (final MapEntry<String, int> entry in possibleSrcs.entries) {
        if (entry.key == importedFileSrc) {
          return buildRef(entry, providerId: importedFileSrc);
        }
      }
    }
    for (final List<Object?> importEntry in fileImports) {
      final String importedFileSrc = importEntry[GraphIndex.directiveSrc] as String;
      final Set<String> visitedSrcs = <String>{};
      final String? src = _traceExportsOf(
        importedFileSrc,
        identifier,
        possibleSrcs.keys,
        visitedSrcs,
      );
      if (src != null) {
        final MapEntry<String, int> srcEntry = possibleSrcs.entries.firstWhere(
          (MapEntry<String, int> k) => k.key == src,
        );
        return buildRef(srcEntry, providerId: importedFileSrc);
      }
    }
    return null;
  }

  /// {@template assets_graph.lookup_identifier_by_provider}
  /// Looks up an identifier using its provider source.
  ///
  /// This is useful for resolving identifiers when you know which library
  /// is providing them, such as when dealing with re-exports.
  ///
  /// [name] is the identifier name.
  /// [providerSrc] is the ID of the library providing the identifier.
  ///
  /// Returns null if the identifier cannot be found.
  /// {@endtemplate}
  DeclarationRef? lookupIdentifierByProvider(String name, String providerSrc) {
    if (!assets.containsKey(providerSrc)) return null;
    final Map<String, List<dynamic>> possibleSrcs = Map<String, List<dynamic>>.fromEntries(
      identifiers
          .where((List<dynamic> e) => e[GraphIndex.identifierName] == name)
          .map(
            (List<dynamic> e) => MapEntry<String, List<dynamic>>(
              e[GraphIndex.identifierSrc],
              e,
            ),
          ),
    );

    // First check if the identifier is declared directly in this file
    for (final MapEntry<String, List<dynamic>> entry in possibleSrcs.entries) {
      if (entry.key == providerSrc) {
        return DeclarationRef(
          identifier: name,
          srcId: providerSrc,
          providerId: providerSrc,
          type: ReferenceType.fromValue(entry.value[GraphIndex.identifierType]),
          srcUri: uriForAsset(providerSrc),
        );
      }
    }
    // trace exports
    final Set<String> visitedSrcs = <String>{};
    final String? src = _traceExportsOf(
      providerSrc,
      name,
      possibleSrcs.keys,
      visitedSrcs,
    );
    if (src != null) {
      return DeclarationRef(
        identifier: name,
        srcId: src,
        providerId: providerSrc,
        type: ReferenceType.fromValue(
          possibleSrcs[src]![GraphIndex.identifierType],
        ),
        srcUri: uriForAsset(src),
      );
    }
    return null;
  }

  /// {@template assets_graph._trace_exports_of}
  /// Recursively traces exports to find the source of an identifier.
  ///
  /// This method follows export directives to find the original declaration
  /// of an identifier, handling re-exports and show/hide clauses.
  ///
  /// [srcId] is the ID of the library to start from.
  /// [identifier] is the name of the identifier to look for.
  /// [possibleSrcs] is a collection of libraries that declare the identifier.
  /// [visitedSrcs] is used to avoid cycles in export chains.
  ///
  /// Returns the ID of the library that declares the identifier, or null if not found.
  /// {@endtemplate}
  String? _traceExportsOf(
    String srcId,
    String identifier,
    Iterable<String> possibleSrcs,
    Set<String> visitedSrcs,
  ) {
    if (visitedSrcs.contains(srcId)) return null;
    visitedSrcs.add(srcId);

    final List<List<dynamic>> exports = exportsOf(srcId);
    final Set<String> checkableExports = <String>{};
    for (final List<dynamic> export in exports) {
      final String exportedFileSrc = export[GraphIndex.directiveSrc] as String;
      final List<dynamic> hides = export[GraphIndex.directiveHide] as List<dynamic>? ?? const <dynamic>[];
      if (hides.contains(identifier)) continue;
      final List<dynamic> shows = export[GraphIndex.directiveShow] as List<dynamic>? ?? const <dynamic>[];
      if (shows.isNotEmpty && !shows.contains(identifier)) continue;

      if (possibleSrcs.contains(exportedFileSrc)) {
        return exportedFileSrc;
      }
      if (shows.contains(identifier)) {
        checkableExports.clear();
        checkableExports.add(exportedFileSrc);
        break;
      }
      checkableExports.add(exportedFileSrc);
    }
    for (final String exportedFileHash in checkableExports) {
      final String? src = _traceExportsOf(
        exportedFileHash,
        identifier,
        possibleSrcs,
        visitedSrcs,
      );
      if (src != null) {
        return src;
      }
    }
    return null;
  }

  /// {@template assets_graph.add_output}
  /// Registers a generated output as being produced by an asset.
  ///
  /// This tracks the relationship between source files and their generated outputs.
  ///
  /// [asset] is the source asset.
  /// [output] is the generated output asset.
  /// {@endtemplate}
  void addOutput(Asset asset, Asset output) {
    assert(assets.containsKey(asset.id), 'Asset not found: ${asset.shortUri}');
    outputs.putIfAbsent(asset.id, () => <String>{}).add(output.id);
  }

  /// {@template assets_graph.identifiers_for_asset}
  /// Returns all identifiers declared in a specific asset.
  ///
  /// [src] is the ID of the asset to get identifiers for.
  /// {@endtemplate}
  Set<String> identifiersForAsset(String src) {
    final Set<String> identifiers = <String>{};
    for (final List<dynamic> entry in this.identifiers) {
      if (entry[GraphIndex.identifierSrc] == src) {
        identifiers.add(entry[GraphIndex.identifierName]);
      }
    }
    return identifiers;
  }

  /// {@template assets_graph.get_exposed_identifiers_inside}
  /// Returns all identifiers exposed within a file through imports.
  ///
  /// This includes all identifiers from imported libraries.
  ///
  /// [fileHash] is the ID of the file to get exposed identifiers for.
  ///
  /// Returns a map of identifier names to the IDs of their source libraries.
  /// {@endtemplate}
  Map<String, String> getExposedIdentifiersInside(String fileHash) {
    final Map<String, String> identifiers = <String, String>{};
    for (final List<dynamic> importArr in importsOf(fileHash)) {
      final Set<String> importedIdentifiers = identifiersForAsset(
        importArr[GraphIndex.directiveSrc],
      );
      for (final String identifier in importedIdentifiers) {
        identifiers[identifier] = importArr[GraphIndex.directiveSrc];
      }
    }
    return identifiers;
  }

  /// {@template assets_graph.to_json}
  /// Converts the graph to a JSON-serializable map.
  ///
  /// Includes version and hash information for cache validation.
  /// {@endtemplate}
  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      ...super.toJson(),
      'version': version,
      'hash': hash,
    };
  }

  /// {@template assets_graph.from_cache}
  /// Creates an [AssetsGraph] from cached JSON data.
  ///
  /// [json] is the cached JSON data.
  /// [hash] is the current configuration hash to validate against.
  ///
  /// Returns a new [AssetsGraph] populated with data from the cache.
  /// {@endtemplate}
  factory AssetsGraph.fromCache(Map<String, dynamic> json, String hash) {
    final String? lastUsedHash = json['hash'] as String?;
    final String? version = json['version'] as String?;
    final bool shouldInvalidate = lastUsedHash != hash || version != AssetsGraph.version;
    final AssetsGraph instance = AssetsGraph._fromCache(
      hash,
      shouldInvalidate: shouldInvalidate,
    );
    return AssetsScanResults.populate(instance, json);
  }

  /// {@template assets_graph.invalidate_digest}
  /// Invalidates the digest of an asset, forcing it to be reprocessed.
  ///
  /// [assetId] is the ID of the asset to invalidate.
  /// {@endtemplate}
  void invalidateDigest(String assetId) {
    if (assets.containsKey(assetId)) {
      assets[assetId]![GraphIndex.assetDigest] = null;
    }
  }

  /// {@template assets_graph.dependents_of}
  /// Returns all assets that depend on a specific asset.
  ///
  /// This includes assets that import, use as a part, or re-export the asset.
  ///
  /// [id] is the ID of the asset to get dependents for.
  ///
  /// Returns a map of dependent asset IDs to their data.
  /// {@endtemplate}
  Map<String, List<dynamic>> dependentsOf(String id) {
    final Set<String> visited = <String>{};
    final Set<String> dependents = _dependentsOf(id, visited);
    final Map<String, List<dynamic>> assets = <String, List<dynamic>>{};
    for (final String dep in dependents) {
      if (dep == id) continue;
      final List<dynamic>? arr = this.assets[dep];
      if (arr != null) {
        assets[dep] = arr;
      }
    }
    return assets;
  }

  /// {@template assets_graph._dependents_of}
  /// Recursively collects all assets that depend on a specific asset.
  ///
  /// [id] is the ID of the asset to get dependents for.
  /// [visited] is used to avoid cycles.
  ///
  /// Returns a set of dependent asset IDs.
  /// {@endtemplate}
  Set<String> _dependentsOf(String id, Set<String> visited) {
    if (visited.contains(id)) return <String>{};
    visited.add(id);
    final Set<String> dependents = <String>{};
    for (final MapEntry<String, List<List<dynamic>>> entry in directives.entries) {
      for (final List<dynamic> directive in entry.value) {
        final int type = directive[GraphIndex.directiveType];
        if (directive[GraphIndex.directiveSrc] == id) {
          if (type == DirectiveStatement.export) {
            dependents.addAll(_dependentsOf(entry.key, visited));
          } else if (type != DirectiveStatement.library) {
            dependents.add(entry.key);
          }
        } else if (type == DirectiveStatement.partOf && entry.key == id) {
          // If 'id' is the main library and 'directiveSrc' is a part of it
          dependents.add(directive[GraphIndex.directiveSrc]);
        }
      }
    }
    return dependents;
  }

  /// {@template assets_graph.get_generator_of_output}
  /// Returns the ID of the asset that generated a specific output.
  ///
  /// [id] is the ID of the output asset.
  ///
  /// Returns null if the asset is not a generated output.
  /// {@endtemplate}
  String? getGeneratorOfOutput(String id) {
    for (final MapEntry<String, Set<String>> entry in outputs.entries) {
      if (entry.value.contains(id)) {
        return entry.key;
      }
    }
    return null;
  }

  /// {@template assets_graph.exported_symbols_of}
  /// Returns all symbols exported by a specific asset.
  ///
  /// [id] is the ID of the asset to get exported symbols for.
  ///
  /// Returns a list of [ExportedSymbol] objects.
  /// {@endtemplate}
  List<ExportedSymbol> exportedSymbolsOf(String id) {
    final List<ExportedSymbol> exportedSymbols = <ExportedSymbol>[];
    for (final List<dynamic> entry in identifiers) {
      if (entry[GraphIndex.identifierSrc] == id) {
        final String name = entry[GraphIndex.identifierName];
        final ReferenceType type = ReferenceType.fromValue(
          entry[GraphIndex.identifierType],
        );
        exportedSymbols.add(ExportedSymbol(name, type));
      }
    }
    return exportedSymbols;
  }

  /// {@template assets_graph.is_a_generated_source}
  /// Returns whether an asset is a generated output.
  ///
  /// [id] is the ID of the asset to check.
  /// {@endtemplate}
  bool isAGeneratedSource(String id) {
    for (final MapEntry<String, Set<String>> entry in outputs.entries) {
      if (entry.value.contains(id)) {
        return true;
      }
    }
    return false;
  }

  /// {@template assets_graph.get_input_of}
  /// Returns the data for the input asset that generated a specific output.
  ///
  /// [id] is the ID of the output asset.
  ///
  /// Returns null if the asset is not a generated output.
  /// {@endtemplate}
  List<dynamic>? getInputOf(String id) {
    for (final MapEntry<String, Set<String>> entry in outputs.entries) {
      if (entry.value.contains(id)) {
        return assets[entry.key];
      }
    }
    return null;
  }

  /// {@template assets_graph.remove_output}
  /// Removes an output asset from the graph.
  ///
  /// This also updates the outputs map to remove the relationship between
  /// the input and output assets.
  ///
  /// [output] is the ID of the output asset to remove.
  /// {@endtemplate}
  void removeOutput(String output) {
    for (final MapEntry<String, Set<String>> entry in outputs.entries) {
      if (entry.value.contains(output)) {
        entry.value.remove(output);
        if (entry.value.isEmpty) {
          outputs.remove(entry.key);
        }
        break;
      }
    }
  }

  /// {@template assets_graph.get_processable_assets}
  /// Returns all assets that need to be processed.
  ///
  /// [fileResolver] is used to resolve asset IDs to [Asset] objects.
  ///
  /// Returns a set of [ProcessableAsset] objects.
  /// {@endtemplate}
  Set<ProcessableAsset> getProcessableAssets(PackageFileResolver fileResolver) {
    final Set<ProcessableAsset> processableAssets = <ProcessableAsset>{};
    for (final MapEntry<String, List<dynamic>> entry in assets.entries) {
      if (entry.value[GraphIndex.assetDigest] == null) continue;
      if (entry.value[GraphIndex.assetState] != AssetState.processed.index) {
        final TLMFlag tlmFlag = TLMFlag.fromIndex(
          entry.value[GraphIndex.assetTLMFlag] as int,
        );
        final Asset asset = fileResolver.assetForUri(
          Uri.parse(entry.value[GraphIndex.assetUri]),
        );
        final AssetState state = AssetState.fromIndex(
          entry.value[GraphIndex.assetState],
        );
        processableAssets.add(ProcessableAsset(asset, state, tlmFlag));
      }
    }
    return processableAssets;
  }

  /// {@template assets_graph.get_builder_processable_assets}
  /// Returns all assets that need to be processed by builders.
  ///
  /// This includes only assets that have builder annotations.
  ///
  /// [fileResolver] is used to resolve asset IDs to [Asset] objects.
  ///
  /// Returns a set of [ProcessableAsset] objects.
  /// {@endtemplate}
  Set<ProcessableAsset> getBuilderProcessableAssets(
    PackageFileResolver fileResolver,
  ) {
    final Set<ProcessableAsset> processableAssets = <ProcessableAsset>{};
    for (final MapEntry<String, List<dynamic>> entry in assets.entries) {
      final int tlmFlag = entry.value[GraphIndex.assetTLMFlag] as int;
      if (tlmFlag == TLMFlag.builder.index || tlmFlag == TLMFlag.both.index) {
        final Asset asset = fileResolver.assetForUri(
          Uri.parse(entry.value[GraphIndex.assetUri]),
        );
        final AssetState state = AssetState.fromIndex(
          entry.value[GraphIndex.assetState],
        );
        processableAssets.add(
          ProcessableAsset(asset, state, TLMFlag.fromIndex(tlmFlag)),
        );
      }
    }
    return processableAssets;
  }

  /// {@template assets_graph.is_builder_config_asset}
  /// Returns whether an asset has builder annotations.
  ///
  /// [id] is the ID of the asset to check.
  /// {@endtemplate}
  bool isBuilderConfigAsset(String id) {
    final int? tlmFlag = assets[id]?[GraphIndex.assetTLMFlag];
    return tlmFlag == TLMFlag.builder.index || tlmFlag == TLMFlag.both.index;
  }

  /// {@template assets_graph.has_processable_assets}
  /// Returns whether there are any assets that need to be processed.
  /// {@endtemplate}
  bool hasProcessableAssets() {
    for (final List<dynamic> asset in assets.values) {
      if (asset[GraphIndex.assetState] != AssetState.processed.index) {
        return true;
      }
    }
    return false;
  }
}

/// {@template scanned_asset}
/// Represents an asset that has been scanned by the build system.
///
/// Contains information about the asset's URI, digest, and annotations.
/// {@endtemplate}
class ScannedAsset {
  /// {@macro scanned_asset}
  ScannedAsset(this.id, this.uri, this.digest, this.hasTopLevelMetadata);

  /// The URI of the asset
  final Uri uri;

  /// The unique identifier of the asset
  final String id;

  /// The content digest of the asset, or null if not computed
  final String? digest;

  /// Whether the asset has top-level metadata annotations
  final bool hasTopLevelMetadata;

  @override
  String toString() {
    return 'PackageAsset{path: $uri, hasTopLevelMetadata: $hasTopLevelMetadata}';
  }
}

/// {@template identifier_ref}
/// Represents a reference to an identifier in Dart code.
///
/// This can be a simple identifier or a prefixed identifier (e.g., 'prefix.name').
/// It can also include information about import prefixes.
/// {@endtemplate}
class IdentifierRef {
  /// The name of the identifier
  final String name;

  /// The prefix of the identifier (e.g., 'prefix' in 'prefix.name')
  final String? prefix;

  /// The import prefix used to import the library containing this identifier
  final String? importPrefix;

  /// A reference to the declaration of this identifier, if resolved
  final DeclarationRef? declarationRef;

  /// {@macro identifier_ref}
  IdentifierRef(
    this.name, {
    this.prefix,
    this.importPrefix,
    this.declarationRef,
  });

  /// Whether this identifier has a prefix
  bool get isPrefixed => prefix != null;

  /// The top-level target of this identifier
  ///
  /// For a prefixed identifier like 'prefix.name', this returns 'prefix'.
  /// For a simple identifier, this returns the name.
  String get topLevelTarget => prefix != null ? prefix! : name;

  /// {@template identifier_ref.from}
  /// Creates an [IdentifierRef] from an [Identifier] AST node.
  ///
  /// [identifier] is the AST node.
  /// [importPrefix] is an optional import prefix.
  /// {@endtemplate}
  factory IdentifierRef.from(Identifier identifier, {String? importPrefix}) {
    if (identifier is PrefixedIdentifier) {
      return IdentifierRef(
        identifier.identifier.name,
        prefix: identifier.prefix.name,
        importPrefix: importPrefix,
      );
    } else {
      return IdentifierRef(identifier.name, importPrefix: importPrefix);
    }
  }

  /// {@template identifier_ref.from_type}
  /// Creates an [IdentifierRef] from a [NamedType] AST node.
  ///
  /// [type] is the AST node.
  /// {@endtemplate}
  factory IdentifierRef.fromType(NamedType type) {
    return IdentifierRef(
      type.name.lexeme,
      importPrefix: type.importPrefix?.name.lexeme,
    );
  }

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer();
    if (prefix != null) {
      buffer.write('$prefix.');
    }
    buffer.write(name);
    if (importPrefix != null) {
      buffer.write('@$importPrefix');
    }
    return buffer.toString();
  }
}
