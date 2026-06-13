import 'package:lean_builder/builder.dart';
import 'package:lean_builder/src/element/element.dart';
import 'package:lean_builder/src/graph/references_scanner.dart';
import 'package:lean_builder/src/resolvers/constant/constant.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/type/type.dart';
import 'package:lean_builder/test.dart';
import 'package:test/test.dart';

void main() {
  late PackageFileResolver fileResolver;
  ReferencesScanner? scanner;
  ResolverImpl? resolver;

  setUpAll(() {
    fileResolver = getTestFileResolver();
  });

  setUp(() {
    final AssetsGraph graph = AssetsGraph('hash');
    scanner = ReferencesScanner(graph, fileResolver);
    resolver = ResolverImpl(graph, fileResolver, SourceParser());
  });

  test('should resolve simple class element', () {
    final StringAsset asset = StringAsset('class Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    expect(library.getClass('Foo'), isNotNull);
  });

  test('should resolve abstract class element', () {
    final StringAsset asset = StringAsset('abstract class Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.name, 'Foo');
    expect(classElement.hasAbstract, isTrue);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.hasSealedKeyword, isFalse);
    expect(classElement.isConstructable, isFalse);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve final class element', () {
    final StringAsset asset = StringAsset('final class Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.hasAbstract, isFalse);
    expect(classElement.hasFinal, isTrue);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.hasSealedKeyword, isFalse);
    expect(classElement.isConstructable, isTrue);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve base class element', () {
    final StringAsset asset = StringAsset('base class Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.hasAbstract, isFalse);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isTrue);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.hasSealedKeyword, isFalse);
    expect(classElement.isConstructable, isTrue);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve interface class element', () {
    final StringAsset asset = StringAsset('interface class Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.hasAbstract, isFalse);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isTrue);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.hasSealedKeyword, isFalse);
    expect(classElement.isConstructable, isTrue);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve mixin class element', () {
    final StringAsset asset = StringAsset('mixin class Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.hasAbstract, isFalse);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, isTrue);
    expect(classElement.hasSealedKeyword, isFalse);
    expect(classElement.isConstructable, isTrue);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve sealed class element', () {
    final StringAsset asset = StringAsset('sealed class Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.hasAbstract, isFalse);
    expect(classElement.hasSealedKeyword, isTrue);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.isConstructable, isFalse);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve mixin application class element', () {
    final StringAsset asset = StringAsset('''
        class Bar {}
        mixin Baz {}
        class Foo = Bar with Baz;
    ''');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.hasSealedKeyword, isFalse);
    expect(classElement.hasAbstract, isFalse);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.isConstructable, isTrue);
    expect(classElement.isMixinApplication, isTrue);
  });

  test('should resolve abstract interface class element', () {
    final StringAsset asset = StringAsset('abstract interface class Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.name, 'Foo');
    expect(classElement.hasAbstract, isTrue);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isTrue);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.hasSealedKeyword, isFalse);
    expect(classElement.isConstructable, isFalse);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve abstract final class element', () {
    final StringAsset asset = StringAsset('abstract final class Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.name, 'Foo');
    expect(classElement.hasAbstract, isTrue);
    expect(classElement.hasFinal, isTrue);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.hasSealedKeyword, isFalse);
    expect(classElement.isConstructable, isFalse);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve abstract mixin class element', () {
    final StringAsset asset = StringAsset('abstract mixin class Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.name, 'Foo');
    expect(classElement.hasAbstract, isTrue);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, true);
    expect(classElement.hasSealedKeyword, false);
    expect(classElement.isConstructable, false);
    expect(classElement.isMixinApplication, false);
  });

  test('should resolve class with super class', () {
    final StringAsset asset = StringAsset('''
        class Bar {}
        class Foo extends Bar {}
    ''');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.superType, library.getClass('Bar')!.thisType);
  });

  test('should resolve class with super interfaces', () {
    final StringAsset asset = StringAsset('''
         class Bar {}
         class Baz {}
         class Foo implements Bar, Baz {}
    ''');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.interfaces, <InterfaceType>[
      library.getClass('Bar')!.thisType,
      library.getClass('Baz')!.thisType,
    ]);
  });

  test('should resolve class with mixins', () {
    final StringAsset asset = StringAsset('''
        mixin Bar {}
        mixin Baz {}
        class Foo with Bar, Baz {}
    ''');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.mixins, <InterfaceType>[
      library.getMixin('Bar')!.thisType,
      library.getMixin('Baz')!.thisType,
    ]);
  });

  test('should resolve const defaults with private field-formal params', () {
    final StringAsset asset = StringAsset('''
    class Foo {
      final String _arg;
      const Foo({required this._arg});
    }
    ''');

    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    final constructor = classElement!.constructors.first;
    final argParam = constructor.getParameter('arg');
    expect(argParam, isNotNull);
    final argField = classElement.getField('_arg');
    expect(argField, isNotNull);
  });

  test('should resolve direct const construction with private field-formal params', () {
    final StringAsset asset = StringAsset('''
   class Foo {
    final String _arg;
    const Foo({required this._arg = 'direct'});
  }
    ''');

    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final ClassElementImpl? fooClass = library.getClass('Foo');
    expect(fooClass, isNotNull);
    final fooConstructor = fooClass!.constructors.first;
    final publicParameter = fooConstructor.getParameter('arg');
    expect(publicParameter, isNotNull);
    expect(fooConstructor.getParameter('_arg'), isNull);
    expect(publicParameter!.defaultValueCode, "'direct'");
    expect(publicParameter.constantValue, isA<ConstString>());
  });

  test('should resolve nested const instance default for private field-formal param', () {
    final StringAsset asset = StringAsset('''
      class Foo {
        final String _arg;
        const Foo({this._arg = 'default'});
      }

      class Bar {
        final Foo _foo;
        const Bar({this._foo = const Foo(arg: 'nested_default')});
      }
    ''');

    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    
    final ClassElementImpl? barClass = library.getClass('Bar');
    expect(barClass, isNotNull);
    
    final barConstructor = barClass!.constructors.first;
    
    // The parameter should be exposed as 'foo', not '_foo'
    final fooParam = barConstructor.getParameter('foo');
    expect(fooParam, isNotNull);
    expect(barConstructor.getParameter('_foo'), isNull);
    
    // Verify the default value is a constant object
    final defaultValue = fooParam!.constantValue;
    expect(defaultValue, isA<ConstObject>());
    
    final constObj = defaultValue as ConstObject;
    expect(constObj.type.name, 'Foo');
    
    // The nested property should be accessible via the actual field name '_arg'
    final argValue = constObj.getString('_arg');
    expect(argValue, isNotNull);
    expect(argValue!.value, 'nested_default');
  });

  test('should resolve multiple private field-formal params with const defaults', () {
    final StringAsset asset = StringAsset('''
      class Config {
        final int _timeout;
        final String _url;
        const Config({this._timeout = 30, this._url = 'https://example.com'});
      }

      class Service {
        final Config _config;
        const Service({this._config = const Config(timeout: 60, url: 'https://api.example.com')});
      }
    ''');

    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    
    final ClassElementImpl? serviceClass = library.getClass('Service');
    expect(serviceClass, isNotNull);
    
    final serviceConstructor = serviceClass!.constructors.first;
    
    final configParam = serviceConstructor.getParameter('config');
    expect(configParam, isNotNull);
    expect(serviceConstructor.getParameter('_config'), isNull);
    
    final defaultValue = configParam!.constantValue;
    expect(defaultValue, isA<ConstObject>());
    
    final constObj = defaultValue as ConstObject;
    expect(constObj.type.name, 'Config');
    
    // Properties should be keyed by actual field names
    expect(constObj.getInt('_timeout')?.value, 60);
    expect(constObj.getString('_url')?.value, 'https://api.example.com');
  });
}
