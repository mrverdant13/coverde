import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cov_utils/src/cov/prefix.dart';
import 'package:path/path.dart' as path;

/// {@template filter_cmd}
/// A command to filter coverage info files.
/// {@endtemplate filter_cmd}
class FilterCommand extends Command<void> {
  /// {@template filter_cmd}
  FilterCommand() {
    argParser
      ..addMultiOption(
        _ignorePatternsOption,
        abbr: 'i',
        help: '''
Set of comma-separated path patterns of the files to be ignored.
Consider that the coverage info of each file is checked as a multiline block.
Each bloc starts with `${Prefix.sourceFile}` and ends with `${Prefix.endOfRecord}`.''',
        defaultsTo: [],
        valueHelp: _ignorePatternsHelpValue,
      )
      ..addOption(
        _originOption,
        abbr: 'o',
        help: 'Origin coverage info file to pick coverage data from.',
        defaultsTo: 'coverage/lcov.info',
        valueHelp: _originHelpValue,
      )
      ..addOption(
        _destinationOption,
        abbr: 'd',
        help: '''
Destination coverage info file to dump the resulting coverage data into.''',
        defaultsTo: 'coverage/wiped.lcov.info',
        valueHelp: _destinationHelpValue,
      );
  }

  static const _ignorePatternsHelpValue = 'PATTERNS';
  static const _originHelpValue = 'ORIGIN_LCOV_FILE';
  static const _destinationHelpValue = 'DESTINATION_LCOV_FILE';

  static const _ignorePatternsOption = 'ignore-patterns';
  static const _originOption = 'origin';
  static const _destinationOption = 'destination';

  @override
  String get description => '''
Filter a coverage info file.

Filter the coverage info by ignoring data related to files with paths that matches the given $_ignorePatternsHelpValue.
The coverage data is taken from the $_originHelpValue file and the result is appended to the $_destinationHelpValue file.''';

  @override
  String get name => 'filter';

  @override
  List<String> get aliases => ['f'];

  @override
  Future<void> run() async {
    // Retrieve arguments and validate their value and the state they represent.
    final _argResults = ArgumentError.checkNotNull(argResults);

    final originPath = ArgumentError.checkNotNull(
      _argResults[_originOption],
    ) as String;
    final destinationPath = ArgumentError.checkNotNull(
      _argResults[_destinationOption],
    ) as String;
    final ignorePatterns = ArgumentError.checkNotNull(
      _argResults[_ignorePatternsOption],
    ) as List<String>;

    final origin = File(originPath);
    final destination = File(destinationPath);
    final pwd = Directory.current;

    if (!origin.existsSync()) {
      throw StateError('The `$originPath` file does not exist.');
    }

    // Get initial package coverage data.
    final initialContent = origin.readAsStringSync().trim();
    final finalContentBuf = StringBuffer();

    // Split coverage data by the end of record prefix, which indirectly splits
    // the info by file.
    final filesCovData = initialContent //
        .split(Prefix.endOfRecord) //
        .map((s) => s.trim()) //
        .where((s) => s.isNotEmpty);

    // For each file coverage data.
    for (final fileCovData in filesCovData) {
      // Check if file should be ignored according to matching patterns.
      var shouldBeIgnored = false;
      for (final ignorePattern in ignorePatterns) {
        final regexp = RegExp(ignorePattern);
        shouldBeIgnored |= regexp.hasMatch(fileCovData);
      }

      // Conditionaly include file coverage data.
      if (shouldBeIgnored) {
        const dartExtension = '.dart';
        final fileStartIdx =
            fileCovData.indexOf(Prefix.sourceFile) + Prefix.sourceFile.length;
        final fileEndIdx = fileCovData.indexOf(dartExtension);

        final ignoredFile = fileCovData.substring(fileStartIdx, fileEndIdx);

        stdout.writeln('<$ignoredFile$dartExtension> coverage data ignored.');
      } else {
        finalContentBuf
          ..writeln(
            fileCovData.replaceAll(
              RegExp(Prefix.sourceFile),
              '${Prefix.sourceFile}${pwd.path}${path.separator}',
            ),
          )
          ..writeln(Prefix.endOfRecord);
      }
    }

    // Generate destination file and its content.
    destination
      ..createSync(recursive: true)
      ..writeAsStringSync(
        finalContentBuf.toString(),
        mode: FileMode.append,
        flush: true,
      );
  }
}
