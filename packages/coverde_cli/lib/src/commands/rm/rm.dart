import 'package:coverde/src/commands/commands.dart';
import 'package:meta/meta.dart';
import 'package:universal_io/io.dart';

export 'failures.dart';

/// {@template rm_cmd}
/// A generic subcommand to remove a set of files and/or folders.
/// {@endtemplate}
class RmCommand extends CoverdeCommand {
  /// {@macro rm_cmd}
  RmCommand() {
    argParser
      ..addFlag(
        dryRunFlag,
        help: '''
Preview what would be deleted without actually deleting.
When enabled (default), the command will list what would be deleted but not perform the deletion.
When disabled, the command will actually delete the specified files and folders.''',
        defaultsTo: true,
      )
      ..addFlag(
        acceptAbsenceFlag,
        help: '''
Accept absence of a file or folder.
When an element is not present:
- If enabled, the command will continue.
- If disabled, the command will fail.''',
        defaultsTo: true,
      );
  }

  /// Flag to define whether to preview deletions without actually deleting.
  @visibleForTesting
  static const dryRunFlag = 'dry-run';

  /// Flag to define whether filesystem entity absence should be accepted.
  @visibleForTesting
  static const acceptAbsenceFlag = 'accept-absence';

  @override
  String get description => '''
Remove a set of files and folders.''';

  @override
  String get name => 'remove';

  @override
  List<String> get aliases => ['rm'];

  @override
  CoverdeCommandParams get params => CoverdeCommandParams(
        identifier: 'paths',
        description: 'Set of file and/or directory paths to be removed.',
      );

  @override
  Future<void> run() async {
    final argResults = this.argResults!;
    final isDryRun = argResults.flag(dryRunFlag);
    final shouldAcceptAbsence = argResults.flag(acceptAbsenceFlag);

    final paths = argResults.rest;
    if (paths.isEmpty) {
      throw CoverdeRmMissingPathsFailure(
        usageMessage: usageWithoutDescription,
      );
    }
    for (final elementPath in paths) {
      final elementType = FileSystemEntity.typeSync(elementPath);

      // The element can only be a folder or a file.
      // ignore: exhaustive_cases
      switch (elementType) {
        case FileSystemEntityType.directory:
          if (isDryRun) {
            logger.info('[DRY RUN] Would remove dir:  <$elementPath>');
          } else {
            Directory(elementPath).deleteSync(recursive: true);
          }
        case FileSystemEntityType.file:
          if (isDryRun) {
            logger.info('[DRY RUN] Would remove file: <$elementPath>');
          } else {
            File(elementPath).deleteSync();
          }
        case FileSystemEntityType.notFound:
          final failure = CoverdeRmElementNotFoundFailure(
            elementPath: elementPath,
          );
          if (shouldAcceptAbsence) {
            logger.info(failure.readableMessage);
          } else {
            throw failure;
          }
      }
    }
  }
}
