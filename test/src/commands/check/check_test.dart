import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/check/check.dart';
import 'package:coverde/src/commands/check/min_coverage.exception.dart';
import 'package:coverde/src/entities/tracefile.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../utils/mocks.dart';

void main() {
  group(
    '''

GIVEN a tracefile coverage checker command''',
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
        '''

AND a minimum expected coverage value
AND an existing tracefile
├─ THAT has a coverage value greater than the minimum expected coverage value
AND the enabled option to log coverage value info
WHEN the command is invoqued
THEN the tracefile coverage should be checked and approved
├─ BY comparing its coverage value
├─ AND logging coverage value data
''',
        () async {
          // ARRANGE
          const tracefileFilePath = 'test/fixtures/check/lcov.info';
          final tracefileFile = File(tracefileFilePath);
          final tracefile = Tracefile.parse(tracefileFile.readAsStringSync());
          const minCoverage = 50;

          expect(tracefileFile.existsSync(), isTrue);
          expect(tracefile.coverage, greaterThan(minCoverage));

          // ACT
          await cmdRunner.run([
            checkCmd.name,
            '--${CheckCommand.inputOption}',
            tracefileFilePath,
            '--${CheckCommand.verboseFlag}',
            '$minCoverage',
          ]);

          // ASSERT
          final verifications = verifyInOrder([
            ...tracefile.sourceFilesCovData.map(
              (d) => () => out.writeln(d.coverageDataString),
            ),
            () => out.writeln('GLOBAL:'),
            () => out.writeln(tracefile.coverageDataString),
          ]);
          for (final verification in verifications) {
            verification.called(1);
          }
          verify(() => out.writeln());
        },
      );

      test(
        '''

AND a minimum expected coverage value
AND an existing tracefile
├─ THAT has a coverage value lower than the minimum expected coverage value
AND the disabled option to log coverage value info
WHEN the command is invoqued
THEN the tracefile coverage should be checked and disapproved
├─ BY comparing its coverage value
├─ AND throwing an exception
''',
        () async {
          // ARRANGE
          const tracefileFilePath = 'test/fixtures/check/lcov.info';
          final tracefileFile = File(tracefileFilePath);
          final tracefile = Tracefile.parse(tracefileFile.readAsStringSync());
          const minCoverage = 90;

          expect(tracefileFile.existsSync(), isTrue);
          expect(tracefile.coverage, lessThan(minCoverage));

          // ACT
          Future<void> action() => cmdRunner.run([
                checkCmd.name,
                '--${CheckCommand.inputOption}',
                tracefileFilePath,
                '--no-${CheckCommand.verboseFlag}',
                '$minCoverage',
              ]);

          // ASSERT
          expect(action, throwsA(isA<MinCoverageException>()));
        },
      );

      test(
        '''

AND a non-existing tracefile
AND a minimum expected coverage value
WHEN the command is invoqued
THEN an error indicating the issue should be thrown
''',
        () async {
          // ARRANGE
          const absentFilePath = 'test/fixtures/check/absent.lcov.info';
          final absentFile = File(absentFilePath);
          const minCoverage = 50;

          expect(absentFile.existsSync(), isFalse);

          // ACT
          Future<void> action() => cmdRunner.run([
                checkCmd.name,
                '--${CheckCommand.inputOption}',
                absentFilePath,
                '$minCoverage',
              ]);

          // ASSERT
          expect(action, throwsA(isA<UsageException>()));
        },
      );

      test(
        '''

AND no minimum expected coverage value
WHEN the command is invoqued
THEN an error indicating the issue should be thrown
''',
        () async {
          // ACT
          Future<void> action() => cmdRunner.run([checkCmd.name]);

          // ASSERT
          expect(action, throwsA(isA<UsageException>()));
        },
      );

      test(
        '''

AND a non-numeric argument as minimum expected coverage value
WHEN the command is invoqued
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
          expect(action, throwsA(isA<UsageException>()));
        },
      );
    },
  );
}
