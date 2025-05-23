/// Directory where build cache and generated files are stored.
/// This is a subdirectory within the standard Dart tool directory.
const String cacheDir = '.dart_tool/lean_build';

/// Path to the generated build script Dart file.
/// This is the entry point for the build process.
const String buildScriptOutput = '$cacheDir/script/build.dart';

/// Path to the compiled executable version of the build script.
/// When compiled, the build script is stored at this location.
const String buildScriptAot = '$cacheDir/script/build.aot';

/// Directory where all generated code is stored.
/// Files created during the build process are placed here.
const String generatedDir = '$cacheDir/generated';

/// Path to the pre-build script kernel file.
/// This is used for pre-compilation of the build script.
const String preBuildScriptKernel = '$cacheDir/script/pre_build_script.dill';
