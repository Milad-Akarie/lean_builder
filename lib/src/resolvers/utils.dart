import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/ast/token.dart';

/// Finds a declaration with the given name in a list of declarations.
extension DeclrationFinder on NodeList<Declaration> {
  /// Finds a declaration with the given name in a list of declarations.
  Declaration? findDeclarationWithName(String name) {
    for (final member in this) {
      if (member is ClassDeclaration) {
        if (member.namePart.typeName.lexeme == name) {
          return member;
        }
      } else if (member is MixinDeclaration) {
        if (member.name.lexeme == name) {
          return member;
        }
      } else if (member is ExtensionDeclaration) {
        if (member.name?.lexeme == name) {
          return member;
        }
      } else if (member is FunctionDeclaration) {
        if (member.name.lexeme == name) {
          return member;
        }
      } else if (member is EnumDeclaration) {
        if (member.namePart.typeName.lexeme == name) {
          return member;
        }
      } else if (member is ConstructorDeclaration) {
        if (member.name?.lexeme == name) {
          return member;
        }
      } else if (member is MethodDeclaration) {
        if (member.name.lexeme == name) {
          return member;
        }
      } else if (member is VariableDeclaration) {
        if (member.name.lexeme == name) {
          return member;
        }
      } else if (member is EnumConstantDeclaration) {
        if (member.name.lexeme == name) {
          return member;
        }
      }
    }
    return null;
  }
}

/// Finds body members of a declaration.
extension MemebersFinder on AstNode {
  /// Finds body members of a declaration.
  Iterable<SyntacticEntity> get bodyMembers {
    for (final child in childEntities.whereType<AstNode>()) {
      if (child is EnumBody || child is ClassBody || child is BlockClassBody) {
        return child.childEntities;
      }
    }
    return const [];
  }

  /// Finds a declaration with the given name in a list of declarations.
  ({AstNode node, Token? name})? findParentInterface() {
    AstNode? node = this;
    while (node != null) {
      if (node is ClassDeclaration) {
        return (node: node, name: node.namePart.typeName);
      } else if (node is MixinDeclaration) {
        return (node: node, name: node.name);
      } else if (node is ExtensionDeclaration) {
        return (node: node, name: node.name);
      } else if (node is FunctionDeclaration) {
        return (node: node, name: node.name);
      } else if (node is EnumDeclaration) {
        return (node: node, name: node.namePart.typeName);
      }
      node = node.parent;
    }
    return null;
  }
}
