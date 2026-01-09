import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

export 'failures.dart';

/// {@template check_cmd}
/// A command to check the minimum coverage value from a trace file.
/// {@endtemplate}
class CheckCommand extends CoverdeCommand {
  /// {@macro check_cmd}
  CheckCommand() {
    argParser
      ..addOption(
        inputOptionName,
        abbr: inputOptionAbbreviation,
        help: '''
Trace file used for the coverage check.''',
        defaultsTo: 'coverage/lcov.info',
      )
      ..addOption(
        fileCoverageLogLevelOptionName,
        help: '''
The log level for the coverage value for each source file listed in the `$inputOptionName` info file.''',
        allowed: FileCoverageLogLevel.values.map((level) => level.identifier),
        allowedHelp: {
          for (final logLevel in FileCoverageLogLevel.values)
            logLevel.identifier: logLevel.help,
        },
        defaultsTo: FileCoverageLogLevel.lineContent.identifier,
      );
  }

  /// Option name for the trace file whose coverage value should be checked.
  @visibleForTesting
  static const inputOptionName = 'input';

  /// Option abbreviation for the trace file whose coverage value should be
  /// checked.
  @visibleForTesting
  static const inputOptionAbbreviation = 'i';

  /// Option name for the log level for the coverage value for each source file.
  @visibleForTesting
  static const fileCoverageLogLevelOptionName = 'file-coverage-log-level';

  @override
  String get description => '''
Check the coverage value (%) computed from a trace file.

The unique argument should be an integer between 0 and 100.
This parameter indicates the minimum value for the coverage to be accepted.''';

  @override
  String get name => 'check';

  @override
  CoverdeCommandParams get params => CoverdeCommandParams(
        identifier: 'min-coverage',
        description: 'The minimum coverage value to be accepted. '
            'It should be an integer between 0 and 100.',
      );

  @override
  Future<void> run() async {
    final argResults = this.argResults!;
    final filePath = p.absolute(argResults.option(inputOptionName)!);
    final fileCoverageLogLevel = () {
      final rawFileCoverageLogLevel = argResults.option(
        fileCoverageLogLevelOptionName,
      )!;
      return FileCoverageLogLevel.values.firstWhere(
        // It is safe to look up the log level by identifier because the allowed
        // values are validated by the args parser.
        (logLevel) => logLevel.identifier == rawFileCoverageLogLevel,
      );
    }();
    final args = argResults.rest;
    if (args.length > 1) {
      throw CoverdeCheckMoreThanOneArgumentFailure(
        usageMessage: usageWithoutDescription,
      );
    }
    final coverageThresholdStr = args.firstOrNull;
    if (coverageThresholdStr == null) {
      throw CoverdeCheckMissingMinimumCoverageThresholdFailure(
        usageMessage: usageWithoutDescription,
      );
    }
    final maybeCoverageThreshold = double.tryParse(coverageThresholdStr);
    if (maybeCoverageThreshold == null ||
        maybeCoverageThreshold < 0 ||
        maybeCoverageThreshold > 100) {
      throw CoverdeCheckInvalidMinimumCoverageThresholdFailure(
        usageMessage: usageWithoutDescription,
      );
    }
    final coverageThreshold = maybeCoverageThreshold;

    if (!FileSystemEntity.isFileSync(filePath)) {
      throw CoverdeCheckTraceFileNotFoundFailure(
        traceFilePath: filePath,
      );
    }
    final file = File(filePath);

    final TraceFile traceFile;
    try {
      traceFile = await TraceFile.parseStreaming(file);
    } on FileSystemException catch (exception) {
      throw CoverdeCheckTraceFileReadFailure.fromFileSystemException(
        traceFilePath: filePath,
        exception: exception,
      );
    }

    if (traceFile.isEmpty) {
      throw CoverdeCheckEmptyTraceFileFailure(
        traceFilePath: filePath,
      );
    }

    ValueCommand.logCoverage(
      logger: logger,
      traceFile: traceFile,
      fileCoverageLogLevel: fileCoverageLogLevel,
    );

    if (traceFile.coverage < coverageThreshold) {
      throw CoverdeCheckCoverageBelowMinimumFailure(
        minimumCoverage: coverageThreshold,
        traceFile: traceFile,
      );
    }
  }
}
