import 'dart:collection' show HashMap;
import 'dart:typed_data' show Uint8List;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart' show SyntacticEntity;
import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/element/builder/directives_builder.dart';
import 'package:lean_builder/src/element/builder/element_builder.dart';
import 'package:lean_builder/src/element/element.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/graph/declaration_ref.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/resolvers/errors.dart';
import 'package:lean_builder/src/resolvers/source_based_cache.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:lean_builder/src/resolvers/source_parser.dart';
import 'package:lean_builder/src/type/type.dart';
import 'package:lean_builder/src/type/type_checker.dart';
import 'package:lean_builder/src/type/type_utils.dart';
import 'package:xxh3/xxh3.dart' show xxh3String;

import 'constant/constant.dart';

/// {@template element_predicate}
/// A function type for filtering elements based on certain criteria.
///
/// Used throughout the resolver to provide flexible filtering of elements
/// during resolution operations.
///
/// @typeParam T The type of element to filter
/// {@endtemplate}
typedef ElementPredicate<T> = bool Function(T element);

/// {@template resolver}
/// Abstract interface for resolving Dart elements and types.
///
/// The Resolver is responsible for turning source code into element models,
/// resolving types, and providing access to the type system. It manages
/// the relationship between assets, libraries, and elements.
/// {@endtemplate}
abstract class Resolver {
  /// {@template resolver.file_resolver}
  /// The file resolver used to map between file paths and URIs.
  ///
  /// This handles URI resolution for package:, asset:, and dart: schemes.
  /// {@endtemplate}
  PackageFileResolver get fileResolver;

  /// {@template resolver.invalidate_asset_cache}
  /// Invalidates any cached information for the given asset.
  ///
  /// This should be called when an asset has been modified to ensure
  /// that subsequent resolutions use the updated content.
  ///
  /// @param src The asset to invalidate from caches
  /// {@endtemplate}
  void invalidateAssetCache(Asset src);

  /// {@template resolver.library_for}
  /// Gets the library element for the given asset.
  ///
  /// This creates or returns a cached library element for the asset,
  /// which represents the top-level structure of a Dart file.
  ///
  /// @param src The asset to get the library for
  /// @param allowSyntaxErrors Whether to continue if syntax errors are encountered
  /// @return The library element for the asset
  /// {@endtemplate}
  LibraryElementImpl libraryFor(Asset src, {bool allowSyntaxErrors = false});

  /// {@template resolver.resolve_library}
  /// Resolves a library and its top-level elements.
  ///
  /// This fully resolves a library, including its top-level elements,
  /// metadata annotations, and optionally its directives.
  ///
  /// @param src The asset to resolve as a library
  /// @param preResolveTopLevelMetadata Whether to resolve metadata annotations immediately
  /// @param allowSyntaxErrors Whether to continue if syntax errors are encountered
  /// @return The resolved library element
  /// {@endtemplate}
  LibraryElement resolveLibrary(Asset src, {bool preResolveTopLevelMetadata = false, bool allowSyntaxErrors = false});

  /// {@template resolver.type_checker_of}
  /// Creates a type checker for the given type.
  ///
  /// This allows checking if elements are of a specific type or
  /// subtype, useful for looking up annotated elements.
  ///
  /// @typeParam T The type to create a checker for
  /// @return A TypeChecker for the specified type
  /// {@endtemplate}
  TypeChecker typeCheckerOf<T>();

  /// {@template resolver.type_checker_for}
  /// Creates a type checker for a type identified by name and package.
  ///
  /// This allows checking if elements are of a specific type or
  /// subtype without needing the actual type at compile time.
  ///
  /// @param name The name of the type
  /// @param packageImport The package import path for the type
  /// @return A TypeChecker for the specified type
  /// {@endtemplate}
  TypeChecker typeCheckerFor(String name, String packageImport);

  /// {@template resolver.get_named_type}
  /// Gets a named type reference from a name and package URL.
  ///
  /// This resolves a type reference by name and package, which can
  /// then be used for type checking or element resolution.
  ///
  /// @param name The name of the type
  /// @param packageUrl The package URL containing the type
  /// @return A NamedDartType reference to the type
  /// {@endtemplate}
  NamedDartType getNamedType(String name, String packageUrl);

  /// {@template resolver.library_for_directive}
  /// Gets the library element for a directive element.
  ///
  /// This resolves the library that a directive (import, export, part)
  /// references, allowing navigation between libraries.
  ///
  /// @param directive The directive to resolve the library for
  /// @return The library element referenced by the directive
  /// {@endtemplate}
  LibraryElement libraryForDirective(DirectiveElement directive);

