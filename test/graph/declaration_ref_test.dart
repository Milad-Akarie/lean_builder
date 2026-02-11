import 'package:lean_builder/src/graph/declaration_ref.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/test.dart';
import 'package:test/test.dart';

void main() {
  group('DeclarationRef', () {
    test('should create declaration ref with all properties', () {
      final asset = StringAsset('class Foo {}');
      final ref = DeclarationRef(
        identifier: 'Foo',
        srcId: 'test-id',
        providerId: 'provider-id',
        type: ReferenceType.$class,
        srcUri: Uri.parse('package:test/test.dart'),
        importingLibrary: asset,
        importPrefix: 'prefix',
      );

      expect(ref.identifier, 'Foo');
      expect(ref.srcId, 'test-id');
      expect(ref.providerId, 'provider-id');
      expect(ref.type, ReferenceType.$class);
      expect(ref.srcUri.toString(), 'package:test/test.dart');
      expect(ref.importingLibrary, asset);
      expect(ref.importPrefix, 'prefix');
    });

    test('should create declaration ref without optional properties', () {
      final ref = DeclarationRef(
        identifier: 'bar',
        srcId: 'test-id',
        providerId: 'provider-id',
        type: ReferenceType.$function,
        srcUri: Uri.parse('package:test/test.dart'),
      );

      expect(ref.identifier, 'bar');
      expect(ref.importingLibrary, isNull);
      expect(ref.importPrefix, isNull);
    });

    test('should create declaration ref from factory method', () {
      final ref = DeclarationRef.from(
        'MyClass',
        'package:test/lib.dart',
        ReferenceType.$class,
      );

      expect(ref.identifier, 'MyClass');
      expect(ref.srcId, isNotEmpty);
      expect(ref.providerId, 'package:test/lib.dart');
      expect(ref.type, ReferenceType.$class);
      expect(ref.srcUri.toString(), 'package:test/lib.dart');
      expect(ref.importingLibrary, isNull);
      expect(ref.importPrefix, isNull);
    });

    test('should generate consistent srcId for same URI', () {
      final ref1 = DeclarationRef.from(
        'Foo',
        'package:test/lib.dart',
        ReferenceType.$class,
      );
      final ref2 = DeclarationRef.from(
        'Bar',
        'package:test/lib.dart',
        ReferenceType.$function,
      );

      expect(ref1.srcId, ref2.srcId);
    });

    test('should generate different srcId for different URIs', () {
      final ref1 = DeclarationRef.from(
        'Foo',
        'package:test/lib1.dart',
        ReferenceType.$class,
      );
      final ref2 = DeclarationRef.from(
        'Foo',
        'package:test/lib2.dart',
        ReferenceType.$class,
      );

      expect(ref1.srcId, isNot(ref2.srcId));
    });

    test('should have proper toString representation', () {
      final ref = DeclarationRef(
        identifier: 'Foo',
        srcId: 'test-id',
        providerId: 'provider-id',
        type: ReferenceType.$class,
        srcUri: Uri.parse('package:test/test.dart'),
      );

      final str = ref.toString();
      expect(str, contains('Foo'));
      expect(str, contains('test-id'));
      expect(str, contains('provider-id'));
    });

    test('should be equal when all properties match', () {
      final ref1 = DeclarationRef(
        identifier: 'Foo',
        srcId: 'test-id',
        providerId: 'provider-id',
        type: ReferenceType.$class,
        srcUri: Uri.parse('package:test/test.dart'),
      );
      final ref2 = DeclarationRef(
        identifier: 'Foo',
        srcId: 'test-id',
        providerId: 'provider-id',
        type: ReferenceType.$class,
        srcUri: Uri.parse('package:test/test.dart'),
      );

      expect(ref1, equals(ref2));
      expect(ref1.hashCode, equals(ref2.hashCode));
    });

    test('should not be equal when identifier differs', () {
      final ref1 = DeclarationRef(
        identifier: 'Foo',
        srcId: 'test-id',
        providerId: 'provider-id',
        type: ReferenceType.$class,
        srcUri: Uri.parse('package:test/test.dart'),
      );
      final ref2 = DeclarationRef(
        identifier: 'Bar',
        srcId: 'test-id',
        providerId: 'provider-id',
        type: ReferenceType.$class,
        srcUri: Uri.parse('package:test/test.dart'),
      );

      expect(ref1, isNot(equals(ref2)));
    });

    test('should not be equal when srcId differs', () {
      final ref1 = DeclarationRef(
        identifier: 'Foo',
        srcId: 'test-id-1',
        providerId: 'provider-id',
        type: ReferenceType.$class,
        srcUri: Uri.parse('package:test/test.dart'),
      );
      final ref2 = DeclarationRef(
        identifier: 'Foo',
        srcId: 'test-id-2',
        providerId: 'provider-id',
        type: ReferenceType.$class,
        srcUri: Uri.parse('package:test/test.dart'),
      );

      expect(ref1, isNot(equals(ref2)));
    });

    test('should not be equal when providerId differs', () {
      final ref1 = DeclarationRef(
        identifier: 'Foo',
        srcId: 'test-id',
        providerId: 'provider-id-1',
        type: ReferenceType.$class,
        srcUri: Uri.parse('package:test/test.dart'),
      );
      final ref2 = DeclarationRef(
        identifier: 'Foo',
        srcId: 'test-id',
        providerId: 'provider-id-2',
        type: ReferenceType.$class,
        srcUri: Uri.parse('package:test/test.dart'),
      );

      expect(ref1, isNot(equals(ref2)));
    });

    test('should not be equal when type differs', () {
      final ref1 = DeclarationRef(
        identifier: 'Foo',
        srcId: 'test-id',
        providerId: 'provider-id',
        type: ReferenceType.$class,
        srcUri: Uri.parse('package:test/test.dart'),
      );
      final ref2 = DeclarationRef(
        identifier: 'Foo',
        srcId: 'test-id',
        providerId: 'provider-id',
        type: ReferenceType.$function,
        srcUri: Uri.parse('package:test/test.dart'),
      );

      expect(ref1, isNot(equals(ref2)));
    });

    test('should not be equal when srcUri differs', () {
      final ref1 = DeclarationRef(
        identifier: 'Foo',
        srcId: 'test-id',
        providerId: 'provider-id',
        type: ReferenceType.$class,
        srcUri: Uri.parse('package:test/test1.dart'),
      );
      final ref2 = DeclarationRef(
        identifier: 'Foo',
        srcId: 'test-id',
        providerId: 'provider-id',
        type: ReferenceType.$class,
        srcUri: Uri.parse('package:test/test2.dart'),
      );

      expect(ref1, isNot(equals(ref2)));
    });

    test('should not be equal when importPrefix differs', () {
      final ref1 = DeclarationRef(
        identifier: 'Foo',
        srcId: 'test-id',
        providerId: 'provider-id',
        type: ReferenceType.$class,
        srcUri: Uri.parse('package:test/test.dart'),
        importPrefix: 'prefix1',
      );
      final ref2 = DeclarationRef(
        identifier: 'Foo',
        srcId: 'test-id',
        providerId: 'provider-id',
        type: ReferenceType.$class,
        srcUri: Uri.parse('package:test/test.dart'),
        importPrefix: 'prefix2',
      );

      expect(ref1, isNot(equals(ref2)));
    });

    test('should be equal to itself', () {
      final ref = DeclarationRef(
        identifier: 'Foo',
        srcId: 'test-id',
        providerId: 'provider-id',
        type: ReferenceType.$class,
        srcUri: Uri.parse('package:test/test.dart'),
      );

      expect(ref, equals(ref));
    });

    test('should work with different reference types', () {
      final types = [
        ReferenceType.$class,
        ReferenceType.$function,
        ReferenceType.$variable,
        ReferenceType.$typeAlias,
        ReferenceType.$enum,
        ReferenceType.$mixin,
        ReferenceType.$extension,
      ];

      for (final type in types) {
        final ref = DeclarationRef.from(
          'identifier',
          'package:test/lib.dart',
          type,
        );
        expect(ref.type, type);
      }
    });

    test('should handle complex URIs', () {
      final ref = DeclarationRef.from(
        'Foo',
        'package:my_package/src/internal/deep/nested/file.dart',
        ReferenceType.$class,
      );

      expect(ref.srcUri.toString(), 'package:my_package/src/internal/deep/nested/file.dart');
      expect(ref.srcId, isNotEmpty);
    });

    test('should handle dart: URIs', () {
      final ref = DeclarationRef.from(
        'List',
        'dart:core',
        ReferenceType.$class,
      );

      expect(ref.srcUri.toString(), 'dart:core');
      expect(ref.srcUri.scheme, 'dart');
    });
  });
}
