import 'package:coverde/src/commands/check/min_coverage.exception.dart';
import 'package:coverde/src/entities/trace_file.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group(
    '$MinCoverageException',
    () {
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
        'code '
        '| returns software exit code',
        () {
          final result = exception.code;

          expect(result, ExitCode.software);
        },
      );

      test(
        'toString() '
        '| returns string representation '
        'including expected and actual coverage values',
        () {
          final result = exception.toString();
          expect(
            result,
            contains(
              'Expected min coverage: ${minCoverage.toStringAsFixed(2)}',
            ),
          );
          expect(
            result,
            contains('Actual coverage: ${traceFile.coverageString}'),
          );
        },
      );
    },
  );
}
