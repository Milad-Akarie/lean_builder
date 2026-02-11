import 'package:lean_builder/src/asset/errors.dart';
import 'package:test/test.dart';

void main() {
  group('PackageConfigNotFound', () {
    test('should create error with proper message', () {
      final error = PackageConfigNotFound();
      expect(error, isA<PackageFileResolverError>());
      expect(
        error.toString(),
        contains('Could not find package_config.json file'),
      );
      expect(error.toString(), contains('flutter pub get'));
    });
  });

  group('PackageConfigParseError', () {
    test('should create error with source only', () {
      const source = '{ invalid json }';
      final error = PackageConfigParseError(source);
      expect(error, isA<PackageFileResolverError>());
      expect(error.source, equals(source));
      expect(error.cause, isNull);
      expect(error.toString(), contains('PackageConfigParseError'));
      expect(error.toString(), contains('Invalid package configuration format'));
    });

    test('should create error with source and cause', () {
      const source = '{ invalid json }';
      final cause = FormatException('Invalid JSON');
      final error = PackageConfigParseError(source, cause);
      expect(error.source, equals(source));
      expect(error.cause, equals(cause));
      expect(error.toString(), contains('cause:'));
      expect(error.toString(), contains('FormatException'));
    });
  });

  group('PackageNotFoundError', () {
    test('should create error with custom message', () {
      const message = 'Package "my_package" not found in configuration';
      final error = PackageNotFoundError(message);
      expect(error, isA<PackageFileResolverError>());
      expect(error.message, equals(message));
      expect(error.toString(), equals(message));
    });
  });

  group('AssetUriError', () {
    test('should create error with path only', () {
      const path = 'lib/invalid/path.dart';
      final error = AssetUriError(path);
      expect(error, isA<PackageFileResolverError>());
      expect(error.path, equals(path));
      expect(error.reason, isNull);
      expect(error.toString(), contains('AssetUriError'));
      expect(error.toString(), contains(path));
    });

    test('should create error with path and reason', () {
      const path = 'lib/invalid/path.dart';
      const reason = 'Invalid package format';
      final error = AssetUriError(path, reason);
      expect(error.path, equals(path));
      expect(error.reason, equals(reason));
      expect(error.toString(), contains(path));
      expect(error.toString(), contains('reason:'));
      expect(error.toString(), contains(reason));
    });
  });

  group('InvalidPathError', () {
    test('should create error with path', () {
      const path = '../../../invalid/path.dart';
      final error = InvalidPathError(path);
      expect(error, isA<PackageFileResolverError>());
      expect(error.path, equals(path));
      expect(error.toString(), contains('InvalidPathError'));
      expect(error.toString(), contains(path));
      expect(error.toString(), contains('is invalid'));
    });
  });
}
