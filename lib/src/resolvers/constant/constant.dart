import 'package:analyzer/dart/ast/ast.dart' show Expression, ArgumentList, NamedExpression;
import 'package:collection/collection.dart' show ListEquality, MapEquality, SetEquality;
import 'package:lean_builder/element.dart';
import 'package:lean_builder/src/graph/declaration_ref.dart';
import 'package:lean_builder/src/type/type.dart';

import 'const_evaluator.dart';

/// {@template constant}
/// Base class for representing compile-time constant values.
///
/// This abstract class provides a common interface for accessing and
/// checking different types of constant values. Each subtype represents
/// a specific kind of Dart constant (primitive values, collections, objects).
/// {@endtemplate}
sealed class Constant {
  /// {@template constant.constructor}
  /// Creates a new constant value.
  /// {@endtemplate}
  const Constant();

  /// A special constant representing an invalid or unresolvable constant.
  static const Constant invalid = InvalidConst();

  /// Whether this constant represents a string value.
  bool get isString => this is ConstString;

  /// Whether this constant represents a numeric value.
  bool get isNum => this is ConstNum;

  /// Whether this constant represents an integer value.
  bool get isInt => this is ConstInt;

  /// Whether this constant represents a double value.
  bool get isDouble => this is ConstDouble;

  /// Whether this constant represents a boolean value.
  bool get isBool => this is ConstBool;

  /// Whether this constant represents a symbol.
  bool get isSymbol => this is ConstSymbol;

  /// Whether this constant represents a type reference.
  bool get isType => this is ConstType;

  /// Whether this constant represents an enum value.
  bool get isEnumValue => this is ConstEnumValue;

  /// Whether this constant represents a function reference.
  bool get isFunctionReference => this is ConstFunctionReference;

  /// Whether this constant represents a list.
  bool get isList => this is ConstList;

  /// Whether this constant represents a map.
  bool get isMap => this is ConstMap;

  /// Whether this constant represents a set.
  bool get isSet => this is ConstSet;

  /// Whether this constant represents an object.
  bool get isObject => this is ConstObject;

  /// Whether this constant represents an invalid constant.
  bool get isInvalid => this is InvalidConst;

  /// Whether this constant represents null.
  bool get isNull => this is ConstNull;

  /// Whether this constant is a literal value.
  bool get isLiteral => this is ConstLiteral<dynamic>;

  /// The literal Dart value represented by this constant.
  ///
  /// This provides access to the underlying Dart value when possible.
  /// For complex types like objects, this may return null.
  Object? get literalValue;
}

/// {@template invalid_const}
/// Represents an invalid or unresolvable constant value.
///
/// This is used when constant evaluation fails or a constant
/// cannot be properly resolved.
/// {@endtemplate}
class InvalidConst extends Constant {
  /// {@template invalid_const.constructor}
  /// Creates a new invalid constant.
  /// {@endtemplate}
  const InvalidConst();

  @override
  String toString() => 'null';

  @override
  bool operator ==(Object other) => identical(this, other) || other is InvalidConst && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;

  @override
  Object? get literalValue => null;
}

/// {@template const_literal}
/// Base class for representing literal constant values.
///
/// This abstract class provides a common implementation for constants
/// that have a direct Dart value representation.
/// {@endtemplate}
abstract class ConstLiteral<T> extends Constant {
  /// {@template const_literal.constructor}
  /// Creates a new literal constant with the given value.
  ///
  /// @param value The Dart value this constant represents
  /// {@endtemplate}
  const ConstLiteral(this.value);

  /// The actual Dart value represented by this constant.
  final T value;

  @override
  Object? get literalValue => value;

  @override
  String toString() => literalValue.toString();
}

