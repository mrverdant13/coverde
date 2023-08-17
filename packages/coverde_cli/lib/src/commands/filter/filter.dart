import 'package:args/command_runner.dart';
import 'package:coverde/src/entities/trace_file.dart';
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
        valueHelp: _outputHelpValue,
      )
      ..addOption(
        pathsParentOption,
        abbr: pathsParentOption[0],
        help: '''
Path to be used to prefix all the paths in the resulting coverage trace file.''',
        valueHelp: _pathsParentHelpValue,
        mandatory: false,
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
        help: 'The mode in which the $_outputHelpValue can be generated.',
        valueHelp: _modeHelpValue,
        allowed: _outModeAllowedHelp.keys,
        allowedHelp: _outModeAllowedHelp,
        defaultsTo: _outModeAllowedHelp.keys.first,
      );
  }

  final Stdout _out;

  static const _inputHelpValue = 'INPUT_LCOV_FILE';
  static const _outputHelpValue = 'OUTPUT_LCOV_FILE';
  static const _pathsParentHelpValue = 'PATHS_PARENT';
  static const _filtersHelpValue = 'FILTERS';
  static const _modeHelpValue = 'MODE';
  static const _outModeAllowedHelp = {
    'a': '''
Append filtered content to the $_outputHelpValue content, if any.''',
    'w': '''
Override the $_outputHelpValue content, if any, with the filtered content.''',
  };

  /// Option name for identifier patters to be used for trace file filtering.
  @visibleForTesting
  static const filtersOption = 'filters';

  /// Option name for the origin trace file to be filtered.
  @visibleForTesting
  static const inputOption = 'input';

  /// Option name for the resulting filtered trace file.
  @visibleForTesting
  static const outputOption = 'output';

  /// Option name for the paths parent to be used to prefix all the paths in the
  /// resulting coverage trace file.
  ///
  /// This option is optional.
  @visibleForTesting
  static const pathsParentOption = 'paths-parent';

  /// Option name for the resulting filtered trace file.
  @visibleForTesting
  static const modeOption = 'mode';

  @override
  String get description => '''
Filter a coverage trace file.

Filter the coverage info by ignoring data related to files with paths that matches the given $_filtersHelpValue.
The coverage data is taken from the $_inputHelpValue file and the result is appended to the $_outputHelpValue file.

All the relative paths in the resulting coverage trace file will be prefixed with $_pathsParentHelpValue, if provided.
If an absolute path is found in the coverage trace file, the process will fail.''';

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
    final pathsParent = checkOptionalOption(
      optionKey: pathsParentOption,
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

    if (!origin.existsSync()) {
      usageException('The trace file located at `$originPath` does not exist.');
    }

    // Get initial package coverage data.
    final initialContent = origin.readAsStringSync().trim();

    // Parse trace file.
    final traceFile = TraceFile.parse(initialContent);
    final acceptedSrcFilesRawData = <String>{};

    // For each file coverage data.
    for (final fileCovData in traceFile.sourceFilesCovData) {
      // Check if file should be ignored according to matching patterns.
      final shouldBeIgnored = ignorePatterns.any(
        (ignorePattern) {
          final regexp = RegExp(ignorePattern);
          return regexp.hasMatch(fileCovData.source.path);
        },
      );

      // Conditionally include file coverage data.
      if (shouldBeIgnored) {
        _out.writeln('<${fileCovData.source.path}> coverage data ignored.');
      } else {
        if (path.isAbsolute(fileCovData.source.path) && pathsParent != null) {
          usageException(
            'The `$pathsParentOption` option cannot be used with trace files'
            'that contain absolute paths.',
          );
        }
        final raw = pathsParent == null
            ? fileCovData.raw
            : fileCovData.raw.replaceFirst(
                RegExp(r'^SF:(.*)$', multiLine: true),
                'SF:${path.join(pathsParent, fileCovData.source.path)}',
              );
        acceptedSrcFilesRawData.add(raw);
      }
    }

    final finalContent = acceptedSrcFilesRawData.join('\n');

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
