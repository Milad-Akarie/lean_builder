import 'package:lean_builder/builder.dart';
import 'package:lean_builder/src/graph/references_scanner.dart';
import 'package:meta/meta.dart';

/// Scans the Dart SDK and the specified [packages] using the given [scanner].
@visibleForTesting
void scanDartSdkAndPackages(
  ReferencesScanner scanner, {
  Set<String> packages = const <String>{},
}) {
  final Map<String, List<Asset>> assetsReader = FileAssetReader(
    scanner.fileResolver,
  ).listAssetsFor(<String>{PackageFileResolver.dartSdk, ...packages});
  for (final Asset asset in assetsReader.values.expand((List<Asset> e) => e)) {
    scanner.scan(asset);
  }
}