  /// {@template resolver.get_declaration_ref}
  /// Gets a declaration reference for an identifier in an importing source.
  ///
  /// This resolves an identifier to its declaration, handling imports
  /// and prefixes to find the correct element.
  ///
  /// @param identifier The identifier to resolve
  /// @param importingSrc The source file containing the identifier
  /// @param importPrefix Optional import prefix for the identifier
  /// @return A reference to the declaration of the identifier
  /// {@endtemplate}
  DeclarationRef? getDeclarationRef(String identifier, Asset importingSrc, {String? importPrefix});

  /// {@template resolver.element_of}
  /// Gets the element represented by a type.
  ///
  /// This resolves a type reference to its corresponding element,
  /// such as a class, mixin, or enum declaration.
  ///
  /// @param type The type to get the element for
  /// @return The element represented by the type, or null if none exists
  /// {@endtemplate}
  Element? elementOf(DartType type);

  /// {@template resolver.all_supertypes_of}
  /// Gets all supertypes of an interface element.
  ///
  /// This includes direct and indirect supertypes, including
  /// implemented interfaces, mixed-in classes, and extended classes.
  ///
  /// @param element The element to get supertypes for
  /// @return A list of all supertypes of the element
  /// {@endtemplate}
  List<InterfaceType> allSupertypesOf(InterfaceElement element);

  /// {@template resolver.resolve_methods}
  /// Resolves the methods of an interface element.
  ///
  /// This creates method elements for method declarations in a class,
  /// mixin, or extension, optionally filtered by a predicate.
  ///
  /// @param elem The interface element to resolve methods for
  /// @param predicate Optional filter for which methods to resolve
  /// {@endtemplate}
  void resolveMethods(InterfaceElement elem, {ElementPredicate<MethodDeclaration>? predicate});

  /// {@template resolver.resolve_fields}
  /// Resolves the fields of an interface element.
  ///
  /// This creates field elements for field declarations in a class,
  /// mixin, or extension.
  ///
  /// @param elem The interface element to resolve fields for
  /// {@endtemplate}
  void resolveFields(InterfaceElement elem);

  /// {@template resolver.resolve_constructors}
  /// Resolves the constructors of an interface element.
  ///
  /// This creates constructor elements for constructor declarations in a class.
  ///
  /// @param elem The interface element to resolve constructors for
  /// {@endtemplate}
  void resolveConstructors(InterfaceElement elem);

  /// {@template resolver.is_library}
  /// Checks if an asset represents a Dart library.
  ///
  /// This determines if an asset is a Dart file that can be treated
  /// as a library, vs a part file.
  ///
  /// @param asset The asset to check
  /// @return true if the asset is a Dart library
  /// {@endtemplate}
  bool isLibrary(Asset asset);

  /// {@template resolver.uri_for_asset}
  /// Gets the URI for an asset by its ID.
  ///
  /// This converts an asset ID to its corresponding URI, which can
  /// be used to locate or reference the asset.
  ///
  /// @param id The asset ID to get the URI for
  /// @return The URI for the asset
  /// {@endtemplate}
  Uri uriForAsset(String id);

  /// {@template resolver.try_uri_for_asset}
  /// Tries to get the URI for an asset by its ID.
  ///
  /// This attempts to convert an asset ID to its corresponding URI,
  /// returning null if the asset cannot be found.
  /// @param id The asset ID to get the URI for
  /// @return The URI for the asset, or null if not found
  /// {@endtemplate}
  Uri? tryUriForAsset(String id);
}

/// {@template resolver_impl}
/// Implementation of the Resolver interface.
///
/// This class provides the concrete implementation for resolving Dart elements
/// and types, managing caches for efficient resolution, and providing access
/// to the type system.
/// {@endtemplate}
class ResolverImpl extends Resolver {
  /// {@template resolver_impl.graph}
  /// The assets graph used to track relationships between assets.
  ///
  /// This graph manages dependencies between assets, imports, exports,
  /// and parts, allowing for efficient navigation between related files.
  /// {@endtemplate}
  final AssetsGraph graph;

  /// {@template resolver_impl.parser}
  /// The source parser used to parse Dart source code.
  ///
  /// This parser converts raw source text into AST (Abstract Syntax Tree)
  /// nodes that can be analyzed and resolved.
  /// {@endtemplate}
  final SourceParser parser;

