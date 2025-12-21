import 'package:lean_builder/test.dart';
import 'package:test/test.dart';

void main() {
  test('String Asset should resolve with no issues', () {
    final asset = StringAsset('class A{}', fileName: 'a.dart');
    final buildStep = buildStepForTestAsset(asset);
    final lib = buildStep.resolver.resolveLibrary(asset);
    expect(lib.getClass('A'), isNotNull);
  });

  test('should resolve asset with imports', () {
    final bAsset = StringAsset('class B{}', fileName: 'b.dart');
    final buildStep = buildStepForTestAsset(
      StringAsset(r'import "b.dart"; class A extends B{}', fileName: 'a.dart'),
      extraAssets: [bAsset],
    );
    final lib = buildStep.resolver.resolveLibrary(buildStep.asset);
    final classA = lib.getClass('A');
    expect(classA, isNotNull);
    expect(classA!.superType?.name, isNotNull);
    expect(classA.superType?.declarationRef.srcUri, bAsset.shortUri);
  });

  test('should resolve simple library', () {
    final buildStep = buildStepForTestContent('class A{}');
    expect(buildStep.hasValidPartDirectiveFor('.g.dart'), isFalse);
    final lib = buildStep.library;
    expect(lib.getClass('A'), isNotNull);
    expect(buildStep.output, isNull);
  });

  test('should resolve library with part directive', () {
    final buildStep = buildStepForTestAsset(StringAsset('part "a.g.dart"; class A{}', fileName: 'a.dart'));
    expect(buildStep.hasValidPartDirectiveFor('.g.dart'), isTrue);
    final lib = buildStep.library;
    expect(lib.getClass('A'), isNotNull);
    expect(buildStep.output, isNull);
  });

  test('should resolve library with import directive', () {
    final bAsset = StringAsset('class B{}', fileName: 'b.dart');
    final buildStep = buildStepForTestAsset(
      StringAsset(r'import "b.dart"; class A extends B{}', fileName: 'a.dart'),
      extraAssets: [bAsset],
    );
    final lib = buildStep.library;
    final classA = lib.getClass('A');
    expect(classA, isNotNull);
    expect(classA!.superType?.name, isNotNull);
    expect(classA.superType?.declarationRef.srcUri, bAsset.shortUri);
    expect(buildStep.output, isNull);
  });

  test('should write output as string', () {
    final asset = StringAsset('class A{}', fileName: 'a.dart');
    final buildStep = buildStepForTestAsset(asset);
    buildStep.writeAsString('generated content', extension: '.g.dart');
    expect(buildStep.output, isNotNull);
    expect(buildStep.output!.content, 'generated content');
    expect(buildStep.output!.stringUri, asset.uriWithExtension('.g.dart').toString());
  });
}
