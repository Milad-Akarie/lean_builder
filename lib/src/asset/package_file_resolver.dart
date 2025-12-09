import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show File, Directory, Platform;
import 'dart:typed_data' show Uint8List;

import 'package:lean_builder/src/utils.dart';
import 'package:meta/meta.dart' show visibleForTesting;
import 'package:path/path.dart' as p show join, joinAll, dirname, normalize, current;
import 'package:xxh3/xxh3.dart' show xxh3String;
import 'asset.dart';
import 'errors.dart';

/// Path to the Dart package configuration file.
const String _packageConfigLocation = '.dart_tool/package_config.json';

/// Special package name for Flutter's SDK implementation.
const String _skyEnginePackage = 'sky_engine';

/// {@template package_file_resolver}
/// Abstract interface for resolving package file paths in a Dart project.
///
/// This resolver handles the translation between different URI schemes used by Dart
/// (package:, asset:, dart:) and absolute file system paths. It's responsible for
/// determining which package a file belongs to and normalizing URI references.
/// {@endtemplate}
abstract class PackageFileResolver {
  /// {@template package_file_resolver.dirs_scheme}
  /// Mapping of directory names to URI schemes.
  ///
  /// This map determines which URI scheme to use based on the directory structure:
  /// - 'lib' directory maps to 'package:' URIs
  /// - 'test', 'bin', and 'codegen' directories map to 'asset:' URIs
  /// {@endtemplate}
  static const Map<String, String> dirsScheme = <String, String>{
    'lib': 'package',
    'test': 'asset',
    'bin': 'asset',
    'codegen': 'asset',
  };

  /// {@template package_file_resolver.dart_sdk}
  /// Special identifier for the Dart SDK in package paths.
  /// {@endtemplate}
  static const String dartSdk = r'$sdk';

  /// {@template package_file_resolver.dart_sdk_path}
  /// The absolute URI path to the Dart SDK on the system.
  ///
  /// This is derived from the location of the Dart executable.
  /// {@endtemplate}
  static final Uri dartSdkPath = Uri.file(
    p.dirname(p.dirname(Platform.resolvedExecutable)),
  );

  /// {@template package_file_resolver.is_dir_supported}
  /// Checks if a given directory scheme is supported by this resolver.
  ///
  /// @param scheme The directory scheme to check
  /// @return true if the scheme is supported, false otherwise
  /// {@endtemplate}
  static bool isDirSupported(String? scheme) {
    if (scheme == null) return false;
    return dirsScheme.containsKey(scheme);
  }

  /// {@template package_file_resolver.resolve_file_uri}
  /// Resolves a URI to an absolute URI on the file system.
  ///
  /// This method handles various URI schemes (package:, asset:, dart:)
  /// and transforms them into absolute file: URIs, which can be used
  /// to read files from the file system.
  ///
  /// @param uri The URI to resolve
  /// @param relativeTo An optional base URI for resolving relative URIs
  /// @return The absolute file URI
  /// {@endtemplate}
  Uri resolveFileUri(Uri uri, {Uri? relativeTo});

  /// {@template package_file_resolver.to_short_uri}
  /// Converts an absolute URI to a short, reversible form.
  ///
  /// This method transforms absolute file: URIs into package:, dart:, or asset:
  /// URIs, which are more concise and portable across different machines.
  ///
  /// Examples:
  /// - package:name/src/file.dart
  /// - dart:core/bool.dart
  /// - asset:package/test/file.dart
  ///
  /// @param uri The URI to convert
  /// @return The shortened URI
  /// {@endtemplate}
  Uri toShortUri(Uri uri);

  /// {@template package_file_resolver.package_for}
  /// Returns the package name that contains the specified URI.
  ///
  /// This method determines which package a file belongs to by comparing
  /// the file's path against known package root directories.
  ///
  /// @param uri The URI to find the package for
  /// @param relativeTo An optional base URI for resolving relative URIs
  /// @return The name of the package containing the URI
  /// @throws PackageNotFoundError if no matching package is found
  /// {@endtemplate}
  String packageFor(Uri uri, {Uri? relativeTo});

