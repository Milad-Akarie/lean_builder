part of 'element.dart';

/// {@macro constant_value_compute}
typedef ConstantValueCompute = Constant? Function();

/// {@template element_impl}
/// Base implementation for [Element].
///
/// This class provides default implementations for many of the methods and
/// properties defined in the [Element] interface.
/// {@endtemplate}
abstract class ElementImpl implements Element {
  @override
  String? get documentationComment => _documentationComment;

  String? _documentationComment;

  set documentationComment(String? documentationComment) {
    _documentationComment = documentationComment;
  }

  /// Whether the metadata of this element has been resolved.
  bool didResolveMetadata = false;

  @override
  List<ElementAnnotation> get metadata {
    if (!didResolveMetadata) {
      metadataResolveCallback?.call();
      didResolveMetadata = true;
    }
    return _metadata;
  }

  final List<ElementAnnotation> _metadata = <ElementAnnotation>[];

  /// Adds a metadata annotation to this element.
  void addMetadata(ElementAnnotation annotation) {
    _metadata.add(annotation);
  }

  @override
  ElementAnnotation? getAnnotation(String name) {
    return metadata.firstWhereOrNull((ElementAnnotation e) => e.name == name);
  }

  /// Callback to resolve metadata.
  void Function()? metadataResolveCallback;

  @override
  Asset get librarySrc => library.src;

  @override
  bool get hasAlwaysThrows => metadata.any((ElementAnnotation m) => m.isAlwaysThrows);

  @override
  bool get hasDeprecated => metadata.any((ElementAnnotation m) => m.isDeprecated);

  @override
  bool get hasDoNotStore => metadata.any((ElementAnnotation m) => m.isDoNotStore);

  @override
  bool get hasFactory => metadata.any((ElementAnnotation m) => m.isFactory);

  @override
  bool get hasInternal => metadata.any((ElementAnnotation m) => m.isInternal);

  @override
  bool get hasIsTest => metadata.any((ElementAnnotation m) => m.isIsTest);

  @override
  bool get hasIsTestGroup => metadata.any((ElementAnnotation m) => m.isIsTestGroup);

  @override
  bool get hasLiteral => metadata.any((ElementAnnotation m) => m.isLiteral);

  @override
  bool get hasMustBeOverridden => metadata.any((ElementAnnotation m) => m.isMustBeOverridden);

  @override
  bool get hasMustCallSuper => metadata.any((ElementAnnotation m) => m.isMustCallSuper);

  @override
  bool get hasNonVirtual => metadata.any((ElementAnnotation m) => m.isNonVirtual);

  @override
  bool get hasOptionalTypeArgs => metadata.any((ElementAnnotation m) => m.isOptionalTypeArgs);

  @override
  bool get hasOverride => metadata.any((ElementAnnotation m) => m.isOverride);

  @override
  bool get hasProtected => metadata.any((ElementAnnotation m) => m.isProtected);

  @override
  bool get hasRedeclare => metadata.any((ElementAnnotation m) => m.isRedeclare);

  @override
  bool get hasReopen => metadata.any((ElementAnnotation m) => m.isReopen);

  @override
  bool get hasRequired => metadata.any((ElementAnnotation m) => m.isRequired);

  @override
  bool get hasSealed => metadata.any((ElementAnnotation m) => m.isSealed);

  @override
  bool get hasUseResult => metadata.any((ElementAnnotation m) => m.isUseResult);

  @override
  bool get hasVisibleForOverriding => metadata.any((ElementAnnotation m) => m.isVisibleForOverriding);

  @override
  String get identifier => '${library.src.shortUri}#$name';

  @override
  bool get isPrivate => Identifier.isPrivateName(name);

  @override
  bool get isPublic => !isPrivate;

  @override
  int get nameLength => _nameLength;

  @override
  int get nameOffset => _nameOffset;

  int _nameLength = 0;
  int _nameOffset = -1;

  int _codeOffset = -1;
  int _codeLength = 0;

  AstNode? _astNode;

  @override
  String? get source {
    if (_astNode == null) {
      return null;
    }
    final String source = _astNode!.toSource();
    if (source.isEmpty) {
      return null;
    }
    return source;
  }

