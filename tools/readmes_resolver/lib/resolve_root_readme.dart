import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:collection/collection.dart';
import 'package:coverde/coverde.dart';
import 'package:path/path.dart' as p;
import 'package:recase/recase.dart' as recase;

/// Gets the git remote URL from the repository.
///
/// Returns the HTTPS URL of the remote origin, or null if git is not available
/// or the remote cannot be determined.
Future<String?> _getGitRemoteUrl(String workingDirectory) async {
  try {
    final result = await Process.run(
      'git',
      ['config', '--get', 'remote.origin.url'],
      workingDirectory: workingDirectory,
    );

    if (result.exitCode != 0) {
      return null;
    }

    final remoteUrl = result.stdout.toString().trim();
    if (remoteUrl.isEmpty) {
      return null;
    }

    return _convertToHttpsUrl(remoteUrl);
  } on Object {
    return null;
  }
}

/// Converts a git remote URL to HTTPS format.
///
/// Handles both SSH (`git@github.com:owner/repo.git`) and HTTPS
/// (`https://github.com/owner/repo.git`) formats.
String _convertToHttpsUrl(String remoteUrl) {
  // Handle SSH format: git@github.com:owner/repo.git
  final sshMatch = RegExp(r'git@([^:]+):(.+)\.git?').firstMatch(remoteUrl);
  if (sshMatch != null) {
    final host = sshMatch.group(1)!;
    final repo = sshMatch.group(2)!;
    return 'https://$host/$repo';
  }

  // Handle HTTPS format: https://github.com/owner/repo.git
  final httpsMatch = RegExp('https?://[^/]+/[^/]+/[^/]+').firstMatch(remoteUrl);
  if (httpsMatch != null) {
    final url = httpsMatch.group(0)!;
    // Remove .git suffix if present
    return url.replaceAll(RegExp(r'\.git$'), '');
  }

  // Return as-is if format is not recognized
  return remoteUrl;
}

/// Gets the current git branch name.
///
/// Returns the current branch name, or 'main' as a default if git is not
/// available or the branch cannot be determined.
Future<String> _getGitBranch(String workingDirectory) async {
  try {
    final result = await Process.run(
      'git',
      ['rev-parse', '--abbrev-ref', 'HEAD'],
      workingDirectory: workingDirectory,
    );

    if (result.exitCode != 0) {
      return 'main';
    }

    final branch = result.stdout.toString().trim();
    return branch.isEmpty ? 'main' : branch;
  } on Object {
    return 'main';
  }
}

