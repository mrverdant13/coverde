import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:coverde/src/entities/tracefile.dart';
import 'package:meta/meta.dart';

/// {@template value_cmd}
/// A command to compute the coverage of a given info file.
/// {@endtemplate filter_cmd}
class ValueCommand extends Command<void> {
  /// {@template filter_cmd}
  ValueCommand({Stdout? out}) : _out = out ?? stdout {
    argParser
      ..addOption(
        fileOption,
        abbr: fileOption[0],
        help: '''
Coverage info file to be used for the coverage value computation.''',
        valueHelp: _fileHelpValue,
        defaultsTo: 'coverage/lcov.info',
      )
      ..addFlag(
        printFilesFlag,
        abbr: printFilesFlag[0],
        help: '''
Print coverage value for each source file listed in the $_fileHelpValue info file.''',
        defaultsTo: true,
      );
  }

  final Stdout _out;

  static const _fileHelpValue = 'LCOV_FILE';

  /// Option name for the tracefile whose coverage value should be computed.
  @visibleForTesting
  static const fileOption = 'file';

  /// Flag name to indicate if the coverage value for individual files should be
  /// logged.
  @visibleForTesting
  static const printFilesFlag = 'print-files';

// coverage:ignore-start
  @override
  String get description => '''
Compute the coverage value (%) of an info file.

Compute the coverage value of the $_fileHelpValue info file.''';
// coverage:ignore-end

  @override
  String get name => 'value';

  @override
  List<String> get aliases => [name[0]];

  @override
  Future<void> run() async {
    // Retrieve arguments and validate their value and the state they represent.
    final _argResults = ArgumentError.checkNotNull(argResults);

    final filePath = ArgumentError.checkNotNull(
      _argResults[fileOption],
    ) as String;
    final shouldPrintFiles = ArgumentError.checkNotNull(
      _argResults[printFilesFlag],
    ) as bool;

    final file = File(filePath);

    if (!file.existsSync()) {
      throw StateError('The `$filePath` file does not exist.');
    }

    // Get coverage info.
    final fileContent = file.readAsStringSync().trim();

    // Split coverage data by the end of record prefix, which indirectly splits
    // the info by file.
    final tracefileData = Tracefile.parse(fileContent);

    if (shouldPrintFiles) {
      // For each file coverage data.
      for (final fileCovData in tracefileData.sourceFilesCovData) {
        _out
          ..writeln(fileCovData.source)
          ..writeln(fileCovData.coverageDataString)
          ..writeln();
      }
    }

    // Show resulting coverage.
    _out
      ..writeln('GLOBAL:')
      ..writeln(tracefileData.coverageDataString);
  }
}
