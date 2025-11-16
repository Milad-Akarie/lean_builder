import 'dart:collection' show HashMap;

import 'package:analyzer/dart/ast/ast.dart';

import 'package:analyzer/dart/ast/token.dart' show TokenType, Token;
import 'package:analyzer/dart/ast/visitor.dart' show GeneralizingAstVisitor;
import 'package:lean_builder/src/element/builder/element_builder.dart';
import 'package:lean_builder/src/element/builder/element_stack.dart';
import 'package:lean_builder/src/element/element.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/graph/declaration_ref.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:lean_builder/src/resolvers/source_based_cache.dart';
import 'package:lean_builder/src/type/type.dart';

import 'constant.dart';

/// A visitor that evaluates constant expressions
///
/// some implementations of this class is borrowed from analyzer package
class ConstantEvaluator extends GeneralizingAstVisitor<Constant> with ElementStack<Constant> {
  final ResolverImpl _resolver;

  final ElementBuilder _elementBuilder;

  LibraryElement get _library => currentLibrary();

  /// Creates a new instance of [ConstantEvaluator].
  ConstantEvaluator(
    this._resolver,
    LibraryElement library,
    this._elementBuilder,
  ) {
    pushElement(library);
  }

  /// Evaluates the given [node] and returns the constant value.
  ///
  /// If the node is not a constant expression, it returns [Constant.invalid].
  /// it also caches the evaluated constant in the [evaluatedConstantsCache].
  Constant? evaluate(AstNode node) {
    final CompoundKey key = _resolver.evaluatedConstantsCache.keyFor(
      _library.src.id,
      '${node.hashCode}',
    );
    if (_resolver.evaluatedConstantsCache.contains(key)) {
      return _resolver.evaluatedConstantsCache[key];
    }
    final Constant? constant = node.accept(this);
    if (constant != null && !identical(constant, Constant.invalid)) {
      _resolver.evaluatedConstantsCache.cacheKey(key, constant);
    }
    return constant;
  }

  @override
  Constant? visitConstructorDeclaration(ConstructorDeclaration node) {
    // redirect constant evaluation to the redirected constructor
    final ConstructorName? redirectConstructor = node.redirectedConstructor;
    if (redirectConstructor != null) {
      final NamedType redType = redirectConstructor.type;
      final IdentifierRef identifierRef = _resolver.resolveIdentifier(_library, <String>[
        if (redType.importPrefix != null) redType.importPrefix!.name.lexeme,
        redType.name.lexeme,
      ]);
      final (
        LibraryElementImpl redirectLib,
        AstNode redirectConstroctor,
        _,
      ) = _resolver.astNodeFor(
        identifierRef,
        _library,
      );
      if (redirectConstroctor is! ConstructorDeclaration) {
        throw Exception(
          'Expected ConstructorDeclaration, but got ${redirectConstroctor.runtimeType}',
        );
      }
      return visitElementScoped(redirectLib, () {
        return evaluate(redirectConstroctor);
      });
    }

    final NamedCompilationUnitMember interfaceDec = node.parent as NamedCompilationUnitMember;
    assert(interfaceDec is ClassDeclaration || interfaceDec is EnumDeclaration);
    ConstObjectImpl? superConstObj;
    final NodeList<ConstructorInitializer> initializers = node.initializers;
    if (interfaceDec is ClassDeclaration) {
      final NamedType? superClass = interfaceDec.extendsClause?.superclass;
      if (superClass != null) {
        final Iterable<SuperConstructorInvocation> superConstInvocations = initializers
            .whereType<SuperConstructorInvocation>();
        final String? superConstName = superConstInvocations.firstOrNull?.constructorName?.name;
        final (
          LibraryElementImpl superLib,
          ClassDeclaration superNode as ClassDeclaration,
          DeclarationRef loc,
        ) = _resolver.astNodeFor(
          IdentifierRef.fromType(superClass),
          _library,
        );
        visitElementScoped(superLib, () {
          final Iterable<ConstructorDeclaration> constructors = superNode.members.whereType<ConstructorDeclaration>();
          final ConstructorDeclaration superConstructor = constructors
              .where(
                (ConstructorDeclaration c) => c.name?.lexeme == superConstName,
              )
              .single;
          superConstObj = evaluate(superConstructor) as ConstObjectImpl?;
        });
      }
    }

    final Iterable<FieldDeclaration> fields = interfaceDec.childEntities.whereType<FieldDeclaration>();
    final NodeList<FormalParameter> params = node.parameters.parameters;
    final Map<String, Constant?> values = <String, Constant?>{};
    final Map<int, String> positionalNames = <int, String>{};

    for (final ConstructorInitializer initializer in initializers) {
      if (initializer is ConstructorFieldInitializer) {
        values[initializer.fieldName.name] = initializer.expression.accept(
          this,
        );
      } else if (initializer is SuperConstructorInvocation) {
        final String? constructorName = initializer.constructorName?.name;
        superConstObj = superConstObj?.construct(
          initializer.argumentList,
          this,
          constructorName,
        );
      }
    }
    if (superConstObj != null) {
      values.addAll(superConstObj!.props);
    }
    for (final FieldDeclaration field in fields.where(
      (FieldDeclaration f) => !f.isStatic,
    )) {
      for (final VariableDeclaration variable in field.fields.variables) {
        if (variable.initializer != null) {
          values[variable.name.lexeme] = variable.initializer!.accept(this);
        }
      }
    }

    for (int i = 0; i < params.length; i++) {
      final FormalParameter param = params[i];
      if (param.isPositional) {
        positionalNames[i] = param.name!.lexeme;
      }
      if (param is DefaultFormalParameter && param.defaultValue != null) {
        values[param.name!.lexeme] = param.defaultValue?.accept(this);
      }
    }

    final String interfaceName = interfaceDec.name.lexeme;
    final InterfaceTypeImpl type = InterfaceTypeImpl(
      interfaceName,
      _library.buildDeclarationRef(interfaceName, ReferenceType.$class),
      _resolver,
    );
    return ConstObjectImpl(values, type, positionalNames: positionalNames);
  }

