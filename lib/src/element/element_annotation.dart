part of 'element.dart';

/// URI for the meta package annotations.
const String _metaPackageUri = 'package:meta/meta.dart';

/// URI for the meta-meta package annotations.
const String _metaMetaPackageUri = 'package:meta/meta_meta.dart';

/// URI for core annotations in the Dart SDK.
const String _coreAnnotationsUri = 'dart:core/annotations.dart';

/// {@template element_annotation}
/// Represents an annotation on a Dart element.
///
/// Annotations provide additional metadata to elements using the `@` syntax.
/// This class provides access to the annotation's constant value and type,
/// as well as convenience methods for checking common annotations from
/// packages like 'meta'.
/// {@endtemplate}
abstract class ElementAnnotation {
  /// {@template element_annotation.name}
  /// The name of the annotation as it appears in code.
  ///
  /// For example, in `@deprecated`, this would be 'deprecated'.
  /// {@endtemplate}
  String get name;

  /// {@template element_annotation.constant}
  /// The constant value of this annotation.
  ///
  /// For annotations with arguments, this provides access to those argument values.
  /// {@endtemplate}
  Constant get constant;

  /// {@template element_annotation.type}
  /// The type of this annotation.
  ///
  /// This represents the class or typedef used as the annotation.
  /// {@endtemplate}
  DartType get type;

  /// {@template element_annotation.annotated_element}
  /// The element that this annotation is applied to.
  ///
  /// This is the element being annotated.
  /// {@endtemplate}
  Element get annotatedElement;

  /// {@template element_annotation.declaration_ref}
  /// Reference to the declaration of this annotation.
  ///
  /// This provides information about where the annotation is defined.
  /// {@endtemplate}
  DeclarationRef get declarationRef;

  /// {@template element_annotation.is_always_throws}
  /// Whether this annotation is `@alwaysThrows` from the meta package.
  ///
  /// `@alwaysThrows` indicates that a function always throws an exception and
  /// never returns normally.
  /// {@endtemplate}
  bool get isAlwaysThrows;

  /// {@template element_annotation.is_deprecated}
  /// Whether this annotation is `@deprecated` or `@Deprecated` from dart:core.
  ///
  /// `@deprecated` marks an API as no longer recommended for use.
  /// {@endtemplate}
  bool get isDeprecated;

  /// {@template element_annotation.is_do_not_store}
  /// Whether this annotation is `@doNotStore` from the meta package.
  ///
  /// `@doNotStore` indicates that a value should not be stored or persisted.
  /// {@endtemplate}
  bool get isDoNotStore;

  /// {@template element_annotation.is_factory}
  /// Whether this annotation is `@factory` from the meta package.
  ///
  /// `@factory` indicates that a method is a factory constructor.
  /// {@endtemplate}
  bool get isFactory;

  /// {@template element_annotation.is_immutable}
  /// Whether this annotation is `@immutable` from the meta package.
  ///
  /// `@immutable` indicates that a class and its subclasses should be immutable.
  /// {@endtemplate}
  bool get isImmutable;

  /// {@template element_annotation.is_internal}
  /// Whether this annotation is `@internal` from the meta package.
  ///
  /// `@internal` indicates that an API is internal to its package and not
  /// meant for public use.
  /// {@endtemplate}
  bool get isInternal;

  /// {@template element_annotation.is_is_test}
  /// Whether this annotation is `@isTest` from the meta package.
  ///
  /// `@isTest` indicates that a function runs a single test.
  /// {@endtemplate}
  bool get isIsTest;

  /// {@template element_annotation.is_is_test_group}
  /// Whether this annotation is `@isTestGroup` from the meta package.
  ///
  /// `@isTestGroup` indicates that a function runs a group of tests.
  /// {@endtemplate}
  bool get isIsTestGroup;

  /// {@template element_annotation.is_literal}
  /// Whether this annotation is `@literal` from the meta package.
  ///
  /// `@literal` indicates that a constructor creates a constant instance.
  /// {@endtemplate}
  bool get isLiteral;

  /// {@template element_annotation.is_must_be_overridden}
  /// Whether this annotation is `@mustBeOverridden` from the meta package.
  ///
  /// `@mustBeOverridden` indicates that a method must be overridden by subclasses.
  /// {@endtemplate}
  bool get isMustBeOverridden;

  /// {@template element_annotation.is_must_call_super}
  /// Whether this annotation is `@mustCallSuper` from the meta package.
  ///
  /// `@mustCallSuper` indicates that overriding methods must call super.method().
  /// {@endtemplate}
  bool get isMustCallSuper;

  /// {@template element_annotation.is_non_virtual}
  /// Whether this annotation is `@nonVirtual` from the meta package.
  ///
  /// `@nonVirtual` indicates that a method cannot be overridden by subclasses.
  /// {@endtemplate}
  bool get isNonVirtual;

  /// {@template element_annotation.is_optional_type_args}
  /// Whether this annotation is `@optionalTypeArgs` from the meta package.
  ///
  /// `@optionalTypeArgs` indicates that type arguments on an API may be omitted.
  /// {@endtemplate}
  bool get isOptionalTypeArgs;

  /// {@template element_annotation.is_override}
  /// Whether this annotation is `@override` from dart:core.
  ///
  /// `@override` indicates that a method is intended to override a method
  /// from a superclass.
  /// {@endtemplate}
  bool get isOverride;

