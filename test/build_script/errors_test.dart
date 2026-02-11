import 'package:lean_builder/src/build_script/errors.dart';
import 'package:test/test.dart';

void main() {
  group('BuildConfigError', () {
    test('should create error with message', () {
      final error = BuildConfigError('Invalid configuration');
      expect(error, isA<BuildScriptError>());
      expect(error, isA<Exception>());
    });

    test('should format message correctly', () {
      final error = BuildConfigError('Invalid configuration');
      expect(error.message, equals('Build configuration error\nInvalid configuration.'));
    });

    test('should have correct toString', () {
      final error = BuildConfigError('Invalid configuration');
      expect(error.toString(), equals('Build configuration error\nInvalid configuration.'));
    });
  });

  group('CompileError', () {
    test('should create error with message', () {
      final error = CompileError('Compilation failed');
      expect(error, isA<BuildScriptError>());
      expect(error, isA<Exception>());
    });

    test('should format message correctly', () {
      final error = CompileError('Compilation failed');
      expect(error.message, equals('Compilation failed.'));
    });

    test('should have correct toString', () {
      final error = CompileError('Compilation failed');
      expect(error.toString(), equals('Compilation failed.'));
    });
  });
}
