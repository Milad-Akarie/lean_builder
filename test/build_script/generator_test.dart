import 'package:lean_builder/src/build_script/generator.dart';
import 'package:lean_builder/src/build_script/parsed_builder_entry.dart';
import 'package:test/test.dart';

void main() {
  group('generateBuildScript', () {
    test('should generate basic build script with single entry', () {
      final entries = [
        BuilderDefinitionEntry(
          key: 'test_builder',
          import: 'package:test/test.dart',
          generatorName: 'TestGenerator',
          builderType: BuilderType.shared,
          expectsOptions: false,
        ),
      ];

      final result = generateBuildScript(entries);

      expect(result, contains('// This is an auto-generated build script.'));
      expect(result, contains('// Do not modify by hand.'));
      expect(result, contains('import \'dart:isolate\' as'));
      expect(result, contains('import \'package:lean_builder/runner.dart\' as'));
      expect(result, contains('import \'package:test/test.dart\' as'));
      expect(result, contains('final _builders ='));
      expect(result, contains('.forSharedPart('));
      expect(result, contains('\'test_builder\''));
      expect(result, contains('void main(List<String> args'));
    });

    test('should generate build script with library builder', () {
      final entries = [
        BuilderDefinitionEntry(
          key: 'lib_builder',
          import: 'package:test/lib.dart',
          generatorName: 'LibGenerator',
          builderType: BuilderType.library,
          expectsOptions: true,
          outputExtensions: {'.g.dart'},
        ),
      ];

      final result = generateBuildScript(entries);

      expect(result, contains('.forLibrary('));
      expect(result, contains('outputExtensions'));
      expect(result, contains('\'.g.dart\''));
      expect(result, contains('LibGenerator.new'));
    });

    test('should generate build script with custom builder', () {
      final entries = [
        BuilderDefinitionEntry(
          key: 'custom_builder',
          import: 'package:test/custom.dart',
          generatorName: 'CustomGenerator',
          builderType: BuilderType.custom,
          expectsOptions: false,
        ),
      ];

      final result = generateBuildScript(entries);

      expect(result, contains('BuilderEntry\n('));
      expect(result, contains('(_)=> '));
    });

    test('should generate build script with registered types', () {
      final entries = [
        BuilderDefinitionEntry(
          key: 'typed_builder',
          import: 'package:test/typed.dart',
          generatorName: 'TypedGenerator',
          builderType: BuilderType.shared,
          expectsOptions: false,
          registeredTypes: [
            RuntimeTypeRegisterEntry('MyType', 'package:test/types.dart', 'my_type_id'),
          ],
        ),
      ];

      final result = generateBuildScript(entries);

      expect(result, contains('registeredTypes:'));
      expect(result, contains('MyType'));
      expect(result, contains('my_type_id'));
    });

    test('should generate build script with generateToCache option', () {
      final entries = [
        BuilderDefinitionEntry(
          key: 'cache_builder',
          import: 'package:test/cache.dart',
          generatorName: 'CacheGenerator',
          builderType: BuilderType.shared,
          expectsOptions: false,
          generateToCache: true,
        ),
      ];

      final result = generateBuildScript(entries);

      expect(result, contains('generateToCache: true'));
    });

    test('should generate build script with allowSyntaxErrors option', () {
      final entries = [
        BuilderDefinitionEntry(
          key: 'error_builder',
          import: 'package:test/error.dart',
          generatorName: 'ErrorGenerator',
          builderType: BuilderType.shared,
          expectsOptions: false,
          allowSyntaxErrors: true,
        ),
      ];

      final result = generateBuildScript(entries);

      expect(result, contains('allowSyntaxErrors: true'));
    });

    test('should generate build script with generateFor option', () {
      final entries = [
        BuilderDefinitionEntry(
          key: 'filter_builder',
          import: 'package:test/filter.dart',
          generatorName: 'FilterGenerator',
          builderType: BuilderType.shared,
          expectsOptions: false,
          generateFor: {'lib/**/*.dart'},
        ),
      ];

      final result = generateBuildScript(entries);

      expect(result, contains('generateFor:'));
      expect(result, contains('lib/**/*.dart'));
    });

    test('should generate build script with runsBefore option', () {
      final entries = [
        BuilderDefinitionEntry(
          key: 'before_builder',
          import: 'package:test/before.dart',
          generatorName: 'BeforeGenerator',
          builderType: BuilderType.shared,
          expectsOptions: false,
          runsBefore: {'other_builder'},
        ),
      ];

      final result = generateBuildScript(entries);

      expect(result, contains('runsBefore:'));
      expect(result, contains('other_builder'));
    });

    test('should generate build script with applies option', () {
      final entries = [
        BuilderDefinitionEntry(
          key: 'applies_builder',
          import: 'package:test/applies.dart',
          generatorName: 'AppliesGenerator',
          builderType: BuilderType.shared,
          expectsOptions: false,
          applies: {'*.dart'},
        ),
      ];

      final result = generateBuildScript(entries);

      expect(result, contains('applies:'));
      expect(result, contains('*.dart'));
    });

    test('should generate build script with options', () {
      final entries = [
        BuilderDefinitionEntry(
          key: 'options_builder',
          import: 'package:test/options.dart',
          generatorName: 'OptionsGenerator',
          builderType: BuilderType.shared,
          expectsOptions: false,
          options: {'key1': 'value1', 'key2': 42},
        ),
      ];

      final result = generateBuildScript(entries);

      expect(result, contains('options:'));
    });

    test('should generate build script with multiple entries', () {
      final entries = [
        BuilderDefinitionEntry(
          key: 'builder1',
          import: 'package:test/builder1.dart',
          generatorName: 'Generator1',
          builderType: BuilderType.shared,
          expectsOptions: false,
        ),
        BuilderDefinitionEntry(
          key: 'builder2',
          import: 'package:test/builder2.dart',
          generatorName: 'Generator2',
          builderType: BuilderType.library,
          expectsOptions: true,
          outputExtensions: {'.g.dart'},
        ),
      ];

      final result = generateBuildScript(entries);

      expect(result, contains('builder1'));
      expect(result, contains('builder2'));
      expect(result, contains('Generator1'));
      expect(result, contains('Generator2'));
    });

    test('should reuse import prefixes for same imports', () {
      final entries = [
        BuilderDefinitionEntry(
          key: 'builder1',
          import: 'package:test/same.dart',
          generatorName: 'Generator1',
          builderType: BuilderType.shared,
          expectsOptions: false,
        ),
        BuilderDefinitionEntry(
          key: 'builder2',
          import: 'package:test/same.dart',
          generatorName: 'Generator2',
          builderType: BuilderType.shared,
          expectsOptions: false,
        ),
      ];

      final result = generateBuildScript(entries);

      // Should only import once
      final importCount = 'import \'package:test/same.dart\''.allMatches(result).length;
      expect(importCount, equals(1));
    });
  });
}
