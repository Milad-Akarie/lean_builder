import 'package:lean_builder/builder.dart';
import 'package:lean_builder/src/element/element.dart';
import 'package:lean_builder/src/graph/references_scanner.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
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

  test('should resolve simple mixin element', () {
    final StringAsset asset = StringAsset('mixin Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final MixinElementImpl? mixinElement = library.getMixin('Foo');
    expect(mixinElement, isNotNull);
    expect(mixinElement!.isBase, isFalse);
    expect(mixinElement.superclassConstraints, isEmpty);
  });

  test('should resolve base mixin element', () {
    final StringAsset asset = StringAsset('base mixin Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final MixinElementImpl? mixinElement = library.getMixin('Foo');
    expect(mixinElement, isNotNull);
    expect(mixinElement!.isBase, isTrue);
    expect(mixinElement.superclassConstraints, isEmpty);
  });

  test('should resolve mixin with superclassConstraints', () {
    final StringAsset asset = StringAsset('''
      class Bar {}
      class Baz {}
      mixin Foo on Bar, Baz {}
    ''');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final MixinElementImpl? mixinElement = library.getMixin('Foo');
    expect(mixinElement, isNotNull);
    expect(
      mixinElement!.superclassConstraints,
      library.classes.map((ClassElementImpl e) => e.thisType),
    );
  });
}
