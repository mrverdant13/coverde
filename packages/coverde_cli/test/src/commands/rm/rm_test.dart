import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/rm/rm.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

import '../../../utils/mocks.dart';

void main() {
  group(
    'coverde rm',
    () {
      late CommandRunner<void> cmdRunner;
      late MockStdout out;
      late RmCommand rmCmd;

      setUp(
        () {
          cmdRunner = CommandRunner<void>('test', 'A tester command runner');
          out = MockStdout();
          rmCmd = RmCommand(out: out);
          cmdRunner.addCommand(rmCmd);
        },
      );

      tearDown(
        () {
          verifyNoMoreInteractions(out);
        },
      );

      test(
        '| description',
        () {
          // ARRANGE
          const expected = '''
Remove a set of files and folders.
''';

          // ACT
          final result = rmCmd.description;

          // ASSERT
          expect(result.trim(), expected.trim());
        },
      );

      test(
        '<existing_file> '
        '| removes existing file',
        () async {
          // ARRANGE
          final filePath = path.joinAll(['coverage', 'existing.file']);
          final file = File(filePath);
          await file.create(recursive: true);
          expect(file.existsSync(), isTrue);

          // ACT
          await cmdRunner.run([
            rmCmd.name,
            filePath,
          ]);

          // ASSERT
          expect(file.existsSync(), isFalse);
        },
      );

      test(
        '--no-${RmCommand.acceptAbsenceFlag} '
        '<non-existing_file> '
        '| fails when file does not exist',
        () async {
          // ARRANGE
          final filePath = path.joinAll(['coverage', 'non-existing.file']);
          final file = File(filePath);
          expect(file.existsSync(), isFalse);

          // ACT
          Future<void> action() => cmdRunner.run([
                rmCmd.name,
                filePath,
                '--no-${RmCommand.acceptAbsenceFlag}',
              ]);

          // ASSERT
          expect(action, throwsA(isA<UsageException>()));
          expect(file.existsSync(), isFalse);
        },
      );

      test(
        '--${RmCommand.acceptAbsenceFlag} '
        '<non-existing_file> '
        '| shows message when file does not exist',
        () async {
          // ARRANGE
          final filePath = path.joinAll(['coverage', 'non-existing.file']);
          final file = File(filePath);
          when(() => out.writeln(any<String>())).thenReturn(null);
          expect(file.existsSync(), isFalse);

          // ACT
          await cmdRunner.run([
            rmCmd.name,
            filePath,
            '--${RmCommand.acceptAbsenceFlag}',
          ]);

          // ASSERT
          verify(
            () => out.writeln('The <$filePath> element does not exist.'),
          ).called(1);
          expect(file.existsSync(), isFalse);
        },
      );

      test(
        '<existing_directory> '
        '| removes existing directory',
        () async {
          // ARRANGE
          final dirPath = path.joinAll(['coverage', 'existing.dir']);
          final dir = Directory(dirPath);
          await dir.create(recursive: true);
          expect(dir.existsSync(), isTrue);

          // ACT
          await cmdRunner.run([
            rmCmd.name,
            dirPath,
          ]);

          // ASSERT
          expect(dir.existsSync(), isFalse);
        },
      );

      test(
        '--no-${RmCommand.acceptAbsenceFlag} '
        '<non-existing_directory> '
        '| fails when directory does not exist',
        () async {
          // ARRANGE
          final dirPath = path.joinAll(['coverage', 'non-existing.dir']);
          final dir = File(dirPath);
          expect(dir.existsSync(), isFalse);

          // ACT
          Future<void> action() => cmdRunner.run([
                rmCmd.name,
                dirPath,
                '--no-${RmCommand.acceptAbsenceFlag}',
              ]);

          // ASSERT
          expect(action, throwsA(isA<UsageException>()));
          expect(dir.existsSync(), isFalse);
        },
      );

      test(
        '--${RmCommand.acceptAbsenceFlag} '
        '<non-existing_directory> '
        '| shows message when directory does not exist',
        () async {
          // ARRANGE
          final dirPath = path.joinAll(['coverage', 'non-existing.dir']);
          final dir = File(dirPath);
          when(() => out.writeln(any<String>())).thenReturn(null);
          expect(dir.existsSync(), isFalse);

          // ACT
          await cmdRunner.run([
            rmCmd.name,
            dirPath,
            '--${RmCommand.acceptAbsenceFlag}',
          ]);

          // ASSERT
          verify(
            () => out.writeln('The <$dirPath> element does not exist.'),
          ).called(1);
          expect(dir.existsSync(), isFalse);
        },
      );

      test(
        '| fails when no elements to remove',
        () {
          // ACT
          Future<void> action() => cmdRunner.run([rmCmd.name]);

          // ASSERT
          expect(action, throwsA(isA<UsageException>()));
        },
      );
    },
  );
}
