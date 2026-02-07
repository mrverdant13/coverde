import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/features/transformations/transformations.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:universal_io/io.dart';

export 'failures.dart';

/// {@template filter_cmd}
/// A command to filter coverage info files.
/// {@endtemplate}
class FilterCommand extends CoverdeCommand {
  /// {@macro filter_cmd}
  FilterCommand() {
    argParser
      ..addOption(
        inputOption,
        abbr: inputOption[0],
        help: 'Origin coverage info file to pick coverage data from.',
        defaultsTo: 'coverage/lcov.info',
        valueHelp: _inputHelpValue,
      )
      ..addOption(
        outputOption,
        abbr: outputOption[0],
        help: '''
Destination coverage info file to dump the resulting coverage data into.''',
        defaultsTo: 'coverage/filtered.lcov.info',
        valueHelp: _outputHelpValue,
      )
      ..addOption(
        baseDirectoryOptionName,
        abbr: baseDirectoryOptionAbbreviation,
        help: '''
Base directory relative to which trace file source paths are resolved.''',
      )
      ..addMultiOption(
        filtersOption,
        abbr: filtersOption[0],
        help: '''
Set of comma-separated path patterns of the files to be ignored.

Each pattern must be a valid regex expression. Invalid patterns will cause the command to fail.''',
        defaultsTo: [],
        valueHelp: _filtersHelpValue,
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
  static const _filtersHelpValue = 'FILTERS';
  static const _modeHelpValue = 'MODE';
  static const _outModeAllowedHelp = {
    'a': '''
Append filtered content to the $_outputHelpValue content, if any.''',
    'w': '''
Override the $_outputHelpValue content, if any, with the filtered content.''',
  };

  /// Option name for identifier patters to be used for trace file filtering.
  @visibleForTesting
  static const filtersOption = 'filters';

  /// Option name for the origin trace file to be filtered.
  @visibleForTesting
  static const inputOption = 'input';

  /// Option name for the resulting filtered trace file.
  @visibleForTesting
  static const outputOption = 'output';

  /// Option name for the base directory relative to which trace file source
  /// paths are resolved.
  @visibleForTesting
  static const baseDirectoryOptionName = 'base-directory';

  /// Option abbreviation for the base directory relative to which trace file
  /// source paths are resolved.
  @visibleForTesting
  static const baseDirectoryOptionAbbreviation = 'b';

  /// Option name for the resulting filtered trace file.
  @visibleForTesting
  static const modeOption = 'mode';

  @override
  String get description => '''
[DEPRECATED] Filter a coverage trace file. Use `coverde transform` instead.

Filter the coverage info by ignoring data related to files with paths that matches the given $_filtersHelpValue.
The coverage data is taken from the $_inputHelpValue file and the result is appended to the $_outputHelpValue file.

All the relative paths in the resulting coverage trace file will be resolved relative to the <$baseDirectoryOptionName>, if provided.''';

  @override
  String get name => 'filter';

  @override
  List<String> get aliases => [name[0]];

  @override
  bool get takesArguments => false;

  /// Builds the equivalent `coverde transform` command for migration guidance.
  @visibleForTesting
  static String buildEquivalentTransformCommand({
    required String inputPath,
    required String outputPath,
    required List<String> filters,
    required String? baseDirectory,
    required String mode,
  }) {
    const inputOpt = 'input';
    const outputOpt = 'output';
    const transformationsOpt = 'transformations';
    const modeOpt = 'mode';
    final parts = <String>[
      'coverde transform',
      '--$inputOpt',
      inputPath,
      '--$outputOpt',
      outputPath,
    ];
    for (final pattern in filters) {
      parts.add(
        '--$transformationsOpt '
        '${SkipByRegexTransformation.identifier}=$pattern',
      );
    }
    if (baseDirectory != null && baseDirectory.isNotEmpty) {
      parts.add(
        '--$transformationsOpt '
        '${RelativeTransformation.identifier}=$baseDirectory',
      );
    }
    parts
      ..add('--$modeOpt')
      ..add(mode);
    return parts.join(' ');
  }

  @override
  Future<void> run() async {
    final argResults = this.argResults!;
    final originPath = argResults.option(inputOption)!;
    final destinationPath = argResults.option(outputOption)!;
    final baseDirectory = argResults.option(baseDirectoryOptionName);
    final ignorePatterns = argResults.multiOption(filtersOption);
    final mode = argResults.option(modeOption)!;

    final equivalentCommand = buildEquivalentTransformCommand(
      inputPath: originPath,
      outputPath: destinationPath,
      filters: ignorePatterns,
      baseDirectory: baseDirectory,
      mode: mode,
    );

    logger.warn(
      [
        '''The `filter` command is deprecated and will be removed in the next major update.''',
        'Use `coverde transform` instead.',
        'Equivalent command:',
        styleBold.wrap(equivalentCommand),
      ].nonNulls.join('\n'),
    );

    final shouldOverride = mode == 'w';

    // Validate regex patterns before use.
    final validatedPatterns = <RegExp>[];
    for (final ignorePattern in ignorePatterns) {
      try {
        validatedPatterns.add(RegExp(ignorePattern));
      } on FormatException catch (exception) {
        throw CoverdeFilterInvalidRegexPatternFailure(
          usageMessage: usageWithoutDescription,
          invalidRegexPattern: ignorePattern,
          exception: exception,
        );
      }
    }

    if (!FileSystemEntity.isFileSync(originPath)) {
      throw CoverdeFilterTraceFileNotFoundFailure(
        traceFilePath: originPath,
      );
    }
    final origin = File(originPath);
    final destination = File(destinationPath);

    final TraceFile traceFile;
    try {
      traceFile = await TraceFile.parseStreaming(origin);
    } on FileSystemException catch (exception) {
      throw CoverdeFilterTraceFileReadFailure.fromFileSystemException(
        traceFilePath: originPath,
        exception: exception,
      );
    }
    final acceptedSrcFilesRawData = <String>{};

    // For each file coverage data.
    for (final fileCovData in traceFile.sourceFilesCovData) {
      // Check if file should be ignored according to matching patterns.
      final shouldBeIgnored = validatedPatterns.any(
        (regexp) => regexp.hasMatch(fileCovData.source.path),
      );

      // Conditionally include file coverage data.
      if (shouldBeIgnored) {
        logger.detail('<${fileCovData.source.path}> coverage data ignored.');
      } else {
        final raw = switch (baseDirectory) {
          null => fileCovData.raw,
          final String baseDirectory => fileCovData.raw.replaceFirst(
              RegExp(r'^SF:(.*)$', multiLine: true),
              'SF:${path.relative(
                fileCovData.source.path,
                from: baseDirectory,
              )}',
            ),
        };
        acceptedSrcFilesRawData.add(raw);
      }
    }

    try {
      destination.parent.createSync(recursive: true);
    } on FileSystemException catch (exception, stackTrace) {
      Error.throwWithStackTrace(
        CoverdeFilterDirectoryCreateFailure.fromFileSystemException(
          directoryPath: destination.parent.path,
          exception: exception,
        ),
        stackTrace,
      );
    }
    final finalContent = acceptedSrcFilesRawData.join('\n');

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
        CoverdeFilterFileWriteFailure.fromFileSystemException(
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
}
