import 'dart:io';

import 'package:coverde/src/commands/check/min_coverage.exception.dart';
import 'package:coverde/src/entities/tracefile.dart';
import 'package:io/io.dart';
import 'package:test/test.dart';

void main() {
  group(
    '''

GIVEN a minimum coverage exception
├─ THAT includes a minimum coverage value
├─ AND holds a tracefile''',
    () {
      // ARRANGE
      const minCoverage = 40.0;
      const tracefileFilePath = 'test/fixtures/check/lcov.info';
      final tracefileFile = File(tracefileFilePath);
      final tracefile = Tracefile.parse(tracefileFile.readAsStringSync());
      final exception = MinCoverageException(
        minCoverage: minCoverage,
        tracefile: tracefile,
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
            result.contains('Actual coverage: ${tracefile.coverageString}'),
            isTrue,
          );
        },
      );
    },
  );
}
