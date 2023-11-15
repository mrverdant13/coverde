import 'package:coverde/src/commands/check/min_coverage.exception.dart';
import 'package:coverde/src/entities/trace_file.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group(
    '''

GIVEN a minimum coverage exception
├─ THAT includes a minimum coverage value
├─ AND holds a trace file''',
    () {
      // ARRANGE
      const minCoverage = 90.0;
      final traceFileContent = '''
SF:${path.join('path', 'to', 'source_file.dart')}
DA:1,1
DA:2,1
DA:3,1
DA:4,1
DA:5,0
LF:5
LH:4
end_of_record
''';
      final traceFile = TraceFile.parse(traceFileContent);
      final exception = MinCoverageException(
        minCoverage: minCoverage,
        traceFile: traceFile,
      );

      test(
        '''
WHEN its exit code is requested
THEN the software code should be returned
''',
        () {
          // ACT
          final result = exception.code;

          // ASSERT
          expect(result, ExitCode.software);
        },
      );

      test(
        '''
WHEN its string representation is requested
THEN a string holding the exception details should be returned
├─ BY including the expected coverage value
├─ AND including the actual coverage value
''',
        () {
          // ACT
          final result = exception.toString();

          // ASSERT
          expect(
            result.contains(
              'Expected min coverage: ${minCoverage.toStringAsFixed(2)}',
            ),
            isTrue,
          );
          expect(
            result.contains('Actual coverage: ${traceFile.coverageString}'),
            isTrue,
          );
        },
      );
    },
  );
}
