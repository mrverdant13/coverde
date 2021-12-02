import 'package:args/command_runner.dart';
import 'package:coverde/src/entities/tracefile.dart';
import 'package:coverde/src/utils/command.dart';
import 'package:io/ansi.dart';
import 'package:meta/meta.dart';
import 'package:universal_io/io.dart';

/// {@template value_cmd}
/// A command to compute the coverage of a given info file.
/// {@endtemplate filter_cmd}
class ValueCommand extends Command<void> {
  /// {@template filter_cmd}
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
      ..addFlag(
        verboseFlag,
        abbr: verboseFlag[0],
        help: '''
Print coverage value for each source file listed in the $_inputHelpValue info file.''',
        defaultsTo: true,
      );
  }

  final Stdout _out;

  static const _inputHelpValue = 'LCOV_FILE';

  /// Option name for the tracefile whose coverage value should be computed.
  @visibleForTesting
  static const inputOption = 'input';

  /// Flag name to indicate if the coverage value for individual files should be
  /// logged.
  @visibleForTesting
  static const verboseFlag = 'verbose';

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
    // Retrieve arguments and validate their value and the state they represent.
    final filePath = checkOption(
      optionKey: inputOption,
      optionName: 'input trace file',
    );
    final shouldLogFiles = checkFlag(
      flagKey: verboseFlag,
      flagName: 'verbose',
    );

    final file = File(filePath);

    if (!file.existsSync()) {
      usageException('The `$filePath` file does not exist.');
    }

    // Get coverage info.
    final fileContent = file.readAsStringSync().trim();

    // Split coverage data by the end of record prefix, which indirectly splits
    // the info by file.
    final tracefileData = Tracefile.parse(fileContent);

    logCoverage(
      out: _out,
      tracefile: tracefileData,
      shouldLogFiles: shouldLogFiles,
    );
  }

  /// Log coverage values.
  static void logCoverage({
    required Stdout out,
    required Tracefile tracefile,
    required bool shouldLogFiles,
  }) {
    if (shouldLogFiles) {
      // For each file coverage data.
      for (final fileCovData in tracefile.sourceFilesCovData) {
        out.writeln(fileCovData.coverageDataString);
      }
      out.writeln();
    }

    // Show resulting coverage.
    out
      ..writeln(wrapWith('GLOBAL:', [blue, styleBold]))
      ..writeln(wrapWith(tracefile.coverageDataString, [blue, styleBold]));
  }
}