  /// {@template resolver_impl.type_utils}
  /// Utilities for working with types.
  ///
  /// This provides helper methods for common type operations.
  /// {@endtemplate}
  late final TypeUtils typeUtils = TypeUtils(this);

  /// {@template resolver_impl.library_cache}
  /// Cache of library elements by source ID.
  ///
  /// This improves performance by avoiding re-parsing and re-resolving
  /// libraries that have already been processed.
  /// {@endtemplate}
  final HashMap<String, LibraryElementImpl> _libraryCache = HashMap<String, LibraryElementImpl>();

  /// {@template resolver_impl.resolved_units_cache}
  /// Cache of resolved AST nodes by source and identifier.
  ///
  /// This improves performance by avoiding re-resolving the same nodes.
  /// {@endtemplate}
  final SourceBasedCache<(LibraryElementImpl, AstNode, DeclarationRef)> _resolvedUnitsCache =
      SourceBasedCache<(LibraryElementImpl, AstNode, DeclarationRef)>();

  /// {@template resolver_impl.resolved_type_refs}
  /// Cache of resolved type references to elements.
  ///
  /// This improves performance by caching the element for a type reference.
  /// {@endtemplate}
  final SourceBasedCache<Element> _resolvedTypeRefs = SourceBasedCache<Element>();

  /// {@template resolver_impl.evaluated_constants_cache}
  /// Cache of evaluated constant values.
  ///
  /// This improves performance by avoiding re-evaluating constants.
  /// {@endtemplate}
  final SourceBasedCache<Constant> evaluatedConstantsCache = SourceBasedCache<Constant>();

  /// {@template resolver_impl.registered_types_map}
  /// Map of registered Dart Types to source IDs.
  ///
  /// This allows looking up types by their runtime Type object.
  /// {@endtemplate}
  final TypeCheckersCache typeCheckersCache = TypeCheckersCache();

  @override
  final PackageFileResolver fileResolver;

  /// {@template resolver_impl.constructor}
  /// Creates a new resolver with the given components.
  ///
  /// @param graph The assets graph for tracking relationships
  /// @param fileResolver The file resolver for URI resolution
  /// @param parser The source parser for parsing Dart code
  /// {@endtemplate}
  ResolverImpl(this.graph, this.fileResolver, this.parser);

  @override
  void invalidateAssetCache(Asset src) {
    parser.invalidate(src.id);
    _libraryCache.remove(src.id);
    _resolvedUnitsCache.invalidateForSource(src.id);
    _resolvedTypeRefs.invalidateForSource(src.id);
    evaluatedConstantsCache.invalidateForSource(src.id);
    typeCheckersCache.invalidateCachesForSource(src.id);
  }

  /// {@template resolver_impl.invalidate_all_caches}
  /// Invalidates all caches used by this resolver.
  ///
  /// This should be called when significant changes have been made
  /// to multiple assets or when the resolver state needs to be reset.
  /// {@endtemplate}
  void invalidateAllCaches() {
    parser.clear();
    _libraryCache.clear();
    _resolvedUnitsCache.clear();
    _resolvedTypeRefs.clear();
    evaluatedConstantsCache.clear();
  }

  /// {@template resolver_impl.register_type_map}
  /// Registers a mapping from a Dart Type to a source ID.
  ///
  /// This allows the resolver to find the source file containing
  /// a type referenced by its runtime Type object.
  ///
  /// @param type The Type object to register
  /// @param srcId The source ID containing the type definition
  /// {@endtemplate}
  void registerTypeMap(Type type, String srcId) {
    typeCheckersCache.registerTypeMap(type, srcId);
  }

  /// {@template resolver_impl.register_types_map}
  /// Registers multiple Type to source ID mappings.
  ///
  /// This is a batch version of registerTypeMap for efficiency.
  ///
  /// @param typeMaps Map of Type objects to their source IDs
  /// {@endtemplate}
  void registerTypesMap(Map<Type, String> typeMaps) {
    typeCheckersCache.registerTypesMap(typeMaps);
  }

  @override
  LibraryElement resolveLibrary(Asset src, {bool preResolveTopLevelMetadata = false, bool allowSyntaxErrors = false}) {
    final LibraryElementImpl library = libraryFor(src, allowSyntaxErrors: allowSyntaxErrors);
    final ElementBuilder visitor = ElementBuilder(
      this,
      library,
      preResolveTopLevelMetadata: preResolveTopLevelMetadata,
    );
    for (final AnnotatedNode child in library.compilationUnit.childEntities.whereType<AnnotatedNode>()) {
      if (child.metadata.isNotEmpty) {
        child.accept(visitor);
      }
    }
    return library;
  }

