import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:coverde/src/entities/cov_file.dart';
import 'package:coverde/src/entities/tracefile.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

/// {@template filter_cmd}
/// A command to filter coverage info files.
/// {@endtemplate filter_cmd}
class FilterCommand extends Command<void> {
  /// {@template filter_cmd}
  FilterCommand({Stdout? out}) : _out = out ?? stdout {
    argParser
      ..addMultiOption(
        ignorePatternsOption,
        abbr: ignorePatternsOption[0],
        help: '''
Set of comma-separated path patterns of the files to be ignored.
Consider that the coverage info of each file is checked as a multiline block.
Each bloc starts with `${CovFile.sourceFileTag}` and ends with `${CovFile.endOfRecordTag}`.''',
        defaultsTo: [],
        valueHelp: _ignorePatternsHelpValue,
      )
      ..addOption(
        originOption,
        abbr: originOption[0],
        help: 'Origin coverage info file to pick coverage data from.',
        defaultsTo: 'coverage/lcov.info',
        valueHelp: _originHelpValue,
      )
      ..addOption(
        destinationOption,
        abbr: destinationOption[0],
        help: '''
Destination coverage info file to dump the resulting coverage data into.''',
        defaultsTo: 'coverage/filtered.lcov.info',
        valueHelp: _destinationHelpValue,
      )
      ..addOption(
        outModeOption,
        abbr: outModeOption[0],
        help: 'The mode in which the $_destinationHelpValue can be generated.',
        valueHelp: _outModeHelpValue,
        allowed: _outModeAllowedHelp.keys,
        allowedHelp: _outModeAllowedHelp,
        defaultsTo: _outModeAllowedHelp.keys.first,
      );
  }

  final Stdout _out;

  static const _ignorePatternsHelpValue = 'PATTERNS';
  static const _originHelpValue = 'ORIGIN_LCOV_FILE';
  static const _destinationHelpValue = 'DESTINATION_LCOV_FILE';
  static const _outModeHelpValue = 'OUT_MODE';
  static const _outModeAllowedHelp = {
    'a': '''
Append filtered content to the $_destinationHelpValue content, if any.''',
    'w': '''
Override the $_destinationHelpValue content, if any, with the filtered content.''',
  };

  /// Option name for identifier patters to be used for tracefile filtering.
  @visibleForTesting
  static const ignorePatternsOption = 'ignore-patterns';

  /// Option name for the origin tracefile to be filtered.
  @visibleForTesting
  static const originOption = 'origin';

  /// Option name for the resulting filtered tracefile.
  @visibleForTesting
  static const destinationOption = 'destination';

  /// Option name for the resulting filtered tracefile.
  @visibleForTesting
  static const outModeOption = 'mode';

// coverage:ignore-start
  @override
  String get description => '''
Filter a coverage info file.

Filter the coverage info by ignoring data related to files with paths that matches the given $_ignorePatternsHelpValue.
The coverage data is taken from the $_originHelpValue file and the result is appended to the $_destinationHelpValue file.''';
// coverage:ignore-end

  @override
  String get name => 'filter';

  @override
  List<String> get aliases => [name[0]];

  @override
  Future<void> run() async {
    // Retrieve arguments and validate their value and the state they represent.
    final _argResults = ArgumentError.checkNotNull(argResults);

    final originPath = ArgumentError.checkNotNull(
      _argResults[originOption],
    ) as String;
    final destinationPath = ArgumentError.checkNotNull(
      _argResults[destinationOption],
    ) as String;
    final ignorePatterns = ArgumentError.checkNotNull(
      _argResults[ignorePatternsOption],
    ) as List<String>;
    final shouldOverride = (ArgumentError.checkNotNull(
          _argResults[outModeOption],
        ) as String) ==
        'w';

    final origin = File(originPath);
    final destination = File(destinationPath);
    final pwd = Directory.current;

    if (!origin.existsSync()) {
      throw StateError('The `$originPath` file does not exist.');
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
