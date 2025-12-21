import 'package:lean_builder/builder.dart';
import 'package:lean_builder/element.dart';
import 'package:lean_builder/src/graph/references_scanner.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/test/scanner.dart';
import 'package:lean_builder/test.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  late ReferencesScanner scanner;
  late AssetsGraph assetsGraph;
  late ResolverImpl resolver;
  setUp(() {
    final PackageFileResolver fileResolver = getTestFileResolver();
    assetsGraph = AssetsGraph(fileResolver.packagesHash);
    scanner = ReferencesScanner(assetsGraph, fileResolver);
    resolver = ResolverImpl(assetsGraph, fileResolver, SourceParser());
  });

  test('Should evaluate const fields with literal values', () {
    final StringAsset asset = StringAsset('''
     enum Enum {enum1, enum2;}
    
      class Foo {
        static const int a = 1;
        static const double b = 2.0;
        static const String c = 'hello';
        static const bool d = true;
        static const Type g = int;
        static const Enum h = Enum.enum2;
        static const n = null;
        static const List<int> e = [1, 2, 3];
        static const Set i = {1, 'str', 3};
        static const Map<String, int> f = {'one': 1, 'two': 2};
        static const bool k = false;
        static const num l = 1.0;
      }
    ''', fileName: 'package:lean_builder/path.dart');
    scanDartSdkAndPackages(scanner);
    scanner.scan(asset);
    final LibraryElement library = resolver.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');

    expect(classElement, isNotNull);
    expect(
      classElement!.getField('a')!.constantValue,
      isA<ConstInt>().having((ConstInt c) => c.value, 'value', 1),
    );
    expect(
      classElement.getField('b')!.constantValue,
      isA<ConstDouble>().having((ConstDouble c) => c.value, 'value', 2.0),
    );
    expect(
      classElement.getField('c')!.constantValue,
      isA<ConstString>().having((ConstString c) => c.value, 'value', 'hello'),
    );
    expect(
      classElement.getField('d')!.constantValue,
      isA<ConstBool>().having((ConstBool c) => c.value, 'value', true),
    );
    expect(classElement.getField('g')!.constantValue, isA<ConstType>());
    expect(classElement.getField('n')!.constantValue, isNull);

    expect(
      classElement.getField('e')!.constantValue,
      isA<ConstList>().having((ConstList c) => c.value, 'value', <ConstInt>[
        ConstInt(1),
        ConstInt(2),
        ConstInt(3),
      ]),
    );
    expect(
      classElement.getField('i')!.constantValue,
      isA<ConstSet>().having((ConstSet c) => c.value, 'value', <Constant>{
        ConstInt(1),
        ConstString('str'),
        ConstInt(3),
      }),
    );

    expect(
      classElement.getField('f')!.constantValue,
      isA<ConstMap>().having(
        (ConstMap c) => c.value,
        'value',
        <ConstString, ConstInt>{
          ConstString('one'): ConstInt(1),
          ConstString('two'): ConstInt(2),
        },
      ),
    );

    expect(
      classElement.getField('h')!.constantValue,
      isA<ConstEnumValue>()
          .having((ConstEnumValue c) => c.value, 'value', 'enum2')
          .having(
            (ConstEnumValue c) => c.literalValue,
            'literalValue',
            'Enum.enum2',
          )
          .having((ConstEnumValue c) => c.index, 'index', 1),
    );
    expect(
      classElement.getField('k')!.constantValue,
      isA<ConstBool>().having((ConstBool c) => c.value, 'value', false),
    );
    expect(
      classElement.getField('l')!.constantValue,
      isA<ConstDouble>().having((ConstDouble c) => c.value, 'value', 1.0),
    );
  });
}
