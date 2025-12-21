import 'dart:typed_data';

import 'package:lean_builder/src/graph/directive_statement.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/test.dart';
import 'package:test/test.dart';

void main() {
  group('AssetsGraph', () {
    late AssetsGraph graph;

    setUp(() {
      graph = AssetsGraph('test_hash');
    });

    test('initial state is empty', () {
      expect(graph.assets, isEmpty);
      expect(graph.identifiers, isEmpty);
    });

    test('clearAll clears the graph', () {
      graph.assets['a'] = ['a', 'hash', 0];
      graph.clearAll();
      expect(graph.assets, isEmpty);
    });

    test('invalidateDigest nulls the digest', () {
      final src = StringAsset('class A {}', fileName: 'a.dart');
      graph.addAsset(src);
      graph.updateAssetInfo(src, content: Uint8List.fromList('class A {}'.codeUnits));

      expect(graph.assets[src.id]![GraphIndex.assetDigest], isNotNull);

      graph.invalidateDigest(src.id);

      expect(graph.assets[src.id]![GraphIndex.assetDigest], isNull);
    });

    test('identifiersForAsset returns identifiers for specific asset', () {
      graph.identifiers.add(['A', 'src1', ReferenceType.$class.value]);
      graph.identifiers.add(['B', 'src1', ReferenceType.$class.value]);
      graph.identifiers.add(['C', 'src2', ReferenceType.$class.value]);

      final ids = graph.identifiersForAsset('src1');
      expect(ids, hasLength(2));
      expect(ids.map((e) => e[0]), containsAll(['A', 'B']));
    });

    test('dependentsOf includes imports and parts of', () {
      // Setup: B imports A, C is a part of A
      final assetA = StringAsset('', fileName: 'a.dart');
      final assetB = StringAsset('', fileName: 'b.dart');
      final assetC = StringAsset('', fileName: 'c.dart');

      graph.addAsset(assetA);
      graph.addAsset(assetB);
      graph.addAsset(assetC);

      graph.addDirective(
        assetB,
        DirectiveStatement(
          type: DirectiveStatement.import,
          asset: assetA,
          stringUri: 'package:e/e.dart',
        ),
      );
      graph.addDirective(
        assetA,
        DirectiveStatement(
          type: DirectiveStatement.partOf,
          asset: assetC,
          stringUri: 'package:e/c.dart',
        ),
      );

      final dependents = graph.dependentsOf(assetA.id);
      expect(dependents.containsKey(assetB.id), isTrue);
      expect(dependents.containsKey(assetC.id), isTrue);
    });

    test('toJson produces valid JSON map', () {
      graph.assets['A'] = ['package:a.dart', 'h1', 1, 0];
      final json = graph.toJson();
      expect(json['assets'], contains('A'));
      expect(json['hash'], 'test_hash');
    });
  });

  group('AssetsGraph Identifier Resolution', () {
    late AssetsGraph graph;
    late StringAsset libA;
    late StringAsset libB;
    late StringAsset libC;

    setUp(() {
      graph = AssetsGraph('hash');

      // libA declares A
      libA = StringAsset('class A {}', fileName: 'a.dart');
      graph.addAsset(libA);
      graph.identifiers.add(['A', libA.id, ReferenceType.$class.value]);

      // libB exports libA
      libB = StringAsset("export 'a.dart';", fileName: 'b.dart');
      graph.addAsset(libB);
      graph.addDirective(
        libB,
        DirectiveStatement(
          type: DirectiveStatement.export,
          asset: libA,
          stringUri: 'a.dart',
        ),
      );

      // libC imports libB
      libC = StringAsset("import 'b.dart';", fileName: 'c.dart');
      graph.addAsset(libC);
      graph.addDirective(
        libC,
        DirectiveStatement(
          type: DirectiveStatement.import,
          asset: libB,
          stringUri: 'b.dart',
        ),
      );
    });

    test('getDeclarationRef resolves identifier via exports', () {
      final ref = graph.getDeclarationRef('A', libC);
      expect(ref, isNotNull);
      expect(ref!.identifier, 'A');
      expect(ref.srcId, libA.id);
      expect(ref.type, ReferenceType.$class);
    });

    test('getDeclarationRef handles show/hide', () {
      // libD imports libA showing only A
      final libD = StringAsset("import 'a.dart' show A;", fileName: 'd.dart');
      graph.addAsset(libD);
      graph.addDirective(
        libD,
        DirectiveStatement(
          type: DirectiveStatement.import,
          asset: libA,
          stringUri: 'a.dart',
          show: ['A'],
        ),
      );

      expect(graph.getDeclarationRef('A', libD)!.identifier, 'A');
      expect(graph.getDeclarationRef('B', libD), isNull);

      // libE imports libA hiding A
      final libE = StringAsset("import 'a.dart' hide A;", fileName: 'e.dart');
      graph.addAsset(libE);
      graph.addDirective(
        libE,
        DirectiveStatement(
          type: DirectiveStatement.import,
          asset: libA,
          stringUri: 'a.dart',
          hide: ['A'],
        ),
      );
      expect(graph.getDeclarationRef('A', libE), isNull);
    });

    test('lookupIdentifierByProvider finds identifier in provider', () {
      final found = graph.lookupIdentifierByProvider('A', libA.id);
      expect(found, isNotNull);
      expect(found!.identifier, 'A');

      final notFound = graph.lookupIdentifierByProvider('B', libA.id);
      expect(notFound, isNull);
    });

    test('getExposedIdentifiersInside returns identifiers from direct imports', () {
      // libF directly imports libA
      final libF = StringAsset("import 'a.dart';", fileName: 'f.dart');
      graph.addAsset(libF);
      graph.addDirective(
        libF,
        DirectiveStatement(
          type: DirectiveStatement.import,
          asset: libA,
          stringUri: 'a.dart',
        ),
      );

      final exposed = graph.getExposedIdentifiersInside(libF.id);
      expect(exposed, containsPair('A', libA.id));
    });
  });
}
