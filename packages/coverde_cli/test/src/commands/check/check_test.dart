import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/check/check.dart';
import 'package:coverde/src/commands/check/min_coverage.exception.dart';
import 'package:coverde/src/entities/cov_file_format.exception.dart';
import 'package:coverde/src/entities/file_coverage_log_level.dart';
import 'package:io/ansi.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

import '../../../helpers/test_files.dart';
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
          final projectDir = Directory(projectPath);

          generateTestFromTemplate(projectDir);
          addTearDown(() => deleteTestFiles(projectDir));

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
        '''--${CheckCommand.inputOptionName}=<empty_trace_file> '''
        '''<min_coverage> '''
        '''| fails when trace file is empty''',
        () async {
          final emptyTraceFilePath = p.joinAll([
            'test',
            'src',
            'commands',
            'check',
            'fixtures',
            'empty.lcov.info',
          ]);
          Future<void> action() => cmdRunner.run([
                checkCmd.name,
                '--${CheckCommand.inputOptionName}',
                emptyTraceFilePath,
                '${50}',
              ]);
          expect(
            action,
            throwsA(
              isA<CovFileFormatException>().having(
                (e) => e.message,
                'message',
                'No coverage data found in the trace file.',
              ),
            ),
          );
        },
      );

      test(
        '''--${CheckCommand.fileCoverageLogLevelOptionName}=${FileCoverageLogLevel.none.identifier} '''
        '<min_coverage> '
        '| fails when coverage is below minimum',
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
        '--${CheckCommand.inputOptionName}=<absent_file> '
        '<min_coverage> '
        '| fails when trace file does not exist',
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
        '| fails when no minimum expected coverage value',
        () async {
          // ACT
          Future<void> action() => cmdRunner.run([checkCmd.name]);

          // ASSERT
          expect(action, throwsArgumentError);
        },
      );

      test(
        '<non-numeric> | fails when minimum coverage value is non-numeric',
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
