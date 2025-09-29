import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:collection/collection.dart';
import 'package:coverde/coverde.dart' as coverde;
import 'package:recase/recase.dart' as recase;

void main(List<String> args) {
  final parser = ArgParser(allowTrailingOptions: false)
    ..addOption(
      'output',
      abbr: 'o',
      mandatory: true,
    );
  final argResults = parser.parse(args);
  final outputPath = argResults.option('output')!;

  // Accessing the internal runner is required to access its details.
  // ignore: invalid_use_of_internal_member
  final runner = coverde.runner;
  final commands =
      runner.commands.values.where((command) => command.name != 'help').toSet();

  final featuresOverviewBuffer = StringBuffer();
  final featureDetailsBuffer = StringBuffer();

  for (final command in commands) {
    featuresOverviewBuffer.writeln(
      /// No separation required for markdown links.
      // ignore: missing_whitespace_between_adjacent_strings
      '- [**${command.summary}**]'
      '(#${'${runner.executableName} ${command.name}'.paramCase})',
    );
    featureDetailsBuffer
      ..writeln('## `${runner.executableName} ${command.name}`')
      ..writeln()
      ..writeln(command.description.asMarkdownMultiline)
      ..writeln();
    final options = command.argParser.options.values;
    final optionGroups = options
        .where((option) => option.name != 'help')
        .groupListsBy((option) => option.type);
    if (optionGroups.isNotEmpty) {
      featureDetailsBuffer
        ..writeln('### Options')
        ..writeln();
    }
    for (final MapEntry(key: type, value: options) in optionGroups.entries) {
      final typeHeading = switch (type) {
        OptionType.flag => 'Flags',
        OptionType.single => 'Single-options',
        OptionType.multiple => 'Multi-options',
        _ => null,
      };
      if (typeHeading == null) {
        stdout.writeln('Unknown option type: $type');
        continue;
      }
      if (options.isEmpty) continue;
      featureDetailsBuffer
        ..writeln('#### $typeHeading')
        ..writeln();
      for (final option in options) {
        featureDetailsBuffer.writeln('- `--${option.name}`');
        final details = () {
          final help = switch (option.help) {
            final String help => help.indent(2),
            null => null,
          };
          // Type check is intended here.
          // ignore: switch_on_type
          final defaultValue = switch (option.defaultsTo) {
            null => null,
            final bool defaults => '**Default value:** '
                '_${defaults ? 'Enabled' : 'Disabled'}_',
            final List<String> defaults when defaults.isEmpty =>
              '**Default value:** '
                  '_None_',
            final List<String> defaults => '**Default value:** '
                '`${defaults.map((value) => '`$value`').join(', ')}`',
            final defaults => '**Default value:** '
                '`$defaults`',
          };

          final allowedDetails = () {
            if (option.allowedHelp case final Map<String, String> help
                when help.isNotEmpty) {
              return [
                '  **Allowed values:**',
                for (final MapEntry(key: value, value: description)
                    in help.entries)
                  '    - `$value`: $description',
              ].join('\n');
            }
            if (option.allowed case final List<String> allowed) {
              return allowed.map((value) => '    `$value`').join('\n');
            }
          }();

          return [
            help,
            defaultValue?.indent(2),
            allowedDetails,
          ].nonNulls.join('\\\n');
        }();
        if (details.isNotEmpty) {
          featureDetailsBuffer
            ..writeln()
            ..writeln(details);
        }
        featureDetailsBuffer.writeln();
      }
    }
    final examples = examplesByCommand[command.name] ?? [];
    if (examples.isNotEmpty) {
      featureDetailsBuffer
        ..writeln('### Examples')
        ..writeln();
      for (final example in examples) {
        final exampleCommand = [
          runner.executableName,
          command.name,
          if (example.isNotEmpty) example,
        ].join(' ');
        featureDetailsBuffer.writeln('- `$exampleCommand`');
      }
      featureDetailsBuffer.writeln();
    }
  }

  final readmeFile = File(outputPath);
  final initialReadmeContent = readmeFile.readAsStringSync();

  const featuresToken = '<!-- CLI FEATURES -->';
  final featuresRegex = RegExp(
    '$featuresToken(.*?)$featuresToken',
    dotAll: true,
  );
  final rawFeatures =
      featuresRegex.firstMatch(initialReadmeContent)?.group(1)?.trim();
  if (rawFeatures == null) {
    throw StateError('Features section not found in root readme');
  }
  final readmeContentWithFeatures = initialReadmeContent.replaceAll(
    featuresRegex,
    '''
$featuresToken
${featuresOverviewBuffer.toString().trim()}

${featureDetailsBuffer.toString().trim()}
$featuresToken
'''
        .trim(),
  );
  readmeFile.writeAsStringSync(readmeContentWithFeatures);
}

extension on String {
  String indent(int level) {
    final lines = LineSplitter.split(this);
    final indentedLines = lines.map((line) => ' ' * level + line);
    return indentedLines.join('\n');
  }

  String get asMarkdownMultiline {
    final lines = LineSplitter.split(this);
    final trimmedLines = lines.map((line) => line.trim());
    final trimmedLinesCount = trimmedLines.length;
    final markdownLines = Iterable.generate(
      trimmedLinesCount,
      (index) {
        final line = trimmedLines.elementAt(index);
        final lineIsEmpty = line.isEmpty;
        if (lineIsEmpty) return line;
        final nextLineIndex = index + 1;
        if (nextLineIndex >= trimmedLinesCount) return line;
        final nextLineIsEmpty = trimmedLines.elementAt(nextLineIndex).isEmpty;
        if (nextLineIsEmpty) return line;
        return '$line\\';
      },
    );
    return markdownLines.join('\n');
  }
}

const Map<String, List<String>> examplesByCommand = {
  'optimize-tests': [
    '',
    "--include='test/**/some_feature/**_test.dart' --output=test/optimized_tests.dart",
    "--exclude='test/**/fixtures/**' --output=test/optimized_tests.dart",
    '--flutter-goldens=false',
  ],
  'check': [
    '90',
    '-i lcov.info 75',
    '100 --file-coverage-log-level none',
  ],
  'filter': [
    '',
    "-f '.g.dart'",
    "-f '.freezed.dart' -mode w",
    '-f generated -mode a',
    '-o coverage/trace-file.info',
  ],
  'report': [
    '',
    '-i coverage/trace-file.info --medium 50',
    '-o coverage/report --high 95 -l',
  ],
  'remove': [
    'file.txt',
    'path/to/folder/',
    'path/to/another.file.txt path/to/another/folder/ local.folder/',
  ],
  'value': [
    '',
    '-i coverage/trace-file.info --file-coverage-log-level none',
    '--file-coverage-log-level line-numbers',
  ],
};