  @override
  TypeChecker typeCheckerOf<T>() {
    assert(T != dynamic, 'T cannot be dynamic');
    final Type type = T;
    final registeredTypesMap = typeCheckersCache._registeredTypesMap;
    if (registeredTypesMap.containsKey(type)) {
      final String srcId = registeredTypesMap[type]!;
      final DeclarationRef? declarationRef = graph.lookupIdentifierByProvider(type.toString(), srcId);
      if (declarationRef == null) {
        throw Exception('Identifier ${type.toString()} not found in $srcId');
      }

      assert(declarationRef.type.representsInterfaceType, '$type does not refer to a named type');
      final InterfaceTypeImpl typeRef = InterfaceTypeImpl(declarationRef.identifier, declarationRef, this);
      return TypeChecker.fromTypeRef(typeRef);
    }
    throw Exception('Type $type not registered');
  }

  @override
  TypeChecker typeCheckerFor(String name, String packageImport) {
    return TypeChecker.fromTypeRef(getNamedType(name, packageImport));
  }

  @override
  NamedDartType getNamedType(String name, String packageUrl) {
    Uri uri = Uri.parse(packageUrl);
    if (uri.scheme != 'package' && uri.scheme != 'dart') {
      throw Exception('Invalid package import: $packageUrl, must be a package or dart import');
    }
    if (uri.scheme == 'dart' && !packageUrl.endsWith('.dart')) {
      final Uri absoluteUri = fileResolver.resolveFileUri(uri);
      uri = fileResolver.toShortUri(absoluteUri);
    }
    final String srcId = xxh3String(Uint8List.fromList(uri.toString().codeUnits));
    final DeclarationRef? declarationRef = graph.lookupIdentifierByProvider(name, srcId);
    if (declarationRef == null) {
      throw Exception('Identifier $name not found in $packageUrl');
    }
    if (declarationRef.type.representsInterfaceType) {
      return InterfaceTypeImpl(name, declarationRef, this);
    } else if (declarationRef.type == ReferenceType.$typeAlias) {
      return TypeAliasTypeImpl(name, declarationRef, this);
    } else {
      throw Exception('$name does not refer to a named type');
    }
  }

  @override
  LibraryElement libraryForDirective(DirectiveElement directive) {
    final Asset assetSrc = fileResolver.assetForUri(directive.uri);
    return libraryFor(assetSrc);
  }

  @override
  DeclarationRef? getDeclarationRef(String identifier, Asset importingSrc, {String? importPrefix}) {
    return graph.getDeclarationRef(identifier, importingSrc, importPrefix: importPrefix);
  }

  @override
  Element? elementOf(DartType type) {
    if (type is NamedDartType) {
      final CompoundKey key = _resolvedTypeRefs.keyFor(type.declarationRef.srcId, type.name);

      if (_resolvedTypeRefs.contains(key)) {
        return _resolvedTypeRefs[key];
      }
      Asset? importingLibrary = type.declarationRef.importingLibrary;
      importingLibrary ??= fileResolver.assetForUri(type.declarationRef.srcUri);

      final LibraryElementImpl importingLib = libraryFor(importingLibrary);
      final IdentifierRef identifier = IdentifierRef(type.name, declarationRef: type.declarationRef);
      final (LibraryElementImpl library, AstNode unit, _) = astNodeFor(identifier, importingLib);
      final ElementBuilder visitor = ElementBuilder(this, library);
      unit.accept(visitor);
      final Element? element = library.getElement(type.name);
      if (element != null) {
        _resolvedTypeRefs.cacheKey(key, element);
      }
      return element;
    }
    return null;
  }

  @override
  List<InterfaceType> allSupertypesOf(InterfaceElement element) {
    final List<InterfaceType> superTypes = <InterfaceType>[];
    final List<NamedDartType> thisLevelTypes = <NamedDartType>[
      if (element.superType != null) element.superType!,
      ...element.mixins,
      ...element.interfaces,
      if (element is MixinElement) ...(element as MixinElement).superclassConstraints,
    ];

    for (final NamedDartType type in thisLevelTypes) {
      final Element? supElement = type.element;
      if (supElement is InterfaceElement) {
        superTypes.add(type as InterfaceType);
        final List<InterfaceType> subTypes = allSupertypesOf(supElement);
        superTypes.addAll(subTypes);
      } else if (supElement is TypeAliasElement && supElement.aliasedType is NamedDartType) {
        // if it's a NamedDartType it should eventually point to an InterfaceType
        final InterfaceType? aliasedType = supElement.aliasedInterfaceType;
        if (aliasedType == null) {
          throw Exception('Type $type is not an interface type');
        }
        superTypes.add(aliasedType);
        final List<InterfaceType> subTypes = allSupertypesOf(aliasedType.element);
        superTypes.addAll(subTypes);
      } else if (supElement != null) {
        throw Exception('Type $type is not an interface type');
      }
    }
    return superTypes;
  }

