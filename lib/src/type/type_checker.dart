import 'dart:typed_data' show Uint8List;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/graph/declaration_ref.dart';
import 'package:lean_builder/src/resolvers/errors.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/type/type.dart';
import 'package:xxh3/xxh3.dart' show xxh3String;

import '../element/element.dart';

/// {@template type_checker}
/// An abstraction around doing static type checking at compile/build time.
///
/// The abstractions are borrowed from the source_gen package.
/// This class provides methods to check type compatibility, examine annotations,
/// and perform other type-related operations.
/// {@endtemplate}
abstract class TypeChecker {
  const TypeChecker._();

  /// {@template type_checker_factory}
  /// Creates a new [TypeChecker] that can check against the given type.
  /// {@endtemplate}

  /// {@macro type_checker_factory}
  ///
  /// This factory creates a checker based on a [NamedDartType] reference.
  factory TypeChecker.fromTypeRef(NamedDartType type) = _RefTypeChecker;

  /// {@macro type_checker_factory}
  ///
  /// This factory creates a checker based on a URL string.
  ///
  /// The expected format of the url is either a direct package url to
  /// the source file declaring the type, or a dart core type.
  /// For example:
  /// - `package:foo/bar.dart#Baz` 'Baz' should be a declared type inside 'package:foo/bar.dart'
  /// - 'dart:core/int.dart' 'int' should be a declared type inside 'dart:core/int.dart'
  /// - `dart:core#int` 'int' which will be normalized to `dart:core/int.dart`
  factory TypeChecker.fromUrl(String url) = _UriTypeChecker;

  /// {@macro type_checker_factory}
  ///
  /// Creates a new [TypeChecker] that delegates to other [checkers].
  factory TypeChecker.any(Iterable<TypeChecker> checkers) = _AnyChecker;

  /// {@template annotation_check}
  /// Examines the annotations on [element] related to this type checker.
  /// {@endtemplate}

  /// {@macro annotation_check}
  ///
  /// Returns the first annotation on [element] that is assignable to this type.
  ElementAnnotation? firstAnnotationOf(Element element) {
    if (element.metadata.isEmpty) {
      return null;
    }
    final Iterable<ElementAnnotation> results = annotationsOf(element);
    return results.isEmpty ? null : results.first;
  }

  /// {@macro annotation_check}
  ///
  /// Returns if a constant annotating [element] is assignable to this type.
  bool hasAnnotationOf(Element element) => firstAnnotationOf(element) != null;

  /// {@macro annotation_check}
  ///
  /// Returns the first constant annotating [element] that is exactly this type.
  ElementAnnotation? firstAnnotationOfExact(Element element) {
    if (element.metadata.isEmpty) {
      return null;
    }
    final Iterable<ElementAnnotation> results = annotationsOfExact(element);
    return results.isEmpty ? null : results.first;
  }

  /// {@macro annotation_check}
  ///
  /// Returns if a constant annotating [element] is exactly this type.
  bool hasAnnotationOfExact(Element element) => firstAnnotationOfExact(element) != null;

  /// {@macro annotation_check}
  ///
  /// Returns annotating constants on [element] assignable to this type.
  Iterable<ElementAnnotation> annotationsOf(Element element) => _annotationsWhere(element, (DartType ref) {
    return isAssignableFromType(ref);
  });

  Iterable<ElementAnnotation> _annotationsWhere(
    Element element,
    bool Function(DartType) predicate,
  ) sync* {
    for (int i = 0; i < element.metadata.length; i++) {
      final ElementAnnotation annotation = element.metadata[i];
      if (predicate(annotation.type)) {
        yield annotation;
      }
    }
  }

  /// {@macro annotation_check}
  ///
  /// Returns annotating constants on [element] of exactly this type.
  Iterable<ElementAnnotation> annotationsOfExact(Element element) => _annotationsWhere(element, isExactlyType);

  /// {@template type_assignability}
  /// Checks type assignability according to Dart's type system rules.
  /// {@endtemplate}

  /// {@macro type_assignability}
  ///
  /// Returns `true` if the type of [element] can be assigned to this type.
  bool isAssignableFrom(Element element) {
    return isExactly(element) || (element is InterfaceElement && isAssignableFromType(element.thisType));
  }

  /// {@macro type_assignability}
  ///
  /// Returns `true` if [typeRef] can be assigned to this type.
  bool isAssignableFromType(DartType typeRef);

  /// {@template type_equality}
  /// Checks if types are exactly the same.
  /// {@endtemplate}

  /// {@macro type_equality}
  ///
  /// Returns `true` if representing the exact same class as [element].
  bool isExactly(Element element) {
    if (element is InterfaceElement) {
      return isExactlyType(element.thisType);
    }
    return false;
  }

  /// {@macro type_equality}
  ///
  /// Returns `true` if representing the exact same type as [typeRef].
  ///
  /// This will always return false for types without a backing class such as
  /// `void` or function types.
  bool isExactlyType(DartType typeRef);

  /// Finds a matching type or supertype for the given [typeRef].
  ///
  /// Returns the matching type if found, otherwise null.
  NamedDartType? matchingTypeOrSupertype(DartType typeRef);

