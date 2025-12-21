# Testing Builders

Lean Builder provides a set of tools to test your generators and builders in isolation without writing files to disk. These tools are available in the `package:lean_builder/test.dart` library.

## Getting Started

To use the testing tools, add `lean_builder` to your `dev_dependencies` and import the test library:

```dart
import 'package:lean_builder/test.dart';
import 'package:test/test.dart';
```

## Core Components

### StringAsset
`StringAsset` is an in-memory implementation of the `Asset` class. It allows you to define the content of an asset as a string, which is useful for simulating source files in tests.

```dart
final asset = StringAsset('class A {}', fileName: 'a.dart');
```

### InMemoryBuildStep
`InMemoryBuildStep` is an implementation of `BuildStep` that captures outputs in memory instead of writing them to the file system. You can access the last written output via the `output` property.

## Helper Functions

### buildStepForTestContent
A convenience function to create an `InMemoryBuildStep` from a raw string.

```dart
test('should resolve simple library', () {
  final buildStep = buildStepForTestContent('class A {}');
  final lib = buildStep.library;
  expect(lib.getClass('A'), isNotNull);
});
```

### buildStepForTestAsset
Creates an `InMemoryBuildStep` for a specific `Asset`. This is useful when you need to test assets with specific paths or multiple related assets.

```dart
test('should resolve asset with imports', () {
  final bAsset = StringAsset('class B {}', fileName: 'b.dart');
  final aAsset = StringAsset('import "b.dart"; class A extends B {}', fileName: 'a.dart');
  
  final buildStep = buildStepForTestAsset(
    aAsset,
    extraAssets: [bAsset],
  );
  
  final lib = buildStep.library;
  final classA = lib.getClass('A');
  expect(classA!.superType?.name, 'B');
});
```

## Verifying Outputs

The primary way to verify what a builder generates is by checking the `output` property of the `InMemoryBuildStep` after calling `builder.build(buildStep)`.

The `InMemoryBuildStep` captures the last file written by the builder as a `StringAsset` in its `output` field.

```dart
test('should verify builder output', () async {
  final builder = MyBuilder(BuilderOptions({}));
  final buildStep = buildStepForTestContent('class A {}');
  
  // The builder calls writeAsString internally
  await builder.build(buildStep);
  
  // Now we verify what the builder wrote
  expect(buildStep.output, isNotNull);
  expect(buildStep.output!.content, contains('Generated code for A'));
});
```

## Real-world Example: Testing a Builder

Here’s a more complete example showing how to test a custom builder that generates JSON metadata.

```dart
test('should generate metadata for annotated class', () async {
  final builder = MyBuilder(BuilderOptions({}));
  final asset = StringAsset(
    '''
    import 'package:my_package/annotations.dart';
    @myAnnotation
    class MyService {}
    ''',
    fileName: 'my_service.dart',
  );

  final buildStep = buildStepForTestAsset(
    asset,
    allowedExtensions: builder.outputExtensions,
    includePackages: {'my_package'},
  );

  await builder.build(buildStep);
  
  expect(buildStep.output, isNotNull);
  expect(buildStep.output!.shortUri, asset.uriWithExtension('.ln.json'));
  expect(buildStep.output!.content, contains('MyService'));
});
```

## Advanced Setup

The Dart SDK is automatically included and scanned when creating a build step using `buildStepForTestContent` or `buildStepForTestAsset`. You only need to provide additional packages if your test code depends on them.

```dart
final buildStep = buildStepForTestAsset(
  myAsset,
  // Only add packages other than the Dart SDK
  includePackages: {'meta', 'path'},
);
```
