import 'package:coverde/src/commands/check/min_coverage.exception.dart';
import 'package:coverde/src/entities/trace_file.dart';
import 'package:coverde/src/utils/path.dart';
import 'package:io/io.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

extension on String {
  String get fixturePath => path.join(
        'test/src/commands/check/fixtures/',
        this,
      );
}

void main() {
  group(
    '''

GIVEN a minimum coverage exception
├─ THAT includes a minimum coverage value
├─ AND holds a trace file''',
    () {
      // ARRANGE
      const minCoverage = 40.0;
      final traceFilePath = 'lcov.info'.fixturePath;
      final traceFileFile = File(traceFilePath);
      final traceFile = TraceFile.parse(traceFileFile.readAsStringSync());
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