  /// {@template package_file_resolver.path_for}
  /// Returns the absolute path for a package.
  ///
  /// @param package The name of the package
  /// @return The absolute path to the package root
  /// @throws PackageNotFoundError if the package is not found
  /// {@endtemplate}
  String pathFor(String package);

  /// {@template package_file_resolver.asset_for_uri}
  /// Creates an Asset object for the specified URI.
  ///
  /// An Asset represents a file in the build system with additional metadata.
  ///
  /// @param uri The URI to create an asset for
  /// @param relativeTo An optional base asset for resolving relative URIs
  /// @return The Asset object for the URI
  /// @throws AssetUriError if the asset cannot be created
  /// {@endtemplate}
  Asset assetForUri(Uri uri, {Asset? relativeTo});

  /// {@template package_file_resolver.packages}
  /// The set of available package names known to this resolver.
  /// {@endtemplate}
  Set<String> get packages;

  /// {@template package_file_resolver.packages_hash}
  /// A hash of the package configuration, used for caching and invalidation.
  /// {@endtemplate}
  String get packagesHash;

  /// {@template package_file_resolver.for_root}
  /// Creates a resolver for the current working directory.
  ///
  /// This factory method loads the package configuration from the current
  /// directory and creates a resolver that can handle URIs relative to it.
  ///
  /// @return A new PackageFileResolver for the current directory
  /// @throws PackageConfigNotFound if the package configuration file is missing
  /// @throws PackageConfigParseError if the configuration file is invalid
  /// {@endtemplate}
  factory PackageFileResolver.forRoot() {
    final String configUri = p.join(p.current, _packageConfigLocation);
    return PackageFileResolverImpl.forRoot(configUri, rootPackageName);
  }

  /// {@template package_file_resolver.from_json}
  /// Creates a resolver from a serialized JSON representation.
  ///
  /// This factory method reconstructs a resolver from data previously
  /// saved with [toJson].
  ///
  /// @param data The JSON data to reconstruct from
  /// @return A new PackageFileResolver with the restored state
  /// {@endtemplate}
  factory PackageFileResolver.fromJson(Map<String, dynamic> data) {
    final Map<String, String> packageToPath = (data['packageToPath'] as Map<dynamic, dynamic>).cast<String, String>();

    return PackageFileResolverImpl(
      packageToPath,
      packagesHash: data['packagesHash'],
      rootPackage: data['rootPackage'],
    );
  }

  /// {@template package_file_resolver.root_package}
  /// The name of the root package for this resolver.
  ///
  /// This is typically the package in which the resolver was created.
  /// {@endtemplate}
  String get rootPackage;

  /// {@template package_file_resolver.to_json}
  /// Serializes this resolver to a JSON-compatible format.
  ///
  /// The resulting map can be used with [PackageFileResolver.fromJson]
  /// to reconstruct the resolver.
  ///
  /// @return A map representing the serialized resolver state
  /// {@endtemplate}
  Map<String, dynamic> toJson();
}

/// {@template package_file_resolver_impl}
/// Implementation of file resolution for Dart package system.
///
/// This class provides the concrete implementation of [PackageFileResolver]
/// with support for resolving different URI schemes, handling package paths,
/// and caching assets for improved performance.
/// {@endtemplate}
class PackageFileResolverImpl implements PackageFileResolver {
  /// {@template package_file_resolver_impl.package_to_path}
  /// Mapping from package names to their absolute paths.
  /// {@endtemplate}
  final Map<String, String> packageToPath;

  /// {@template package_file_resolver_impl.path_to_package}
  /// Reverse mapping from absolute paths to their package names.
  /// {@endtemplate}
  final Map<String, String> pathToPackage;

  @override
  final String packagesHash;

  @override
  final String rootPackage;

  /// {@template package_file_resolver_impl.constructor}
  /// Creates a new package file resolver with the specified mappings.
  ///
  /// @param packageToPath Mapping from package names to absolute paths
  /// @param packagesHash Hash of the package configuration
  /// @param rootPackage Name of the root package
  /// {@endtemplate}
  PackageFileResolverImpl(
    this.packageToPath, {
    required this.packagesHash,
    required this.rootPackage,
  }) : pathToPackage = packageToPath.map(
         (String k, String v) => MapEntry<String, String>(v, k),
       );

