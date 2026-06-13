part of 'type.dart';

/// {@template void_type}
/// Represents the 'void' type in Dart.
///
/// The void type is used to indicate that a function doesn't return a value.
/// {@endtemplate}
class VoidType extends NonElementType {
  const VoidType._() : super('void', isNullable: false);

  /// The singleton instance of the void type.
  static const VoidType instance = VoidType._();

  @override
  bool get isVoid => true;
}

/// {@template dynamic_type}
/// Represents the 'dynamic' type in Dart.
///
/// The dynamic type represents a value of any type, with runtime type checking.
/// {@endtemplate}
class DynamicType extends NonElementType {
  const DynamicType._() : super('dynamic', isNullable: true);

  /// The singleton instance of the dynamic type.
  static const DynamicType instance = DynamicType._();

  @override
  bool get isDynamic => true;
}

/// {@template never_type}
/// Represents the 'Never' type in Dart.
///
/// The Never type indicates that an expression never completes normally.
/// {@endtemplate}
class NeverType extends NonElementType {
  const NeverType._() : super('Never', isNullable: false);

  /// The singleton instance of the Never type.
  static const NeverType instance = NeverType._();

  @override
  bool get isNever => true;
}

/// {@template invalid_type}
/// Represents an invalid type in Dart.
///
/// Used to indicate that a type cannot be resolved or is otherwise invalid.
/// {@endtemplate}
class InvalidType extends NonElementType {
  const InvalidType._() : super('Invalid', isNullable: false);

  /// The singleton instance of the invalid type.
  static const InvalidType instance = InvalidType._();

  @override
  bool get isInvalid => true;
}

/// {@template unknown_inferred_type}
/// Represents a type that couldn't be inferred.
///
/// Used in type inference when the type couldn't be determined.
/// {@endtemplate}
class UnknownInferredType extends NonElementType {
  const UnknownInferredType._() : super('UnknownInferred', isNullable: false);

  /// The singleton instance of the unknown inferred type.
  static const UnknownInferredType instance = UnknownInferredType._();
}

/// {@template interface_type_impl}
/// Implementation of the [InterfaceType] interface.
///
/// Represents class types in Dart, including core types like String, List, etc.
/// {@endtemplate}
class InterfaceTypeImpl extends TypeImpl implements InterfaceType {
  /// The unique identifier for this interface type in the form `name@declarationRef.srcId`.
  @override
  String get identifier => '$name@${declarationRef.srcId}';

  /// The resolver used to resolve this interface type.
  @override
  final ResolverImpl resolver;

  /// The type arguments applied to this interface type.
  @override
  final List<DartType> typeArguments;

  /// The name of this interface type.
  @override
  final String name;

  /// Reference to the declaration of this interface type.
  @override
  final DeclarationRef declarationRef;

  /// Creates a new [InterfaceTypeImpl] with the given properties.
  InterfaceTypeImpl(
    this.name,
    this.declarationRef,
    this.resolver, {
    super.isNullable = false,
    this.typeArguments = const <DartType>[],
    this._element,
  });

  String get _srcName => declarationRef.srcUri.toString();

  @override
  bool get isDartCoreBool => name == 'bool' && _srcName == CoreTypeSource.coreBool;

  @override
  bool get isDartCoreDouble => name == 'double' && _srcName == CoreTypeSource.coreDouble;

  @override
  bool get isDartCoreEnum => name == 'Enum' && _srcName == CoreTypeSource.coreEnum;

  @override
  bool get isDartCoreFunction => name == 'Function' && _srcName == CoreTypeSource.coreFunction;

  @override
  bool get isDartCoreInt => name == 'int' && _srcName == CoreTypeSource.coreInt;

  @override
  bool get isDartCoreNum => name == 'num' && _srcName == CoreTypeSource.coreNum;

  @override
  bool get isDartCoreIterable => name == 'Iterable' && _srcName == CoreTypeSource.coreIterable;

  @override
  bool get isDartCoreList => name == 'List' && _srcName == CoreTypeSource.coreList;

  @override
  bool get isDartCoreMap => name == 'Map' && _srcName == CoreTypeSource.coreMap;

  @override
  bool get isDartCoreNull => name == 'Null' && _srcName == CoreTypeSource.coreNull;

  @override
  bool get isDartCoreObject => name == 'Object' && _srcName == CoreTypeSource.coreObject;

