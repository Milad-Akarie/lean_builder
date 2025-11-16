import 'package:analyzer/dart/ast/ast.dart';

import 'package:analyzer/dart/ast/token.dart' show Keyword, Token;
import 'package:analyzer/dart/ast/visitor.dart' show UnifyingAstVisitor;
import 'package:lean_builder/src/element/builder/element_stack.dart';
import 'package:lean_builder/src/element/element.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/graph/declaration_ref.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/resolvers/constant/const_evaluator.dart';
import 'package:lean_builder/src/resolvers/constant/constant.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/type/type.dart';

/// {@template element_builder}
/// Builds element models by visiting AST nodes.
///
/// This visitor traverses the AST nodes of a Dart file and constructs the corresponding
/// element model. It resolves types, annotations, and other references to create a
/// complete element hierarchy that represents the structure of the code.
/// {@endtemplate}
class ElementBuilder extends UnifyingAstVisitor<void> with ElementStack<void> {
  /// The resolver used to resolve references and types.
  final ResolverImpl resolver;

  /// Whether to pre-resolve top-level metadata annotations.
  ///
  /// When true, metadata annotations on top-level declarations are resolved
  /// immediately during the initial visit. When false, they are registered
  /// for later resolution.
  final bool preResolveTopLevelMetadata;

  /// {@template element_builder.constructor}
  /// Creates a new element builder with the specified resolver and root library.
  ///
  /// @param resolver The resolver to use for resolving references
  /// @param rootLibrary The library element that will contain the built elements
  /// @param preResolveTopLevelMetadata Whether to pre-resolve top-level metadata
  /// {@endtemplate}
  ElementBuilder(
    this.resolver,
    LibraryElement rootLibrary, {
    this.preResolveTopLevelMetadata = false,
  }) {
    pushElement(rootLibrary);
  }

