// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async' show FutureOr;
import 'dart:convert' show Encoding, utf8;
import 'dart:io' show File, Directory;

import 'package:analyzer/dart/ast/ast.dart' show PartDirective;
import 'package:lean_builder/builder.dart';
import 'package:lean_builder/src/build_script/paths.dart';
import 'package:lean_builder/src/element/element.dart';
import 'package:path/path.dart' as p show basename, withoutExtension, join, current, dirname, relative, joinAll;

/// some of the abstractions are borrowed from the build package

/// A single step in a build process.
///
/// This represents a single [asset], logic around resolving as a library,
/// and the ability to read and write assets as allowed by the underlying build
/// system. BuildStep provides an abstraction over the file system operations
/// needed during code generation, allowing builders to focus on transformation
/// logic rather than I/O handling.
abstract class BuildStep {
  /// The primary input for this build step.
  ///
  /// This is the asset that triggered the build step and will be
  /// used as the basis for generating output files.
  Asset get asset;

  /// The [Resolver] for this build step.
  ///
  /// Used to analyze Dart code and resolve references across libraries.
  /// Provides access to AST and element model for the input asset.
  Resolver get resolver;

  /// The set of allowed file extensions for output assets.
  ///
  /// The writing methods [writeAsBytes] and [writeAsString] will throw an
  /// error when attempting to write an asset not part of
  /// the [allowedExtensions].
  Set<String> get allowedExtensions;

  /// Finds assets within the root package that match the [matcher] pattern.
  ///
  /// Useful for locating additional input files needed during generation,
  /// such as template files or configuration files.
  ///
  /// @param matcher The path matcher to match against files in the root package
  /// @param subDir An optional subdirectory to limit the search within the root package.
  /// @return A list of matching assets
  List<Asset> findAssets(PathMatcher matcher, {String? subDir});

  /// Writes [bytes] to a binary file located at [id].
  ///
  /// Returns a [Future] that completes after writing the asset out.
  ///
  /// * Throws an error if the output was not valid (that is,
  ///   the resulting file extension is not in [allowedExtensions])
  ///
  /// **NOTE**: Most `Builder` implementations should not need to `await` this
  /// Future since the runner will be responsible for waiting until all outputs
  /// are written.
  ///
  /// @param bytes The binary content to write
  /// @param extension The extension of the file to be written (must be in [allowedExtensions])
  FutureOr<void> writeAsBytes(List<int> bytes, {required String extension});

  /// Writes [contents] to a text file with the specified [extension] using the given [encoding].
  ///
  /// Returns a [Future] that completes after writing the asset out.
  ///
  /// * Throws an  error if the output was not valid (that is,
  ///   the resulting file extension is not in [allowedExtensions])
  ///
  /// **NOTE**: Most `Builder` implementations should not need to `await` this
  /// Future since the runner will be responsible for waiting until all outputs
  /// are written.
  ///
  /// @param contents The text content to write
  /// @param extension The extension of the file to be written (must be in [allowedExtensions])
  /// @param encoding The character encoding to use (defaults to UTF-8)
  FutureOr<void> writeAsString(
    String contents, {
    required String extension,
    Encoding encoding = utf8,
  });

  /// Returns true if the input library has a part directive for the given extension.
  ///
  /// This is useful for determining if a part file with the given extension
  /// is already included in the library, avoiding duplicate part directives.
  ///
  /// @param extension The extension to check for in part directives
  /// @return True if a part directive exists for a file with the given extension
  bool hasValidPartDirectiveFor(String extension);

  /// The set of output URIs that have been written by this build step.
  ///
  /// This is populated as files are written via [writeAsBytes] or [writeAsString].
  Set<Uri> get outputs;
}

/// Default implementation of [BuildStep] that writes files to the file system.
///
/// This implementation handles the logic of resolving output paths,
/// validating extensions, and writing to the correct location based on
/// whether outputs should be generated to cache or not.
class BuildStepImpl implements BuildStep {
  @override
  final Asset asset;

  @override
  final Resolver resolver;

  /// Whether to write outputs to the build cache instead of alongside inputs.
  ///
  /// When true, outputs are written to the .dart_tool/lean_build/generated directory.
  /// When false, outputs are written alongside their inputs.
  final bool generateToCache;

  /// Creates a new build step for the given asset and resolver.
  ///
  /// @param asset The primary input asset
  /// @param resolver The resolver to use for this build step
  /// @param allowedExtensions The set of allowed output file extensions
  /// @param generateToCache Whether to write outputs to the build cache
  BuildStepImpl(
    this.asset,
    this.resolver, {
    required this.allowedExtensions,
    required this.generateToCache,
  });

  @override
  final Set<String> allowedExtensions;

  @override
  Set<Uri> get outputs => _outputs;

  final Set<Uri> _outputs = <Uri>{};