  @override
  Constant? visitAdjacentStrings(AdjacentStrings node) {
    StringBuffer buffer = StringBuffer();
    for (StringLiteral string in node.strings) {
      Constant? value = string.accept(this);
      if (identical(value, Constant.invalid)) {
        return value;
      }
      buffer.write(value);
    }
    return ConstString(buffer.toString());
  }

  dynamic _valueOf(Constant? constant) {
    if (constant is ConstLiteral) {
      return constant.value;
    }
    return null;
  }

  @override
  Constant? visitBinaryExpression(BinaryExpression node) {
    dynamic leftOperand = _valueOf(node.leftOperand.accept(this));
    if (identical(leftOperand, Constant.invalid)) {
      return leftOperand;
    }
    dynamic rightOperand = _valueOf(node.rightOperand.accept(this));
    if (identical(rightOperand, Constant.invalid)) {
      return rightOperand;
    }
    while (true) {
      if (node.operator.type == TokenType.AMPERSAND) {
        // integer or {@code null}
        if (leftOperand is int && rightOperand is int) {
          return ConstInt(leftOperand & rightOperand);
        }
      } else if (node.operator.type == TokenType.AMPERSAND_AMPERSAND) {
        // boolean or {@code null}
        if (leftOperand is bool && rightOperand is bool) {
          return ConstBool(leftOperand && rightOperand);
        }
      } else if (node.operator.type == TokenType.BANG_EQ) {
        // numeric, string, boolean, or {@code null}
        if (leftOperand is bool && rightOperand is bool) {
          return ConstBool(leftOperand != rightOperand);
        } else if (leftOperand is num && rightOperand is num) {
          return ConstBool(leftOperand != rightOperand);
        } else if (leftOperand is String && rightOperand is String) {
          return ConstBool(leftOperand != rightOperand);
        }
      } else if (node.operator.type == TokenType.BAR) {
        // integer or {@code null}
        if (leftOperand is int && rightOperand is int) {
          return ConstInt(leftOperand | rightOperand);
        }
      } else if (node.operator.type == TokenType.BAR_BAR) {
        // boolean or {@code null}
        if (leftOperand is bool && rightOperand is bool) {
          return ConstBool(leftOperand || rightOperand);
        }
      } else if (node.operator.type == TokenType.CARET) {
        // integer or {@code null}
        if (leftOperand is int && rightOperand is int) {
          return ConstInt(leftOperand ^ rightOperand);
        }
      } else if (node.operator.type == TokenType.EQ_EQ) {
        // numeric, string, boolean, or {@code null}
        if (leftOperand is bool && rightOperand is bool) {
          return ConstBool(leftOperand == rightOperand);
        } else if (leftOperand is num && rightOperand is num) {
          return ConstBool(leftOperand == rightOperand);
        } else if (leftOperand is String && rightOperand is String) {
          return ConstBool(leftOperand == rightOperand);
        }
      } else if (node.operator.type == TokenType.GT) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return ConstBool(leftOperand.compareTo(rightOperand) > 0);
        }
      } else if (node.operator.type == TokenType.GT_EQ) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return ConstBool(leftOperand.compareTo(rightOperand) >= 0);
        }
      } else if (node.operator.type == TokenType.GT_GT) {
        // integer or {@code null}
        if (leftOperand is int && rightOperand is int) {
          return ConstInt(leftOperand >> rightOperand);
        }
      } else if (node.operator.type == TokenType.GT_GT_GT) {
        if (leftOperand is int && rightOperand is int) {
          return ConstInt(
            rightOperand >= 64 ? 0 : (leftOperand >> rightOperand) & ((1 << (64 - rightOperand)) - 1),
          );
        }
      } else if (node.operator.type == TokenType.LT) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return ConstBool(leftOperand.compareTo(rightOperand) < 0);
        }
      } else if (node.operator.type == TokenType.LT_EQ) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return ConstBool(leftOperand.compareTo(rightOperand) <= 0);
        }
      } else if (node.operator.type == TokenType.LT_LT) {
        // integer or {@code null}
        if (leftOperand is int && rightOperand is int) {
          return ConstInt(leftOperand << rightOperand);
        }
      } else if (node.operator.type == TokenType.MINUS) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return ConstNum(leftOperand - rightOperand);
        }
      } else if (node.operator.type == TokenType.PERCENT) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return ConstNum(leftOperand.remainder(rightOperand));
        }
      } else if (node.operator.type == TokenType.PLUS) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return ConstNum(leftOperand + rightOperand);
        }
        if (leftOperand is String && rightOperand is String) {
          return ConstString(leftOperand + rightOperand);
        }
      } else if (node.operator.type == TokenType.STAR) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return ConstNum(leftOperand * rightOperand);
        }
      } else if (node.operator.type == TokenType.SLASH) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return ConstNum(leftOperand / rightOperand);
        }
      } else if (node.operator.type == TokenType.TILDE_SLASH) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return ConstNum(leftOperand ~/ rightOperand);
        }
      }
      break;
    }
    // TODO This doesn't handle numeric conversions.
    return visitExpression(node);
  }

  @override
  Constant? visitDoubleLiteral(DoubleLiteral node) => ConstDouble(node.value);

  @override
  Constant? visitIntegerLiteral(IntegerLiteral node) => node.value == null ? null : ConstInt(node.value!);

  @override
  Constant? visitInterpolationExpression(InterpolationExpression node) {
    Constant? value = node.expression.accept(this);
    if (value == null || value is ConstBool || value is ConstString || value is ConstNum) {
      return value;
    }
    return Constant.invalid;
  }

  @override
  Constant? visitBooleanLiteral(BooleanLiteral node) => ConstBool(node.value);

  @override
  Constant? visitInterpolationString(InterpolationString node) => ConstString(node.value);

  @override
  Constant? visitListLiteral(ListLiteral node) {
    List<Constant> list = <Constant>[];
    for (CollectionElement element in node.elements) {
      if (element is Expression) {
        Constant? value = element.accept(this);
        if (value == null || identical(value, Constant.invalid)) {
          return value;
        }
        list.add(value);
      } else {
        // There are a lot of constants that this class does not support, so we
        // didn't add support for the extended collection support.
        return Constant.invalid;
      }
    }
    return ConstList(list);
  }

  @override
  Constant? visitMethodInvocation(MethodInvocation node) {
    final Expression? target = node.target;
    final List<String> parts = <String>[
      if (target is SimpleIdentifier) target.name,
      if (target is PrefixedIdentifier) ...<String>[
        target.prefix.name,
        target.identifier.name,
      ],
      node.methodName.name,
    ];
    if (parts.length < 3) {
      parts.add('');
    }
    final IdentifierRef identifierRef = _resolver.resolveIdentifier(
      _library,
      parts,
    );
    final (
      LibraryElementImpl lib,
      AstNode constructorNode,
      DeclarationRef loc,
    ) = _resolver.astNodeFor(
      identifierRef,
      _library,
    );

    if (constructorNode is! ConstructorDeclaration) {
      throw Exception(
        'Expected ConstructorDeclaration, but got ${constructorNode.runtimeType}',
      );
    }
    final Constant? constant = visitElementScoped(lib, () {
      return evaluate(constructorNode);
    });

    if (constant is ConstObjectImpl) {
      return visitElementScoped(_library, () {
        return constant.construct(
          node.argumentList,
          this,
          constructorNode.name?.lexeme,
        );
      });
    }
    return Constant.invalid;
  }

  @override
  Constant? visitNode(AstNode node) => Constant.invalid;

  @override
  Constant? visitNullLiteral(NullLiteral node) => null;

  @override
  Constant? visitParenthesizedExpression(ParenthesizedExpression node) => node.expression.accept(this);

  @override
  Constant? visitPropertyAccess(PropertyAccess node) {
    final Expression target = node.realTarget;
    if (target is PrefixedIdentifier) {
      return _getConstantValue(
        IdentifierRef(
          node.propertyName.name,
          prefix: target.identifier.name,
          importPrefix: target.prefix.name,
        ),
        _library,
      );
    }
    return Constant.invalid;
  }

  @override
  Constant? visitPrefixedIdentifier(PrefixedIdentifier node) {
    return _getConstantValue(IdentifierRef.from(node), _library);
  }

  @override
  Constant? visitPrefixExpression(PrefixExpression node) {
    dynamic operand = _valueOf(node.operand.accept(this));
    if (identical(operand, Constant.invalid)) {
      return operand;
    }
    while (true) {
      if (node.operator.type == TokenType.BANG) {
        if (identical(operand, true)) {
          return ConstBool(false);
        } else if (identical(operand, false)) {
          return ConstBool(true);
        }
      } else if (node.operator.type == TokenType.TILDE) {
        if (operand is int) {
          return ConstInt(~operand);
        }
      } else if (node.operator.type == TokenType.MINUS) {
        if (operand == null) {
          return null;
        } else if (operand is num) {
          return ConstNum(-operand);
        }
      } else {}
      break;
    }
    return Constant.invalid;
  }

  @override
  Constant? visitSetOrMapLiteral(SetOrMapLiteral node) {
    final NodeList<CollectionElement> elements = node.elements;
    if (elements.isEmpty) return ConstSet(const <Constant>{});

    final bool isMap = elements.first is MapLiteralEntry;

    if (!isMap) {
      final Set<Constant> elements = <Constant>{};
      for (CollectionElement element in node.elements) {
        final Constant? constant = element.accept(this);
        if (constant != null && constant != Constant.invalid) {
          elements.add(constant);
        } else {
          return Constant.invalid;
        }
      }
      return ConstSet(elements);
    }

    Map<Constant, Constant> map = HashMap<Constant, Constant>();
    for (CollectionElement element in node.elements) {
      if (element is MapLiteralEntry) {
        Constant? key = element.key.accept(this);
        Constant? value = element.value.accept(this);
        if (key != null && value != null && !identical(value, Constant.invalid)) {
          map[key] = value;
        } else {
          return Constant.invalid;
        }
      } else {
        // There are a lot of constants that this class does not support, so
        // we didn't add support for the extended collection support.
        return Constant.invalid;
      }
    }
    return ConstMap(map);
  }

  @override
  Constant? visitSimpleIdentifier(SimpleIdentifier node) {
    final NamedCompilationUnitMember? namedUnit = node.thisOrAncestorOfType<NamedCompilationUnitMember>();
    String? prefix;
    if (namedUnit != null) {
      bool isMember = namedUnit.childEntities.whereType<ClassMember>().any((
        ClassMember m,
      ) {
        if (m is MethodDeclaration) {
          return m.name.lexeme == node.name;
        } else if (m is FieldDeclaration) {
          return m.fields.variables.any(
            (VariableDeclaration v) => v.name.lexeme == node.name,
          );
        }
        return false;
      });
      if (isMember) {
        prefix = namedUnit.name.lexeme;
      }
    }
    return _getConstantValue(
      IdentifierRef(node.name, prefix: prefix),
      _library,
    );
  }

  @override
  Constant? visitFunctionReference(FunctionReference node) {
    final Constant? value = node.function.accept(this);
    if (value is ConstFunctionReferenceImpl) {
      for (final TypeAnnotation typeArg in <TypeAnnotation>[
        ...?node.typeArguments?.arguments,
      ]) {
        final DartType type = _elementBuilder.resolveTypeRef(
          (typeArg),
          _library,
        );
        value.addTypeArgument(type);
      }
    }
    return value;
  }

  @override
  Constant? visitSimpleStringLiteral(SimpleStringLiteral node) => ConstString(node.value);

  @override
  Constant? visitStringInterpolation(StringInterpolation node) {
    StringBuffer buffer = StringBuffer();
    for (InterpolationElement element in node.elements) {
      Constant? value = element.accept(this);
      if (identical(value, Constant.invalid)) {
        return value;
      }
      buffer.write(value);
    }
    return ConstString(buffer.toString());
  }

  @override
  Constant? visitSymbolLiteral(SymbolLiteral node) {
    StringBuffer buffer = StringBuffer();
    for (Token component in node.components) {
      if (buffer.length > 0) {
        buffer.writeCharCode(0x2E);
      }
      buffer.write(component.lexeme);
    }
    return ConstSymbol(buffer.toString());
  }

  /// Return the constant value of the static constant represented by the given
  /// [objectArg].
  Constant _getConstantValue(IdentifierRef ref, LibraryElement library) {
    final (LibraryElementImpl lib, AstNode node, DeclarationRef loc) = _resolver.astNodeFor(ref, library);

    if (node is TopLevelVariableDeclaration) {
      final VariableDeclaration variable = node.variables.variables.firstWhere(
        (VariableDeclaration e) => e.name.lexeme == ref.topLevelTarget,
        orElse: () => throw Exception(
          'Identifier ${ref.topLevelTarget} not found in ${lib.src.uri}',
        ),
      );
      final Expression? initializer = variable.initializer;
      if (initializer != null) {
        final Constant? resolved = initializer.accept(this);
        if (resolved != null && !identical(resolved, Constant.invalid)) {
          return resolved;
        }
      }
    } else if (node is FunctionDeclaration) {
      _elementBuilder.visitFunctionDeclaration(node);
      final Element? function = lib.getElement(node.name.lexeme);
      if (function is FunctionElement) {
        return ConstFunctionReferenceImpl(
          name: node.name.lexeme,
          element: function,
          declaration: loc,
        );
      } else {
        throw Exception(
          'Function ${node.name.lexeme} not found in ${lib.src.uri}',
        );
      }
    } else if (node is NamedCompilationUnitMember) {
      final InterfaceTypeImpl type = InterfaceTypeImpl(
        node.name.lexeme,
        loc,
        _resolver,
      );
      return ConstType(type);
    } else if (node is MethodDeclaration) {
      assert(
        node.isStatic,
        'Methods reference in constant context should be static',
      );

      final MethodElement? method = _elementBuilder.visitElementScoped(lib, () {
        final NamedCompilationUnitMember parent = node.parent as NamedCompilationUnitMember;
        parent.accept(_elementBuilder);
        final Element? interfaceElement = lib.getElement(parent.name.lexeme);
        if (interfaceElement is! InterfaceElement) {
          throw Exception(
            'Expected InterfaceElement, but got ${interfaceElement.runtimeType}',
          );
        }
        _elementBuilder.visitElementScoped(interfaceElement, () {
          _elementBuilder.visitMethodDeclaration(node);
        });
        final MethodElement? method = interfaceElement.getMethod(
          node.name.lexeme,
        );
        if (method == null) {
          throw Exception(
            'Method ${node.name.lexeme} not found in ${lib.src.uri}',
          );
        }
        return method;
      });
      return ConstFunctionReferenceImpl(
        name: method!.name,
        element: method,
        declaration: loc,
      );
    } else if (node is EnumConstantDeclaration) {
      final String name = node.name.lexeme;
      final EnumDeclaration enumDeclaration = node.parent as EnumDeclaration;
      final int index = enumDeclaration.constants.indexWhere(
        (EnumConstantDeclaration e) => e.name.lexeme == name,
      );
      final InterfaceTypeImpl enumType = InterfaceTypeImpl(
        enumDeclaration.name.lexeme,
        loc,
        _resolver,
      );
      return ConstEnumValue(node.name.lexeme, index, enumType);
    } else if (node is FieldDeclaration) {
      assert(
        node.isStatic,
        'Fields reference in constant context should be static',
      );
      final VariableDeclaration variable = node.fields.variables.firstWhere(
        (VariableDeclaration e) => e.name.lexeme == ref.name,
        orElse: () => throw Exception(
          'Identifier ${ref.name} not found in ${lib.src.uri}',
        ),
      );
      final Expression? initializer = variable.initializer;
      if (initializer != null) {
        final Constant? resolved = initializer.accept(this);
        if (resolved != null && !identical(resolved, Constant.invalid)) {
          return resolved;
        }
      }
    }
    return Constant.invalid;
  }
}
