import 'package:args/command_runner.dart';
import 'package:coverde/src/utils/command.dart';
import 'package:meta/meta.dart';
import 'package:universal_io/io.dart';

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

  @override
  String get description => '''
Remove a set of files and folders.''';

  @override
  String get name => 'remove';

  @override
  List<String> get aliases => ['rm'];

  @override
  String get invocation => super.invocation.replaceAll(
        '[arguments]',
        '[paths]',
      );

  @override
  Future<void> run() async {
    final shouldAcceptAbsence = checkFlag(
      flagKey: acceptAbsenceFlag,
      flagName: 'absence acceptance',
    );

    final paths = argResults!.rest;
    if (paths.isEmpty) {
      usageException(
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
            usageException(message);
          }
      }
    }
  }
}