  /// {@template element_annotation.is_protected}
  /// Whether this annotation is `@protected` from the meta package.
  ///
  /// `@protected` indicates that a member is visible only to subclasses.
  /// {@endtemplate}
  bool get isProtected;

  /// {@template element_annotation.is_redeclare}
  /// Whether this annotation is `@redeclare` from the meta package.
  ///
  /// `@redeclare` indicates that a member redeclares an inherited member.
  /// {@endtemplate}
  bool get isRedeclare;

  /// {@template element_annotation.is_reopen}
  /// Whether this annotation is `@reopen` from the meta package.
  ///
  /// `@reopen` indicates that a member reopens a declaration from a superclass.
  /// {@endtemplate}
  bool get isReopen;

  /// {@template element_annotation.is_required}
  /// Whether this annotation is `@required` from the meta package.
  ///
  /// `@required` indicates that a parameter or field must be provided.
  /// {@endtemplate}
  bool get isRequired;

  /// {@template element_annotation.is_sealed}
  /// Whether this annotation is `@sealed` from the meta package.
  ///
  /// `@sealed` indicates that a class cannot be extended, implemented, or mixed in.
  /// {@endtemplate}
  bool get isSealed;

  /// {@template element_annotation.is_target}
  /// Whether this annotation is `@Target` from the meta_meta package.
  ///
  /// `@Target` is used to indicate that a class is intended to be used as
  /// an annotation.
  /// {@endtemplate}
  bool get isTarget;

  /// {@template element_annotation.is_use_result}
  /// Whether this annotation is `@useResult` or `@UseResult` from the meta package.
  ///
  /// `@useResult` indicates that the return value of a method should not be ignored.
  /// {@endtemplate}
  bool get isUseResult;

  /// {@template element_annotation.is_visible_for_overriding}
  /// Whether this annotation is `@visibleForOverriding` from the meta package.
  ///
  /// `@visibleForOverriding` indicates that a member is visible for overriding
  /// but not for direct use.
  /// {@endtemplate}
  bool get isVisibleForOverriding;
}

/// {@template element_annotation_impl}
/// Implementation of an element annotation.
///
/// This class provides the concrete implementation of [ElementAnnotation] with
/// support for recognizing common annotations from packages like 'meta' and
/// 'dart:core'. It resolves the constant value of the annotation lazily to
/// improve performance.
/// {@endtemplate}
class ElementAnnotationImpl implements ElementAnnotation {
  @override
  final DartType type;

  @override
  final DeclarationRef declarationRef;

  @override
  Constant get constant => _constValue ??= _constantValueCompute()!;

  /// Cached constant value of this annotation.
  Constant? _constValue;

  /// Function that computes the constant value of this annotation.
  final ConstantValueCompute _constantValueCompute;

  @override
  String get name => declarationRef.identifier;

  @override
  final Element annotatedElement;

  /// {@template element_annotation_impl.constructor}
  /// Creates an element annotation with the specified parameters.
  ///
  /// @param type The type of this annotation
  /// @param annotatedElement The element being annotated
  /// @param constantValueCompute Function to compute the constant value
  /// @param declarationRef Reference to the annotation declaration
  /// {@endtemplate}
  ElementAnnotationImpl({
    required this.type,
    required this.annotatedElement,
    required this._constantValueCompute,
    required this.declarationRef,
  });

  /// Source name for this annotation, used to determine package.
  late final String _srcName = declarationRef.srcUri.toString();

  bool _isMeta(String name) => _belongsToPackage(_metaPackageUri, name);

  bool _isCore(String name) => _belongsToPackage(_coreAnnotationsUri, name);

  bool _belongsToPackage(String srcName, String name) {
    return _srcName == srcName && name == this.name;
  }

  @override
  bool get isAlwaysThrows => _isMeta('alwaysThrows');

  @override
  bool get isDeprecated => _isCore('deprecated') || _isCore('Deprecated');

  @override
  bool get isDoNotStore => _isMeta('doNotStore');

  @override
  bool get isFactory => _isMeta('factory');

  @override
  bool get isInternal => _isMeta('internal');

  @override
  bool get isIsTest => _isMeta('isTest');

  @override
  bool get isIsTestGroup => _isMeta('isTestGroup');

  @override
  bool get isLiteral => _isMeta('literal');

  @override
  bool get isMustBeOverridden => _isMeta('mustBeOverridden');

  @override
  bool get isMustCallSuper => _isMeta('mustCallSuper');

  @override
  bool get isNonVirtual => _isMeta('nonVirtual');

  @override
  bool get isOptionalTypeArgs => _isMeta('optionalTypeArgs');

  @override
  bool get isOverride => _isCore('override');

  @override
  bool get isProtected => _isMeta('protected');

  @override
  bool get isRedeclare => _isMeta('redeclare');

  @override
  bool get isReopen => _isMeta('reopen');

  @override
  bool get isRequired => _isMeta('required');

  @override
  bool get isSealed => _isMeta('sealed');

  @override
  bool get isUseResult => _isMeta('useResult') || _isMeta('UseResult');

  @override
  bool get isVisibleForOverriding => _isMeta('visibleForOverriding');

  @override
  bool get isImmutable => _isMeta('immutable');

  @override
  bool get isTarget {
    return _belongsToPackage(_metaMetaPackageUri, 'Target');
  }

  @override
  String toString() {
    return '@$name';
  }
}
