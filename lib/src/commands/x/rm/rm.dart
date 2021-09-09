import 'dart:io';

import 'package:args/command_runner.dart';

/// {@template rm_cmd}
/// A generic subcommand to remove a set of files and/or folders.
/// {@endtemplate}
class RmCommand extends Command<void> {
  /// {@macro rm_cmd}
  RmCommand();

  @override
  String get description => 'Remove a set of files and folders.';

  @override
  String get name => 'remove';

  @override
  List<String> get aliases => ['rm'];

  @override
  Future<void> run() async {
    try {
      final _argResults = ArgumentError.checkNotNull(argResults);
      final args = _argResults.arguments;
      if (args.isEmpty) {
        stdout.writeln(
          'A set of file and/or directory paths should be provided.',
        );
      }
      for (final elementPath in args) {
        final elementType = FileSystemEntity.typeSync(elementPath);
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
            stdout.writeln('The element <$elementPath> does not exist.');
            break;
          default:
            throw UnsupportedError(
              'Unsupported element type: $elementType. '
              "The next paths in the provided set won't be processed.",
            );
        }
      }
    } catch (e) {
      stdout.write('$e');
      exitCode = 1;
    }
  }
}