/// Resolves the git URL for the repository.
///
/// Constructs a GitHub blob URL from the git remote URL and current branch.
/// Falls back to a default value if git information cannot be determined.
Future<String> _resolveGitUrl(String readmePath) async {
  // Find the repository root by looking for .git directory
  final readmeDir = Directory(p.dirname(readmePath));
  var currentDir = readmeDir.absolute;

  // Walk up the directory tree to find .git
  while (currentDir.path != currentDir.parent.path) {
    final gitDir = Directory(p.join(currentDir.path, '.git'));
    if (gitDir.existsSync()) {
      final remoteUrl = await _getGitRemoteUrl(currentDir.path);
      final branch = await _getGitBranch(currentDir.path);

      if (remoteUrl != null) {
        // Construct GitHub blob URL with the path to packages/coverde_cli
        final relativePath = p
            .relative(
              p.dirname(readmePath),
              from: currentDir.path,
            )
            .replaceAll(r'\', '/');
        return '$remoteUrl/blob/$branch/$relativePath';
      }
      break;
    }
    currentDir = currentDir.parent;
  }

  // Fallback to hardcoded value if git info cannot be determined
  return '''https://github.com/mrverdant13/coverde/blob/main/packages/coverde_cli''';
}

Future<void> main(List<String> args) async {
  final runner = CoverdeCommandRunner();
  final commands = runner.featureCommands.toSet();

  final parser = ArgParser(allowTrailingOptions: false)
    ..addOption(
      'readme',
      mandatory: true,
    )
    ..addOption(
      'description-footer-dir',
    )
    ..addMultiOption(
      'example-dirs',
    );
  final argResults = parser.parse(args);
  final readmePath = argResults.option('readme')!;
  final descriptionFooterDirPath = argResults.option('description-footer-dir');
  final exampleDirPaths = argResults.multiOption('example-dirs');

  final readmeFile = File(readmePath);
  if (!readmeFile.existsSync()) readmeFile.createSync(recursive: true);
  final initialReadmeContent = readmeFile.readAsStringSync();

  final gitUrl = await _resolveGitUrl(readmePath);

  const updateChecksToken = '<!-- UPDATE CHECKS -->';
  final updateChecksRegex = RegExp(
    '$updateChecksToken(.*?)$updateChecksToken',
    dotAll: true,
  );
  final updateChecks =
      updateChecksRegex.firstMatch(initialReadmeContent)?.group(1)?.trim();
  if (updateChecks == null) {
    throw StateError('Update checks section not found in root readme');
  }
  final updateCheckOptionDetails = runner
          .argParser.options[CoverdeCommandRunner.updateCheckOptionName]
          ?.asMarkdownMultiline(isBullet: false) ??
      '';

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

  final descriptionFooterFiles = switch (descriptionFooterDirPath) {
    null => <File>[],
    final String path =>
      Directory(path).listSync().whereType<File>().sortedBy((it) => it.path),
  };

  final exampleFiles = exampleDirPaths
      .map((path) => Directory(path).listSync().whereType<File>())
      .expand((it) => it)
      .sortedBy((it) => it.path);

  final features = await Future.wait([
    for (final command in commands)
      Future(() async {
        final commandInvocation = '${runner.executableName} ${command.name}';
        final detailsBuffer = StringBuffer();
        final overview = [
          '- [**${command.summary}**]',
          '(#${commandInvocation.paramCase})',
        ].join();
        final descriptionFooter = descriptionFooterFiles
            .where(
              (file) {
                return p.basename(file.path) ==
                    '${commandInvocation.paramCase}.md';
              },
            )
            .map((file) => file.readAsStringSync().trim())
            .singleOrNull
            ?.trim();
        detailsBuffer
          ..writeln('## `$commandInvocation`')
          ..writeln()
          ..writeln(
            command.getMarkdownMultiline(
              descriptionFooter: descriptionFooter,
            ),
          );
        final commandExampleFiles = exampleFiles.where(
          (file) {
            final name = p.basenameWithoutExtension(file.path);
            final extension = p.extension(file.path);
            return name.startsWith(commandInvocation.paramCase) &&
                ['.png', '.md'].contains(extension);
          },
        );
        if (commandExampleFiles.isNotEmpty) {
          detailsBuffer
            ..writeln()
            ..writeln('### Examples')
            ..writeln();
          for (final commandExampleFile in commandExampleFiles) {
            final exampleExtension = p.extension(commandExampleFile.path);
            if (exampleExtension == '.png') {
              final referenceableExamplePath = p.relative(
                commandExampleFile.path,
                from: p.dirname(readmePath),
              );
              detailsBuffer.writeln(
                '![${p.basename(commandExampleFile.path)}]'
                '(${p.url.joinAll([gitUrl, referenceableExamplePath])})',
              );
            } else if (exampleExtension == '.md') {
              detailsBuffer.writeln(
                commandExampleFile.readAsStringSync().trim(),
              );
            }
          }
        }
        return (
          overview: overview,
          details: detailsBuffer.toString(),
        );
      }),
  ]);

  final readmeContentWithFeatures = initialReadmeContent
      .replaceAll(
        updateChecksRegex,
        '''
$updateChecksToken
$updateCheckOptionDetails
$updateChecksToken
'''
            .trim(),
      )
      .replaceAll(
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

extension on CoverdeCommand {
  String getMarkdownMultiline({
    String? descriptionFooter,
  }) {
    final buf = StringBuffer()..writeln(description.asMarkdownMultiline);
    if (descriptionFooter != null) {
      buf
        ..writeln()
        ..writeln(descriptionFooter);
    }
    final optionsAsMarkdownMultiline =
        argParser.options.values.asMarkdownMultiline;
    final paramsAsMarkdownMultiline = params?.asMarkdownMultiline;
    if (optionsAsMarkdownMultiline != null ||
        paramsAsMarkdownMultiline != null) {
      buf
        ..writeln()
        ..writeln('### Arguments');
    }
    if (optionsAsMarkdownMultiline != null) {
      buf
        ..writeln()
        ..writeln(optionsAsMarkdownMultiline);
    }
    if (paramsAsMarkdownMultiline != null) {
      buf
        ..writeln()
        ..writeln(paramsAsMarkdownMultiline);
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
    for (final MapEntry(key: type, value: options) in optionGroups.entries) {
      if (options.isEmpty) continue;
      final typeHeading = switch (type) {
        OptionType.flag => 'Flags',
        OptionType.single => 'Single-options',
        OptionType.multiple => 'Multi-options',
        _ => null,
      };
      if (typeHeading == null) {
        throw UnsupportedError(
          'Unknown option type encountered: $type.\n'
          'Please update the asMarkdownMultiline extension in '
          '`resolve_root_readme.dart` to handle this new option type.\n'
          'This error prevents incomplete or incorrect documentation output.\n'
          'If you recently updated the args package or introduced a new '
          'OptionType, ensure it is handled here.',
        );
      }
      buf
        ..writeln('#### $typeHeading')
        ..writeln();
      for (final option in options) {
        buf
          ..writeln(option.asMarkdownMultiline(isBullet: true))
          ..writeln();
      }
    }
    return buf.toString().trim();
  }
}

extension on CoverdeCommandParams {
  String get asMarkdownMultiline {
    final buf = StringBuffer()
      ..writeln('#### Parameters')
      ..writeln()
      ..writeln('- `$identifier`')
      ..writeln()
      ..writeln(description.asMarkdownMultiline.indent(2));
    return buf.toString().trim();
  }
}

extension on Option {
  String asMarkdownMultiline({
    required bool isBullet,
  }) {
    final buf = StringBuffer();
    if (isBullet) {
      buf.write('- ');
    }
    buf
      ..writeln('`--$name`')
      ..writeln();

    final defaultValueString = switch (defaultsTo) {
      null => null,
      final bool defaults => '_${defaults ? 'Enabled' : 'Disabled'}_',
      final List<String> defaults when defaults.isEmpty => '_None_',
      final List<String> defaults =>
        defaults.map((value) => '`$value`').join(', '),
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
    ].nonNulls.join('\\\n').indent(isBullet ? 2 : 0);

    if (details.isNotEmpty) {
      buf.writeln(details);
    }
    return buf.toString().trim();
  }
}

extension on String {
  String indent(int level) {
    if (level == 0) return this;
    final lines = LineSplitter.split(this);
    final indentedLines = lines.map(
      (line) => line.isEmpty ? line : ' ' * level + line,
    );
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