  @override
  Set<String> get packages => packageToPath.keys.toSet();

  @override
  String pathFor(String package) {
    if (packageToPath.containsKey(package)) {
      return packageToPath[package]!;
    }
    throw PackageNotFoundError('Package "$package" not found');
  }

  /// {@template package_file_resolver_impl.for_root}
  /// Creates a resolver for the specified root directory.
  ///
  /// @param path Path to the package configuration file
  /// @param rootPackage Name of the root package
  /// @return A new PackageFileResolverImpl
  /// @throws PackageConfigNotFound if the package configuration file is missing
  /// @throws PackageConfigParseError if the configuration file is invalid
  /// {@endtemplate}
  factory PackageFileResolverImpl.forRoot(String path, String rootPackage) {
    final PackageConfig config = loadPackageConfig(path);
    return PackageFileResolverImpl(
      config.packageToPath,
      packagesHash: config.packagesHash,
      rootPackage: rootPackage,
    );
  }

  /// {@template package_file_resolver_impl.load_package_config}
  /// Helper method to load and parse package configuration from a file.
  ///
  /// @param packageConfigPath Path to the package configuration file
  /// @return A PackageConfig object with the parsed configuration
  /// @throws PackageConfigNotFound if the file doesn't exist
  /// @throws PackageConfigParseError if the file is invalid
  /// {@endtemplate}
  static PackageConfig loadPackageConfig(String packageConfigPath) {
    final File packageConfig = File(packageConfigPath);
    if (!packageConfig.existsSync()) {
      throw PackageConfigNotFound();
    }
    try {
      final dynamic json = jsonDecode(packageConfig.readAsStringSync());
      final List<dynamic> packageConfigJson = json['packages'] as List<dynamic>;
      final String packagesHash = xxh3String(
        Uint8List.fromList(jsonEncode(packageConfigJson).codeUnits),
      );
      final Map<String, String> packageToPath = <String, String>{};
      for (dynamic entry in packageConfigJson) {
        String name = entry['name'] as String;
        if (name[0] == '_') continue;
        if (name == _skyEnginePackage) {
          name = PackageFileResolver.dartSdk;
        }
        final Uri packageUri = Uri.parse(entry['rootUri'] as String);
        String resolvedPath = packageUri.toString();
        if (!packageUri.hasScheme) {
          Uri absoluteUri = packageUri;
          absoluteUri = Directory.current.uri.resolve(
            packageUri.pathSegments.skip(1).join('/'),
          );
          resolvedPath = absoluteUri.toString();
        }
        packageToPath[name] = resolvedPath;
      }
      if (!packageToPath.containsKey(PackageFileResolver.dartSdk)) {
        final String sdkPath = PackageFileResolver.dartSdkPath.toString();
        packageToPath[PackageFileResolver.dartSdk] = sdkPath;
      }
      return PackageConfig(packageToPath, packagesHash);
    } catch (e) {
      throw PackageConfigParseError(packageConfig.path, e);
    }
  }

  @override
  String packageFor(Uri uri, {Uri? relativeTo}) {
    if (uri.scheme == 'dart') {
      return PackageFileResolver.dartSdk;
    }
    final String path = resolveFileUri(
      uri,
      relativeTo: relativeTo,
    ).replace(scheme: 'file').toString();
    String? bestMatch;
    int bestMatchLength = 0;
    for (final MapEntry<String, String> entry in pathToPackage.entries) {
      final String rootPath = entry.key;
      final String packageName = entry.value;

      // Check for exact match
      if (path == rootPath) {
        return packageName;
      }
      // Check if uri starts with this root path
      if (path.startsWith(rootPath) && (rootPath.endsWith('/') || path.substring(rootPath.length).startsWith('/'))) {
        // If this match is longer than our current best match, use it
        if (rootPath.length > bestMatchLength) {
          bestMatch = packageName;
          bestMatchLength = rootPath.length;
        }
      }
    }
    if (bestMatch == null) {
      throw PackageNotFoundError('Package not found for URI: $uri');
    }
    return bestMatch;
  }

