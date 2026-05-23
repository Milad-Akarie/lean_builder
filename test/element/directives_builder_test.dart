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

  group('Multiple directives', () {
    test('should resolve multiple imports', () {
      final StringAsset utilAsset = StringAsset('class Util {}', fileName: 'util.dart');
      final StringAsset helperAsset = StringAsset('class Helper {}', fileName: 'helper.dart');
      scanner!.scan(utilAsset);
      scanner!.scan(helperAsset);
      final StringAsset asset = StringAsset("import 'util.dart'; import 'helper.dart';");
      scanner!.scan(asset);
      final LibraryElement library = resolver!.resolveLibrary(asset);
      final imports = library.directives.whereType<ImportElement>().toList();
      expect(imports.length, 2);
      expect(imports[0].stringUri, 'util.dart');
      expect(imports[1].stringUri, 'helper.dart');
    });

    test('should resolve import with multiple show names', () {
      final StringAsset utilAsset = StringAsset('class A {} class B {} class C {}', fileName: 'util.dart');
      scanner!.scan(utilAsset);
      final StringAsset asset = StringAsset("import 'util.dart' show A, B;");
      scanner!.scan(asset);
      final LibraryElement library = resolver!.resolveLibrary(asset);
      final ImportElement? directive = library.directives.whereType<ImportElement>().firstOrNull;
      expect(directive, isNotNull);
      expect(directive!.shownNames, containsAll(['A', 'B']));
    });

    test('should resolve import with multiple hide names', () {
      final StringAsset utilAsset = StringAsset('class A {} class B {} class C {}', fileName: 'util.dart');
      scanner!.scan(utilAsset);
      final StringAsset asset = StringAsset("import 'util.dart' hide A, B;");
      scanner!.scan(asset);
      final LibraryElement library = resolver!.resolveLibrary(asset);
      final ImportElement? directive = library.directives.whereType<ImportElement>().firstOrNull;
      expect(directive, isNotNull);
      expect(directive!.hiddenNames, containsAll(['A', 'B']));
    });

    test('should resolve export with hide combinator', () {
      final StringAsset utilAsset = StringAsset('class Util {} class Other {}', fileName: 'util.dart');
      scanner!.scan(utilAsset);
      final StringAsset asset = StringAsset("export 'util.dart' hide Other;");
      scanner!.scan(asset);
      final LibraryElement library = resolver!.resolveLibrary(asset);
      final ExportElement? directive = library.directives.whereType<ExportElement>().firstOrNull;
      expect(directive, isNotNull);
      expect(directive!.hiddenNames, contains('Other'));
    });

    test('should resolve multiple part directives', () {
      final StringAsset part1Asset = StringAsset('part of foo;', fileName: 'part1.dart');
      final StringAsset part2Asset = StringAsset('part of foo;', fileName: 'part2.dart');
      scanner!.scan(part1Asset);
      scanner!.scan(part2Asset);
      final StringAsset asset = StringAsset("library foo; part 'part1.dart'; part 'part2.dart';");
      scanner!.scan(asset);
      final LibraryElement library = resolver!.resolveLibrary(asset);
      final parts = library.directives.whereType<PartElement>().toList();
      expect(parts.length, 2);
      expect(parts[0].stringUri, 'part1.dart');
      expect(parts[1].stringUri, 'part2.dart');
    });
  });

  group('Directive element properties', () {
    test('should have correct library reference', () {
      final StringAsset utilAsset = StringAsset('class Util {}', fileName: 'util.dart');
      scanner!.scan(utilAsset);
      final StringAsset asset = StringAsset("import 'util.dart';");
      scanner!.scan(asset);
      final LibraryElement library = resolver!.resolveLibrary(asset);
      final ImportElement? directive = library.directives.whereType<ImportElement>().firstOrNull;
      expect(directive!.library, library);
    });

    test('should have valid uri after resolution', () {
      final StringAsset utilAsset = StringAsset('class Util {}', fileName: 'util.dart');
      scanner!.scan(utilAsset);
      final StringAsset asset = StringAsset("import 'util.dart';");
      scanner!.scan(asset);
      final LibraryElement library = resolver!.resolveLibrary(asset);
      final ImportElement? directive = library.directives.whereType<ImportElement>().firstOrNull;
      expect(directive!.uri, isNotNull);
      expect(directive.uri.toString(), contains('util.dart'));
    });

    test('should have valid srcId', () {
      final StringAsset utilAsset = StringAsset('class Util {}', fileName: 'util.dart');
      scanner!.scan(utilAsset);
      final StringAsset asset = StringAsset("import 'util.dart';");
      scanner!.scan(asset);
      final LibraryElement library = resolver!.resolveLibrary(asset);
      final ImportElement? directive = library.directives.whereType<ImportElement>().firstOrNull;
      expect(directive!.srcId, isNotEmpty);
    });

    test('non-deferred import should have isDeferred false', () {
      final StringAsset utilAsset = StringAsset('class Util {}', fileName: 'util.dart');
      scanner!.scan(utilAsset);
      final StringAsset asset = StringAsset("import 'util.dart';");
      scanner!.scan(asset);
      final LibraryElement library = resolver!.resolveLibrary(asset);
      final ImportElement? directive = library.directives.whereType<ImportElement>().firstOrNull;
      expect(directive!.isDeferred, isFalse);
    });

    test('import without prefix should have null prefix', () {
      final StringAsset utilAsset = StringAsset('class Util {}', fileName: 'util.dart');
      scanner!.scan(utilAsset);
      final StringAsset asset = StringAsset("import 'util.dart';");
      scanner!.scan(asset);
      final LibraryElement library = resolver!.resolveLibrary(asset);
      final ImportElement? directive = library.directives.whereType<ImportElement>().firstOrNull;
      expect(directive!.prefix, isNull);
    });

    test('import without show/hide should have empty lists', () {
      final StringAsset utilAsset = StringAsset('class Util {}', fileName: 'util.dart');
      scanner!.scan(utilAsset);
      final StringAsset asset = StringAsset("import 'util.dart';");
      scanner!.scan(asset);
      final LibraryElement library = resolver!.resolveLibrary(asset);
      final ImportElement? directive = library.directives.whereType<ImportElement>().firstOrNull;
      expect(directive!.shownNames, isEmpty);
      expect(directive.hiddenNames, isEmpty);
    });
  });
}