  @override
  LibraryElementImpl libraryFor(Asset src, {bool allowSyntaxErrors = false}) {
    assert(src.uri.path.endsWith('.dart'), 'Asset $src is not a dart file');
    return _libraryCache.putIfAbsent(src.id, () {
      final CompilationUnit unit = parser.parse(src, allowSyntaxErrors: allowSyntaxErrors);
      return LibraryElementImpl(this, unit, src: src);
    });
  }

  /// {@template resolver_impl.ast_node_for}
  /// Resolves an identifier reference to its AST node, library, and declaration.
  ///
  /// This method finds the AST node for an identifier, resolving imports
  /// and locating the correct declaration in the source file.
  ///
  /// @param identifier The identifier reference to resolve
  /// @param enclosingLibrary The library containing the reference
  /// @return A tuple of (library, AST node, declaration reference)
  /// {@endtemplate}
  (LibraryElementImpl, AstNode, DeclarationRef) astNodeFor(IdentifierRef identifier, LibraryElement enclosingLibrary) {
    final Asset enclosingAsset = enclosingLibrary.src;
    final CompoundKey cacheKey = _resolvedUnitsCache.keyFor(enclosingAsset.id, identifier.toString());
    if (_resolvedUnitsCache.contains(cacheKey)) {
      return _resolvedUnitsCache[cacheKey]!;
    }

    final DeclarationRef? declarationRef =
        identifier.declarationRef ??
        getDeclarationRef(identifier.topLevelTarget, enclosingAsset, importPrefix: identifier.importPrefix);
    if (declarationRef == null) {
      throw IdentifierNotFoundError(identifier.topLevelTarget, identifier.importPrefix, enclosingAsset.shortUri);
    }

    final Uri srcUri = uriForAsset(declarationRef.srcId);
    final Asset assetFile = fileResolver.assetForUri(srcUri, relativeTo: enclosingAsset);

    final LibraryElementImpl library = libraryFor(assetFile);
    final CompilationUnit compilationUnit = library.compilationUnit;

    if (declarationRef.type == ReferenceType.$variable) {
      final TopLevelVariableDeclaration unit = compilationUnit.declarations
          .whereType<TopLevelVariableDeclaration>()
          .firstWhere(
            (TopLevelVariableDeclaration e) =>
                e.variables.variables.any((VariableDeclaration v) => v.name.lexeme == declarationRef.identifier),
            orElse: () => throw Exception('Identifier  ${declarationRef.identifier} not found in $srcUri'),
          );
      return _resolvedUnitsCache.cacheKey(cacheKey, (library, unit, declarationRef));
    } else if (declarationRef.type == ReferenceType.$function) {
      final FunctionDeclaration unit = compilationUnit.declarations.whereType<FunctionDeclaration>().firstWhere(
        (FunctionDeclaration e) => e.name.lexeme == declarationRef.identifier,
        orElse: () => throw Exception('Identifier  ${declarationRef.identifier} not found in $srcUri'),
      );
      return _resolvedUnitsCache.cacheKey(cacheKey, (library, unit, declarationRef));
    } else if (declarationRef.type == ReferenceType.$typeAlias) {
      final TypeAlias unit = compilationUnit.declarations.whereType<TypeAlias>().firstWhere(
        (TypeAlias e) => e.name.lexeme == declarationRef.identifier,
        orElse: () => throw Exception('Identifier  ${declarationRef.identifier} not found in $srcUri'),
      );
      return _resolvedUnitsCache.cacheKey(cacheKey, (library, unit, declarationRef));
    }

    final NamedCompilationUnitMember? unit = compilationUnit.declarations
        .whereType<NamedCompilationUnitMember>()
        .firstWhereOrNull((NamedCompilationUnitMember e) => e.name.lexeme == declarationRef.identifier);

    if (unit == null) {
      throw Exception('Identifier  ${declarationRef.identifier} not found in $srcUri');
    } else if (identifier.isPrefixed) {
      final String targetIdentifier = identifier.name;

      for (final SyntacticEntity member in unit.childEntities) {
        if (member is FieldDeclaration) {
          if (member.fields.variables.any((VariableDeclaration v) => v.name.lexeme == targetIdentifier)) {
            return _resolvedUnitsCache.cacheKey(cacheKey, (library, member, declarationRef));
          }
        } else if (member is ConstructorDeclaration) {
          if ((member.name?.lexeme ?? '') == targetIdentifier) {
            return _resolvedUnitsCache.cacheKey(cacheKey, (library, member, declarationRef));
          }
        } else if (member is MethodDeclaration) {
          if (member.name.lexeme == targetIdentifier) {
            return _resolvedUnitsCache.cacheKey(cacheKey, (library, member, declarationRef));
          }
        } else if (member is EnumConstantDeclaration) {
          if (member.name.lexeme == targetIdentifier) {
            return _resolvedUnitsCache.cacheKey(cacheKey, (library, member, declarationRef));
          }
        }
      }
      throw Exception('Identifier $targetIdentifier (${identifier.toString()}) not found in $srcUri');
    }

    return _resolvedUnitsCache.cacheKey(cacheKey, (library, unit, declarationRef));
  }

