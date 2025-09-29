import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:collection/collection.dart';
import 'package:coverde/coverde.dart' as coverde;
import 'package:path/path.dart' as p;
import 'package:recase/recase.dart' as recase;

const gitUrl =
    '''https://github.com/mrverdant13/coverde/blob/main/packages/coverde_cli''';

Future<void> main(List<String> args) async {
  // Accessing the internal runner is required to access its details.
  // ignore: invalid_use_of_internal_member
  final runner = coverde.runner;
  final commands =
      runner.commands.values.where((command) => command.name != 'help').toSet();

  final parser = ArgParser(allowTrailingOptions: false)
    ..addOption(
      'readme-output',
      mandatory: true,
    )
    ..addMultiOption(
      'termshot-commands',
      allowed: [for (final command in commands) command.name],
    )
    ..addOption(
      'termshot-output',
    )
    ..addOption(
      'termshot-working-directory',
    );
  final argResults = parser.parse(args);
  final outputPath = argResults.option('readme-output')!;
  final termshotCommands = argResults.multiOption('termshot-commands');
  final termshotOutputPath = argResults.option('termshot-output');
  final termshotWorkingDirectory =
      argResults.option('termshot-working-directory');
  if (termshotCommands.isNotEmpty && termshotOutputPath == null) {
    throw ArgumentError(
      'termshot-output is required '
      'when termshot-commands is provided',
    );
  }
  if (termshotCommands.isNotEmpty && termshotWorkingDirectory == null) {
    throw ArgumentError(
      'termshot-working-directory is required '
      'when termshot-commands is provided',
    );
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

  final features = await Future.wait([
    for (final command in commands)
      Future(() async {
        final detailsBuffer = StringBuffer();
        final overview = [
          '- [**${command.summary}**]',
          '(#${'${runner.executableName} ${command.name}'.paramCase})',
        ].join();
        detailsBuffer
          ..writeln('## `${runner.executableName} ${command.name}`')
          ..writeln()
          ..writeln(command.asMarkdownMultiline);
        final examplesCommands = termshotCommands.contains(command.name)
            ? examplesByCommand[command.name] ?? <String>[]
            : <String>[];
        await () async {
          final exampleResults = await Future.wait([
            if (termshotOutputPath != null)
              for (final exampleCommand in examplesCommands)
                Future(() async {
                  final fullCommand = [
                    runner.executableName,
                    command.name,
                    if (exampleCommand.isNotEmpty) exampleCommand,
                  ].join(' ');
                  final imageFileName = p.setExtension(
                    fullCommand.asSlug,
                    '.png',
                  );
                  final imageFilePath = p.joinAll([
                    termshotOutputPath,
                    imageFileName,
                  ]);
                  final [executable, ...arguments] = [
                    'termshot',
                    '--show-cmd',
                    '--filename',
                    imageFilePath,
                    '--',
                    ...fullCommand.split(' '),
                  ];
                  await Process.run(
                    executable,
                    arguments,
                    workingDirectory: termshotWorkingDirectory,
                  );
                  return (
                    fullCommand: fullCommand,
                    imageFilePath: imageFilePath,
                  );
                }),
          ]);
          final validExampleResults = exampleResults.nonNulls;
          if (validExampleResults.isEmpty) return null;
          detailsBuffer
            ..writeln('### Examples')
            ..writeln();
          for (final exampleResult in validExampleResults) {
            final imageRelativePath = p.relative(
              exampleResult.imageFilePath,
              from: p.dirname(outputPath),
            );
            detailsBuffer.writeln(
              '![${exampleResult.fullCommand}]'
              '(${p.url.joinAll([gitUrl, imageRelativePath])})',
            );
          }
        }();
        return (
          overview: overview,
          details: detailsBuffer.toString(),
        );
      }),
  ]);

  final readmeContentWithFeatures = initialReadmeContent.replaceAll(
    featuresRegex,
    '''
$featuresToken
${features.map((feature) => feature.overview).join('\n').trim()}

${features.map((feature) => feature.details).join('\n' * 2).trim()}
$featuresToken
'''
        .trim(),
  );
  readmeFile.writeAsStringSync(readmeContentWithFeatures);
}

extension on Command<dynamic> {
  String get asMarkdownMultiline {
    final buf = StringBuffer()..writeln(description.asMarkdownMultiline);
    final optionsAsMarkdownMultiline =
        argParser.options.values.asMarkdownMultiline;
    if (optionsAsMarkdownMultiline != null) {
      buf
        ..writeln()
        ..writeln(optionsAsMarkdownMultiline);
    }
    return buf.toString().trim();
  }
}

extension on Iterable<Option> {
  String? get asMarkdownMultiline {
    final buf = StringBuffer();
    final options = where((option) => option.name != 'help');
    if (options.isEmpty) return null;
    final optionGroups = options.groupListsBy((option) => option.type);
    buf
      ..writeln('### Options')
      ..writeln();
    for (final MapEntry(key: type, value: options) in optionGroups.entries) {
      if (options.isEmpty) continue;
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
      buf
        ..writeln('#### $typeHeading')
        ..writeln();
      for (final option in options) {
        buf
          ..writeln(option.asMarkdownMultiline)
          ..writeln();
      }
    }
    return buf.toString().trim();
  }
}

extension on Option {
  String get asMarkdownMultiline {
    final buf = StringBuffer()
      ..writeln('- `--$name`')
      ..writeln();

    // Type check is intended here.
    // ignore: switch_on_type
    final defaultValueString = switch (defaultsTo) {
      null => null,
      final bool defaults => '_${defaults ? 'Enabled' : 'Disabled'}_',
      final List<String> defaults when defaults.isEmpty => '_None_',
      final List<String> defaults =>
        '`${defaults.map((value) => '`$value`').join(', ')}`',
      final defaults => '`$defaults`',
    };

    final allowedList = () {
      if (allowedHelp case final Map<String, String> help
          when help.isNotEmpty) {
        return [
          for (final MapEntry(key: value, value: description) in help.entries)
            '- `$value`: $description',
        ];
      }
      if (allowed case final List<String> allowed when allowed.isNotEmpty) {
        return [
          for (final value in allowed) '- `$value`',
        ];
      }
    }();
    final details = [
      help,
      if (defaultValueString != null) '**Default value:** $defaultValueString',
      if (allowedList != null)
        [
          '**Allowed values:**',
          allowedList.join('\n').indent(2),
        ].join('\n'),
    ].nonNulls.join('\\\n').indent(2);

    if (details.isNotEmpty) {
      buf.writeln(details);
    }
    return buf.toString().trim();
  }
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

  String get asSlug {
    return toLowerCase()
        .trim()
        // Remove accents/diacritics
        .replaceAllMapped(
          // cspell:disable
          RegExp('[àáâãäçèéêëìíîïñòóôõöùúûüýÿ]'),
          (match) {
            const from = 'àáâãäçèéêëìíîïñòóôõöùúûüýÿ';
            const to = 'aaaaaceeeeiiiinooooouuuuyy';
            return to[from.indexOf(match[0]!)];
          },
          // cspell:enable
        )
        // Replace special chars with hyphens
        .replaceAll(RegExp(r'[^\w\s-]'), '-')
        // Replace whitespace with single hyphen
        .replaceAll(RegExp(r'\s+'), '-')
        // Replace underscores with hyphens
        .replaceAll('_', '-')
        // Remove consecutive hyphens
        .replaceAll(RegExp('-+'), '-')
        // Remove leading/trailing hyphens
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}

const Map<String, List<String>> examplesByCommand = {
  'optimize-tests': [
    "--exclude='test/**/fixtures/**' --output=test/optimized_tests.dart",
    "--include='test/**/some_feature/**_test.dart' --output=test/optimized_tests.dart",
    '--no-flutter-goldens',
    '',
  ],
  'check': [
    '50',
    '--file-coverage-log-level line-numbers 100',
    '-i coverage/custom.lcov.info --file-coverage-log-level none 75',
  ],
  'filter': [
    '',
    "-f '.g.dart'",
    "-f '.freezed.dart' --mode w",
    '-f generated --mode a',
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
    '--file-coverage-log-level line-numbers',
    '-i coverage/custom.lcov.info --file-coverage-log-level none',
    '',
  ],
};
