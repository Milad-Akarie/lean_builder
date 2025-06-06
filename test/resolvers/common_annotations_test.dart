import 'package:lean_builder/src/asset/package_file_resolver.dart' show PackageFileResolver;
import 'package:lean_builder/src/element/element.dart';
import 'package:lean_builder/src/graph/assets_graph.dart' show AssetsGraph;
import 'package:lean_builder/src/graph/references_scanner.dart' show ReferencesScanner;
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/resolvers/source_parser.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import '../scanner/string_asset_src.dart';
import '../utils/test_utils.dart';

void main() {
  PackageFileResolver? fileResolver;
  ReferencesScanner? scanner;
  ResolverImpl? resolver;

  setUp(() {
    fileResolver = PackageFileResolver.forRoot();
    final AssetsGraph graph = AssetsGraph('hash');
    scanner = ReferencesScanner(graph, fileResolver!);
    resolver = ResolverImpl(graph, fileResolver!, SourceParser());
  });

  // should resolve refs of core dart types
  test('should resolve core dart types', () {
    final StringAsset asset = StringAsset('''
      import 'package:meta/meta.dart';
      import 'package:meta/meta_meta.dart';
      
      @alwaysThrows
      @deprecated
      @deprecated
      @doNotStore
      @factory
      @internal
      @isTest
      @isTestGroup
      @literal
      @mustBeOverridden
      @mustCallSuper
      @nonVirtual
      @optionalTypeArgs
      @override
      @protected
      @redeclare
      @reopen
      @required
      @sealed
      @useResult
      @useResult
      @visibleForOverriding
      @Target()
      class AnnotatedClass {}
    ''');
    scanner!.registerAndScan(asset);
    scanDartSdk(scanner!, also: <String>{'meta'});
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('AnnotatedClass');
    expect(classElement, isNotNull);
    expect(classElement!.getAnnotation('alwaysThrows')!.isAlwaysThrows, isTrue);
    expect(classElement.getAnnotation('deprecated')!.isDeprecated, isTrue);
    expect(classElement.getAnnotation('doNotStore')!.isDoNotStore, isTrue);
    expect(classElement.getAnnotation('factory')!.isFactory, isTrue);
    expect(classElement.getAnnotation('internal')!.isInternal, isTrue);
    expect(classElement.getAnnotation('isTest')!.isIsTest, isTrue);
    expect(classElement.getAnnotation('isTestGroup')!.isIsTestGroup, isTrue);
    expect(classElement.getAnnotation('literal')!.isLiteral, isTrue);
    expect(
      classElement.getAnnotation('mustBeOverridden')!.isMustBeOverridden,
      isTrue,
    );
    expect(
      classElement.getAnnotation('mustCallSuper')!.isMustCallSuper,
      isTrue,
    );
    expect(classElement.getAnnotation('nonVirtual')!.isNonVirtual, isTrue);
    expect(
      classElement.getAnnotation('optionalTypeArgs')!.isOptionalTypeArgs,
      isTrue,
    );
    expect(classElement.getAnnotation('override')!.isOverride, isTrue);
    expect(classElement.getAnnotation('protected')!.isProtected, isTrue);
    expect(classElement.getAnnotation('redeclare')!.isRedeclare, isTrue);
    expect(classElement.getAnnotation('reopen')!.isReopen, isTrue);
    expect(classElement.getAnnotation('required')!.isRequired, isTrue);
    expect(classElement.getAnnotation('sealed')!.isSealed, isTrue);
    expect(classElement.getAnnotation('useResult')!.isUseResult, isTrue);
    expect(
      classElement.getAnnotation('visibleForOverriding')!.isVisibleForOverriding,
      isTrue,
    );
    expect(classElement.getAnnotation('useResult')!.isUseResult, isTrue);
    expect(classElement.getAnnotation('Target')!.isTarget, isTrue);
    expect(classElement.getAnnotation('useResult')!.isUseResult, isTrue);
    expect(
      classElement.getAnnotation('visibleForOverriding')!.isVisibleForOverriding,
      isTrue,
    );
  });
}
