import 'package:lean_builder/src/graph/references_scanner.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/test/scanner.dart';
import 'package:lean_builder/src/type/substitution.dart';
import 'package:lean_builder/src/type/type.dart';
import 'package:lean_builder/test.dart';
import 'package:test/test.dart';

void main() {
  late ResolverImpl resolver;

  setUp(() {
    final fileResolver = getTestFileResolver();
    final assetsGraph = AssetsGraph('hash');
    final scanner = ReferencesScanner(assetsGraph, fileResolver);
    scanDartSdkAndPackages(scanner);
    resolver = ResolverImpl(assetsGraph, fileResolver, SourceParser());
  });

  group('Substitution.substituteType', () {
    test('substitutes interface type arguments', () {
      final listType = (resolver.getNamedType('List', 'dart:core') as InterfaceType).element.thisType;
      // List<T> -> List<int>
      final t = listType.typeArguments.first as TypeParameterType;
      final intType = resolver.getNamedType('int', 'dart:core');

      final substitution = Substitution.fromPairs([t], [intType]);
      final substituted = substitution.substituteType(listType) as InterfaceType;

      expect(substituted.name, 'List');
      expect(substituted.typeArguments.first, intType);
    });

    test('substitutes function return type', () {
      final intType = resolver.getNamedType('int', 'dart:core');

      final t = TypeParameterType('T', bound: DartType.dynamicType);

      final f = FunctionType(
        isNullable: false,
        parameters: [],
        returnType: t,
        typeParameters: [t],
      );

      final substitution = Substitution.fromPairs([t], [intType]);
      final substituted = substitution.substituteType(f) as FunctionType;

      expect(substituted.returnType, intType);
    });

    test('substitutes record types', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      final t = TypeParameterType('T', bound: DartType.dynamicType);

      final record = RecordType(
        positionalFields: [RecordTypePositionalField(t)],
        namedFields: [RecordTypeNamedField('val', t)],
        isNullable: false,
      );

      final substitution = Substitution.fromPairs([t], [intType]);
      final substituted = substitution.substituteType(record) as RecordType;

      expect(substituted.positionalFields.first.type, intType);
      expect(substituted.namedFields.first.type, intType);
      expect(substituted.namedFields.first.name, 'val');
    });
  });
}