  @override
  Uri uriForAsset(String id) {
    return graph.uriForAsset(id);
  }

  @override
  bool isLibrary(Asset asset) {
    if (!asset.uri.path.endsWith('.dart')) {
      return false;
    }
    return graph.getParentSrc(asset.id) == asset.id;
  }

  /// {@template resolver_impl.resolve_directives}
  /// Resolves all directives in a library.
  ///
  /// This processes import, export, part, and part-of directives
  /// to build the relationships between libraries.
  ///
  /// @param library The library to resolve directives for
  /// {@endtemplate}
  void resolveDirectives(LibraryElementImpl library) {
    final DirectivesBuilder builder = DirectivesBuilder(this, library);
    final NodeList<Directive> directives = library.compilationUnit.directives;
    for (final Directive directive in directives) {
      directive.accept(builder);
    }
  }

  @override
  void resolveMethods(InterfaceElement elem, {ElementPredicate<MethodDeclaration>? predicate}) {
    final ElementBuilder elementBuilder = ElementBuilder(this, elem.library);
    final NamedCompilationUnitMember namedUnit = (elem as InterfaceElementImpl).compilationUnit;

    final Iterable<MethodDeclaration> methods = namedUnit.childEntities.filterAs<MethodDeclaration>(predicate);
    elementBuilder.visitElementScoped(elem, () {
      for (final MethodDeclaration method in methods) {
        method.accept(elementBuilder);
      }
    });
  }

  @override
  void resolveFields(InterfaceElement elem) {
    final ElementBuilder elementBuilder = ElementBuilder(this, elem.library);
    final InterfaceElementImpl interfaceElem = elem as InterfaceElementImpl;
    final NamedCompilationUnitMember namedUnit = interfaceElem.compilationUnit;
    final Iterable<FieldDeclaration> fields = namedUnit.childEntities.whereType<FieldDeclaration>();
    elementBuilder.visitElementScoped(interfaceElem, () {
      for (final FieldDeclaration field in fields) {
        field.accept(elementBuilder);
      }
    });
  }

  @override
  void resolveConstructors(InterfaceElement elem) {
    final ElementBuilder elementBuilder = ElementBuilder(this, elem.library);
    final InterfaceElementImpl interfaceElem = elem as InterfaceElementImpl;
    final NamedCompilationUnitMember namedUnit = interfaceElem.compilationUnit;
    final Iterable<ConstructorDeclaration> constructors = namedUnit.childEntities.whereType<ConstructorDeclaration>();
    if (constructors.isEmpty && elem is ClassElementImpl) {
      // If no constructors are defined, add a default constructor
      elem.addConstructor(
        ConstructorElementImpl(name: '', enclosingElement: elem, isConst: false, isFactory: false, isGenerator: false),
      );
      return;
    }

    elementBuilder.visitElementScoped(interfaceElem, () {
      for (final ConstructorDeclaration constructor in constructors) {
        constructor.accept(elementBuilder);
      }
    });
  }

