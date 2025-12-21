# Lean Builder

 <p align="center">  
 <a href="https://github.com/Milad-Akarie/lean_builder/stargazers"><img src="https://img.shields.io/github/stars/Milad-Akarie/lean_builder?style=flat&logo=github&colorB=green&label=stars" alt="stars"></a>                    
 <a href="https://pub.dev/packages/lean_builder"><img src="https://img.shields.io/pub/v/lean_builder.svg?label=pub&color=orange" alt="pub version"></a>     
 <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-purple.svg" alt="License: MIT"></a>
 </p>      

<p align="center">                  
<a href="https://www.buymeacoffee.com/miladakarie" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="30px" width= "108px"></a>                  
</p> 


A streamlined Dart build system that applies lean principles to minimize waste and maximize speed.

## Disclaimer

Some core concepts and code-abstractions are borrowed from the Dart build system. However, Lean
Builder is designed as a more efficient and user-friendly alternative, not a direct replacement. It
prioritizes performance and simplicity while offering a streamlined approach to code generation.

## Current Status
Lean Builder is in active development and is not yet fully tested.
- Feedback from the community is welcome to help improve the system.
- Adding more tests is a priority to ensure stability and reliability.
- The Api is considered stable, but some changes may occur based on feedback and testing.

## Overview

Lean Builder is a code generation system designed to be fast, efficient, and easy to use. It
provides a streamlined alternative to other build systems with a focus on performance and developer
experience.

## Features

- Fast incremental builds
- it doesn't relay on mirrors so it can be compiled to native code
- Parallel processing for maximum efficiency
- Watch mode with hot reload support for faster generator development
- Simple, declarative builder configuration using annotations
- Comprehensive asset tracking and dependency management
- Support for shared part builders, library builders, and standard builders
- and much more!

## Installation

Add Lean Builder to your `pubspec.yaml` as a dependency:

```yaml
dev_dependencies:
  lean_builder: <latest-version>
```

using `pub`:

```bash
 flutter pub add lean_builder --dev
 ```

Note: Add `lean_builder` to your `dependenciespe` section, if you plan to use it inside of a
generator package.

## Basic Usage

### One-time Build

To build once, use the following command:

```bash
dart run lean_builder build
```

### Watch Mode

For continuous builds on file changes, use the watch mode:

```bash
dart run lean_builder watch
```

Use the `--dev` flag for development mode with hot reload support:

```bash
dart run lean_builder watch --dev
```

Use the clean command to delete caches and precompiled script:

```bash
dart run lean_builder clean
```

## Creating Builders

Lean Builder offers multiple ways to create code generators, from simple generators to custom
builders.

### Using LeanGenerator

#### Library Generator

Create a generator that outputs standalone library files:

```dart 
@LeanGenerator({'.lib.dart'})
class MyGenerator extends GeneratorForAnnotatedClass<MyAnnotation> {
  @override
  Future<String> generateForClass(buildStep, element, annotation) async {
    return '// Generated code for ${element.name}';
  }
}
```

#### Shared Part Generator

Create a generator that outputs (.g.dart) part files, which can collect multiple outputs from
different generators:

```dart 
@LeanGenerator.shared()
class MySharedGenerator extends GeneratorForAnnotatedClass<MyAnnotation> {
  @override
  Future<String> generateForClass(buildStep, element, annotation) async {
    return '// Generated code for ${element.name}';
  }
}
```

### Custom Builders

For more control, create a custom builder by extending the `Builder` class:

```dart
@LeanBuilder()
class MyBuilder extends Builder {

  @override
  Set<String> get outputExtensions => {'.lib.dart'};

  @override
  bool shouldBuildFor(BuildCandidate candidate) {
    return candidate.isDartSource && candidate.hasTopLevelMetadata;
  }

  @override
  FutureOr<void> build(BuildStep buildStep) {
    final resolver = buildStep.resolver;
    final library = resolver.resolveLibrary(buildStep.asset);
    final elements = library.annotatedWith('<type-checker>');
    // logic
    buildStep.writeAsString('// Generated code', extension: '.lib.dart');
  }
}
```

### Registering Runtime Types

Since `LeanBuilder` does not relay on reflections, to use your runtime types with type checkers, you
need to register them first:

```dart
@LeanBuilder(registerTypes: {MyAnnotation})
class MyBuilder extends Builder {
  // ...
  @override
  FutureOr<void> build(BuildStep buildStep) async {
    final resolver = buildStep.resolver;
    final myAnnotationChecker = resolver.typeCheckerOf<MyAnnotation>();
    // Use the type checker in your build logic
  }
}
```

**Note**: Generic types of `GeneratorForAnnotation<Type>` and friends are automatically registered.

### Reading Constant Values

To read constant values from annotations, use the `ConstantReader` class:

```dart
void readConstantValues(ElementAnnotation elementAnnotation) {
    Constant constant = elementAnnotation.constant;
  
    if (constant is ConstString) {
      constant.value; // the String value
    }
  
    if (constant is ConstLiteral) {
      constant.literalValue; // the literal value of this constant
    }
  
    if (constant is ConstObject) {
      constant.props; // all the props of the object
      constant.getBool('boolKey')?.value; // ConstBool
      constant.getTypeRef('typeKey')?.value; // ConstType
      constant.getObject('NestedObjKey'); // ConstObject?;
      constant.get('constKey'); // Constant?;
    }
  
    if (constant is ConstList) {
      constant.value; // List<Constant>
      constant.literalValue; // List<dynamic>, dart values
    }
  
    if (constant is ConstFunctionReference) {
      constant.name; // the name of the function
      constant.type; // the type of the function
      constant.element; // the executable element of the function
    }
  }
  ``` 

### Advanced Type Checking

The `TypeChecker` provides a robust way to identify and compare types across libraries.

```dart
// Check for a specific type from a package
final myChecker = TypeChecker.typeNamed(MyType, inPackage: 'my_package');

// Check for deep assignability
if (myChecker.isAssignableFromType(someType)) {
  // logic
}

// Or use a URL-based check
final urlChecker = TypeChecker.fromUrl('package:my_package/src/models.dart#MyModel');
```

### Deep Element Model

Lean Builder provides a comprehensive element model that stays up-to-date with modern Dart features:
- **Class Modifiers**: Full support for `sealed`, `final`, `base`, and `interface` classes.
- **Modern Syntax**: Accurate resolution for `extension type`, `records`, and `mixins`.
- **Core Annotations**: Built-in awareness of `package:meta` annotations (e.g., `@internal`, `@protected`, `@visibleForTesting`).

### Using LeanBuilder directly inside of a project

LeanBuilder is designed to be used inside of generator packages and directly inside of a project.
To use `LeanBuilder` directly inside of a project, it's recommended that you put your generator code
inside a folder named `codegen` in same level as the `lib` folder. This
way, you'll be able to import from `dev_dependencies` with no linter warnings.

**Notes:**

- Do not name the folder other than `codegen` because the build system will only process the
  following folders: [`lib`, `bin`, `test`, `codegen`].
- Annotations used by the generator should be imported from your lib folder or other packages.

**More documentation:**
- [Testing Builders](docs/testing.md)