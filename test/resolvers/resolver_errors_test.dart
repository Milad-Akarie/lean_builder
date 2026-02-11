import 'package:lean_builder/src/resolvers/errors.dart';
import 'package:test/test.dart';

void main() {
  group('IdentifierNotFoundError', () {
    test('should create error without import prefix', () {
      const identifier = 'MyClass';
      final importingLibrary = Uri.parse('package:my_package/lib.dart');
      final error = IdentifierNotFoundError(
        identifier,
        null,
        importingLibrary,
      );

      expect(error, isA<ResolverError>());
      expect(error.identifier, equals(identifier));
      expect(error.importPrefix, isNull);
      expect(error.importingLibrary, equals(importingLibrary));
      expect(error.toString(), contains(identifier));
      expect(error.toString(), contains(importingLibrary.toString()));
      expect(error.toString(), contains('Could not resolve'));
    });

    test('should create error with import prefix', () {
      const identifier = 'String';
      const importPrefix = 'dart';
      final importingLibrary = Uri.parse('package:my_package/lib.dart');
      final error = IdentifierNotFoundError(
        identifier,
        importPrefix,
        importingLibrary,
      );

      expect(error.identifier, equals(identifier));
      expect(error.importPrefix, equals(importPrefix));
      expect(error.importingLibrary, equals(importingLibrary));
      expect(error.toString(), contains('$importPrefix.$identifier'));
      expect(error.toString(), contains(importingLibrary.toString()));
    });

    test('should format error message correctly', () {
      final error = IdentifierNotFoundError(
        'UnknownClass',
        'mylib',
        Uri.parse('package:test/test.dart'),
      );

      final message = error.toString();
      expect(message, contains('Could not resolve'));
      expect(message, contains('mylib.UnknownClass'));
      expect(message, contains('package:test/test.dart'));
    });
  });
}
