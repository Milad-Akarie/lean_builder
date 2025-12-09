import 'package:lean_builder/builder.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/graph/references_scanner.dart';
import 'package:lean_builder/src/resolvers/source_parser.dart';
import 'package:test/test.dart';
import 'package:lean_builder/src/type/type_checker.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/graph/declaration_ref.dart';
import 'package:lean_builder/src/graph/scan_results.dart';

import 'scanner/string_asset_src.dart';
import 'utils/test_utils.dart';

DeclarationRef refFor(String name, String uri, ReferenceType type) {
  return DeclarationRef.from(name, uri, type);
}

final _typesAsset = StringAsset(
  '''
  class A{}
  class B{}
  class C extends A {}
  class D extends C {}
''',
  uriString: 'package:test/test.dart',
);

class A {}

void main() {
  late ResolverImpl resolver;
  setUp(() {
    final PackageFileResolver fileResolver = PackageFileResolver.forRoot();
    final assetsGraph = AssetsGraph(fileResolver.packagesHash);
    final scanner = ReferencesScanner(assetsGraph, fileResolver);
    scanDartSdk(scanner);
    scanner.registerAndScan(_typesAsset);
    resolver = ResolverImpl(assetsGraph, fileResolver, SourceParser());
  });

  group('TypeChecker.isExactlyType', () {
    test('fromUrl throws on invalid format', () {
      final checker = TypeChecker.fromUrl('invalid_url');
      final aType = resolver.getNamedType('A', _typesAsset.uri.toString());
      expect(() => checker.isExactlyType(aType), throwsArgumentError);
    });

    test('fromUrl matches type from valid url', () {
      final aType = resolver.getNamedType('A', _typesAsset.uri.toString());
      final checker = TypeChecker.fromUrl('package:test/test.dart#A');
      expect(checker.isExactlyType(aType), isTrue);
    });

    test('fromUrl returns false for different type', () {
      final bType = resolver.getNamedType('B', _typesAsset.uri.toString());
      final checker = TypeChecker.fromUrl('package:test/test.dart#A');
      expect(checker.isExactlyType(bType), isFalse);
    });

    test('typeNameLiterally matches type name', () {
      final dummyType = resolver.getNamedType('A', _typesAsset.uri.toString());
      final checker = const TypeChecker.typeNameLiterally('A', inPackage: 'test');
      expect(checker.isExactlyType(dummyType), isTrue);
    });

    test('typeNameLiterally matches core type name', () {
      final stringType = resolver.getNamedType('String', 'dart:core');
      final checker = TypeChecker.typeNamed(String, inSdk: true);
      expect(checker.isExactlyType(stringType), isTrue);
    });

    test('typeNameLiterally returns false for different type', () {
      final bType = resolver.getNamedType('B', _typesAsset.uri.toString());
      final checker = TypeChecker.typeNameLiterally('A', inPackage: 'test');
      expect(checker.isExactlyType(bType), isFalse);
    });

    test('typeNamed matches runtime type', () {
      final dummyType = resolver.getNamedType('A', _typesAsset.uri.toString());
      final checker = TypeChecker.typeNamed(A, inPackage: 'test');
      expect(checker.isExactlyType(dummyType), isTrue);
    });

    test('typeNamed returns false for different type', () {
      final bType = resolver.getNamedType('B', _typesAsset.uri.toString());
      final checker = TypeChecker.typeNamed(A, inPackage: 'test');
      expect(checker.isExactlyType(bType), isFalse);
    });

    test('any delegates to multiple checkers', () {
      final checker1 = TypeChecker.typeNameLiterally('A', inPackage: 'test');
      final checker2 = TypeChecker.typeNameLiterally('B', inPackage: 'test');
      final anyChecker = TypeChecker.any([checker1, checker2]);
      final fakeTypeA = resolver.getNamedType('A', _typesAsset.uri.toString());
      final fakeTypeB = resolver.getNamedType('B', _typesAsset.uri.toString());
      final dummyType = resolver.getNamedType('C', _typesAsset.uri.toString());
      expect(anyChecker.isExactlyType(fakeTypeA), isTrue);
      expect(anyChecker.isExactlyType(fakeTypeB), isTrue);
      expect(anyChecker.isExactlyType(dummyType), isFalse);
    });
  });

  group('TypeChecker.isAssignableFromType', () {
    test('returns true for the same type', () {
      final typeA = resolver.getNamedType('A', _typesAsset.uri.toString());
      final checker = TypeChecker.fromUrl('${_typesAsset.uri}#A');
      expect(checker.isAssignableFromType(typeA), isTrue);
    });

    test('returns true for subtype', () {
      final typeC = resolver.getNamedType('C', _typesAsset.uri.toString());
      final checker = TypeChecker.fromUrl('${_typesAsset.uri}#A');
      expect(checker.isAssignableFromType(typeC), isTrue);
    });

    test('returns false for unrelated type', () {
      final typeB = resolver.getNamedType('B', _typesAsset.uri.toString());
      final checker = TypeChecker.fromUrl('${_typesAsset.uri}#A');
      expect(checker.isAssignableFromType(typeB), isFalse);
    });

    test('returns true for deeper subtype', () {
      final typeD = resolver.getNamedType('D', _typesAsset.uri.toString());
      final checker = TypeChecker.fromUrl('${_typesAsset.uri}#A');
      expect(checker.isAssignableFromType(typeD), isTrue);
    });
  });
}
