import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/check/check.dart';
import 'package:coverde/src/commands/check/min_coverage.exception.dart';
import 'package:coverde/src/entities/trace_file.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

import '../../../utils/mocks.dart';

void main() {
  group(
    '''

GIVEN a trace file coverage checker command''',
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

WHEN its description is requested
THEN a proper abstract should be returned
''',
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
        '''

AND a minimum expected coverage value
AND an existing trace file
├─ THAT has a coverage value greater than the minimum expected coverage value
AND the enabled option to log coverage value info
WHEN the command is invoked
THEN the trace file coverage should be checked and approved
├─ BY comparing its coverage value
├─ AND logging coverage value data
''',
        () async {
          // ARRANGE
          final directory = Directory.systemTemp.createTempSync();
          final traceFileContent = '''
SF:${path.join('path', 'to', 'source_file.dart')}
DA:1,1
DA:2,0
DA:3,1
DA:4,1
DA:5,0
LF:5
LH:3
end_of_record
''';
          final traceFilePath = path.join(directory.path, 'lcov.info');
          final traceFileFile = File(traceFilePath)
            ..createSync()
            ..writeAsStringSync(traceFileContent);
          final traceFile = TraceFile.parse(traceFileFile.readAsStringSync());
          const minCoverage = 50.0;

          expect(traceFileFile.existsSync(), isTrue);
          expect(traceFile.coverage, greaterThan(minCoverage));

          // ACT
          await cmdRunner.run([
            checkCmd.name,
            '--${CheckCommand.inputOption}',
            traceFilePath,
            '--${CheckCommand.verboseFlag}',
            '$minCoverage',
          ]);

          // ASSERT
          final verifications = verifyInOrder([
            ...traceFile.sourceFilesCovData.map(
              (d) => () => out.writeln(d.coverageDataString),
            ),
            () => out.writeln('GLOBAL:'),
            () => out.writeln(traceFile.coverageDataString),
          ]);
          for (final verification in verifications) {
            verification.called(1);
          }
          verify(() => out.writeln());
          directory.deleteSync(recursive: true);
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
          // ARRANGE
          final directory = Directory.systemTemp.createTempSync();
          final traceFileContent = '''
SF:${path.join('path', 'to', 'source_file.dart')}
DA:1,1
DA:2,0
DA:3,1
DA:4,1
DA:5,0
LF:5
LH:3
end_of_record
''';
          final traceFilePath = path.join(directory.path, 'lcov.info');
          final traceFileFile = File(traceFilePath)
            ..createSync()
            ..writeAsStringSync(traceFileContent);
          final traceFile = TraceFile.parse(traceFileFile.readAsStringSync());
          const minCoverage = 75.0;

          expect(traceFileFile.existsSync(), isTrue);
          expect(traceFile.coverage, lessThan(minCoverage));

          // ACT
          Future<void> action() => cmdRunner.run([
                checkCmd.name,
                '--${CheckCommand.inputOption}',
                traceFilePath,
                '--no-${CheckCommand.verboseFlag}',
                '$minCoverage',
              ]);

          // ASSERT
          expect(action, throwsA(isA<MinCoverageException>()));
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
          final absentFilePath = path.join(directory.path, 'absent.lcov.info');
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
          expect(action, throwsA(isA<UsageException>()));
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
          expect(action, throwsA(isA<UsageException>()));
        },
      );
    },
  );
}
