import 'dart:convert';
import 'dart:io';
import 'package:lean_builder/src/asset/asset.dart';
import 'package:test/test.dart';

void main() {
  group('FileAsset', () {
    late Directory tempDir;
    late File testFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('asset_test_');
      testFile = File('${tempDir.path}/test.dart');
      testFile.writeAsStringSync('test content');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('should create FileAsset with factory constructor', () {
      final asset = Asset(
        id: 'test_id',
        shortUri: Uri.parse('package:test/test.dart'),
        file: testFile,
      );

      expect(asset, isA<FileAsset>());
      expect(asset.id, equals('test_id'));
      expect(asset.shortUri.toString(), equals('package:test/test.dart'));
      expect(asset.uri, equals(testFile.uri));
    });

    test('should read file as bytes', () {
      final asset = FileAsset(
        id: 'test_id',
        shortUri: Uri.parse('package:test/test.dart'),
        file: testFile,
      );

      final bytes = asset.readAsBytesSync();
      expect(bytes, isNotEmpty);
      expect(utf8.decode(bytes), equals('test content'));
    });

    test('should read file as string', () {
      final asset = FileAsset(
        id: 'test_id',
        shortUri: Uri.parse('package:test/test.dart'),
        file: testFile,
      );

      final content = asset.readAsStringSync();
      expect(content, equals('test content'));
    });

    test('should read file as string with custom encoding', () {
      final asset = FileAsset(
        id: 'test_id',
        shortUri: Uri.parse('package:test/test.dart'),
        file: testFile,
      );

      final content = asset.readAsStringSync(encoding: utf8);
      expect(content, equals('test content'));
    });

    test('should check if file exists', () {
      final asset = FileAsset(
        id: 'test_id',
        shortUri: Uri.parse('package:test/test.dart'),
        file: testFile,
      );

      expect(asset.existsSync(), isTrue);

      testFile.deleteSync();
      expect(asset.existsSync(), isFalse);
    });

    test('should convert to JSON', () {
      final asset = FileAsset(
        id: 'test_id',
        shortUri: Uri.parse('package:test/test.dart'),
        file: testFile,
      );

      final json = asset.toJson();
      expect(json['id'], equals('test_id'));
      expect(json['shortUri'], equals('package:test/test.dart'));
      expect(json['uri'], equals(testFile.uri.toString()));
    });

    test('should create from JSON', () {
      final json = {
        'id': 'test_id',
        'shortUri': 'package:test/test.dart',
        'uri': testFile.uri.toString(),
      };

      final asset = FileAsset.fromJson(json);
      expect(asset.id, equals('test_id'));
      expect(asset.shortUri.toString(), equals('package:test/test.dart'));
      expect(asset.uri, equals(testFile.uri));
    });

    test('should extract package name from package URI', () {
      final asset = FileAsset(
        id: 'test_id',
        shortUri: Uri.parse('package:my_package/test.dart'),
        file: testFile,
      );

      expect(asset.packageName, equals('my_package'));
    });

    test('should extract package name from asset URI', () {
      final asset = FileAsset(
        id: 'test_id',
        shortUri: Uri.parse('asset:my_package/test.dart'),
        file: testFile,
      );

      expect(asset.packageName, equals('my_package'));
    });

    test('should extract package name from dart URI', () {
      final asset = FileAsset(
        id: 'test_id',
        shortUri: Uri.parse('dart:core/string.dart'),
        file: testFile,
      );

      expect(asset.packageName, equals('dart'));
    });

    test('should return null for unknown URI scheme', () {
      final asset = FileAsset(
        id: 'test_id',
        shortUri: Uri.parse('file:///test.dart'),
        file: testFile,
      );

      expect(asset.packageName, isNull);
    });

    test('should create URI with different extension', () {
      final asset = FileAsset(
        id: 'test_id',
        shortUri: Uri.parse('package:test/test.dart'),
        file: testFile,
      );

      final newUri = asset.uriWithExtension('.g.dart');
      expect(newUri.path, endsWith('.g.dart'));
      expect(newUri.path, isNot(endsWith('.dart.g.dart')));
    });

    test('should safely delete existing file', () {
      final asset = FileAsset(
        id: 'test_id',
        shortUri: Uri.parse('package:test/test.dart'),
        file: testFile,
      );

      expect(testFile.existsSync(), isTrue);
      asset.safeDelete();
      expect(testFile.existsSync(), isFalse);
    });

    test('should safely handle deleting non-existent file', () {
      final nonExistentFile = File('${tempDir.path}/non_existent.dart');
      final asset = FileAsset(
        id: 'test_id',
        shortUri: Uri.parse('package:test/test.dart'),
        file: nonExistentFile,
      );

      // Should not throw
      expect(() => asset.safeDelete(), returnsNormally);
    });

    test('should have correct toString', () {
      final asset = FileAsset(
        id: 'test_id',
        shortUri: Uri.parse('package:test/test.dart'),
        file: testFile,
      );

      final str = asset.toString();
      expect(str, contains('FileAsset'));
      expect(str, contains('test_id'));
      expect(str, contains('package:test/test.dart'));
    });

    test('should implement equality correctly', () {
      final asset1 = FileAsset(
        id: 'test_id',
        shortUri: Uri.parse('package:test/test.dart'),
        file: testFile,
      );

      final asset2 = FileAsset(
        id: 'test_id',
        shortUri: Uri.parse('package:test/test.dart'),
        file: testFile,
      );

      expect(asset1, equals(asset2));
      expect(asset1.hashCode, equals(asset2.hashCode));
    });

    test('should not be equal with different id', () {
      final asset1 = FileAsset(
        id: 'test_id_1',
        shortUri: Uri.parse('package:test/test.dart'),
        file: testFile,
      );

      final asset2 = FileAsset(
        id: 'test_id_2',
        shortUri: Uri.parse('package:test/test.dart'),
        file: testFile,
      );

      expect(asset1, isNot(equals(asset2)));
    });

    test('should not be equal with different shortUri', () {
      final asset1 = FileAsset(
        id: 'test_id',
        shortUri: Uri.parse('package:test/test1.dart'),
        file: testFile,
      );

      final asset2 = FileAsset(
        id: 'test_id',
        shortUri: Uri.parse('package:test/test2.dart'),
        file: testFile,
      );

      expect(asset1, isNot(equals(asset2)));
    });

    test('should not be equal with different file', () {
      final file2 = File('${tempDir.path}/test2.dart');
      file2.writeAsStringSync('test content 2');

      final asset1 = FileAsset(
        id: 'test_id',
        shortUri: Uri.parse('package:test/test.dart'),
        file: testFile,
      );

      final asset2 = FileAsset(
        id: 'test_id',
        shortUri: Uri.parse('package:test/test.dart'),
        file: file2,
      );

      expect(asset1, isNot(equals(asset2)));
    });
  });
}
