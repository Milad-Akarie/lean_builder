import 'package:lean_builder/src/graph/declaration_ref.dart';
import 'package:lean_builder/src/graph/references_scanner.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/test/scanner.dart';
import 'package:lean_builder/src/type/type.dart';
import 'package:lean_builder/src/type/type_checker.dart';
import 'package:lean_builder/test.dart';
import 'package:test/test.dart';

DeclarationRef refFor(String name, String uri, ReferenceType type) {
  return DeclarationRef.from(name, uri, type);
}

final _importedTypesAsset = StringAsset.withRawUri('''
class A{}
class B{}
''', 'package:test_/types.dart');

final _typesAsset = StringAsset.withRawUri(
  '''
  import 'package:test_/types.dart';
  class C extends A {}
  class D extends C {}
  class E implements B {}
  class M with A {}
''',
  'package:test_/test.dart',
);

class A {}

void main() {
  late ResolverImpl resolver;
  late ReferencesScanner scanner;
  setUp(() {
    final fileResolver = getTestFileResolver();
    final assetsGraph = AssetsGraph(fileResolver.packagesHash);
    scanner = ReferencesScanner(assetsGraph, fileResolver);
    scanDartSdkAndPackages(scanner);
    scanner.scan(_typesAsset);
    scanner.scan(_importedTypesAsset);
    resolver = ResolverImpl(assetsGraph, fileResolver, SourceParser());
    resolver.resolveLibrary(_importedTypesAsset);
    resolver.resolveLibrary(_typesAsset);
  });

  group('TypeChecker.isExactlyType', () {
    test('fromUrl throws on invalid format', () {
      final checker = TypeChecker.fromUrl('invalid_url');
      final aType = resolver.getNamedType('A', _importedTypesAsset.shortUri.toString());
      expect(() => checker.isExactlyType(aType), throwsArgumentError);
    });

    test('fromUrl matches type from valid url', () {
      final aType = resolver.getNamedType('A', _importedTypesAsset.shortUri.toString());
      final checker = TypeChecker.fromUrl('${_importedTypesAsset.shortUri}#A');
      expect(checker.isExactlyType(aType), isTrue);
    });

    test('fromUrl returns false for different type', () {
      final bType = resolver.getNamedType('B', _importedTypesAsset.shortUri.toString());
      final checker = TypeChecker.fromUrl('${_importedTypesAsset.shortUri}#A');
      expect(checker.isExactlyType(bType), isFalse);
    });

    test('typeNameLiterally matches type name', () {
      final dummyType = resolver.getNamedType('A', _importedTypesAsset.shortUri.toString());
      print(dummyType);
      final checker = const TypeChecker.typeNameLiterally('A', inPackage: 'test_');
      expect(checker.isExactlyType(dummyType), isTrue);
    });

    test('typeNameLiterally matches core type name', () {
      final stringType = resolver.getNamedType('String', 'dart:core');
      final checker = TypeChecker.typeNamed(String, inSdk: true);
      expect(checker.isExactlyType(stringType), isTrue);
    });

    test('typeNameLiterally returns false for different type', () {
      final bType = resolver.getNamedType('B', _importedTypesAsset.shortUri.toString());
      final checker = TypeChecker.typeNameLiterally('A', inPackage: 'test_');
      expect(checker.isExactlyType(bType), isFalse);
    });

    test('typeNamed matches runtime type', () {
      final dummyType = resolver.getNamedType('A', _importedTypesAsset.shortUri.toString());
      final checker = TypeChecker.typeNamed(A, inPackage: 'test_');
      expect(checker.isExactlyType(dummyType), isTrue);
    });

    test('typeNamed returns false for different type', () {
      final bType = resolver.getNamedType('B', _importedTypesAsset.shortUri.toString());
      final checker = TypeChecker.typeNamed(A, inPackage: 'test_');
      expect(checker.isExactlyType(bType), isFalse);
    });

    test('any delegates to multiple checkers', () {
      final checker1 = TypeChecker.typeNameLiterally('A', inPackage: 'test_');
      final checker2 = TypeChecker.typeNameLiterally('B', inPackage: 'test_');
      final anyChecker = TypeChecker.any([checker1, checker2]);
      final fakeTypeA = resolver.getNamedType('A', _importedTypesAsset.shortUri.toString());
      final fakeTypeB = resolver.getNamedType('B', _importedTypesAsset.shortUri.toString());
      final dummyType = resolver.getNamedType('C', _typesAsset.shortUri.toString());
      expect(anyChecker.isExactlyType(fakeTypeA), isTrue);
      expect(anyChecker.isExactlyType(fakeTypeB), isTrue);
      expect(anyChecker.isExactlyType(dummyType), isFalse);
    });
  });

  group('TypeChecker.isAssignableFromType', () {
    test('returns true for the same type', () {
      final typeA = resolver.getNamedType('A', _importedTypesAsset.shortUri.toString());
      final checker = TypeChecker.fromUrl('${_importedTypesAsset.shortUri}#A');
      expect(checker.isAssignableFromType(typeA), isTrue);
    });

    test('returns true for subtype', () {
      final typeC = resolver.getNamedType('C', _typesAsset.shortUri.toString());
      final checker = TypeChecker.typeNameLiterally('A', inPackage: 'test_');
      expect(checker.isAssignableFromType(typeC), isTrue);
    });

    test('returns false for unrelated type', () {
      final typeB = resolver.getNamedType('B', _importedTypesAsset.shortUri.toString());
      final checker = TypeChecker.fromUrl('${_importedTypesAsset.shortUri}#A');
      expect(checker.isAssignableFromType(typeB), isFalse);
    });

    test('returns true for deeper subtype', () {
      final typeD = resolver.getNamedType('D', _typesAsset.shortUri.toString());
      final checker = TypeChecker.fromUrl('${_importedTypesAsset.shortUri}#A');
      expect(checker.isAssignableFromType(typeD), isTrue);
    });
  });

  group('TypeChecker.isSupertypeOf', () {
    test('returns true for superclass', () {
      final typeC = resolver.getNamedType('C', _typesAsset.shortUri.toString());
      final checkerA = TypeChecker.typeNameLiterally('A', inPackage: 'test_');
      expect(checkerA.isSupertypeOf(typeC), isTrue);
    });

    test('returns false for interface (not superclass)', () {
      final typeE = resolver.getNamedType('E', _typesAsset.shortUri.toString());
      final checkerB = TypeChecker.typeNameLiterally('B', inPackage: 'test_');
      expect(checkerB.isSupertypeOf(typeE), isFalse);
    });

    test('returns false for mixin (not superclass)', () {
      final typeM = resolver.getNamedType('M', _typesAsset.shortUri.toString());
      final checkerA = TypeChecker.typeNameLiterally('A', inPackage: 'test_');
      expect(checkerA.isSupertypeOf(typeM), isFalse);
    });
  });

  group('TypeChecker annotations', () {
    test('hasAnnotationOf returns true if annotation exists', () {
      final annotatedAsset = StringAsset.withRawUri('''
        import 'package:test_/types.dart';
        @A()
        class Annotated {}
      ''', 'package:test_/annotated.dart');

      scanner.scan(_importedTypesAsset);
      scanner.scan(annotatedAsset);

      resolver.resolveLibrary(_importedTypesAsset);
      resolver.resolveLibrary(annotatedAsset);

      final annotatedClass = resolver.getNamedType('Annotated', 'package:test_/annotated.dart').element;
      final checkerA = TypeChecker.typeNameLiterally('A', inPackage: 'test_');

      expect(checkerA.hasAnnotationOf(annotatedClass!), isTrue);
      expect(checkerA.firstAnnotationOf(annotatedClass), isNotNull);
    });
  });

  group('TypeChecker.matchingTypeOrSupertype', () {
    test('returns the matched type', () {
      final typeC = resolver.getNamedType('C', _typesAsset.shortUri.toString());
      final checkerA = TypeChecker.typeNameLiterally('A', inPackage: 'test_');
      final matched = checkerA.matchingTypeOrSupertype(typeC);
      expect(matched, isNotNull);
      expect(matched!.name, 'A');
    });
  });

  group('TypeChecker - FutureOr', () {
    test('isExactlyType matches FutureOr', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      final futureOrInt = InterfaceTypeImpl(
        'FutureOr',
        (resolver.getNamedType('FutureOr', 'dart:async') as InterfaceType).declarationRef,
        resolver,
        typeArguments: [intType],
      );
      final checkerFutureOr = TypeChecker.typeNameLiterally('FutureOr', inSdk: true);
      expect(checkerFutureOr.isExactlyType(futureOrInt), isTrue);
    });
  });
}
