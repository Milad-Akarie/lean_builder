import 'package:lean_builder/src/graph/references_scanner.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/test/scanner.dart';
import 'package:lean_builder/src/type/type.dart';
import 'package:lean_builder/src/type/type_utils.dart';
import 'package:lean_builder/test.dart';
import 'package:test/test.dart';

void main() {
  late ResolverImpl resolver;
  late TypeUtils typeUtils;

  setUp(() {
    final fileResolver = getTestFileResolver();
    final assetsGraph = AssetsGraph('hash');
    final scanner = ReferencesScanner(assetsGraph, fileResolver);
    scanDartSdkAndPackages(scanner);
    resolver = ResolverImpl(assetsGraph, fileResolver, SourceParser());
    typeUtils = resolver.typeUtils;
  });

  group('TypeUtils.isNullable', () {
    test('dynamic is nullable', () {
      expect(typeUtils.isNullable(DartType.dynamicType), isTrue);
    });

    test('void is nullable', () {
      expect(typeUtils.isNullable(DartType.voidType), isTrue);
    });

    test('Null is nullable', () {
      final nullType = typeUtils.nullTypeObject;
      expect(typeUtils.isNullable(nullType), isTrue);
    });

    test('Object? is nullable', () {
      expect(typeUtils.isNullable(typeUtils.objectTypeNullable), isTrue);
    });

    test('Object is not nullable', () {
      expect(typeUtils.isNullable(typeUtils.objectType), isFalse);
    });

    test('FutureOr<int?> is nullable', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      final nullableInt = (intType as InterfaceType).withNullability(true);
      final futureOrType = InterfaceTypeImpl(
        'FutureOr',
        (resolver.getNamedType('FutureOr', 'dart:async') as InterfaceType).declarationRef,
        resolver,
        typeArguments: [nullableInt],
      );
      expect(typeUtils.isNullable(futureOrType), isTrue);
    });

    test('FutureOr<int> is not nullable', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      final futureOrType = InterfaceTypeImpl(
        'FutureOr',
        (resolver.getNamedType('FutureOr', 'dart:async') as InterfaceType).declarationRef,
        resolver,
        typeArguments: [intType],
      );
      expect(typeUtils.isNullable(futureOrType), isFalse);
    });
  });

  group('TypeUtils.buildFutureType', () {
    test('builds non-nullable Future', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      final futureInt = typeUtils.buildFutureType(intType);
      expect(futureInt.name, 'Future');
      expect(futureInt.typeArguments.first, intType);
      expect(futureInt.isNullable, isFalse);
    });

    test('builds nullable Future', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      final futureInt = typeUtils.buildFutureType(intType, isNullable: true);
      expect(futureInt.isNullable, isTrue);
    });
  });

  group('TypeUtils.isEqualTo', () {
    test('int equals int', () {
      final int1 = resolver.getNamedType('int', 'dart:core');
      final int2 = resolver.getNamedType('int', 'dart:core');
      expect(typeUtils.isEqualTo(int1, int2), isTrue);
    });

    test('int does not equal String', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      final stringType = resolver.getNamedType('String', 'dart:core');
      expect(typeUtils.isEqualTo(intType, stringType), isFalse);
    });

    test('nullable int does not equal int', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      final nullableInt = (intType as InterfaceType).withNullability(true);
      expect(typeUtils.isEqualTo(intType, nullableInt), isFalse);
    });
  });

  group('TypeUtils.isAssignableTo', () {
    test('int is assignable to Object', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      final objectType = typeUtils.objectType;
      expect(typeUtils.isAssignableTo(intType, objectType), isTrue);
    });

    test('Object is assignable to int (implicit downcast)', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      final objectType = typeUtils.objectType;
      expect(typeUtils.isAssignableTo(objectType, intType), isTrue);
    });

    test('Object is NOT assignable to int with strictCasts', () {
      final strictTypeUtils = TypeUtils(resolver, strictCasts: true);
      final intType = resolver.getNamedType('int', 'dart:core');
      final objectType = strictTypeUtils.objectType;
      expect(strictTypeUtils.isAssignableTo(objectType, intType), isFalse);
    });
  });

  group('TypeUtils.acceptsFunctionType', () {
    test('Function accepts function type', () {
      final functionType = resolver.getNamedType('Function', 'dart:core');
      expect(typeUtils.acceptsFunctionType(functionType), isTrue);
    });

    test('FutureOr<Function> accepts function type', () {
      final functionType = resolver.getNamedType('Function', 'dart:core');
      final futureOrFunction = InterfaceTypeImpl(
        'FutureOr',
        (resolver.getNamedType('FutureOr', 'dart:async') as InterfaceType).declarationRef,
        resolver,
        typeArguments: [functionType],
      );
      expect(typeUtils.acceptsFunctionType(futureOrFunction), isTrue);
    });

    test('int does not accept function type', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      expect(typeUtils.acceptsFunctionType(intType), isFalse);
    });
  });
}
