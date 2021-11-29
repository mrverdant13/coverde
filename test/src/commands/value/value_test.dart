import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/value/value.dart';
import 'package:coverde/src/entities/tracefile.dart';
import 'package:coverde/src/utils/path.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

import '../../../utils/mocks.dart';

extension _FixturedString on String {
  String get fixturePath => path.join(
        'test/src/commands/value/fixtures/',
        this,
      );
}

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

AND an existing tracefile
AND the disabled option to print coverage data about tracefile listed files
WHEN the the tracefile coverage value is requested
THEN the global value is displayed
├─ BY logging the relative coverage value in percentage
├─ AND logging the number of covered lines fo code
''',
        () async {
          // ARRANGE
          final tracefilePath = 'lcov.info'.fixturePath;
          final tracefileFile = File(tracefilePath);
          final tracefile = Tracefile.parse(tracefileFile.readAsStringSync());

          expect(tracefileFile.existsSync(), isTrue);

          // ACT
          await cmdRunner.run([
            valueCmd.name,
            '--${ValueCommand.inputOption}',
            tracefilePath,
            '--no-${ValueCommand.verboseFlag}',
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
          final tracefilePath = 'lcov.info'.fixturePath;
          final tracefileFile = File(tracefilePath);
          final tracefile = Tracefile.parse(tracefileFile.readAsStringSync());

          expect(tracefileFile.existsSync(), isTrue);

          // ACT
          await cmdRunner.run([
            valueCmd.name,
            '--${ValueCommand.inputOption}',
            tracefilePath,
            '--${ValueCommand.verboseFlag}',
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
