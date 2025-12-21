import 'package:lean_builder/element.dart';
import 'package:lean_builder/src/type/substitution.dart';
import 'package:lean_builder/src/type/type_utils.dart';
import 'package:lean_builder/src/type/variance.dart';
import 'package:lean_builder/type.dart';

/// Helper for checking the subtype relation.
///
/// https://github.com/dart-lang/language
/// See `resources/type-system/subtyping.md`
class SubtypeHelper {
  final InterfaceType _nullNone;
  final InterfaceType _objectNone;
  final InterfaceType _objectQuestion;
  final DynamicType _dynamicType = DartType.dynamicType;
  final NeverType _neverType = DartType.neverType;
  final UnknownInferredType _unknownInferredType = DartType.unknownInferredType;
  final InvalidType _invalidType = DartType.invalidType;
  final VoidType _voidType = DartType.voidType;

  final TypeUtils _typeUtils;

  /// Create a [SubtypeHelper] instance.
  SubtypeHelper(this._typeUtils)
    : _nullNone = _typeUtils.nullTypeObject,
      _objectNone = _typeUtils.objectType,
      _objectQuestion = _typeUtils.objectTypeNullable;

  /// Return `true` if [T0_] is a subtype of [T1_].
  bool isSubtypeOf(DartType t0, DartType t1) {
    // Reflexivity: if `T0` and `T1` are the same type then `T0 <: T1`.
    if (identical(t0, t1)) {
      return true;
    }

    // // `_` is treated as a top and a bottom type during inference.
    if (identical(t0, _unknownInferredType) || identical(t1, _unknownInferredType)) {
      return true;
    }

    // `InvalidType` is treated as a top and a bottom type.
    if (identical(t0, DartType.invalidType) || identical(t1, DartType.invalidType)) {
      return true;
    }

    // Right Top: if `T1` is a top type (i.e. `dynamic`, or `void`, or
    // `Object?`) then `T0 <: T1`.
    if (identical(t1, _dynamicType) ||
        identical(t1, _invalidType) ||
        identical(t1, _voidType) ||
        t1.isNullable && t1.isDartCoreObject) {
      return true;
    }

    // Left Top: if `T0` is `dynamic` or `void`,
    //   then `T0 <: T1` if `Object? <: T1`.
    if (identical(t0, _dynamicType) || identical(t0, _invalidType) || identical(t0, _voidType)) {
      if (isSubtypeOf(_objectQuestion, t1)) {
        return true;
      }
    }

    // Left Bottom: if `T0` is `Never`, then `T0 <: T1`.
    if (identical(t0, _neverType)) {
      return true;
    }

    // Right Object: if `T1` is `Object` then:
    if (!t1.isNullable && t1.isDartCoreObject) {
      // * if `T0` is an unpromoted type variable with bound `B`,
      //   then `T0 <: T1` iff `B <: Object`.
      // * if `T0` is a promoted type variable `X & S`,
      //   then `T0 <: T1` iff `S <: Object`.
      if (!t0.isNullable && t0 is TypeParameterType) {
        DartType? S = t0.promotedBound;
        if (S == null) {
          DartType B = t0.bound.isDynamic ? _objectQuestion : t0.bound;
          return isSubtypeOf(B, _objectNone);
        } else {
          return isSubtypeOf(S, _objectNone);
        }
      }
      // * if `T0` is `FutureOr<S>` for some `S`,
      //   then `T0 <: T1` iff `S <: Object`
      if (!t0.isNullable && t0 is InterfaceTypeImpl && t0.isDartAsyncFutureOr) {
        return isSubtypeOf(t0.typeArguments[0], t1);
      }

      // * if `T0` is `Null`, `dynamic`, `void`, or `S?` for any `S`,
      //   then the subtyping does not hold, the result is false.
      if (!t0.isNullable && t0.isDartCoreNull ||
          identical(t0, _dynamicType) ||
          identical(t0, _invalidType) ||
          identical(t0, _voidType) ||
          t0.isNullable) {
        return false;
      }
      // Extension types:
      //   If `R` is a non-nullable type then `V0` is a proper subtype
      //   of `Object`, and a non-nullable type.
      if (t0 is InterfaceTypeImpl && t0.element is ExtensionTypeImpl) {
        if (t0.superType case final NamedDartType representationType?) {
          if (_typeUtils.isNullable(representationType)) {
            return false;
          }
        }
      }
      // Otherwise `T0 <: T1` is true.
      return true;
    }

    // Left Null: if `T0` is `Null` then:
    if (!t0.isNullable && t0.isDartCoreNull) {
      // * If `T1` is `FutureOr<S>` for some `S`, then the query is true iff
      // `Null <: S`.
      if (!t1.isNullable && t1 is InterfaceTypeImpl && t1.isDartAsyncFutureOr) {
        DartType S = t1.typeArguments[0];
        return isSubtypeOf(_nullNone, S);
      }
      // If `T1` is `Null`, `S?` or `S*` for some `S`, then the query is true.
      if (!t1.isNullable && t1.isDartCoreNull || t1.isNullable) {
        return true;
      }
      // * if `T1` is a type variable (promoted or not) the query is false
      if (t1 is TypeParameterType) {
        return false;
      }
      // Otherwise, the query is false.
      return false;
    }

    // Left FutureOr: if `T0` is `FutureOr<S0>` then:
    if (!t0.isNullable && t0 is InterfaceTypeImpl && t0.isDartAsyncFutureOr) {
      DartType s0 = t0.typeArguments[0];
      // * `T0 <: T1` iff `Future<S0> <: T1` and `S0 <: T1`
      if (isSubtypeOf(s0, t1)) {
        InterfaceType futureS0 = _typeUtils.buildFutureType(s0);
        return isSubtypeOf(futureS0, t1);
      }
      return false;
    }

    // Left Nullable: if `T0` is `S0?` then:
    //   * `T0 <: T1` iff `S0 <: T1` and `Null <: T1`.
    if (t0.isNullable) {
      DartType s0 = t0.withNullability(false);
      return isSubtypeOf(s0, t1) && isSubtypeOf(_nullNone, t1);
    }

    // Type Variable Reflexivity 1: if T0 is a type variable X0 or a promoted
    // type variables X0 & S0 and T1 is X0 then:
    //   * T0 <: T1
    if (t0 is TypeParameterType &&
        t1 is TypeParameterType &&
        // T1.promotedBound == null && //todo investigate if this is needed
        t0.element == t1.element) {
      return true;
    }

    // Right Promoted Variable: if `T1` is a promoted type variable `X1 & S1`:
    //   * `T0 <: T1` iff `T0 <: X1` and `T0 <: S1`
    if (t1 is TypeParameterType) {
      DartType? t1PromotedBound = t1.promotedBound;
      if (t1PromotedBound != null) {
        TypeParameterType x1 = TypeParameterType(
          t1.name,
          isNullable: t1.isNullable,
          bound: DartType.dynamicType,
        );
        return isSubtypeOf(t0, x1) && isSubtypeOf(t0, t1PromotedBound);
      }
    }

    // Right FutureOr: if `T1` is `FutureOr<S1>` then:
    if (!t1.isNullable && t1 is InterfaceTypeImpl && t1.isDartAsyncFutureOr) {
      DartType s1 = t1.typeArguments[0];
      // `T0 <: T1` iff any of the following hold:
      // * either `T0 <: Future<S1>`
      InterfaceType futureS1 = _typeUtils.buildFutureType(s1);
      if (isSubtypeOf(t0, futureS1)) {
        return true;
      }
      // * or `T0 <: S1`
      if (isSubtypeOf(t0, s1)) {
        return true;
      }
      // * or `T0` is `X0` and `X0` has bound `S0` and `S0 <: T1`
      // * or `T0` is `X0 & S0` and `S0 <: T1`
      if (t0 is TypeParameterType) {
        DartType? s0 = t0.promotedBound;
        if (s0 != null && isSubtypeOf(s0, t1)) {
          return true;
        }
        DartType b1 = t0.bound;
        if (!b1.isDynamic && isSubtypeOf(b1, t1)) {
          return true;
        }
      }
      // iff
      return false;
    }

    // Right Nullable: if `T1` is `S1?` then:
    if (t1.isNullable) {
      DartType s1 = t1.withNullability(false);
      // `T0 <: T1` iff any of the following hold:
      // * either `T0 <: S1`
      if (isSubtypeOf(t0, s1)) {
        return true;
      }
      // * or `T0 <: Null`
      if (isSubtypeOf(t0, _nullNone)) {
        return true;
      }
      // or `T0` is `X0` and `X0` has bound `S0` and `S0 <: T1`
      // or `T0` is `X0 & S0` and `S0 <: T1`
      if (t0 is TypeParameterType) {
        DartType? s0 = t0.promotedBound;
        if (s0 != null && isSubtypeOf(s0, t1)) {
          return true;
        }
        DartType b0 = t0.bound;
        if (!b0.isDynamic && isSubtypeOf(b0, t1)) {
          return true;
        }
      }
      // iff
      return false;
    }

    // Super-Interface: `T0` is an interface type with super-interfaces
    // `S0,...Sn`:
    //   * and `Si <: T1` for some `i`.
    if (t0 is InterfaceTypeImpl && t1 is InterfaceTypeImpl) {
      return _isInterfaceSubtypeOf(t0, t1);
    }

    // Left Promoted Variable: `T0` is a promoted type variable `X0 & S0`
    //   * and `S0 <: T1`
    // Left Type Variable Bound: `T0` is a type variable `X0` with bound `B0`
    //   * and `B0 <: T1`
    if (t0 is TypeParameterType) {
      DartType? s0 = t0.promotedBound;
      if (s0 != null && isSubtypeOf(s0, t1)) {
        return true;
      }

      DartType b0 = t0.bound;
      if (!b0.isDynamic && isSubtypeOf(b0, t1)) {
        return true;
      }
    }

    if (t0 is FunctionType) {
      // Function Type/Function: `T0` is a function type and `T1` is `Function`.
      if (t1.isDartCoreFunction) {
        return true;
      }
      if (t1 is FunctionType) {
        return _isFunctionSubtypeOf(t0, t1);
      }
    }

    if (t0 is RecordType) {
      // Record Type/Record: `T0` is a record type, and `T1` is `Record`.
      if (t1.isDartCoreRecord) {
        return true;
      }
      if (t1 is RecordType) {
        return _isRecordSubtypeOf(t0, t1);
      }
    }

    return false;
  }