  @override
  Uri toShortUri(Uri uri) {
    if (uri.scheme == 'package') {
      return uri;
    } else if (uri.scheme == 'file') {
      final String packageName = packageFor(uri);

      final Uri rootUri = Uri.parse(packageToPath[packageName]!);
      // remove trailing slash if present
      int rootSegLength = rootUri.pathSegments.length;
      if (rootUri.pathSegments.last == '') {
        rootSegLength--;
      }
      final List<String> segments = uri.pathSegments.sublist(rootSegLength);
      final String dir = segments[0];

      if (packageName == PackageFileResolver.dartSdk) {
        return Uri(scheme: 'dart', pathSegments: segments.skip(1));
      }

      final String scheme = PackageFileResolver.dirsScheme[dir] ?? 'asset';
      final int dirsToSkip = scheme == 'package' ? 1 : 0;
      return Uri(
        scheme: scheme,
        pathSegments: <String>[packageName, ...segments.skip(dirsToSkip)],
      );
    }
    return uri;
  }

  /// {@template package_file_resolver_impl.asset_cache}
  /// Cache of previously created assets, indexed by their request identifier.
  ///
  /// This improves performance by avoiding redundant asset creation and
  /// URI resolution for the same inputs.
  /// {@endtemplate}
  final Map<String, Asset> _assetCache = <String, Asset>{};

  /// {@template package_file_resolver_impl.register_asset}
  /// Manually registers an asset in the cache.
  ///
  /// This is primarily used for testing to pre-populate the cache.
  ///
  /// @param asset The asset to register
  /// @param relativeTo An optional base asset for creating the cache key
  /// {@endtemplate}
  @visibleForTesting
  void registerAsset(Asset asset, {Asset? relativeTo}) {
    final uri = asset.uri;
    final String reqId = uri.hasScheme ? uri.toString() : '$uri@${relativeTo?.uri}';
    _assetCache[reqId] = asset;
  }

  @override
  Asset assetForUri(Uri uri, {Asset? relativeTo}) {
    final String reqId = uri.hasScheme ? uri.toString() : '$uri@${relativeTo?.uri}';
    if (_assetCache.containsKey(reqId)) {
      return _assetCache[reqId]!;
    }
    assert(!uri.hasEmptyPath, 'URI path cannot be empty');
    final Uri absoluteUri = resolveFileUri(uri, relativeTo: relativeTo?.uri);
    final Uri shortUri = toShortUri(absoluteUri);
    try {
      final String id = xxh3String(
        Uint8List.fromList(shortUri.toString().codeUnits),
      );
      final Asset asset = Asset(
        file: File.fromUri(absoluteUri),
        shortUri: shortUri,
        id: id,
      );
      return _assetCache[reqId] = asset;
    } catch (e) {
      throw AssetUriError(uri.toString(), e.toString());
    }
  }

  @override
  Uri resolveFileUri(Uri uri, {Uri? relativeTo}) {
    return switch (uri.scheme) {
      'package' => _resolvePackageUri(uri),
      'asset' => _resolveAssetUri(uri),
      'dart' => _resolveDartUri(uri),
      '' => _resolveRelativeUri(uri, relativeTo),
      _ => uri,
    };
  }

  /// {@template package_file_resolver_impl.resolve_package_uri}
  /// Resolves a package: URI to an absolute file: URI.
  ///
  /// Package URIs are resolved by mapping the package name to its root path
  /// and appending the lib directory and the remaining path segments.
  ///
  /// @param uri The package: URI to resolve
  /// @return The absolute file: URI
  /// {@endtemplate}
  Uri _resolvePackageUri(Uri uri) {
    final String package = uri.pathSegments.first;
    final String? packagePath = packageToPath[package];
    if (packagePath != null) {
      return Uri.parse(
        p.joinAll(<String>[packagePath, 'lib', ...uri.pathSegments.skip(1)]),
      );
    }
    return uri;
  }

  /// {@template package_file_resolver_impl.resolve_asset_uri}
  /// Resolves an asset: URI to an absolute file: URI.
  ///
  /// Asset URIs are resolved by mapping the package name to its root path
  /// and appending the remaining path segments.
  ///
  /// @param uri The asset: URI to resolve
  /// @return The absolute file: URI
  /// {@endtemplate}
  Uri _resolveAssetUri(Uri uri) {
    final String package = uri.pathSegments.first;
    final String? packagePath = packageToPath[package];
    if (packagePath != null) {
      return Uri.parse(
        p.joinAll(<String>[packagePath, ...uri.pathSegments.skip(1)]),
      );
    }
    return uri;
  }

