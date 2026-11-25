import 'package:args/args.dart';
import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/features/lcov_html/render_lcov_html.dart';
import 'package:coverde/src/features/reporting/reporters/coverage_source_reader.dart';
import 'package:coverde/src/utils/utils.dart';
import 'package:io/ansi.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:universal_io/io.dart';

/// {@template lcov_html_cmd}
/// A command to generate an LCOV HTML coverage report.
/// {@endtemplate}
class LcovHtmlCommand extends CoverdeCommand {
  /// {@macro lcov_html_cmd}
  LcovHtmlCommand() {
    argParser
      ..addMultiOption(
        inputOption,
        abbr: inputOption[0],
        help: '''
Coverage trace file to be used for the coverage report generation.

Repeat to merge traces. Records with the same path are merged.
The trace time is the latest modification time.''',
        valueHelp: _inputHelpValue,
        defaultsTo: const ['coverage/lcov.info'],
      )
      ..addOption(
        outputOption,
        abbr: outputOption[0],
        help: '''
Destination directory where the generated coverage report will be stored.''',
        valueHelp: _outputHelpValue,
        defaultsTo: 'coverage/html/',
      )
      ..addSeparator('''
Threshold values (%):
These options provide reference coverage values for the HTML report styling.

High: $_highHelpValue <= coverage <= 100
Medium: $_mediumHelpValue <= coverage < $_highHelpValue
Low: 0 <= coverage < $_mediumHelpValue
''')
      ..addOption(
        mediumOption,
        help: '''
Medium threshold.

Must be a number between 0 and 100, and must be less than the high threshold.''',
        valueHelp: _mediumHelpValue,
        defaultsTo: '75',
      )
      ..addOption(
        highOption,
        help: '''
High threshold.

Must be a number between 0 and 100, and must be greater than the medium threshold.''',
        valueHelp: _highHelpValue,
        defaultsTo: '90',
      );
  }

  static const _inputHelpValue = 'TRACE_FILE';
  static const _outputHelpValue = 'REPORT_DIR';
  static const _mediumHelpValue = 'MEDIUM_VAL';
  static const _highHelpValue = 'HIGH_VAL';

  /// Option name for the origin trace file.
  @visibleForTesting
  static const inputOption = 'input';

  /// Option name for the destination container folder to dump the report to.
  @visibleForTesting
  static const outputOption = 'output';

  /// Option name to set the medium threshold for coverage validation.
  @visibleForTesting
  static const mediumOption = 'medium';

  /// Option name to set the high threshold for coverage validation.
  @visibleForTesting
  static const highOption = 'high';

  @override
  String get description => '''
Generate an LCOV HTML coverage report.

Generate the report inside $_outputHelpValue from the $_inputHelpValue trace files.''';

  @override
  String get name => 'lcov-html';

  @override
  bool get takesArguments => false;

  @override
  Future<void> run() async {
    final argResults = this.argResults!;
    final thresholds = _thresholds(argResults);
    final tracePaths = [
      for (final tracePath in argResults.multiOption(inputOption))
        _absolute(tracePath),
    ];
    final reportDirPath = _absolute(argResults.option(outputOption)!);
    final document = _document(tracePaths);
    _readSources(document);
    await renderLcovHtmlReport(
      document: document,
      sources: const FileCoverageSourceReader(),
      output: Directory(reportDirPath),
      medium: thresholds.medium,
      high: thresholds.high,
    );

    final reportIndexAbsPath = path.join(reportDirPath, 'index.html');
    final reportLocationMessage = StringBuffer()
      ..write(wrapWith('Report location: ', [blue, styleBold]))
      ..write(wrapWith(reportIndexAbsPath, [blue, styleBold, styleUnderlined]));
    logger.info('$reportLocationMessage\n');
  }

  ({double medium, double high}) _thresholds(ArgResults argResults) {
    final mediumString = argResults.option(mediumOption) ?? '';
    final medium = double.tryParse(mediumString);
    if (medium == null || medium < 0 || medium > 100) {
      throw CoverdeReportInvalidMediumThresholdFailure(
        usageMessage: usageWithoutDescription,
        rawValue: mediumString,
      );
    }
    final highString = argResults.option(highOption) ?? '';
    final high = double.tryParse(highString);
    if (high == null || high < 0 || high > 100) {
      throw CoverdeReportInvalidHighThresholdFailure(
        usageMessage: usageWithoutDescription,
        rawValue: highString,
      );
    }
    if (medium >= high) {
      throw CoverdeReportInvalidThresholdRelationshipFailure(
        usageMessage: usageWithoutDescription,
        mediumValue: medium,
        highValue: high,
      );
    }
    return (medium: medium, high: high);
  }

  CoverageDocument _document(List<String> tracePaths) {
    final trace = StringBuffer();
    DateTime? traceModifiedAt;
    for (final traceFilePath in tracePaths) {
      if (!FileSystemEntity.isFileSync(traceFilePath)) {
        throw CoverdeReportTraceFileNotFoundFailure(
          traceFilePath: traceFilePath,
        );
      }
      final traceFile = File(traceFilePath);
      try {
        final modified = traceFile.lastModifiedSync();
        if (traceModifiedAt == null || modified.isAfter(traceModifiedAt)) {
          traceModifiedAt = modified;
        }
        appendTraceContent(trace, traceFile.readAsStringSync());
      } on FileSystemException catch (exception) {
        throw CoverdeReportTraceFileReadFailure.fromFileSystemException(
          traceFilePath: traceFilePath,
          exception: exception,
        );
      }
    }
    final document = CoverageDocument.parse(
      trace.toString(),
      traceModifiedAt: traceModifiedAt,
    );
    if (document.files.isEmpty) {
      throw CoverdeReportEmptyTraceFileFailure(
        traceFilePath: tracePaths.join(', '),
      );
    }
    return document;
  }

  void _readSources(CoverageDocument document) {
    for (final file in document.files) {
      if (!hostCanResolveCoveragePath(
        file.path,
        windowsHost: Platform.isWindows,
      )) {
        throw CoverdeReportUnresolvedCoveragePathFailure(sourcePath: file.path);
      }
      final source = File(file.path).absolute;
      try {
        source.readAsLinesSync();
      } on FileSystemException catch (exception) {
        throw CoverdeReportFileReadFailure.fromFileSystemException(
          filePath: source.path,
          exception: exception,
        );
      }
    }
  }

  String _absolute(String value) {
    final resolved = path.isAbsolute(value)
        ? value
        : path.join(Directory.current.path, value);
    return path.normalize(resolved);
  }
}
