import 'dart:collection' show HashMap;

import 'package:lean_builder/src/build_script/parsed_builder_entry.dart';

const String _leanBuilderImport = 'package:lean_builder/runner.dart';
const String _isolateImport = 'dart:isolate';

/// Generates the build script for the given entries.
String generateBuildScript(List<BuilderDefinitionEntry> entries) {
  assert(entries.isNotEmpty);
  final Map<String, String> importPrefixes = HashMap<String, String>();

  final StringBuffer buffer = StringBuffer();
  final Function writeln = buffer.writeln;
  final void Function(Object? object) write = buffer.write;
  writeln('// This is an auto-generated build script.');
  writeln('// Do not modify by hand.');

  final Set<String> imports = <String>{_isolateImport, _leanBuilderImport};
  for (final BuilderDefinitionEntry entry in entries) {
    imports.add(entry.import);
    if (entry.registeredTypes != null) {
      for (final RuntimeTypeRegisterEntry annotation in entry.registeredTypes!) {
        if (annotation.import != null) {
          imports.add(annotation.import!);
        }
      }
    }
  }
  for (final String import in imports) {
    final String prefix = importPrefixes[import] ??= 'i${importPrefixes.length + 1}';
    writeln('import \'$import\' as $prefix;');
  }
  final String builderPrefix = importPrefixes[_leanBuilderImport]!;
  final String isolatePrefix = importPrefixes[_isolateImport]!;

  writeln('final _builders = <$builderPrefix.BuilderEntry>[');
  for (final BuilderDefinitionEntry entry in entries) {
    final String prefix = importPrefixes[entry.import]!;
    writeln('$builderPrefix.BuilderEntry');

    final Map<String, String> typeRegMap = <String, String>{};
    for (final RuntimeTypeRegisterEntry reg in <RuntimeTypeRegisterEntry>{
      ...?entry.registeredTypes,
    }) {
      final String? importPrefix = importPrefixes[reg.import];
      typeRegMap[<String>[
            ?importPrefix,
            reg.name,
          ].join('.')] =
          reg.srcId;
    }

    final BuilderType type = entry.builderType;

    write(switch (type) {
      BuilderType.shared => '.forSharedPart(',
      BuilderType.library => '.forLibrary(',
      BuilderType.custom => '(',
    });

    final List<String> props = <String>[
      '\'${entry.key}\'',
      if (type.isLibrary)
        'outputExtensions'
            ' : {${entry.outputExtensions!.map((String e) => "'$e'").join(', ')}}',
      entry.expectsOptions ? '$prefix.${entry.generatorName}.new' : '(_)=> $prefix.${entry.generatorName}()',
      if (entry.generateToCache != null) 'generateToCache: ${entry.generateToCache}',
      if (typeRegMap.isNotEmpty)
        'registeredTypes: {${typeRegMap.entries.map((MapEntry<String, String> e) => "${e.key}: '${e.value}' ").join(', ')}}',
      if (entry.allowSyntaxErrors != null) 'allowSyntaxErrors: ${entry.allowSyntaxErrors}',
      if (entry.generateFor?.isNotEmpty == true)
        'generateFor: {${entry.generateFor!.map((String e) => "'$e'").join(', ')}}',
      if (entry.runsBefore?.isNotEmpty == true)
        'runsBefore: {${entry.runsBefore!.map((String e) => "'$e'").join(', ')}}',
      if (entry.applies?.isNotEmpty == true) 'applies: {${entry.applies!.map((String e) => "'$e'").join(', ')}}',
      if (entry.options?.isNotEmpty == true)
        'options: ${entry.options!.map((String k, dynamic v) => MapEntry<String, dynamic>("'$k'", v))}',
    ];
    writeln('${props.join(',\n')},');

    writeln('),');
  }
  writeln('];');

  write('''
  void main(List<String> args, $isolatePrefix.SendPort? sendPort)  async{
    final result =  await $builderPrefix.runBuilders(_builders, args);
    sendPort?.send(result);
  }
  ''');
  return buffer.toString();
}
