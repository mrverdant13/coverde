import 'package:args/command_runner.dart';
import 'package:coverde/src/entities/cov_file.dart';
import 'package:coverde/src/entities/tracefile.dart';
import 'package:coverde/src/utils/command.dart';
import 'package:coverde/src/utils/path.dart';
import 'package:meta/meta.dart';
import 'package:universal_io/io.dart';

/// {@template filter_cmd}
/// A command to filter coverage info files.
/// {@endtemplate filter_cmd}
class FilterCommand extends Command<void> {
  /// {@template filter_cmd}
  FilterCommand({Stdout? out}) : _out = out ?? stdout {
    argParser
      ..addOption(
        inputOption,
        abbr: inputOption[0],
        help: 'Origin coverage info file to pick coverage data from.',
        defaultsTo: 'coverage/lcov.info',
        valueHelp: _inputHelpValue,
      )
      ..addOption(
        outputOption,
        abbr: outputOption[0],
        help: '''
Destination coverage info file to dump the resulting coverage data into.''',
        defaultsTo: 'coverage/filtered.lcov.info',
        valueHelp: _outpitHelpValue,
      )
      ..addMultiOption(
        filtersOption,
        abbr: filtersOption[0],
        help: '''
Set of comma-separated path patterns of the files to be ignored.''',
        defaultsTo: [],
        valueHelp: _filtersHelpValue,
      )
      ..addOption(
        modeOption,
        abbr: modeOption[0],
        help: 'The mode in which the $_outpitHelpValue can be generated.',
        valueHelp: _modeHelpValue,
        allowed: _outModeAllowedHelp.keys,
        allowedHelp: _outModeAllowedHelp,
        defaultsTo: _outModeAllowedHelp.keys.first,
      );
  }

  final Stdout _out;

  static const _inputHelpValue = 'INPUT_LCOV_FILE';
  static const _outpitHelpValue = 'OUTPUT_LCOV_FILE';
  static const _filtersHelpValue = 'FILTERS';
  static const _modeHelpValue = 'MODE';
  static const _outModeAllowedHelp = {
    'a': '''
Append filtered content to the $_outpitHelpValue content, if any.''',
    'w': '''
Override the $_outpitHelpValue content, if any, with the filtered content.''',
  };

  /// Option name for identifier patters to be used for tracefile filtering.
  @visibleForTesting
  static const filtersOption = 'filters';

  /// Option name for the origin tracefile to be filtered.
  @visibleForTesting
  static const inputOption = 'input';

  /// Option name for the resulting filtered tracefile.
  @visibleForTesting
  static const outputOption = 'output';

  /// Option name for the resulting filtered tracefile.
  @visibleForTesting
  static const modeOption = 'mode';

  @override
  String get description => '''
Filter a coverage trace file.

Filter the coverage info by ignoring data related to files with paths that matches the given $_filtersHelpValue.
The coverage data is taken from the $_inputHelpValue file and the result is appended to the $_outpitHelpValue file.''';

  @override
  String get name => 'filter';

  @override
  List<String> get aliases => [name[0]];

  @override
  bool get takesArguments => false;

  @override
  Future<void> run() async {
    // Retrieve arguments and validate their value and the state they represent.
    final originPath = checkOption(
      optionKey: inputOption,
      optionName: 'input trace file',
    );
    final destinationPath = checkOption(
      optionKey: outputOption,
      optionName: 'output trace file',
    );
    final ignorePatterns = checkMultiOption(
      multiOptionKey: filtersOption,
      multiOptionName: 'ignored patterns list',
    );
    final shouldOverride = checkOption(
          optionKey: modeOption,
          optionName: 'output mode',
        ) ==
        'w';

    final origin = File(originPath);
    final destination = File(destinationPath);
    final pwd = Directory.current;

    if (!origin.existsSync()) {
      usageException('The trace file located at `$originPath` does not exist.');
    }

    // Get initial package coverage data.
    final initialContent = origin.readAsStringSync().trim();

    // Parse tracefile.
    final tracefile = Tracefile.parse(initialContent);
    final acceptedSrcFilesCovData = <CovFile>{};

    // For each file coverage data.
    for (final fileCovData in tracefile.sourceFilesCovData) {
      // Check if file should be ignored according to matching patterns.
      final shouldBeIgnored = ignorePatterns.any(
        (ignorePattern) {
          final regexp = RegExp(ignorePattern);
          return regexp.hasMatch(fileCovData.source.path);
        },
      );

      // Conditionaly include file coverage data.
      if (shouldBeIgnored) {
        _out.writeln('<${fileCovData.source.path}> coverage data ignored.');
      } else {
        acceptedSrcFilesCovData.add(fileCovData);
      }
    }

    // Use absolute path.
    final finalContent = acceptedSrcFilesCovData
        .map((srcFileCovData) => srcFileCovData.raw)
        .join('\n')
        .replaceAll(
          RegExp(CovFile.sourceFileTag),
          '${CovFile.sourceFileTag}${pwd.path}${path.separator}',
        );

    // Generate destination file and its content.
    destination
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '$finalContent\n',
        mode: shouldOverride ? FileMode.write : FileMode.append,
        flush: true,
      );
  }
}
