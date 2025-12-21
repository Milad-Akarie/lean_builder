import 'package:lean_builder/builder.dart';
import 'package:lean_builder/src/element/element.dart';
import 'package:lean_builder/src/graph/references_scanner.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/test/scanner.dart';
import 'package:lean_builder/test.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  PackageFileResolver? fileResolver;
  ReferencesScanner? scanner;
  ResolverImpl? resolver;

  setUp(() {
    fileResolver = getTestFileResolver();
    final AssetsGraph graph = AssetsGraph('hash');
    scanner = ReferencesScanner(graph, fileResolver!);
    resolver = ResolverImpl(graph, fileResolver!, SourceParser());
  });

  // should resolve refs of core dart types
  test('should resolve core dart types', () {
    final StringAsset asset = StringAsset('''
      import 'dart:async';
      
      class CoreTypes {
        final int intField;
        final double doubleField;
        final String stringField;
        final bool boolField;
        final List<int> listField;
        final Map<String, int> mapField;
        final Set<String> setField;
        final Function functionField;
        final Object objectField;
        final num numField;
        final Type typeField;
        final DateTime dateTimeField;
        final RegExp regExpField;
        final Uri uriField;
        final Symbol symbolField;
        final BigInt bigIntField;
        final dynamic dynamicField;
        final noTypeField = '';
        final Future<String> futureField = Future.value('');
        final FutureOr<String> futureOrField = Future.value('');
        final Stream<String> streamField = Stream.fromIterable(['a', 'b']);
        void voidMethod() {}
        Never neverMethod() {}
      }
    ''');
    scanner!.scan(asset);
    scanDartSdkAndPackages(scanner!, packages: <String>{'meta'});
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('CoreTypes');
    expect(classElement, isNotNull);
    expect(classElement!.getField('intField')!.type.isDartCoreInt, isTrue);
    expect(classElement.getField('doubleField')!.type.isDartCoreDouble, isTrue);
    expect(classElement.getField('stringField')!.type.isDartCoreString, isTrue);
    expect(classElement.getField('boolField')!.type.isDartCoreBool, isTrue);
    expect(classElement.getField('listField')!.type.isDartCoreList, isTrue);
    expect(classElement.getField('mapField')!.type.isDartCoreMap, isTrue);
    expect(classElement.getField('setField')!.type.isDartCoreSet, isTrue);
    expect(
      classElement.getField('functionField')!.type.isDartCoreFunction,
      isTrue,
    );
    expect(classElement.getField('objectField')!.type.isDartCoreObject, isTrue);
    expect(classElement.getField('numField')!.type.isDartCoreNum, isTrue);
    expect(classElement.getField('typeField')!.type.isDartCoreType, isTrue);
    expect(
      classElement.getField('dateTimeField')!.type.isDartCoreDateTime,
      isTrue,
    );
    expect(classElement.getField('noTypeField')!.type.isInvalid, isTrue);
    expect(classElement.getField('dynamicField')!.type.isDynamic, isTrue);
    expect(classElement.getMethod('voidMethod')!.returnType.isVoid, isTrue);
    expect(classElement.getMethod('neverMethod')!.returnType.isNever, isTrue);
    expect(
      classElement.getField('futureField')!.type.isDartAsyncFuture,
      isTrue,
    );
    expect(
      classElement.getField('futureOrField')!.type.isDartAsyncFutureOr,
      isTrue,
    );
    expect(
      classElement.getField('streamField')!.type.isDartAsyncStream,
      isTrue,
    );
  });
}