  /// Resolves the output URI for a file with the given extension.
  ///
  /// When [generateToCache] is true, outputs are written to the build cache.
  /// Otherwise, they're written alongside their inputs.
  ///
  /// @param extension The extension for the output file
  /// @return The URI where the output file should be written
  Uri getOutputUri(String extension) {
    if (generateToCache) {
      final Uri shortUri = asset.shortUri;
      final isPackageUri = shortUri.scheme == 'package';
      assert(
        isPackageUri || shortUri.scheme == 'asset',
        'Only package and asset URIs are supported',
      );
      final parts = isPackageUri
          ? [...shortUri.pathSegments.take(1), 'lib', ...shortUri.pathSegments.skip(1)]
          : shortUri.pathSegments;
      final path = p.joinAll(parts);
      final Uri outputUri = shortUri.replace(
        path: '${p.withoutExtension(path)}$extension',
      );
      _validateOutput(outputUri);
      final String filename = p.basename(outputUri.path);
      final Directory outputDir = Directory(
        p.join(p.current, generatedDir, p.dirname(outputUri.path)),
      );
      if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true);
      }
      return Uri.file(p.join(outputDir.path, filename));
    } else {
      final Uri outputUri = asset.uriWithExtension(extension);
      _validateOutput(outputUri);
      final Directory dir = Directory.fromUri(
        outputUri.replace(path: p.dirname(outputUri.path)),
      );
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return outputUri;
    }
  }

  @override
  FutureOr<void> writeAsBytes(
    List<int> bytes, {
    required String extension,
  }) async {
    final Uri outputUri = getOutputUri(extension);
    await File.fromUri(outputUri).writeAsBytes(bytes);
    _outputs.add(outputUri);
  }

  @override
  FutureOr<void> writeAsString(
    String contents, {
    required String extension,
    Encoding encoding = utf8,
  }) async {
    final Uri outputUri = getOutputUri(extension);
    final File file = File.fromUri(outputUri);
    await file.writeAsString(contents, encoding: encoding);
    _outputs.add(outputUri);
  }

  /// Validates that the output URI has an allowed extension.
  ///
  /// @param uri The URI to validate
  /// @throws ArgumentError if the URI doesn't have an allowed extension
  void _validateOutput(Uri uri) {
    if (!allowedExtensions.any((String e) => uri.path.endsWith(e))) {
      throw ArgumentError(
        'Invalid extension, allowed extensions are: $allowedExtensions',
      );
    }
  }

  @override
  bool hasValidPartDirectiveFor(String extension) {
    final LibraryElementImpl library = resolver.libraryFor(asset);
    final Iterable<PartDirective> partDirectives = library.compilationUnit.directives.whereType<PartDirective>();
    final PackageFileResolver fileResolver = resolver.fileResolver;
    for (final PartDirective partDirect in partDirectives) {
      final String? part = partDirect.uri.stringValue;
      if (part == null) continue;
      final Uri partUri = fileResolver.resolveFileUri(
        Uri.parse(part),
        relativeTo: library.src.uri,
      );
      if (partUri == asset.uriWithExtension(extension)) {
        return true;
      }
    }
    return false;
  }

  late final FileAssetReader _assetReader = FileAssetReader(
    resolver.fileResolver,
  );

  @override
  List<Asset> findAssets(PathMatcher matcher, {String? subDir}) {
    return _assetReader.findRootAssets(matcher, subDir: subDir);
  }
}

/// A specialized build step that buffers output content to be written as a single part file.
///
/// Rather than writing each output immediately, SharedBuildStep collects all content
/// written to it and then writes it as a single file with appropriate part directive
/// when [flush] is called. This is useful for generating part files that contain
/// multiple pieces of generated code.
class SharedBuildStep extends BuildStepImpl {
  /// Buffer that collects all content written to this build step.
  final StringBuffer _buffer = StringBuffer();

  /// The URI where the final output will be written.
  final Uri outputUri;

  /// Creates a new shared build step for the given asset and resolver.
  ///
  /// @param asset The primary input asset
  /// @param resolver The resolver to use for this build step
  /// @param outputUri The URI where the final output will be written
  SharedBuildStep(super.asset, super.resolver, {required this.outputUri})
    : super(
        allowedExtensions: <String>{SharedPartBuilder.extension},
        generateToCache: false,
      );

  @override
  Future<void> writeAsBytes(
    List<int> bytes, {
    required String extension,
  }) async {
    assert(
      outputUri == asset.uriWithExtension(extension),
      'Unexpected output uri, expected $outputUri',
    );
    _buffer.writeln(utf8.decode(bytes));
  }

  @override
  Future<void> writeAsString(
    String contents, {
    required String extension,
    Encoding encoding = utf8,
  }) async {
    assert(
      encoding == utf8,
      'Only utf8 encoding is supported for deferred outputs',
    );
    assert(
      outputUri == asset.uriWithExtension(extension),
      'Unexpected output uri, expected $outputUri',
    );
    _buffer.writeln(contents);
  }

  /// Writes the buffered content to the output file and clears the buffer.
  ///
  /// The output file will include a part directive that points back to the
  /// original input file. If the buffer is empty, no file is written.
  ///
  /// @return A future that completes when the file has been written
  Future<void> flush() async {
    if (_buffer.isEmpty) return;
    final String partOf = p.relative(
      asset.uri.path,
      from: p.dirname(outputUri.path),
    );
    final String header = <String>[defaultFileHeader, "part of '$partOf';"].join('\n\n');
    final String content = _buffer.toString();

    final File outputFile = File.fromUri(outputUri);
    await outputFile.writeAsString('$header\n\n$content');
    _buffer.clear();
    outputs.add(outputUri);
  }
}
