import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/value/value.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

import '../../../utils/mocks.dart';

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
          final directory = Directory.systemTemp.createTempSync();
          final traceFileContent = '''
SF:${path.joinAll(['path', 'to', 'source_file.dart'])}
DA:1,1
DA:2,0
DA:3,1
DA:4,0
LF:4
LH:2
end_of_record
''';
          final traceFilePath = path.join(directory.path, 'lcov.info');
          final traceFileFile = File(traceFilePath)
            ..createSync()
            ..writeAsStringSync(traceFileContent);

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
            () => out.writeln('50.00% - 2/4'),
          ]);
          for (final verification in verifications) {
            verification.called(1);
          }
          directory.deleteSync(recursive: true);
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
          final directory = Directory.systemTemp.createTempSync();
          final sourceFileAPath =
              path.joinAll(['path', 'to', 'source_file_a.dart']);
          final sourceFileBPath =
              path.joinAll(['path', 'to', 'source_file_b.dart']);
          final traceFileContent = '''
SF:$sourceFileAPath
DA:1,1
DA:2,0
DA:3,1
DA:4,0
LF:4
LH:2
end_of_record
SF:$sourceFileBPath
DA:1,1
DA:2,0
DA:3,0
DA:4,0
DA:5,0
LF:5
LH:1
end_of_record
''';
          final traceFilePath = path.join(directory.path, 'lcov.info');
          final traceFileFile = File(traceFilePath)
            ..createSync()
            ..writeAsStringSync(traceFileContent);

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
            () => out.writeln('$sourceFileAPath (50.00% - 2/4)'),
            () => out.writeln('$sourceFileBPath (20.00% - 1/5)'),
            () => out.writeln('GLOBAL:'),
            () => out.writeln('33.33% - 3/9'),
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

AND a non-existing trace file
WHEN the the trace file coverage value is requested
THEN an error indicating the issue should be thrown
''',
        () async {
          // ARRANGE
          final directory = Directory.systemTemp.createTempSync();
          final absentFilePath = path.join(directory.path, 'absent.lcov.info');
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
          directory.deleteSync(recursive: true);
        },
      );
    },
  );
}
