import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/value/value.dart';
import 'package:coverde/src/entities/tracefile.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../utils/mocks.dart';

void main() {
  group(
    '''

GIVEN a tracefile value computer command''',
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

AND an existing tracefile
AND the disabled option to print coverage data about tracefile listed files
WHEN the the tracefile coverage value is requested
THEN the global value is displayed
├─ BY logging the relative coverage value in percentage
├─ AND logging the number of covered lines fo code
''',
        () async {
          // ARRANGE
          const tracefilePath = 'test/fixtures/value/lcov.info';
          final tracefileFile = File(tracefilePath);
          final tracefile = Tracefile.parse(tracefileFile.readAsStringSync());

          expect(tracefileFile.existsSync(), isTrue);

          // ACT
          await cmdRunner.run([
            valueCmd.name,
            '--${ValueCommand.fileOption}',
            tracefilePath,
            '--no-${ValueCommand.printFilesFlag}',
          ]);

          // ASSERT
          final verifications = verifyInOrder([
            () => out.writeln('GLOBAL:'),
            () => out.writeln(tracefile.coverageDataString),
          ]);
          for (final verification in verifications) {
            verification.called(1);
          }
        },
      );

      test(
        '''

AND an existing tracefile
AND the enabled option to print coverage data about tracefile listed files
WHEN the the tracefile coverage value is requested
THEN the coverage value for each individual file should be displayed
AND the global value should be displayed
├─ BY logging the relative coverage value in percentage
├─ AND logging the number of covered lines fo code
''',
        () async {
          // ARRANGE
          const tracefilePath = 'test/fixtures/value/lcov.info';
          final tracefileFile = File(tracefilePath);
          final tracefile = Tracefile.parse(tracefileFile.readAsStringSync());

          expect(tracefileFile.existsSync(), isTrue);

          // ACT
          await cmdRunner.run([
            valueCmd.name,
            '--${ValueCommand.fileOption}',
            tracefilePath,
            '--${ValueCommand.printFilesFlag}',
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

AND a non-existing tracefile
WHEN the the tracefile coverage value is requested
THEN an error indicating the issue should be thrown
''',
        () async {
          // ARRANGE
          const absentFilePath = 'test/fixtures/value/absent.lcov.info';
          final absentFile = File(absentFilePath);
          expect(absentFile.existsSync(), isFalse);

          // ACT
          Future<void> action() => cmdRunner.run([
                valueCmd.name,
                '--${ValueCommand.fileOption}',
                absentFilePath,
              ]);

          // ASSERT
          expect(action, throwsA(isA<StateError>()));
        },
      );
    },
  );
}
