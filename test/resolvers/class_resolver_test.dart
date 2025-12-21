import 'package:lean_builder/builder.dart';
import 'package:lean_builder/src/element/element.dart';
import 'package:lean_builder/src/graph/references_scanner.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/type/type.dart';
import 'package:lean_builder/test.dart';
import 'package:test/test.dart';

void main() {
  late PackageFileResolver fileResolver;
  ReferencesScanner? scanner;
  ResolverImpl? resolver;

  setUpAll(() {
    fileResolver = getTestFileResolver();
  });

  setUp(() {
    final AssetsGraph graph = AssetsGraph('hash');
    scanner = ReferencesScanner(graph, fileResolver);
    resolver = ResolverImpl(graph, fileResolver, SourceParser());
  });

  test('should resolve simple class element', () {
    final StringAsset asset = StringAsset('class Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    expect(library.getClass('Foo'), isNotNull);
  });

  test('should resolve abstract class element', () {
    final StringAsset asset = StringAsset('abstract class Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.name, 'Foo');
    expect(classElement.hasAbstract, isTrue);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.hasSealedKeyword, isFalse);
    expect(classElement.isConstructable, isFalse);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve final class element', () {
    final StringAsset asset = StringAsset('final class Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.hasAbstract, isFalse);
    expect(classElement.hasFinal, isTrue);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.hasSealedKeyword, isFalse);
    expect(classElement.isConstructable, isTrue);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve base class element', () {
    final StringAsset asset = StringAsset('base class Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.hasAbstract, isFalse);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isTrue);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.hasSealedKeyword, isFalse);
    expect(classElement.isConstructable, isTrue);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve interface class element', () {
    final StringAsset asset = StringAsset('interface class Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.hasAbstract, isFalse);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isTrue);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.hasSealedKeyword, isFalse);
    expect(classElement.isConstructable, isTrue);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve mixin class element', () {
    final StringAsset asset = StringAsset('mixin class Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.hasAbstract, isFalse);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, isTrue);
    expect(classElement.hasSealedKeyword, isFalse);
    expect(classElement.isConstructable, isTrue);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve sealed class element', () {
    final StringAsset asset = StringAsset('sealed class Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.hasAbstract, isFalse);
    expect(classElement.hasSealedKeyword, isTrue);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.isConstructable, isFalse);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve mixin application class element', () {
    final StringAsset asset = StringAsset('''
        class Bar {}
        mixin Baz {}
        class Foo = Bar with Baz;
    ''');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.hasSealedKeyword, isFalse);
    expect(classElement.hasAbstract, isFalse);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.isConstructable, isTrue);
    expect(classElement.isMixinApplication, isTrue);
  });

  test('should resolve abstract interface class element', () {
    final StringAsset asset = StringAsset('abstract interface class Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.name, 'Foo');
    expect(classElement.hasAbstract, isTrue);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isTrue);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.hasSealedKeyword, isFalse);
    expect(classElement.isConstructable, isFalse);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve abstract final class element', () {
    final StringAsset asset = StringAsset('abstract final class Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.name, 'Foo');
    expect(classElement.hasAbstract, isTrue);
    expect(classElement.hasFinal, isTrue);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.hasSealedKeyword, isFalse);
    expect(classElement.isConstructable, isFalse);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve abstract mixin class element', () {
    final StringAsset asset = StringAsset('abstract mixin class Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.name, 'Foo');
    expect(classElement.hasAbstract, isTrue);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, true);
    expect(classElement.hasSealedKeyword, false);
    expect(classElement.isConstructable, false);
    expect(classElement.isMixinApplication, false);
  });

  test('should resolve class with super class', () {
    final StringAsset asset = StringAsset('''
        class Bar {}
        class Foo extends Bar {}
    ''');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.superType, library.getClass('Bar')!.thisType);
  });

  test('should resolve class with super interfaces', () {
    final StringAsset asset = StringAsset('''
         class Bar {}
         class Baz {}
         class Foo implements Bar, Baz {}
    ''');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.interfaces, <InterfaceType>[
      library.getClass('Bar')!.thisType,
      library.getClass('Baz')!.thisType,
    ]);
  });

  test('should resolve class with mixins', () {
    final StringAsset asset = StringAsset('''
        mixin Bar {}
        mixin Baz {}
        class Foo with Bar, Baz {}
    ''');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.mixins, <InterfaceType>[
      library.getMixin('Bar')!.thisType,
      library.getMixin('Baz')!.thisType,
    ]);
  });
}
