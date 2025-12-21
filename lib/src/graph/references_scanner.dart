import 'dart:math' as math show max;
import 'dart:typed_data' show Uint8List;
import 'package:path/path.dart' as p show extension;

// ignore: implementation_imports
import 'package:_fe_analyzer_shared/src/scanner/scanner.dart' as fasta;
import 'package:analyzer/dart/ast/token.dart' show TokenType, Keyword, Token;
import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/build_script/annotations.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/logger.dart';

import 'directive_statement.dart';

/// {@template references_scanner}
/// A scanner that parses Dart source files to find declarations and directives.
///
/// The [ReferencesScanner] reads and analyzes Dart source code to:
/// - Identify top-level declarations (classes, functions, extensions, etc.)
/// - Detect import, export, part, and library directives
/// - Track annotations (including builder annotations)
///
/// It uses a lightweight token-based approach rather than a full AST parser
///
/// The results of this scanner are used to build a reference graph of the
/// Dart codebase, which can later be used for resolving references and dependencies.
/// {@endtemplate}
class ReferencesScanner {
  /// The results collector that will store discovered references
  final ScanResults results;

  /// The file resolver used to resolve file references
  final PackageFileResolver fileResolver;

  /// {@macro references_scanner}
  ReferencesScanner(this.results, this.fileResolver);

  /// {@template references_scanner.scan}
  /// Scans a Dart source file to identify declarations and directives.
  ///
  /// This method:
  /// 1. Tokenizes the source file
  /// 2. Analyzes tokens to find declarations and directives
  /// 3. Records results in the [ScanResults] collector
  ///
  /// [asset] The asset to scan
  /// [forceOverride] When true, re-scans the asset even if it has been visited before
  /// {@endtemplate}
  void scan(Asset asset, {bool forceOverride = false}) {
    try {
      if (results.isVisited(asset.id) && !forceOverride) return;

      final Uint8List bytes = asset.readAsBytesSync();

      results.addAsset(asset);
      // do not scan non-Dart files
      if (p.extension(asset.uri.path) != '.dart') {
        results.updateAssetInfo(asset, content: bytes);
        return;
      }

      Token? token = fasta.scan(bytes).tokens;
      String? libraryName;
      int annotationFlag = 0;

      while (token != null && !token.isEof && token.next != null) {
        token = _skipCurlyBrackets(token);
        if (token.isEof) break;
        Token nextToken = token.next!;
        if (token.type == TokenType.AT) {
          if (kBuilderAnnotationNames.contains(nextToken.lexeme)) {
            annotationFlag |= 2;
          } else {
            annotationFlag |= 1;
          }
          token = nextToken;
          // could be import-prefixed or has a named constructor
          while (token?.next?.type == TokenType.PERIOD) {
            token = token?.next?.next;
          }
          token = _skipParenthesis(token?.next);
          continue;
        } else if (token.isTopLevelKeyword) {
          if (nextToken.isTopLevelKeyword) {
            token = nextToken;
            continue;
          }
          final TokenType type = token.type;
          final String nextLexeme = nextToken.lexeme;
          switch (type) {
            case Keyword.LIBRARY:
              final (
                fasta.Token? nextT,
                String? name,
              ) = _tryParseLibraryDirective(
                nextToken,
              );
              libraryName = name;
              nextToken = nextT ?? nextToken;
              break;
            case Keyword.IMPORT:
            case Keyword.EXPORT:
            case Keyword.PART:
              final (
                fasta.Token? nextT,
                DirectiveStatement? directive,
              ) = _tryParseDirective(
                type,
                nextToken,
                asset,
              );
              nextToken = nextT ?? nextToken;
              if (directive != null) {
                results.addDirective(asset, directive);
              }
              break;
            case Keyword.TYPEDEF:
              nextToken = parseTypeDef(nextToken, asset) ?? nextToken;
              break;
            case Keyword.CLASS:
              results.addDeclaration(nextLexeme, asset, ReferenceType.$class);
              nextToken = _skipUntilAny(token, <TokenType>{
                TokenType.OPEN_CURLY_BRACKET,
                TokenType.SEMICOLON,
              });
              break;
            case Keyword.MIXIN:
              if (nextToken.type == Keyword.CLASS) {
                break;
              }
              results.addDeclaration(nextLexeme, asset, ReferenceType.$mixin);
              nextToken = _skipUntil(token, TokenType.OPEN_CURLY_BRACKET);
              break;
            case Keyword.ENUM:
              results.addDeclaration(nextLexeme, asset, ReferenceType.$enum);
              nextToken = _skipUntil(token, TokenType.OPEN_CURLY_BRACKET);
              break;
            case Keyword.EXTENSION:
              String extName = nextLexeme;
              if (nextLexeme == 'type') {
                Token? current = nextToken.next;
                if (current != null && current.isKeyword) {
                  current = current.next;
                }
                if (current != null && current.isIdentifier) {
                  extName = current.lexeme;
                }
              }
              results.addDeclaration(extName, asset, ReferenceType.$extension);

              nextToken = _skipUntil(nextToken, TokenType.OPEN_CURLY_BRACKET);
              break;
          }
        } else if (<fasta.Keyword>{
              Keyword.CONST,
              Keyword.FINAL,
              Keyword.VAR,
              Keyword.LATE,
            }.contains(token.type) &&
            nextToken.isIdentifier) {
          if (token.type == Keyword.CONST) {
            _tryParseConstVar(nextToken, asset);
          }
          nextToken = _skipUntil(nextToken, TokenType.SEMICOLON);
        } else if (token.isIdentifier) {
          nextToken = _tryParseFunction(token, asset) ?? nextToken;
        }

        token = nextToken;
      }

      results.updateAssetInfo(
        asset,
        content: bytes,
        tlmFlag: annotationFlag,
        libraryName: libraryName,
      );
    } catch (e, stack) {
      Logger.error(
        'Error scanning asset ${asset.uri} ${e.toString()}',
        stackTrace: stack,
      );
    }
  }

