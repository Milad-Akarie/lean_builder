import 'package:lean_builder/src/builder/errors.dart';
import 'package:lean_builder/test.dart';
import 'package:test/test.dart';

void main() {
  group('InvalidGenerationSourceError', () {
    test('should create error with message only', () {
      const message = 'Invalid annotation usage';
      final error = InvalidGenerationSourceError(message);

      expect(error.message, equals(message));
      expect(error.todo, isEmpty);
      expect(error.element, isNull);
      expect(error.node, isNull);
      expect(error.toString(), equals(message));
    });

    test('should create error with message and todo', () {
      const message = 'Invalid annotation usage';
      const todo = 'Add @override annotation';
      final error = InvalidGenerationSourceError(
        message,
        todo: todo,
      );

      expect(error.message, equals(message));
      expect(error.todo, equals(todo));
      expect(error.element, isNull);
      expect(error.node, isNull);
    });

    test('should create error with element', () {
      const source = '''
class MyClass {
  String myField = 'value';
}
''';

      final buildStep = buildStepForTestContent(source);
      final library = buildStep.library;
      final myClass = library.getClass('MyClass')!;
      final myField = myClass.getField('myField')!;

      final error = InvalidGenerationSourceError(
        'Field error',
        element: myField,
      );

      expect(error.message, equals('Field error'));
      expect(error.element, equals(myField));
      expect(error.node, isNull);

      // The toString should include element information
      final errorString = error.toString();
      expect(errorString, contains('Field error'));
      // Should contain element name or type information
      expect(errorString, contains('myField'));
    });

    test('should format error with multiple components', () {
      const source = '''
class TestClass {
  int value = 42;
}
''';

      final buildStep = buildStepForTestContent(source);
      final library = buildStep.library;
      final testClass = library.getClass('TestClass')!;
      final field = testClass.getField('value')!;

      final error = InvalidGenerationSourceError(
        'Invalid field type',
        todo: 'Change type to String',
        element: field,
      );

      expect(error.message, equals('Invalid field type'));
      expect(error.todo, equals('Change type to String'));
      expect(error.element, isNotNull);

      final errorString = error.toString();
      expect(errorString, contains('Invalid field type'));
    });

    test('should handle element without valid source location', () {
      const source = '''
class MyClass {
  int value = 0;
}
''';

      final buildStep = buildStepForTestContent(source);
      final library = buildStep.library;
      final myClass = library.getClass('MyClass')!;

      final error = InvalidGenerationSourceError(
        'Class error',
        element: myClass,
      );

      expect(error.message, equals('Class error'));
      expect(error.element, equals(myClass));

      // Should not throw when converting to string
      final errorString = error.toString();
      expect(errorString, contains('Class error'));
    });
  });

  group('spanForElement', () {
    test('should create span for class element', () {
      const source = '''
class MyClass {
  int value = 0;
}
''';

      final buildStep = buildStepForTestContent(source);
      final library = buildStep.library;
      final myClass = library.getClass('MyClass')!;

      final span = spanForElement(myClass);
      expect(span, isNotNull);
      expect(span.text, contains('MyClass'));
    });

    test('should create span for field element', () {
      const source = '''
class MyClass {
  String myField = 'test';
}
''';

      final buildStep = buildStepForTestContent(source);
      final library = buildStep.library;
      final myClass = library.getClass('MyClass')!;
      final field = myClass.getField('myField')!;

      final span = spanForElement(field);
      expect(span, isNotNull);
      expect(span.text, contains('myField'));
    });

    test('should create span for method element', () {
      const source = '''
class MyClass {
  void myMethod() {}
}
''';

      final buildStep = buildStepForTestContent(source);
      final library = buildStep.library;
      final myClass = library.getClass('MyClass')!;
      final method = myClass.getMethod('myMethod')!;

      final span = spanForElement(method);
      expect(span, isNotNull);
      expect(span.text, contains('myMethod'));
    });

    test('should create span for constructor element', () {
      const source = '''
class MyClass {
  MyClass();
}
''';

      final buildStep = buildStepForTestContent(source);
      final library = buildStep.library;
      final myClass = library.getClass('MyClass')!;
      final constructor = myClass.constructors.first;

      final span = spanForElement(constructor);
      expect(span, isNotNull);
      expect(span.text, contains('MyClass'));
    });
  });
}
