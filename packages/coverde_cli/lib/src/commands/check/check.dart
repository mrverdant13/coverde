import 'package:coverde/src/commands/check/min_coverage.exception.dart';
import 'package:coverde/src/commands/coverde_command.dart';
import 'package:coverde/src/commands/value/value.dart';
import 'package:coverde/src/entities/cov_file_format.exception.dart';
import 'package:coverde/src/entities/file_coverage_log_level.dart';
import 'package:coverde/src/entities/trace_file.dart';
import 'package:coverde/src/utils/coverage.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

/// {@template check_cmd}
/// A command to check the minimum coverage value from a trace file.
/// {@endtemplate}
class CheckCommand extends CoverdeCommand {
  /// {@macro check_cmd}
  CheckCommand({
    super.logger,
  }) {
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
    final filePath = () {
      final rawFilePath = argResults.option(
        inputOptionName,
      )!;
      return p.absolute(rawFilePath);
    }();
    final fileCoverageLogLevel = () {
      final rawFileCoverageLogLevel = argResults.option(
        fileCoverageLogLevelOptionName,
      )!;
      return FileCoverageLogLevel.values.firstWhere(
        (logLevel) => logLevel.identifier == rawFileCoverageLogLevel,
      );
    }();
    final args = argResults.rest;
    if (args.length > 1) usageException('Too many arguments.');
    final coverageThresholdStr = args.firstOrNull;
    if (coverageThresholdStr == null) {
      throw ArgumentError('Missing minimum coverage threshold.');
    }
    final maybeCoverageThreshold = double.tryParse(coverageThresholdStr);
    if (maybeCoverageThreshold == null) {
      throw ArgumentError('Invalid minimum coverage threshold.');
    }
    final coverageThreshold = maybeCoverageThreshold.checkedAsCoverage(
      valueName: 'coverage threshold',
    );

    final file = File(filePath);

    if (!file.existsSync()) {
      usageException('The trace file located at `$filePath` does not exist.');
    }

    // Get coverage info.
    final fileContent = file.readAsStringSync().trim();

    // Split coverage data by the end of record prefix, which indirectly splits
    // the info by file.
    final traceFile = TraceFile.parse(fileContent);

    if (traceFile.isEmpty) {
      throw CovFileFormatException(
        message: 'No coverage data found in the trace file.',
      );
    }

    ValueCommand.logCoverage(
      logger: logger,
      traceFile: traceFile,
      fileCoverageLogLevel: fileCoverageLogLevel,
    );

    if (traceFile.coverage < coverageThreshold) {
      throw MinCoverageException(
        minCoverage: coverageThreshold,
        traceFile: traceFile,
      );
    }
  }
}
