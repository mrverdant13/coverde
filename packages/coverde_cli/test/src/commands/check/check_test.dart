import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/check/check.dart';
import 'package:coverde/src/commands/check/min_coverage.exception.dart';
import 'package:coverde/src/entities/file_coverage_log_level.dart';
import 'package:io/ansi.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

import '../../../utils/mocks.dart';

void main() {
  group(
    'coverde check',
    () {
      late CommandRunner<void> cmdRunner;
      late MockStdout out;
      late CheckCommand checkCmd;

      // ARRANGE
      setUp(
        () {
          cmdRunner = CommandRunner<void>('test', 'A tester command runner');
          out = MockStdout();
          checkCmd = CheckCommand(out: out);
          cmdRunner.addCommand(checkCmd);
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
Check the coverage value (%) computed from a trace file.

The unique argument should be an integer between 0 and 100.
This parameter indicates the minimum value for the coverage to be accepted.
''';

          // ACT
          final result = checkCmd.description;

          // ASSERT
          expect(result.trim(), expected.trim());
        },
      );

      test(
        '''--${CheckCommand.fileCoverageLogLevelOptionName}=${FileCoverageLogLevel.none.identifier} '''
        '''<min_coverage> '''
        '''| meets the minimum coverage''',
        () async {
          final currentDirectory = Directory.current;
          final projectPath = p.joinAll([
            currentDirectory.path,
            'test',
            'src',
            'commands',
            'check',
            'fixtures',
            'partially_covered_proj',
          ]);

          await IOOverrides.runZoned(
            () async {
              await cmdRunner.run([
                checkCmd.name,
                '--${CheckCommand.fileCoverageLogLevelOptionName}',
                FileCoverageLogLevel.none.identifier,
                '${50}',
              ]);
            },
            getCurrentDirectory: () => Directory(projectPath),
          );

          final messages = [
            wrapWith('GLOBAL:', [blue, styleBold]),
            wrapWith('56.25% - 9/16', [blue, styleBold]),
          ];
          verifyInOrder([
            for (final message in messages) () => out.writeln(message),
          ]);
        },
      );

      test(
        '''

AND a minimum expected coverage value
AND an existing trace file
├─ THAT has a coverage value lower than the minimum expected coverage value
AND the disabled option to log coverage value info
WHEN the command is invoked
THEN the trace file coverage should be checked and disapproved
├─ BY comparing its coverage value
├─ AND throwing an exception
''',
        () async {
          final currentDirectory = Directory.current;
          final projectPath = p.joinAll([
            currentDirectory.path,
            'test',
            'src',
            'commands',
            'check',
            'fixtures',
            'partially_covered_proj',
          ]);

          Future<void> action() => IOOverrides.runZoned(
                () async {
                  await cmdRunner.run([
                    checkCmd.name,
                    '--${CheckCommand.fileCoverageLogLevelOptionName}',
                    FileCoverageLogLevel.none.identifier,
                    '${75}',
                  ]);
                },
                getCurrentDirectory: () => Directory(projectPath),
              );

          expect(action, throwsA(isA<MinCoverageException>()));
          final messages = [
            wrapWith('GLOBAL:', [blue, styleBold]),
            wrapWith('56.25% - 9/16', [blue, styleBold]),
          ];
          verifyInOrder([
            for (final message in messages) () => out.writeln(message),
          ]);
        },
      );

      test(
        '''

AND a non-existing trace file
AND a minimum expected coverage value
WHEN the command is invoked
THEN an error indicating the issue should be thrown
''',
        () async {
          // ARRANGE
          final directory = Directory.systemTemp.createTempSync();
          final absentFilePath = p.join(directory.path, 'absent.lcov.info');
          final absentFile = File(absentFilePath);
          const minCoverage = 50;
          expect(absentFile.existsSync(), isFalse);

          // ACT
          Future<void> action() => cmdRunner.run([
                checkCmd.name,
                '--${CheckCommand.inputOptionName}',
                absentFilePath,
                '$minCoverage',
              ]);

          // ASSERT
          expect(action, throwsA(isA<UsageException>()));
          directory.deleteSync(recursive: true);
        },
      );

      test(
        '''

AND no minimum expected coverage value
WHEN the command is invoked
THEN an error indicating the issue should be thrown
''',
        () async {
          // ACT
          Future<void> action() => cmdRunner.run([checkCmd.name]);

          // ASSERT
          expect(action, throwsArgumentError);
        },
      );

      test(
        '''

AND a non-numeric argument as minimum expected coverage value
WHEN the command is invoked
THEN an error indicating the issue should be thrown
''',
        () async {
          // ARRANGE
          const invalidMinCoverage = 'str';

          // ACT
          Future<void> action() => cmdRunner.run([
                checkCmd.name,
                invalidMinCoverage,
              ]);

          // ASSERT
          expect(action, throwsArgumentError);
        },
      );
    },
  );
}