  /// {@template resolver_impl.resolve_type_aliases}
  /// Resolves type aliases in a library.
  ///
  /// This creates type alias elements for type alias declarations
  /// in a library, optionally filtered by a predicate.
  ///
  /// @param library The library to resolve type aliases for
  /// @param predicate Optional filter for which type aliases to resolve
  /// {@endtemplate}
  void resolveTypeAliases(LibraryElementImpl library, {ElementPredicate<TypeAlias>? predicate}) {
    final CompilationUnit unit = library.compilationUnit;
    final ElementBuilder visitor = ElementBuilder(this, library);
    for (final TypeAlias typeAlias in unit.declarations.filterAs<TypeAlias>(predicate)) {
      typeAlias.accept(visitor);
    }
  }

  /// {@template resolver_impl.resolve_mixins}
  /// Resolves mixin declarations in a library.
  ///
  /// This creates mixin elements for mixin declarations in a library,
  /// optionally filtered by a predicate.
  ///
  /// @param library The library to resolve mixins for
  /// @param predicate Optional filter for which mixins to resolve
  /// {@endtemplate}
  void resolveMixins(LibraryElementImpl library, {ElementPredicate<MixinDeclaration>? predicate}) {
    final CompilationUnit unit = library.compilationUnit;
    final ElementBuilder visitor = ElementBuilder(this, library);
    for (final MixinDeclaration mixin in unit.declarations.filterAs<MixinDeclaration>(predicate)) {
      mixin.accept(visitor);
    }
  }

  /// {@template resolver_impl.resolve_enums}
  /// Resolves enum declarations in a library.
  ///
  /// This creates enum elements for enum declarations in a library,
  /// optionally filtered by a predicate.
  ///
  /// @param library The library to resolve enums for
  /// @param predicate Optional filter for which enums to resolve
  /// {@endtemplate}
  void resolveEnums(LibraryElementImpl library, {ElementPredicate<EnumDeclaration>? predicate}) {
    final CompilationUnit unit = library.compilationUnit;
    final ElementBuilder visitor = ElementBuilder(this, library);
    for (final EnumDeclaration enumDeclaration in unit.declarations.filterAs<EnumDeclaration>(predicate)) {
      enumDeclaration.accept(visitor);
    }
  }

  /// {@template resolver_impl.resolve_functions}
  /// Resolves function declarations in a library.
  ///
  /// This creates function elements for function declarations in a library,
  /// optionally filtered by a predicate.
  ///
  /// @param library The library to resolve functions for
  /// @param predicate Optional filter for which functions to resolve
  /// {@endtemplate}
  void resolveFunctions(LibraryElementImpl library, {ElementPredicate<FunctionDeclaration>? predicate}) {
    final CompilationUnit unit = library.compilationUnit;
    final ElementBuilder visitor = ElementBuilder(this, library);
    for (final FunctionDeclaration function in unit.declarations.filterAs<FunctionDeclaration>(predicate)) {
      function.accept(visitor);
    }
  }

  /// {@template resolver_impl.resolve_classes}
  /// Resolves class declarations in a library.
  ///
  /// This creates class elements for class declarations and class type
  /// aliases in a library, optionally filtered by a predicate.
  ///
  /// @param library The library to resolve classes for
  /// @param predicate Optional filter for which classes to resolve
  /// {@endtemplate}
  void resolveClasses(LibraryElementImpl library, {ElementPredicate<NamedCompilationUnitMember>? predicate}) {
    final CompilationUnit unit = library.compilationUnit;
    final ElementBuilder visitor = ElementBuilder(this, library);
    for (final ClassDeclaration classDeclaration in unit.declarations.filterAs<ClassDeclaration>(predicate)) {
      classDeclaration.accept(visitor);
    }

    /// class type alias are treated as classes
    for (final ClassTypeAlias classTypeAlias in unit.declarations.filterAs<ClassTypeAlias>(predicate)) {
      classTypeAlias.accept(visitor);
    }
  }

  /// {@template resolver_impl.resolve_identifier}
  /// Resolves a dotted identifier path to an IdentifierRef.
  ///
  /// This handles import prefixes, nested identifiers, and qualified names,
  /// turning them into a structured reference that can be resolved.
  ///
  /// @param library The library containing the identifier
  /// @param parts The parts of the dotted identifier path
  /// @return An IdentifierRef representing the identifier
  /// {@endtemplate}
  IdentifierRef resolveIdentifier(LibraryElement library, List<String> parts) {
    assert(parts.isNotEmpty, 'Identifier parts cannot be empty');
    if (parts.length == 1) {
      return IdentifierRef(parts.first);
    } else {
      final String prefix = parts[0];
      final Set<String> importPrefixes = graph.importPrefixesOf(library.src.id);
      final bool isImportPrefix = importPrefixes.contains(prefix);
      if (isImportPrefix) {
        final String? namedUnit = parts.length == 3 ? parts[1] : null;
        return IdentifierRef(parts.last, prefix: namedUnit, importPrefix: prefix);
      } else {
        return IdentifierRef(parts.last, prefix: parts[0]);
      }
    }
  }