  bool _interfaceArguments(
    InterfaceElement element,
    InterfaceType subType,
    InterfaceType superType,
  ) {
    List<TypeParameterType> parameters = element.typeParameters;
    List<DartType> subArguments = subType.typeArguments;
    List<DartType> superArguments = superType.typeArguments;

    assert(subArguments.length == superArguments.length);
    assert(parameters.length == subArguments.length);

    for (int i = 0; i < subArguments.length; i++) {
      TypeParameterType parameter = parameters[i];
      DartType subArgument = subArguments[i];
      DartType superArgument = superArguments[i];

      // todo: ready actual variance value
      Variance variance = Variance.covariant;
      if (variance.isCovariant) {
        if (!isSubtypeOf(subArgument, superArgument)) {
          return false;
        }
      } else if (variance.isContravariant) {
        if (!isSubtypeOf(superArgument, subArgument)) {
          return false;
        }
      } else if (variance.isInvariant) {
        if (!isSubtypeOf(subArgument, superArgument) || !isSubtypeOf(superArgument, subArgument)) {
          return false;
        }
      } else {
        throw StateError(
          'Type parameter $parameter has unknown '
          'variance $variance for subtype checking.',
        );
      }
    }
    return true;
  }

  /// Check that [f] is a subtype of [g].
  bool _isFunctionSubtypeOf(FunctionType f, FunctionType g) {
    RelatedTypeParameters? fresh = _typeUtils.relateTypeParameters(
      f.typeParameters,
      g.typeParameters,
    );
    if (fresh == null) {
      return false;
    }

    f = f.instantiate(fresh.typeParameterTypes);
    g = g.instantiate(fresh.typeParameterTypes);

    if (!isSubtypeOf(f.returnType, g.returnType)) {
      return false;
    }

    List<ParameterElement> fParameters = f.parameters;
    List<ParameterElement> gParameters = g.parameters;

    int fIndex = 0;
    int gIndex = 0;
    while (fIndex < fParameters.length && gIndex < gParameters.length) {
      ParameterElement fParameter = fParameters[fIndex];
      ParameterElement gParameter = gParameters[gIndex];
      if (fParameter.isRequiredPositional) {
        if (gParameter.isRequiredPositional) {
          if (isSubtypeOf(gParameter.type, fParameter.type)) {
            fIndex++;
            gIndex++;
          } else {
            return false;
          }
        } else {
          return false;
        }
      } else if (fParameter.isOptionalPositional) {
        if (gParameter.isPositional) {
          if (isSubtypeOf(gParameter.type, fParameter.type)) {
            fIndex++;
            gIndex++;
          } else {
            return false;
          }
        } else {
          return false;
        }
      } else if (fParameter.isNamed) {
        if (gParameter.isNamed) {
          int compareNames = fParameter.name.compareTo(gParameter.name);
          if (compareNames == 0) {
            bool gIsRequiredOrLegacy = gParameter.isRequiredNamed;
            if (fParameter.isRequiredNamed && !gIsRequiredOrLegacy) {
              return false;
            } else if (isSubtypeOf(gParameter.type, fParameter.type)) {
              fIndex++;
              gIndex++;
            } else {
              return false;
            }
          } else if (compareNames < 0) {
            if (fParameter.isRequiredNamed) {
              return false;
            } else {
              fIndex++;
            }
          } else {
            assert(compareNames > 0);
            // The subtype must accept all parameters of the supertype.
            return false;
          }
        } else {
          break;
        }
      }
    }

    // The supertype must provide all required parameters to the subtype.
    while (fIndex < fParameters.length) {
      ParameterElement fParameter = fParameters[fIndex++];
      if (fParameter.isRequired) {
        return false;
      }
    }

    // The subtype must accept all parameters of the supertype.
    assert(fIndex == fParameters.length);
    if (gIndex < gParameters.length) {
      return false;
    }

    return true;
  }