  @override
  int get codeOffset => _codeOffset;

  @override
  int get codeLength => _codeLength;

  /// Sets the code range for this element.
  void setCodeRange(AstNode? node, int offset, int length) {
    _astNode = node;
    _codeOffset = offset;
    _codeLength = length;
  }

  /// Sets the name range for this element.
  void setNameRange(int offset, int length) {
    _nameOffset = offset;
    _nameLength = length;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Element && runtimeType == other.runtimeType && identifier == other.identifier;

  @override
  int get hashCode => name.hashCode ^ library.hashCode;

  @override
  String toString() => name;
}

/// {@template library_element_impl}
/// Implementation for [LibraryElement].
///
/// This class provides methods for accessing the classes, mixins, enums,
/// functions, and type aliases defined in a library.
/// {@endtemplate}
class LibraryElementImpl extends ElementImpl implements LibraryElement {
  /// Creates an instance of [LibraryElementImpl].
  LibraryElementImpl(this.resolver, this.compilationUnit, {required this.src});

  @override
  final CompilationUnit compilationUnit;

  @override
  final ResolverImpl resolver;

  /// The list of elements that have been resolved in this library.
  List<Element> get resolvedElements => List<Element>.unmodifiable(_resolvedElements);

  final List<Element> _resolvedElements = <Element>[];

  bool _didResolveDirectives = false;

  bool _didResolveAllTypeAliases = false;

  bool _didResolveAllClasses = false;

  bool _didResolveAllMixins = false;

  bool _didResolveAllEnums = false;

  bool _didResolveAllFunctions = false;

  /// Adds an element to the library.
  void addElement(Element element) {
    _resolvedElements.add(element);
  }

  @override
  late final String name = src.shortUri.pathSegments.last;

  @override
  final Asset src;

  @override
  Null get enclosingElement => null;

  @override
  LibraryElement get library => this;

  List<E> _elementsOfType<E extends Element>() {
    return List<E>.unmodifiable(_resolvedElements.whereType<E>());
  }

  @override
  List<ClassElementImpl> get classes {
    if (!_didResolveAllClasses) {
      resolver.resolveClasses(this);
      _didResolveAllClasses = true;
    }
    return _elementsOfType<ClassElementImpl>();
  }

  @override
  List<MixinElementImpl> get mixins {
    if (!_didResolveAllMixins) {
      resolver.resolveMixins(this);
      _didResolveAllMixins = true;
    }
    return _elementsOfType<MixinElementImpl>();
  }

  @override
  List<EnumElementImpl> get enums {
    if (!_didResolveAllEnums) {
      resolver.resolveEnums(this);
      _didResolveAllEnums = true;
    }
    return _elementsOfType<EnumElementImpl>();
  }

  @override
  List<FunctionElement> get functions {
    if (!_didResolveAllFunctions) {
      resolver.resolveFunctions(this);
      _didResolveAllFunctions = true;
    }
    return _elementsOfType<FunctionElement>();
  }

  @override
  List<TypeAliasElement> get typeAliases {
    if (!_didResolveAllTypeAliases) {
      resolver.resolveTypeAliases(this);
      _didResolveAllTypeAliases = true;
    }
    return _elementsOfType<TypeAliasElement>();
  }

  /// Checks if the library has an element with the given name.
  bool hasElement(String name) {
    return resolvedElements.any((Element e) => e.name == name);
  }

  @override
  ClassElementImpl? getClass(String name) {
    if (_didResolveAllClasses || hasElement(name)) {
      return _elementsOfType<ClassElementImpl>().firstWhereOrNull((ClassElementImpl e) => e.name == name);
    }
    resolver.resolveClasses(this, predicate: (String name) => name == name);
    return _elementsOfType<ClassElementImpl>().firstWhereOrNull((ClassElementImpl e) => e.name == name);
  }

  @override
  Element? getElement(String name) {
    return resolvedElements.firstWhereOrNull((Element e) => e.name == name);
  }

