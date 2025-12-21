import 'dart:async';

import 'dart:convert';

import 'package:lean_builder/builder.dart';
import 'package:lean_builder/element.dart';
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/graph/references_scanner.dart';
import 'package:lean_builder/src/test/scanner.dart';
import 'package:lean_builder/src/utils.dart';
import 'package:lean_builder/test.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

@visibleForTesting
/// Creates an in-memory [InMemoryBuildStep] from a raw string [content].
///
/// This is a convenience wrapper around [buildStepForTestAsset] that constructs a
/// [StringAsset] from [content]. The returned build step records outputs in
/// memory instead of writing to disk which makes it suitable for tests.
InMemoryBuildStep buildStepForTestContent(
  String content, {
  Set<String> allowedExtensions = const {'g.dart'},
  Set<String> includePackages = const {},
}) {
  return buildStepForTestAsset(
    StringAsset(content),
    allowedExtensions: allowedExtensions,
    includePackages: includePackages,
  );
}

@visibleForTesting
/// Creates an in-memory [InMemoryBuildStep] for the given [asset].
///
/// [allowedExtensions] controls which output extensions this build step will
/// accept when writing files. Any [extraAssets] will be scanned and added to
/// the internal assets graph so that references between assets are available
/// to the resolver and can be resolved during tests.
InMemoryBuildStep buildStepForTestAsset(
  Asset asset, {
  Set<String> allowedExtensions = const {'.g.dart'},
  Set<String> includePackages = const {},
  List<Asset> extraAssets = const [],
}) {
  final fileResolver = getTestFileResolver();
  final graph = AssetsGraph('hash');
  final scanner = ReferencesScanner(graph, fileResolver);
  scanDartSdkAndPackages(scanner, packages: includePackages);
  for (final extraAsset in extraAssets) {
    scanner.scan(extraAsset);
  }
  scanner.scan(asset);
  final resolver = Resolver.from(graph, fileResolver, SourceParser());
  return InMemoryBuildStep(asset, resolver, allowedExtensions: allowedExtensions);
}

@visibleForTesting
/// Creates a [PackageFileResolverImpl] for tests.
///
/// The resolver maps the test package to [testFilePath] and uses the provided
/// [config] for other package mappings.
PackageFileResolverImpl getTestFileResolver() {
  final testFilePath = Uri.file('/${StringAsset.testPackageName}');
  final String configUri = p.join(p.current, packageConfigLocation);
  final PackageConfig config = PackageFileResolverImpl.loadPackageConfig(configUri);
  final fileResolver = PackageFileResolverImpl(
    {
      StringAsset.testPackageName: testFilePath.toString(),
      ...config.packageToPath,
    },
    packagesHash: config.packagesHash,
    rootPackage: rootPackageName,
  );
  return fileResolver;
}

/// An in-memory implementation of [BuildStep] used by tests.
///
/// Instead of writing outputs to disk or a build cache this class captures the
/// last written output as a [StringAsset] in [output]. This simplifies
/// assertions in tests that need to verify generated content. The build step
/// is constructed with `generateToCache: false` so it won't attempt to update
/// any external cache.
@visibleForTesting
class InMemoryBuildStep extends BuildStepImpl {
  /// The last asset written by this build step as a [StringAsset].
  ///
  /// `null` if no output has been written yet.
  StringAsset? output;

  /// The resolved [LibraryElement] for the build step's input asset.
  LibraryElement get library => resolver.resolveLibrary(asset);

  /// Creates an [InMemoryBuildStep] for the given [asset] and [resolver].
  ///
  /// [allowedExtensions] specifies which output extensions are accepted when
  /// calling [writeAsBytes] or [writeAsString].
  InMemoryBuildStep(super.asset, super.resolver, {required super.allowedExtensions}) : super(generateToCache: false);

  @override
  /// Writes [bytes] to the in-memory output and records the resulting
  /// [StringAsset] in [output].
  ///
  /// The [extension] parameter determines the output asset URI extension.
  FutureOr<void> writeAsBytes(List<int> bytes, {required String extension}) {
    final uri = asset.uriWithExtension(extension);
    output = StringAsset.withRawUri(utf8.decode(bytes), uri.toString());
    return null;
  }

  @override
  /// Writes [contents] to the in-memory output and records the resulting
  /// [StringAsset] in [output].
  ///
  /// The [extension] parameter determines the output asset URI extension.
  FutureOr<void> writeAsString(String contents, {required String extension, Encoding encoding = utf8}) {
    final uri = asset.uriWithExtension(extension);
    output = StringAsset.withRawUri(contents, uri.toString());
    return null;
  }
}