  @override
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) {
    final LibraryElementImpl library = currentLibrary();
    if (library.hasElement(node.name.lexeme)) return;
    final ExtensionTypeImpl extensionTypeElement = ExtensionTypeImpl(
      name: node.name.lexeme,
      library: library,
      compilationUnit: node,
    );
    setCodeRange(extensionTypeElement, node);
    extensionTypeElement.setNameRange(node.name.offset, node.name.length);
    library.addElement(extensionTypeElement);
    visitElementScoped(extensionTypeElement, () {
      node.documentationComment?.accept(this);
      node.typeParameters?.visitChildren(this);
      if (preResolveTopLevelMetadata) {
        node.metadata.accept(this);
        extensionTypeElement.didResolveMetadata = true;
      }
    });
    _resolveInterfaceTypeRefs(
      extensionTypeElement,
      implementsClause: node.implementsClause,
    );
    extensionTypeElement.thisType = InterfaceTypeImpl(
      extensionTypeElement.name,
      library.buildDeclarationRef(
        extensionTypeElement.name,
        ReferenceType.$class,
      ),
      resolver,
    );

    if (!preResolveTopLevelMetadata) {
      registerMetadataResolver(extensionTypeElement, node.metadata);
    }
  }

  @override
  void visitClassTypeAlias(ClassTypeAlias node) {
    final LibraryElementImpl library = currentLibrary();
    if (library.hasElement(node.name.lexeme)) return;
    final ClassElementImpl clazzElement = ClassElementImpl(
      library: library,
      name: node.name.lexeme,
      compilationUnit: node,
      hasAbstract: node.abstractKeyword != null,
      hasSealedKeyword: node.sealedKeyword != null,
      hasBase: node.baseKeyword != null,
      hasInterface: node.interfaceKeyword != null,
      isMixinClass: node.mixinKeyword != null,
      hasFinal: node.finalKeyword != null,
      isMixinApplication: true,
    );

    setCodeRange(clazzElement, node);
    clazzElement.setNameRange(node.name.offset, node.name.length);
    visitElementScoped(clazzElement, () {
      node.documentationComment?.accept(this);
      node.typeParameters?.visitChildren(this);
      if (preResolveTopLevelMetadata) {
        node.metadata.accept(this);
        clazzElement.didResolveMetadata = true;
      }
    });
    _resolveSuperTypeRef(clazzElement, node.superclass);
    _resolveInterfaceTypeRefs(
      clazzElement,
      withClause: node.withClause,
      implementsClause: node.implementsClause,
    );
    library.addElement(clazzElement);

    if (!preResolveTopLevelMetadata) {
      registerMetadataResolver(clazzElement, node.metadata);
    }
  }

  /// Registers a lazy metadata resolver for the given element.
  void registerMetadataResolver(ElementImpl elm, NodeList<Annotation> meta) {
    elm.metadataResolveCallback = () {
      visitElementScoped(elm, () => meta.accept(this));
    };
  }

  void _resolveSuperTypeRef(InterfaceElementImpl element, NamedType? type) {
    if (type == null) return;
    final DartType resolvedSuperType = resolveTypeRef(type, element);
    assert(
      resolvedSuperType is NamedDartType,
      'Super type must be a NamedDartType type ${resolvedSuperType.runtimeType}',
    );
    element.superType = resolvedSuperType as NamedDartType;
  }

  void _resolveInterfaceTypeRefs(
    InterfaceElementImpl element, {
    WithClause? withClause,
    ImplementsClause? implementsClause,
    MixinOnClause? onClause,
  }) {
    if (withClause != null) {
      for (final NamedType mixin in withClause.mixinTypes) {
        final DartType mixinType = resolveTypeRef((mixin), element);
        assert(
          mixinType is NamedDartType,
          'Mixin type must be a NamedDartType',
        );
        element.addMixin(mixinType as NamedDartType);
      }
    }
    if (implementsClause != null) {
      for (final NamedType interface in implementsClause.interfaces) {
        final DartType interfaceType = resolveTypeRef((interface), element);
        assert(
          interfaceType is NamedDartType,
          'Interface type must be a NamedDartType',
        );
        element.addInterface(interfaceType as NamedDartType);
      }
    }

    if (onClause != null) {
      assert(element is MixinElementImpl);
      for (final NamedType interface in onClause.superclassConstraints) {
        final DartType interfaceType = resolveTypeRef((interface), element);
        assert(
          interfaceType is NamedDartType,
          'Interface type must be a NamedDartType',
        );
        (element as MixinElementImpl).addSuperConstrain(
          interfaceType as NamedDartType,
        );
      }
    }
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    final LibraryElementImpl library = currentLibrary();
    if (library.hasElement(node.name.lexeme)) return;
    final TypeAliasElementImpl typeAliasElm = TypeAliasElementImpl(
      name: node.name.lexeme,
      library: library,
    );
    setCodeRange(typeAliasElm, node);
    typeAliasElm.setNameRange(node.name.offset, node.name.length);
    library.addElement(typeAliasElm);
    visitElementScoped(typeAliasElm, () {
      node.documentationComment?.accept(this);
      node.typeParameters?.visitChildren(this);
      if (preResolveTopLevelMetadata) {
        node.metadata.accept(this);
        typeAliasElm.didResolveMetadata = true;
      }
    });
    final TypeAnnotation targetType = node.functionType != null ? node.functionType! : node.type;
    final DartType type = resolveTypeRef((targetType), typeAliasElm);
    typeAliasElm.aliasedType = type;

    if (!preResolveTopLevelMetadata) {
      registerMetadataResolver(typeAliasElm, node.metadata);
    }
  }

  @override
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    final LibraryElementImpl library = currentLibrary();
    if (library.hasElement(node.name.lexeme)) return;
    final FunctionElementImpl funcElement = FunctionElementImpl(
      name: node.name.lexeme,
      enclosingElement: library,
    );
    setCodeRange(funcElement, node);
    funcElement.setNameRange(node.name.offset, node.name.length);
    visitElementScoped(funcElement, () {
      node.documentationComment?.accept(this);
      node.typeParameters?.visitChildren(this);
      node.parameters.visitChildren(this);
      if (preResolveTopLevelMetadata) {
        node.metadata.accept(this);
        funcElement.didResolveMetadata = true;
      }
    });
    final TypeAliasElementImpl typeAliasElm = TypeAliasElementImpl(
      name: node.name.lexeme,
      library: library,
    );
    library.addElement(typeAliasElm);
    typeAliasElm.aliasedType = FunctionType(
      isNullable: false,
      parameters: funcElement.parameters,
      typeParameters: funcElement.typeParameters,
      returnType: resolveTypeRef(node.returnType, funcElement),
    );

    if (!preResolveTopLevelMetadata) {
      registerMetadataResolver(typeAliasElm, node.metadata);
    }
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final LibraryElementImpl library = currentLibrary();
    if (library.hasElement(node.name.lexeme)) return;
    final ClassElementImpl classElement = ClassElementImpl(
      name: node.name.lexeme,
      library: library,
      compilationUnit: node,
      hasAbstract: node.abstractKeyword != null,
      hasSealedKeyword: node.sealedKeyword != null,
      hasBase: node.baseKeyword != null,
      hasFinal: node.finalKeyword != null,
      hasInterface: node.interfaceKeyword != null,
      isMixinClass: node.mixinKeyword != null,
      isMixinApplication: false,
    );
    library.addElement(classElement);
    setCodeRange(classElement, node);
    classElement.setNameRange(node.name.offset, node.name.length);
    visitElementScoped(classElement, () {
      node.documentationComment?.accept(this);
      node.typeParameters?.visitChildren(this);

      if (preResolveTopLevelMetadata) {
        node.metadata.accept(this);
        classElement.didResolveMetadata = true;
      }
    });

    classElement.thisType = InterfaceTypeImpl(
      classElement.name,
      library.buildDeclarationRef(classElement.name, ReferenceType.$class),
      resolver,
      typeArguments: classElement.typeParameters,
      element: classElement,
    );

    _resolveSuperTypeRef(classElement, node.extendsClause?.superclass);
    _resolveInterfaceTypeRefs(
      classElement,
      withClause: node.withClause,
      implementsClause: node.implementsClause,
    );

    if (!preResolveTopLevelMetadata) {
      registerMetadataResolver(classElement, node.metadata);
    }
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    final LibraryElementImpl libraryElement = currentLibrary();
    if (libraryElement.hasElement(node.name.lexeme)) return;

    final MixinElementImpl mixinElement = MixinElementImpl(
      name: node.name.lexeme,
      compilationUnit: node,
      library: libraryElement,
      isBase: node.baseKeyword != null,
    );

    setCodeRange(mixinElement, node);
    mixinElement.setNameRange(node.name.offset, node.name.length);
    libraryElement.addElement(mixinElement);

    visitElementScoped(mixinElement, () {
      node.documentationComment?.accept(this);
      node.typeParameters?.visitChildren(this);

      if (preResolveTopLevelMetadata) {
        node.metadata.accept(this);
        mixinElement.didResolveMetadata = true;
      }
    });
    mixinElement.thisType = InterfaceTypeImpl(
      mixinElement.name,
      libraryElement.buildDeclarationRef(
        mixinElement.name,
        ReferenceType.$mixin,
      ),
      resolver,
      typeArguments: mixinElement.typeParameters,
      element: mixinElement,
    );
    _resolveInterfaceTypeRefs(
      mixinElement,
      implementsClause: node.implementsClause,
      onClause: node.onClause,
    );

    if (!preResolveTopLevelMetadata) {
      registerMetadataResolver(mixinElement, node.metadata);
    }
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    final LibraryElementImpl library = currentLibrary();
    if (library.hasElement(node.name.lexeme)) return;

    final EnumElementImpl enumElement = EnumElementImpl(
      name: node.name.lexeme,
      library: library,
      compilationUnit: node,
    );
    library.addElement(enumElement);
    setCodeRange(enumElement, node);
    enumElement.setNameRange(node.name.offset, node.name.length);
    enumElement.thisType = InterfaceTypeImpl(
      enumElement.name,
      library.buildDeclarationRef(enumElement.name, ReferenceType.$enum),
      resolver,
      element: enumElement,
    );

    visitElementScoped(enumElement, () {
      node.documentationComment?.accept(this);
      node.typeParameters?.visitChildren(this);
      node.constants.accept(this);
      if (preResolveTopLevelMetadata) {
        node.metadata.accept(this);
        enumElement.didResolveMetadata = true;
      }
    });
    _resolveInterfaceTypeRefs(
      enumElement,
      implementsClause: node.implementsClause,
      withClause: node.withClause,
    );

    if (!preResolveTopLevelMetadata) {
      registerMetadataResolver(enumElement, node.metadata);
    }
  }

  @override
  void visitEnumConstantDeclaration(EnumConstantDeclaration node) {
    final EnumElementImpl enumElement = currentElementAs<EnumElementImpl>();

    final FieldElementImpl fieldEle = FieldElementImpl(
      name: node.name.lexeme,
      isStatic: true,
      isAbstract: false,
      isCovariant: false,
      isEnumConstant: true,
      enclosingElement: enumElement,
      hasImplicitType: false,
      isConst: true,
      isFinal: true,
      isLate: false,
      isExternal: false,
      type: enumElement.thisType,
      isSynthetic: node.isSynthetic,
    );
    visitElementScoped(fieldEle, () {
      node.documentationComment?.accept(this);
    });
    final EnumConstantArguments? args = node.arguments;
    if (args != null) {
      fieldEle.setConstantComputeValue(() {
        final ConstantEvaluator constEvaluator = ConstantEvaluator(
          resolver,
          enumElement.library,
          this,
        );
        final EnumDeclaration enumNode = node.thisOrAncestorOfType<EnumDeclaration>()!;
        final SimpleIdentifier? constructorName = args.constructorSelector?.name;
        final ConstructorDeclaration constructor = enumNode.members.whereType<ConstructorDeclaration>().firstWhere(
          (ConstructorDeclaration e) => e.name?.lexeme == constructorName?.name,
          orElse: () => throw Exception('Could not find constructor'),
        );
        final ConstObjectImpl? constantObj = constEvaluator.evaluate(constructor) as ConstObjectImpl?;
        return constantObj?.construct(
          args.argumentList,
          constEvaluator,
          constructorName?.name,
        );
      });
    }
    enumElement.addField(fieldEle);
    setCodeRange(fieldEle, node);
    fieldEle.setNameRange(node.name.offset, node.name.length);
    registerMetadataResolver(fieldEle, node.metadata);
  }

  @override
  void visitTypeParameter(TypeParameter node) {
    final TypeParameterizedElementMixin element = currentElementAs<TypeParameterizedElementMixin>();
    final TypeAnnotation? bound = node.bound;
    DartType boundType = DartType.dynamicType;
    if (bound != null) {
      boundType = resolveTypeRef(bound, element);
    }
    element.addTypeParameter(
      TypeParameterType(node.name.lexeme, bound: boundType),
    );
  }

  /// Resolves a type reference in the context of the given enclosing element.
  DartType resolveTypeRef(TypeAnnotation? typeAnno, Element enclosingEle) {
    if (typeAnno == null) {
      return DartType.invalidType;
    }
    if (typeAnno is NamedType) {
      if (enclosingEle is TypeParameterizedElementMixin) {
        for (final TypeParameterType typeParam in enclosingEle.allTypeParameters) {
          if (typeParam.name == typeAnno.name.lexeme) {
            return typeParam.withNullability(typeAnno.question != null);
          }
        }
      }
      return resolveNamedType(typeAnno, enclosingEle);
    } else if (typeAnno is GenericFunctionType) {
      return resolveFunctionTypeRef(
        typeAnno,
        FunctionElementImpl(name: 'Function', enclosingElement: enclosingEle),
      );
    } else if (typeAnno is RecordTypeAnnotation) {
      return resolveRecordTypeRef(typeAnno, enclosingEle);
    }
    return DartType.invalidType;
  }

  /// Builds a parameter element from the given formal parameter node.
  FunctionType resolveFunctionTypeRef(
    GenericFunctionType typeAnnotation,
    FunctionElement funcElement,
  ) {
    visitElementScoped(funcElement, () {
      typeAnnotation.typeParameters?.visitChildren(this);
      typeAnnotation.parameters.visitChildren(this);
    });
    return FunctionType(
      returnType: resolveTypeRef(typeAnnotation.returnType, funcElement),
      typeParameters: funcElement.typeParameters,
      parameters: funcElement.parameters,
      isNullable: typeAnnotation.question != null,
    );
  }

  /// Resolves a record type reference in the context of the given enclosing element.
  RecordType resolveRecordTypeRef(
    RecordTypeAnnotation typeAnnotation,
    Element enclosingEle,
  ) {
    final List<RecordTypePositionalField> positionalTypes = <RecordTypePositionalField>[];
    for (final RecordTypeAnnotationPositionalField field in typeAnnotation.positionalFields) {
      positionalTypes.add(
        RecordTypePositionalField(resolveTypeRef(field.type, enclosingEle)),
      );
    }
    final List<RecordTypeNamedField> namedTypes = <RecordTypeNamedField>[];
    for (final RecordTypeAnnotationNamedField field in <RecordTypeAnnotationNamedField>[
      ...?typeAnnotation.namedFields?.fields,
    ]) {
      namedTypes.add(
        RecordTypeNamedField(
          field.name.lexeme,
          resolveTypeRef(field.type, enclosingEle),
        ),
      );
    }
    return RecordType(
      positionalFields: positionalTypes,
      namedFields: namedTypes,
      isNullable: typeAnnotation.question != null,
    );
  }

  /// Resolves a named type reference in the context of the given enclosing element.
  DartType resolveNamedType(NamedType annotation, Element enclosingEle) {
    final String typename = annotation.name.lexeme;
    if (typename == DartType.voidType.name) return DartType.voidType;
    if (typename == DartType.dynamicType.name) return DartType.dynamicType;
    if (typename == DartType.neverType.name) return DartType.neverType;

    final List<DartType> typeArgs = <DartType>[];
    for (final TypeAnnotation typeArg in <TypeAnnotation>[
      ...?annotation.typeArguments?.arguments,
    ]) {
      typeArgs.add(resolveTypeRef(typeArg, enclosingEle));
    }

    final ImportPrefixReference? importPrefix = annotation.importPrefix;

    final DeclarationRef? declarationRef = resolver.getDeclarationRef(
      typename,
      enclosingEle.library.src,
      importPrefix: importPrefix?.name.lexeme,
    );
    if (declarationRef == null) {
      return SyntheticNamedType(
        typename,
        resolver,
        isNullable: annotation.question != null,
      );
    }

    if (declarationRef.type == ReferenceType.$typeAlias) {
      return TypeAliasTypeImpl(
        typename,
        declarationRef,
        resolver,
        typeArguments: typeArgs,
        isNullable: annotation.question != null,
      );
    }

    assert(
      declarationRef.type.representsInterfaceType,
      'Expected interface type, but got ${declarationRef.type}',
    );

    return InterfaceTypeImpl(
      typename,
      declarationRef,
      resolver,
      isNullable: annotation.question != null,
      typeArguments: typeArgs,
    );
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    final InterfaceElementImpl interfaceElement = currentElementAs<InterfaceElementImpl>();
    final DartType fieldType = resolveTypeRef(
      node.fields.type,
      interfaceElement,
    );

    // Process each variable in the field declaration
    for (final VariableDeclaration variable in node.fields.variables) {
      final FieldElementImpl fieldEle = FieldElementImpl(
        isStatic: node.isStatic,
        name: variable.name.lexeme,
        isAbstract: node.abstractKeyword != null,
        isCovariant: node.covariantKeyword != null,
        isEnumConstant: false,
        isExternal: node.externalKeyword != null,
        enclosingElement: interfaceElement,
        hasImplicitType: node.fields.type == null,
        isConst: node.fields.isConst,
        isFinal: node.fields.isFinal,
        isLate: node.fields.isLate,
        isSynthetic: variable.isSynthetic,
        type: fieldType,
      );
      fieldEle.initializer = variable.initializer;
      if (fieldEle.hasInitializer && fieldEle.isConst) {
        fieldEle.setConstantComputeValue(() {
          final ConstantEvaluator constEvaluator = ConstantEvaluator(
            resolver,
            interfaceElement.library,
            this,
          );
          return constEvaluator.evaluate(variable.initializer!);
        });
      }
      setCodeRange(fieldEle, node);
      fieldEle.setNameRange(variable.name.offset, variable.name.length);
      interfaceElement.addField(fieldEle);
      registerMetadataResolver(fieldEle, node.metadata);
    }
  }

  @override
  void visitAnnotation(Annotation node) {
    final ElementImpl currentElement = currentElementAs<ElementImpl>();
    final Identifier name = node.name;
    final IdentifierRef identifier = resolver.resolveIdentifier(
      currentElement.library,
      <String>[
        if (name is SimpleIdentifier) name.name,
        if (name is PrefixedIdentifier) ...<String>[
          name.prefix.name,
          name.identifier.name,
        ],
      ],
    );

    final (
      LibraryElementImpl lib,
      AstNode targetNode,
      DeclarationRef decRef,
    ) = resolver.astNodeFor(
      identifier,
      currentElement.library,
    );
    final ConstantEvaluator constantEvaluator = ConstantEvaluator(
      resolver,
      lib,
      this,
    );
    if (targetNode is ClassDeclaration || targetNode is ConstructorDeclaration) {
      final ClassDeclaration classDeclaration = targetNode.thisOrAncestorOfType<ClassDeclaration>()!;
      final String className = classDeclaration.name.lexeme;
      final List<DartType> typeArgs = <DartType>[];
      for (final TypeAnnotation typeArg in <TypeAnnotation>[
        ...?node.typeArguments?.arguments,
      ]) {
        typeArgs.add(resolveTypeRef(typeArg, currentElement));
      }
      final ElementAnnotationImpl elem = ElementAnnotationImpl(
        annotatedElement: currentElement,
        type: InterfaceTypeImpl(
          className,
          decRef,
          resolver,
          typeArguments: typeArgs,
        ),
        declarationRef: decRef,
        constantValueCompute: () {
          final ConstructorDeclaration constructor;
          if (targetNode is ConstructorDeclaration) {
            constructor = targetNode;
          } else {
            constructor = classDeclaration.members.whereType<ConstructorDeclaration>().firstWhere(
              (ConstructorDeclaration e) => e.name?.lexeme == node.constructorName?.name,
              orElse: () => throw Exception('Could not find constructor'),
            );
          }
          final ConstObjectImpl? obj = constantEvaluator.evaluate(constructor) as ConstObjectImpl?;
          if (node.arguments != null) {
            return constantEvaluator.visitElementScoped(
              currentElement.library,
              () {
                return obj?.construct(
                  node.arguments!,
                  constantEvaluator,
                  constructor.name?.lexeme,
                );
              },
            );
          }
          return obj;
        },
      );
      currentElement.addMetadata(elem);
    } else if (targetNode is TopLevelVariableDeclaration || targetNode is FieldDeclaration) {
      final VariableDeclarationList varList;
      if (targetNode is TopLevelVariableDeclaration) {
        varList = targetNode.variables;
      } else {
        varList = (targetNode as FieldDeclaration).fields;
      }

      final VariableDeclaration variable = varList.variables.firstWhere(
        (VariableDeclaration e) => e.name.lexeme == identifier.name,
      );
      DartType typeRef = DartType.invalidType;
      final Expression? initializer = variable.initializer;
      if (varList.type != null) {
        typeRef = resolveTypeRef(varList.type!, currentElement);
      } else if (initializer is MethodInvocation) {
        final Expression? target = initializer.target;
        final List<String> parts = <String>[
          if (target is SimpleIdentifier) ...<String>[
            target.name,
            initializer.methodName.name,
          ] else if (target is PrefixedIdentifier) ...<String>[
            target.prefix.name,
            target.identifier.name,
          ] else if (target == null)
            initializer.methodName.name,
        ];
        final IdentifierRef identifier = resolver.resolveIdentifier(lib, parts);
        final (_, _, DeclarationRef declarationRef) = resolver.astNodeFor(
          identifier,
          lib,
        );
        final List<DartType> typeArgs = <DartType>[];
        for (final TypeAnnotation typeArg in <TypeAnnotation>[
          ...?initializer.typeArguments?.arguments,
        ]) {
          typeArgs.add(resolveTypeRef(typeArg, currentElement));
        }
        typeRef = InterfaceTypeImpl(
          identifier.topLevelTarget,
          declarationRef,
          resolver,
          typeArguments: typeArgs,
        );
      }
      final ElementAnnotationImpl elem = ElementAnnotationImpl(
        annotatedElement: currentElement,
        type: typeRef,
        declarationRef: decRef,
        constantValueCompute: () {
          return constantEvaluator.evaluate(variable.initializer!);
        },
      );
      currentElement.addMetadata(elem);
    }
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final LibraryElementImpl libraryElement = currentLibrary();
    if (libraryElement.hasElement(node.name.lexeme)) return;
    final FunctionBody body = node.functionExpression.body;
    final FunctionElementImpl funcElement = FunctionElementImpl(
      name: node.name.lexeme,
      enclosingElement: libraryElement,
      isExternal: node.externalKeyword != null,
      isOperator: false,
      isAsynchronous: body.isAsynchronous,
      isGenerator: body.isGenerator,
      isSynchronous: body.isSynchronous,
    );
    setCodeRange(funcElement, node);
    funcElement.setNameRange(node.name.offset, node.name.length);
    libraryElement.addElement(funcElement);
    visitElementScoped(funcElement, () {
      node.documentationComment?.accept(this);
      node.functionExpression.typeParameters?.visitChildren(this);
      node.functionExpression.parameters?.visitChildren(this);
      if (preResolveTopLevelMetadata) {
        node.metadata.accept(this);
        funcElement.didResolveMetadata = true;
      }
    });
    final DartType returnType = resolveTypeRef((node.returnType), funcElement);
    funcElement.returnType = returnType;
    funcElement.type = FunctionType(
      returnType: returnType,
      typeParameters: funcElement.typeParameters,
      parameters: funcElement.parameters,
      isNullable: false,
    );

    if (!preResolveTopLevelMetadata) {
      registerMetadataResolver(funcElement, node.metadata);
    }
  }

  @override
  void visitSimpleFormalParameter(SimpleFormalParameter node) {
    final String name = node.name?.lexeme ?? '';
    final ExecutableElementImpl executableElement = currentElementAs<ExecutableElementImpl>();
    if (executableElement.getParameter(name) != null) {
      return;
    }
    final ParameterElementImpl parameterElement = _buildParameter(
      node,
      executableElement,
    );
    executableElement.addParameter(parameterElement);
  }

  @override
  void visitDefaultFormalParameter(DefaultFormalParameter node) {
    node.parameter.accept(this);
    final ExecutableElementImpl executableElement = currentElementAs<ExecutableElementImpl>();
    final ParameterElementImpl? param =
        executableElement.getParameter(node.name?.lexeme ?? '') as ParameterElementImpl?;
    if (param != null && node.defaultValue != null) {
      param.initializer = node.defaultValue;
      param.setConstantComputeValue(() {
        final ConstantEvaluator constEvaluator = ConstantEvaluator(
          resolver,
          executableElement.library,
          this,
        );
        return constEvaluator.evaluate(node.defaultValue!);
      });
    }
  }

  @override
  void visitFieldFormalParameter(FieldFormalParameter node) {
    final String name = node.name.lexeme;
    final ConstructorElementImpl constructorEle = currentElementAs<ConstructorElementImpl>();
    if (constructorEle.getParameter(name) != null) {
      return;
    }
    final InterfaceElementImpl interfaceElement = constructorEle.enclosingElement as InterfaceElementImpl;
    final List<FieldElement> fields = interfaceElement.fields;
    final DartType thisType = fields
        .firstWhere(
          (FieldElement e) => e.name == name,
          orElse: () => throw Exception('Could not link this type'),
        )
        .type;
    final ParameterElementImpl parameterElement = _buildParameter(
      node,
      constructorEle,
      type: thisType,
    );
    constructorEle.addParameter(parameterElement);
  }

  (DartType, Expression?) _resolveSuperParam({
    required IdentifierRef ref,
    required LibraryElementImpl library,
    required String constructorName,
    required SuperFormalParameter superParam,
  }) {
    final (
      LibraryElementImpl lib,
      ClassDeclaration clazzNode as ClassDeclaration,
      _,
    ) = resolver.astNodeFor(
      ref,
      library,
    );

    final ConstructorDeclaration constructorNode = clazzNode.members.whereType<ConstructorDeclaration>().firstWhere(
      (ConstructorDeclaration e) => (e.name?.lexeme ?? '') == constructorName,
    );

    final FormalParameter targetParam;
    final NodeList<FormalParameter> ancestorParams = constructorNode.parameters.parameters;
    if (superParam.isNamed) {
      targetParam = ancestorParams.firstWhere(
        (FormalParameter e) => e.name?.lexeme == superParam.name.lexeme,
        orElse: () => throw Exception('Could not find super param'),
      );
    } else {
      final List<FormalParameter> thisParams = <FormalParameter>[
        ...?superParam.thisOrAncestorOfType<ConstructorDeclaration>()?.parameters.parameters,
      ];
      final int superParamIndex = thisParams.indexWhere(
        (FormalParameter p) => p.name?.lexeme == superParam.name.lexeme,
      );
      if (superParamIndex != -1) {
        targetParam = ancestorParams[superParamIndex];
      } else {
        throw Exception('Could not find super param');
      }
    }

    InterfaceElement getTypeParamsCollector() {
      final InterfaceElementImpl typeParamsCollector = InterfaceElementImpl(
        name: '',
        library: lib,
        compilationUnit: clazzNode,
      );
      visitElementScoped(typeParamsCollector, () {
        clazzNode.typeParameters?.visitChildren(this);
      });
      return typeParamsCollector;
    }

    (DartType, Expression?) buildParam(
      FormalParameter param,
      LibraryElementImpl lib,
    ) {
      if (param is FieldFormalParameter) {
        final FieldDeclaration field = clazzNode.members.whereType<FieldDeclaration>().firstWhere(
          (FieldDeclaration e) => e.fields.variables.any(
            (VariableDeclaration v) => v.name.lexeme == param.name.lexeme,
          ),
          orElse: () => throw Exception('Could not find field formal parameter'),
        );
        return (
          resolveTypeRef(field.fields.type, getTypeParamsCollector()),
          null,
        );
      } else if (param is SimpleFormalParameter) {
        return (resolveTypeRef(param.type, getTypeParamsCollector()), null);
      } else if (param is DefaultFormalParameter) {
        return (buildParam(param.parameter, lib).$1, param.defaultValue);
      } else if (param is SuperFormalParameter) {
        final SuperConstructorInvocation? superInvocation = constructorNode.initializers
            .whereType<SuperConstructorInvocation>()
            .singleOrNull;
        final NamedType superType = clazzNode.extendsClause!.superclass;
        return _resolveSuperParam(
          ref: IdentifierRef(
            superType.name.lexeme,
            importPrefix: superType.importPrefix?.name.lexeme,
          ),
          library: lib,
          constructorName: superInvocation?.constructorName?.name ?? '',
          superParam: param,
        );
      } else {
        throw Exception('Unknown parameter type: ${param.runtimeType}');
      }
    }

    return buildParam(targetParam, lib);
  }

  @override
  void visitSuperFormalParameter(SuperFormalParameter node) {
    final String name = node.name.lexeme;
    final ConstructorElementImpl constructorEle = currentElementAs<ConstructorElementImpl>();
    if (constructorEle.getParameter(name) != null) {
      return;
    }
    final LibraryElementImpl library = currentLibrary();
    final ConstructorElementRef superConstRef = constructorEle.superConstructor!;

    final (DartType superType, Expression? initializer) = _resolveSuperParam(
      ref: IdentifierRef(
        superConstRef.classType.name,
        declarationRef: superConstRef.classType.declarationRef,
      ),
      library: library,
      constructorName: superConstRef.name,
      superParam: node,
    );
    final ParameterElementImpl parameterElement = _buildParameter(
      node,
      constructorEle,
      isSuperFormal: true,
      type: superType,
    );

    if (initializer != null) {
      parameterElement.setConstantComputeValue(() {
        final ConstantEvaluator constEvaluator = ConstantEvaluator(
          resolver,
          library,
          this,
        );
        return constEvaluator.evaluate(initializer);
      });
    }
    constructorEle.addParameter(parameterElement);
  }

  ParameterElementImpl _buildParameter(
    FormalParameter node,
    ExecutableElementImpl executableElement, {
    bool isSuperFormal = false,
    DartType? type,
  }) {
    final String name = node.name?.lexeme ?? '';

    if (type == null && node is SimpleFormalParameter) {
      type = resolveTypeRef((node.type), executableElement);
    }

    final ParameterElementImpl parameterElement = ParameterElementImpl(
      name: name,
      isConst: node.isConst,
      isFinal: node.isFinal,
      isLate: node.isOptional,
      hasImplicitType: node.isExplicitlyTyped,
      enclosingElement: executableElement,
      isCovariant: node.covariantKeyword != null,
      isInitializingFormal: node is FieldFormalParameter,
      isNamed: node.isNamed,
      isOptional: node.isOptional,
      isPositional: node.isPositional,
      isRequired: node.isRequired,
      isRequiredNamed: node.isRequiredNamed,
      isRequiredPositional: node.isRequiredPositional,
      isOptionalNamed: node.isOptionalNamed,
      isOptionalPositional: node.isOptionalPositional,
      isSuperFormal: isSuperFormal,
    );

    parameterElement.type = type ?? DartType.neverType;
    registerMetadataResolver(parameterElement, node.metadata);
    setCodeRange(parameterElement, node);
    parameterElement.setNameRange(
      node.name?.offset ?? 0,
      node.name?.length ?? 0,
    );
    final Token? nameToken = node.name;
    if (nameToken != null) {
      parameterElement.setNameRange(nameToken.offset, nameToken.length);
    }
    return parameterElement;
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    final LibraryElementImpl library = currentLibrary();
    final ConstantEvaluator constantEvaluator = ConstantEvaluator(
      resolver,
      library,
      this,
    );
    final DartType type = resolveTypeRef((node.variables.type), library);
    for (final VariableDeclaration variable in node.variables.variables) {
      final TopLevelVariableElementImpl topLevelVar = TopLevelVariableElementImpl(
        name: variable.name.lexeme,
        isConst: node.variables.isConst,
        isFinal: node.variables.isFinal,
        isLate: node.variables.isLate,
        isExternal: node.externalKeyword != null,
        hasImplicitType: node.variables.type == null,
        enclosingElement: library,
      );
      topLevelVar.type = type;
      if (variable.initializer != null) {
        topLevelVar.setConstantComputeValue(() {
          return constantEvaluator.evaluate(variable.initializer!);
        });
      }
      visitElementScoped(topLevelVar, () {
        node.documentationComment?.accept(this);
        if (preResolveTopLevelMetadata) {
          node.metadata.accept(this);
          topLevelVar.didResolveMetadata = true;
        }
      });
      if (!preResolveTopLevelMetadata) {
        registerMetadataResolver(topLevelVar, node.metadata);
      }
      setCodeRange(topLevelVar, variable);
      topLevelVar.setNameRange(variable.name.offset, variable.name.length);
      library.addElement(topLevelVar);
    }
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final InterfaceElementImpl interfaceElement = currentElementAs<InterfaceElementImpl>();
    final String name = node.name.lexeme;
    MethodElementImpl methodElement = MethodElementImpl(
      isStatic: node.isStatic,
      name: name,
      enclosingElement: interfaceElement,
      isAbstract: node.isAbstract,
      isAsynchronous: node.body.isAsynchronous,
      isExternal: node.externalKeyword != null,
      isGenerator: node.body.isGenerator,
      isOperator: node.isOperator,
      isSynchronous: node.body.isSynchronous,
    );

    final Token? accessKeyword = node.propertyKeyword;
    if (accessKeyword != null) {
      methodElement = methodElement.toPropertyAccessorElement(
        isGetter: accessKeyword.keyword == Keyword.GET,
        isSetter: accessKeyword.keyword == Keyword.SET,
      );
    }

    interfaceElement.addMethod(methodElement);
    visitElementScoped(methodElement, () {
      node.documentationComment?.accept(this);
      node.typeParameters?.visitChildren(this);
      node.parameters?.visitChildren(this);
    });

    final DartType returnType = resolveTypeRef(
      (node.returnType),
      methodElement,
    );
    methodElement.returnType = returnType;
    methodElement.type = FunctionType(
      returnType: returnType,
      typeParameters: methodElement.typeParameters,
      parameters: methodElement.parameters,
      isNullable: false,
    );

    setCodeRange(methodElement, node);
    methodElement.setNameRange(node.name.offset, node.name.length);
    registerMetadataResolver(methodElement, node.metadata);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final InterfaceElementImpl interfaceElement = currentElementAs<InterfaceElementImpl>();
    final String constructorName = node.name?.lexeme ?? '';

    final NodeList<ConstructorInitializer> initializers = node.initializers;
    ConstructorElementRef? superConstructor;

    if (interfaceElement.superType != null) {
      final Iterable<SuperConstructorInvocation> invocations = initializers.whereType<SuperConstructorInvocation>();
      final String? superConstName = invocations
          .map((SuperConstructorInvocation e) => e.constructorName?.name)
          .firstOrNull;
      final NamedDartType? superClazz = interfaceElement.superType;
      if (superClazz != null) {
        superConstructor = ConstructorElementRef(
          superClazz,
          superConstName ?? '',
        );
      }
    }

    final ConstructorElementImpl constructorElement = ConstructorElementImpl(
      name: constructorName,
      enclosingElement: interfaceElement,
      isConst: node.constKeyword != null,
      isFactory: node.factoryKeyword != null,
      isGenerator: node.body.isGenerator,
      superConstructor: superConstructor,
    );

    setCodeRange(constructorElement, node);
    Token? nameNode = node.name;
    if (nameNode == null) {
      final Token parentName = node.thisOrAncestorOfType<NamedCompilationUnitMember>()!.name;
      constructorElement.setNameRange(node.offset, parentName.length);
    } else {
      constructorElement.setNameRange(nameNode.offset, nameNode.length);
    }

    interfaceElement.addConstructor(constructorElement);
    constructorElement.returnType = interfaceElement.thisType;

    visitElementScoped(constructorElement, () {
      node.documentationComment?.accept(this);
      node.parameters.visitChildren(this);
    });

    final ConstructorName? redirectedConstructor = node.redirectedConstructor;
    if (redirectedConstructor != null) {
      final NamedType redType = redirectedConstructor.type;
      final IdentifierRef identifierRef = resolver.resolveIdentifier(interfaceElement.library, <String>[
        if (redType.importPrefix != null) redType.importPrefix!.name.lexeme,
        redType.name.lexeme,
      ]);

      final DeclarationRef? declarationRef = resolver.getDeclarationRef(
        identifierRef.topLevelTarget,
        constructorElement.library.src,
        importPrefix: identifierRef.importPrefix,
      );
      if (declarationRef != null) {
        final InterfaceTypeImpl resolvedType = InterfaceTypeImpl(
          identifierRef.name,
          declarationRef,
          resolver,
        );
        constructorElement.returnType = resolvedType;
        constructorElement.redirectedConstructor = ConstructorElementRef(
          resolvedType,
          identifierRef.name,
        );
      }

      registerMetadataResolver(constructorElement, node.metadata);
    }
  }

  @override
  void visitComment(Comment node) {
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < node.tokens.length; i++) {
      buffer.write(node.tokens[i].lexeme);
      if (i < node.tokens.length - 1) {
        buffer.writeln();
      }
    }
    currentElementAs<ElementImpl>().documentationComment = buffer.toString();
  }

  /// Sets the code range for the given [element] based on the provided [node].
  void setCodeRange(ElementImpl element, AstNode node) {
    AstNode? parent = node.parent;
    if (node is FormalParameter && parent is DefaultFormalParameter) {
      node = parent;
    }

    if (node is VariableDeclaration && parent is VariableDeclarationList) {
      AstNode? fieldDeclaration = parent.parent;
      if (fieldDeclaration != null && parent.variables.first == node) {
        int offset = fieldDeclaration.offset;
        element.setCodeRange(node, offset, node.end - offset);
        return;
      }
    }

    element.setCodeRange(node, node.offset, node.length);
  }
}