  /// {@template package_file_resolver_impl.resolve_dart_uri}
  /// Resolves a dart: URI to an absolute file: URI.
  ///
  /// Dart URIs are resolved by mapping to the appropriate location in the
  /// Dart SDK directory. This method tries several common patterns for
  /// locating SDK libraries.
  ///
  /// @param uri The dart: URI to resolve
  /// @return The absolute file: URI
  /// {@endtemplate}
  Uri _resolveDartUri(Uri uri) {
    final String sdkPath = packageToPath[PackageFileResolver.dartSdk]!;

    // Handle special case for dart:core and other standard libraries
    String libraryName = uri.path;

    // remove the leading underscore for the internal library
    /// todo: investigate why this is needed
    if (libraryName == '_internal') {
      libraryName = libraryName.substring(1);
    }
    // The SDK libraries are typically located at sdk_path/lib/library_name/library_name.dart
    // First try the standard pattern
    final Uri absoluteUri = Uri.parse(
      p.joinAll(<String>[sdkPath, 'lib', libraryName, '$libraryName.dart']),
    );
    if (File.fromUri(absoluteUri).existsSync()) {
      return absoluteUri;
    }

    // Some libraries might be directly in the lib directory
    final Uri directUri = Uri.parse(
      p.joinAll(<String>[sdkPath, 'lib', ...uri.pathSegments]),
    );
    if (File.fromUri(directUri).existsSync()) {
      return directUri;
    }

    // For libraries with additional path segments
    if (uri.pathSegments.length > 1) {
      final List<String> segments = uri.pathSegments;
      final String baseLib = segments.first;
      final List<String> fileSegments = segments.sublist(1);
      final Uri libPath = Uri.parse(
        p.joinAll(<String>[sdkPath, 'lib', baseLib, ...fileSegments]),
      );
      if (File.fromUri(libPath).existsSync()) {
        return libPath;
      }
    }

    // If we can't find the file, return the best guess
    return directUri;
  }

  /// {@template package_file_resolver_impl.resolve_relative_uri}
  /// Resolves a relative URI to an absolute file: URI.
  ///
  /// Relative URIs are resolved against the provided base URI, which must
  /// be present for this method to work.
  ///
  /// @param uri The relative URI to resolve
  /// @param relativeTo The base URI to resolve against
  /// @return The absolute file: URI
  /// @throws InvalidPathError if relativeTo is null or the path is invalid
  /// {@endtemplate}
  Uri _resolveRelativeUri(Uri uri, Uri? relativeTo) {
    if (relativeTo == null) {
      throw InvalidPathError('Relative URI requires a base URI');
    }
    final String baseDir = p.dirname(relativeTo.path);
    final String uriPath = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
    try {
      final String normalized = p.normalize(p.join(baseDir, uriPath));
      return Uri(scheme: 'file', path: normalized);
    } catch (e) {
      throw InvalidPathError(uri.toString());
    }
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'packageToPath': packageToPath,
      'packagesHash': packagesHash,
      'rootPackage': rootPackage,
    };
  }
}

/// {@template package_config}
/// Container class to hold package configuration data.
///
/// This class stores the mapping from package names to their paths,
/// along with a hash of the configuration for caching purposes.
/// {@endtemplate}
class PackageConfig {
  /// {@template package_config.package_to_path}
  /// Mapping from package names to their absolute paths.
  /// {@endtemplate}
  final Map<String, String> packageToPath;

  /// {@template package_config.packages_hash}
  /// A hash of the package configuration, used for caching and invalidation.
  /// {@endtemplate}
  final String packagesHash;

  /// {@template package_config.constructor}
  /// Creates a new package configuration.
  ///
  /// @param packageToPath Mapping from package names to absolute paths
  /// @param packagesHash Hash of the package configuration
  /// {@endtemplate}
  PackageConfig(this.packageToPath, this.packagesHash);
}
