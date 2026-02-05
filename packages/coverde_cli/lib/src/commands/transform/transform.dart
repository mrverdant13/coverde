import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/features/coverde_config/coverde_config.dart';
import 'package:coverde/src/features/transformations/transformations.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:universal_io/io.dart';

export 'failures.dart';

/// {@template transform_cmd}
/// A command to transform coverage info files.
/// {@endtemplate}
class TransformCommand extends CoverdeCommand {
  /// {@macro transform_cmd}
  TransformCommand() {
    argParser
      ..addOption(
        inputOption,
        abbr: inputOption[0],
        help: 'Origin coverage info file to transform.',
        defaultsTo: 'coverage/lcov.info',
        valueHelp: _inputHelpValue,
      )
      ..addOption(
        outputOption,
        abbr: outputOption[0],
        help: '''
Destination coverage info file to dump the transformed coverage data into.''',
        defaultsTo: 'coverage/transformed.lcov.info',
        valueHelp: _outputHelpValue,
      )
      ..addMultiOption(
        transformationsOption,
        abbr: transformationsOption[0],
        help: '''
Transformation steps to apply in order.''',
        defaultsTo: [],
        allowedHelp: {
          'keep-by-regex=<regex>': //
              'Keep files that match the <regex>.',
          'skip-by-regex=<regex>': //
              'Skip files that match the <regex>.',
          'keep-by-glob=<glob>': //
              'Keep files that match the <glob>.',
          'skip-by-glob=<glob>': //
              'Skip files that match the <glob>.',
          'relative=<base-path>': //
              'Rewrite file paths to be relative to the <base-path>.',
          'preset=<name>': //
              'Expand a preset from coverde.yaml.',
        },
        valueHelp: _transformationsHelpValue,
      )
      ..addFlag(
        explainFlag,
        abbr: explainFlag[0],
        help: 'Print the resolved transformation list and exit without '
            'modifying files.',
        negatable: false,
      )
      ..addOption(
        modeOption,
        abbr: modeOption[0],
        help: 'The mode in which the $_outputHelpValue can be generated.',
        valueHelp: _modeHelpValue,
        allowed: _outModeAllowedHelp.keys,
        allowedHelp: _outModeAllowedHelp,
        defaultsTo: _outModeAllowedHelp.keys.first,
      );
  }

  static const _inputHelpValue = 'INPUT_LCOV_FILE';
  static const _outputHelpValue = 'OUTPUT_LCOV_FILE';
  static const _transformationsHelpValue = 'TRANSFORMATIONS';
  static const _modeHelpValue = 'MODE';
  static const _outModeAllowedHelp = {
    'a': '''
Append transformed content to the $_outputHelpValue content, if any.''',
    'w': '''
Override the $_outputHelpValue content, if any, with the transformed content.''',
  };

  /// Option name for the transformation steps to apply in order.
  @visibleForTesting
  static const transformationsOption = 'transformations';

  /// Option name for the origin trace file to be transformed.
  @visibleForTesting
  static const inputOption = 'input';

  /// Option name for the resulting transformed trace file.
  @visibleForTesting
  static const outputOption = 'output';

  /// Option name for the flag to print the resolved transformation list and
  /// exit without modifying files.
  @visibleForTesting
  static const explainFlag = 'explain';

  /// Option name for the mode in which the $_outputHelpValue can be generated.
  @visibleForTesting
  static const modeOption = 'mode';

  /// The name of the configuration file.
  static const _configFileName = 'coverde.yaml';

  @override
  String get description => '''
Transform a coverage trace file.

Apply a sequence of transformations to the coverage data.
The coverage data is taken from the $_inputHelpValue file and written to the $_outputHelpValue file.

Presets can be defined in $_configFileName under transformations.<name>.''';

  @override
  String get name => 'transform';

  @override
  bool get takesArguments => false;