  /// {@template references_scanner._try_parse_library_directive}
  /// Attempts to parse a library directive and extract the library name.
  ///
  /// [nextToken] Token following the 'library' keyword
  ///
  /// Returns a tuple containing:
  /// - The next token to continue scanning from
  /// - The parsed library name (or null if no name was found)
  /// {@endtemplate}
  (Token?, String?) _tryParseLibraryDirective(fasta.Token nextToken) {
    if (nextToken.type == TokenType.SEMICOLON) {
      nextToken = nextToken.next!;
      return (nextToken, null);
    }
    String name = '';
    Token? nameToken = nextToken;
    while (nameToken != null && nameToken.type != TokenType.SEMICOLON && !nameToken.isEof) {
      name += nameToken.lexeme;
      nameToken = nameToken.next;
    }
    return (nameToken?.next, name);
  }

  /// {@template references_scanner._try_parse_function}
  /// Attempts to parse a function declaration.
  ///
  /// This method identifies standalone functions and methods, recording them
  /// in the results collector.
  ///
  /// [token] The token that might be a function identifier
  /// [asset] The asset containing the function
  ///
  /// Returns the next token to continue scanning from
  /// {@endtemplate}
  Token? _tryParseFunction(Token token, Asset asset) {
    Token? current = _skipLTGT(token);
    current = _skipParenthesis(current);

    bool funcFound = false;
    Token? next = current?.next;
    if (current?.type == Keyword.FUNCTION) {
      current = current?.next;
    } else if (next != null && _skipLTGT(next).type == TokenType.OPEN_PAREN) {
      funcFound = true;
      if (_isValidName(current?.lexeme)) {
        results.addDeclaration(current!.lexeme, asset, ReferenceType.$function);
      }
    } else if (next != null && next.type == TokenType.LT) {
      return _skipLTGT(next);
    }

    if (!funcFound) {
      return current?.next;
    }

    while (current != null &&
        !current.isEof &&
        current.type != TokenType.OPEN_CURLY_BRACKET &&
        current.type != TokenType.FUNCTION &&
        current.type != TokenType.SEMICOLON) {
      current = current.next;
    }
    if (current?.type == TokenType.OPEN_CURLY_BRACKET) {
      return current;
    } else if (current != null && current.type == TokenType.FUNCTION) {
      current = _skipUntil(current, TokenType.SEMICOLON).next;
    } else if (current != null && current.type == TokenType.SEMICOLON) {
      current = current.next;
    }
    return current;
  }

  /// {@template references_scanner._try_parse_const_var}
  /// Attempts to parse a constant variable declaration.
  ///
  /// This method identifies top-level const variables and records them in
  /// the results collector.
  ///
  /// [nextToken] Token following the 'const' keyword
  /// [asset] The asset containing the variable
  /// {@endtemplate}
  void _tryParseConstVar(Token nextToken, Asset asset) {
    Token? currentToken = nextToken;
    // Skip type information to get to the variable name
    while (currentToken != null && currentToken.type != TokenType.SEMICOLON) {
      if (currentToken.isIdentifier) {
        fasta.Token? afterIdentifier = currentToken.next;
        if (afterIdentifier != null && (afterIdentifier.type == TokenType.EQ)) {
          results.addDeclaration(
            currentToken.lexeme,
            asset,
            ReferenceType.$variable,
          );
          break;
        }
      }
      currentToken = currentToken.next;
    }
  }