/// {@template const_null}
/// Represents a null constant value.
/// {@endtemplate}
class ConstNull extends ConstLiteral<String> {
  /// {@template const_null.constructor}
  /// Creates a new null constant.
  /// {@endtemplate}
  const ConstNull() : super('null');

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConstNull && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// {@template const_type}
/// Represents a type constant (Type literal).
///
/// Used when a constant expression refers to a type, such as in
/// `const Type = String`.
/// {@endtemplate}
class ConstType extends Constant {
  /// {@template const_type.constructor}
  /// Creates a new type constant with the given type.
  ///
  /// @param value The Dart type this constant represents
  /// {@endtemplate}
  ConstType(this.value);

  /// The Dart type represented by this constant.
  final DartType value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConstType && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  DartType? get literalValue => value;
}

/// {@template const_string}
/// Represents a string constant value.
/// {@endtemplate}
class ConstString extends ConstLiteral<String> {
  /// {@template const_string.constructor}
  /// Creates a new string constant with the given value.
  ///
  /// @param value The string value this constant represents
  /// {@endtemplate}
  ConstString(super.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConstString && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => "'$value'";
}

/// {@template const_num}
/// Represents a numeric constant value.
///
/// This is the base class for numeric constants and can be used
/// when the specific numeric type (int or double) doesn't matter.
/// {@endtemplate}
class ConstNum extends ConstLiteral<num> {
  /// {@template const_num.constructor}
  /// Creates a new numeric constant with the given value.
  ///
  /// @param value The numeric value this constant represents
  /// {@endtemplate}
  ConstNum(super.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConstNum && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// {@template const_int}
/// Represents an integer constant value.
/// {@endtemplate}
class ConstInt extends ConstLiteral<int> {
  /// {@template const_int.constructor}
  /// Creates a new integer constant with the given value.
  ///
  /// @param value The integer value this constant represents
  /// {@endtemplate}
  ConstInt(super.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConstInt && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// {@template const_double}
/// Represents a double constant value.
/// {@endtemplate}
class ConstDouble extends ConstLiteral<double> {
  /// {@template const_double.constructor}
  /// Creates a new double constant with the given value.
  ///
  /// @param value The double value this constant represents
  /// {@endtemplate}
  ConstDouble(super.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConstDouble && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// {@template const_symbol}
/// Represents a Symbol constant value.
///
/// In Dart, Symbol constants are created using the #symbol syntax.
/// {@endtemplate}
class ConstSymbol extends ConstLiteral<String> {
  /// {@template const_symbol.constructor}
  /// Creates a new symbol constant with the given name.
  ///
  /// @param value The name of the symbol this constant represents
  /// {@endtemplate}
  ConstSymbol(super.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConstSymbol && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// {@template const_bool}
/// Represents a boolean constant value.
/// {@endtemplate}
class ConstBool extends ConstLiteral<bool> {
  /// {@template const_bool.constructor}
  /// Creates a new boolean constant with the given value.
  ///
  /// @param value The boolean value this constant represents
  /// {@endtemplate}
  ConstBool(super.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConstBool && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// {@template const_enum_value}
/// Represents an enum value constant.
///
/// Contains information about the enum type and the specific value,
/// including its index within the enum declaration.
/// {@endtemplate}
class ConstEnumValue extends Constant {
  /// The index of this enum value within its enum declaration.
  final int index;

  /// The type of the enum that contains this value.
  final InterfaceType type;

  /// The name of this enum value.
  final String value;

  /// {@template const_enum_value.constructor}
  /// Creates a new enum value constant.
  ///
  /// @param value The name of the enum value
  /// @param index The index of the enum value
  /// @param type The type of the enum
  /// {@endtemplate}
  ConstEnumValue(this.value, this.index, this.type);

  @override
  Object get literalValue => '${type.name}.$value';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstEnumValue && runtimeType == other.runtimeType && value == other.value && type == other.type;

  @override
  int get hashCode => value.hashCode ^ type.hashCode;
}

/// {@template const_function_reference}
/// Represents a function reference constant.
///
/// Function references are created using the tear-off syntax
/// (e.g., `Function func = someFunction`).
/// {@endtemplate}
abstract class ConstFunctionReference extends Constant {
  /// The name of the referenced function.
  String get name;

  /// The declaration reference to the function.
  DeclarationRef get declaration;

  /// The function type of the referenced function.
  FunctionType get type;

  /// Type arguments if the function is generic.
  List<DartType> get typeArguments;

  /// The executable element representing the function.
  ExecutableElement get element;
}

/// {@template const_function_reference_impl}
/// Implementation of a function reference constant.
/// {@endtemplate}
class ConstFunctionReferenceImpl extends ConstFunctionReference {
  @override
  FunctionType get type => element.type;

  @override
  final String name;

  @override
  final DeclarationRef declaration;

  @override
  final ExecutableElement element;

  /// {@template const_function_reference_impl.constructor}
  /// Creates a new function reference constant.
  ///
  /// @param name The name of the function
  /// @param element The executable element for the function
  /// @param declaration The declaration reference to the function
  /// {@endtemplate}
  ConstFunctionReferenceImpl({
    required this.name,
    required this.element,
    required this.declaration,
  });

  @override
  String toString() => name;

  @override
  List<DartType> get typeArguments => _typeArguments;

  final List<DartType> _typeArguments = <DartType>[];

  /// Adds a type argument to this function reference.
  ///
  /// Used when the referenced function has generic type parameters.
  ///
  /// @param type The type argument to add
  void addTypeArgument(DartType type) {
    _typeArguments.add(type);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstFunctionReferenceImpl &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          name == other.name &&
          declaration == other.declaration &&
          const ListEquality<DartType>().equals(
            _typeArguments,
            other._typeArguments,
          );

  @override
  int get hashCode =>
      type.hashCode ^ name.hashCode ^ declaration.hashCode ^ const ListEquality<DartType>().hash(_typeArguments);

  @override
  Object? get literalValue => null;
}

/// {@template const_list}
/// Represents a list constant value.
///
/// Contains a list of other constant values, representing a constant list
/// expression like `const [1, 2, 3]`.
/// {@endtemplate}
class ConstList extends ConstLiteral<List<Constant>> {
  /// {@template const_list.constructor}
  /// Creates a new list constant with the given elements.
  ///
  /// @param value The list of constant elements
  /// {@endtemplate}
  ConstList(super.value);

  @override
  String toString() => '[${value.map((Constant e) => e.toString()).join(', ')}]';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstList &&
          runtimeType == other.runtimeType &&
          const ListEquality<Constant>().equals(value, other.value);

  @override
  int get hashCode => const ListEquality<Constant>().hash(value);

  @override
  List<dynamic> get literalValue => value.map((Constant e) => e.literalValue).toList();
}

/// {@template const_map}
/// Represents a map constant value.
///
/// Contains a mapping of constant keys to constant values, representing
/// a constant map expression like `const {'key': 'value'}`.
/// {@endtemplate}
class ConstMap extends ConstLiteral<Map<Constant, Constant>> {
  /// {@template const_map.constructor}
  /// Creates a new map constant with the given entries.
  ///
  /// @param value The map of constant key-value pairs
  /// {@endtemplate}
  ConstMap(super.value);

  @override
  String toString() => '{${value.entries.map((MapEntry<Constant, Constant> e) => '${e.key}: ${e.value}').join(', ')}}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstMap &&
          runtimeType == other.runtimeType &&
          const MapEquality<Constant, Constant>().equals(value, other.value);

  @override
  int get hashCode => const MapEquality<Constant, Constant>().hash(value);

  @override
  Map<dynamic, dynamic> get literalValue => value.map(
    (Constant k, Constant v) => MapEntry<dynamic, dynamic>(k.literalValue, v.literalValue),
  );
}

/// {@template const_set}
/// Represents a set constant value.
///
/// Contains a set of other constant values, representing a constant set
/// expression like `const {1, 2, 3}`.
/// {@endtemplate}
class ConstSet extends ConstLiteral<Set<Constant>> {
  /// {@template const_set.constructor}
  /// Creates a new set constant with the given elements.
  ///
  /// @param value The set of constant elements
  /// {@endtemplate}
  ConstSet(super.value);

  @override
  String toString() => '{${value.map((Constant e) => e.toString()).join(', ')}}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstSet && runtimeType == other.runtimeType && const SetEquality<Constant>().equals(value, other.value);

  @override
  int get hashCode => const SetEquality<Constant>().hash(value);

  @override
  Set<dynamic> get literalValue => value.map((Constant e) => e.literalValue).toSet();
}

/// {@template const_object}
/// Represents a constant object value.
///
/// This abstract class provides a common interface for accessing properties
/// of constant objects, such as those created with `const MyClass(...)`.
/// {@endtemplate}
abstract class ConstObject extends Constant {
  /// {@template const_object.constructor}
  /// Creates a new constant object.
  /// {@endtemplate}
  ConstObject() : super();

  /// The type of the constant object.
  DartType get type;

  /// The name of the constructor used to create the constant.
  ///
  /// This is null for the default constructor.
  String? get constructorName;

  /// The constructor arguments used to create the constant.
  List<Expression> get constructorArguments;

  /// The properties of the constant object.
  Map<String, Constant?> get props;

  /// Gets a property value by name.
  ///
  /// @param key The property name
  /// @return The property value, or null if not found
  Constant? get(String key) => props[key];

  /// Gets a type reference property by name.
  ///
  /// @param key The property name
  /// @return The type reference, or null if not found or not a type
  ConstType? getTypeRef(String key) => props[key] as ConstType?;

  /// Gets a string property by name.
  ///
  /// @param key The property name
  /// @return The string value, or null if not found or not a string
  ConstString? getString(String key);

  /// Gets an integer property by name.
  ///
  /// @param key The property name
  /// @return The integer value, or null if not found or not an integer
  ConstInt? getInt(String key);

  /// Gets a double property by name.
  ///
  /// @param key The property name
  /// @return The double value, or null if not found or not a double
  ConstDouble? getDouble(String key);

  /// Gets a numeric property by name.
  ///
  /// @param key The property name
  /// @return The numeric value, or null if not found or not a number
  ConstNum? getNum(String key);

  /// Gets a boolean property by name.
  ///
  /// @param key The property name
  /// @return The boolean value, or null if not found or not a boolean
  ConstBool? getBool(String key);

  /// Gets an object property by name.
  ///
  /// @param key The property name
  /// @return The object value, or null if not found or not an object
  ConstObject? getObject(String key);

  /// Gets a list property by name.
  ///
  /// @param key The property name
  /// @return The list value, or null if not found or not a list
  ConstList? getList(String key);

  /// Gets a map property by name.
  ///
  /// @param key The property name
  /// @return The map value, or null if not found or not a map
  ConstMap? getMap(String key);

  /// Gets a set property by name.
  ///
  /// @param key The property name
  /// @return The set value, or null if not found or not a set
  ConstSet? getSet(String key);

  /// Gets an enum value property by name.
  ///
  /// @param key The property name
  /// @return The enum value, or null if not found or not an enum value
  ConstEnumValue? getEnumValue(String key);

  /// Gets a function reference property by name.
  ///
  /// @param key The property name
  /// @return The function reference, or null if not found or not a function reference
  ConstFunctionReference? getFunctionReference(String key);
}

/// {@template const_object_impl}
/// Implementation of a constant object.
///
/// This class represents objects created with constant constructors
/// and provides typed access to their properties.
/// {@endtemplate}
class ConstObjectImpl extends ConstObject {
  /// {@template const_object_impl.constructor}
  /// Creates a new constant object with the given properties and type.
  ///
  /// @param props The properties of the object
  /// @param type The type of the object
  /// @param positionalNames Mapping of positional parameter indices to names
  /// @param constructorName The name of the constructor used (null for default)
  /// @param constructorArguments The constructor arguments used
  /// {@endtemplate}
  ConstObjectImpl(
    this.props,
    this.type, {
    this.positionalNames = const <int, String>{},
    this.constructorName,
    this.constructorArguments = const <Expression>[],
  });

  @override
  final DartType type;

  @override
  final Map<String, Constant?> props;

  /// Mapping of positional parameter indices to names.
  ///
  /// Used to resolve positional arguments to named properties.
  final Map<int, String> positionalNames;

  @override
  String toString() => '{${props.entries.map((MapEntry<String, Constant?> e) => '${e.key}: ${e.value}').join(', ')}}';

  @override
  ConstString? getString(String key) => _getTyped<ConstString>(key);

  @override
  ConstInt? getInt(String key) => _getTyped<ConstInt>(key);

  @override
  ConstDouble? getDouble(String key) => _getTyped<ConstDouble>(key);

  @override
  ConstNum? getNum(String key) => _getTyped<ConstNum>(key);

  @override
  ConstBool? getBool(String key) => _getTyped<ConstBool>(key);

  @override
  ConstObject? getObject(String key) => _getTyped<ConstObject>(key);

  @override
  ConstList? getList(String key) => _getTyped<ConstList>(key);

  @override
  ConstMap? getMap(String key) => _getTyped<ConstMap>(key);

  @override
  ConstSet? getSet(String key) => _getTyped<ConstSet>(key);

  @override
  ConstEnumValue? getEnumValue(String key) => _getTyped<ConstEnumValue>(key);

  @override
  ConstFunctionReference? getFunctionReference(String key) => _getTyped<ConstFunctionReference>(key);

  /// Helper method for retrieving typed properties.
  ///
  /// @param key The property name
  /// @return The typed property value, or null if not found
  /// @throws Exception if the property exists but has the wrong type
  T? _getTyped<T extends Constant>(String key) {
    final Constant? value = props[key];
    if (value == null) {
      return null;
    }
    if (value is T) {
      return value;
    }
    throw Exception(
      'Value for $key is expected to be $T, but got ${value.runtimeType}',
    );
  }

  /// Creates a new constant object by applying constructor arguments to this object.
  ///
  /// This is used during constant evaluation to create new objects based on
  /// existing ones with constructor arguments applied.
  ///
  /// @param args The argument list from the constructor call
  /// @param evaluator The constant evaluator to evaluate arguments
  /// @param name The constructor name (optional)
  /// @return A new constant object with arguments applied
  ConstObjectImpl construct(
    ArgumentList args,
    ConstantEvaluator evaluator, [
    String? name,
  ]) {
    final Map<String, Constant?> props = Map<String, Constant?>.of(this.props);
    for (int i = 0; i < args.arguments.length; i++) {
      final Expression arg = args.arguments[i];
      if (arg is NamedExpression) {
        final String name = arg.name.label.name;
        props[name] = evaluator.evaluate(arg.expression);
      } else {
        final String? name = positionalNames[i];
        if (name != null) {
          props[name] = evaluator.evaluate(arg);
        }
      }
    }
    return ConstObjectImpl(
      props,
      type,
      positionalNames: positionalNames,
      constructorName: name,
      constructorArguments: List<Expression>.of(args.arguments),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstObjectImpl &&
          runtimeType == other.runtimeType &&
          const MapEquality<String, Constant?>().equals(props, other.props) &&
          type == other.type;

  @override
  int get hashCode => const MapEquality<String, Constant?>().hash(props) ^ type.hashCode;

  @override
  final List<Expression> constructorArguments;

  @override
  final String? constructorName;

  @override
  Object? get literalValue => null;
}
