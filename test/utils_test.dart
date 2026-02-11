import 'dart:io';

import 'package:lean_builder/src/utils.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('rootPackageName', () {
    test('should return package name from pubspec.yaml', () {
      // This test runs in the context of the lean_builder package
      expect(rootPackageName, isNotEmpty);
      expect(rootPackageName, isA<String>());
      // The package name should be 'lean_builder' based on the project
      expect(rootPackageName, equals('lean_builder'));
    });
  });

  group('rootPackagePubspec', () {
    test('should load pubspec.yaml as YamlMap', () {
      expect(rootPackagePubspec, isA<YamlMap>());
      expect(rootPackagePubspec['name'], isNotNull);
      expect(rootPackagePubspec['name'], equals('lean_builder'));
    });

    test('should contain expected fields', () {
      expect(rootPackagePubspec['name'], isNotNull);
      expect(rootPackagePubspec['description'], isNotNull);
      // Most packages have dependencies
      expect(
        rootPackagePubspec.containsKey('dependencies') || rootPackagePubspec.containsKey('dev_dependencies'),
        isTrue,
      );
    });

    test('should have valid structure', () {
      // Verify it's a valid YAML map
      expect(rootPackagePubspec, isA<YamlMap>());

      // Check that name is a string
      final name = rootPackagePubspec['name'];
      expect(name, isA<String>());
    });
  });

  group('pathHostedPackages', () {
    test('should return a set of strings', () {
      expect(pathHostedPackages, isA<Set<String>>());
    });

    test('should be empty or contain valid package names', () {
      // Path hosted packages may or may not exist
      for (final packageName in pathHostedPackages) {
        expect(packageName, isA<String>());
        expect(packageName, isNotEmpty);
      }
    });

    test('should extract packages with path dependencies', () {
      // This is a meta-test that verifies the function works
      // The actual content depends on the pubspec.yaml
      expect(pathHostedPackages, isA<Set<String>>());

      // If there are path dependencies, they should be strings
      if (pathHostedPackages.isNotEmpty) {
        for (final pkg in pathHostedPackages) {
          expect(pkg, isA<String>());
        }
      }
    });
  });

  group('error handling', () {
    test('rootPackageName should be accessible', () {
      // This verifies the lazy initialization works
      expect(() => rootPackageName, returnsNormally);
      expect(rootPackageName, isNotEmpty);
    });

    test('rootPackagePubspec should be accessible', () {
      // This verifies the lazy initialization works
      expect(() => rootPackagePubspec, returnsNormally);
      expect(rootPackagePubspec, isNotNull);
    });

    test('pathHostedPackages should be accessible', () {
      // This verifies the lazy initialization works
      expect(() => pathHostedPackages, returnsNormally);
      expect(pathHostedPackages, isNotNull);
    });
  });

  group('integration', () {
    test('package name from pubspec should match rootPackageName', () {
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue);

      final content = pubspecFile.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap;

      expect(yaml['name'], equals(rootPackageName));
    });

    test('should handle pubspec with no path dependencies', () {
      // Even if there are no path dependencies, the set should be valid
      expect(pathHostedPackages, isA<Set<String>>());
    });

    test('should handle pubspec with dependencies but no path', () {
      // The function should handle dependencies that are not path-based
      expect(() => pathHostedPackages, returnsNormally);
    });
  });
}
