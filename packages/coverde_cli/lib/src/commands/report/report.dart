import 'package:coverde/src/assets/assets.dart';
import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/utils/utils.dart';
import 'package:io/ansi.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:universal_io/io.dart';

export 'failures.dart';

/// {@template report_cmd}
/// A command to generate the coverage report from a given trace file.
/// {@endtemplate}
class ReportCommand extends CoverdeCommand {
  /// {@macro report_cmd}
  ReportCommand() {
    argParser
      ..addOption(
        inputOption,
        abbr: inputOption[0],
        help: '''
Coverage trace file to be used for the coverage report generation.''',
        valueHelp: _inputHelpValue,
        defaultsTo: 'coverage/lcov.info',
      )
      ..addOption(
        outputOption,
        abbr: outputOption[0],
        help: '''
Destination directory where the generated coverage report will be stored.''',
        valueHelp: _outputHelpValue,
        defaultsTo: 'coverage/html/',
      )
      ..addFlag(
        launchFlag,
        abbr: launchFlag[0],
        help: '''
Launch the generated report in the default browser.
This option is only supported on desktop platforms.
(defaults to off)''',
      )
      ..addSeparator(
        '''
Threshold values (%):
These options provide reference coverage values for the HTML report styling.

High: $_highHelpValue <= coverage <= 100
Medium: $_mediumHelpValue <= coverage < $_highHelpValue
Low: 0 <= coverage < $_mediumHelpValue
''',
      )
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

  /// Flag name to indicate if the resulting report should be launched in the
  /// browser.
  @visibleForTesting
  static const launchFlag = 'launch';

  @override
  String get description => '''
Generate the coverage report from a trace file.

Generate the coverage report inside $_outputHelpValue from the $_inputHelpValue trace file.''';

  @override
  String get name => 'report';

  @override
  List<String> get aliases => [name[0]];

  @override
  bool get takesArguments => false;

  @override
  Future<void> run() async {
    final argResults = this.argResults!;
    final traceFilePath = argResults.option(inputOption)!;
    final reportDirPath = path.joinAll(
      path.split(
        argResults.option(outputOption)!,
      ),
    );
    final mediumString = argResults.option(mediumOption)!;
    final medium = double.tryParse(mediumString);
    if (medium == null || medium < 0 || medium > 100) {
      throw CoverdeReportInvalidMediumThresholdFailure(
        usageMessage: usageWithoutDescription,
        rawValue: mediumString,
      );
    }
    final highString = argResults.option(highOption)!;
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
    final shouldLaunch = argResults.flag(launchFlag);

    // Report dir path should be absolute.
    final reportDirAbsPath = path.isAbsolute(reportDirPath)
        ? reportDirPath
        : path.join(Directory.current.path, reportDirPath);
    final traceFileAbsPath = path.isAbsolute(traceFilePath)
        ? traceFilePath
        : path.join(Directory.current.path, traceFilePath);

    final traceFile = File(traceFileAbsPath);

    if (!traceFile.existsSync()) {
      throw CoverdeReportTraceFileNotFoundFailure(
        traceFilePath: traceFileAbsPath,
      );
    }

    final traceFileData = await TraceFile.parseStreaming(traceFile);

    if (traceFileData.isEmpty) {
      throw CoverdeReportEmptyTraceFileFailure(
        traceFilePath: traceFileAbsPath,
      );
    }

    // Build cov report base tree.
    final traceFileModificationDate = () {
      try {
        return traceFile.lastModifiedSync();
      } on FileSystemException catch (exception, stackTrace) {
        Error.throwWithStackTrace(
          CoverdeReportFileReadFailure.fromFileSystemException(
            filePath: traceFileAbsPath,
            exception: exception,
          ),
          stackTrace,
        );
      }
    }();
    // Build cov report base tree.
    final covTree = traceFileData.asTree;
    // Generate report doc.
    try {
      covTree.generateReport(
        traceFileName: path.basename(traceFileAbsPath),
        traceFileModificationDate: traceFileModificationDate,
        parentReportDirAbsPath: reportDirAbsPath,
        medium: medium,
        high: high,
      );
    } on GenerateHtmlCoverageReportFailure catch (exception, stackTrace) {
      Error.throwWithStackTrace(
        switch (exception) {
          final GenerateHtmlCoverageReportFileOperationFailure failure =>
            switch (failure) {
              GenerateHtmlCoverageReportFileCreateFailure() =>
                CoverdeReportFileCreateFailure(
                  filePath: failure.filePath,
                  errorMessage: failure.errorMessage,
                ),
              GenerateHtmlCoverageReportFileReadFailure() =>
                CoverdeReportFileReadFailure(
                  filePath: failure.filePath,
                  errorMessage: failure.errorMessage,
                ),
              GenerateHtmlCoverageReportFileWriteFailure() =>
                CoverdeReportFileWriteFailure(
                  filePath: failure.filePath,
                  errorMessage: failure.errorMessage,
                ),
            },
        },
        stackTrace,
      );
    }

    // Copy static files.
    final cssRootPath = path.join(
      reportDirAbsPath,
      'report_style.css',
    );
    final cssFile = File(cssRootPath);
    try {
      cssFile.createSync(recursive: true);
    } on FileSystemException catch (exception, stackTrace) {
      Error.throwWithStackTrace(
        CoverdeReportFileCreateFailure.fromFileSystemException(
          filePath: cssRootPath,
          exception: exception,
        ),
        stackTrace,
      );
    }
    try {
      cssFile.writeAsBytesSync(reportStyleCssBytes);
    } on FileSystemException catch (exception, stackTrace) {
      Error.throwWithStackTrace(
        CoverdeReportFileWriteFailure.fromFileSystemException(
          filePath: cssRootPath,
          exception: exception,
        ),
        stackTrace,
      );
    }

    final sortAlphaIconRootPath = path.join(
      reportDirAbsPath,
      'sort_alpha.png',
    );
    final sortAlphaFile = File(sortAlphaIconRootPath);
    try {
      sortAlphaFile.createSync(recursive: true);
    } on FileSystemException catch (exception, stackTrace) {
      Error.throwWithStackTrace(
        CoverdeReportFileCreateFailure.fromFileSystemException(
          filePath: sortAlphaIconRootPath,
          exception: exception,
        ),
        stackTrace,
      );
    }
    try {
      sortAlphaFile.writeAsBytesSync(sortAlphaPngBytes);
    } on FileSystemException catch (exception, stackTrace) {
      Error.throwWithStackTrace(
        CoverdeReportFileWriteFailure.fromFileSystemException(
          filePath: sortAlphaIconRootPath,
          exception: exception,
        ),
        stackTrace,
      );
    }

    final sortNumericIconRootPath = path.join(
      reportDirAbsPath,
      'sort_numeric.png',
    );
    final sortNumericFile = File(sortNumericIconRootPath);
    try {
      sortNumericFile.createSync(recursive: true);
    } on FileSystemException catch (exception, stackTrace) {
      Error.throwWithStackTrace(
        CoverdeReportFileCreateFailure.fromFileSystemException(
          filePath: sortNumericIconRootPath,
          exception: exception,
        ),
        stackTrace,
      );
    }
    try {
      sortNumericFile.writeAsBytesSync(sortNumericPngBytes);
    } on FileSystemException catch (exception, stackTrace) {
      Error.throwWithStackTrace(
        CoverdeReportFileWriteFailure.fromFileSystemException(
          filePath: sortNumericIconRootPath,
          exception: exception,
        ),
        stackTrace,
      );
    }

    final reportIndexAbsPath = path.joinAll([reportDirAbsPath, 'index.html']);

    logger.info('$covTree');

    final reportLocationMessage = StringBuffer()
      ..write(
        wrapWith(
          'Report location: ',
          [blue, styleBold],
        ),
      )
      ..write(
        wrapWith(
          reportIndexAbsPath,
          [blue, styleBold, styleUnderlined],
        ),
      );
    logger.info('$reportLocationMessage\n');

    if (shouldLaunch) {
      final launchCommand = launchCommands[operatingSystemIdentifier];
      if (launchCommand == null) {
        logger.warn(
          '''Browser launch is not supported on $operatingSystemIdentifier platform.''',
        );
        return;
      }
      await processManager.run(
        [launchCommand, reportIndexAbsPath],
        runInShell: true,
      );
    }
  }
}

/// The commands to launch the browser on different platforms.
@visibleForTesting
const launchCommands = {
  'linux': 'xdg-open',
  'macos': 'open',
  'windows': 'start',
};