  @override
  Uri? tryUriForAsset(String id) {
    return graph.uriForAssetOrNull(id);
  }
}

/// {@template iterable_filter_ext}
/// Extension methods for filtering iterable collections.
///
/// Provides convenient methods for filtering elements of a specific type
/// and optionally applying additional predicates.
/// {@endtemplate}
extension IterableFilterExt<E> on Iterable<E> {
  /// {@template iterable_filter_ext.filter_as}
  /// Filters elements of a specific type with an optional predicate.
  ///
  /// This combines whereType with a predicate function for more
  /// precise filtering of elements.
  ///
  /// @typeParam T The type to filter for
  /// @param predicate Optional additional filter condition
  /// @return Filtered iterable containing only matching elements
  /// {@endtemplate}
  Iterable<T> filterAs<T>([ElementPredicate<T>? predicate]) {
    if (predicate == null) return whereType<T>();
    return whereType<T>().where(predicate);
  }
}

///  {@template resolver_impl.type_checkers_cache}
///  Cache for type checkers and resolved types.
///  This cache improves performance by storing type checkers
///  and resolved types for quick access.
///  {@endtemplate}
abstract class TypeCheckersCache {
  /// {@template resolver_impl.registered_types_map}
  /// Map of Dart types to their source IDs.
  ///
  /// This allows resolving types by their runtime Type object.
  /// {@endtemplate}
  HashMap<Type, String> get _registeredTypesMap;

  /// {@template resolver_impl.resolved_types_cache}
  /// Cache of resolved interface types.
  ///
  /// This improves performance by caching resolved types.
  /// {@endtemplate}
  SourceBasedCache<InterfaceType> get resolvedTypesCache;

  /// {@template resolver_impl.super_type_checks_cache}
  /// Cache of supertype check results.
  ///
  /// This improves performance by caching the results of supertype checks.
  /// {@endtemplate}
  SourceBasedCache<(bool, NamedDartType?)> get superTypeChecksCache;

  /// {@template resolver_impl.type_checkers_cache_constructor}
  /// Creates a new instance of the TypeCheckersCache.
  /// {@endtemplate}
  ///
  factory TypeCheckersCache() => _TypeCheckersCacheImpl();

  /// {@template resolver_impl.invalidate_caches_for_source}
  /// Invalidates caches for a specific source ID.
  ///
  /// This clears cached entries related to the given source.
  ///  @param srcId The source ID to invalidate caches for
  /// {@endtemplate}
  void invalidateCachesForSource(String srcId);

  /// {@template resolver_impl.register_type_map}
  /// Registers a mapping from a Dart Type to a source ID.
  ///
  /// This allows the resolver to find the source file containing
  /// a type referenced by its runtime Type object.
  ///
  /// @param type The Type object to register
  /// @param srcId The source ID containing the type definition
  /// {@endtemplate}
  void registerTypeMap(Type type, String srcId);

  /// {@template resolver_impl.register_types_map}
  /// Registers multiple Type to source ID mappings.
  ///
  /// This is a batch version of registerTypeMap for efficiency.
  ///
  /// @param typeMaps Map of Type objects to their source IDs
  /// {@endtemplate}
  void registerTypesMap(Map<Type, String> typeMaps);
}

class _TypeCheckersCacheImpl implements TypeCheckersCache {
  @override
  final HashMap<Type, String> _registeredTypesMap = HashMap<Type, String>();

  @override
  final SourceBasedCache<InterfaceType> resolvedTypesCache = SourceBasedCache<InterfaceType>();

  @override
  final SourceBasedCache<(bool, NamedDartType?)> superTypeChecksCache = SourceBasedCache<(bool, NamedDartType?)>();

  @override
  void invalidateCachesForSource(String srcId) {
    resolvedTypesCache.invalidateForSource(srcId);
    superTypeChecksCache.invalidateForSource(srcId);
  }

  @override
  void registerTypeMap(Type type, String srcId) {
    _registeredTypesMap[type] = srcId;
  }

  @override
  void registerTypesMap(Map<Type, String> typeMaps) {
    _registeredTypesMap.addAll(typeMaps);
  }
}