  bool _isInterfaceSubtypeOf(InterfaceType subType, InterfaceType superType) {
    // Note: we should never reach `_isInterfaceSubtypeOf` with `i2 == Object`,
    // because top types are eliminated before `isSubtypeOf` calls this.
    // TODO: Replace with assert().
    if (identical(subType, superType) || superType.isDartCoreObject) {
      return true;
    }

    // Object cannot subtype anything but itself (handled above).
    if (subType.isDartCoreObject) {
      return false;
    }

    InterfaceElement subElement = subType.element;
    InterfaceElement superElement = superType.element;
    if (subElement == superElement) {
      return _interfaceArguments(superElement, subType, superType);
    }

    // Classes types cannot subtype `Function` or vice versa.
    if (subType.isDartCoreFunction || superType.isDartCoreFunction) {
      return false;
    }

    for (InterfaceType interface in subElement.allSupertypes) {
      if (interface.element == superElement) {
        if (subType.typeArguments.isNotEmpty) {
          Substitution substitution = Substitution.fromPairs(
            subType.element.typeParameters,
            subType.typeArguments,
          );
          InterfaceType substitutedInterface = substitution.substituteType(interface) as InterfaceType;
          return _interfaceArguments(
            superElement,
            substitutedInterface,
            superType,
          );
        } else {
          _interfaceArguments(superElement, interface, superType);
        }
      }
    }

    return false;
  }

  /// Check that [subType] is a subtype of [superType].
  bool _isRecordSubtypeOf(RecordType subType, RecordType superType) {
    final List<RecordTypePositionalField> subPositional = subType.positionalFields;
    final List<RecordTypePositionalField> superPositional = superType.positionalFields;
    if (subPositional.length != superPositional.length) {
      return false;
    }

    final List<RecordTypeNamedField> subNamed = subType.namedFields;
    final List<RecordTypeNamedField> superNamed = superType.namedFields;
    if (subNamed.length != superNamed.length) {
      return false;
    }

    for (int i = 0; i < subPositional.length; i++) {
      final RecordTypePositionalField subField = subPositional[i];
      final RecordTypePositionalField superField = superPositional[i];
      if (!isSubtypeOf(subField.type, superField.type)) {
        return false;
      }
    }

    for (int i = 0; i < subNamed.length; i++) {
      final RecordTypeNamedField subField = subNamed[i];
      final RecordTypeNamedField superField = superNamed[i];
      if (subField.name != superField.name) {
        return false;
      }
      if (!isSubtypeOf(subField.type, superField.type)) {
        return false;
      }
    }

    return true;
  }
}