  /// {@template references_scanner._try_parse_directive}
  /// Attempts to parse an import, export, or part directive.
  ///
  /// This method extracts all relevant information from a directive, including:
  /// - The URI string
  /// - Show/hide clauses
  /// - Import prefixes
  /// - Deferred status
  ///
  /// [keyword] The directive keyword (import, export, part)
  /// [next] The token following the keyword
  /// [enclosingAsset] The asset containing the directive
  ///
  /// Returns a tuple containing:
  /// - The next token to continue scanning from
  /// - The parsed directive (or null if parsing failed)
  /// {@endtemplate}
  (Token?, DirectiveStatement?) _tryParseDirective(
    TokenType keyword,
    Token next,
    Asset enclosingAsset,
  ) {
    bool isPartOf = keyword == Keyword.PART && next.type == Keyword.OF;
    String stringUri = '';

    Token? current = next.next;

    if (isPartOf) {
      // could be pointing to a library directive which can have chained String Tokens
      if (current?.type == TokenType.STRING) {
        stringUri = current!.lexeme;
      } else {
        while (current != null && !current.isEof && current.type != TokenType.SEMICOLON) {
          stringUri += current.lexeme;
          current = current.next;
        }
        if (stringUri.isNotEmpty) {
          results.addLibraryPartOf(stringUri, enclosingAsset);
        }
        return (current, null);
      }
    } else {
      stringUri = next.lexeme;
    }

    if (stringUri.length < 3) {
      return (_skipUntil(next, TokenType.SEMICOLON), null);
    }

    // remove quotes
    stringUri = stringUri.substring(1, stringUri.length - 1);
    final Uri uri = Uri.parse(stringUri);

    // skip private package imports
    if (uri.scheme == 'package' && uri.path.isNotEmpty && uri.path[0] == '_') {
      return (_skipUntil(next, TokenType.SEMICOLON), null);
    }

    final Asset asset = fileResolver.assetForUri(uri, relativeTo: enclosingAsset);

    final List<String> show = <String>[];
    final List<String> hide = <String>[];
    String? prefix;
    bool deferred = false;
    bool showMode = true;
    for (current; current != null && !current.isEof; current = current.next) {
      if (current.type == TokenType.AS) {
        if (current.previous?.type == Keyword.DEFERRED) {
          deferred = true;
        }
        current = current.next;
        prefix = current?.lexeme;
        if (current?.next == null) break;
        current = current!.next!;
      } else if (current.type == Keyword.SHOW) {
        showMode = true;
      } else if (current.type == Keyword.HIDE) {
        showMode = false;
      } else if (current.type == TokenType.IDENTIFIER) {
        if (showMode) {
          show.add(current.lexeme);
        } else {
          hide.add(current.lexeme);
        }
      }
      if (current.type == TokenType.SEMICOLON) break;
    }

    final int type = switch (keyword) {
      Keyword.IMPORT => DirectiveStatement.import,
      Keyword.EXPORT => DirectiveStatement.export,
      Keyword.PART => isPartOf ? DirectiveStatement.partOf : DirectiveStatement.part,
      _ => throw UnimplementedError('Unknown directive type: $keyword'),
    };

    final DirectiveStatement directive = DirectiveStatement(
      type: type,
      stringUri: stringUri,
      asset: asset,
      show: show,
      hide: hide,
      prefix: prefix,
      deferred: deferred,
    );
    return (current, directive);
  }

  /// {@template references_scanner.parse_type_def}
  /// Parses a typedef declaration to extract the type alias name.
  ///
  /// This handles both function typedefs and type alias declarations.
  ///
  /// [token] Token following the 'typedef' keyword
  /// [asset] The asset containing the typedef
  ///
  /// Returns the next token to continue scanning from
  /// {@endtemplate}
  Token? parseTypeDef(Token? token, Asset asset) {
    final List<fasta.Token> identifiers = <Token>[];
    int scopeTracker = 0;
    while (token != null && token.type != TokenType.EOF) {
      token = _skipLTGT(token);
      token = _skipParenthesis(token);
      if (scopeTracker == 0 && (token != null && token.isIdentifier || token?.type == TokenType.EQ)) {
        identifiers.add(token!);
      }
      if (token?.type == TokenType.SEMICOLON) {
        token = token?.next;
        break;
      }
      token = token?.next;
    }

    final int eqIndex = identifiers.indexWhere(
      (fasta.Token e) => e.type == TokenType.EQ,
    );
    final String? nameLexeme = eqIndex > 0 ? identifiers[eqIndex - 1].lexeme : identifiers.lastOrNull?.lexeme;
    if (_isValidName(nameLexeme)) {
      results.addDeclaration(nameLexeme!, asset, ReferenceType.$typeAlias);
    }

    return token;
  }

