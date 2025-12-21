import 'dart:collection' show HashMap, HashSet;
import 'dart:io' show File;
import 'dart:isolate' show Isolate;

import 'package:lean_builder/builder.dart';
import 'package:lean_builder/runner.dart';
import 'package:lean_builder/src/graph/references_scan_manager.dart';
import 'package:lean_builder/src/graph/references_scanner.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/runner/build_utils.dart';

import '../../test.dart';
import 'build_result.dart';

/// {@template build_phase}
/// Represents a phase in the build process.
///
/// A build phase contains a set of [BuilderEntry] instances that can run
/// in parallel. The phase is responsible for:
///
/// - Preparing the builders for execution
/// - Distributing assets across isolates for parallel processing
/// - Collecting and consolidating results
/// - Managing generated outputs
/// - Cleaning up stale outputs
///
/// Build phases execute sequentially, but the builders within a phase
/// can run in parallel.
/// {@endtemplate}
class BuildPhase {
  /// The resolver used for analyzing Dart code
  final ResolverImpl resolver;

  /// The builders that belong to this phase
  final List<BuilderEntry> builders;

  /// {@macro build_phase}
  BuildPhase(this.resolver, this.builders);

  /// Tracks outputs from previous builds that might need cleaning up
  final Set<String> _oldOutputs = <String>{};

  /// The asset graph used to track dependencies and outputs
  AssetsGraph get graph => resolver.graph;

  /// The file resolver used to resolve file references
  PackageFileResolver get fileResolver => resolver.fileResolver;

  /// {@template build_phase.before_build}
  /// Prepares the phase for building.
  ///
  /// This method:
  /// 1. Prepares each builder by registering custom type annotations
  /// 2. Identifies old outputs that might need to be cleaned up
  /// 3. Removes generated outputs from the list of assets to process
  ///
  /// [resolver] The resolver to use for analysis
  /// [assets] The list of assets to process
  /// {@endtemplate}
  void beforeBuild(ResolverImpl resolver, List<ProcessableAsset> assets) {
    final HashSet<String> outputExtensions = HashSet<String>();
    for (final BuilderEntry builder in builders) {
      // some builder entries need to do stuff before the build
      builder.onPrepare(resolver);
      outputExtensions.addAll(builder.outputExtensions);
    }

    for (final ProcessableAsset entry in Set<ProcessableAsset>.of(assets)) {
      final Set<String>? outputs = graph.outputs[entry.asset.id];
      if (outputs != null) {
        for (final String output in outputs) {
          final Uri? outputUri = graph.uriForAssetOrNull(output);
          if (outputUri == null) continue;
          if (outputExtensions.any((String e) => outputUri.path.endsWith(e))) {
            _oldOutputs.add(output);
            assets.removeWhere((entry) => entry.asset.id == output);
          }
        }
      }
    }
  }

  /// {@template build_phase.build}
  /// Builds all assets in this phase using the configured builders.
  ///
  /// This method:
  /// 1. Determines whether to use parallel or sequential processing
  /// 2. Distributes assets across isolates for large builds
  /// 3. Executes builders on each asset
  /// 4. Collects and consolidates results
  /// 5. Finalizes the phase by updating the asset graph
  ///
  /// [assets] The set of assets to process
  ///
  /// Returns a [PhaseResult] containing information about generated outputs
  /// and any errors that occurred.
  /// {@endtemplate}
  Future<PhaseResult> build(Set<ProcessableAsset> assets) async {
    Logger.debug(
      'Running build phase for $builders, assets count: ${assets.length}',
    );

    if (assets.length < 15) {
      final BuildResult result = await _buildChunk(assets);
      return _finalizePhase(result.outputs, result.failedAssets);
    }

    final List<Set<ProcessableAsset>> chunks = calculateChunks(assets);
    final List<Future<BuildResult>> chunkResults = <Future<BuildResult>>[];
    for (final Set<ProcessableAsset> chunk in chunks) {
      final Future<BuildResult> future = Isolate.run<BuildResult>(() {
        return _buildChunk(chunk);
      });
      chunkResults.add(future);
    }

    final HashMap<Asset, Set<Uri>> phaseOutputs = HashMap<Asset, Set<Uri>>();
    final List<FailedAsset> failedAssets = <FailedAsset>[];
    for (final result in await Future.wait(chunkResults)) {
      phaseOutputs.addAll(result.outputs);
      failedAssets.addAll(result.failedAssets);
    }
    return _finalizePhase(phaseOutputs, failedAssets);
  }

