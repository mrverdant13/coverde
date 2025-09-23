import 'package:args/command_runner.dart';
import 'package:collection/collection.dart';
import 'package:coverde/src/commands/check/min_coverage.exception.dart';
import 'package:coverde/src/commands/value/value.dart';
import 'package:coverde/src/entities/file_coverage_log_level.dart';
import 'package:coverde/src/entities/trace_file.dart';
import 'package:coverde/src/utils/coverage.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

/// {@template check_cmd}
/// A command to check the minimum coverage value from a trace file.
/// {@endtemplate}
class CheckCommand extends Command<void> {
  /// {@macro check_cmd}
  CheckCommand({Stdout? out}) : _out = out ?? stdout {
    argParser
      ..addOption(
        inputOption,
        abbr: inputOption[0],
        help: '''
Trace file used for the coverage check.''',
        valueHelp: _inputHelpValue,
        defaultsTo: 'coverage/lcov.info',
      )
      ..addOption(
        fileCoverageLogLevelFlag,
        help: '''
The log level for the coverage value for each source file listed in the $_inputHelpValue info file.''',
        allowedHelp: {
          for (final logLevel in FileCoverageLogLevel.values)
            logLevel.identifier: logLevel.help,
        },
        defaultsTo: FileCoverageLogLevel.lineContent.identifier,
      );
  }

  final Stdout _out;

  static const _inputHelpValue = 'LCOV_FILE';

  /// Option name for the trace file whose coverage value should be checked.
  @visibleForTesting
  static const inputOption = 'input';

  /// Option name for the log level for the coverage value for each source file.
  @visibleForTesting
  static const fileCoverageLogLevelFlag = 'file-coverage-log-level';

  @override
  String get description => '''
Check the coverage value (%) computed from a trace file.

The unique argument should be an integer between 0 and 100.
This parameter indicates the minimum value for the coverage to be accepted.''';

  @override
  String get name => 'check';

  @override
  List<String> get aliases => [name[0]];

  @override
  String get invocation => super.invocation.replaceAll(
        '[arguments]',
        '[min-coverage]',
      );

  @override
  Future<void> run() async {
    final argResults = this.argResults!;
    final filePath = () {
      final rawFilePath = argResults.option(
        inputOption,
      )!;
      return p.absolute(rawFilePath);
    }();
    final fileCoverageLogLevel = () {
      final rawFileCoverageLogLevel = argResults.option(
        fileCoverageLogLevelFlag,
      )!;
      return FileCoverageLogLevel.values.firstWhere(
        (logLevel) => logLevel.identifier == rawFileCoverageLogLevel,
      );
    }();
    final args = argResults.rest;
    if (args.length > 1) usageException('Too many arguments.');
    final coverageThresholdStr = args.firstOrNull;
    if (coverageThresholdStr == null) {
      usageException('Missing minimum coverage threshold.');
    }
    final maybeCoverageThreshold = double.tryParse(coverageThresholdStr);
    if (maybeCoverageThreshold == null) {
      usageException('Invalid minimum coverage threshold.');
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

    ValueCommand.logCoverage(
      out: _out,
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
