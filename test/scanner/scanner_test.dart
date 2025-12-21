import 'dart:typed_data';

import 'package:lean_builder/src/graph/directive_statement.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/graph/references_scanner.dart' show ReferencesScanner;
import 'package:lean_builder/test.dart';

import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';
import 'package:xxh3/xxh3.dart';

String idFor(String uriString) => xxh3String(Uint8List.fromList(uriString.codeUnits));

void main() {
  late ReferencesScanner scanner;
  late AssetsGraph assetsGraph;

  setUp(() {
    final fileResolver = getTestFileResolver();
    assetsGraph = AssetsGraph(fileResolver.packagesHash);
    scanner = ReferencesScanner(assetsGraph, fileResolver);
  });

  test('TopLevelScanner should scan a file with const variables', () {
    final StringAsset file = StringAsset('''
    String stringVar = 'string';
    const int _privateConst = 42;
    final int finalInt = 42;
    const kPi = 3.14159;
    const inferredConst = 3.14159;
    const List<String> constants = ['A', 'B'];
    const Map<int, List<int>> kValue = _kValue; 
    ''');
    scanner.scan(file);
    final List<List<Object>> expected = <List<Object>>[
      <Object>['_privateConst', file.id, ReferenceType.$variable.value],
      <Object>['kPi', file.id, ReferenceType.$variable.value],
      <Object>['inferredConst', file.id, ReferenceType.$variable.value],
      <Object>['constants', file.id, ReferenceType.$variable.value],
      <Object>['kValue', file.id, ReferenceType.$variable.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  test('TopLevelScanner should ignore commented out identifiers', () {
    final StringAsset file = StringAsset('''
    // constant kPi = 3.14159;
    // class Shape {}
    // void add(){}
    /* constant constInt = 42; */
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.isEmpty, true);
  });

  // member variables/methods should be ignored
  test('TopLevelScanner should ignore member variables and methods', () {
    final StringAsset file = StringAsset('''
    class MyClass {
      static constant privateInt = 42;
      final int finalInt = 42;
      late final String lateString;
      void privateMethod() {}
      int get getter => 42;
      set setter(int value) {}
      abstract void abstractMethod();
    }
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.length, 1);
  });

  test('TopLevelScanner should scan a file with enums', () {
    final StringAsset file = StringAsset('''
    enum Enum { red, green, blue }
    enum EnumWithImpl implements Logger { red, green, blue }
    ''');
    scanner.scan(file);
    final List<List<Object>> expected = <List<Object>>[
      <Object>['Enum', file.id, ReferenceType.$enum.value],
      <Object>['EnumWithImpl', file.id, ReferenceType.$enum.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  // typedef
  test('TopLevelScanner should scan a file with typedefs', () {
    final StringAsset file = StringAsset('''
    typedef JsonMap = Map<String, dynamic>;
    typedef Record = (String key, dynamic value);
    typedef Callback = void Function(String);
    typedef GenericCallback<T> = void Function(T);
    typedef GenericCallback2<T, U> = void Function(T, U);
    typedef bool ElementPredicate<E>(E element);
    typedef Future<int> TypeName();
    typedef void ConsumerCallback<T>(T value);
    typedef NullableMap = Map<String, String?>;
    typedef FunctionFactory = void Function() Function(String);
    typedef Comparable<T extends num> = int Function(T, T);
    typedef ComplexRecord = ({String name, int age, List<String>? hobbies});
    typedef KeyValuePair<K extends Comparable<K>, V> = MapEntry<K, V>;
    typedef OptionalParams = void Function(int required, [String? optional]);
    typedef NamedParams = void Function({required String name, int? age});
    typedef JsonProcessor = void Function(JsonMap data);
    typedef Transformer<T, U> = U Function(T Function(T) processor, T input);
    ''');
    scanner.scan(file);
    final List<List<Object>> expected = <List<Object>>[
      <Object>['JsonMap', file.id, ReferenceType.$typeAlias.value],
      <Object>['Record', file.id, ReferenceType.$typeAlias.value],
      <Object>['Callback', file.id, ReferenceType.$typeAlias.value],
      <Object>['GenericCallback', file.id, ReferenceType.$typeAlias.value],
      <Object>['GenericCallback2', file.id, ReferenceType.$typeAlias.value],
      <Object>['ElementPredicate', file.id, ReferenceType.$typeAlias.value],
      <Object>['TypeName', file.id, ReferenceType.$typeAlias.value],
      <Object>['ConsumerCallback', file.id, ReferenceType.$typeAlias.value],
      <Object>['NullableMap', file.id, ReferenceType.$typeAlias.value],
      <Object>['FunctionFactory', file.id, ReferenceType.$typeAlias.value],
      <Object>['Comparable', file.id, ReferenceType.$typeAlias.value],
      <Object>['ComplexRecord', file.id, ReferenceType.$typeAlias.value],
      <Object>['KeyValuePair', file.id, ReferenceType.$typeAlias.value],
      <Object>['OptionalParams', file.id, ReferenceType.$typeAlias.value],
      <Object>['NamedParams', file.id, ReferenceType.$typeAlias.value],
      <Object>['JsonProcessor', file.id, ReferenceType.$typeAlias.value],
      <Object>['Transformer', file.id, ReferenceType.$typeAlias.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  test('TopLevelScanner should scan a file with extensions', () {
    final StringAsset file = StringAsset('''
    extension StringExt on String {}
    extension ListExt<S> on List<S> {}
    extension type const TypeExt(double? offset) {}
    extension type TypeExt2(double? offset) {}
    ''');
    scanner.scan(file);
    final List<List<Object>> expected = <List<Object>>[
      <Object>['StringExt', file.id, ReferenceType.$extension.value],
      <Object>['ListExt', file.id, ReferenceType.$extension.value],
      <Object>['TypeExt', file.id, ReferenceType.$extension.value],
      <Object>['TypeExt2', file.id, ReferenceType.$extension.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  test('TopLevelScanner should scan a file with mixins', () {
    final StringAsset file = StringAsset('''
    mixin Logger {
      void log(String msg) {}
    }
    mixin Logger2 on Logger {
      void log2(String msg) {}
    }
    ''');
    scanner.scan(file);
    final List<List<Object>> expected = <List<Object>>[
      <Object>['Logger', file.id, ReferenceType.$mixin.value],
      <Object>['Logger2', file.id, ReferenceType.$mixin.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  test('TopLevelScanner should scan a file with classes', () {
    final StringAsset file = StringAsset('''
      class Shape {
       void draw() {}
       }
      class Rectangle extends Shape {}
      class Box<T> implements Shape {}
      class Boxes<List<T> with Shape {}
      abstract class AbstractShape {}
      final class FinalShape {}
      interface class Shape2 {}
      sealed class Shape3 {}
      base class Shape4 {}
      mixin class GenericMixin<T> {}
      class AliasedClass<T> = GenericClass<T> with GenericMixin<T>;
    ''');
    scanner.scan(file);
    final List<List<Object>> expected = <List<Object>>[
      <Object>['Shape', file.id, ReferenceType.$class.value],
      <Object>['Rectangle', file.id, ReferenceType.$class.value],
      <Object>['Box', file.id, ReferenceType.$class.value],
      <Object>['Boxes', file.id, ReferenceType.$class.value],
      <Object>['AbstractShape', file.id, ReferenceType.$class.value],
      <Object>['FinalShape', file.id, ReferenceType.$class.value],
      <Object>['Shape2', file.id, ReferenceType.$class.value],
      <Object>['Shape3', file.id, ReferenceType.$class.value],
      <Object>['Shape4', file.id, ReferenceType.$class.value],
      <Object>['GenericMixin', file.id, ReferenceType.$class.value],
      <Object>['AliasedClass', file.id, ReferenceType.$class.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  // functions
  test('TopLevelScanner should scan a file with functions', () {
    final StringAsset file = StringAsset('''
    noReturn() {}
    void printMsg(String message) {}
    int add(int a, int b) => a + b;
    void configure({required String apiKey}) {}
    List<int> getRange(int start, [int end = 10]) => [];
    List<Set<T>> nestedList<T>(Mix<T> list) => [];
    T identity<T>(T value) => value;
    Future<String> fetchData() async => '';
    Stream<int> countStream(int max) async* {
      yield 1;
    }
    Future<void> runTests(List<String> args) async {}
    bool codeUnitForDigit(int digit) => digit < 10;
    Future<List<Map<String, dynamic>>> processSourceReport() async => [];
 ''');

    scanner.scan(file);
    final List<List<Object>> expected = <List<Object>>[
      <Object>['noReturn', file.id, ReferenceType.$function.value],
      <Object>['printMsg', file.id, ReferenceType.$function.value],
      <Object>['add', file.id, ReferenceType.$function.value],
      <Object>['configure', file.id, ReferenceType.$function.value],
      <Object>['getRange', file.id, ReferenceType.$function.value],
      <Object>['nestedList', file.id, ReferenceType.$function.value],
      <Object>['identity', file.id, ReferenceType.$function.value],
      <Object>['fetchData', file.id, ReferenceType.$function.value],
      <Object>['countStream', file.id, ReferenceType.$function.value],
      <Object>['runTests', file.id, ReferenceType.$function.value],
      <Object>['codeUnitForDigit', file.id, ReferenceType.$function.value],
      <Object>['processSourceReport', file.id, ReferenceType.$function.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  test('TopLevelScanner should scan advanced function syntax variants', () {
    final StringAsset file = StringAsset('''
        Iterable<int> syncGenerator(int max) sync* {
          for (int i = 0; i < max; i++) {
            yield i;
          }
         }
        external void nativeFunction();
        Map<K, List<V>> groupBy<K, V>(List<V> items, K Function(V item) keySelector) => {};
        Future<List<Map<String, List<int>>>> processComplexData() async => [];
        int Function(int) makeAdder(int addBy) => (int a) => a + addBy;
        T operator <T>(T other) => other;
        int? nullableReturn() => null;
        void functionWithRecords((String, int) record) {}
        (String, int) returnRecord() => ('hello', 42);
        ({String name, int age}) namedRecord({String name = '', int age = 0}) => (name: name, age: age);
  ''');

    scanner.scan(file);
    final List<List<Object>> expected = <List<Object>>[
      <Object>['syncGenerator', file.id, ReferenceType.$function.value],
      <Object>['nativeFunction', file.id, ReferenceType.$function.value],
      <Object>['groupBy', file.id, ReferenceType.$function.value],
      <Object>['processComplexData', file.id, ReferenceType.$function.value],
      <Object>['makeAdder', file.id, ReferenceType.$function.value],
      <Object>['operator', file.id, ReferenceType.$function.value],
      <Object>['nullableReturn', file.id, ReferenceType.$function.value],
      <Object>['functionWithRecords', file.id, ReferenceType.$function.value],
      <Object>['returnRecord', file.id, ReferenceType.$function.value],
      <Object>['namedRecord', file.id, ReferenceType.$function.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  test('Should parse simple import', () {
    final StringAsset src = StringAsset("import 'package:test_/path.dart';");
    scanner.scan(src);
    final List<List<dynamic>> imports = assetsGraph.importsOf(src.id);
    expect(imports.length, 1);
    final List<dynamic> importArr = imports.first;
    expect(importArr, <Object?>[
      DirectiveStatement.import,
      idFor('package:test_/path.dart'),
      'package:test_/path.dart',
      null,
      null,
    ]);
  });

  test('Should parse simple import with alias', () {
    final StringAsset file = StringAsset(
      "import 'package:test_/path.dart' as i;",
    );
    scanner.scan(file);
    final List<List<dynamic>> imports = assetsGraph.importsOf(file.id);
    expect(imports.length, 1);
    expect(imports.first, <Object?>[
      DirectiveStatement.import,
      idFor('package:test_/path.dart'),
      'package:test_/path.dart',
      null,
      null,
      'i',
    ]);
  });

  test('Should parse simple deferred import', () {
    final StringAsset file = StringAsset(
      "import 'package:test_/path.dart' deferred as i;",
      fileName: 'package:test_/path.dart',
    );
    scanner.scan(file);
    final List<List<dynamic>> imports = assetsGraph.importsOf(file.id);
    expect(imports.length, 1);
    expect(imports.first, <Object?>[
      DirectiveStatement.import,
      idFor('package:test_/path.dart'),
      'package:test_/path.dart',
      null,
      null,
      'i',
      1,
    ]);
  });

  test('Should parse simple import with show', () {
    final StringAsset asset = StringAsset(
      "import 'package:test_/path.dart' show A, B;",
    );
    scanner.scan(asset);
    final List<List<dynamic>> imports = assetsGraph.importsOf(asset.id);
    expect(imports.length, 1);
    expect(imports.first, <Object?>[
      DirectiveStatement.import,
      idFor('package:test_/path.dart'),
      'package:test_/path.dart',
      <String>['A', 'B'],
      null,
    ]);
  });

  test('Should parse simple import with hide', () {
    final StringAsset asset = StringAsset(
      "import 'package:test_/path.dart' hide A, B;",
    );
    scanner.scan(asset);
    final List<List<dynamic>> imports = assetsGraph.importsOf(asset.id);
    expect(imports.first, <Object?>[
      DirectiveStatement.import,
      idFor('package:test_/path.dart'),
      'package:test_/path.dart',
      null,
      <String>['A', 'B'],
    ]);
  });

  test('Should parse simple import with show and hide', () {
    final StringAsset file = StringAsset(
      "import 'package:test_/path.dart' show A, B hide C, D;",
    );
    scanner.scan(file);
    final List<List<dynamic>> imports = assetsGraph.importsOf(file.id);
    expect(imports.length, 1);
    expect(imports.first, <Object>[
      DirectiveStatement.import,
      idFor('package:test_/path.dart'),
      'package:test_/path.dart',
      <String>['A', 'B'],
      <String>['C', 'D'],
    ]);
  });

  test('Should parse simple export', () {
    final StringAsset file = StringAsset("export 'package:test_/path.dart';");
    scanner.scan(file);
    final List<List<dynamic>> exports = assetsGraph.exportsOf(file.id);
    expect(exports.first, <Object?>[
      DirectiveStatement.export,
      idFor('package:test_/path.dart'),
      'package:test_/path.dart',
      null,
      null,
    ]);
  });

  test('Should parse simple export with show', () {
    final StringAsset file = StringAsset(
      "export 'package:test_/path.dart' show A, B;",
      fileName: 'package:test_/path.dart',
    );
    scanner.scan(file);
    final List<List<dynamic>> exports = assetsGraph.exportsOf(file.id);
    expect(exports.first, <Object?>[
      DirectiveStatement.export,
      idFor('package:test_/path.dart'),
      'package:test_/path.dart',
      <String>['A', 'B'],
      null,
    ]);
  });

  test('Should parse simple export with hide', () {
    final StringAsset file = StringAsset(
      "export 'package:test_/path.dart' hide A, B;",
      fileName: 'package:test_/path.dart',
    );
    scanner.scan(file);
    final List<List<dynamic>> exports = assetsGraph.exportsOf(file.id);
    expect(exports.first, <Object?>[
      DirectiveStatement.export,
      idFor('package:test_/path.dart'),
      'package:test_/path.dart',
      null,
      <String>['A', 'B'],
    ]);
  });

  test('Should parse simple export with show and hide', () {
    final StringAsset file = StringAsset(
      "export 'package:test_/path.dart' show A, B hide C, D;",
      fileName: 'package:test_/path.dart',
    );
    scanner.scan(file);
    final List<List<dynamic>> exports = assetsGraph.exportsOf(file.id);
    expect(exports.first, <Object>[
      DirectiveStatement.export,
      idFor('package:test_/path.dart'),
      'package:test_/path.dart',
      <String>['A', 'B'],
      <String>['C', 'D'],
    ]);
  });

  test('Should parse simple part', () {
    final StringAsset file = StringAsset("part 'package:test_/path.dart';");
    scanner.scan(file);
    final List<List<dynamic>> imports = assetsGraph.importsOf(file.id);
    final List<List<dynamic>> exports = assetsGraph.exportsOf(file.id);
    final List<List<dynamic>> parts = assetsGraph.partsOf(file.id);
    expect(imports.first, <Object?>[
      DirectiveStatement.part,
      idFor('package:test_/path.dart'),
      'package:test_/path.dart',
      null,
      null,
    ]);
    expect(exports.first, <Object?>[
      DirectiveStatement.part,
      idFor('package:test_/path.dart'),
      'package:test_/path.dart',
      null,
      null,
    ]);
    expect(parts.first, <Object?>[
      DirectiveStatement.part,
      idFor('package:test_/path.dart'),
      'package:test_/path.dart',
      null,
      null,
    ]);
  });

  test('Should parse part of', () {
    final StringAsset asset = StringAsset(
      "part of 'path.dart';",
      fileName: 'path2.dart',
    );
    scanner.scan(asset);
    print(assetsGraph.directives);
    expect(assetsGraph.partOfOf(asset.id), isNotNull);
  });

  test('TopLevelScanner should detect class annotation', () {
    final StringAsset asset = StringAsset('''
      @Annotation()
      class MyClass {}
    ''');
    scanner.scan(asset);
    expect(assetsGraph.identifiers.first, <Object>[
      'MyClass',
      asset.id,
      ReferenceType.$class.value,
    ]);
    expect(assetsGraph.assets[asset.id]?[2], 1);
  });

  test('TopLevelScanner should detect class annotation with arguments', () {
    final StringAsset file = StringAsset('''
      @Annotation('arg1', arg2: 42)
      class MyClass {}
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, <Object>[
      'MyClass',
      file.id,
      ReferenceType.$class.value,
    ]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect class annotation with constant var', () {
    final StringAsset file = StringAsset('''
      @annotation
      class MyClass {}
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, <Object>[
      'MyClass',
      file.id,
      ReferenceType.$class.value,
    ]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect const var annotation', () {
    final StringAsset file = StringAsset('''
      @Annotation()
      const myVar = 42;
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, <Object>[
      'myVar',
      file.id,
      ReferenceType.$variable.value,
    ]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect const var annotation', () {
    final StringAsset file = StringAsset('''
      @Annotation.named()
      const myVar = 42;
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, <Object>[
      'myVar',
      file.id,
      ReferenceType.$variable.value,
    ]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test(
    'TopLevelScanner should detect class annotated with import-prefixed annotation',
    () {
      final StringAsset file = StringAsset('''
      @prefix.Annotation()
      @prefix.Annotation.named()
      class MyClass {}
    ''');
      scanner.scan(file);
      expect(assetsGraph.identifiers.first, <Object>[
        'MyClass',
        file.id,
        ReferenceType.$class.value,
      ]);
      expect(assetsGraph.assets[file.id]?[2], 1);
    },
  );

  test('TopLevelScanner should detect multiple annotations', () {
    final StringAsset file = StringAsset('''
      @Annotation1()
      @Annotation2()
      class MyClass {}
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, <Object>[
      'MyClass',
      file.id,
      ReferenceType.$class.value,
    ]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  // function annotation
  test('TopLevelScanner should detect function annotation', () {
    final StringAsset file = StringAsset('''
      @Annotation()
      @Annotation.named()
      @annotation
      void myFunction() {}
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, <Object>[
      'myFunction',
      file.id,
      ReferenceType.$function.value,
    ]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test(
    'TopLevelScanner should ignore field, method, any class member annotation',
    () {
      final StringAsset file = StringAsset('''
      class MyClass {
        @Annotation()
        int myField = 42;
        @Annotation()
        void myMethod() {}
      }
    ''');
      scanner.scan(file);
      expect(assetsGraph.identifiers.first, <Object>[
        'MyClass',
        file.id,
        ReferenceType.$class.value,
      ]);
      expect(assetsGraph.assets[file.id]?[2], 0);
    },
  );

  test('TopLevelScanner should ignore top functions parameter annotation', () {
    final StringAsset file = StringAsset('''
      void myFunction(@Annotation() int arg) {}
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, <Object>[
      'myFunction',
      file.id,
      ReferenceType.$function.value,
    ]);
    expect(assetsGraph.assets[file.id]?[2], 0);
  });
}
