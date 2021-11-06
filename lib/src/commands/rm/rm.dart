import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:meta/meta.dart';

/// {@template rm_cmd}
/// A generic subcommand to remove a set of files and/or folders.
/// {@endtemplate}
class RmCommand extends Command<void> {
  /// {@macro rm_cmd}
  RmCommand({Stdout? out}) : _out = out ?? stdout {
    argParser.addFlag(
      acceptAbsenceFlag,
      help: '''
Accept absence of a file or folder.
When an element is not present:
- If enabled, the command will continue.
- If disabled, the command will fail.''',
      defaultsTo: true,
    );
  }

  final Stdout _out;

  /// Flag to define whether filesystem entity absence should be accepted.
  @visibleForTesting
  static const acceptAbsenceFlag = 'accept-absence';

  @override // coverage:ignore-line
  String get description => '''
Remove a set of files and folders.''';

  @override
  String get name => 'remove';

  @override
  List<String> get aliases => ['rm'];

  @override
  Future<void> run() async {
    final _argResults = ArgumentError.checkNotNull(argResults);

    final shouldAcceptAbsence = ArgumentError.checkNotNull(
      _argResults[acceptAbsenceFlag],
    ) as bool;

    final paths = _argResults.rest;
    if (paths.isEmpty) {
      throw ArgumentError(
        'A set of file and/or directory paths should be provided.',
      );
    }
    for (final elementPath in paths) {
      final elementType = FileSystemEntity.typeSync(elementPath);

      // The element can only be a folder or a file.
      // ignore: exhaustive_cases
      switch (elementType) {
        case FileSystemEntityType.directory:
          final dir = Directory(elementPath);
          dir.deleteSync(recursive: true);
          break;
        case FileSystemEntityType.file:
          final file = File(elementPath);
          file.deleteSync(recursive: true);
          break;
        case FileSystemEntityType.notFound:
          final message = 'The <$elementPath> element does not exist.';
          if (shouldAcceptAbsence) {
            _out.writeln(message);
          } else {
            throw StateError(message);
          }
      }
    }
  }
}
