import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/element.dart';
import 'package:lean_builder/src/graph/references_scanner.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
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

  group('LibraryDirectiveElement', () {
    test('should resolve library directive', () {
      final StringAsset asset = StringAsset('library foo;');
      scanner!.scan(asset);
      final LibraryElement library = resolver!.resolveLibrary(asset);
      final LibraryDirectiveElement? directive = library.directives.whereType<LibraryDirectiveElement>().firstOrNull;
      expect(directive, isNotNull);
      expect(directive!.stringUri, 'foo');
    });

    test('should resolve library directive with dotted name', () {
      final StringAsset asset = StringAsset('library foo.bar.baz;');
      scanner!.scan(asset);
      final LibraryElement library = resolver!.resolveLibrary(asset);
      final LibraryDirectiveElement? directive = library.directives.whereType<LibraryDirectiveElement>().firstOrNull;
      expect(directive, isNotNull);
      expect(directive!.stringUri, 'foo.bar.baz');
    });

    test('should handle library directive without name', () {
      final StringAsset asset = StringAsset('class Foo {}');
      scanner!.scan(asset);
      final LibraryElement library = resolver!.resolveLibrary(asset);
      final LibraryDirectiveElement? directive = library.directives.whereType<LibraryDirectiveElement>().firstOrNull;
      expect(directive, isNull);
    });
  });

  group('ImportElement', () {
    test('should resolve import directive', () {
      final StringAsset utilAsset = StringAsset('class Util {}', fileName: 'util.dart');
      scanner!.scan(utilAsset);
      final StringAsset asset = StringAsset("import 'util.dart';");
      scanner!.scan(asset);
      final LibraryElement library = resolver!.resolveLibrary(asset);
      final ImportElement? directive = library.directives.whereType<ImportElement>().firstOrNull;
      expect(directive, isNotNull);
      expect(directive!.stringUri, 'util.dart');
    });

    test('should resolve import with prefix', () {
      final StringAsset utilAsset = StringAsset('class Util {}', fileName: 'util.dart');
      scanner!.scan(utilAsset);
      final StringAsset asset = StringAsset("import 'util.dart' as u;");
      scanner!.scan(asset);
      final LibraryElement library = resolver!.resolveLibrary(asset);
      final ImportElement? directive = library.directives.whereType<ImportElement>().firstOrNull;
      expect(directive, isNotNull);
      expect(directive!.prefix, 'u');
    });

    test('should resolve deferred import', () {
      final StringAsset utilAsset = StringAsset('class Util {}', fileName: 'util.dart');
      scanner!.scan(utilAsset);
      final StringAsset asset = StringAsset("import 'util.dart' deferred as u;");
      scanner!.scan(asset);
      final LibraryElement library = resolver!.resolveLibrary(asset);
      final ImportElement? directive = library.directives.whereType<ImportElement>().firstOrNull;
      expect(directive, isNotNull);
      expect(directive!.isDeferred, isTrue);
    });

    test('should resolve import with show combinator', () {
      final StringAsset utilAsset = StringAsset('class Util {} class Other {}', fileName: 'util.dart');
      scanner!.scan(utilAsset);
      final StringAsset asset = StringAsset("import 'util.dart' show Util;");
      scanner!.scan(asset);
      final LibraryElement library = resolver!.resolveLibrary(asset);
      final ImportElement? directive = library.directives.whereType<ImportElement>().firstOrNull;
      expect(directive, isNotNull);
      expect(directive!.shownNames, contains('Util'));
    });

    test('should resolve import with hide combinator', () {
      final StringAsset utilAsset = StringAsset('class Util {} class Other {}', fileName: 'util.dart');
      scanner!.scan(utilAsset);
      final StringAsset asset = StringAsset("import 'util.dart' hide Other;");
      scanner!.scan(asset);
      final LibraryElement library = resolver!.resolveLibrary(asset);
      final ImportElement? directive = library.directives.whereType<ImportElement>().firstOrNull;
      expect(directive, isNotNull);
      expect(directive!.hiddenNames, contains('Other'));
    });
  });

  group('ExportElement', () {
    test('should resolve export directive', () {
      final StringAsset utilAsset = StringAsset('class Util {}', fileName: 'util.dart');
      scanner!.scan(utilAsset);
      final StringAsset asset = StringAsset("export 'util.dart';");
      scanner!.scan(asset);
      final LibraryElement library = resolver!.resolveLibrary(asset);
      final ExportElement? directive = library.directives.whereType<ExportElement>().firstOrNull;
      expect(directive, isNotNull);
      expect(directive!.stringUri, 'util.dart');
    });

    test('should resolve export with show combinator', () {
      final StringAsset utilAsset = StringAsset('class Util {} class Other {}', fileName: 'util.dart');
      scanner!.scan(utilAsset);
      final StringAsset asset = StringAsset("export 'util.dart' show Util;");
      scanner!.scan(asset);
      final LibraryElement library = resolver!.resolveLibrary(asset);
      final ExportElement? directive = library.directives.whereType<ExportElement>().firstOrNull;
      expect(directive, isNotNull);
      expect(directive!.shownNames, contains('Util'));
    });
  });

  group('PartElement', () {
    test('should resolve part directive', () {
      final StringAsset partAsset = StringAsset('part of foo;', fileName: 'part.dart');
      scanner!.scan(partAsset);
      final StringAsset asset = StringAsset("library foo; part 'part.dart';");
      scanner!.scan(asset);
      final LibraryElement library = resolver!.resolveLibrary(asset);
      final PartElement? directive = library.directives.whereType<PartElement>().firstOrNull;
      expect(directive, isNotNull);
      expect(directive!.stringUri, 'part.dart');
    });
  });

  group('PartOfElement', () {
    test('should resolve part of directive', () {
      final StringAsset partAsset = StringAsset("part of 'foo.dart';", fileName: 'part.dart');
      scanner!.scan(partAsset);
      final StringAsset asset = StringAsset("library foo;", fileName: 'foo.dart');
      scanner!.scan(asset);
      final LibraryElement library = resolver!.resolveLibrary(partAsset);
      final PartOfElement? directive = library.directives.whereType<PartOfElement>().firstOrNull;
      expect(directive, isNotNull);
      expect(directive!.stringUri, 'foo.dart');
      expect(directive.referencesLibraryDirective, isTrue);
    });
  });
}