  @override
  MixinElementImpl? getMixin(String name) {
    if (_didResolveAllMixins || hasElement(name)) {
      return _elementsOfType<MixinElementImpl>().firstWhereOrNull((MixinElementImpl e) => e.name == name);
    }
    resolver.resolveMixins(this, predicate: (MixinDeclaration e) => e.name.lexeme == name);
    return _elementsOfType<MixinElementImpl>().firstWhereOrNull((MixinElementImpl e) => e.name == name);
  }

  @override
  EnumElementImpl? getEnum(String name) {
    if (_didResolveAllEnums || hasElement(name)) {
      return _elementsOfType<EnumElementImpl>().firstWhereOrNull((EnumElementImpl e) => e.name == name);
    }
    resolver.resolveEnums(this, predicate: (EnumDeclaration e) => e.namePart.typeName.lexeme == name);
    return _elementsOfType<EnumElementImpl>().firstWhereOrNull((EnumElementImpl e) => e.name == name);
  }

  @override
  TypeAliasElement? getTypeAlias(String name) {
    if (_didResolveAllTypeAliases || hasElement(name)) {
      return _elementsOfType<TypeAliasElement>().firstWhereOrNull((TypeAliasElement e) => e.name == name);
    }
    resolver.resolveTypeAliases(this, predicate: (TypeAlias e) => e.name.lexeme == name);
    return _elementsOfType<TypeAliasElement>().firstWhereOrNull((TypeAliasElement e) => e.name == name);
  }

  @override
  FunctionElement? getFunction(String name) {
    if (_didResolveAllFunctions || hasElement(name)) {
      return _elementsOfType<FunctionElement>().firstWhereOrNull((FunctionElement e) => e.name == name);
    }
    resolver.resolveFunctions(this, predicate: (FunctionDeclaration e) => e.name.lexeme == name);
    return _elementsOfType<FunctionElement>().firstWhereOrNull((FunctionElement e) => e.name == name);
  }

  @override
  Iterable<AnnotatedElement> annotatedWith(TypeChecker checker) sync* {
    for (final Element element in resolvedElements) {
      final ElementAnnotation? annotation = checker.firstAnnotationOf(element);
      if (annotation != null) {
        yield AnnotatedElement(element, annotation);
      }
    }
  }

