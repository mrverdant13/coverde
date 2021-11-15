import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:collection/collection.dart';
import 'package:coverde/src/commands/check/min_coverage.exception.dart';
import 'package:coverde/src/commands/value/value.dart';
import 'package:coverde/src/entities/tracefile.dart';
import 'package:meta/meta.dart';

/// {@template check_cmd}
/// A command to check the minimum coverage value from a tracefile.
/// {@endtemplate check_cmd}
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
      ..addFlag(
        verboseFlag,
        abbr: verboseFlag[0],
        help: 'Print coverage value.',
        defaultsTo: true,
      );
  }

  final Stdout _out;

  static const _inputHelpValue = 'LCOV_FILE';

  /// Option name for the tracefile whose coverage value should be checked.
  @visibleForTesting
  static const inputOption = 'input';

  /// Flag name to indicate if the coverage value for individual files should be
  /// logged.
  @visibleForTesting
  static const verboseFlag = 'verbose';

// coverage:ignore-start
  @override
  String get description => '''
Check the coverage value (%) computed from a trace file.

The unique argument should be an integer between 0 and 100.
This parameter indicates the minimum value for the coverage to be accepted.''';
// coverage:ignore-end

  @override
  String get name => 'check';

  @override
  List<String> get aliases => [name[0]];

  @override
  Future<void> run() async {
    // Retrieve arguments and validate their value and the state they represent.
    final _argResults = ArgumentError.checkNotNull(argResults);

    final filePath = ArgumentError.checkNotNull(
      _argResults[inputOption],
    ) as String;
    final isVerbose = ArgumentError.checkNotNull(
      _argResults[verboseFlag],
    ) as bool;

    final coverageThreshold = RangeError.checkValueInInterval(
      ArgumentError.checkNotNull(
        int.tryParse(_argResults.rest.firstOrNull ?? ''),
      ),
      0,
      100,
    );

    final file = File(filePath);

    if (!file.existsSync()) {
      throw StateError('The `$filePath` file does not exist.');
    }

    // Get coverage info.
    final fileContent = file.readAsStringSync().trim();

    // Split coverage data by the end of record prefix, which indirectly splits
    // the info by file.
    final tracefile = Tracefile.parse(fileContent);

    if (isVerbose) {
      ValueCommand.logCoverage(
        out: _out,
        tracefile: tracefile,
        shouldLogFiles: true,
      );
    }

    if (tracefile.coverage < coverageThreshold) {
      throw MinCoverageException(
        minCoverage: coverageThreshold,
        tracefile: tracefile,
      );
    }
  }
}
