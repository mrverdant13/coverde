import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/rm/rm.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

import '../../../utils/mocks.dart';

void main() {
  group(
    '''

GIVEN a filesystem element remover command''',
    () {
      late CommandRunner<void> cmdRunner;
      late MockStdout out;
      late RmCommand rmCmd;

      // ARRANGE
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
        '''

WHEN its description is requested
THEN a proper abstract should be returned
''',
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
        '''

AND an existing file to remove
WHEN the command is invoqued
THEN the file should be removed
''',
        () async {
          // ARRANGE
          const filePath = 'coverage/existing.file';
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
        '''

AND a non-existing file to remove
AND the requirement for the file to exist
WHEN the command is invoqued
THEN an error indicating the issue should be thrown
AND the file should remain inexistent
''',
        () async {
          // ARRANGE
          const filePath = 'coverage/non-existing.file';
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
        '''

AND a non-existing file to remove
AND no requirement for the file to exist
WHEN the command is invoqued
THEN a message indicating the issue should be shown
AND the file should remain inexistent
''',
        () async {
          // ARRANGE
          const filePath = 'coverage/non-existing.file';
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
        '''

AND an existing directory to remove
WHEN the command is invoqued
THEN the directory should be removed
''',
        () async {
          // ARRANGE
          const dirPath = 'coverage/existing.dir/';
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
        '''

AND a non-existing directory to remove
AND the requirement for the directory to exist
WHEN the command is invoqued
THEN an error indicating the issue should be thrown
AND the directory should remain inexistent
''',
        () async {
          // ARRANGE
          const dirPath = 'coverage/non-existing.dir/';
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
        '''

AND a non-existing directory to remove
AND no requirement for the directory to exist
WHEN the command is invoqued
THEN a message indicating the issue should be shown
AND the directory should remain inexistent
''',
        () async {
          // ARRANGE
          const dirPath = 'coverage/non-existing.dir/';
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
        '''

AND no element to remove
WHEN the command is invoqued
THEN an error indicating the issue should be thrown
''',
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