  @override
  bool get isDartCoreRecord => name == 'Record' && _srcName == CoreTypeSource.coreRecord;

  @override
  bool get isDartCoreSet => name == 'Set' && _srcName == CoreTypeSource.coreSet;

  @override
  bool get isDartCoreString => name == 'String' && _srcName == CoreTypeSource.coreString;

  @override
  bool get isDartCoreSymbol => name == 'Symbol' && _srcName == CoreTypeSource.coreSymbol;

  @override
  bool get isDartCoreType => name == 'Type' && _srcName == CoreTypeSource.coreType;

  @override
  bool get isDartAsyncFuture => name == 'Future' && _srcName == CoreTypeSource.asyncFuture;

  @override
  bool get isDartAsyncFutureOr => name == 'FutureOr' && _srcName == CoreTypeSource.asyncFutureOr;

  @override
  bool get isDartAsyncStream => name == 'Stream' && _srcName == CoreTypeSource.asyncStream;

  @override
  bool get isDartCoreBigInt => name == 'BigInt' && _srcName == CoreTypeSource.coreBigInt;

  @override
  bool get isDartCoreDateTime => name == 'DateTime' && _srcName == CoreTypeSource.coreDateTime;

  @override
  bool get isEnum => declarationRef.type == ReferenceType.$enum;

  @override
  bool get isClass => declarationRef.type == ReferenceType.$class;