  /// Returns `true` if representing a super class of [element].
  ///
  /// This check only takes into account the *extends* hierarchy. If you wish
  /// to check mixins and interfaces, use [isAssignableFrom].
  bool isSuperOf(Element element) {
    if (element is InterfaceElement) {
      return isSupertypeOf(element.thisType);
    }
    return false;
  }

  /// Returns `true` if representing a super type of [staticType].
  ///
  /// This only takes into account the *extends* hierarchy. If you wish
  /// to check mixins and interfaces, use [isAssignableFromType].
  bool isSupertypeOf(DartType type);
}

class _RefTypeChecker extends _TypeCheckerImpl {
  final NamedDartType _type;

  _RefTypeChecker(this._type);

  @override
  String toString() => _type.name;

  @override
  bool isExactlyType(DartType typeRef) {
    if (typeRef is NamedDartType) {
      return typeRef.isExactly(_type);
    }
    return false;
  }
}

class _UriTypeChecker extends _TypeCheckerImpl {
  final String name;
  final Uri uri;
  final String? srcId;

  factory _UriTypeChecker(String url) {
    final List<String> parts = url.split('#');
    if (parts.length != 2) {
      throw ArgumentError(
        'Invalid url format: $url, expected format e.g package:foo/bar.dart#baz or dart:core#int',
      );
    }
    Uri libraryUrl = Uri.parse(parts[0]);
    final String typeName = parts[1];
    if (libraryUrl.scheme != 'package' && libraryUrl.scheme != 'dart') {
      throw ArgumentError(
        'Invalid url format: $url, expected format e.g package:foo/bar.dart#baz or dart:core#int',
      );
    }
    String? srcId;
    if (libraryUrl.path.endsWith('.dart')) {
      srcId = xxh3String(Uint8List.fromList(libraryUrl.toString().codeUnits));
    }

    return _UriTypeChecker._(typeName, libraryUrl, srcId);
  }

  _UriTypeChecker._(this.name, this.uri, this.srcId);

  @override
  bool isExactlyType(DartType typeRef) {
    if (typeRef is NamedDartType) {
      if (typeRef.name != name) {
        return false;
      }
      if (srcId != null) {
        return typeRef.declarationRef.srcId == srcId;
      }
      // at this point we should have something like dart:core;
      // we convert it to dart:core/core.dart
      final ResolverImpl resolver = typeRef.resolver as ResolverImpl;
      final NamedDartType type = resolver.getNamedType(name, uri.toString());
      return type.isExactly(typeRef);
    }
    return false;
  }
}

abstract class _TypeCheckerImpl extends TypeChecker {
  _TypeCheckerImpl() : super._();

  final Map<String, InterfaceType> _resolvedTypesCache = <String, InterfaceType>{};

  final Map<String, (bool, NamedDartType?)> _superTypeChecksCache = <String, (bool, NamedDartType?)>{};

  (bool, NamedDartType?) _checkSupertypesRecursively(
    NamedDartType typeToCheck,
    LibraryElement importingLib, {
    bool extendClauseOnly = false,
  }) {
    final String reqId = '${typeToCheck.identifier}@${importingLib.src.id}';

    if (_superTypeChecksCache.containsKey(reqId)) {
      return _superTypeChecksCache[reqId]!;
    }

    final IdentifierRef identifier = IdentifierRef(
      typeToCheck.name,
      importPrefix: typeToCheck.declarationRef.importPrefix,
      declarationRef: typeToCheck.declarationRef,
    );
    final (LibraryElementImpl library, AstNode unit, _) = importingLib.resolver.astNodeFor(identifier, importingLib);
    final Map<InterfaceType, LibraryElement> typesToSuperCheck = <InterfaceType, LibraryElement>{};

    (bool, InterfaceType?) check(NamedType? typeAnnotation) {
      if (typeAnnotation == null) {
        return (false, null);
      }
      final InterfaceType resolvedSuper = _resolveType(typeAnnotation, library);
      if (isExactlyType(resolvedSuper)) {
        return (true, resolvedSuper);
      } else {
        typesToSuperCheck[resolvedSuper] = library;
      }
      return (false, resolvedSuper);
    }

    if (extendClauseOnly) {
      if (unit is ClassDeclaration && unit.extendsClause != null) {
        final NamedType superType = unit.extendsClause!.superclass;
        final (bool match, InterfaceType? type) = check(superType);
        if (match) {
          return _superTypeChecksCache[reqId] = (true, type);
        } else if (typesToSuperCheck.isNotEmpty) {
          return _checkSupertypesRecursively(
            typesToSuperCheck.keys.first,
            typesToSuperCheck.values.first,
          );
        }
      }
      return _superTypeChecksCache[reqId] = (false, null);
    }

    if (unit is ClassDeclaration) {
      final NamedType? superType = unit.extendsClause?.superclass;
      final (bool match, InterfaceType? type) = check(superType);
      if (match) {
        return _superTypeChecksCache[reqId] = (true, type);
      }
      for (final NamedType interface in <NamedType>[
        ...?unit.implementsClause?.interfaces,
      ]) {
        final (bool match, InterfaceType? type) = check(interface);
        if (match) {
          return _superTypeChecksCache[reqId] = (true, type);
        }
      }
      for (final NamedType mixin in <NamedType>[
        ...?unit.withClause?.mixinTypes,
      ]) {
        final (bool match, InterfaceType? type) = check(mixin);
        if (match) {
          return _superTypeChecksCache[reqId] = (true, type);
        }
      }
    } else if (unit is MixinDeclaration) {
      for (final NamedType interface in <NamedType>[
        ...?unit.implementsClause?.interfaces,
      ]) {
        final (bool match, InterfaceType? type) = check(interface);
        if (match) {
          return _superTypeChecksCache[reqId] = (true, type);
        }
      }
    } else if (unit is EnumDeclaration) {
      for (final NamedType interface in <NamedType>[
        ...?unit.implementsClause?.interfaces,
      ]) {
        final (bool match, InterfaceType? type) = check(interface);
        if (match) {
          return _superTypeChecksCache[reqId] = (true, type);
        }
      }
    } else {
      throw Exception('Unsupported AST node type: ${unit.runtimeType}');
    }

    for (final MapEntry<InterfaceType, LibraryElement> entry in typesToSuperCheck.entries) {
      final (bool match, NamedDartType? type) = _checkSupertypesRecursively(
        entry.key,
        entry.value,
      );
      if (match) {
        return _superTypeChecksCache[reqId] = (true, type);
      }
    }
    return _superTypeChecksCache[reqId] = (false, null);
  }

