import 'package:args/command_runner.dart';
import 'package:collection/collection.dart';
import 'package:coverde/src/entities/cov_file.dart';
import 'package:coverde/src/entities/file_coverage_log_level.dart';
import 'package:coverde/src/entities/file_line_coverage_details.dart';
import 'package:coverde/src/entities/trace_file.dart';
import 'package:io/ansi.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

/// {@template value_cmd}
/// A command to compute the coverage of a given info file.
/// {@endtemplate}
class ValueCommand extends Command<void> {
  /// {@macro filter_cmd}
  ValueCommand({Stdout? out}) : _out = out ?? stdout {
    argParser
      ..addOption(
        inputOption,
        abbr: inputOption[0],
        help: '''
Coverage info file to be used for the coverage value computation.''',
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

  /// Option name for the trace file whose coverage value should be computed.
  @visibleForTesting
  static const inputOption = 'input';

  /// Option name for the log level for the coverage value for each source file.
  @visibleForTesting
  static const fileCoverageLogLevelFlag = 'file-coverage-log-level';

  @override
  String get description => '''
Compute the coverage value (%) of an info file.

Compute the coverage value of the $_inputHelpValue info file.''';

  @override
  String get name => 'value';

  @override
  List<String> get aliases => [name[0]];

  @override
  bool get takesArguments => false;

  @override
  Future<void> run() async {
    final argResults = this.argResults!;
    final filePath = () {
      final rawFilePath = argResults.option(inputOption)!;
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

    final file = File(filePath);

    if (!file.existsSync()) {
      usageException('The trace file located at `$filePath` does not exist.');
    }

    // Get coverage info.
    final fileContent = file.readAsStringSync().trim();

    // Split coverage data by the end of record prefix, which indirectly splits
    // the info by file.
    final traceFile = TraceFile.parse(fileContent);

    logCoverage(
      out: _out,
      traceFile: traceFile,
      fileCoverageLogLevel: fileCoverageLogLevel,
    );
  }

  /// Log coverage values.
  static void logCoverage({
    required Stdout out,
    required TraceFile traceFile,
    required FileCoverageLogLevel fileCoverageLogLevel,
  }) {
    switch (fileCoverageLogLevel) {
      case FileCoverageLogLevel.none:
        break;
      case FileCoverageLogLevel.overview:
        for (final fileCovData in traceFile.sourceFilesCovData) {
          out.writeln(fileCovData.coverageDataString);
        }
      case FileCoverageLogLevel.lineNumbers:
        for (final fileCovData in traceFile.sourceFilesCovData) {
          out.writeln(fileCovData.coverageDataString);
          final uncoveredLineNumbers = fileCovData.uncoveredLineNumbers;
          if (uncoveredLineNumbers.isNotEmpty) {
            final message = 'UNCOVERED: ${uncoveredLineNumbers.join(', ')}';
            out.writeln('└ ${wrapWith(message, [red, styleBold])}');
          }
        }
      case FileCoverageLogLevel.lineContent:
        for (final fileCovData in traceFile.sourceFilesCovData) {
          out.writeln(fileCovData.coverageDataString);
          final sourceLines = fileCovData.source.absolute.readAsLinesSync();
          final sourceLinesCount = sourceLines.length;
          final lineNumberColumnWidth = '$sourceLinesCount'.length;
          final uncoveredLineRanges = fileCovData.uncoveredLineRanges;
          final indexedUncoveredLineRanges = uncoveredLineRanges.indexed;
          for (final (index, uncoveredLineRange)
              in indexedUncoveredLineRanges) {
            if (index > 0) {
              out.writeln('├ ${'•' * lineNumberColumnWidth} | •••');
            }
            for (final lineWithStatus in uncoveredLineRange) {
              final FileLineCoverageDetails(
                :lineNumber,
                :content,
                :status,
              ) = lineWithStatus;
              final styles = switch (status) {
                FileLineCoverageStatus.covered => [green, styleBold],
                FileLineCoverageStatus.uncovered => [red, styleBold],
                FileLineCoverageStatus.neutral => <AnsiCode>[],
              };
              final lineNumberSegment = wrapWith(
                '$lineNumber'.padLeft(lineNumberColumnWidth),
                styles,
              );
              final contentSegment = wrapWith(
                content,
                styles,
              );
              out.writeln('├ $lineNumberSegment | $contentSegment');
            }
          }
          out.writeln();
        }
    }
    if (fileCoverageLogLevel != FileCoverageLogLevel.none) out.writeln();

    // Show resulting coverage.
    out
      ..writeln(wrapWith('GLOBAL:', [blue, styleBold]))
      ..writeln(wrapWith(traceFile.coverageDataString, [blue, styleBold]));
  }
}

extension on CovFile {
  Iterable<int> get uncoveredLineNumbers {
    return covLines
        .where((line) => !line.hasBeenHit)
        .map((line) => line.lineNumber);
  }

  Iterable<Iterable<FileLineCoverageDetails>> get uncoveredLineRanges {
    const maxGap = 5;
    const surroundingLines = 2;
    final sourceLines = source.absolute.readAsLinesSync();
    final sourceLinesCount = sourceLines.length;
    final ranges = covLines
        .where(
          (line) => !line.hasBeenHit,
        )
        .map(
          (line) => line.lineNumber,
        )
        .splitBetween(
          (a, b) => b - a > maxGap,
        )
        .map(
          (group) => (
            start: (group.first - surroundingLines).clamp(1, sourceLinesCount),
            end: (group.last + surroundingLines).clamp(1, sourceLinesCount),
          ),
        )
        .map(
      (range) {
        final rangeLines = <FileLineCoverageDetails>[];
        for (var lineNumber = range.start;
            lineNumber <= range.end;
            lineNumber++) {
          final content = sourceLines[lineNumber - 1];
          final covLine = covLines.singleWhereOrNull(
            (line) => line.lineNumber == lineNumber,
          );
          final status = switch (covLine?.hasBeenHit) {
            null => FileLineCoverageStatus.neutral,
            true => FileLineCoverageStatus.covered,
            false => FileLineCoverageStatus.uncovered,
          };
          rangeLines.add(
            FileLineCoverageDetails(
              lineNumber: lineNumber,
              content: content,
              status: status,
            ),
          );
        }
        return rangeLines;
      },
    );
    return ranges;
  }
}
