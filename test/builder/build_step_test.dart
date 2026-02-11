import 'dart:convert';

import 'package:glob/glob.dart';
import 'package:lean_builder/builder.dart';
import 'package:lean_builder/src/graph/references_scanner.dart';
import 'package:lean_builder/test.dart';
import 'package:test/test.dart';

void main() {
  group('BuildStepImpl', () {
    test('should validate allowed extensions', () {
      const source = 'class MyClass {}';
      final buildStep = buildStepForTestContent(source);

      expect(buildStep.allowedExtensions, contains('g.dart'));
      expect(buildStep.outputs, isEmpty);
    });

    test('should throw on invalid extension', () {
      const source = 'class MyClass {}';
      final asset = StringAsset(source);
      final fileResolver = getTestFileResolver();
      final graph = AssetsGraph('hash');
      final scanner = ReferencesScanner(graph, fileResolver);
      scanner.scan(asset);
      final resolver = Resolver.from(graph, fileResolver, SourceParser());

      final buildStep = BuildStepImpl(
        asset,
        resolver,
        allowedExtensions: {'.g.dart'},
        generateToCache: false,
      );

      expect(
        () => buildStep.writeAsString('content', extension: '.invalid'),
        throwsArgumentError,
      );
    });

    test('should check for valid part directive', () {
      const sourceWithPart = 'part "test.g.dart"; class MyClass {}';
      final buildStep = buildStepForTestAsset(
        StringAsset(sourceWithPart, fileName: 'test.dart'),
      );

      expect(buildStep.hasValidPartDirectiveFor('.g.dart'), isTrue);
      expect(buildStep.hasValidPartDirectiveFor('.other.dart'), isFalse);
    });

    test('should check for missing part directive', () {
      const sourceWithoutPart = 'class MyClass {}';
      final buildStep = buildStepForTestContent(sourceWithoutPart);

      expect(buildStep.hasValidPartDirectiveFor('.g.dart'), isFalse);
    });

    test('should find assets with matcher', () {
      const source = 'class MyClass {}';
      final buildStep = buildStepForTestContent(source);

      // Test that findAssets doesn't throw
      final assets = buildStep.findAssets(GlobPathMatcher(Glob('**.dart')));
      expect(assets, isA<List>());
    });

    test('should write content to output', () {
      const source = 'class MyClass {}';
      final buildStep = buildStepForTestContent(source);

      expect(buildStep.output, isNull);

      buildStep.writeAsString('generated content', extension: '.g.dart');

      expect(buildStep.output, isNotNull);
      expect(buildStep.output!.readAsStringSync(), equals('generated content'));
    });

    test('should write as bytes', () {
      const source = 'class MyClass {}';
      final buildStep = buildStepForTestContent(source);

      final bytes = utf8.encode('generated content');
      buildStep.writeAsBytes(bytes, extension: '.g.dart');

      expect(buildStep.output, isNotNull);
      expect(buildStep.output!.readAsStringSync(), equals('generated content'));
    });

    test('should write as string with custom encoding', () {
      const source = 'class MyClass {}';
      final buildStep = buildStepForTestContent(source);

      buildStep.writeAsString(
        'generated content',
        extension: '.g.dart',
        encoding: utf8,
      );

      expect(buildStep.output, isNotNull);
      expect(buildStep.output!.readAsStringSync(), equals('generated content'));
    });
  });

  group('SharedBuildStep', () {
    test('should create SharedBuildStep instance', () {
      const source = 'class MyClass {}';
      final asset = StringAsset(source, fileName: 'test.dart');
      final fileResolver = getTestFileResolver();
      final graph = AssetsGraph('hash');
      final scanner = ReferencesScanner(graph, fileResolver);
      scanner.scan(asset);
      final resolver = Resolver.from(graph, fileResolver, SourceParser());

      final outputUri = asset.uriWithExtension('.g.dart');
      final sharedStep = SharedBuildStep(asset, resolver, outputUri: outputUri);

      expect(sharedStep, isNotNull);
      expect(sharedStep.asset, equals(asset));
      expect(sharedStep.resolver, equals(resolver));
      expect(sharedStep.outputUri, equals(outputUri));
      expect(sharedStep.allowedExtensions, contains('.g.dart'));
    });

    test('should have correct allowed extensions', () {
      const source = 'class MyClass {}';
      final asset = StringAsset(source, fileName: 'test.dart');
      final fileResolver = getTestFileResolver();
      final graph = AssetsGraph('hash');
      final scanner = ReferencesScanner(graph, fileResolver);
      scanner.scan(asset);
      final resolver = Resolver.from(graph, fileResolver, SourceParser());

      final outputUri = asset.uriWithExtension('.g.dart');
      final sharedStep = SharedBuildStep(asset, resolver, outputUri: outputUri);

      expect(sharedStep.allowedExtensions, equals({'.g.dart'}));
    });
  });
}