  @override
  Iterable<AnnotatedElement> annotatedWithExact(TypeChecker checker) sync* {
    for (final Element element in resolvedElements) {
      final ElementAnnotation? annotation = checker.firstAnnotationOfExact(element);
      if (annotation != null) {
        yield AnnotatedElement(element, annotation);
      }
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && other is LibraryElement && runtimeType == other.runtimeType && src.id == other.src.id;

  @override
  int get hashCode => src.id.hashCode;

  @override
  DeclarationRef buildDeclarationRef(String identifier, ReferenceType type) {
    return DeclarationRef(
      identifier: identifier,
      srcId: src.id,
      srcUri: resolver.uriForAsset(src.id),
      providerId: src.id,
      type: type,
    );
  }

  @override
  List<DirectiveElement> get directives {
    if (!_didResolveDirectives) {
      resolver.resolveDirectives(this);
      _didResolveDirectives = true;
    }
    return _elementsOfType<DirectiveElement>();
  }

  @override
  String get source {
    return compilationUnit.toSource();
  }
}

/// {@template annotated_element}
/// Represents an element that has been annotated with a specific annotation.
/// {@endtemplate}
class AnnotatedElement {
  /// The annotated element.
  final Element element;

  /// The annotation associated with the element.
  final ElementAnnotation annotation;

  /// Creates an instance of [AnnotatedElement].
  AnnotatedElement(this.element, this.annotation);
}

/// {@template type_parameterized_element_mixin}
/// A mixin that implements the [TypeParameterizedElement] interface.
/// {@endtemplate}
mixin TypeParameterizedElementMixin on Element implements TypeParameterizedElement {
  final List<TypeParameterType> _typeParameters = <TypeParameterType>[];

  @override
  List<TypeParameterType> get typeParameters => _typeParameters;

  /// Adds a type parameter to this element.
  void addTypeParameter(TypeParameterType typeParameter) {
    _typeParameters.add(typeParameter);
  }

  /// Returns all type parameters of this element and its enclosing elements.
  List<TypeParameterType> get allTypeParameters {
    final List<TypeParameterType> allTypeParameters = <TypeParameterType>[];
    allTypeParameters.addAll(typeParameters);
    if (enclosingElement is TypeParameterizedElementMixin) {
      allTypeParameters.addAll((enclosingElement as TypeParameterizedElementMixin).allTypeParameters);
    }
    return allTypeParameters;
  }
}

/// {@template extension_type_impl}
/// Implementation for [ExtensionType].
/// {@endtemplate}
class ExtensionTypeImpl extends InterfaceElementImpl {
  /// Creates an instance of [ExtensionTypeImpl].
  ExtensionTypeImpl({required super.name, required super.library, required super.compilationUnit});
}

/// {@template interface_element_impl}
/// Implementation for [InterfaceElement].
/// {@endtemplate}
class InterfaceElementImpl extends ElementImpl with TypeParameterizedElementMixin implements InterfaceElement {
  final List<NamedDartType> _mixins = <NamedDartType>[];
  final List<NamedDartType> _interfaces = <NamedDartType>[];
  final List<NamedDartType> _superConstrains = <NamedDartType>[];
  NamedDartType? _superType;
  List<InterfaceType>? _allSuperTypes;
  InterfaceType? _thisType;
  final List<MethodElement> _methods = <MethodElement>[];
  final List<ConstructorElement> _constructors = <ConstructorElement>[];

  /// The AST node representing the compilation unit of this element.
  final AstNode compilationUnit;

  bool _didResolveMethods = false;
  bool _didResolveFields = false;
  bool _didResolveConstructors = false;

  final List<FieldElement> _fields = <FieldElement>[];

  /// Creates an instance of [InterfaceElementImpl].
  InterfaceElementImpl({required this.name, required this.library, required this.compilationUnit});

  @override
  List<FieldElement> get fields {
    if (!_didResolveFields) {
      library.resolver.resolveFields(this);
      _didResolveFields = true;
    }
    return List<FieldElement>.unmodifiable(_fields);
  }

  @override
  List<MethodElement> get methods {
    if (!_didResolveMethods) {
      library.resolver.resolveMethods(this);
      _didResolveMethods = true;
    }
    return List<MethodElement>.unmodifiable(_methods.whereNot((MethodElement e) => e is PropertyAccessorElementImpl));
  }

  @override
  List<PropertyAccessorElement> get accessors {
    if (!_didResolveMethods) {
      library.resolver.resolveMethods(this);
      _didResolveMethods = true;
    }
    return List<PropertyAccessorElement>.unmodifiable(_methods.whereType<PropertyAccessorElement>());
  }

  @override
  bool hasMethod(String name) {
    if (_didResolveMethods) {
      return _methods.any((MethodElement e) => e.name == name);
    }
    for (final MethodDeclaration method in compilationUnit.childEntities.whereType<MethodDeclaration>()) {
      if (method.name.lexeme == name) {
        return true;
      }
    }
    return false;
  }

  @override
  bool hasPropertyAccessor(String name) {
    if (_didResolveMethods) {
      return _methods.any((MethodElement e) => e.name == name && e is PropertyAccessorElement);
    }
    for (final MethodDeclaration method in compilationUnit.childEntities.whereType<MethodDeclaration>()) {
      if (method.name.lexeme == name && method.propertyKeyword != null) {
        return true;
      }
    }
    return false;
  }

  @override
  bool hasField(String name) {
    return _fields.any((FieldElement e) => e.name == name);
  }

  @override
  List<ConstructorElement> get constructors {
    if (!_didResolveConstructors) {
      if (!_didResolveFields) {
        library.resolver.resolveFields(this);
        _didResolveFields = true;
      }
      library.resolver.resolveConstructors(this);
      _didResolveConstructors = true;
    }
    return List<ConstructorElement>.unmodifiable(_constructors);
  }

  /// Adds a constructor to this element.
  void addConstructor(ConstructorElement constructor) {
    _constructors.add(constructor);
  }

  @override
  ConstructorElement? getConstructor(String name) {
    return constructors.firstWhereOrNull((ConstructorElement e) => e.name == name);
  }

  @override
  ConstructorElement? get unnamedConstructor {
    return constructors.firstWhereOrNull((ConstructorElement e) => e.name.isEmpty);
  }

  @override
  List<NamedDartType> get interfaces => _interfaces;

  @override
  List<NamedDartType> get mixins => _mixins;

  @override
  List<InterfaceType> get allSupertypes {
    return _allSuperTypes ??= library.resolver.allSupertypesOf(this);
  }

  @override
  List<TypeParameterType> get typeParameters => _typeParameters;

  /// Adds a mixin type to this element.
  void addMixin(NamedDartType mixin) {
    _mixins.add(mixin);
  }

  /// Adds an interface type to this element.
  void addInterface(NamedDartType interface) {
    _interfaces.add(interface);
  }

  /// Adds a Method to this element.
  void addMethod(MethodElement method) {
    _methods.add(method);
  }

  /// Adds A field to this element.
  void addField(FieldElement field) {
    _fields.add(field);
  }

  @override
  final String name;

  @override
  final LibraryElementImpl library;

  @override
  Element? get enclosingElement => library;

  set superType(NamedDartType? value) {
    _superType = value;
  }

  @override
  NamedDartType? get superType => _superType;

  set thisType(InterfaceType? value) {
    _thisType = value;
  }

  @override
  InterfaceType get thisType => _thisType!;

  @override
  FieldElement? getField(String name) {
    for (final FieldElement field in fields) {
      if (field.name == name) {
        return field;
      }
    }
    return null;
  }

  @override
  MethodElement? getMethod(String name) {
    if (_didResolveMethods) {
      for (final MethodElement method in _methods) {
        if (method.name == name) {
          return method;
        }
      }
      return null;
    }
    library.resolver.resolveMethods(
      this,
      predicate: (MethodDeclaration m) {
        return m.name.lexeme == name;
      },
    );

    for (final MethodElement method in _methods) {
      if (method.name == name) {
        return method;
      }
    }
    return null;
  }

  @override
  DartType instantiate(NamedDartType typeRef) {
    Substitution substitution = Substitution.fromPairs(typeParameters, typeRef.typeArguments);
    return substitution.substituteType(thisType, isNullable: typeRef.isNullable);
  }

  @override
  bool hasConstructor(String name) {
    return constructors.any((ConstructorElement e) => e.name == name);
  }
}

/// {@template variable_element_impl}
/// Implementation for [VariableElement].
/// {@endtemplate}
abstract class VariableElementImpl extends ElementImpl implements VariableElement {
  /// Creates an instance of [VariableElementImpl].
  VariableElementImpl({
    required this.name,
    required this.enclosingElement,
    required this.hasImplicitType,
    required this.isConst,
    required this.isFinal,
    required this.isLate,
    required this.isStatic,
    DartType? type,
  }) : _type = type;

  @override
  final Element enclosingElement;

  @override
  LibraryElement get library => enclosingElement.library;

  @override
  final bool hasImplicitType;
  @override
  final bool isConst;
  @override
  final bool isFinal;
  @override
  final bool isLate;
  @override
  final bool isStatic;
  @override
  final String name;

  @override
  bool get hasInitializer => _initializer != null;

  @override
  Expression? get initializer => _initializer;

  Expression? _initializer;

  set initializer(Expression? initializer) {
    _initializer = initializer;
  }

  /// The compute function to calculate the constant value.
  ConstantValueCompute? constantValueCompute;

  /// Sets the compute function to calculate the constant value.
  void setConstantComputeValue(ConstantValueCompute? constantValueCompute) {
    this.constantValueCompute = constantValueCompute;
  }

  @override
  Constant? get constantValue => _constantValue ??= constantValueCompute?.call();

  Constant? _constantValue;

  @override
  DartType get type => _type!;

  DartType? _type;

  set type(DartType type) {
    _type = type;
  }
}

/// {@template top_level_variable_element_impl}
/// Implementation for [TopLevelVariableElement].
/// {@endtemplate}
class TopLevelVariableElementImpl extends VariableElementImpl implements TopLevelVariableElement {
  /// Creates an instance of [TopLevelVariableElementImpl].
  TopLevelVariableElementImpl({
    required super.name,
    required super.enclosingElement,
    required super.hasImplicitType,
    required super.isConst,
    required super.isFinal,
    required super.isLate,
    required this.isExternal,
  }) : super(isStatic: false);

  @override
  final bool isExternal;

  @override
  LibraryElement get library => enclosingElement.library;
}

/// {@template field_element_impl}
/// Implementation for [FieldElement].
/// {@endtemplate}
class FieldElementImpl extends VariableElementImpl implements ClassMemberElement, FieldElement {
  /// Creates an instance of [FieldElementImpl].
  FieldElementImpl({
    required super.isStatic,
    required super.name,
    required super.enclosingElement,
    required super.hasImplicitType,
    required super.isConst,
    required super.isFinal,
    required super.isLate,
    required this.isSynthetic,
    required this.isAbstract,
    required this.isCovariant,
    required this.isEnumConstant,
    required this.isExternal,
    required this.type,
  });

  @override
  final bool isAbstract;
  @override
  final bool isCovariant;
  @override
  final bool isEnumConstant;
  @override
  final bool isExternal;

  @override
  final bool isSynthetic;

  @override
  LibraryElement get library => enclosingElement.library;

  @override
  final DartType type;

  @override
  PropertyAccessorElement? get getter {
    final Element parent = enclosingElement;
    if (parent is! InterfaceElement) return null;
    return parent.accessors.firstWhereOrNull((PropertyAccessorElement e) {
      return e.isGetter && e.name == name || e.name == '_$name';
    });
  }

  @override
  PropertyAccessorElement? get setter {
    final Element parent = enclosingElement;
    if (parent is! InterfaceElement) return null;
    return parent.accessors.firstWhereOrNull((PropertyAccessorElement e) {
      return e.isSetter && e.name == name || e.name == '_$name';
    });
  }
}

/// {@template parameter_element_impl}
/// Implementation for [ParameterElement].
/// {@endtemplate}
class ParameterElementImpl extends VariableElementImpl implements ParameterElement, VariableElement {
  /// Creates an instance of [ParameterElementImpl].
  ParameterElementImpl({
    required super.name,
    required super.enclosingElement,
    required super.hasImplicitType,
    required super.isConst,
    required super.isFinal,
    required super.isLate,
    required this.isCovariant,
    required this.isInitializingFormal,
    required this.isNamed,
    required this.isOptional,
    required this.isOptionalNamed,
    required this.isOptionalPositional,
    required this.isPositional,
    required this.isRequired,
    required this.isRequiredPositional,
    required this.isRequiredNamed,
    required this.isSuperFormal,
    super.type,
  }) : super(isStatic: false);

  @override
  LibraryElement get library => enclosingElement.library;

  @override
  String? get defaultValueCode => constantValue?.toString();

  @override
  bool get hasDefaultValue => constantValueCompute != null;

  @override
  final bool isCovariant;

  @override
  final bool isInitializingFormal;

  @override
  final bool isNamed;

  @override
  final bool isOptional;

  @override
  final bool isOptionalNamed;

  @override
  final bool isOptionalPositional;

  @override
  final bool isPositional;
  @override
  final bool isRequired;

  @override
  final bool isRequiredPositional;

  @override
  final bool isRequiredNamed;

  @override
  final bool isSuperFormal;

  @override
  List<ParameterElement> get parameters {
    final DartType type = this.type;
    if (type is FunctionType) {
      return type.parameters;
    }
    return <ParameterElement>[];
  }

  @override
  List<TypeParameterType> get typeParameters {
    final DartType type = this.type;
    if (type is FunctionType) {
      return type.typeParameters;
    }
    return <TypeParameterType>[];
  }

  /// Creates a new [ParameterElementImpl] with the specified changes.
  ParameterElementImpl changeKind({
    bool? isNamed,
    bool? isOptional,
    bool? isPositional,
    bool? isRequired,
    bool? isRequiredPositional,
    bool? isRequiredNamed,
    bool? isOptionalNamed,
    bool? isOptionalPositional,
  }) => ParameterElementImpl(
    name: name,
    enclosingElement: enclosingElement,
    hasImplicitType: hasImplicitType,
    isConst: isConst,
    isFinal: isFinal,
    isLate: isLate,
    type: _type,
    isSuperFormal: isSuperFormal,
    isCovariant: isCovariant,
    isInitializingFormal: isInitializingFormal,
    isNamed: isNamed ?? this.isNamed,
    isOptional: isOptional ?? this.isOptional,
    isOptionalNamed: isOptionalNamed ?? this.isOptionalNamed,
    isOptionalPositional: isOptionalPositional ?? this.isOptionalPositional,
    isPositional: isPositional ?? this.isPositional,
    isRequired: isRequired ?? this.isRequired,
    isRequiredPositional: isRequiredPositional ?? this.isRequiredPositional,
    isRequiredNamed: isRequiredNamed ?? this.isRequiredNamed,
  );
}

/// {@template class_element_impl}
/// Implementation for [ClassElement].
/// {@endtemplate}
class ClassElementImpl extends InterfaceElementImpl implements ClassElement {
  /// Creates an instance of [ClassElementImpl].
  ClassElementImpl({
    required super.name,
    required super.library,
    required super.compilationUnit,
    required this.hasAbstract,
    required this.hasBase,
    required this.hasFinal,
    required this.hasInterface,
    required this.isMixinApplication,
    required this.isMixinClass,
    required this.hasSealedKeyword,
  });

  @override
  final bool hasAbstract;

  @override
  final bool hasBase;

  @override
  bool get isConstructable => !hasAbstract && !hasSealedKeyword;

  @override
  final bool hasFinal;

  @override
  final bool hasInterface;

  @override
  final bool isMixinApplication;

  @override
  final bool isMixinClass;

  @override
  final bool hasSealedKeyword;
}

/// {@template enum_element_impl}
/// Implementation for [EnumElement].
/// {@endtemplate}
class EnumElementImpl extends InterfaceElementImpl implements EnumElement {
  /// Creates a new instance of [EnumElementImpl].
  EnumElementImpl({required super.name, required super.library, required super.compilationUnit});
}

/// {@template mixin_element_impl}
/// Implementation for [MixinElement].
/// {@endtemplate}
class MixinElementImpl extends InterfaceElementImpl implements MixinElement {
  /// Creates a new instance of [MixinElementImpl].
  MixinElementImpl({required super.name, required super.library, required this.isBase, required super.compilationUnit});

  @override
  final bool isBase;

  @override
  List<NamedDartType> get superclassConstraints => _superConstrains;

  /// Adds a superclass constraint to the mixin.
  void addSuperConstrain(NamedDartType superConstrains) {
    _superConstrains.add(superConstrains);
  }
}

/// {@template type_alias_element_impl}
/// Implementation for [TypeAliasElement].
/// {@endtemplate}
class TypeAliasElementImpl extends ElementImpl with TypeParameterizedElementMixin implements TypeAliasElement {
  /// Creates a new instance of [TypeAliasElementImpl].
  TypeAliasElementImpl({required this.name, required this.library});

  @override
  final String name;

  @override
  final LibraryElement library;

  @override
  Element get enclosingElement => library;

  @override
  DartType get aliasedType {
    return _aliasedType!;
  }

  DartType? _aliasedType;

  set aliasedType(DartType? aliasedType) {
    _aliasedType = aliasedType;
  }

  @override
  DartType instantiate(NamedDartType typeRef) {
    Substitution substitution = Substitution.fromPairs(typeParameters, typeRef.typeArguments);
    return substitution.substituteType(aliasedType, isNullable: typeRef.isNullable);
  }

  @override
  InterfaceType? get aliasedInterfaceType => _getTargetInterfaceType(this);

  InterfaceType? _getTargetInterfaceType(TypeAliasElement element) {
    final DartType aliasedType = element.aliasedType;
    if (aliasedType is InterfaceType) {
      return element.aliasedType as InterfaceType;
    } else if (aliasedType is TypeAliasType) {
      return _getTargetInterfaceType(aliasedType.element);
    }
    return null;
  }
}
