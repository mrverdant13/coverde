import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cov_utils/src/commands/x/rm/rm.dart';
import 'package:test/test.dart';

void main() {
  group(
    '''

GIVEN a filesystem element remover command''',
    () {
      late CommandRunner<void> cmdRunner;
      late RmCommand rmCmd;

      // ARRANGE
      setUp(
        () {
          cmdRunner = CommandRunner<void>('test', 'A tester command runner');
          rmCmd = RmCommand();
          cmdRunner.addCommand(rmCmd);
        },
      );

      test(
        '''

AND an existing file to remove
WHEN it the command is invoqued
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
WHEN it the command is invoqued
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
              ]);

          // ASSERT
          expect(action, throwsA(isA<StateError>()));
          expect(file.existsSync(), isFalse);
        },
      );

      test(
        '''

AND an existing directory to remove
WHEN it the command is invoqued
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
WHEN it the command is invoqued
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
              ]);

          // ASSERT
          expect(action, throwsA(isA<StateError>()));
          expect(dir.existsSync(), isFalse);
        },
      );

      test(
        '''

AND no element to remove
WHEN it the command is invoqued
THEN an error indicating the issue should be thrown
''',
        () {
          // ACT
          Future<void> action() => cmdRunner.run([rmCmd.name]);

          // ASSERT
          expect(action, throwsA(isA<ArgumentError>()));
        },
      );
    },
  );
}
