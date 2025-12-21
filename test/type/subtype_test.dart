import 'package:lean_builder/element.dart';
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

  ParameterElement createParam(String name, DartType type) {
    return ParameterElementImpl(
      name: name,
      enclosingElement: resolver.libraryFor(StringAsset('')), // Dummy library
      hasImplicitType: false,
      isConst: false,
      isFinal: false,
      isLate: false,
      isCovariant: false,
      isInitializingFormal: false,
      isNamed: false,
      isOptional: false,
      isOptionalNamed: false,
      isOptionalPositional: false,
      isPositional: true,
      isRequired: true,
      isRequiredPositional: true,
      isRequiredNamed: false,
      isSuperFormal: false,
      type: type,
    );
  }

  group('SubtypeHelper.isSubtypeOf - Basic Types', () {
    test('int is subtype of num', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      final numType = resolver.getNamedType('num', 'dart:core');
      expect(typeUtils.isSubtypeOf(intType, numType), isTrue);
    });

    test('String is subtype of Object', () {
      final stringType = resolver.getNamedType('String', 'dart:core');
      final objectType = typeUtils.objectType;
      expect(typeUtils.isSubtypeOf(stringType, objectType), isTrue);
    });

    test('int is not subtype of String', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      final stringType = resolver.getNamedType('String', 'dart:core');
      expect(typeUtils.isSubtypeOf(intType, stringType), isFalse);
    });
  });

  group('SubtypeHelper.isSubtypeOf - Special Types', () {
    test('Any type is subtype of dynamic', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      expect(typeUtils.isSubtypeOf(intType, DartType.dynamicType), isTrue);
    });

    test('Any type is subtype of void', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      expect(typeUtils.isSubtypeOf(intType, DartType.voidType), isTrue);
    });

    test('Never is subtype of any type', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      expect(typeUtils.isSubtypeOf(DartType.neverType, intType), isTrue);
    });

    test('Null is subtype of any nullable type', () {
      final objectNullable = typeUtils.objectTypeNullable;
      final nullType = typeUtils.nullTypeObject;
      expect(typeUtils.isSubtypeOf(nullType, objectNullable), isTrue);
    });

    test('Null is NOT subtype of non-nullable type', () {
      final objectType = typeUtils.objectType;
      final nullType = typeUtils.nullTypeObject;
      expect(typeUtils.isSubtypeOf(nullType, objectType), isFalse);
    });
  });

  group('SubtypeHelper.isSubtypeOf - Nullability', () {
    test('T is subtype of T?', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      final nullableInt = (intType as InterfaceType).withNullability(true);
      expect(typeUtils.isSubtypeOf(intType, nullableInt), isTrue);
    });

    test('T? is NOT subtype of T', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      final nullableInt = (intType as InterfaceType).withNullability(true);
      expect(typeUtils.isSubtypeOf(nullableInt, intType), isFalse);
    });
  });

  group('SubtypeHelper.isSubtypeOf - Function Types', () {
    test('Function subtype with same parameters and return type', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      final f = FunctionType(
        isNullable: false,
        parameters: [],
        returnType: intType,
      );
      final g = FunctionType(
        isNullable: false,
        parameters: [],
        returnType: intType,
      );
      expect(typeUtils.isSubtypeOf(f, g), isTrue);
    });

    test('Return type is covariant', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      final numType = resolver.getNamedType('num', 'dart:core');
      final f = FunctionType(
        isNullable: false,
        parameters: [],
        returnType: intType,
      );
      final g = FunctionType(
        isNullable: false,
        parameters: [],
        returnType: numType,
      );
      expect(typeUtils.isSubtypeOf(f, g), isTrue);
    });

    test('Parameter type is contravariant', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      final numType = resolver.getNamedType('num', 'dart:core');

      final f = FunctionType(
        isNullable: false,
        parameters: [createParam('x', numType)],
        returnType: DartType.voidType,
      );
      final g = FunctionType(
        isNullable: false,
        parameters: [createParam('x', intType)],
        returnType: DartType.voidType,
      );

      expect(typeUtils.isSubtypeOf(f, g), isTrue);
    });
  });

  group('SubtypeHelper.isSubtypeOf - Generic Interface Types', () {
    test('List<int> is subtype of List<num>', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      final numType = resolver.getNamedType('num', 'dart:core');
      final listInt = InterfaceTypeImpl(
        'List',
        (resolver.getNamedType('List', 'dart:core') as InterfaceType).declarationRef,
        resolver,
        typeArguments: [intType],
      );
      final listNum = InterfaceTypeImpl(
        'List',
        (resolver.getNamedType('List', 'dart:core') as InterfaceType).declarationRef,
        resolver,
        typeArguments: [numType],
      );
      expect(typeUtils.isSubtypeOf(listInt, listNum), isTrue);
    });

    test('List<int> is subtype of Iterable<num>', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      final numType = resolver.getNamedType('num', 'dart:core');
      final listInt = InterfaceTypeImpl(
        'List',
        (resolver.getNamedType('List', 'dart:core') as InterfaceType).declarationRef,
        resolver,
        typeArguments: [intType],
      );
      final iterableNum = InterfaceTypeImpl(
        'Iterable',
        (resolver.getNamedType('Iterable', 'dart:core') as InterfaceType).declarationRef,
        resolver,
        typeArguments: [numType],
      );
      expect(typeUtils.isSubtypeOf(listInt, iterableNum), isTrue);
    });
  });

  group('SubtypeHelper.isSubtypeOf - Record Types', () {
    test('(int, String) is subtype of (num, Object)', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      final stringType = resolver.getNamedType('String', 'dart:core');
      final numType = resolver.getNamedType('num', 'dart:core');
      final objectType = typeUtils.objectType;

      final sub = RecordType(
        positionalFields: [RecordTypePositionalField(intType), RecordTypePositionalField(stringType)],
        namedFields: [],
        isNullable: false,
      );
      final sup = RecordType(
        positionalFields: [RecordTypePositionalField(numType), RecordTypePositionalField(objectType)],
        namedFields: [],
        isNullable: false,
      );
      expect(typeUtils.isSubtypeOf(sub, sup), isTrue);
    });

    test('({int a}) is subtype of ({num a})', () {
      final intType = resolver.getNamedType('int', 'dart:core');
      final numType = resolver.getNamedType('num', 'dart:core');

      final sub = RecordType(
        positionalFields: [],
        namedFields: [RecordTypeNamedField('a', intType)],
        isNullable: false,
      );
      final sup = RecordType(
        positionalFields: [],
        namedFields: [RecordTypeNamedField('a', numType)],
        isNullable: false,
      );
      expect(typeUtils.isSubtypeOf(sub, sup), isTrue);
    });

    test('({int a}) is NOT subtype of ({int b})', () {
      final intType = resolver.getNamedType('int', 'dart:core');

      final sub = RecordType(
        positionalFields: [],
        namedFields: [RecordTypeNamedField('a', intType)],
        isNullable: false,
      );
      final sup = RecordType(
        positionalFields: [],
        namedFields: [RecordTypeNamedField('b', intType)],
        isNullable: false,
      );
      expect(typeUtils.isSubtypeOf(sub, sup), isFalse);
    });
  });
}
