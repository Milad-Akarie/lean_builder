import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/element/element.dart';
import 'package:lean_builder/src/graph/references_scanner.dart';
import 'package:lean_builder/src/resolvers/constant/constant.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/test/scanner.dart';
import 'package:lean_builder/src/type/type.dart';
import 'package:lean_builder/test.dart';
import 'package:test/test.dart';

void main() {
  PackageFileResolverImpl? fileResolver;
  ReferencesScanner? scanner;
  ResolverImpl? resolver;

  setUp(() {
    fileResolver = getTestFileResolver();
    final AssetsGraph graph = AssetsGraph('hash');
    scanner = ReferencesScanner(graph, fileResolver!);
    resolver = ResolverImpl(graph, fileResolver!, SourceParser());
  });

  test('should resolve simple enum element', () {
    final StringAsset asset = StringAsset('enum Foo {item;}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final EnumElementImpl? enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
  });

  test('should resolve enum with implements clause', () {
    final StringAsset asset = StringAsset('''
     class Bar {}
     enum Foo implements Bar {item;}
    ''');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final EnumElementImpl? enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
    expect(enumElement!.interfaces, <InterfaceType>[
      library.getClass('Bar')!.thisType,
    ]);
  });

  test('should resolve enum with mixin clause', () {
    final StringAsset asset = StringAsset('''
     class Bar {}
     enum Foo with Bar {enum1;}
    ''');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final EnumElementImpl? enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
    expect(enumElement!.mixins, <InterfaceType>[
      library.getClass('Bar')!.thisType,
    ]);
  });

  test('should resolve enum with mixin and implements clause', () {
    final StringAsset asset = StringAsset('''
      class Bar {}
      mixin Baz {}
      enum Foo with Baz implements Bar { enum1 }
    ''');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final EnumElementImpl? enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
    expect(enumElement!.interfaces, <InterfaceType>[
      library.getClass('Bar')!.thisType,
    ]);
    expect(enumElement.mixins, <InterfaceType>[
      library.getMixin('Baz')!.thisType,
    ]);
  });

  test('should resolve enum with annotations', () {
    final StringAsset annotationAsset = StringAsset(
      'class Bar { const Bar();}',
      fileName: 'bar.dart',
    );

    final StringAsset asset = StringAsset('''
      import 'bar.dart';
      @Bar()
      enum Foo { enum1 }
    ''', fileName: 'foo.dart');

    scanner!.scan(annotationAsset);
    scanner!.scan(asset);

    final LibraryElement library = resolver!.resolveLibrary(asset);
    final LibraryElement annotationLibrary = resolver!.resolveLibrary(
      annotationAsset,
    );
    final EnumElementImpl? enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);

    expect(enumElement!.metadata.length, 1);
    expect(
      enumElement.metadata[0].type,
      annotationLibrary.getClass('Bar')!.thisType,
    );
  });

  test('should resolve enum with fields', () {
    final StringAsset asset = StringAsset('''
      enum Foo { enum1, enum2 }
    ''');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final EnumElementImpl? enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
    expect(enumElement!.fields.length, 2);
    expect(enumElement.fields[0].name, 'enum1');
    expect(enumElement.fields[1].name, 'enum2');
  });

  test('should resolve enum with no arguments', () {
    final StringAsset asset = StringAsset('''
      enum Foo { item1; }
    ''');
    scanner!.scan(asset);

    final LibraryElement library = resolver!.resolveLibrary(asset);
    final EnumElementImpl? enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
    expect(enumElement!.fields[0].constantValue, isNull);
  });

  test('should resolve enum with arguments', () {
    final StringAsset asset = StringAsset('''
      enum Foo { 
        enum1(1);
        final int value; 
        const Foo(this.value); 
      }
    ''');
    scanner!.scan(asset);
    scanDartSdkAndPackages(scanner!);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final EnumElementImpl? enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
    expect(enumElement!.constructors.length, 1);
    expect(enumElement.constructors[0].parameters[0], isA<ParameterElement>());
    final Iterable<FieldElement> constantFields = enumElement.fields.where(
      (FieldElement field) => field.isEnumConstant,
    );
    final Constant? constantObj = constantFields.first.constantValue;
    expect(constantObj, isA<ConstObject>());
    expect((constantObj as ConstObject).props, <String, ConstInt>{
      'value': ConstInt(1),
    });
  });

  test('should resolve enum with named and optional positional arguments', () {
    final StringAsset asset = StringAsset('''
      enum Foo { 
        enum1(1, name: 'name', value: 2); 
        final int value;
        final String name;  
        const Foo(this.value, {this.name}); 
      }
    ''');
    scanner!.scan(asset);
    scanDartSdkAndPackages(scanner!);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final EnumElementImpl? enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
    final Iterable<FieldElement> constantFields = enumElement!.fields.where(
      (FieldElement field) => field.isEnumConstant,
    );

    expect(constantFields.length, 1);
    final Constant? constantObj = constantFields.first.constantValue;
    expect(constantObj, isA<ConstObject>());
    expect((constantObj as ConstObject).props, <String, Constant>{
      'value': ConstInt(2),
      'name': ConstString('name'),
    });
  });
}