  /// Checks if the given identifier is a valid name.
  bool _isValidName(String? identifier) {
    return identifier != null && identifier.isNotEmpty;
  }

  /// {@template references_scanner._skip_until}
  /// Skips tokens until a specific token type is encountered.
  ///
  /// [current] The token to start from
  /// [until] The token type to stop at
  ///
  /// Returns the first token that matches the specified type
  /// {@endtemplate}
  Token _skipUntil(Token current, TokenType until) {
    while (current.type != until && !current.isEof) {
      current = current.next!;
    }
    return current;
  }

  /// {@template references_scanner._skip_until_any}
  /// Skips tokens until any of the specified token types is encountered.
  ///
  /// [current] The token to start from
  /// [until] A set of token types to stop at
  ///
  /// Returns the first token that matches any of the specified types
  /// {@endtemplate}
  Token _skipUntilAny(Token current, Set<TokenType> until) {
    while (!current.isEof && !until.contains(current.type)) {
      current = current.next!;
    }
    return current;
  }

  /// {@template references_scanner._skip_curly_brackets}
  /// Skips tokens between matching curly brackets.
  ///
  /// This handles nested brackets correctly by tracking scope depth.
  ///
  /// [token] The opening curly bracket token
  ///
  /// Returns the token after the matching closing bracket
  /// {@endtemplate}
  Token _skipCurlyBrackets(Token token) {
    if (token.type != TokenType.OPEN_CURLY_BRACKET) {
      return token;
    }
    int scopeTracker = 1;
    Token? current = token.next;
    while (current != null && !current.isEof && scopeTracker != 0) {
      switch (current.type) {
        case TokenType.OPEN_CURLY_BRACKET:
        case TokenType.STRING_INTERPOLATION_EXPRESSION:
          scopeTracker += 1;
          break;
        case TokenType.CLOSE_CURLY_BRACKET:
          scopeTracker = math.max(0, scopeTracker - 1);
      }
      current = current.next;
    }
    return current ?? token;
  }

  /// {@template references_scanner._skip_lt_gt}
  /// Skips tokens between matching angle brackets (< >).
  ///
  /// This handles nested angle brackets correctly by tracking scope depth.
  /// Used for skipping generic type parameters.
  ///
  /// [token] The opening angle bracket token
  ///
  /// Returns the token after the matching closing angle bracket
  /// {@endtemplate}
  Token _skipLTGT(Token token) {
    if (token.type != TokenType.LT) {
      return token;
    }
    int scopeTracker = 1;
    Token? current = token.next;
    while (current != null && !current.isEof && scopeTracker != 0) {
      switch (current.type) {
        case TokenType.LT:
          scopeTracker += 1;
          break;
        case TokenType.LT_LT:
          scopeTracker += 2;
          break;
        case TokenType.GT:
          scopeTracker = math.max(0, scopeTracker - 1);
          break;
        case TokenType.GT_GT:
          scopeTracker = math.max(0, scopeTracker - 2);
          break;
        case TokenType.GT_GT_GT:
          scopeTracker = math.max(0, scopeTracker - 3);
          break;
      }
      current = current.next;
    }
    return current ?? token;
  }

  /// {@template references_scanner._skip_parenthesis}
  /// Skips tokens between matching parentheses.
  ///
  /// This handles nested parentheses correctly by tracking scope depth.
  ///
  /// [token] The opening parenthesis token
  ///
  /// Returns the token after the matching closing parenthesis
  /// {@endtemplate}
  Token? _skipParenthesis(Token? token) {
    if (token == null) {
      return null;
    }
    if (token.type != TokenType.OPEN_PAREN) {
      return token;
    }
    int scopeTracker = 1;
    Token? current = token.next;
    while (current != null && !current.isEof && scopeTracker != 0) {
      switch (current.type) {
        case TokenType.OPEN_PAREN:
          scopeTracker += 1;
          break;
        case TokenType.CLOSE_PAREN:
          scopeTracker = math.max(0, scopeTracker - 1);
      }
      current = current.next;
    }
    return current ?? token;
  }
}