  @override
  Future<void> run() async {
    final argResults = this.argResults!;
    final rawTransformations = argResults.multiOption(transformationsOption);
    final explain = argResults.flag(explainFlag);

    final coverdeConfigPath = path.joinAll([
      Directory.current.path,
      _configFileName,
    ]);

    final String rawCoverdeConfig;
    try {
      rawCoverdeConfig =
          switch (FileSystemEntity.isFileSync(coverdeConfigPath)) {
        true => File(coverdeConfigPath).readAsStringSync(),
        false => '{}',
      };
    } on FileSystemException catch (exception) {
      throw CoverdeTransformFileReadFailure.fromFileSystemException(
        filePath: coverdeConfigPath,
        exception: exception,
      );
    }
    final CoverdeConfig config;
    try {
      config = CoverdeConfig.fromYaml(rawCoverdeConfig);
    } on CoverdeConfigFromYamlFailure catch (failure, stackTrace) {
      Error.throwWithStackTrace(
        CoverdeTransformInvalidConfigFileFailure(
          configPath: coverdeConfigPath,
          failure: failure,
        ),
        stackTrace,
      );
    }

    final steps = _resolveSteps(
      rawTransformations: rawTransformations,
      presets: config.presets,
      configPath: coverdeConfigPath,
    );

    if (explain) {
      _printExplain(steps);
      return;
    }

    final originPath = argResults.option(inputOption)!;
    final destinationPath = argResults.option(outputOption)!;
    final shouldOverride = argResults.option(modeOption) == 'w';

    if (!FileSystemEntity.isFileSync(originPath)) {
      throw CoverdeTransformTraceFileNotFoundFailure(
        traceFilePath: originPath,
      );
    }
    final origin = File(originPath);
    final destination = File(destinationPath);

    final TraceFile traceFile;
    try {
      traceFile = await TraceFile.parseStreaming(origin);
    } on FileSystemException catch (exception) {
      throw CoverdeTransformFileReadFailure.fromFileSystemException(
        filePath: originPath,
        exception: exception,
      );
    }

    final acceptedRawData = _applyTransformations(traceFile, steps);

    try {
      destination.parent.createSync(recursive: true);
    } on FileSystemException catch (exception, stackTrace) {
      Error.throwWithStackTrace(
        CoverdeTransformDirectoryCreateFailure.fromFileSystemException(
          directoryPath: destination.parent.path,
          exception: exception,
        ),
        stackTrace,
      );
    }
    final finalContent = acceptedRawData.join('\n');

    RandomAccessFile? raf;
    try {
      raf = await destination.open(
        mode: shouldOverride ? FileMode.writeOnly : FileMode.append,
      );
      await raf.lock(
        FileLock.blockingExclusive,
      );
      if (shouldOverride) {
        await raf.truncate(0);
      } else {
        final length = await raf.length();
        await raf.setPosition(length);
        if (length > 0) await raf.writeString('\n');
      }
      await raf.writeString(finalContent);
      await raf.flush();
    } on FileSystemException catch (exception, stackTrace) {
      Error.throwWithStackTrace(
        CoverdeTransformFileWriteFailure.fromFileSystemException(
          filePath: destination.path,
          exception: exception,
        ),
        stackTrace,
      );
    } finally {
      await raf?.unlock();
      await raf?.close();
    }
  }

  void _printExplain(List<Transformation> steps) {
    var i = 1;
    final stepsWithPresetChains = steps.getStepsWithPresetChains();
    for (final (:presets, :transformation) in stepsWithPresetChains) {
      final suffix = presets.isEmpty
          ? ''
          : '   (from preset ${presets.join(presetChainSeparator)})';
      logger.info('$i. ${transformation.describe}$suffix');
      i++;
    }
  }

  List<Transformation> _resolveSteps({
    required List<String> rawTransformations,
    required List<PresetTransformation> presets,
    required String configPath,
  }) {
    final result = <Transformation>[];

    for (final untrimmedRawTransformation in rawTransformations) {
      final rawTransformation = untrimmedRawTransformation.trim();
      try {
        result.add(
          Transformation.fromCliOption(
            rawTransformation,
            presets: presets,
          ),
        );
      } on TransformationFromCliOptionFailure catch (failure, stackTrace) {
        Error.throwWithStackTrace(
          CoverdeTransformInvalidTransformCliOptionFailure(
            failure: failure,
          ),
          stackTrace,
        );
      }
    }

    return result;
  }

  List<String> _applyTransformations(
    TraceFile traceFile,
    List<Transformation> steps,
  ) {
    var entries = traceFile.sourceFilesCovData
        .map((f) => (path: f.source.path, raw: f.raw))
        .toList();

    final flatSteps = steps.flattenedSteps;
    for (final step in flatSteps) {
      switch (step) {
        case KeepByRegexTransformation(:final regex):
          entries = entries.where((e) => regex.hasMatch(e.path)).toList();
        case SkipByRegexTransformation(:final regex):
          entries = entries.where((e) => !regex.hasMatch(e.path)).toList();
        case KeepByGlobTransformation(:final glob):
          entries = entries
              .where((e) => glob.matches(_normalizePath(e.path)))
              .toList();
        case SkipByGlobTransformation(:final glob):
          entries = entries
              .where((e) => !glob.matches(_normalizePath(e.path)))
              .toList();
        case RelativeTransformation(basePath: final bp):
          entries = entries.map((e) {
            final newPath = path.relative(e.path, from: bp);
            final newRaw = e.raw.replaceFirst(
              RegExp(r'^SF:(.*)$', multiLine: true),
              'SF:$newPath',
            );
            return (path: newPath, raw: newRaw);
          }).toList();
      }
    }

    return entries.map((e) => e.raw).toList();
  }

  /// Normalize path for glob matching (use posix separators).
  String _normalizePath(String pth) {
    return path.posix.joinAll(path.split(pth));
  }
}
