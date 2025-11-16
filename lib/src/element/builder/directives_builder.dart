import 'package:analyzer/dart/ast/ast.dart'
    show
        ImportDirective,
        ExportDirective,
        PartDirective,
        PartOfDirective,
        LibraryDirective,
        Combinator,
        ShowCombinator,
        HideCombinator,
        SimpleIdentifier;
import 'package:lean_builder/src/element/builder/element_builder.dart';
import 'package:lean_builder/src/element/element.dart';
import 'package:lean_builder/src/graph/directive_statement.dart';
import 'package:lean_builder/src/graph/scan_results.dart';

/// A Specialized [ElementBuilder] for building directive elements.
/// to reduce the complexity of the [ElementBuilder] class.
///
/// See [ElementBuilder] for more information.
class DirectivesBuilder extends ElementBuilder {
  /// Creates a new instance of [DirectivesBuilder].
  DirectivesBuilder(super.resolver, super.rootLibrary);

  @override
  void visitImportDirective(ImportDirective node) {
    final String? stringUri = node.uri.stringValue;
    if (stringUri == null) return;
    final LibraryElementImpl library = currentLibrary();
    final List<dynamic> directive = _getCorrespondingDirective(
      library,
      stringUri,
      DirectiveStatement.import,
    );
    final List<String> showNames = <String>[];
    final List<String> hideNames = <String>[];
    for (final Combinator comb in node.combinators) {
      if (comb is ShowCombinator) {
        showNames.addAll(comb.shownNames.map((SimpleIdentifier e) => e.name));
      } else if (comb is HideCombinator) {
        hideNames.addAll(comb.hiddenNames.map((SimpleIdentifier e) => e.name));
      }
    }

    final ImportElement element = ImportElement(
      library: library,
      stringUri: stringUri,
      srcId: directive[GraphIndex.directiveSrc],
      uri: resolver.uriForAsset(directive[GraphIndex.directiveSrc]),
      shownNames: showNames,
      hiddenNames: hideNames,
      prefix: node.prefix?.name,
      isDeferred: node.deferredKeyword != null,
    );
    setCodeRange(element, node);
    element.setNameRange(node.uri.offset, node.uri.length);
    visitElementScoped(element, () {
      node.documentationComment?.accept(this);
    });

    library.addElement(element);
    registerMetadataResolver(element, node.metadata);
  }

  @override
  void visitExportDirective(ExportDirective node) {
    final String? stringUri = node.uri.stringValue;
    if (stringUri == null) return;
    final LibraryElementImpl library = currentLibrary();
    final List<dynamic> directive = _getCorrespondingDirective(
      library,
      stringUri,
      DirectiveStatement.export,
    );
    final List<String> showNames = <String>[];
    final List<String> hideNames = <String>[];
    for (final Combinator comb in node.combinators) {
      if (comb is ShowCombinator) {
        showNames.addAll(comb.shownNames.map((SimpleIdentifier e) => e.name));
      } else if (comb is HideCombinator) {
        hideNames.addAll(comb.hiddenNames.map((SimpleIdentifier e) => e.name));
      }
    }

    final ExportElement element = ExportElement(
      library: library,
      stringUri: stringUri,
      srcId: directive[GraphIndex.directiveSrc],
      uri: resolver.uriForAsset(directive[GraphIndex.directiveSrc]),
      shownNames: showNames,
      hiddenNames: hideNames,
    );
    setCodeRange(element, node);
    element.setNameRange(node.uri.offset, node.uri.length);
    visitElementScoped(element, () {
      node.documentationComment?.accept(this);
    });

    library.addElement(element);
    registerMetadataResolver(element, node.metadata);
  }

  @override
  void visitPartDirective(PartDirective node) {
    final String? stringUri = node.uri.stringValue;
    if (stringUri == null) return;
    final LibraryElementImpl library = currentLibrary();
    final List<dynamic> directive = _getCorrespondingDirective(
      library,
      stringUri,
      DirectiveStatement.part,
    );
    final PartElement element = PartElement(
      library: library,
      stringUri: stringUri,
      srcId: directive[GraphIndex.directiveSrc],
      uri: resolver.uriForAsset(directive[GraphIndex.directiveSrc]),
    );
    setCodeRange(element, node);
    element.setNameRange(node.uri.offset, node.uri.length);
    visitElementScoped(element, () {
      node.documentationComment?.accept(this);
    });

    library.addElement(element);
    registerMetadataResolver(element, node.metadata);
  }

  @override
  void visitPartOfDirective(PartOfDirective node) {
    final String? stringUri = node.uri?.stringValue;
    if (stringUri == null) return;
    final LibraryElementImpl library = currentLibrary();
    final String thisSrc = library.src.id;
    final List<dynamic>? partOf = resolver.graph.partOfOf(thisSrc);
    assert(
      partOf != null && partOf[GraphIndex.directiveStringUri] == stringUri,
    );
    final String actualSrc = partOf![GraphIndex.directiveSrc];
    final PartOfElement element = PartOfElement(
      referencesLibraryDirective: true,
      uri: resolver.uriForAsset(actualSrc),
      library: library,
      srcId: actualSrc,
      stringUri: stringUri,
    );
    setCodeRange(element, node);
    element.setNameRange(node.uri!.offset, node.uri!.length);
    visitElementScoped(element, () {
      node.documentationComment?.accept(this);
    });
    library.addElement(element);
    registerMetadataResolver(element, node.metadata);
  }

  @override
  void visitLibraryDirective(LibraryDirective node) {
    final String? name = node.name?.name;
    if (name == null) return;
    final LibraryElementImpl library = currentLibrary();
    final List<dynamic>? asset = resolver.graph.assets[library.src.id];
    assert(
      asset?.elementAtOrNull(GraphIndex.assetLibraryName) == name,
      'Library name mismatch: ${asset?.elementAtOrNull(GraphIndex.assetLibraryName)} != $name',
    );
    final LibraryDirectiveElement element = LibraryDirectiveElement(
      library: library,
      stringUri: name,
      srcId: library.src.id,
      uri: resolver.uriForAsset(library.src.id),
    );

    setCodeRange(element, node);
    element.setNameRange(
      node.name?.offset ?? node.offset,
      node.name?.length ?? node.length,
    );

    visitElementScoped(element, () {
      node.documentationComment?.accept(this);
    });
    library.addElement(element);
    registerMetadataResolver(element, node.metadata);
  }

  List<dynamic> _getCorrespondingDirective(
    LibraryElementImpl library,
    String stringUri,
    int type,
  ) {
    final List<List<dynamic>>? fileDirectives = resolver.graph.directives[library.src.id];
    if (fileDirectives == null) {
      throw StateError('No directives found for ${library.src.shortUri}');
    }
    final List<dynamic> directive = fileDirectives.firstWhere(
      (List<dynamic> element) =>
          element[GraphIndex.directiveStringUri] == stringUri && element[GraphIndex.directiveType] == type,
      orElse: () => throw StateError(
        'No export directive found for $stringUri in ${library.src.shortUri}',
      ),
    );
    return directive;
  }
}
