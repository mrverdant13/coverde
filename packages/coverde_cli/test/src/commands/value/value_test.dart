import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/value/value.dart';
import 'package:coverde/src/entities/trace_file.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

import '../../../utils/mocks.dart';

extension on String {
  String get fixturePath => path.join(
        'test/src/commands/value/fixtures/',
        this,
      );
}

void main() {
  group(
    '''

GIVEN a trace file value computer command''',
    () {
      late CommandRunner<void> cmdRunner;
      late MockStdout out;
      late ValueCommand valueCmd;

      // ARRANGE
      setUp(
        () {
          cmdRunner = CommandRunner<void>('test', 'A tester command runner');
          out = MockStdout();
          valueCmd = ValueCommand(out: out);
          cmdRunner.addCommand(valueCmd);
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
Compute the coverage value (%) of an info file.

Compute the coverage value of the LCOV_FILE info file.
''';

          // ACT
          final result = valueCmd.description;

          // ASSERT
          expect(result.trim(), expected.trim());
        },
      );

      test(
        '''

AND an existing trace file
AND the disabled option to print coverage data about trace file listed files
WHEN the the trace file coverage value is requested
THEN the global value is displayed
├─ BY logging the relative coverage value in percentage
├─ AND logging the number of covered lines fo code
''',
        () async {
          // ARRANGE
          final traceFilePath = 'lcov.info'.fixturePath;
          final traceFileFile = File(traceFilePath);
          final traceFile = TraceFile.parse(traceFileFile.readAsStringSync());

          expect(traceFileFile.existsSync(), isTrue);

          // ACT
          await cmdRunner.run([
            valueCmd.name,
            '--${ValueCommand.inputOption}',
            traceFilePath,
            '--no-${ValueCommand.verboseFlag}',
          ]);

          // ASSERT
          final verifications = verifyInOrder([
            () => out.writeln('GLOBAL:'),
            () => out.writeln(traceFile.coverageDataString),
          ]);
          for (final verification in verifications) {
            verification.called(1);
          }
        },
      );

      test(
        '''

AND an existing trace file
AND the enabled option to print coverage data about trace file listed files
WHEN the the trace file coverage value is requested
THEN the coverage value for each individual file should be displayed
AND the global value should be displayed
├─ BY logging the relative coverage value in percentage
├─ AND logging the number of covered lines fo code
''',
        () async {
          // ARRANGE
          final traceFilePath = 'lcov.info'.fixturePath;
          final traceFileFile = File(traceFilePath);
          final traceFile = TraceFile.parse(traceFileFile.readAsStringSync());

          expect(traceFileFile.existsSync(), isTrue);

          // ACT
          await cmdRunner.run([
            valueCmd.name,
            '--${ValueCommand.inputOption}',
            traceFilePath,
            '--${ValueCommand.verboseFlag}',
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
        },
      );

      test(
        '''

AND a non-existing trace file
WHEN the the trace file coverage value is requested
THEN an error indicating the issue should be thrown
''',
        () async {
          // ARRANGE
          final absentFilePath = 'absent.lcov.info'.fixturePath;
          final absentFile = File(absentFilePath);
          expect(absentFile.existsSync(), isFalse);

          // ACT
          Future<void> action() => cmdRunner.run([
                valueCmd.name,
                '--${ValueCommand.inputOption}',
                absentFilePath,
              ]);

          // ASSERT
          expect(action, throwsA(isA<UsageException>()));
        },
      );
    },
  );
}
