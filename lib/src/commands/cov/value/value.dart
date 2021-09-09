import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cov_utils/src/entities/file_coverage.dart';
import 'package:cov_utils/src/entities/prefix.dart';

/// {@template value_cmd}
/// A command to compute the coverage of a given info file.
/// {@endtemplate filter_cmd}
class ValueCommand extends Command<void> {
  /// {@template filter_cmd}
  ValueCommand() {
    argParser
      ..addOption(
        _fileOption,
        abbr: _fileOption[0],
        help: '''
Coverage info file to be used for the coverage value computation.''',
        valueHelp: _fileHelpValue,
        defaultsTo: 'coverage/lcov.info',
      )
      ..addFlag(
        _printFilesFlag,
        abbr: _printFilesFlag[0],
        help: '''
Print coverage value for each source file listed in the $_fileHelpValue info file.''',
        defaultsTo: true,
      );
  }

  static const _fileHelpValue = 'LCOV_FILE';

  static const _fileOption = 'file';
  static const _printFilesFlag = 'print-files';

  @override
  String get description => '''
Compute the coverage value (%) of an info file.

Compute the coverage value of the $_fileHelpValue info file.''';

  @override
  String get name => 'value';

  @override
  List<String> get aliases => [name[0]];

  @override
  Future<void> run() async {
    // Retrieve arguments and validate their value and the state they represent.
    final _argResults = ArgumentError.checkNotNull(argResults);

    final filePath = ArgumentError.checkNotNull(
      _argResults[_fileOption],
    ) as String;
    final shouldPrintFiles = ArgumentError.checkNotNull(
      _argResults[_printFilesFlag],
    ) as bool;

    final file = File(filePath);

    if (!file.existsSync()) {
      throw StateError('The `$filePath` file does not exist.');
    }

    // Get coverage info.
    final fileContent = file.readAsStringSync().trim();

    // Split coverage data by the end of record prefix, which indirectly splits
    // the info by file.
    final filesCovData = fileContent //
        .split(Prefix.endOfRecord) //
        .map((s) => s.trim()) //
        .where((s) => s.isNotEmpty);

    // Set initial values.
    var totalLinesFound = 0;
    var totalLinesHit = 0;

    // For each file coverage data.
    for (final fileCovData in filesCovData) {
      // Parse file coverage data.
      final fileCoverage = FileCoverage.parse(fileCovData);
      totalLinesFound += fileCoverage.linesFound;
      totalLinesHit += fileCoverage.linesHit;
      if (shouldPrintFiles) {
        stdout
          ..writeln(fileCoverage.sourceFile)
          ..write(fileCoverage.coveragePercentage.toStringAsFixed(2))
          ..write(' % (')
          ..write(fileCoverage.linesHit)
          ..write(' of ')
          ..write(fileCoverage.linesFound)
          ..writeln(' lines)')
          ..writeln();
      }
    }

    // Show resulting coverage.
    final resultingCoveragePercentage = (totalLinesHit * 100) / totalLinesFound;
    stdout
      ..write('Global: ')
      ..write(resultingCoveragePercentage.toStringAsFixed(2))
      ..write(' % (')
      ..write(totalLinesHit)
      ..write(' of ')
      ..write(totalLinesFound)
      ..write(' lines)');
  }
}
