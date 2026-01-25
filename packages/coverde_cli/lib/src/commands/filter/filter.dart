import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:glob/glob.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
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
      ..addOption(
        excludeOptionName,
        help: '''
The glob pattern of the files to be excluded.

In order to be cross-platform compatible, the glob pattern must use the POSIX path syntax.''',
        valueHelp: _excludeHelpValue,
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
  static const _excludeHelpValue = 'EXCLUDE_GLOB';
  static const _modeHelpValue = 'MODE';
  static const _outModeAllowedHelp = {
    'a': '''
Append filtered content to the $_outputHelpValue content, if any.''',
    'w': '''
Override the $_outputHelpValue content, if any, with the filtered content.''',
  };

  /// Option name for the glob pattern of the files to be excluded.
  @visibleForTesting
  static const excludeOptionName = 'exclude';

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
Filter a coverage trace file.

Filter the coverage info by ignoring data related to files with paths that matches the given $_excludeHelpValue.
The coverage data is taken from the $_inputHelpValue file and the result is appended to the $_outputHelpValue file.

All the relative paths in the resulting coverage trace file will be resolved relative to the <$baseDirectoryOptionName>, if provided.''';

  @override
  String get name => 'filter';

  @override
  List<String> get aliases => [name[0]];

  @override
  bool get takesArguments => false;

  @override
  Future<void> run() async {
    final argResults = this.argResults!;
    final originPath = argResults.option(inputOption)!;
    final destinationPath = argResults.option(outputOption)!;
    final baseDirectory = argResults.option(baseDirectoryOptionName);
    final excludeGlob = () {
      final excludePattern = argResults.option(excludeOptionName);
      if (excludePattern == null) return null;
      try {
        return Glob(excludePattern, context: p.posix);
      } on FormatException catch (exception) {
        throw CoverdeFilterInvalidGlobPatternFailure(
          invalidGlobPattern: excludePattern,
          usageMessage: usageWithoutDescription,
          exception: exception,
        );
      }
    }();
    final shouldOverride = argResults.option(modeOption) == 'w';

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
      final shouldBeIgnored =
          excludeGlob?.matches(fileCovData.source.path) ?? false;

      // Conditionally include file coverage data.
      if (shouldBeIgnored) {
        logger.detail('<${fileCovData.source.path}> coverage data ignored.');
      } else {
        final raw = switch (baseDirectory) {
          null => fileCovData.raw,
          final String baseDirectory => fileCovData.raw.replaceFirst(
              RegExp(r'^SF:(.*)$', multiLine: true),
              'SF:${p.relative(
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