  InterfaceType _resolveType(
    NamedType superType,
    LibraryElementImpl importingLib,
  ) {
    final String reqId = '$superType@${importingLib.src.id}';

    if (_resolvedTypesCache.containsKey(reqId)) {
      return _resolvedTypesCache[reqId]!;
    }
    final String typename = superType.name.lexeme;
    final ImportPrefixReference? importPrefix = superType.importPrefix;
    final DeclarationRef? identifierLocation = importingLib.resolver.getDeclarationRef(
      typename,
      importingLib.src,
      importPrefix: importPrefix?.name.lexeme,
    );

    if (identifierLocation == null) {
      throw IdentifierNotFoundError(
        typename,
        importPrefix?.name.lexeme,
        importingLib.src.shortUri,
      );
    }
    final InterfaceTypeImpl resolvedType = InterfaceTypeImpl(
      typename,
      identifierLocation,
      importingLib.resolver,
      isNullable: superType.question != null,
    );
    return _resolvedTypesCache[reqId] = resolvedType;
  }

  @override
  bool isSupertypeOf(DartType typeRef) => _isSupertypeOf(typeRef, extendClauseOnly: true);

  bool _isSupertypeOf(DartType typeRef, {bool extendClauseOnly = false}) {
    if (typeRef is InterfaceType) {
      final Asset? importingLibrary = typeRef.declarationRef.importingLibrary;
      if (importingLibrary == null) return false;
      final LibraryElementImpl importingLib = typeRef.resolver.libraryFor(
        importingLibrary,
      );
      final (bool match, _) = _checkSupertypesRecursively(
        typeRef,
        importingLib,
        extendClauseOnly: extendClauseOnly,
      );
      return match;
    }
    return false;
  }

  @override
  NamedDartType? matchingTypeOrSupertype(DartType typeRef) {
    if (typeRef is InterfaceType) {
      if (isExactlyType(typeRef)) {
        return typeRef;
      }
      final Asset? importingLibrary = typeRef.declarationRef.importingLibrary;
      if (importingLibrary == null) return null;
      final LibraryElementImpl importingLib = typeRef.resolver.libraryFor(
        importingLibrary,
      );
      final (
        bool match,
        NamedDartType? superType,
      ) = _checkSupertypesRecursively(
        typeRef,
        importingLib,
      );
      return match ? superType : null;
    }
    return null;
  }

  @override
  bool isAssignableFromType(DartType typeRef) {
    if (isExactlyType(typeRef)) {
      return true;
    }
    if (typeRef is NamedDartType) {
      return _isSupertypeOf(typeRef);
    }
    return false;
  }
}

class _AnyChecker extends TypeChecker {
  final Iterable<TypeChecker> _checkers;

  const _AnyChecker(this._checkers) : super._();

  @override
  bool isExactlyType(DartType typeRef) {
    if (typeRef is NamedDartType) {
      return _checkers.any((TypeChecker c) => c.isExactlyType(typeRef));
    }
    return false;
  }

  @override
  bool isSupertypeOf(DartType typeRef) {
    return _checkers.any((TypeChecker c) => c.isSupertypeOf(typeRef));
  }

  @override
  NamedDartType? matchingTypeOrSupertype(DartType typeRef) {
    for (final TypeChecker checker in _checkers) {
      final NamedDartType? result = checker.matchingTypeOrSupertype(typeRef);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  @override
  bool isAssignableFromType(DartType typeRef) {
    return _checkers.any((TypeChecker c) => c.isAssignableFromType(typeRef));
  }
}
