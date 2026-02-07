import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:collection/collection.dart';
import 'package:coverde/coverde.dart';
import 'package:path/path.dart' as p;
import 'package:recase/recase.dart' as recase;

/// Gets the git remote URL from the repository.
///
/// Returns the remote URL as-is, or null if git is not available
/// or the remote cannot be determined.
Future<String?> _getGitRemoteUrl(String workingDirectory) async {
  try {
    final result = await Process.run(
      'git',
      ['config', '--get', 'remote.origin.url'],
      workingDirectory: workingDirectory,
    );
    if (result.exitCode != 0) return null;
    final remoteUrl = result.stdout.toString().trim();
    if (remoteUrl.isEmpty) return null;
    return remoteUrl;
  } on Object {
    return null;
  }
}

/// Extracts owner and repo name from a git remote URL.
///
/// Handles both SSH (`git@github.com:owner/repo.git`) and HTTPS
/// (`https://github.com/owner/repo.git`) formats.
///
/// Returns a record of (owner, repo), or null if the URL format is not
/// recognized.
(String owner, String repo)? _extractOwnerAndRepo(String remoteUrl) {
  // Handle SSH format: git@github.com:owner/repo.git
  final sshMatch =
      RegExp(r'git@[^:]+:([^/]+)/(.+)\.git?').firstMatch(remoteUrl);
  if (sshMatch != null) {
    final owner = sshMatch.group(1)!;
    final repo = sshMatch.group(2)!;
    return (owner, repo);
  }

  // Handle HTTPS format: https://github.com/owner/repo.git
  final httpsMatch =
      RegExp('https?://[^/]+/([^/]+)/([^/]+)').firstMatch(remoteUrl);
  if (httpsMatch != null) {
    final owner = httpsMatch.group(1)!;
    final repo = httpsMatch.group(2)!.replaceAll(RegExp(r'\.git$'), '');
    return (owner, repo);
  }

  return null;
}

/// Resolves the base URL for a docs asset.
Future<Uri?> _resolveDocsAssetBaseUri(String readmePath) async {
  final readmeDir = Directory(p.dirname(readmePath));
  final repoRootPath = () {
    var currentDir = readmeDir.absolute;
    while (currentDir.path != currentDir.parent.path) {
      final gitDir = Directory(p.join(currentDir.path, '.git'));
      if (gitDir.existsSync()) {
        return currentDir.path;
      }
      currentDir = currentDir.parent;
    }
  }();
  if (repoRootPath == null) return null;
  final remoteUrl = await _getGitRemoteUrl(repoRootPath);
  if (remoteUrl == null) return null;
  final ownerAndRepo = _extractOwnerAndRepo(remoteUrl);
  if (ownerAndRepo == null) return null;
  final (owner, repo) = ownerAndRepo;
  final relativePath = p.relative(
    p.dirname(readmePath),
    from: repoRootPath,
  );
  final pathSegments = [
    owner,
    repo,
    'main',
    ...p.split(relativePath),
  ].map(Uri.encodeComponent);
  final path = p.url.joinAll(pathSegments);
  final uri = Uri.https('raw.githubusercontent.com').replace(path: path);
  return uri;
}

Future<void> main(List<String> args) async {
  final runner = CoverdeCommandRunner();
  final commands = runner.featureCommands.toSet();

  final parser = ArgParser(allowTrailingOptions: false)
    ..addOption(
      'readme',
      mandatory: true,
    )
    ..addMultiOption(
      'example-dirs',
    );
  final argResults = parser.parse(args);
  final readmePath = argResults.option('readme')!;
  final exampleDirPaths = argResults.multiOption('example-dirs');

  final readmeFile = File(readmePath);
  if (!readmeFile.existsSync()) readmeFile.createSync(recursive: true);
  final initialReadmeContent = readmeFile.readAsStringSync();

  final docsAssetBaseUri = await _resolveDocsAssetBaseUri(readmePath);

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
          '- [**${command.sanitizedSummary}**]',
          '(#${commandInvocation.paramCase})',
        ].join();

        detailsBuffer
          ..writeln('## `$commandInvocation`')
          ..writeln()
          ..writeln(
            command.markdownMultiline,
          );
        final commandExampleFiles = exampleFiles.where(
          (file) {
            final name = p.basenameWithoutExtension(file.path);
            final extension = p.extension(file.path);
            return name.startsWith(commandInvocation.paramCase) &&
                ['.png', '.md'].contains(extension);
          },
        );
        if (commandExampleFiles.isNotEmpty && docsAssetBaseUri != null) {
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
              final path = p.url.joinAll([
                docsAssetBaseUri.path,
                ...p.split(referenceableExamplePath).map(Uri.encodeComponent),
              ]);
              final exampleUri = docsAssetBaseUri.replace(path: path);
              detailsBuffer.writeln(
                '![${p.basename(commandExampleFile.path)}]'
                '($exampleUri)',
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
  String get markdownMultiline {
    final buf = StringBuffer();
    if (descriptionHeader != null) {
      buf
        ..writeln()
        ..writeln(descriptionHeader);
    }
    buf.writeln(sanitizedDescription.asMarkdownMultiline);
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
    if (argumentsFooter != null) {
      buf
        ..writeln()
        ..writeln(argumentsFooter);
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

extension on CoverdeCommand {
  String get sanitizedSummary {
    return switch (this) {
      _ => summary,
    };
  }

  String get sanitizedDescription {
    return switch (this) {
      FilterCommand() => () {
          final description = this.description;
          return [
            sanitizedSummary,
            ...LineSplitter.split(description).skip(1),
          ].join('\n').trim();
        }(),
      _ => description,
    };
  }

  String? get descriptionHeader {
    return switch (this) {
      _ => null,
    };
  }

  String? get descriptionFooter {
    return switch (this) {
      OptimizeTestsCommand() => '''
> [!NOTE]
> **Why use `coverde optimize-tests`?**
>
> The `optimize-tests` command gathers all your Dart test files into a single "optimized" test entry point. This can lead to much faster test execution, especially in CI/CD pipelines or large test suites. By reducing the Dart VM spawn overhead and centralizing test discovery, it enables more efficient use of resources.
>
> For more information, see the [flutter/flutter#90225](https://github.com/flutter/flutter/issues/90225).
'''
          .trim(),
      _ => null,
    };
  }

  String? get argumentsFooter {
    return switch (this) {
      _ => null,
    };
  }
}
