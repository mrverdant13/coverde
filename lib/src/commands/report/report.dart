import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:coverde/src/common/assets.dart';
import 'package:coverde/src/entities/tracefile.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

/// {@template report_cmd}
/// A command to generate the coverage report from a given tracefile.
/// {@endtemplate}
class ReportCommand extends Command<void> {
  /// {@macro report_cmd}
  ReportCommand() {
    argParser
      ..addOption(
        _inputTracefileOption,
        abbr: _inputTracefileOption[0],
        help: '''
Coverage tracefile to be used for the coverage report generation.''',
        valueHelp: _inputTracefileHelpValue,
        defaultsTo: 'coverage/lcov.info',
      )
      ..addOption(
        _outputReportDirOption,
        abbr: _outputReportDirOption[0],
        help: '''
Destination directory where the generated coverage report will be stored.''',
        valueHelp: _outputReportDirHelpValue,
        defaultsTo: 'coverage/html/',
      )
      ..addSeparator('''
Threshold values (%):
These options provide reference coverage values for the HTML report styling.

High: $_highHelpValue <= coverage <= 100
Medium: $_mediumHelpValue <= coverge < $_highHelpValue
Low: 0 <= coverage < $_mediumHelpValue
''')
      ..addOption(
        _mediumOption,
        help: '''
Medium threshold.''',
        valueHelp: _mediumHelpValue,
        defaultsTo: '75',
      )
      ..addOption(
        _highOption,
        help: '''
High threshold.''',
        valueHelp: _highHelpValue,
        defaultsTo: '90',
      );
  }

  static const _inputTracefileHelpValue = 'TRACEFILE';
  static const _outputReportDirHelpValue = 'REPORT_DIR';
  static const _mediumHelpValue = 'MEDIUM_VAL';
  static const _highHelpValue = 'HIGH_VAL';

  static const _inputTracefileOption = 'input-tracefile';
  static const _outputReportDirOption = 'output-report-dir';
  static const _mediumOption = 'medium';
  static const _highOption = 'high';

  @override
  String get description => '''
Generate the coverage report from a tracefile.

Genrate the coverage report inside $_outputReportDirHelpValue from the $_inputTracefileHelpValue tracefile.''';

  @override
  String get name => 'report';

  @override
  List<String> get aliases => [name[0]];

  /// Report style CSS file.
  @visibleForTesting
  static final reportStyleFile = File(
    path.join(
      assetsPath,
      'report-style.css',
    ),
  );

  /// Alphabetic sorting icon file.
  @visibleForTesting
  static final sortAlphaIconFile = File(
    path.join(
      assetsPath,
      'sort-alpha.png',
    ),
  );

  /// Numeric sorting icon file.
  @visibleForTesting
  final sortNumericIconFile = File(
    path.join(
      assetsPath,
      'sort-numeric.png',
    ),
  );

  @override
  Future<void> run() async {
    // Retrieve arguments and validate their value and the state they represent.
    final _argResults = ArgumentError.checkNotNull(argResults);

    final _tracefilePath = ArgumentError.checkNotNull(
      _argResults[_inputTracefileOption],
    ) as String;
    final _reportDirPath = ArgumentError.checkNotNull(
      _argResults[_outputReportDirOption],
    ) as String;
    final medium = ArgumentError.checkNotNull(
      double.tryParse(
        ArgumentError.checkNotNull(
          _argResults[_mediumOption],
        ) as String,
      ),
    );
    final high = ArgumentError.checkNotNull(
      double.tryParse(
        ArgumentError.checkNotNull(
          _argResults[_highOption],
        ) as String,
      ),
    );

    // Report dir path should be absolute.
    final reportDirAbsPath = path.isAbsolute(_reportDirPath)
        ? _reportDirPath
        : path.join(Directory.current.path, _reportDirPath);
    final tracefileAbsPath = path.isAbsolute(_tracefilePath)
        ? _tracefilePath
        : path.join(Directory.current.path, _tracefilePath);

    final tracefile = File(tracefileAbsPath);

    if (!tracefile.existsSync()) {
      throw StateError('The `$tracefileAbsPath` tracefile does not exist.');
    }

    // Get tracefile content.
    final tracefileContent = tracefile.readAsStringSync().trim();

    // Parse tracefile data.
    final tracefileData = Tracefile.parse(tracefileContent);

    // Build cov report base tree.
    final covTree = tracefileData.asTree
      // Generate report doc.
      ..generateReport(
        tracefileName: path.basename(tracefileAbsPath),
        tracefileModificationDate: tracefile.lastModifiedSync(),
        parentReportDirAbsPath: reportDirAbsPath,
        medium: medium,
        high: high,
      );

    // Copy static files.
    final cssRootPath = path.join(
      reportDirAbsPath,
      path.basename(reportStyleFile.path),
    );
    File(cssRootPath).createSync(recursive: true);
    reportStyleFile.copySync(cssRootPath);

    final sortAlphaIconRootPath = path.join(
      reportDirAbsPath,
      'sort-alpha.png',
    );
    File(sortAlphaIconRootPath).createSync(recursive: true);
    sortAlphaIconFile.copySync(sortAlphaIconRootPath);

    final sortNumericIconRootPath = path.join(
      reportDirAbsPath,
      'sort-numeric.png',
    );
    File(sortNumericIconRootPath).createSync(recursive: true);
    sortNumericIconFile.copySync(sortNumericIconRootPath);

    stdout.writeln(covTree);
  }
}