  /// {@template build_phase._finalize_phase}
  /// Finalizes the build phase by:
  ///
  /// 1. Scanning generated Dart files to update the asset graph
  /// 2. Registering outputs in the asset graph
  /// 3. Cleaning up any stale outputs
  ///
  /// [outputs] Map of source assets to their generated output URIs
  /// [failedAssets] List of assets that failed to build
  ///
  /// Returns a [PhaseResult] containing information about outputs and errors
  /// {@endtemplate}
  PhaseResult _finalizePhase(
    Map<Asset, Set<Uri>> outputs,
    List<FailedAsset> failedAssets,
  ) {
    final scanner = ReferencesScanner(resolver.graph, resolver.fileResolver);
    final Set<Uri> outputUris = <Uri>{};
    for (final MapEntry<Asset, Set<Uri>> entry in outputs.entries) {
      for (final Uri uri in entry.value) {
        final Asset output = resolver.fileResolver.assetForUri(uri);
        scanner.scan(output, forceOverride: true);
        resolver.graph.addOutput(entry.key, output);
        outputUris.add(uri);
      }
    }
    final Set<Uri> deletedOutputs = _cleanUp(outputUris);
    return PhaseResult(
      outputs: outputUris,
      failedAssets: failedAssets,
      deletedOutputs: deletedOutputs,
    );
  }

  /// {@template build_phase._clean_up}
  /// Cleans up stale outputs that were not regenerated in this build.
  ///
  /// This method:
  /// 1. Compares old outputs to the newly generated ones
  /// 2. Deletes files that are no longer needed
  /// 3. Updates the asset graph to remove references to deleted outputs
  ///
  /// [outputUris] The set of newly generated output URIs
  ///
  /// Returns a set of URIs representing deleted outputs
  /// {@endtemplate}
  Set<Uri> _cleanUp(Set<Uri> outputUris) {
    final Set<Uri> deletedOutputs = <Uri>{};
    for (final String oldOutput in _oldOutputs) {
      final Uri? oldOutputUri = graph.uriForAssetOrNull(oldOutput);
      if (oldOutputUri == null) continue;
      final Uri fileOutputUri = fileResolver.resolveFileUri(oldOutputUri);
      if (!outputUris.contains(fileOutputUri)) {
        deletedOutputs.add(fileOutputUri);
        final File file = File.fromUri(fileOutputUri);
        if (file.existsSync()) {
          file.deleteSync();
        }
        graph.removeOutput(oldOutput);
      }
    }
    _oldOutputs.clear();
    return deletedOutputs;
  }

  Future<BuildResult> _buildChunk(Set<ProcessableAsset> chunk) async {
    final HashMap<Asset, Set<Uri>> chunkOutputs = HashMap<Asset, Set<Uri>>();
    final List<FailedAsset> chunkErrors = <FailedAsset>[];
    for (final ProcessableAsset entry in chunk) {
      try {
        final BuildCandidate candidate = BuildCandidate(
          entry.asset,
          entry.tlmFlag.hasNormal,
          resolver.graph.exportedSymbolsOf(entry.asset.id),
        );
        for (final BuilderEntry builderEntry in builders) {
          if (!builderEntry.shouldGenerateFor(candidate)) continue;
          final Set<Uri> generatedOutputs = await builderEntry.build(
            resolver,
            entry.asset,
          );
          chunkOutputs.putIfAbsent(entry.asset, () => <Uri>{}).addAll(generatedOutputs);
        }
      } catch (e, stack) {
        chunkErrors.add(FailedAsset(entry.asset, e, stack));
      }
    }
    return BuildResult(chunkOutputs, chunkErrors);
  }
}
