import 'dart:io' show File, Directory, exit, Platform, Process, ProcessStartMode;
import 'dart:isolate' show Isolate, ReceivePort;

import 'package:lean_builder/src/build_script/compile.dart';
import 'package:lean_builder/src/build_script/paths.dart' as paths;
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/runner/command/utils.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  final bool isCleanMode = args.contains('clean');

  if (isCleanMode) {
    exit(await _clean());
  }

  final bool isDevMode = args.contains('--dev');
  final bool isWatchMode = args.contains('watch');

  Uri? preBuildScriptUri = Isolate.resolvePackageUriSync(
    Uri.parse('package:lean_builder/src/build_script/pre_build_script.dart'),
  );
  if (preBuildScriptUri == null) {
    Logger.error('Could not resolve the path to pre_build_script.dart');
    exit(1);
  }

  final preBuildScriptKernelPath = p.join(p.current, paths.preBuildScriptKernel);
  if (!File(preBuildScriptKernelPath).existsSync()) {
    await compileKernel(Uri.decodeComponent(preBuildScriptUri.path), preBuildScriptKernelPath);
  }
  final messagePort = ReceivePort();

  try {
    await Isolate.spawnUri(Uri.file(preBuildScriptKernelPath), args, messagePort.sendPort, errorsAreFatal: true);
    final exitCode = await messagePort.first as int;
    if (exitCode == 2) {
      if (!isWatchMode && !isDevMode) {
        Logger.info('No Assets to process. Exiting.');
        exit(0);
      }
    } else if (exitCode != 0) {
      Logger.error('Process exited with code $exitCode');
      exit(exitCode);
    }
  } catch (e, stack) {
    Logger.error(
      'Error running pre-build script: $e\ntry running `dart run lean_builder clean` then rebuilding',
      stackTrace: stack,
    );
    exit(1);
  } finally {
    messagePort.close();
  }

  final String scriptAbsPath = p.join(p.current, paths.buildScriptOutput);

  if (isDevMode) {
    invalidateExecutable();
    await _runJit(scriptAbsPath, args, enableVmService: isWatchMode && isDevMode);
  } else {
    await _runAot(scriptAbsPath, args);
  }
}

Future<int> _runJit(String scriptPath, List<String> args, {required bool enableVmService}) async {
  Logger.warning('Running in JIT mode. This may be slower than AOT.');
  return _runProcess('dart', [if (enableVmService) '--enable-vm-service', scriptPath, ...args]);
}

Future<int> _runAot(String scriptPath, List<String> args) async {
  final File executableFile = File(p.join(p.current, paths.buildScriptAot));

  if (!executableFile.existsSync()) {
    final Stopwatch stopwatch = Stopwatch()..start();
    Logger.info('Compiling build script...');
    await compileToAotSnapshot(scriptPath, executableFile.path);
    Logger.info('Compilation completed in ${stopwatch.elapsed.formattedMS}');
  }
  return _runProcess(_getRuntimePath(), [executableFile.path, ...args]);
}

Future<int> _runProcess(String executable, List<String> arguments) async {
  final Process process = await Process.start(executable, arguments, mode: ProcessStartMode.inheritStdio);
  // Wait for the process to complete and get the exit code
  return process.exitCode;
}

String _getRuntimePath() {
  final String dartExecutable = Platform.resolvedExecutable;
  final String dartSdkDir = Directory(dartExecutable).parent.path;
  return '$dartSdkDir${Platform.pathSeparator}dartaotruntime';
}

Future<int> _clean() async {
  try {
    final String cachePath = p.join(p.current, paths.cacheDir);
    final Directory cacheDirectory = Directory(cachePath);
    if (await cacheDirectory.exists()) {
      await cacheDirectory.delete(recursive: true);
      Logger.info('Cleaned build artifacts at $cachePath');
    } else {
      Logger.info('No build artifacts found at $cachePath');
    }
    return 0;
  } catch (e) {
    Logger.error('Error cleaning build artifacts: $e');
    return 1;
  }
}