  @override
  bool get isMixin => declarationRef.type == ReferenceType.$mixin;

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer();
    buffer.write(name);
    if (typeArguments.isNotEmpty) {
      buffer.write('<');
      buffer.write(typeArguments.map((DartType e) => e.toString()).join(', '));
      buffer.write('>');
    }
    if (isNullable) {
      buffer.write('?');
    }
    return buffer.toString();
  }

  /// Returns a copy of this interface type with the specified nullability.
  @override
  InterfaceTypeImpl withNullability(bool isNullable) {
    if (this.isNullable == isNullable) {
      return this;
    }
    return InterfaceTypeImpl(
      name,
      declarationRef,
      resolver,
      isNullable: isNullable,
      typeArguments: typeArguments,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InterfaceTypeImpl &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          declarationRef.srcId == other.declarationRef.srcId &&
          const ListEquality<DartType>().equals(
            typeArguments,
            other.typeArguments,
          );

  @override
  int get hashCode =>
      name.hashCode ^ declarationRef.srcId.hashCode ^ const ListEquality<DartType>().hash(typeArguments);

  /// Determines if this type is exactly the same as [other].
  @override
  bool isExactly(DartType other) {
    if (other is NamedDartType) {
      return name == other.name && declarationRef.srcId == other.declarationRef.srcId;
    }
    return false;
  }

  InterfaceElement? _element;

  /// Resolves the element associated with this interface type.
  InterfaceElement _resolveElement() {
    final Element? ele = resolver.elementOf(this);
    if (ele is! InterfaceElement) {
      throw Exception(
        'Element of $this (${ele.runtimeType}) is not an InterfaceElement',
      );
    }
    return ele;
  }

  /// The element that declares this interface type.
  @override
  InterfaceElement get element => _element ??= _resolveElement();

  /// Returns all direct and indirect supertypes of this interface type.
  @override
  List<NamedDartType> get allSupertypes => element.allSupertypes;

  /// Returns the interfaces implemented by this interface type.
  @override
  List<NamedDartType> get interfaces => element.interfaces;

  /// Returns the mixins applied to this interface type.
  @override
  List<NamedDartType> get mixins => element.mixins;

  /// Returns the super type of this interface type.
  @override
  NamedDartType? get superType => element.superType;

  /// Returns the constructor with the given [name], or null if not found.
  @override
  ConstructorElement? getConstructor(String name) {
    return element.getConstructor(name);
  }

  /// Returns the field with the given [name], or null if not found.
  @override
  FieldElement? getField(String name) {
    return element.getField(name);
  }

  /// Returns the method with the given [name], or null if not found.
  @override
  MethodElement? getMethod(String name) {
    return element.getMethod(name);
  }

  /// Returns true if this type has a constructor with the given [name].
  @override
  bool hasConstructor(String name) {
    return element.hasConstructor(name);
  }

  /// Returns true if this type has a field with the given [name].
  @override
  bool hasField(String name) {
    return element.hasField(name);
  }

  /// Returns true if this type has a method with the given [name].
  @override
  bool hasMethod(String name) {
    return element.hasMethod(name);
  }

  /// Returns true if this type has a property accessor with the given [name].
  @override
  bool hasPropertyAccessor(String name) {
    return element.hasPropertyAccessor(name);
  }
}

/// {@template type_alias_type_impl}
/// Implementation of the [TypeAliasType] interface.
///
/// Represents a type alias defined using the `typedef` keyword.
/// {@endtemplate}
class TypeAliasTypeImpl extends TypeImpl implements TypeAliasType {
  /// The type arguments applied to this type alias.
  @override
  final List<DartType> typeArguments;

  /// The resolver used to resolve this type alias.
  @override
  final ResolverImpl resolver;

  /// The name of this type alias.
  @override
  final String name;

  /// Reference to the declaration of this type alias.
  @override
  final DeclarationRef declarationRef;

  /// Creates a new [TypeAliasTypeImpl] with the given properties.
  TypeAliasTypeImpl(
    this.name,
    this.declarationRef,
    this.resolver, {
    super.isNullable = false,
    this.typeArguments = const <DartType>[],
  });

  /// The element that declares this type alias.
  @override
  TypeAliasElement get element => _element ??= _resolveElement();

  TypeAliasElement? _element;

  /// Resolves the element associated with this type alias.
  TypeAliasElement _resolveElement() {
    final Element? ele = resolver.elementOf(this);
    if (ele is! TypeAliasElement) {
      throw Exception('Element of $this is not a TypeAliasElement');
    }
    return ele;
  }

  /// The unique identifier for this type alias in the form `name@declarationRef.srcId`.
  @override
  String get identifier => '$name@${declarationRef.srcId}';

  /// Determines if this type is exactly the same as [other].
  @override
  bool isExactly(DartType other) {
    if (other is TypeAliasTypeImpl) {
      return name == other.name && declarationRef.srcId == other.declarationRef.srcId;
    }
    return false;
  }

  /// Returns a copy of this type alias with the specified nullability.
  @override
  DartType withNullability(bool isNullable) {
    if (this.isNullable == isNullable) {
      return this;
    }
    return TypeAliasTypeImpl(
      name,
      declarationRef,
      resolver,
      isNullable: isNullable,
      typeArguments: typeArguments,
    );
  }
}

/// {@template function_type}
/// Represents a function type in Dart.
///
/// Function types describe the signature of functions, including their
/// parameters, return type, and type parameters.
/// {@endtemplate}
class FunctionType extends TypeImpl {
  /// The parameters of this function type.
  final List<ParameterElement> parameters;

  /// The type parameters of this function type.
  final List<TypeParameterType> typeParameters;

  /// The return type of this function type.
  final DartType returnType;

  /// Creates a new [FunctionType] with the given properties.
  FunctionType({
    required super.isNullable,
    required this.parameters,
    this.typeParameters = const <TypeParameterType>[],
    required this.returnType,
  });

  /// Returns a copy of this function type with the specified nullability.
  @override
  FunctionType withNullability(bool isNullable) {
    if (this.isNullable == isNullable) {
      return this;
    }
    return FunctionType(
      isNullable: isNullable,
      parameters: parameters,
      typeParameters: typeParameters,
      returnType: returnType,
    );
  }

  @override
  String toString() {
    final Iterable<ParameterElement> requiredPositionalParams = parameters.where(
      (ParameterElement p) => p.isRequiredPositional,
    );
    final Iterable<ParameterElement> optionalPositionalParams = parameters.where(
      (ParameterElement p) => p.isOptionalPositional,
    );
    final Iterable<ParameterElement> namedParams = parameters.where(
      (ParameterElement p) => p.isNamed,
    );

    final StringBuffer buffer = StringBuffer();
    if (returnType != DartType.neverType) {
      buffer.write('$returnType ');
    }
    if (typeParameters.isNotEmpty) {
      buffer.write('<');
      buffer.write(typeParameters.toString());
      buffer.write('>');
    }
    buffer.write('Function');
    if (parameters.isNotEmpty) {
      buffer.write('(');
      if (requiredPositionalParams.isNotEmpty) {
        buffer.write(
          requiredPositionalParams.map((ParameterElement e) => '${e.type} ${e.name}').join(', '),
        );
      }
      if (optionalPositionalParams.isNotEmpty) {
        if (requiredPositionalParams.isNotEmpty) {
          buffer.write(', ');
        }
        buffer.write('[');
        buffer.write(
          optionalPositionalParams.map((ParameterElement e) => '${e.type} ${e.name}').join(', '),
        );
        buffer.write(']');
      }
      if (namedParams.isNotEmpty) {
        if (requiredPositionalParams.isNotEmpty || optionalPositionalParams.isNotEmpty) {
          buffer.write(', ');
        }
        buffer.write('{');
        buffer.write(
          namedParams.map((ParameterElement e) => '${e.type} ${e.name}').join(', '),
        );
        buffer.write('}');
      }
      buffer.write(')');
    }
    if (isNullable) {
      buffer.write('?');
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FunctionType &&
          runtimeType == other.runtimeType &&
          const ListEquality<ParameterElement>().equals(
            parameters,
            other.parameters,
          ) &&
          const ListEquality<TypeParameterType>().equals(
            typeParameters,
            other.typeParameters,
          ) &&
          returnType == other.returnType;

  @override
  int get hashCode =>
      const ListEquality<ParameterElement>().hash(parameters) ^
      const ListEquality<TypeParameterType>().hash(typeParameters) ^
      returnType.hashCode;

  /// A map of named parameter names to their types.
  Map<String, DartType> get namedParameterTypes {
    Map<String, DartType> types = <String, DartType>{};
    for (final ParameterElement parameter in parameters) {
      if (parameter.isNamed && parameter.isRequiredNamed) {
        types[parameter.name] = parameter.type;
      }
    }
    return types;
  }

  /// A list of types for all required positional parameters.
  List<DartType> get normalParameterTypes {
    List<DartType> types = <DartType>[];
    for (final ParameterElement parameter in parameters) {
      if (parameter.isRequired) {
        types.add(parameter.type);
      }
    }
    return types;
  }

  /// A list of types for all optional parameters (either positional or named).
  List<DartType> get optionalParameterTypes {
    List<DartType> types = <DartType>[];
    for (final ParameterElement parameter in parameters) {
      if (parameter.isOptional) {
        types.add(parameter.type);
      }
    }
    return types;
  }

  /// A list of names for required positional parameters.
  List<String> get normalParameterNames =>
      parameters.where((ParameterElement p) => p.isRequiredPositional).map((ParameterElement p) => p.name).toList();

  /// A list of names for optional positional parameters.
  List<String> get optionalParameterNames =>
      parameters.where((ParameterElement p) => p.isOptionalPositional).map((ParameterElement p) => p.name).toList();

  @override
  Null get element => null;

  /// Creates a new function type by instantiating this generic function
  /// with the provided type arguments.
  FunctionType instantiate(List<DartType> argumentTypes) {
    if (argumentTypes.length != typeParameters.length) {
      throw ArgumentError(
        "argumentTypes.length (${argumentTypes.length}) != "
        "typeParameters.length (${typeParameters.length})",
      );
    }
    if (argumentTypes.isEmpty) {
      return this;
    }

    Substitution substitution = Substitution.fromPairs(
      typeParameters,
      argumentTypes,
    );

    final List<ParameterElement> newParams = List<ParameterElement>.of(
      parameters,
    );
    for (final ParameterElementImpl param in parameters.whereType<ParameterElementImpl>()) {
      param.type = substitution.substituteType(param.type);
    }

    return FunctionType(
      returnType: substitution.substituteType(returnType),
      typeParameters: const <TypeParameterType>[],
      parameters: newParams,
      isNullable: isNullable,
    );
  }
}

/// {@template type_parameter_type}
/// Represents a type parameter in a generic class or method.
///
/// For example, in `class List&lt;T&gt;`, `T` is a type parameter.
/// {@endtemplate}
class TypeParameterType extends TypeImpl {
  /// The bound of this type parameter.
  final DartType bound;

  /// The promoted bound of this type parameter, if any.
  ///
  /// This is used in type promotion contexts.
  final DartType? promotedBound;

  /// The name of this type parameter.
  @override
  final String name;

  /// Creates a new [TypeParameterType] with the given properties.
  TypeParameterType(
    this.name, {
    required this.bound,
    super.isNullable = false,
    this.promotedBound,
  });

  /// Returns a copy of this type parameter with the specified nullability.
  @override
  TypeParameterType withNullability(bool isNullable) {
    if (this.isNullable == isNullable) {
      return this;
    }
    return TypeParameterType(name, bound: bound, isNullable: isNullable);
  }

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer();
    buffer.write(name);
    if (bound != DartType.dynamicType) {
      buffer.write(' extends ');
      buffer.write(bound.toString());
    }
    if (isNullable) {
      buffer.write('?');
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypeParameterType && runtimeType == other.runtimeType && bound == other.bound && name == other.name;

  @override
  int get hashCode => bound.hashCode;

  @override
  Null get element => null;
}

/// {@template record_type}
/// Represents a record type in Dart.
///
/// Record types are composite types with named and/or positional fields.
/// For example: `(int, String, {bool flag})`.
/// {@endtemplate}
class RecordType extends TypeImpl {
  /// The named fields of this record type.
  List<RecordTypeNamedField> namedFields;

  /// The positional fields of this record type.
  List<RecordTypePositionalField> positionalFields;

  /// Creates a new [RecordType] with the given properties.
  RecordType({
    required this.positionalFields,
    required this.namedFields,
    required super.isNullable,
  });

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer();
    buffer.write('(');
    if (positionalFields.isNotEmpty) {
      buffer.write(
        positionalFields
            .mapIndexed(
              (int i, RecordTypePositionalField e) => '${e.type} ${r'$'}${i + 1}',
            )
            .join(', '),
      );
    }
    if (namedFields.isNotEmpty) {
      if (positionalFields.isNotEmpty) {
        buffer.write(', ');
      }
      buffer.write('{');
      buffer.write(
        namedFields.map((RecordTypeNamedField e) => '${e.type} ${e.name}').join(', '),
      );
      buffer.write('}');
    }
    buffer.write(')');
    if (isNullable) {
      buffer.write('?');
    }
    return buffer.toString();
  }

  /// Returns a copy of this record type with the specified nullability.
  @override
  RecordType withNullability(bool isNullable) {
    if (this.isNullable == isNullable) {
      return this;
    }
    return RecordType(
      positionalFields: positionalFields,
      namedFields: namedFields,
      isNullable: isNullable,
    );
  }

  @override
  Element? get element => null;
}

/// {@template record_type_named_field}
/// Represents a named field in a [RecordType].
///
/// For example, in `(int, {String name})`, `name` is a named field.
/// {@endtemplate}
class RecordTypeNamedField implements RecordTypeField {
  /// The name of this field.
  final String name;

  /// The type of this field.
  @override
  final DartType type;

  /// Creates a new [RecordTypeNamedField] with the given name and type.
  RecordTypeNamedField(this.name, this.type);
}

/// {@template record_type_positional_field}
/// Represents a positional field in a [RecordType].
///
/// For example, in `(int, String)`, the `int` and `String` are positional fields.
/// {@endtemplate}
class RecordTypePositionalField implements RecordTypeField {
  /// The type of this positional field.
  @override
  final DartType type;

  /// Creates a new [RecordTypePositionalField] with the given type.
  const RecordTypePositionalField(this.type);
}

/// {@template synthetic_named_type}
/// Represents a synthetic named type.
///
/// This is used for types unresolved by the resolver at build time.
///
/// e.g class A with _$A { } _$A would be a synthetic named type since it can't be
/// resolved at build time.
/// {@endtemplate}
class SyntheticNamedType extends TypeImpl implements NamedDartType {
  /// Creates a new [SyntheticNamedType] with the given name and resolver.
  const SyntheticNamedType(
    this.name,
    this.resolver, {
    required super.isNullable,
  });

  @override
  final String name;

  @override
  DeclarationRef get declarationRef => DeclarationRef(
    identifier: name,
    srcId: '',
    providerId: '',
    type: ReferenceType.unknown,
    srcUri: Uri(),
  );

  @override
  Element? get element => null;

  @override
  String get identifier => name;

  @override
  bool isExactly(DartType other) => false;

  @override
  final Resolver resolver;

  @override
  List<DartType> get typeArguments => const <DartType>[];

  @override
  DartType withNullability(bool isNullable) {
    return SyntheticNamedType(name, resolver, isNullable: isNullable);
  }
}
