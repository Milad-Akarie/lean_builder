import 'package:lean_builder/builder.dart';
import 'package:lean_builder/src/build_script/build_script.dart';
import 'package:lean_builder/src/build_script/errors.dart';
import 'package:lean_builder/src/graph/references_scanner.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/test/scanner.dart';
import 'package:lean_builder/test.dart';
import 'package:test/test.dart';

void main() {
  late PackageFileResolver fileResolver;
  late ReferencesScanner scanner;
  late ResolverImpl resolver;

  setUpAll(() {
    fileResolver = getTestFileResolver();
  });

  setUp(() {
    final AssetsGraph graph = AssetsGraph('hash');
    scanner = ReferencesScanner(graph, fileResolver);
    scanDartSdkAndPackages(scanner, packages: <String>{'lean_builder'});
    resolver = ResolverImpl(graph, fileResolver, SourceParser());
  });

  test('Should parse Simple SharedPart builder entry', () {
    final StringAsset asset = StringAsset.withRawUri('''
      import 'package:lean_builder/builder.dart';
      
      @LeanGenerator.shared()
      class FooGenerator extends Generator {}
    ''', 'package:test_/foo_generator.dart');

    scanner.scan(asset);
    final (List<BuilderDefinitionEntry> entries, _) = parseBuilderEntries(<Asset>{asset}, resolver);
    expect(entries.length, 1);
    expect(
      entries.first,
      BuilderDefinitionEntry(
        key: 'FooGenerator',
        import: asset.shortUri.toString(),
        builderType: BuilderType.shared,
        generatorName: 'FooGenerator',
        expectsOptions: false,
        generateToCache: false,
      ),
    );
  });
  // test relative import
  test('Should parse Simple builder with relative import', () {
    final StringAsset asset = StringAsset('''
      import 'package:lean_builder/builder.dart';
      
     @LeanGenerator.shared()
      class FooGenerator extends Generator {}
    ''', fileName: 'generator.dart');

    scanner.scan(asset);
    final (List<BuilderDefinitionEntry> entries, _) = parseBuilderEntries(<Asset>{asset}, resolver);
    expect(entries.length, 1);
    expect(
      entries.first,
      BuilderDefinitionEntry(
        key: 'FooGenerator',
        import: '../../../../../../../test_/generator.dart',
        builderType: BuilderType.shared,
        generatorName: 'FooGenerator',
        expectsOptions: false,
        generateToCache: false,
      ),
    );
  });

  test('Should parse Simple Library builder entry', () {
    final StringAsset asset = StringAsset.withRawUri('''
      import 'package:lean_builder/builder.dart';
      
      @LeanGenerator({'.lib.dart'})
      class FooGenerator extends Generator {}
    ''', 'package:test_/foo_generator.dart');

    scanner.scan(asset);
    final (List<BuilderDefinitionEntry> entries, _) = parseBuilderEntries(
      <Asset>{asset},
      resolver,
    );
    expect(entries.length, 1);

    expect(
      entries.first,
      BuilderDefinitionEntry(
        key: 'FooGenerator',
        outputExtensions: <String>{'.lib.dart'},
        import: asset.shortUri.toString(),
        builderType: BuilderType.library,
        generatorName: 'FooGenerator',
        expectsOptions: false,
      ),
    );
  });

  test('Should parse SharedPart with custom key', () {
    final StringAsset asset = StringAsset.withRawUri('''
      import 'package:lean_builder/builder.dart';
      
      @LeanGenerator.shared(key: 'CustomKey')
      class FooGenerator extends Generator {}
    ''', 'package:test_/foo_generator.dart');

    scanner.scan(asset);
    final (List<BuilderDefinitionEntry> entries, _) = parseBuilderEntries(
      <Asset>{asset},
      resolver,
    );
    expect(entries.length, 1);
    expect(
      entries.first,
      BuilderDefinitionEntry(
        key: 'CustomKey',
        import: asset.shortUri.toString(),
        builderType: BuilderType.shared,
        generatorName: 'FooGenerator',
        expectsOptions: false,
        generateToCache: false,
      ),
    );
  });

  test('Should parse SharedPart with customizations', () {
    final StringAsset asset = StringAsset.withRawUri('''
      import 'package:lean_builder/builder.dart';
      
      @LeanGenerator.shared(generateToCache: false, options: {'key': 'value'}, generateFor: {'lib/**.dart'}, runsBefore: {'other'})
      class FooGenerator extends Generator {}
    ''', 'package:test_/foo_generator.dart');

    scanner.scan(asset);
    final (List<BuilderDefinitionEntry> entries, _) = parseBuilderEntries(
      <Asset>{asset},
      resolver,
    );
    expect(entries.length, 1);
    expect(
      entries.first,
      BuilderDefinitionEntry(
        key: 'FooGenerator',
        import: asset.shortUri.toString(),
        builderType: BuilderType.shared,
        generatorName: 'FooGenerator',
        expectsOptions: false,
        generateToCache: false,
        options: <String, dynamic>{'key': 'value'},
        generateFor: <String>{'lib/**.dart'},
        runsBefore: <String>{'other'},
      ),
    );
  });

  test('Should throw if annotated class does not have extend clause', () {
    final StringAsset asset = StringAsset('''
      import 'package:lean_builder/builder.dart';
      
      @LeanGenerator.shared()
      class Foo {}
    ''');

    scanner.scan(asset);
    expect(
      () => parseBuilderEntries(<Asset>{asset}, resolver),
      throwsA(isA<BuildConfigError>()),
    );
  });

  test('Should throw if annotated class does not extend Generator', () {
    final StringAsset asset = StringAsset('''
      import 'package:lean_builder/builder.dart';
      
      class Bar{}
      @LeanGenerator.shared()
      class FooGenerator extends Bar {}
    ''');

    scanner.scan(asset);
    expect(
      () => parseBuilderEntries(<Asset>{asset}, resolver),
      throwsA(isA<BuildConfigError>()),
    );
  });

  test('Should register the generic type args for the extended generator', () {
    final StringAsset asset = StringAsset.withRawUri('''
      import 'package:lean_builder/builder.dart';
       class Bar{ const Bar();}
      @LeanGenerator.shared()
      class FooGenerator extends GeneratorForAnnotation<Bar> {}
    ''', 'package:test_/foo_generator.dart');

    scanner.scan(asset);
    final (List<BuilderDefinitionEntry> entries, _) = parseBuilderEntries(
      <Asset>{asset},
      resolver,
    );
    expect(entries.length, 1);
    expect(
      entries.first,
      BuilderDefinitionEntry(
        key: 'FooGenerator',
        import: asset.shortUri.toString(),
        builderType: BuilderType.shared,
        generatorName: 'FooGenerator',
        expectsOptions: false,
        generateToCache: false,
        registeredTypes: <RuntimeTypeRegisterEntry>[
          RuntimeTypeRegisterEntry('Bar', asset.shortUri.toString(), asset.id),
        ],
      ),
    );
  });

  test('Should register the generic type args for the annotation', () {
    final StringAsset asset = StringAsset.withRawUri('''
      import 'package:lean_builder/builder.dart';
       class Bar {}
       class Baz {}
      @LeanGenerator.shared(registerTypes: {Bar,Baz})
      class FooGenerator extends Generator {}
    ''', 'package:test_/foo_generator.dart');

    scanner.scan(asset);
    final (List<BuilderDefinitionEntry> entries, _) = parseBuilderEntries(
      <Asset>{asset},
      resolver,
    );
    expect(entries.length, 1);
    expect(
      entries.first,
      BuilderDefinitionEntry(
        key: 'FooGenerator',
        import: asset.shortUri.toString(),
        builderType: BuilderType.shared,
        generatorName: 'FooGenerator',
        expectsOptions: false,
        generateToCache: false,
        registeredTypes: <RuntimeTypeRegisterEntry>[
          RuntimeTypeRegisterEntry('Bar', asset.shortUri.toString(), asset.id),
          RuntimeTypeRegisterEntry('Baz', asset.shortUri.toString(), asset.id),
        ],
      ),
    );
  });

  test(
    'Should set expectsOptions to true if the generator has a single positional parameter of type BuilderOptions',
    () {
      final StringAsset asset = StringAsset.withRawUri('''
      import 'package:lean_builder/builder.dart';
      
      @LeanGenerator.shared()
      class FooGenerator extends Generator {
        FooGenerator(BuilderOptions options);
      }
    ''', 'package:test_/foo_generator.dart');

      scanner.scan(asset);
      final (List<BuilderDefinitionEntry> entries, _) = parseBuilderEntries(
        <Asset>{asset},
        resolver,
      );
      expect(entries.length, 1);
      expect(
        entries.first,
        BuilderDefinitionEntry(
          key: 'FooGenerator',
          import: asset.shortUri.toString(),
          builderType: BuilderType.shared,
          generatorName: 'FooGenerator',
          expectsOptions: true,
          generateToCache: false,
        ),
      );
    },
  );

  test(
    'Should throw if the constructor has more then one positional parameter of type BuilderOptions',
    () {
      final StringAsset asset = StringAsset.withRawUri('''
      import 'package:lean_builder/builder.dart';
      
      @LeanGenerator.shared()
      class FooGenerator extends Generator {
        FooGenerator(BuilderOptions options, String name);
      }
    ''', 'package:test_/foo_generator.dart');
      scanner.scan(asset);
      expect(
        () => parseBuilderEntries(<Asset>{asset}, resolver),
        throwsA(isA<BuildConfigError>()),
      );
    },
  );

  test('Should throw if @LeanGenerator is used on none class elements', () {
    final StringAsset asset = StringAsset.withRawUri('''
      import 'package:lean_builder/builder.dart';
      
      @LeanGenerator.shared()
       enum FooEnum {}
    ''', 'package:test_/foo_generator.dart');
    scanner.scan(asset);
    expect(
      () => parseBuilderEntries(<Asset>{asset}, resolver),
      throwsA(isA<BuildConfigError>()),
    );
  });

  test(
    'Should throw if the constructor has more then one positional parameter of type BuilderOptions for @LeanBuilder annotation',
    () {
      final StringAsset asset = StringAsset.withRawUri('''
      import 'package:lean_builder/builder.dart';
      
      @LeanBuilder()
      class FooBuilder extends Builder {
        FooBuilder(BuilderOptions options, String name);
      }
    ''', 'package:test_/foo_generator.dart');
      scanner.scan(asset);
      expect(
        () => parseBuilderEntries(<Asset>{asset}, resolver),
        throwsA(isA<BuildConfigError>()),
      );
    },
  );

  test(
    'Should throw if the constructor has a single BuilderOptions parameter but is not positional',
    () {
      final StringAsset asset = StringAsset.withRawUri('''
      import 'package:lean_builder/builder.dart';
      
      @LeanGenerator.shared()
      class FooGenerator extends Generator {
        FooGenerator({required BuilderOptions options});
      }
    ''', 'package:test_/foo_generator.dart');
      scanner.scan(asset);
      expect(
        () => parseBuilderEntries(<Asset>{asset}, resolver),
        throwsA(isA<BuildConfigError>()),
      );
    },
  );

  test(
    'Should throw if the constructor has a single BuilderOptions parameter but is not positional for @LeanBuilder',
    () {
      final StringAsset asset = StringAsset('''
      import 'package:lean_builder/builder.dart';
      
      @LeanBuilder()
      class FooBuilder extends Builder {
        FooBuilder({required BuilderOptions options});
      }
    ''');
      scanner.scan(asset);
      expect(
        () => parseBuilderEntries(<Asset>{asset}, resolver),
        throwsA(isA<BuildConfigError>()),
      );
    },
  );

  test('Should parse the @LeanBuilderOverrides annotation', () {
    final StringAsset asset = StringAsset('''
      import 'package:lean_builder/builder.dart';
      
      @LeanBuilderOverrides()
      const builderOverrides = [
        BuilderOverride(key: 'CustomKey', runsBefore: {'SerializableGenerator'}, generateFor: {'lib/**.dart'}, options: {'key': 'value'}),
      ];
    ''');
    scanner.scan(asset);
    final (_, List<BuilderOverride> overries) = parseBuilderEntries(<Asset>{
      asset,
    }, resolver);
    expect(overries.length, 1);
    expect(
      overries.first,
      BuilderOverride(
        key: 'CustomKey',
        runsBefore: <String>{'SerializableGenerator'},
        generateFor: <String>{'lib/**.dart'},
        options: <String, dynamic>{'key': 'value'},
      ),
    );
  });

  test(
    'Should throw if the @LeanBuilderOverrides is not a top level const variable',
    () {
      final StringAsset asset = StringAsset('''
      import 'package:lean_builder/builder.dart';
      
      @LeanBuilderOverrides()
      final builderOverrides = [
        BuilderOverride(key: 'CustomKey', runsBefore: {'SerializableGenerator'}),
      ];
    ''');
      scanner.scan(asset);
      expect(
        () => parseBuilderEntries(<Asset>{asset}, resolver),
        throwsA(isA<BuildConfigError>()),
      );
    },
  );

  test('Should throw if the @LeanBuilderOverrides is not a const list', () {
    final StringAsset asset = StringAsset('''
      import 'package:lean_builder/builder.dart';
      
      @LeanBuilderOverrides()
      const builderOverrides = {
        BuilderOverride(key: 'CustomKey', runsBefore: {'SerializableGenerator'}),
      };
    ''');
    scanner.scan(asset);
    expect(
      () => parseBuilderEntries(<Asset>{asset}, resolver),
      throwsA(isA<BuildConfigError>()),
    );
  });

  test('Should throw if any element in the list is not a BuilderOverride', () {
    final StringAsset asset = StringAsset('''
      import 'package:lean_builder/builder.dart';
      
      @LeanBuilderOverrides()
      const builderOverrides = [
        BuilderOverride(key: 'CustomKey', runsBefore: {'SerializableGenerator'}),
        1,
      ];
    ''');
    scanner.scan(asset);
    expect(
      () => parseBuilderEntries(<Asset>{asset}, resolver),
      throwsA(isA<BuildConfigError>()),
    );
  });

  test('Should override the builder entry with the one in the overrides', () {
    final StringAsset asset = StringAsset.withRawUri('''
      import 'package:lean_builder/builder.dart';
      
      @LeanGenerator.shared(options: {'feature': true})
      class FooGenerator extends Generator {}
      
      @LeanBuilderOverrides()
      const builderOverrides = [
        BuilderOverride(key: 'FooGenerator', options: {'feature': false}, generateFor: {'lib/**.dart'}),
      ];
    ''', 'package:test_/foo_generator.dart');
    scanner.scan(asset);
    final (
      List<BuilderDefinitionEntry> entries,
      List<BuilderOverride> overries,
    ) = parseBuilderEntries(<Asset>{
      asset,
    }, resolver);
    final List<BuilderDefinitionEntry> withOverrides = applyOverrides(
      entries,
      overries,
    );
    expect(entries.length, 1);
    expect(
      withOverrides.first,
      BuilderDefinitionEntry(
        key: 'FooGenerator',
        import: asset.shortUri.toString(),
        builderType: BuilderType.shared,
        generatorName: 'FooGenerator',
        expectsOptions: false,
        generateToCache: false,
        generateFor: <String>{'lib/**.dart'},
        options: <String, dynamic>{'feature': false},
      ),
    );
  });
}
