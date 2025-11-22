import 'package:lean_builder/src/build_script/build_script.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('resolveImport', () {
    test('should return null for dart:core imports', () {
      final Uri dartCoreUri = Uri.parse('dart:core');
      final result = resolveImport(dartCoreUri);
      expect(result, isNull);
    });

    test('should return null for dart:core/something imports', () {
      final Uri dartCoreUri = Uri.parse('dart:core/lib.dart');
      final result = resolveImport(dartCoreUri);
      expect(result, isNull);
    });

    test('should return the URI string for other dart: imports', () {
      final Uri dartUri = Uri.parse('dart:async');
      final result = resolveImport(dartUri);
      expect(result, equals('dart:async'));
    });

    test('should return the URI string for dart:io imports', () {
      final Uri dartUri = Uri.parse('dart:io');
      final result = resolveImport(dartUri);
      expect(result, equals('dart:io'));
    });

    test('should return the URI string for package imports', () {
      final Uri packageUri = Uri.parse('package:lean_builder/builder.dart');
      final result = resolveImport(packageUri);
      expect(result, equals('package:lean_builder/builder.dart'));
    });

    test('should return the URI string for package imports from other packages', () {
      final Uri packageUri = Uri.parse('package:test/test.dart');
      final result = resolveImport(packageUri);
      expect(result, equals('package:test/test.dart'));
    });

    test('should convert asset URI to relative path', () {
      // Create an asset URI that would be in the lib directory
      final Uri assetUri = Uri.parse('asset:///lib/src/some_file.dart');
      final result = resolveImport(assetUri);

      // Result should be a relative path
      expect(result, isNotNull);
      expect(result, isNot(contains('asset:')));
      expect(result, isNot(contains('\\')));
    });

    test('should handle asset URI with uri parameter', () {
      final Uri shortUri = Uri.parse('asset:///lib/builder.dart');
      final Uri fullUri = Uri(
        scheme: 'file',
        path: p.join(p.current, 'lib', 'builder.dart'),
      );

      final result = resolveImport(shortUri, uri: fullUri);

      expect(result, isNotNull);
      expect(result, isNot(contains('asset:')));
      expect(result, isNot(contains('\\')));
    });

    test('should remove Windows drive letters from asset paths (C:) with backslashes', () {
      final Uri assetUri = Uri.parse('asset:///lib/file.dart');
      final Uri windowsUri = Uri(
        scheme: 'file',
        path: r'C:\Users\test\project\lib\file.dart',
      );
      final result = resolveImport(assetUri, uri: windowsUri);

      expect(result, isNotNull);
      expect(result, isNot(startsWith('C:')));
      expect(result, isNot(contains('\\')), reason: 'Should convert backslashes to forward slashes');
      expect(result, isNot(contains('C:\\')));
    });

    test('should remove Windows drive letters from asset paths (D:) with backslashes', () {
      final Uri assetUri = Uri.parse('asset://lib/src/file.dart');
      final Uri windowsUri = Uri(
        scheme: 'file',
        path: r'\D:\Projects\myapp\lib\src\file.dart',
      );
      final result = resolveImport(assetUri, uri: windowsUri);
      expect(result, isNotNull);
      expect(result, isNot(startsWith('D:')));
      expect(result, isNot(contains('D:')));
      expect(result, isNot(contains('\\')), reason: 'Should convert backslashes to forward slashes');
    });

    test('should remove Windows drive letters with backslash prefix (\\C:)', () {
      final Uri assetUri = Uri.parse('asset:///lib/file.dart');
      // Simulate a URI with Windows path with backslash prefix
      final Uri windowsUri = Uri(
        scheme: 'file',
        path: r'\C:\Users\test\project\lib\file.dart',
      );

      final result = resolveImport(assetUri, uri: windowsUri);

      expect(result, isNotNull);
      expect(result, isNot(contains('C:')));
      expect(result, isNot(contains('\\')));
    });

    test('should handle lowercase Windows drive letters', () {
      final Uri assetUri = Uri.parse('asset:///lib/file.dart');
      final Uri windowsUri = Uri(
        scheme: 'file',
        path: r'c:\users\test\project\lib\file.dart',
      );

      final result = resolveImport(assetUri, uri: windowsUri);

      expect(result, isNotNull);
      expect(result, isNot(contains('c:')));
      expect(result, isNot(contains('C:')));
      expect(result, isNot(contains('\\')));
    });

    test('should handle Windows paths with mixed separators', () {
      final Uri assetUri = Uri.parse('asset:///lib/file.dart');
      final Uri windowsUri = Uri(
        scheme: 'file',
        path: r'C:\Users\test/project\lib\file.dart',
      );

      final result = resolveImport(assetUri, uri: windowsUri);

      expect(result, isNotNull);
      expect(result, isNot(contains('C:')));
      expect(result, isNot(contains('\\')), reason: 'Should convert all backslashes to forward slashes');
    });

    test('should handle Windows UNC paths without drive letters', () {
      // UNC paths like \\server\share\path should not have drive letter removal
      final Uri assetUri = Uri.parse('asset:///lib/file.dart');
      final Uri uncUri = Uri(
        scheme: 'file',
        path: r'\\server\share\project\lib\file.dart',
      );

      final result = resolveImport(assetUri, uri: uncUri);

      expect(result, isNotNull);
      // Result should still have backslashes converted
      expect(result, isNot(contains('\\')));
    });

    test('should handle all uppercase drive letters (A-Z)', () {
      for (var letter in ['A', 'E', 'F', 'Z']) {
        final Uri assetUri = Uri.parse('asset:///lib/file.dart');
        final Uri windowsUri = Uri(
          scheme: 'file',
          path: '$letter:\\Users\\test\\project\\lib\\file.dart',
        );

        final result = resolveImport(assetUri, uri: windowsUri);

        expect(result, isNotNull);
        expect(result, isNot(contains('$letter:')));
        expect(result, isNot(contains('\\')));
      }
    });

    test('should handle deeply nested Windows paths with backslashes', () {
      final Uri assetUri = Uri.parse('asset:///lib/src/deeply/nested/file.dart');
      final Uri windowsUri = Uri(
        scheme: 'file',
        path: r'C:\Users\test\project\lib\src\deeply\nested\file.dart',
      );

      final result = resolveImport(assetUri, uri: windowsUri);

      expect(result, isNotNull);
      expect(result, isNot(contains('\\')), reason: 'All backslashes should be converted to forward slashes');
      expect(result, contains('/'), reason: 'Should contain forward slashes instead');
    });

    test('should handle Windows paths with spaces in directory names', () {
      final Uri assetUri = Uri.parse('asset:///lib/file.dart');
      final Uri windowsUri = Uri(
        scheme: 'file',
        path: r'C:\Users\My User\My Projects\project name\lib\file.dart',
      );

      final result = resolveImport(assetUri, uri: windowsUri);

      expect(result, isNotNull);
      expect(result, isNot(contains('C:')));
      expect(result, isNot(contains('\\')));
    });

    test('should handle Windows paths from Program Files', () {
      final Uri assetUri = Uri.parse('asset:///lib/file.dart');
      final Uri windowsUri = Uri(
        scheme: 'file',
        path: r'C:\Program Files\MyApp\lib\file.dart',
      );

      final result = resolveImport(assetUri, uri: windowsUri);

      expect(result, isNotNull);
      expect(result, isNot(contains('C:')));
      expect(result, isNot(contains('\\')));
    });

    test('should convert backslashes to forward slashes', () {
      final Uri assetUri = Uri.parse('asset:///lib/src/nested/file.dart');
      final result = resolveImport(assetUri);

      expect(result, isNotNull);
      // All path separators should be forward slashes for Dart imports
      expect(result, isNot(contains('\\')));
      if (result!.contains('/')) {
        expect(result.split('\\').length, equals(1), reason: 'Should not contain any backslashes');
      }
    });

    test('should handle nested asset paths', () {
      final Uri assetUri = Uri.parse('asset:///lib/src/deeply/nested/path/file.dart');
      final result = resolveImport(assetUri);

      expect(result, isNotNull);
      expect(result, isNot(contains('asset:')));
      expect(result, endsWith('file.dart'));
    });

    test('should handle asset URIs in the same directory as build script', () {
      final Uri assetUri = Uri.parse('asset:///.dart_tool/lean_build/script/some_file.dart');
      final result = resolveImport(assetUri);

      expect(result, isNotNull);
      expect(result, isNot(contains('asset:')));
    });

    test('should handle relative package imports', () {
      final Uri packageUri = Uri.parse('package:my_package/src/internal/file.dart');
      final result = resolveImport(packageUri);
      expect(result, equals('package:my_package/src/internal/file.dart'));
    });

    test('should preserve package URI structure', () {
      final Uri packageUri = Uri.parse('package:collection/collection.dart');
      final result = resolveImport(packageUri);
      expect(result, equals('package:collection/collection.dart'));
    });
  });
}
