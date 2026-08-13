import 'dart:convert';
import 'dart:typed_data';

import 'package:lean_builder/builder.dart';
import 'package:path/path.dart' as p;
import 'package:xxh3/xxh3.dart';

/// A simple in-memory implementation of [Asset] for testing purposes.
/// This is only intended for use in tests and should not be used in production code.
///
/// it's not annotated with `@visibleForTesting` because it is used in the `lib/src/test/resolver.dart` file, which is not a test file.
class StringAsset implements Asset {
  /// The package name used for test assets.
  static const String testPackageName = r'test_';

  /// Creates a new StringAsset with the given [content] and optional [fileName].
  StringAsset(this.content, {String fileName = 'path.dart'}) : stringUri = 'asset:$testPackageName/$fileName';

  /// Creates a new StringAsset with the given [content] and [stringUri].
  StringAsset.withRawUri(this.content, this.stringUri);

  /// The URI string representing this asset.
  final String stringUri;

  @override
  late final String id = xxh3String(Uint8List.fromList(stringUri.codeUnits));

  @override
  Uri get uri => Uri.file('/${Uri.parse(stringUri).path}');

  /// The content of this asset as a string.
  final String content;

  @override
  Uint8List readAsBytesSync() {
    return Uint8List.fromList(content.codeUnits);
  }

  @override
  String readAsStringSync({Encoding encoding = utf8}) {
    return content;
  }

  @override
  bool existsSync() => true;

  @override
  Uri get shortUri => Uri.parse(stringUri);

  @override
  String? get packageName {
    return switch (shortUri.scheme) {
      'dart' => 'dart',
      'package' || 'asset' => shortUri.pathSegments.firstOrNull,
      _ => null,
    };
  }

  @override
  Uri uriWithExtension(String ext) {
    return uri.replace(path: p.withoutExtension(uri.path) + ext);
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'shortUri': shortUri.toString(),
      'uri': uri.toString(),
      'content': content,
    };
  }

  @override
  void safeDelete() {
    // No-op for StringAsset
  }
}
